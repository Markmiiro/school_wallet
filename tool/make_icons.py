#!/usr/bin/env python3
"""Makes the web app icons from the reversed Nuvora mark.

    python3 tool/make_icons.py

Navy ground with assets/brand/nuvora-mark-reversed.svg, as the launch spec
sets it. Full-colour on navy is misuse, so the primary file is never used.
Rendered by headless Chrome straight from the vector, so the gradients are
the mark's own; Pillow only rewrites the result as plain 8-bit RGBA.

  rounded tiles  favicon 32, Icon-192, Icon-512: the mark at 62% of the
                 tile, corner radius from the spec (112 at 512)
  full bleed     apple-touch-icon 180 (iOS rounds it), and the maskable
                 192 and 512, where the mark is 50% wide so it stays inside
                 the 80% circle Android's launcher mask keeps
"""
import pathlib
import re
import shutil
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
NAVY = "#102B5C"

# path, size, corner radius (0 = full bleed), mark width as a share of size
ICONS = [
    ("web/favicon.png", 32, 7, 0.62),
    ("web/icons/Icon-192.png", 192, 42, 0.62),
    ("web/icons/Icon-512.png", 512, 112, 0.62),
    ("web/icons/apple-touch-icon.png", 180, 0, 0.62),
    ("web/icons/Icon-maskable-192.png", 192, 0, 0.50),
    ("web/icons/Icon-maskable-512.png", 512, 0, 0.50),
]


def chrome():
    for name in ("google-chrome", "chromium", "chromium-browser"):
        if shutil.which(name):
            return name
    raise SystemExit("needs Chrome or Chromium on PATH")


def main():
    svg = (ROOT / "assets/brand/nuvora-mark-reversed.svg").read_text()
    svg = re.sub(r'\s(width|height)="[^"]*"', "", svg, count=2)
    svg = svg.replace("<svg ", '<svg style="display:block;width:100%;height:auto" ', 1)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        for rel, size, radius, share in ICONS:
            page = tmp / "icon.html"
            page.write_text(
                "<!doctype html><html><body style='margin:0;background:transparent'>"
                f"<div style='width:{size}px;height:{size}px;background:{NAVY};"
                f"border-radius:{radius}px;display:flex;align-items:center;"
                f"justify-content:center'>"
                f"<div style='width:{size * share}px'>{svg}</div>"
                "</div></body></html>")
            shot = tmp / "shot.png"
            subprocess.run(
                [chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
                 "--force-device-scale-factor=1", "--default-background-color=00000000",
                 f"--window-size={size},{size}", f"--screenshot={shot}",
                 page.as_uri()],
                check=True, capture_output=True)
            img = Image.open(shot).convert("RGBA").crop((0, 0, size, size))
            if not radius:
                # full bleed: no transparency anywhere
                ground = Image.new("RGBA", img.size, NAVY)
                img = Image.alpha_composite(ground, img)
            img.save(ROOT / rel, optimize=True)
            print(f"{rel}  {size}x{size}")


if __name__ == "__main__":
    main()
