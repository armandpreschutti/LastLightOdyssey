#!/usr/bin/env python3
"""
Generate beacon sprite for Last Light Odyssey
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

# Color palette - Planet theme (beacon/communication)
base_color = (64, 51, 77, 255)      # Dark purple-gray
accent_color = (102, 77, 128, 255)  # Medium purple
beacon_color = (255, 179, 102, 255) # Orange beacon light
glow_color = (255, 230, 153, 255)  # Yellow glow
active_color = (255, 128, 77, 255) # Orange active indicator
shadow_color = (38, 26, 51, 255)   # Dark shadow

# Draw base platform (bottom, wider)
draw.rectangle([5, 26, 26, 30], fill=base_color)

# Draw main beacon body (tall, tapering)
draw.polygon([(15, 6), (10, 20), (20, 20)], fill=accent_color)

# Draw beacon light/emitter (top, circular)
draw.ellipse([12, 4, 18, 10], fill=beacon_color)
draw.ellipse([13, 5, 17, 9], fill=glow_color)

# Draw light beam (radiating upward)
draw.polygon([(13, 4), (15, 2), (17, 4)], fill=glow_color)

# Draw body details (horizontal bands)
draw.line([10, 14, 20, 14], fill=base_color, width=1)
draw.line([10, 17, 20, 17], fill=base_color, width=1)

# Draw side supports/legs
draw.rectangle([7, 22, 10, 26], fill=base_color)
draw.rectangle([21, 22, 24, 26], fill=base_color)

# Draw indicator lights (when active)
draw.point([12, 15], fill=active_color)
draw.point([18, 15], fill=active_color)

# Add highlights for depth
draw.line([10, 20, 20, 20], fill=glow_color, width=1)
draw.line([5, 26, 26, 26], fill=glow_color, width=1)

# Add glow effect around beacon
draw.ellipse([11, 3, 19, 11], outline=glow_color, width=1)

# Add shadow to base
draw.line([6, 30, 25, 30], fill=shadow_color, width=1)

# Save the image
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))
output_path = os.path.join(project_root, "assets", "sprites", "objects", "beacon.png")

# Ensure directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

img.save(output_path)
print(f"Beacon sprite generated at: {output_path}")
