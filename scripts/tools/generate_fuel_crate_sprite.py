#!/usr/bin/env python3
"""
Generate fuel crate sprite for Last Light Odyssey
Redesigned to match reference images with:
- Yellow/black hazard stripes (power cell aesthetic)
- Glowing green fuel indicators (fuel gauge aesthetic)
- Industrial/technical look
Creates a 32x32 pixel art sprite matching the game's style
"""

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("PIL/Pillow not installed. Install with: pip install Pillow")
    exit(1)

# Create 32x32 image with transparency
img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Color palette - Fuel crate with hazard stripes and glowing green fuel
# Base colors
dark_grey = (60, 60, 70, 255)          # Dark grey base
medium_grey = (90, 90, 100, 255)       # Medium grey
light_grey = (120, 120, 130, 255)      # Light grey highlight
black = (20, 20, 25, 255)              # Black for stripes
yellow = (255, 220, 50, 255)          # Bright yellow for hazard stripes
yellow_dark = (200, 170, 40, 255)     # Darker yellow for depth

# Glowing green fuel colors (matching fuel gauge aesthetic)
fuel_green_bright = (50, 255, 100, 255)    # Bright green glow
fuel_green = (40, 220, 80, 255)            # Main green
fuel_green_dark = (30, 180, 60, 255)       # Dark green
fuel_green_glow = (100, 255, 150, 255)     # Very bright green glow

# Red warning indicator
red_warning = (255, 60, 60, 255)      # Red warning
red_dark = (180, 40, 40, 255)         # Dark red

# Draw main crate body (rectangular, slightly angled for 3/4 view)
# Base rectangle
crate_left = 4
crate_right = 28
crate_top = 8
crate_bottom = 26

# Main body - dark grey
draw.rectangle([crate_left, crate_top, crate_right, crate_bottom], fill=dark_grey)

# Top face (visible in 3/4 view) - lighter grey
draw.polygon([
    (crate_left, crate_top),
    (crate_right - 3, crate_top),
    (crate_right, crate_top + 3),
    (crate_left + 3, crate_top + 3)
], fill=medium_grey)

# Right face (visible in 3/4 view) - darker
draw.polygon([
    (crate_right, crate_top + 3),
    (crate_right, crate_bottom),
    (crate_right - 3, crate_bottom - 3),
    (crate_right - 3, crate_top)
], fill=dark_grey)

# Yellow/black hazard stripes on front face (like power cell reference)
# Diagonal stripes pattern
stripe_y_start = crate_top + 3
stripe_y_end = crate_bottom - 3
stripe_x_start = crate_left + 3
stripe_x_end = crate_right - 3

# Draw diagonal hazard stripes (simplified pixel art style)
# Create diagonal pattern by offsetting based on position
for y in range(stripe_y_start, stripe_y_end):
    for x in range(stripe_x_start, stripe_x_end):
        # Create diagonal stripe pattern
        diagonal_index = (x - stripe_x_start + y - stripe_y_start) % 6
        if diagonal_index < 3:
            draw.point([x, y], fill=yellow)
        else:
            draw.point([x, y], fill=black)

# Glowing green fuel indicator (center, like fuel gauge)
fuel_indicator_x = 16
fuel_indicator_y = 17
fuel_indicator_width = 8
fuel_indicator_height = 4

# Outer glow
draw.ellipse([
    fuel_indicator_x - fuel_indicator_width - 1,
    fuel_indicator_y - fuel_indicator_height - 1,
    fuel_indicator_x + fuel_indicator_width + 1,
    fuel_indicator_y + fuel_indicator_height + 1
], fill=fuel_green_glow)

# Main fuel indicator (glowing green bar, like fuel gauge)
draw.rectangle([
    fuel_indicator_x - fuel_indicator_width,
    fuel_indicator_y - fuel_indicator_height,
    fuel_indicator_x + fuel_indicator_width,
    fuel_indicator_y + fuel_indicator_height
], fill=fuel_green)

# Inner bright core
draw.rectangle([
    fuel_indicator_x - fuel_indicator_width + 1,
    fuel_indicator_y - fuel_indicator_height + 1,
    fuel_indicator_x + fuel_indicator_width - 1,
    fuel_indicator_y + fuel_indicator_height - 1
], fill=fuel_green_bright)

# Add wavy top edge to fuel indicator (like liquid level in fuel gauge)
for x in range(fuel_indicator_x - fuel_indicator_width + 1, fuel_indicator_x + fuel_indicator_width - 1):
    wave_offset = int(0.5 * (x - fuel_indicator_x))
    wave_y = fuel_indicator_y - fuel_indicator_height + 1 + abs(wave_offset % 2)
    draw.point([x, wave_y], fill=fuel_green_glow)

# Red warning indicator at bottom (like fuel gauge reference)
warning_y = crate_bottom - 2
draw.rectangle([
    fuel_indicator_x - 3,
    warning_y,
    fuel_indicator_x + 3,
    warning_y + 1
], fill=red_warning)

# Add highlights and depth
# Top edge highlight
draw.line([crate_left, crate_top, crate_right - 3, crate_top], fill=light_grey, width=1)
draw.line([crate_left, crate_top, crate_left + 3, crate_top + 3], fill=light_grey, width=1)

# Left edge highlight
draw.line([crate_left, crate_top, crate_left, crate_bottom], fill=light_grey, width=1)

# Bottom shadow
draw.line([crate_left, crate_bottom, crate_right, crate_bottom], fill=black, width=1)
draw.line([crate_right, crate_top + 3, crate_right, crate_bottom], fill=black, width=1)

# Corner details
draw.point([crate_left, crate_top], fill=light_grey)
draw.point([crate_right - 3, crate_top], fill=light_grey)
draw.point([crate_left, crate_bottom], fill=black)
draw.point([crate_right, crate_bottom], fill=black)

# Add subtle outline for definition
draw.rectangle([crate_left - 1, crate_top - 1, crate_right + 1, crate_bottom + 1], outline=(40, 40, 50, 200), width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "crate_fuel.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Fuel crate sprite generated at: {output_path}")
