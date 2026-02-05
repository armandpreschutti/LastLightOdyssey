#!/usr/bin/env python3
"""
Generate human-like officer sprites for Last Light Odyssey
Style: Pokemon/RPG-style chibi pixel art
Perspective: 3/4 front-facing view with large head, visible body and legs
"""

from PIL import Image, ImageDraw
import os

# Output directory
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "characters")

# Sprite size
SIZE = 32

# Common colors
OUTLINE = (40, 40, 50)
SKIN_LIGHT = (255, 220, 185)
SKIN_MID = (240, 195, 160)
SKIN_SHADOW = (210, 165, 135)
WHITE = (255, 255, 255)
BLACK = (20, 20, 30)
EYE_WHITE = (255, 255, 255)
EYE_PUPIL = (40, 40, 60)


def create_base_image():
    """Create a transparent 32x32 image."""
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def draw_base_body(draw, colors, has_pants=True):
    """Draw the common humanoid body structure."""
    cx = 16  # Center x
    
    # === LEGS (bottom) ===
    # Left leg
    draw.rectangle((10, 27, 13, 31), fill=colors["pants"] if has_pants else colors["primary"])
    draw.rectangle((10, 27, 10, 31), fill=OUTLINE)  # Left edge
    draw.rectangle((10, 31, 13, 31), fill=OUTLINE)  # Bottom
    # Left foot/shoe
    draw.rectangle((9, 29, 13, 31), fill=colors["shoes"])
    draw.rectangle((9, 31, 13, 31), fill=OUTLINE)
    
    # Right leg  
    draw.rectangle((18, 27, 21, 31), fill=colors["pants"] if has_pants else colors["primary"])
    draw.rectangle((21, 27, 21, 31), fill=OUTLINE)  # Right edge
    draw.rectangle((18, 31, 21, 31), fill=OUTLINE)  # Bottom
    # Right foot/shoe
    draw.rectangle((18, 29, 22, 31), fill=colors["shoes"])
    draw.rectangle((18, 31, 22, 31), fill=OUTLINE)
    
    # === TORSO ===
    # Main body
    draw.rectangle((9, 18, 22, 27), fill=colors["primary"])
    # Body outline
    draw.rectangle((8, 18, 8, 27), fill=OUTLINE)  # Left
    draw.rectangle((23, 18, 23, 27), fill=OUTLINE)  # Right
    
    # Shirt/uniform details
    draw.rectangle((13, 19, 18, 26), fill=colors["secondary"])
    
    # === ARMS ===
    # Left arm
    draw.rectangle((5, 19, 8, 26), fill=colors["primary"])
    draw.rectangle((4, 19, 4, 26), fill=OUTLINE)
    draw.rectangle((5, 26, 8, 26), fill=OUTLINE)
    # Left hand
    draw.rectangle((5, 24, 7, 26), fill=SKIN_MID)
    
    # Right arm
    draw.rectangle((23, 19, 26, 26), fill=colors["primary"])
    draw.rectangle((27, 19, 27, 26), fill=OUTLINE)
    draw.rectangle((23, 26, 26, 26), fill=OUTLINE)
    # Right hand
    draw.rectangle((24, 24, 26, 26), fill=SKIN_MID)


