#!/usr/bin/env python3
"""
Generate security terminal sprite for Last Light Odyssey
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

# Color palette - Station theme (cyan/blue tech)
base_color = (51, 77, 102, 255)        # Dark blue-gray
accent_color = (77, 128, 179, 255)    # Medium blue
highlight_color = (128, 179, 230, 255) # Light blue
screen_color = (51, 204, 255, 255)   # Cyan screen
tech_accent = (77, 230, 255, 255)     # Bright cyan
shadow_color = (26, 38, 51, 255)      # Dark shadow

# Draw base platform (bottom, wider)
draw.rectangle([4, 24, 27, 30], fill=base_color)

# Draw main terminal body (tall, rectangular)
draw.rectangle([10, 8, 21, 23], fill=accent_color)

# Draw screen area (top portion of terminal)
draw.rectangle([11, 9, 20, 16], fill=screen_color)

# Draw screen frame/border
draw.rectangle([10, 8, 21, 17], outline=highlight_color, width=1)

# Draw control panel (bottom portion)
draw.rectangle([11, 17, 20, 22], fill=base_color)

# Draw buttons/controls
draw.rectangle([12, 18, 14, 20], fill=tech_accent)
draw.rectangle([17, 18, 19, 20], fill=tech_accent)

# Draw side supports/legs
draw.rectangle([6, 22, 9, 24], fill=base_color)
draw.rectangle([22, 22, 25, 24], fill=base_color)

# Add highlights for depth
draw.line([10, 8, 21, 8], fill=highlight_color, width=1)
draw.line([4, 24, 27, 24], fill=highlight_color, width=1)

# Add screen glow effect (pixels on screen)
draw.point([13, 11], fill=tech_accent)
draw.point([15, 11], fill=tech_accent)
draw.point([17, 11], fill=tech_accent)
draw.point([14, 13], fill=tech_accent)
draw.point([16, 13], fill=tech_accent)

# Add shadow to base
draw.line([5, 30, 26, 30], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "security_terminal.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Security terminal sprite generated at: {output_path}")
