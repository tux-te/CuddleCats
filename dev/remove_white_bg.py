"""
Cross-platform white-background stripper (flood-fill from the border).

Use this after generating art that comes back with a flat white/solid
background instead of transparency. Only clears background pixels connected
to the image border, so interior white/dark highlights (eyes, teeth, etc.)
are preserved.

Usage:
    python3 dev/remove_white_bg.py [--dark] Sprites/some_image.png [threshold]

threshold (default 200, or 40 with --dark): a pixel counts as "background"
if R, G, and B are all above (or, with --dark, all below) this value.
"""
import sys
from collections import deque

from PIL import Image


def remove_white_bg(path: str, threshold: int = 200, dark: bool = False) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    visited = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    cleared = 0
    while q:
        x, y = q.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        if visited[y][x]:
            continue
        visited[y][x] = True
        r, g, b, a = px[x, y]
        is_bg = (r < threshold and g < threshold and b < threshold) if dark \
            else (r > threshold and g > threshold and b > threshold)
        if not is_bg:
            continue
        px[x, y] = (r, g, b, 0)
        cleared += 1
        q.append((x - 1, y))
        q.append((x + 1, y))
        q.append((x, y - 1))
        q.append((x, y + 1))
    if dark:
        _keep_largest_piece(img)
    img.save(path)
    print(f"{path}: cleared {cleared} bg pixels ({w}x{h})")


def _keep_largest_piece(img: Image.Image) -> None:
    """Make every opaque pixel outside the largest connected blob transparent."""
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    best: list = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] == 0:
                continue
            comp = []
            q = deque([(sx, sy)])
            seen[sy][sx] = True
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] != 0:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(comp) > len(best):
                for x, y in best:
                    r, g, b, _ = px[x, y]
                    px[x, y] = (r, g, b, 0)
                best = comp
            else:
                for x, y in comp:
                    r, g, b, _ = px[x, y]
                    px[x, y] = (r, g, b, 0)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--dark"]
    dark = "--dark" in sys.argv[1:]
    if not args:
        print("Usage: python3 dev/remove_white_bg.py [--dark] <path.png> [threshold]")
        sys.exit(1)
    thresh = int(args[1]) if len(args) > 1 else (40 if dark else 200)
    remove_white_bg(args[0], thresh, dark)
