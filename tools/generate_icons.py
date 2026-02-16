from PIL import Image, ImageDraw

def create_pixel_icon(name, color, shape="rect"):
    # 32x32 icon
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Simple retro pixel art style
    if shape == "circle":
        draw.ellipse([4, 4, 27, 27], fill=color, outline=(255, 255, 255, 128), width=2)
        # Inner glow
        draw.ellipse([10, 10, 21, 21], fill=(255, 255, 255, 100))
    elif shape == "diamond":
        draw.polygon([(16, 4), (28, 16), (16, 28), (4, 16)], fill=color, outline=(255, 255, 255, 128), width=2)
        # Inner glow
        draw.polygon([(16, 10), (22, 16), (16, 22), (10, 16)], fill=(255, 255, 255, 100))
    else: # Square/Chip
        draw.rectangle([6, 6, 25, 25], fill=color, outline=(255, 255, 255, 128), width=2)
        # Decorative dots
        draw.point([(8,8), (23,8), (8,23), (23,23)], fill=(255, 255, 255, 200))
    
    img.save(f"C:/Users/arman/Documents/Godot/Projects/Last Light Odyssey/assets/sprites/ui/icons/{name}.png")
    print(f"Generated {name}.png")

# Cash: Yellow/Gold Chip
create_pixel_icon("icon_cash", (255, 200, 0, 255), "rect")
# Intel: Cyan Signal Pulse
create_pixel_icon("icon_intel", (0, 220, 255, 255), "diamond")
# Data Logs: Amber/Orange Wave/Log
create_pixel_icon("icon_data_logs", (255, 120, 0, 255), "circle")
