#!/usr/bin/env python3
"""
Generate sample collector sprite for Last Light Odyssey
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

# Color palette - Planet theme (alien/organic)
base_color = (89, 64, 102, 255)      # Dark purple
accent_color = (128, 89, 153, 255)   # Medium purple
sample_color = (204, 153, 255, 255) # Light purple sample
organic_color = (255, 179, 230, 255) # Pink organic
glow_color = (255, 128, 204, 255)   # Pink glow
shadow_color = (51, 38, 64, 255)    # Dark shadow

# Draw base platform (bottom, organic shape)
draw.ellipse([6, 24, 25, 28], fill=base_color)

# Draw main collector body (rounded, organic shape)
draw.ellipse([9, 10, 22, 23], fill=accent_color)

# Draw sample container (center, glowing)
draw.ellipse([12, 13, 19, 20], fill=sample_color)
draw.ellipse([13, 14, 18, 19], fill=organic_color)

# Draw collection tubes/pipes (top)
draw.rectangle([13, 8, 15, 12], fill=base_color)
draw.rectangle([16, 8, 18, 12], fill=base_color)

# Draw side attachments (organic growths)
draw.ellipse([6, 14, 10, 18], fill=accent_color)
draw.ellipse([21, 14, 25, 18], fill=accent_color)

# Add organic details (irregular patterns)
draw.point([10, 15], fill=glow_color)
draw.point([21, 15], fill=glow_color)
draw.point([11, 17], fill=glow_color)
draw.point([20, 17], fill=glow_color)

# Add highlights for depth
draw.line([9, 10, 22, 10], fill=organic_color, width=1)
draw.line([6, 24, 25, 24], fill=organic_color, width=1)

# Add glow effect around sample
draw.ellipse([11, 12, 20, 21], outline=glow_color, width=1)

# Add shadow to base
draw.line([7, 28, 24, 28], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "sample_collector.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Sample collector sprite generated at: {output_path}")
