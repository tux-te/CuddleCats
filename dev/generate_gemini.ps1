<#
.SYNOPSIS
    Generate (or edit) an image with Google Gemini 2.5 Flash Image ("Nano Banana")
    via the Generative Language REST API, and save the PNG into ../Sprites/.

.DESCRIPTION
    Mirrors the shape of generate_pixellab.ps1 so it drops into the same workflow.

    API key resolution (in order):
      1. $env:GEMINI_API_KEY
      2. dev/gemini_key.txt   <-- git-ignored; this is the normal path.
    Get a key at https://aistudio.google.com/  ->  "Get API key".

    HOW GEMINI DIFFERS FROM PIXELLAB (read this before relying on it):
    ------------------------------------------------------------------
    - Gemini makes "pixel-ish" art, NOT a true fixed pixel grid / limited
      palette. For crisp gameplay sprites and clean animation frames,
      PixelLab is still the better default.
    - Gemini's superpower is EDITING an existing image (reskin, recolor,
      "make this arctic") and generating base/reference/concept images.
    - It ignores exact output sizes; it returns ~1024px. Crop/downscale
      afterwards (see crop step used for river_turtle_base.png).
    - Backgrounds: it does not do true alpha. Ask for a flat "plain white
      background" (or "solid green background" if the subject is white),
      then run remove_white_bg.ps1 to knock it out.

    RECOMMENDED PROMPT FORMULA (what has worked here):
        "<subject> only, pixel art, <view angle>, plain white background,
         no shadows, no water, no ripples, no outline, no background elements"
      e.g. "river turtle swimming, turtle only, pixel art, top-down view,
            plain white background, no shadows, no water, no ripples,
            no outline, no background elements"
      Use "solid green background" instead of white if the subject itself
      is mostly white.

      IMPORTANT: Gemini LOVES to add environment. For an underwater/river
      subject it will draw a faint blue water halo, ripples, and a soft
      outline around the creature even when you ask for a white background.
      Those blue/gray pixels are NOT white, so remove_white_bg.ps1 will not
      strip them and you get a halo in-game. ALWAYS include the negative
      phrases above ("<subject> only ... no water, no ripples, no outline,
      no background elements"). If a halo still appears, regenerate rather
      than shipping it.

    QUALITY: avoiding blocky / low-res results
    ------------------------------------------
    A plain "pixel art" prompt often renders at a LOW logical resolution --
    big chunky pixels, muddy shading. To force fine detail, add:
        "highly detailed pixel art, fine intricate pixel detail,
         sharp clean crisp pixels, rich shading"
    This noticeably raises the effective pixel density (verified on the
    top-down river turtle: chunky without it, crisp with it).

    -InputImage / reference-image GOTCHA
    ------------------------------------
    Passing -InputImage anchors Gemini HARD to that image's COMPOSITION and
    camera angle. It is great for reskin/recolor ("same pose, arctic colors")
    but it will NOT rotate the subject -- asking a side-view reference for a
    "top-down" result just returns the side view again. To change the view
    angle, generate COLD (no -InputImage) and describe the angle + detail in
    the text prompt instead.

    PROJECT PERSPECTIVE CONVENTIONS:
      - Overworld / ship / river-view subjects: TOP-DOWN.
      - Dive subjects (Scripts/Dive*.cs): SIDE / vertical-scrolling.
      State the view angle explicitly in the prompt.

.EXAMPLE
    # Text -> image (generate). Verify it, THEN animate with PixelLab.
    ./generate_gemini.ps1 -Name "river_turtle_td" `
        -Prompt "river turtle swimming, pixel art, top-down view, plain white background, no shadows"

.EXAMPLE
    # Edit / reskin an existing sprite (Gemini's best use).
    ./generate_gemini.ps1 -Name "river_turtle_arctic" -InputImage "river_turtle_base.png" `
        -Prompt "recolor this turtle for an arctic theme: pale icy shell, frost on the back, same pose, pixel art, plain white background, no shadows"

.NOTES
    After generating, this script does NOT auto-remove the background (Gemini
    output needs the white-key path). To get a game-ready transparent sprite:
        ./remove_white_bg.ps1 <see that script's params>
    and crop to the subject if there is empty margin.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Name,

    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Prompt,

    # Optional: path to an image to EDIT (relative to cwd or ../Sprites).
    # When set, Gemini edits this image instead of generating from scratch.
    [string] $InputImage,

    # Where to save. Default ../Sprites. Use a temp dir for throwaway test runs.
    [string] $OutDir,

    # Model id. gemini-2.5-flash-image is the current image model.
    [string] $Model = 'gemini-2.5-flash-image',

    # Optional: output aspect ratio, e.g. "16:9", "21:9", "4:3". Default is
    # square (~1024x1024) if omitted. Use a wide ratio for battle backgrounds.
    [string] $AspectRatio
)