def draw_base_head(draw, hair_color, hair_style="short"):
    """Draw the head with face and hair."""
    cx = 16
    
    # === HEAD/FACE ===
    # Face base (oval-ish)
    draw.ellipse((9, 4, 22, 18), fill=SKIN_LIGHT)
    # Face shadow (lower part)
    draw.ellipse((10, 12, 21, 17), fill=SKIN_MID)
    # Head outline
    draw.arc((8, 3, 23, 18), 0, 360, fill=OUTLINE, width=1)
    
    # === EYES ===
    # Left eye
    draw.rectangle((11, 9, 13, 12), fill=EYE_WHITE)
    draw.rectangle((12, 10, 13, 12), fill=EYE_PUPIL)
    draw.point((12, 10), fill=WHITE)  # Shine
    
    # Right eye
    draw.rectangle((18, 9, 20, 12), fill=EYE_WHITE)
    draw.rectangle((18, 10, 19, 12), fill=EYE_PUPIL)
    draw.point((19, 10), fill=WHITE)  # Shine
    
    # === HAIR ===
    if hair_style == "short":
        # Short spiky hair
        draw.ellipse((8, 2, 23, 10), fill=hair_color)
        # Hair outline
        draw.arc((7, 1, 24, 10), 180, 360, fill=OUTLINE, width=1)
        # Spiky bits
        draw.polygon([(10, 3), (12, 0), (14, 4)], fill=hair_color)
        draw.polygon([(14, 2), (16, -1), (18, 3)], fill=hair_color)
        draw.polygon([(17, 3), (20, 0), (21, 4)], fill=hair_color)
        
    elif hair_style == "military":
        # Short military cut
        draw.ellipse((8, 2, 23, 9), fill=hair_color)
        draw.arc((7, 1, 24, 9), 180, 360, fill=OUTLINE, width=1)
        # Flat top
        draw.rectangle((10, 2, 21, 5), fill=hair_color)
        
    elif hair_style == "ponytail":
        # Hair with ponytail
        draw.ellipse((8, 2, 23, 10), fill=hair_color)
        draw.arc((7, 1, 24, 10), 180, 360, fill=OUTLINE, width=1)
        # Side hair
        draw.rectangle((7, 8, 9, 14), fill=hair_color)
        draw.rectangle((22, 8, 24, 14), fill=hair_color)
        # Ponytail (back, visible on side)
        draw.ellipse((20, 4, 26, 12), fill=hair_color)
        
    elif hair_style == "bun":
        # Neat bun style
        draw.ellipse((8, 2, 23, 10), fill=hair_color)
        draw.arc((7, 1, 24, 10), 180, 360, fill=OUTLINE, width=1)
        # Bun on top
        draw.ellipse((12, 0, 19, 5), fill=hair_color)
        draw.arc((12, 0, 19, 5), 0, 360, fill=OUTLINE, width=1)


def generate_captain():
    """Generate captain sprite - commanding officer with cap."""
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (200, 170, 50),      # Gold uniform
        "secondary": (170, 140, 30),    # Darker gold
        "pants": (60, 60, 70),          # Dark pants
        "shoes": (50, 40, 35),          # Brown shoes
        "accent": (255, 215, 0),        # Bright gold
    }
    hair_color = (60, 45, 30)  # Dark brown
    
    # Draw body first
    draw_base_body(draw, colors)
    
    # Draw head
    draw_base_head(draw, hair_color, "military")
    
    # === CAPTAIN'S CAP ===
    # Cap base
    draw.rectangle((7, 2, 24, 6), fill=colors["primary"])
    draw.rectangle((6, 2, 6, 6), fill=OUTLINE)
    draw.rectangle((25, 2, 25, 6), fill=OUTLINE)
    # Cap visor/brim
    draw.rectangle((6, 6, 25, 8), fill=(40, 40, 45))
    draw.rectangle((5, 7, 26, 8), fill=OUTLINE)
    # Cap emblem
    draw.rectangle((14, 3, 17, 5), fill=colors["accent"])
    
    # === RANK INSIGNIA ===
    # Shoulder epaulettes
    draw.rectangle((5, 18, 8, 20), fill=colors["accent"])
    draw.rectangle((23, 18, 26, 20), fill=colors["accent"])
    
    # Chest medals/badge
    draw.rectangle((10, 21, 12, 23), fill=colors["accent"])
    draw.point((11, 22), fill=WHITE)
    
    # Belt
    draw.rectangle((9, 25, 22, 26), fill=(80, 70, 50))
    draw.rectangle((14, 25, 17, 26), fill=colors["accent"])  # Belt buckle
    
    return img


def generate_scout():
    """Generate scout sprite - agile recon specialist."""
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (60, 100, 60),       # Forest green
        "secondary": (45, 80, 45),      # Darker green
        "pants": (50, 75, 50),          # Green pants
        "shoes": (45, 40, 35),          # Dark boots
        "accent": (150, 200, 150),      # Light green
    }
    hair_color = (100, 70, 45)  # Auburn/brown
    
    # Draw body
    draw_base_body(draw, colors)
    
    # Draw head with short spiky hair
    draw_base_head(draw, hair_color, "short")
    
    # === TACTICAL GOGGLES ===
    # Goggles on forehead
    draw.rectangle((9, 5, 22, 8), fill=(60, 60, 65))
    draw.rectangle((10, 6, 14, 7), fill=(100, 180, 220))  # Left lens
    draw.rectangle((17, 6, 21, 7), fill=(100, 180, 220))  # Right lens
    draw.point((11, 6), fill=WHITE)  # Lens shine
    draw.point((18, 6), fill=WHITE)
    
    # === TACTICAL VEST ===
    # Vest over uniform
    draw.rectangle((10, 19, 21, 26), fill=(70, 85, 70))
    # Pouches
    draw.rectangle((10, 22, 13, 25), fill=(55, 70, 55))
    draw.rectangle((18, 22, 21, 25), fill=(55, 70, 55))
    
    # Collar high
    draw.rectangle((11, 17, 20, 19), fill=colors["primary"])
    
    # === EQUIPMENT ===
    # Antenna/radio on back (visible on side)
    draw.line((24, 12, 26, 6), fill=(50, 50, 55), width=1)
    draw.point((26, 6), fill=(255, 80, 80))  # Red light
    
    return img


