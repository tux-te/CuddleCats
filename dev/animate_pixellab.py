"""
Caller for PixelLab's "Pro" animate endpoint, POST /v2/animate-with-text-v2
("Animate with text (pro)" in PixelLab's API spec). Takes a single reference
image + a text description of the action and returns an animation frame set.

Usage:
    python3 dev/animate_pixellab.py <base_image.png> <output_folder_name> "<action>" [frames] [size]

Example:
    python3 dev/animate_pixellab.py Sprites/kiwi_cutout.png kiwi_bell_toy \
        "playing with a small bell toy, batting it with a paw" 5 196

Saves frames as Sprites/<output_folder_name>/frame_00.png .. frame_NN.png,
matching this project's existing animation-folder convention (see
Sprites/kiwi_walk, Sprites/sheila_walk, etc.). Runs remove_white_bg.py
automatically on each saved frame as a safety net (a no-op if the frame is
already fully transparent, since no_background=true is always passed).

Note: the [frames] arg is NOT sent to the API — this endpoint decides frame
count itself based on the action description, it isn't configurable. The
arg is accepted for logging/expectation-setting only.

API key: reads dev/pixellab_key.txt (one line, no quotes). Get one at
https://www.pixellab.ai/account
"""
import base64
import io
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "Sprites"


def load_api_key() -> str:
    key_file = ROOT / "dev" / "pixellab_key.txt"
    if not key_file.exists():
        print(f"ERROR: {key_file} not found. Put your PixelLab API key there "
              f"(one line, no quotes). Get one at https://www.pixellab.ai/account")
        sys.exit(1)
    key = key_file.read_text().strip()
    if not key:
        print(f"ERROR: {key_file} is empty.")
        sys.exit(1)
    return key


def letterbox(path: Path, size: int) -> str:
    img = Image.open(path).convert("RGBA")
    iw, ih = img.size
    fit = min(size / iw, size / ih)
    dw, dh = int(iw * fit), int(ih * fit)
    dx, dy = (size - dw) // 2, (size - dh) // 2
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img.resize((dw, dh), Image.NEAREST), (dx, dy))
    buf = io.BytesIO()
    canvas.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def main() -> None:
    if len(sys.argv) < 4:
        print('Usage: python3 dev/animate_pixellab.py <base.png> <out_folder> "<action>" [frames] [size]')
        sys.exit(1)
    base_name, out_folder, action = sys.argv[1], sys.argv[2], sys.argv[3]
    frames = int(sys.argv[4]) if len(sys.argv) > 4 else 4
    size = int(sys.argv[5]) if len(sys.argv) > 5 else 196

    base_path = Path(base_name) if Path(base_name).exists() else SPRITES / base_name
    if not base_path.exists():
        print(f"Base image not found: {base_path}")
        sys.exit(1)

    api_key = load_api_key()
    b64 = letterbox(base_path, size)

    payload = {
        "reference_image": {"base64": "data:image/png;base64," + b64},
        "reference_image_size": {"width": size, "height": size},
        "action": action,
        "image_size": {"width": size, "height": size},
        "no_background": True,
        "view": "none",
        "direction": "none",
    }
    req = urllib.request.Request(
        "https://api.pixellab.ai/v2/animate-with-text-v2",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    print(f"Submitting '{out_folder}' ({size}x{size}, frames={frames}, action={action!r})...")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            result = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:2000])
        sys.exit(1)

    job_id = result.get("background_job_id")
    if not job_id:
        print("No background_job_id in response:", result)
        sys.exit(1)
    print(f"Job: {job_id}")

    job = None
    for i in range(120):
        time.sleep(5)
        poll_req = urllib.request.Request(
            f"https://api.pixellab.ai/v2/background-jobs/{job_id}",
            headers={"Authorization": f"Bearer {api_key}"},
        )
        try:
            with urllib.request.urlopen(poll_req, timeout=60) as resp:
                job = json.loads(resp.read().decode())
        except urllib.error.URLError as e:
            print(f"  [{i*5}s] poll error: {e} — retrying")
            continue
        status = job.get("status")
        print(f"  [{i*5}s] status={status}")
        if status in ("completed", "failed", "error", "cancelled"):
            break

    if not job or job.get("status") != "completed":
        print("Job did not complete:", job)
        sys.exit(1)

    images = job["last_response"]["images"]
    print(f"Got {len(images)} frames")
    out_dir = SPRITES / out_folder
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, img in enumerate(images):
        b64_out = img["base64"]
        if b64_out.startswith("data:"):
            b64_out = b64_out.split(",", 1)[1]
        out_path = out_dir / f"frame_{i:02d}.png"
        out_path.write_bytes(base64.b64decode(b64_out))
        subprocess.run(
            [sys.executable, str(ROOT / "dev" / "remove_white_bg.py"), str(out_path)],
            check=False,
        )
        print(f"Saved {out_path}")


if __name__ == "__main__":
    main()