$ErrorActionPreference = 'Stop'

$ApiKey = $env:GEMINI_API_KEY
if (-not $ApiKey) {
    $KeyFile = Join-Path $PSScriptRoot 'gemini_key.txt'
    if (Test-Path $KeyFile) { $ApiKey = (Get-Content $KeyFile -Raw).Trim() }
}
if (-not $ApiKey) {
    Write-Error "No API key. Put it in dev/gemini_key.txt or set `$env:GEMINI_API_KEY. Get one at https://aistudio.google.com/"
    exit 1
}

if (-not $Name.ToLower().EndsWith('.png')) { $Name += '.png' }
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\Sprites' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutPath = Join-Path $OutDir $Name

# Build request parts: text, plus optional inline image for editing.
$parts = @( @{ text = $Prompt } )
if ($InputImage) {
    $InPath = if (Test-Path $InputImage) { $InputImage } else { Join-Path (Join-Path $PSScriptRoot '..\Sprites') $InputImage }
    if (-not (Test-Path $InPath)) { Write-Error "Input image not found: $InPath"; exit 1 }
    $ext = ([IO.Path]::GetExtension($InPath)).TrimStart('.').ToLower()
    $mime = switch ($ext) { 'jpg' { 'image/jpeg' } 'jpeg' { 'image/jpeg' } default { 'image/png' } }
    $inB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($InPath))
    $parts += @{ inline_data = @{ mime_type = $mime; data = $inB64 } }
    Write-Host "Editing base image: $InPath"
}

$bodyHash = @{ contents = @( @{ parts = $parts } ) }
if ($AspectRatio) {
    $bodyHash.generationConfig = @{ imageConfig = @{ aspectRatio = $AspectRatio } }
}
$body = $bodyHash | ConvertTo-Json -Depth 8
$uri  = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:generateContent"

Write-Host "Gemini ($Model): $Prompt"
try {
    $resp = Invoke-RestMethod -Method Post -Uri $uri `
        -Headers @{ 'x-goog-api-key' = $ApiKey } `
        -ContentType 'application/json' `
        -Body $body -TimeoutSec 180
}
catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    exit 1
}

# Find the first inline image part in the first candidate. Responses use
# camelCase (inlineData.data). Surface any text parts (often a refusal/why).
$imgB64 = $null
$textOut = @()
foreach ($p in $resp.candidates[0].content.parts) {
    if ($p.inlineData -and $p.inlineData.data) { $imgB64 = $p.inlineData.data; break }
    if ($p.inline_data -and $p.inline_data.data) { $imgB64 = $p.inline_data.data; break }
    if ($p.text) { $textOut += $p.text }
}

if (-not $imgB64) {
    Write-Host "No image in response."
    if ($textOut.Count) { Write-Host ("Model said: " + ($textOut -join ' ')) }
    if ($resp.promptFeedback) { $resp.promptFeedback | ConvertTo-Json -Depth 6 }
    exit 1
}

[IO.File]::WriteAllBytes($OutPath, [Convert]::FromBase64String($imgB64))
Write-Host "Saved: $OutPath"
Write-Host "Next: verify the image, crop to the subject, then remove_white_bg.ps1 (and animate with PixelLab if it needs frames)."
