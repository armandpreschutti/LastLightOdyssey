#!/usr/bin/env python3
"""
Generate scrap pile sprite for Last Light Odyssey
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

# Color palette - Bright amber/orange/gold for high visibility
base_color = (255, 176, 0, 255)       # Amber/orange base
accent_color = (255, 217, 102, 255)  # Gold accent
highlight_color = (255, 230, 153, 255) # Light amber highlight
metallic_color = (255, 242, 179, 255)  # Bright metallic highlight
shadow_color = (204, 128, 0, 255)     # Dark amber shadow
dark_shadow = (153, 96, 0, 255)       # Very dark shadow

# Draw scrap pile base (irregular pile shape)
# Main pile body (larger pieces at bottom)
draw.polygon([(8, 24), (12, 20), (20, 20), (24, 24), (22, 26), (10, 26)], fill=base_color)

# Top scrap pieces (smaller pieces on top)
draw.polygon([(10, 20), (14, 16), (18, 16), (22, 20), (20, 22), (12, 22)], fill=accent_color)

# Additional scrap piece on left
draw.polygon([(6, 22), (9, 19), (11, 19), (8, 22)], fill=base_color)

# Additional scrap piece on right
draw.polygon([(21, 22), (24, 19), (26, 19), (23, 22)], fill=accent_color)

# Small top piece
draw.polygon([(13, 16), (16, 13), (19, 16), (16, 18)], fill=highlight_color)

# Draw metallic edges and highlights (make it look like metal)
# Top edge highlights
draw.line([10, 20, 22, 20], fill=metallic_color, width=1)
draw.line([13, 16, 19, 16], fill=metallic_color, width=1)
draw.line([14, 16, 18, 16], fill=highlight_color, width=1)

# Side edge highlights
draw.line([12, 20, 12, 22], fill=metallic_color, width=1)
draw.line([20, 20, 20, 22], fill=metallic_color, width=1)
draw.line([8, 24, 10, 26], fill=metallic_color, width=1)
draw.line([22, 24, 24, 26], fill=metallic_color, width=1)

# Left piece highlight
draw.line([9, 19, 11, 19], fill=metallic_color, width=1)
draw.line([6, 22, 8, 22], fill=metallic_color, width=1)

# Right piece highlight
draw.line([24, 19, 26, 19], fill=metallic_color, width=1)
draw.line([21, 22, 23, 22], fill=metallic_color, width=1)

# Draw shadows for depth
draw.line([10, 26, 22, 26], fill=shadow_color, width=1)
draw.line([12, 22, 20, 22], fill=shadow_color, width=1)
draw.line([8, 24, 10, 26], fill=dark_shadow, width=1)
draw.line([22, 24, 24, 26], fill=dark_shadow, width=1)

# Add corner highlights for metallic shine
draw.point([12, 20], fill=metallic_color)
draw.point([20, 20], fill=metallic_color)
draw.point([14, 16], fill=highlight_color)
draw.point([18, 16], fill=highlight_color)

# Add some small detail lines (scratches/edges on metal)
draw.line([11, 21, 13, 21], fill=shadow_color, width=1)
draw.line([19, 21, 21, 21], fill=shadow_color, width=1)
draw.line([15, 17, 17, 17], fill=shadow_color, width=1)

# Add subtle glow outline for extra visibility
draw.ellipse([7, 18, 25, 28], outline=accent_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "scrap_pile.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Scrap pile sprite generated at: {output_path}")
