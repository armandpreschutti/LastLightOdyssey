#!/usr/bin/env python3
"""
Generate placeholder portrait PNGs for Last Light Odyssey.
Requires Pillow: pip install pillow

Run from project root:
    python3 tools/generate_portraits.py
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUTPUT_BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "portraits")
SIZE = 2048

# --- Accent colours per unit type ---
TYPE_COLORS = {
    "basic":   (110, 140, 180),   # grey-blue
    "heavy":   (200, 90,  50),    # red-orange
    "sniper":  (60,  180, 150),   # green-teal
    "elite":   (160, 80,  210),   # purple
    "boss":    (210, 170, 40),    # gold
    "sniper_officer": (140, 210, 230),  # silver-cyan
}

# --- Biome tint colours (applied at 20 % opacity) ---
BIOME_TINTS = {
    "station":  (80,  120, 180),  # cool blue-grey
    "asteroid": (160, 100, 50),   # warm brown-orange
    "planet":   (80,  160, 80),   # green-amber
}

# --- Silhouette regions per type (as fraction of 2048) ---
# Each entry is a list of (x, y) polygon points (0-1 range)
def _scale_poly(pts, s=SIZE):
    return [(int(x * s), int(y * s)) for x, y in pts]

SILHOUETTE_SHAPES = {
    "basic": [
        (0.35, 0.20), (0.65, 0.20),   # head top
        (0.68, 0.35), (0.65, 0.50),   # shoulders
        (0.72, 0.75), (0.60, 0.90),   # right leg
        (0.40, 0.90), (0.28, 0.75),   # left leg
        (0.35, 0.50), (0.32, 0.35),   # left shoulder
    ],
    "heavy": [
        (0.30, 0.18), (0.70, 0.18),
        (0.80, 0.40), (0.76, 0.60),
        (0.72, 0.90), (0.55, 0.90),
        (0.45, 0.90), (0.28, 0.90),
        (0.24, 0.60), (0.20, 0.40),
    ],
    "sniper": [
        (0.40, 0.12), (0.60, 0.12),
        (0.62, 0.30), (0.60, 0.55),
        (0.65, 0.80), (0.56, 0.92),
        (0.44, 0.92), (0.35, 0.80),
        (0.40, 0.55), (0.38, 0.30),
    ],
    "elite": [
        (0.33, 0.16), (0.67, 0.16),
        (0.74, 0.36), (0.72, 0.58),
        (0.70, 0.88), (0.56, 0.92),
        (0.44, 0.92), (0.30, 0.88),
        (0.28, 0.58), (0.26, 0.36),
    ],
    "boss": [
        (0.25, 0.14), (0.75, 0.14),
        (0.85, 0.38), (0.82, 0.62),
        (0.78, 0.92), (0.58, 0.95),
        (0.42, 0.95), (0.22, 0.92),
        (0.18, 0.62), (0.15, 0.38),
    ],
    "sniper_officer": [
        (0.38, 0.14), (0.62, 0.14),
        (0.64, 0.32), (0.62, 0.54),
        (0.66, 0.78), (0.57, 0.92),
        (0.43, 0.92), (0.34, 0.78),
        (0.38, 0.54), (0.36, 0.32),
    ],
}


def _draw_radial_bg(draw: ImageDraw.ImageDraw, accent: tuple):
    """Dark radial gradient background."""
    cx, cy = SIZE // 2, SIZE // 2
    max_r = math.sqrt(cx**2 + cy**2)
    for r in range(int(max_r), 0, -4):
        t = r / max_r                      # 1 = edge, 0 = centre
        dark = int(18 + (1 - t) * 30)     # 18–48
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(dark, dark, dark + 8),
        )


def _draw_silhouette(draw: ImageDraw.ImageDraw, unit_type: str, accent: tuple):
    pts = _scale_poly(SILHOUETTE_SHAPES.get(unit_type, SILHOUETTE_SHAPES["basic"]))
    # Dark body fill
    r, g, b = accent
    fill_col = (max(0, r - 60), max(0, g - 60), max(0, b - 60))
    draw.polygon(pts, fill=fill_col, outline=accent)


def _draw_border(draw: ImageDraw.ImageDraw, accent: tuple, thickness: int = 24):
    for i in range(thickness, 0, -1):
        a = int(255 * (i / thickness))
        draw.rectangle([i, i, SIZE - i, SIZE - i], outline=(*accent, a))


def _apply_biome_tint(img: Image.Image, biome: str) -> Image.Image:
    tint_rgb = BIOME_TINTS.get(biome, (128, 128, 128))
    tint_layer = Image.new("RGBA", img.size, (*tint_rgb, 51))  # 20 % opacity
    img = img.convert("RGBA")
    img.alpha_composite(tint_layer)
    return img


def _draw_label(draw: ImageDraw.ImageDraw, unit_type: str, biome: str):
    text = f"{unit_type.upper()}\n{biome.upper()}"
    # Semi-transparent box
    box_x1, box_y1 = SIZE - 520, SIZE - 220
    box_x2, box_y2 = SIZE - 20, SIZE - 20
    draw.rectangle([box_x1, box_y1, box_x2, box_y2], fill=(0, 0, 0, 160))

    # Draw text lines
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 72)
    except Exception:
        font = ImageFont.load_default()

    lines = text.split("\n")
    y = box_y1 + 20
    for line in lines:
        draw.text((box_x1 + 20, y), line, fill=(220, 220, 220, 230), font=font)
        y += 90


def generate_portrait(unit_type: str, biome: str, out_path: str):
    img = Image.new("RGBA", (SIZE, SIZE), (20, 20, 28, 255))
    draw = ImageDraw.Draw(img)
    accent = TYPE_COLORS.get(unit_type, (128, 128, 128))

    _draw_radial_bg(draw, accent)
    _draw_silhouette(draw, unit_type, accent)
    _draw_border(draw, accent)
    _draw_label(draw, unit_type, biome)

    img = _apply_biome_tint(img, biome)

    # Slight gaussian blur on bg for soft look (preserve sharp border via composite)
    blurred = img.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.composite(img, blurred, img.split()[3])  # no-op but keeps alpha

    out_dir = os.path.dirname(out_path)
    os.makedirs(out_dir, exist_ok=True)
    img.convert("RGBA").save(out_path)
    print(f"  Wrote {out_path}")


def main():
    base_portraits = os.path.abspath(OUTPUT_BASE)
    enemies_dir = os.path.join(base_portraits, "enemies")

    # --- Enemy portraits: type × biome ---
    enemy_types = ["basic", "heavy", "sniper", "elite", "boss"]
    biomes = ["station", "asteroid", "planet"]

    print("Generating enemy portraits…")
    for etype in enemy_types:
        for biome in biomes:
            fname = f"enemy_{etype}_{biome}.png"
            generate_portrait(etype, biome, os.path.join(enemies_dir, fname))

    # --- Sniper officer portrait ---
    print("Generating sniper officer portrait…")
    generate_portrait(
        "sniper_officer",
        "station",
        os.path.join(base_portraits, "sniper_officer_portrait.png"),
    )

    total = len(enemy_types) * len(biomes) + 1
    print(f"\nDone — {total} portraits generated.")


if __name__ == "__main__":
    main()
