#!/usr/bin/env python3
"""
Generate nest sprite for Last Light Odyssey
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

# Color palette - Planet theme (hostile/organic)
base_color = (77, 51, 38, 255)      # Dark brown
accent_color = (128, 89, 64, 255)   # Medium brown
organic_color = (153, 102, 77, 255) # Light brown
hostile_color = (204, 77, 77, 255) # Red hostile indicator
glow_color = (255, 128, 128, 255)  # Red glow
shadow_color = (51, 38, 26, 255)   # Dark shadow

# Draw base nest structure (irregular, organic shape)
# Main body (rounded, lumpy)
draw.ellipse([8, 14, 23, 26], fill=base_color)

# Draw organic growths/spikes (irregular pattern)
draw.ellipse([6, 12, 12, 18], fill=accent_color)
draw.ellipse([19, 12, 25, 18], fill=accent_color)
draw.ellipse([10, 10, 16, 16], fill=accent_color)
draw.ellipse([15, 10, 21, 16], fill=accent_color)

# Draw center opening/hole (dark)
draw.ellipse([12, 16, 19, 22], fill=shadow_color)

# Draw organic tendrils/strands
draw.line([9, 15, 11, 13], fill=organic_color, width=1)
draw.line([20, 15, 22, 13], fill=organic_color, width=1)
draw.line([13, 11, 15, 9], fill=organic_color, width=1)
draw.line([17, 11, 19, 9], fill=organic_color, width=1)

# Draw hostile indicators (red spots/eyes)
draw.point([11, 14], fill=hostile_color)
draw.point([20, 14], fill=hostile_color)
draw.point([13, 12], fill=hostile_color)
draw.point([18, 12], fill=hostile_color)

# Draw base/ground connection
draw.rectangle([7, 24, 24, 28], fill=accent_color)

# Add highlights for depth
draw.line([8, 14, 23, 14], fill=organic_color, width=1)

# Add glow effect around hostile indicators
draw.point([10, 14], fill=glow_color)
draw.point([21, 14], fill=glow_color)

# Add shadow to base
draw.line([8, 28, 23, 28], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "nest.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Nest sprite generated at: {output_path}")
