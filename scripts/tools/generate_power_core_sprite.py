#!/usr/bin/env python3
"""
Generate power core sprite for Last Light Odyssey
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

# Color palette - Station theme (power/energy)
base_color = (51, 51, 77, 255)       # Dark purple-gray
accent_color = (77, 77, 128, 255)    # Medium purple-blue
core_color = (102, 153, 255, 255)    # Bright blue core
energy_color = (153, 204, 255, 255)  # Light blue energy
glow_color = (77, 230, 255, 255)     # Cyan glow
shadow_color = (26, 26, 38, 255)     # Dark shadow

# Draw base platform (bottom, circular base)
draw.ellipse([8, 24, 23, 28], fill=base_color)

# Draw main core body (cylindrical, vertical)
draw.rectangle([12, 10, 19, 23], fill=accent_color)

# Draw core center (glowing energy core)
draw.ellipse([13, 12, 18, 17], fill=core_color)
draw.ellipse([14, 13, 17, 16], fill=energy_color)

# Draw energy rings/bands around core
draw.ellipse([11, 11, 20, 18], outline=glow_color, width=1)
draw.ellipse([10, 10, 21, 19], outline=glow_color, width=1)

# Draw top cap
draw.ellipse([12, 8, 19, 12], fill=accent_color)

# Draw side connectors/conduits
draw.rectangle([8, 14, 11, 18], fill=base_color)
draw.rectangle([20, 14, 23, 18], fill=base_color)

# Add highlights for depth
draw.line([12, 10, 19, 10], fill=energy_color, width=1)
draw.line([8, 24, 23, 24], fill=energy_color, width=1)

# Add energy particles/sparks
draw.point([10, 15], fill=glow_color)
draw.point([21, 15], fill=glow_color)
draw.point([9, 16], fill=glow_color)
draw.point([22, 16], fill=glow_color)

# Add shadow to base
draw.line([9, 28, 22, 28], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "power_core.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Power core sprite generated at: {output_path}")
