#!/usr/bin/env python3
"""
Generate pixel art icons for Last Light Odyssey UI
Icons are 24x24 pixels with retro sci-fi aesthetic
"""

from PIL import Image, ImageDraw
import os

# Output directory
OUTPUT_DIR = "../assets/sprites/ui/icons"

# Color palette (matching game aesthetic)
COLORS = {
    'transparent': (0, 0, 0, 0),
    'cyan': (102, 230, 255, 255),        # Primary cyan
    'cyan_dark': (51, 153, 204, 255),    # Darker cyan
    'cyan_light': (179, 242, 255, 255),  # Lighter cyan
    'amber': (255, 176, 0, 255),         # Amber/orange
    'amber_dark': (204, 128, 0, 255),    # Darker amber
    'amber_light': (255, 217, 102, 255), # Lighter amber
    'red': (255, 77, 77, 255),           # Red for damage
    'red_dark': (179, 51, 51, 255),      # Darker red
    'green': (51, 255, 128, 255),        # Green for health
    'green_dark': (26, 179, 77, 255),    # Darker green
    'white': (230, 242, 255, 255),       # Off-white
    'gray': (128, 153, 179, 255),        # Gray
    'dark': (26, 38, 51, 255),           # Dark background
}

def create_icon(size=24):
    """Create a new transparent icon canvas"""
    return Image.new('RGBA', (size, size), COLORS['transparent'])

def draw_colonists_icon():
    """Person/group silhouette icon for colonists"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Main person (center)
    # Head
    draw.ellipse([10, 3, 14, 7], fill=COLORS['cyan'])
    # Body
    draw.rectangle([9, 8, 15, 16], fill=COLORS['cyan'])
    # Legs
    draw.rectangle([9, 16, 11, 21], fill=COLORS['cyan_dark'])
    draw.rectangle([13, 16, 15, 21], fill=COLORS['cyan_dark'])
    
    # Left person (smaller, background)
    draw.ellipse([3, 6, 6, 9], fill=COLORS['cyan_dark'])
    draw.rectangle([3, 10, 6, 15], fill=COLORS['cyan_dark'])
    draw.rectangle([3, 15, 4, 19], fill=COLORS['gray'])
    draw.rectangle([5, 15, 6, 19], fill=COLORS['gray'])
    
    # Right person (smaller, background)
    draw.ellipse([18, 6, 21, 9], fill=COLORS['cyan_dark'])
    draw.rectangle([18, 10, 21, 15], fill=COLORS['cyan_dark'])
    draw.rectangle([18, 15, 19, 19], fill=COLORS['gray'])
    draw.rectangle([20, 15, 21, 19], fill=COLORS['gray'])
    
    return img

def draw_fuel_icon():
    """Fuel cell/energy symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Battery/fuel cell shape
    # Main body
    draw.rectangle([6, 5, 18, 20], fill=COLORS['amber_dark'])
    draw.rectangle([7, 6, 17, 19], fill=COLORS['dark'])
    
    # Top terminal
    draw.rectangle([9, 2, 15, 5], fill=COLORS['amber'])
    
    # Energy bars inside
    draw.rectangle([8, 8, 16, 10], fill=COLORS['amber'])
    draw.rectangle([8, 12, 16, 14], fill=COLORS['amber'])
    draw.rectangle([8, 16, 16, 18], fill=COLORS['amber_light'])
    
    # Highlight
    draw.line([6, 5, 6, 20], fill=COLORS['amber_light'])
    
    return img

def draw_hull_icon():
    """Shield/ship hull symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Shield shape
    points = [
        (12, 2),   # Top
        (20, 6),   # Top right
        (20, 14),  # Right
        (12, 22),  # Bottom
        (4, 14),   # Left
        (4, 6),    # Top left
    ]
    draw.polygon(points, fill=COLORS['cyan_dark'])
    
    # Inner shield
    inner_points = [
        (12, 5),
        (17, 8),
        (17, 13),
        (12, 19),
        (7, 13),
        (7, 8),
    ]
    draw.polygon(inner_points, fill=COLORS['dark'])
    
    # Center emblem (ship silhouette)
    draw.polygon([(12, 7), (15, 14), (12, 12), (9, 14)], fill=COLORS['cyan'])
    
    # Highlight
    draw.line([(4, 6), (12, 2), (20, 6)], fill=COLORS['cyan_light'])
    
    return img

def draw_scrap_icon():
    """Metal/junk pile symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Gear/cog shape
    # Outer teeth
    draw.rectangle([10, 2, 14, 5], fill=COLORS['amber'])
    draw.rectangle([10, 19, 14, 22], fill=COLORS['amber'])
    draw.rectangle([2, 10, 5, 14], fill=COLORS['amber'])
    draw.rectangle([19, 10, 22, 14], fill=COLORS['amber'])
    
    # Diagonal teeth
    draw.polygon([(4, 4), (7, 4), (4, 7)], fill=COLORS['amber_dark'])
    draw.polygon([(17, 4), (20, 4), (20, 7)], fill=COLORS['amber_dark'])
    draw.polygon([(4, 17), (4, 20), (7, 20)], fill=COLORS['amber_dark'])
    draw.polygon([(17, 20), (20, 20), (20, 17)], fill=COLORS['amber_dark'])
    
    # Center circle
    draw.ellipse([5, 5, 19, 19], fill=COLORS['amber'])
    draw.ellipse([8, 8, 16, 16], fill=COLORS['dark'])
    draw.ellipse([10, 10, 14, 14], fill=COLORS['amber_dark'])
    
    return img

