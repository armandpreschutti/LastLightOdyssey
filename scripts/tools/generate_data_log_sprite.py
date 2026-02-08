#!/usr/bin/env python3
"""
Generate data log sprite for Last Light Odyssey
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

# Color palette - Station theme (data storage device)
base_color = (64, 64, 89, 255)        # Dark gray-blue
accent_color = (102, 128, 153, 255)  # Medium gray-blue
highlight_color = (153, 179, 204, 255) # Light gray-blue
data_color = (77, 204, 255, 255)     # Cyan data indicator
tech_accent = (128, 204, 255, 255)   # Bright cyan
shadow_color = (38, 38, 51, 255)     # Dark shadow

# Draw base device body (rectangular, horizontal)
draw.rectangle([6, 12, 25, 20], fill=base_color)

# Draw top section (screen/display area)
draw.rectangle([7, 13, 24, 17], fill=accent_color)

# Draw data display lines (horizontal lines representing data)
for y in range(14, 17, 1):
    draw.line([8, y, 23, y], fill=data_color, width=1)

# Draw side connectors/ports
draw.rectangle([4, 14, 6, 18], fill=base_color)
draw.rectangle([25, 14, 27, 18], fill=base_color)

# Draw indicator lights
draw.point([9, 15], fill=tech_accent)
draw.point([22, 15], fill=tech_accent)

# Draw bottom section (base)
draw.rectangle([7, 17, 24, 19], fill=base_color)

# Add highlights for depth
draw.line([6, 12, 25, 12], fill=highlight_color, width=1)
draw.line([6, 20, 25, 20], fill=shadow_color, width=1)

# Add corner details
draw.point([6, 12], fill=highlight_color)
draw.point([25, 12], fill=highlight_color)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "data_log.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Data log sprite generated at: {output_path}")
