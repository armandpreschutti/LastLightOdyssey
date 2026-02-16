from PIL import Image, ImageDraw

def create_skull():
    # 32x32 white skull icon, pixel art style, transparent background
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    
    # Very simple pixel art skull
    # Main head
    draw.rectangle([8, 4, 23, 18], fill=white)
    # Jaw
    draw.rectangle([11, 19, 20, 24], fill=white)
    
    # Eyes (transparent holes)
    draw.rectangle([10, 8, 13, 12], fill=(0, 0, 0, 0))
    draw.rectangle([18, 8, 21, 12], fill=(0, 0, 0, 0))
    
    # Nose
    draw.point([(15, 14), (16, 14)], fill=(0, 0, 0, 0))
    
    # Teeth gaps
    draw.point([(12, 24), (15, 24), (19, 24)], fill=(0, 0, 0, 0))
    
    img.save('c:/Users/arman/Documents/Godot/Projects/Last Light Odyssey/assets/sprites/navigation/skull_icon.png')
    print("Skull icon generated successfully.")

if __name__ == "__main__":
    create_skull()
