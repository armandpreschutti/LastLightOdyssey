import os
from PIL import Image, ImageDraw

def create_ship_icon():
    # Create a 64x64 transparent image
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Define ship shape (Triangle pointing right)
    # Center is 32, 32
    # Tip at 56, 32
    # Back top at 8, 8
    # Back bottom at 8, 56
    # Indent at back: 16, 32
    
    points = [
        (56, 32),  # Tip
        (8, 56),   # Bottom Back
        (16, 32),  # Back Center Indent
        (8, 8),    # Top Back
    ]
    
    # Draw fill
    draw.polygon(points, fill=(255, 255, 255, 255))
    
    # Draw outline (optional, maybe distinct color or just rely on modulation)
    draw.line(points + [points[0]], fill=(200, 200, 200, 255), width=2)
    
    # Engine glow?
    # draw.ellipse((4, 28, 12, 36), fill=(0, 255, 255, 200))

    # Save
    output_dir = r"c:\Users\arman\Documents\Godot\Projects\Last Light Odyssey\assets\sprites\navigation"
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "ship_icon.png")
    img.save(output_path)
    print(f"Created ship icon at {output_path}")

if __name__ == "__main__":
    create_ship_icon()