def generate_tech():
    """Generate tech sprite - engineer with tools."""
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (50, 140, 150),      # Teal/cyan
        "secondary": (35, 110, 120),    # Darker teal
        "pants": (50, 50, 60),          # Dark work pants
        "shoes": (60, 55, 50),          # Work boots
        "accent": (100, 220, 230),      # Bright cyan
    }
    hair_color = (45, 45, 55)  # Dark gray/black
    
    # Draw body (slightly bulkier)
    draw_base_body(draw, colors)
    
    # Draw head
    draw_base_head(draw, hair_color, "short")
    
    # === TECH VISOR/GLASSES ===
    # Safety glasses
    draw.rectangle((9, 9, 22, 11), fill=(200, 200, 210))
    draw.rectangle((10, 9, 13, 11), fill=(180, 220, 255))  # Left lens
    draw.rectangle((18, 9, 21, 11), fill=(180, 220, 255))  # Right lens
    
    # === UTILITY SUIT ===
    # Chest panel/display
    draw.rectangle((12, 20, 19, 24), fill=(40, 45, 50))
    draw.rectangle((13, 21, 18, 23), fill=(30, 35, 40))
    # Display lights
    draw.point((14, 22), fill=colors["accent"])
    draw.point((16, 22), fill=(100, 255, 100))
    draw.point((17, 21), fill=(255, 200, 100))
    
    # Tool belt
    draw.rectangle((8, 25, 23, 27), fill=(80, 70, 55))
    # Tools on belt
    draw.rectangle((9, 24, 11, 26), fill=(150, 150, 160))  # Wrench
    draw.rectangle((20, 24, 22, 27), fill=(180, 180, 60))  # Tool
    
    # === BACKPACK ===
    # Tech backpack (visible behind shoulders)
    draw.rectangle((6, 17, 8, 24), fill=colors["secondary"])
    draw.rectangle((23, 17, 25, 24), fill=colors["secondary"])
    
    return img


def generate_medic():
    """Generate medic sprite - field medic with cross."""
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (180, 60, 140),      # Magenta/purple
        "secondary": (150, 40, 115),    # Darker magenta
        "pants": (140, 50, 110),        # Matching pants
        "shoes": (80, 70, 75),          # Gray boots
        "accent": (255, 255, 255),      # White (for cross)
    }
    hair_color = (160, 130, 100)  # Light brown/blonde
    
    # Draw body
    draw_base_body(draw, colors)
    
    # Draw head with ponytail
    draw_base_head(draw, hair_color, "ponytail")
    
    # === MEDICAL CROSS ===
    # Cross on chest (prominent)
    draw.rectangle((14, 20, 17, 25), fill=WHITE)  # Vertical
    draw.rectangle((12, 21, 19, 24), fill=WHITE)  # Horizontal
    # Cross outline
    draw.rectangle((14, 20, 14, 25), fill=(220, 220, 220))
    draw.rectangle((12, 22, 19, 22), fill=(220, 220, 220))
    
    # === MEDICAL HEADBAND ===
    draw.rectangle((8, 7, 23, 8), fill=WHITE)
    # Small cross on headband
    draw.point((15, 7), fill=(255, 50, 50))
    draw.point((16, 7), fill=(255, 50, 50))
    
    # === MED KIT ===
    # Bag on hip
    draw.rectangle((22, 22, 27, 27), fill=WHITE)
    draw.rectangle((22, 22, 27, 22), fill=OUTLINE)
    draw.rectangle((27, 22, 27, 27), fill=OUTLINE)
    draw.rectangle((22, 27, 27, 27), fill=OUTLINE)
    # Cross on bag
    draw.rectangle((24, 23, 25, 26), fill=(255, 50, 50))
    draw.rectangle((23, 24, 26, 25), fill=(255, 50, 50))
    
    # Arm patch
    draw.rectangle((5, 20, 7, 22), fill=WHITE)
    draw.point((6, 21), fill=(255, 50, 50))
    
    return img


