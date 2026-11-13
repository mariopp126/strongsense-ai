#!/usr/bin/env python3
"""Generate the StrongSense AI launcher icon assets.

The source images are committed; run this only when the brand mark changes.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SLATE = (15, 23, 42, 255)
EMERALD = (16, 185, 129, 255)
EMERALD_DARK = (5, 150, 105, 255)


def draw_dumbbell(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    scale: float,
    color: tuple[int, int, int, int],
) -> None:
    unit = SIZE * scale

    bar_w = unit * 0.72
    bar_h = unit * 0.075
    draw.rounded_rectangle(
        (cx - bar_w / 2, cy - bar_h / 2, cx + bar_w / 2, cy + bar_h / 2),
        radius=bar_h / 2,
        fill=color,
    )

    for sign in (-1, 1):
        inner_x = cx + sign * unit * 0.30
        inner_w = unit * 0.105
        inner_h = unit * 0.46
        draw.rounded_rectangle(
            (
                inner_x - inner_w / 2,
                cy - inner_h / 2,
                inner_x + inner_w / 2,
                cy + inner_h / 2,
            ),
            radius=inner_w / 2,
            fill=color,
        )

        outer_x = cx + sign * unit * 0.42
        outer_w = unit * 0.075
        outer_h = unit * 0.30
        draw.rounded_rectangle(
            (
                outer_x - outer_w / 2,
                cy - outer_h / 2,
                outer_x + outer_w / 2,
                cy + outer_h / 2,
            ),
            radius=outer_w / 2,
            fill=color,
        )


def build_icon(path: Path, *, background: bool, scale: float) -> None:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    if background:
        draw.rounded_rectangle(
            (0, 0, SIZE - 1, SIZE - 1),
            radius=int(SIZE * 0.22),
            fill=SLATE,
        )
        # Subtle emerald ring behind the dumbbell.
        ring = int(SIZE * 0.30)
        draw.ellipse(
            (
                SIZE / 2 - ring,
                SIZE / 2 - ring,
                SIZE / 2 + ring,
                SIZE / 2 + ring,
            ),
            outline=(16, 185, 129, 38),
            width=int(SIZE * 0.018),
        )

    draw_dumbbell(draw, SIZE / 2, SIZE / 2, scale, EMERALD)
    image.save(path)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    assets = root / "apps" / "strongsense" / "assets" / "icon"
    assets.mkdir(parents=True, exist_ok=True)

    build_icon(assets / "icon.png", background=True, scale=0.62)
    build_icon(assets / "icon_foreground.png", background=False, scale=0.42)

    # A small preview for the README.
    preview = root / "docs" / "screenshots" / "icon.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    Image.open(assets / "icon.png").resize((256, 256)).save(preview)

    print(f"Wrote icons to {assets}")


if __name__ == "__main__":
    main()
