"""
Generate a pixel art question mark sprite for locked navigation nodes.
Matches the style of existing node graphics (64x64, pixel art).
"""

from PIL import Image, ImageDraw
import math

def generate_question_mark_sprite():
    """Generate a 64x64 pixel art question mark sprite."""
    # Create 64x64 RGBA image with transparent background
    size = 64
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Color scheme matching the code
    outline_color = (51, 51, 77, 255)  # Dark gray/blue outline (0.2, 0.2, 0.3)
    fill_color = (128, 128, 153, 255)  # Medium gray fill (0.5, 0.5, 0.6)
    highlight_color = (179, 179, 204, 255)  # Light gray highlight (0.7, 0.7, 0.8)
    
    center_x, center_y = size // 2, size // 2
    
    # Draw top curve of question mark (elliptical shape)
    # Upper arc from top-left to top-right, then down
    for y in range(8, 24):
        for x in range(16, 48):
            dx = (x - center_x) / 16.0
            dy = (y - (center_y - 8)) / 12.0
            dist_sq = dx * dx + dy * dy
            
            # Draw outline (thick border)
            if 0.85 <= dist_sq <= 1.15:
                img.putpixel((x, y), outline_color)
            # Draw fill (inside)
            elif dist_sq < 0.85:
                img.putpixel((x, y), fill_color)
    
    # Draw vertical stem (middle part)
    for y in range(24, 40):
        for x in range(center_x - 3, center_x + 4):
            # Outline
            if x == center_x - 3 or x == center_x + 3:
                img.putpixel((x, y), outline_color)
            # Fill
            else:
                img.putpixel((x, y), fill_color)
    
    # Draw bottom dot
    dot_y = 44
    dot_radius = 5
    for y in range(dot_y - dot_radius, dot_y + dot_radius + 1):
        for x in range(center_x - dot_radius, center_x + dot_radius + 1):
            dx = x - center_x
            dy = y - dot_y
            dist = math.sqrt(dx * dx + dy * dy)
            
            # Outline
            if dot_radius - 1.5 <= dist <= dot_radius + 0.5:
                img.putpixel((x, y), outline_color)
            # Fill
            elif dist < dot_radius - 1.5:
                img.putpixel((x, y), fill_color)
    
    # Add highlight on top-left of curve for 3D effect
    for y in range(10, 18):
        for x in range(18, 28):
            dx = (x - center_x) / 16.0
            dy = (y - (center_y - 8)) / 12.0
            dist_sq = dx * dx + dy * dy
            if 0.3 <= dist_sq <= 0.7:
                img.putpixel((x, y), highlight_color)
    
    return img

if __name__ == "__main__":
    # Generate the sprite
    sprite = generate_question_mark_sprite()
    
    # Save to the navigation assets folder
    output_path = "assets/sprites/navigation/question_mark.png"
    sprite.save(output_path)
    print(f"Question mark sprite saved to: {output_path}")
    print(f"Size: {sprite.size}, Mode: {sprite.mode}")
