#!/usr/bin/env python3
"""
Generate mining equipment sprite for Last Light Odyssey
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

# Color palette
base_color = (77, 77, 89, 255)        # Dark gray/steel
accent_color = (128, 128, 153, 255)   # Medium gray
highlight_color = (179, 179, 204, 255) # Light gray
drill_color = (102, 89, 77, 255)      # Brownish drill bit
tech_accent = (51, 204, 255, 255)     # Cyan tech accent
shadow_color = (26, 26, 38, 255)      # Dark shadow

# Draw base platform (bottom, wider)
draw.rectangle([6, 22, 25, 27], fill=base_color)

# Draw main body (center column)
draw.rectangle([12, 10, 19, 21], fill=accent_color)

# Draw drill bit assembly
# Drill housing
draw.rectangle([13, 6, 18, 9], fill=accent_color)
# Drill bit
draw.rectangle([14, 4, 17, 7], fill=drill_color)
# Drill tip
draw.rectangle([15, 2, 16, 3], fill=drill_color)

# Draw side supports/legs
draw.rectangle([8, 14, 11, 21], fill=base_color)
draw.rectangle([20, 14, 23, 21], fill=base_color)

# Add highlights for depth
draw.line([12, 10, 19, 10], fill=highlight_color, width=1)
draw.line([6, 22, 25, 22], fill=highlight_color, width=1)

# Add control panel/details (tech indicators)
draw.point([9, 16], fill=tech_accent)
draw.point([22, 16], fill=tech_accent)
draw.point([10, 17], fill=tech_accent)
draw.point([21, 17], fill=tech_accent)

# Add cyan accent lines on drill housing
for x in range(13, 19):
    if x % 2 == 0:
        draw.point([x, 7], fill=tech_accent)

# Add shadow to base
draw.line([7, 27, 24, 27], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "mining_equipment.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Mining equipment sprite generated at: {output_path}")
