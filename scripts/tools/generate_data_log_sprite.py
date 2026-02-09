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
# Bright cyan/blue colors for high visibility against dark floor tiles
base_color = (77, 179, 255, 255)      # Bright cyan-blue base
accent_color = (102, 230, 255, 255)  # Bright cyan accent
highlight_color = (179, 242, 255, 255) # Light cyan highlight
data_color = (153, 230, 255, 255)    # Bright cyan data indicator
tech_accent = (204, 255, 255, 255)   # Very bright cyan glow
shadow_color = (38, 77, 128, 255)    # Dark blue shadow
glow_color = (230, 255, 255, 255)    # Bright white-cyan glow

# Draw base device body (rectangular, horizontal) - brighter and more visible
draw.rectangle([6, 12, 25, 20], fill=base_color)

# Draw top section (screen/display area) - bright cyan
draw.rectangle([7, 13, 24, 17], fill=accent_color)

# Draw data display lines (horizontal lines representing data) - bright cyan
for y in range(14, 17, 1):
    draw.line([8, y, 23, y], fill=data_color, width=1)

# Draw side connectors/ports - bright cyan-blue
draw.rectangle([4, 14, 6, 18], fill=base_color)
draw.rectangle([25, 14, 27, 18], fill=base_color)

# Draw glowing indicator lights - very bright
draw.ellipse([8, 14, 11, 17], fill=tech_accent)
draw.ellipse([20, 14, 23, 17], fill=tech_accent)
# Add glow effect around indicators
draw.ellipse([7, 13, 12, 18], outline=glow_color, width=1)
draw.ellipse([19, 13, 24, 18], outline=glow_color, width=1)

# Draw bottom section (base)
draw.rectangle([7, 17, 24, 19], fill=base_color)

# Add bright highlights for depth and visibility
draw.line([6, 12, 25, 12], fill=highlight_color, width=1)
draw.line([7, 12, 7, 20], fill=highlight_color, width=1)
draw.line([24, 12, 24, 20], fill=highlight_color, width=1)
draw.line([6, 20, 25, 20], fill=shadow_color, width=1)

# Add bright corner details
draw.point([6, 12], fill=glow_color)
draw.point([25, 12], fill=glow_color)
draw.point([6, 20], fill=shadow_color)
draw.point([25, 20], fill=shadow_color)

# Add subtle glow outline for extra visibility
draw.rectangle([5, 11, 26, 21], outline=accent_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "data_log.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Data log sprite generated at: {output_path}")