def draw_cryo_icon():
    """Cryo pod/temperature symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Snowflake/cryo pattern
    # Center
    draw.rectangle([11, 11, 13, 13], fill=COLORS['cyan_light'])
    
    # Main cross
    draw.rectangle([11, 3, 13, 21], fill=COLORS['cyan'])
    draw.rectangle([3, 11, 21, 13], fill=COLORS['cyan'])
    
    # Diagonal lines
    draw.line([(5, 5), (19, 19)], fill=COLORS['cyan_dark'], width=2)
    draw.line([(5, 19), (19, 5)], fill=COLORS['cyan_dark'], width=2)
    
    # Branch tips
    draw.rectangle([10, 2, 14, 4], fill=COLORS['cyan_light'])
    draw.rectangle([10, 20, 14, 22], fill=COLORS['cyan_light'])
    draw.rectangle([2, 10, 4, 14], fill=COLORS['cyan_light'])
    draw.rectangle([20, 10, 22, 14], fill=COLORS['cyan_light'])
    
    return img

def draw_health_icon():
    """Cross/medical symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Red cross
    draw.rectangle([9, 3, 15, 21], fill=COLORS['green'])
    draw.rectangle([3, 9, 21, 15], fill=COLORS['green'])
    
    # Inner highlight
    draw.rectangle([10, 4, 14, 20], fill=COLORS['green_dark'])
    draw.rectangle([4, 10, 20, 14], fill=COLORS['green_dark'])
    
    # Center
    draw.rectangle([10, 10, 14, 14], fill=COLORS['green'])
    
    # Highlight
    draw.line([(9, 3), (9, 21)], fill=COLORS['white'])
    draw.line([(3, 9), (21, 9)], fill=COLORS['white'])
    
    return img

def draw_action_points_icon():
    """Lightning bolt/energy symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Lightning bolt
    points = [
        (14, 1),   # Top
        (8, 10),   # Left indent
        (12, 10),  # Inner left
        (6, 23),   # Bottom
        (16, 12),  # Right indent
        (12, 12),  # Inner right
    ]
    draw.polygon(points, fill=COLORS['amber'])
    
    # Highlight
    highlight = [
        (13, 3),
        (9, 10),
        (11, 10),
        (8, 18),
    ]
    draw.line(highlight, fill=COLORS['amber_light'], width=1)
    
    return img

def draw_turn_icon():
    """Clock/time symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Outer circle
    draw.ellipse([2, 2, 22, 22], fill=COLORS['cyan'])
    draw.ellipse([4, 4, 20, 20], fill=COLORS['dark'])
    
    # Clock face markers
    draw.rectangle([11, 5, 13, 7], fill=COLORS['cyan_light'])  # 12
    draw.rectangle([11, 17, 13, 19], fill=COLORS['cyan_dark'])  # 6
    draw.rectangle([5, 11, 7, 13], fill=COLORS['cyan_dark'])   # 9
    draw.rectangle([17, 11, 19, 13], fill=COLORS['cyan_dark']) # 3
    
    # Clock hands
    draw.line([(12, 12), (12, 7)], fill=COLORS['cyan_light'], width=2)  # Hour
    draw.line([(12, 12), (17, 12)], fill=COLORS['cyan'], width=1)  # Minute
    
    # Center dot
    draw.ellipse([10, 10, 14, 14], fill=COLORS['cyan_light'])
    
    return img

def draw_enemies_icon():
    """Skull/hostile symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Skull shape
    draw.ellipse([4, 3, 20, 17], fill=COLORS['red'])
    draw.ellipse([6, 5, 18, 15], fill=COLORS['dark'])
    
    # Eyes
    draw.ellipse([7, 7, 11, 11], fill=COLORS['red'])
    draw.ellipse([13, 7, 17, 11], fill=COLORS['red'])
    
    # Nose
    draw.polygon([(12, 11), (10, 14), (14, 14)], fill=COLORS['red_dark'])
    
    # Jaw
    draw.rectangle([7, 15, 17, 21], fill=COLORS['red'])
    draw.rectangle([8, 16, 16, 20], fill=COLORS['dark'])
    
    # Teeth
    draw.rectangle([9, 16, 11, 19], fill=COLORS['red_dark'])
    draw.rectangle([13, 16, 15, 19], fill=COLORS['red_dark'])
    
    return img

def draw_display_icon():
    """Monitor/display symbol for settings"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Monitor frame
    draw.rectangle([3, 3, 21, 17], fill=COLORS['cyan'])
    draw.rectangle([5, 5, 19, 15], fill=COLORS['dark'])
    
    # Screen content (lines)
    draw.line([(6, 7), (18, 7)], fill=COLORS['cyan_dark'])
    draw.line([(6, 10), (14, 10)], fill=COLORS['cyan_dark'])
    draw.line([(6, 13), (16, 13)], fill=COLORS['cyan_dark'])
    
    # Stand
    draw.rectangle([10, 17, 14, 19], fill=COLORS['cyan_dark'])
    draw.rectangle([7, 19, 17, 21], fill=COLORS['cyan'])
    
    return img