def generate_heavy():
    """Generate heavy sprite - armored tank with shield."""
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (180, 90, 50),       # Orange-red armor
        "secondary": (150, 70, 40),     # Darker orange
        "pants": (70, 65, 60),          # Dark gray pants
        "shoes": (50, 45, 40),          # Dark boots
        "accent": (255, 150, 50),       # Bright orange
        "metal": (140, 140, 150),       # Metal gray
        "dark_metal": (90, 90, 100),    # Dark metal
    }
    hair_color = (50, 40, 35)  # Dark brown/black
    
    # Draw body (bulkier version)
    draw_base_body(draw, colors)
    
    # Draw head with military cut
    draw_base_head(draw, hair_color, "military")
    
    # === HEAVY ARMOR PLATING ===
    # Shoulder pauldrons (large, armored)
    draw.rectangle((3, 17, 8, 22), fill=colors["metal"])
    draw.rectangle((2, 17, 2, 22), fill=OUTLINE)
    draw.rectangle((3, 17, 8, 17), fill=OUTLINE)
    draw.rectangle((3, 17, 8, 18), fill=(180, 180, 190))  # Highlight
    
    draw.rectangle((23, 17, 28, 22), fill=colors["metal"])
    draw.rectangle((29, 17, 29, 22), fill=OUTLINE)
    draw.rectangle((23, 17, 28, 17), fill=OUTLINE)
    draw.rectangle((23, 17, 28, 18), fill=(180, 180, 190))  # Highlight
    
    # Chest plate (extra armor layer)
    draw.rectangle((10, 19, 21, 26), fill=colors["primary"])
    draw.rectangle((11, 20, 20, 25), fill=colors["secondary"])
    # Armor rivets
    draw.point((12, 21), fill=colors["metal"])
    draw.point((19, 21), fill=colors["metal"])
    draw.point((12, 24), fill=colors["metal"])
    draw.point((19, 24), fill=colors["metal"])
    
    # Central armor emblem (shield icon)
    draw.rectangle((14, 21, 17, 24), fill=colors["accent"])
    draw.polygon([(14, 24), (15, 25), (16, 25), (17, 24)], fill=colors["accent"])
    draw.point((15, 22), fill=WHITE)  # Emblem highlight
    
    # === HEAVY HELMET ===
    # Armored helmet
    draw.rectangle((7, 2, 24, 8), fill=colors["metal"])
    draw.rectangle((6, 2, 6, 8), fill=OUTLINE)
    draw.rectangle((25, 2, 25, 8), fill=OUTLINE)
    draw.rectangle((7, 1, 24, 2), fill=OUTLINE)
    # Visor
    draw.rectangle((9, 5, 22, 7), fill=(40, 40, 50))
    draw.rectangle((10, 5, 21, 6), fill=(80, 60, 50))  # Tinted visor
    draw.line((10, 5, 21, 5), fill=(120, 100, 80))  # Visor reflection
    # Helmet details
    draw.rectangle((14, 2, 17, 4), fill=colors["accent"])  # Top stripe
    
    # === ARM ARMOR ===
    # Armored gauntlets
    draw.rectangle((4, 23, 8, 27), fill=colors["dark_metal"])
    draw.rectangle((23, 23, 27, 27), fill=colors["dark_metal"])
    
    # === LEG ARMOR ===
    # Knee pads
    draw.rectangle((9, 26, 13, 28), fill=colors["metal"])
    draw.rectangle((18, 26, 22, 28), fill=colors["metal"])
    
    # Heavy belt with equipment
    draw.rectangle((8, 25, 23, 26), fill=colors["dark_metal"])
    draw.rectangle((13, 24, 18, 26), fill=colors["metal"])  # Belt buckle
    draw.point((15, 25), fill=colors["accent"])  # Buckle detail
    
    return img


def main():
    """Generate all officer sprites."""
    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    sprites = {
        "officer_captain.png": generate_captain,
        "officer_scout.png": generate_scout,
        "officer_tech.png": generate_tech,
        "officer_medic.png": generate_medic,
        "officer_heavy.png": generate_heavy,
    }
    
    for filename, generator in sprites.items():
        filepath = os.path.join(OUTPUT_DIR, filename)
        img = generator()
        img.save(filepath, "PNG")
        print(f"Generated: {filepath}")
    
    print("\nAll officer sprites generated successfully!")
    print(f"Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
