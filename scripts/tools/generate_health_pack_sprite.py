#!/usr/bin/env python3
"""
Generate health pack sprite for Last Light Odyssey
Creates a 32x32 pixel art sprite matching the game's style
Medical kit/first aid box design
"""

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("PIL/Pillow not installed. Install with: pip install Pillow")
    exit(1)

# Create 32x32 image with transparency
img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Color palette - Medical kit theme
# White/light colors for medical items with red cross symbol
base_color = (255, 255, 255, 255)      # White base
accent_color = (240, 240, 240, 255)   # Light gray accent
highlight_color = (255, 255, 255, 255) # White highlight
cross_color = (255, 50, 50, 255)      # Red cross symbol
shadow_color = (200, 200, 200, 255)   # Gray shadow
outline_color = (50, 50, 50, 255)     # Dark outline
band_color = (220, 220, 220, 255)     # Gray band/strap

# Draw main body (rectangular medical kit box)
# Top section
draw.rectangle([8, 10, 24, 18], fill=base_color, outline=outline_color, width=1)
# Bottom section
draw.rectangle([8, 18, 24, 24], fill=accent_color, outline=outline_color, width=1)

# Draw lid/top section with slight separation
draw.rectangle([9, 10, 23, 12], fill=accent_color)
draw.line([8, 12, 24, 12], fill=outline_color, width=1)

# Draw red cross symbol (medical symbol) - centered on front
# Vertical line
draw.rectangle([14, 14, 18, 20], fill=cross_color)
# Horizontal line
draw.rectangle([12, 16, 20, 18], fill=cross_color)

# Draw side straps/bands (metallic look)
draw.rectangle([6, 13, 8, 21], fill=band_color, outline=outline_color, width=1)
draw.rectangle([24, 13, 26, 21], fill=band_color, outline=outline_color, width=1)

# Add highlights for depth
draw.line([8, 10, 24, 10], fill=highlight_color, width=1)
draw.line([8, 10, 8, 24], fill=highlight_color, width=1)
draw.line([24, 10, 24, 24], fill=highlight_color, width=1)
draw.line([8, 24, 24, 24], fill=shadow_color, width=1)

# Add corner details
draw.point([8, 10], fill=highlight_color)
draw.point([24, 10], fill=highlight_color)
draw.point([8, 24], fill=shadow_color)
draw.point([24, 24], fill=shadow_color)

# Add subtle outline for extra visibility
draw.rectangle([7, 9, 25, 25], outline=outline_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "health_pack.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Health pack sprite generated at: {output_path}")