def draw_audio_icon():
    """Speaker/audio symbol for settings"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Speaker body
    draw.rectangle([3, 8, 8, 16], fill=COLORS['amber'])
    draw.polygon([(8, 8), (14, 4), (14, 20), (8, 16)], fill=COLORS['amber'])
    
    # Sound waves
    draw.arc([14, 6, 18, 18], 300, 60, fill=COLORS['amber_light'], width=2)
    draw.arc([17, 4, 23, 20], 300, 60, fill=COLORS['amber_dark'], width=2)
    
    return img

def draw_tutorial_icon():
    """Question mark/help symbol"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Circle background
    draw.ellipse([3, 3, 21, 21], fill=COLORS['amber'])
    draw.ellipse([5, 5, 19, 19], fill=COLORS['dark'])
    
    # Question mark
    draw.arc([8, 6, 16, 14], 180, 0, fill=COLORS['amber_light'], width=3)
    draw.rectangle([11, 11, 13, 15], fill=COLORS['amber_light'])
    
    # Dot
    draw.ellipse([10, 17, 14, 21], fill=COLORS['amber_light'])
    
    return img

def draw_movement_icon():
    """Movement/footsteps icon"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Arrow pointing right
    draw.polygon([(4, 12), (14, 12), (14, 7), (22, 12), (14, 17), (14, 12)], fill=COLORS['cyan'])
    draw.polygon([(4, 10), (12, 10), (12, 8), (18, 12), (12, 16), (12, 14), (4, 14)], fill=COLORS['cyan_dark'])
    
    return img

def draw_attack_icon():
    """Crosshair/attack icon"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Outer circle
    draw.ellipse([3, 3, 21, 21], fill=COLORS['red'])
    draw.ellipse([5, 5, 19, 19], fill=COLORS['dark'])
    
    # Crosshair lines
    draw.rectangle([11, 3, 13, 9], fill=COLORS['red'])
    draw.rectangle([11, 15, 13, 21], fill=COLORS['red'])
    draw.rectangle([3, 11, 9, 13], fill=COLORS['red'])
    draw.rectangle([15, 11, 21, 13], fill=COLORS['red'])
    
    # Center dot
    draw.ellipse([10, 10, 14, 14], fill=COLORS['red'])
    
    return img

def draw_cover_icon():
    """Shield/cover bonus icon"""
    img = create_icon()
    draw = ImageDraw.Draw(img)
    
    # Wall/cover shape
    draw.rectangle([4, 6, 8, 20], fill=COLORS['cyan'])
    draw.rectangle([5, 7, 7, 19], fill=COLORS['cyan_dark'])
    
    # Person behind cover
    draw.ellipse([12, 4, 18, 10], fill=COLORS['cyan_light'])
    draw.rectangle([12, 10, 18, 18], fill=COLORS['cyan_light'])
    
    # Plus sign for bonus
    draw.rectangle([18, 12, 22, 14], fill=COLORS['green'])
    draw.rectangle([19, 10, 21, 16], fill=COLORS['green'])
    
    return img

def main():
    # Ensure output directory exists
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)
    
    # Generate all icons
    icons = {
        'icon_colonists.png': draw_colonists_icon(),
        'icon_fuel.png': draw_fuel_icon(),
        'icon_hull.png': draw_hull_icon(),
        'icon_scrap.png': draw_scrap_icon(),
        'icon_cryo.png': draw_cryo_icon(),
        'icon_health.png': draw_health_icon(),
        'icon_ap.png': draw_action_points_icon(),
        'icon_turn.png': draw_turn_icon(),
        'icon_enemies.png': draw_enemies_icon(),
        'icon_display.png': draw_display_icon(),
        'icon_audio.png': draw_audio_icon(),
        'icon_tutorial.png': draw_tutorial_icon(),
        'icon_movement.png': draw_movement_icon(),
        'icon_attack.png': draw_attack_icon(),
        'icon_cover.png': draw_cover_icon(),
    }
    
    for filename, img in icons.items():
        filepath = os.path.join(output_path, filename)
        img.save(filepath)
        print(f"Created: {filepath}")
    
    print(f"\nGenerated {len(icons)} icons in {output_path}")

if __name__ == "__main__":
    main()
