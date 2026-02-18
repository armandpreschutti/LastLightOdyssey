"""
Generate a dedicated pixel art icon for STORY SIGNAL nodes.
Features a signal pillar with radiating waves in tech cyan and story purple.
"""

from PIL import Image, ImageDraw
import math
import os

def generate_story_signal_icon():
    """Generate a 64x64 pixel art story signal icon."""
    size = 64
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x, center_y = size // 2, size // 2
    
    # Colors
    cyan_bright = (0, 255, 255, 255)       # Base cyan
    purple_story = (242, 115, 255, 255)    # Story purple (matching COLOR_STORY approx)
    cyan_dark = (0, 150, 150, 255)         # Darker cyan for outlines
    white_highlight = (255, 255, 255, 255) # Pure white for highlights
    
    # 1. Draw the central pillar (antenna)
    # Base of the antenna
    draw.rectangle([center_x - 6, 50, center_x + 6, 54], fill=cyan_dark)
    draw.rectangle([center_x - 4, 46, center_x + 4, 50], fill=cyan_bright)
    
    # Vertical mast
    draw.rectangle([center_x - 2, 28, center_x + 2, 46], fill=cyan_bright)
    # Highlight on mast
    draw.line([center_x - 1, 30, center_x - 1, 44], fill=white_highlight)
    
    # Tip of the antenna (the broadcaster)
    draw.rectangle([center_x - 4, 24, center_x + 4, 30], fill=purple_story)
    draw.point([(center_x, 22), (center_x-1, 23), (center_x+1, 23)], fill=white_highlight)

    # 2. Draw radiating signal waves (concentric arcs)
    # Using 3 arcs of increasing size
    arc_data = [
        {"radius": 12, "width": 3, "alpha_mult": 1.0},
        {"radius": 20, "width": 2, "alpha_mult": 0.7},
        {"radius": 28, "width": 2, "alpha_mult": 0.4}
    ]
    
    for arc in arc_data:
        r = arc["radius"]
        w = arc["width"]
        alpha = int(255 * arc["alpha_mult"])
        color = (purple_story[0], purple_story[1], purple_story[2], alpha)
        
        # Draw arcs in the upper hemisphere
        # Bounding box for the full circle
        bbox = [center_x - r, 24 - r, center_x + r, 24 + r]
        
        # Pillow's arc uses degrees: 0 is 3 o'clock, clockwise.
        # We want top arcs: from 210 to 330 degrees (approx)
        draw.arc(bbox, start=200, end=340, fill=color, width=w)

    # 3. Add some "bits" or "interference" for tech look
    bits = [
        (center_x - 15, 40), (center_x + 15, 35),
        (center_x - 22, 25), (center_x + 22, 20)
    ]
    for bx, by in bits:
        draw.point([(bx, by)], fill=(0, 255, 255, 128))

    return img

if __name__ == "__main__":
    # Ensure directory exists
    output_dir = "assets/sprites/navigation"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    # Generate the icon
    icon = generate_story_signal_icon()
    
    # Save the icon
    output_path = os.path.join(output_dir, "story_signal.png")
    icon.save(output_path)
    print(f"STORY SIGNAL icon saved to: {output_path}")
    print(f"Size: {icon.size}, Mode: {icon.mode}")
