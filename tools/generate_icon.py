"""
Last Light Odyssey - Application Icon Generator
Creates a pixel art icon matching the game's aesthetic:
- Dark space background
- Stylized ark ship silhouette  
- Glowing engine (orange/amber)
- Stars representing the journey
"""

from PIL import Image, ImageDraw

def create_icon(size):
    """Create the icon at a specific size"""
    # Scale factor for pixel art look
    scale = size // 32
    if scale < 1:
        scale = 1
    
    # Create image with transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Color palette (matching game aesthetic)
    DARK_BG = (18, 20, 28, 255)          # Deep space blue-black
    SHIP_MAIN = (60, 65, 75, 255)        # Dark gray hull
    SHIP_LIGHT = (90, 95, 105, 255)      # Lighter hull accent
    SHIP_DARK = (35, 38, 45, 255)        # Shadow
    ENGINE_GLOW = (255, 140, 50, 255)    # Orange engine glow
    ENGINE_CORE = (255, 200, 100, 255)   # Bright engine center
    ENGINE_OUTER = (200, 80, 30, 200)    # Outer glow
    WINDOW_BLUE = (100, 180, 255, 255)   # Cyan window light
    STAR_BRIGHT = (255, 255, 255, 255)   # Bright stars
    STAR_DIM = (150, 160, 180, 200)      # Dim stars
    
    # Helper to draw scaled pixels
    def pixel(x, y, color):
        x1, y1 = x * scale, y * scale
        x2, y2 = x1 + scale, y1 + scale
        draw.rectangle([x1, y1, x2-1, y2-1], fill=color)
    
    def pixels(coords, color):
        for x, y in coords:
            pixel(x, y, color)
    
    # Background - circular dark space
    center = size // 2
    radius = size // 2 - scale
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], fill=DARK_BG)
    
    # Stars (scattered in background)
    star_positions_bright = [(4, 5), (27, 8), (6, 24), (25, 22), (15, 3), (20, 27)]
    star_positions_dim = [(8, 10), (23, 14), (10, 20), (3, 15), (28, 18), (12, 28), (22, 4)]
    
    for x, y in star_positions_bright:
        pixel(x, y, STAR_BRIGHT)
    for x, y in star_positions_dim:
        pixel(x, y, STAR_DIM)
    
    # Ark Ship - side view silhouette (facing right, engine on left)
    # Main hull body
    hull_main = [
        (10, 14), (11, 14), (12, 14), (13, 14), (14, 14), (15, 14), (16, 14), (17, 14), (18, 14), (19, 14), (20, 14),
        (10, 15), (11, 15), (12, 15), (13, 15), (14, 15), (15, 15), (16, 15), (17, 15), (18, 15), (19, 15), (20, 15), (21, 15),
        (10, 16), (11, 16), (12, 16), (13, 16), (14, 16), (15, 16), (16, 16), (17, 16), (18, 16), (19, 16), (20, 16), (21, 16),
        (10, 17), (11, 17), (12, 17), (13, 17), (14, 17), (15, 17), (16, 17), (17, 17), (18, 17), (19, 17), (20, 17),
    ]
    pixels(hull_main, SHIP_MAIN)
    
    # Hull highlights (top edge)
    hull_highlight = [(11, 13), (12, 13), (13, 13), (14, 13), (15, 13), (16, 13), (17, 13), (18, 13), (19, 13)]
    pixels(hull_highlight, SHIP_LIGHT)
    
    # Hull shadow (bottom)
    hull_shadow = [(11, 18), (12, 18), (13, 18), (14, 18), (15, 18), (16, 18), (17, 18), (18, 18), (19, 18)]
    pixels(hull_shadow, SHIP_DARK)
    
    # Nose of ship (pointed right)
    nose = [(22, 15), (22, 16), (23, 15), (23, 16), (24, 15)]
    pixels(nose, SHIP_LIGHT)
    
    # Windows/viewports (cyan glow)
    windows = [(18, 14), (20, 14), (15, 14), (13, 14)]
    pixels(windows, WINDOW_BLUE)
    
    # Engine section (left side)
    engine_housing = [(8, 14), (9, 14), (8, 15), (9, 15), (8, 16), (9, 16), (8, 17), (9, 17)]
    pixels(engine_housing, SHIP_DARK)
    
    # Engine glow (the "last light")
    engine_outer = [(6, 14), (7, 14), (6, 15), (7, 15), (6, 16), (7, 16), (6, 17), (7, 17), (5, 15), (5, 16)]
    pixels(engine_outer, ENGINE_OUTER)
    
    engine_core = [(7, 15), (7, 16)]
    pixels(engine_core, ENGINE_GLOW)
    
    engine_bright = [(6, 15), (6, 16)]
    pixels(engine_bright, ENGINE_CORE)
    
    # Trailing engine particles (showing movement)
    trail = [(4, 15), (3, 16), (4, 16), (2, 15)]
    for i, (x, y) in enumerate(trail):
        alpha = 150 - i * 40
        pixel(x, y, (255, 140, 50, max(alpha, 50)))
    
    return img


def main():
    # Standard Windows icon sizes
    sizes = [16, 32, 48, 64, 128, 256]
    
    print("Generating Last Light Odyssey application icon...")
    
    # Create icons at each size
    icons = []
    for size in sizes:
        print(f"  Creating {size}x{size} icon...")
        icon = create_icon(size)
        icons.append(icon)
    
    # Save as ICO file (Windows application icon)
    ico_path = "../icon.ico"
    icons[0].save(
        ico_path,
        format='ICO',
        sizes=[(s, s) for s in sizes],
        append_images=icons[1:]
    )
    print(f"Saved: {ico_path}")
    
    # Also save a 256x256 PNG for other uses
    png_path = "../icon_256.png"
    icons[-1].save(png_path, format='PNG')
    print(f"Saved: {png_path}")
    
    # Save 32x32 for quick preview
    preview_path = "../icon_32.png"
    icons[1].save(preview_path, format='PNG')
    print(f"Saved: {preview_path}")
    
    print("\nIcon generation complete!")
    print("\nTo use in Godot export:")
    print("1. In the Export dialog, scroll to 'Application' section")
    print("2. Click the folder icon next to 'Icon'")
    print("3. Select 'icon.ico' from your project root")


if __name__ == "__main__":
    main()
