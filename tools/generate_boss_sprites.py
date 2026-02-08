#!/usr/bin/env python3
"""
Generate boss enemy sprites for Last Light Odyssey
- STATION: Massive security mech/defensive unit
- ASTEROID: Giant mining rig/industrial behemoth
- PLANET: Massive alien creature/alpha predator
Style: Pokemon/RPG-style pixel art with 3/4 TOP-DOWN perspective
Size: 64x64 (2x2 tiles) - much larger than regular enemies
"""

from PIL import Image, ImageDraw
import os

# Output directory
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "characters")

# Sprite size - 64x64 for boss enemies (2x2 tiles)
SIZE = 64

# Common colors
OUTLINE = (25, 25, 35)           # Dark outline
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def create_base_image():
    """Create a transparent 64x64 image."""
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def draw_shadow(draw, cx=32, width=24, y=60):
    """Draw ground shadow ellipse for 3/4 top-down grounding (larger for boss)."""
    shadow_color = (0, 0, 0, 80)  # Slightly more opaque for larger unit
    draw.ellipse(
        (cx - width // 2, y - 4, cx + width // 2, y + 2),
        fill=shadow_color
    )


# =============================================================================
# STATION BOSS - Massive Security Mech
# =============================================================================

def generate_station_boss():
    """
    Station Boss - Massive defensive security mech
    Large armored body, multiple weapon systems, defensive posture
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    # Station colors - dark metal, cyan/teal accents, industrial
    colors = {
        "primary": (60, 70, 85),          # Dark blue-gray metal
        "secondary": (40, 50, 65),        # Very dark metal
        "metal": (140, 150, 165),         # Light metal
        "dark_metal": (30, 40, 50),       # Very dark metal
        "accent": (50, 200, 255),          # Bright cyan/teal glow
        "energy": (100, 220, 255),        # Energy core
        "warning": (255, 150, 50),        # Orange warning lights
    }
    
    draw_shadow(draw, cx=32, width=28, y=60)
    cx = 32  # Center of 64x64 image
    
    # === MASSIVE BASE/TREADS ===
    # Left tread (large)
    draw.rectangle((cx - 20, 50, cx - 8, 62), fill=colors["dark_metal"])
    draw.rectangle((cx - 20, 50, cx - 20, 62), fill=OUTLINE)
    draw.rectangle((cx - 20, 62, cx - 8, 62), fill=OUTLINE)
    # Tread details
    for i in range(4):
        x = cx - 19 + i * 3
        draw.rectangle((x, 52, x + 2, 60), fill=colors["metal"])
    
    # Right tread
    draw.rectangle((cx + 8, 50, cx + 20, 62), fill=colors["dark_metal"])
    draw.rectangle((cx + 20, 50, cx + 20, 62), fill=OUTLINE)
    draw.rectangle((cx + 8, 62, cx + 20, 62), fill=OUTLINE)
    # Tread details
    for i in range(4):
        x = cx + 9 + i * 3
        draw.rectangle((x, 52, x + 2, 60), fill=colors["metal"])
    
    # === MASSIVE ARMORED BODY ===
    # Main body (large, boxy)
    draw.rectangle((cx - 18, 20, cx + 18, 50), fill=colors["primary"])
    draw.rectangle((cx - 18, 20, cx - 18, 50), fill=OUTLINE)
    draw.rectangle((cx + 18, 20, cx + 18, 50), fill=OUTLINE)
    draw.rectangle((cx - 18, 20, cx + 18, 20), fill=OUTLINE)
    
    # Armor panels (layered)
    draw.rectangle((cx - 15, 23, cx + 15, 47), fill=colors["secondary"])
    # Reinforced corners
    draw.rectangle((cx - 15, 23, cx - 11, 27), fill=colors["metal"])
    draw.rectangle((cx + 11, 23, cx + 15, 27), fill=colors["metal"])
    draw.rectangle((cx - 15, 43, cx - 11, 47), fill=colors["metal"])
    draw.rectangle((cx + 11, 43, cx + 15, 47), fill=colors["metal"])
    
    # Energy core (glowing center)
    draw.ellipse((cx - 6, 30, cx + 6, 40), fill=colors["energy"])
    draw.ellipse((cx - 4, 32, cx + 4, 38), fill=(150, 240, 255))
    draw.point((cx, 35), fill=WHITE)
    
    # Warning lights (multiple)
    for x in [cx - 12, cx - 4, cx + 4, cx + 12]:
        draw.ellipse((x - 2, 22, x + 2, 25), fill=colors["warning"])
        draw.point((x, 23), fill=(255, 220, 150))
    
    # === WEAPON SYSTEMS ===
    # Left weapon mount
    draw.rectangle((cx - 20, 28, cx - 18, 38), fill=colors["primary"])
    draw.rectangle((cx - 22, 30, cx - 18, 36), fill=colors["dark_metal"])
    draw.ellipse((cx - 23, 31, cx - 19, 35), fill=colors["accent"])
    
    # Right weapon mount
    draw.rectangle((cx + 18, 28, cx + 20, 38), fill=colors["primary"])
    draw.rectangle((cx + 18, 30, cx + 22, 36), fill=colors["dark_metal"])
    draw.ellipse((cx + 19, 31, cx + 23, 35), fill=colors["accent"])
    
    # Top weapon turret
    draw.rectangle((cx - 4, 18, cx + 4, 20), fill=colors["primary"])
    draw.ellipse((cx - 6, 16, cx + 6, 22), fill=colors["dark_metal"])
    draw.ellipse((cx - 4, 17, cx + 4, 21), fill=colors["accent"])
    
    # === SENSOR HEAD (large) ===
    draw.rectangle((cx - 10, 8, cx + 10, 20), fill=colors["dark_metal"])
    draw.rectangle((cx - 10, 8, cx - 10, 20), fill=OUTLINE)
    draw.rectangle((cx + 10, 8, cx + 10, 20), fill=OUTLINE)
    draw.rectangle((cx - 10, 8, cx + 10, 8), fill=OUTLINE)
    
    # Multiple sensor lenses
    draw.ellipse((cx - 7, 10, cx - 4, 13), fill=colors["energy"])
    draw.ellipse((cx - 2, 10, cx + 2, 13), fill=colors["energy"])
    draw.ellipse((cx + 4, 10, cx + 7, 13), fill=colors["energy"])
    draw.point((cx - 5, 11), fill=(200, 250, 255))
    draw.point((cx, 11), fill=(200, 250, 255))
    draw.point((cx + 5, 11), fill=(200, 250, 255))
    
    # Antenna/comm array
    draw.line((cx, 8, cx, 4), fill=colors["metal"], width=2)
    draw.ellipse((cx - 2, 2, cx + 2, 6), fill=colors["accent"])
    
    return img


# =============================================================================
# ASTEROID BOSS - Giant Mining Rig
# =============================================================================

def generate_asteroid_boss():
    """
    Asteroid Boss - Massive industrial mining behemoth
    Huge drill systems, multiple arms, heavily armored
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (80, 60, 50),          # Brown metal
        "secondary": (60, 45, 35),         # Dark brown
        "metal": (130, 120, 110),          # Light metal
        "dark_metal": (40, 35, 30),        # Very dark metal
        "accent": (240, 160, 100),        # Bright orange
        "drill": (30, 30, 35),             # Dark drill
        "energy": (150, 200, 255),         # Blue energy
    }
    
    draw_shadow(draw, cx=32, width=30, y=60)
    cx = 32
    
    # === MASSIVE BASE/PLATFORM ===
    # Wide base platform
    draw.rectangle((cx - 22, 48, cx + 22, 62), fill=colors["dark_metal"])
    draw.rectangle((cx - 22, 48, cx - 22, 62), fill=OUTLINE)
    draw.rectangle((cx + 22, 48, cx + 22, 62), fill=OUTLINE)
    draw.rectangle((cx - 22, 48, cx + 22, 48), fill=OUTLINE)
    
    # Platform details
    for i in range(6):
        x = cx - 20 + i * 7
        draw.rectangle((x, 50, x + 5, 60), fill=colors["metal"])
    
    # === MASSIVE BODY ===
    # Main body (huge, boxy)
    draw.rectangle((cx - 20, 15, cx + 20, 48), fill=colors["primary"])
    draw.rectangle((cx - 20, 15, cx - 20, 48), fill=OUTLINE)
    draw.rectangle((cx + 20, 15, cx + 20, 48), fill=OUTLINE)
    draw.rectangle((cx - 20, 15, cx + 20, 15), fill=OUTLINE)
    
    # Armor panels
    draw.rectangle((cx - 17, 18, cx + 17, 45), fill=colors["secondary"])
    # Heavy rivets
    for x in [cx - 14, cx - 7, cx, cx + 7, cx + 14]:
        for y in [20, 26, 32, 38, 44]:
            draw.point((x, y), fill=colors["metal"])
    
    # Energy core
    draw.ellipse((cx - 8, 28, cx + 8, 38), fill=colors["energy"])
    draw.ellipse((cx - 6, 30, cx + 6, 36), fill=(200, 230, 255))
    draw.point((cx, 33), fill=WHITE)
    
    # Warning lights
    for x in [cx - 15, cx, cx + 15]:
        draw.ellipse((x - 2, 16, x + 2, 19), fill=colors["accent"])
        draw.point((x, 17), fill=(255, 220, 180))
    
    # === MASSIVE DRILL ARMS ===
    # Left drill arm (huge)
    draw.rectangle((cx - 22, 25, cx - 20, 40), fill=colors["primary"])
    draw.ellipse((cx - 26, 20, cx - 20, 28), fill=colors["drill"])
    draw.ellipse((cx - 25, 21, cx - 21, 27), fill=colors["dark_metal"])
    # Drill tip
    draw.polygon([(cx - 23, 20), (cx - 26, 16), (cx - 20, 16)], fill=colors["dark_metal"])
    # Drill details
    for i in range(3):
        y = 22 + i * 2
        draw.line((cx - 25, y, cx - 21, y), fill=colors["metal"], width=1)
    
    # Right drill arm
    draw.rectangle((cx + 20, 25, cx + 22, 40), fill=colors["primary"])
    draw.ellipse((cx + 20, 20, cx + 26, 28), fill=colors["drill"])
    draw.ellipse((cx + 21, 21, cx + 25, 27), fill=colors["dark_metal"])
    # Drill tip
    draw.polygon([(cx + 23, 20), (cx + 20, 16), (cx + 26, 16)], fill=colors["dark_metal"])
    # Drill details
    for i in range(3):
        y = 22 + i * 2
        draw.line((cx + 21, y, cx + 25, y), fill=colors["metal"], width=1)
    
    # Center drill (top)
    draw.rectangle((cx - 4, 12, cx + 4, 15), fill=colors["primary"])
    draw.ellipse((cx - 6, 8, cx + 6, 14), fill=colors["drill"])
    draw.ellipse((cx - 5, 9, cx + 5, 13), fill=colors["dark_metal"])
    draw.polygon([(cx, 8), (cx - 4, 4), (cx + 4, 4)], fill=colors["dark_metal"])
    
    # === SENSOR HEAD ===
    draw.rectangle((cx - 12, 4, cx + 12, 15), fill=colors["dark_metal"])
    draw.rectangle((cx - 12, 4, cx - 12, 15), fill=OUTLINE)
    draw.rectangle((cx + 12, 4, cx + 12, 15), fill=OUTLINE)
    draw.rectangle((cx - 12, 4, cx + 12, 4), fill=OUTLINE)
    
    # Multiple sensors
    draw.ellipse((cx - 8, 6, cx - 5, 9), fill=colors["energy"])
    draw.ellipse((cx - 3, 6, cx + 3, 9), fill=colors["energy"])
    draw.ellipse((cx + 5, 6, cx + 8, 9), fill=colors["energy"])
    draw.point((cx - 6, 7), fill=(200, 240, 255))
    draw.point((cx, 7), fill=(200, 240, 255))
    draw.point((cx + 6, 7), fill=(200, 240, 255))
    
    return img


# =============================================================================
# PLANET BOSS - Massive Alien Alpha
# =============================================================================

def generate_planet_boss():
    """
    Planet Boss - Massive alien alpha predator
    Huge organic body, multiple limbs, bioluminescent patterns
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (140, 100, 160),        # Bright purple body
        "secondary": (110, 70, 130),       # Darker purple
        "accent": (255, 180, 255),         # Bright pink/purple glow
        "biolum": (120, 250, 230),         # Bright teal bioluminescence
        "eye": (180, 255, 250),            # Very bright eyes
        "limb": (90, 60, 110),             # Dark limb color
        "crystal": (220, 160, 255),        # Crystal growths
        "pattern": (160, 120, 180),        # Body pattern
    }
    
    draw_shadow(draw, cx=32, width=28, y=60)
    cx = 32
    
    # === MASSIVE LEGS/BASE ===
    # Four large legs (visible from top)
    leg_positions = [(-14, 50), (-4, 52), (4, 52), (14, 50)]
    for x_offset, y_start in leg_positions:
        # Leg
        draw.ellipse((cx + x_offset - 3, y_start, cx + x_offset + 3, 60), fill=colors["limb"])
        draw.ellipse((cx + x_offset - 3, y_start, cx + x_offset + 3, y_start + 6), fill=OUTLINE)
        # Foot
        draw.ellipse((cx + x_offset - 4, 58, cx + x_offset + 4, 62), fill=colors["secondary"])
    
    # === MASSIVE BODY (organic, rounded) ===
    # Main body (huge)
    draw.ellipse((cx - 22, 18, cx + 22, 52), fill=colors["primary"])
    draw.arc((cx - 22, 18, cx + 22, 52), 30, 150, fill=OUTLINE, width=2)
    
    # Body segments/pattern
    draw.ellipse((cx - 18, 22, cx + 18, 48), fill=colors["pattern"])
    draw.ellipse((cx - 15, 26, cx + 15, 44), fill=colors["secondary"])
    
    # Complex bioluminescent pattern (glowing spots)
    pattern_spots = [
        (-16, 24), (-10, 28), (-4, 32), (4, 32), (10, 28), (16, 24),
        (-14, 30), (-6, 34), (6, 34), (14, 30),
        (-12, 36), (0, 38), (12, 36),
        (-8, 40), (8, 40),
    ]
    for x_offset, y in pattern_spots:
        draw.point((cx + x_offset, y), fill=colors["biolum"])
        # Glow effect
        draw.point((cx + x_offset - 1, y), fill=(colors["biolum"][0]//2, colors["biolum"][1]//2, colors["biolum"][2]//2, 150))
        draw.point((cx + x_offset + 1, y), fill=(colors["biolum"][0]//2, colors["biolum"][1]//2, colors["biolum"][2]//2, 150))
        draw.point((cx + x_offset, y - 1), fill=(colors["biolum"][0]//2, colors["biolum"][1]//2, colors["biolum"][2]//2, 150))
        draw.point((cx + x_offset, y + 1), fill=(colors["biolum"][0]//2, colors["biolum"][1]//2, colors["biolum"][2]//2, 150))
    
    # Energy core (glowing center)
    draw.ellipse((cx - 10, 32, cx + 10, 42), fill=colors["accent"])
    draw.ellipse((cx - 8, 34, cx + 8, 40), fill=(255, 220, 255))
    draw.point((cx, 37), fill=WHITE)
    
    # === MASSIVE HEAD ===
    # Head (large, elongated)
    draw.ellipse((cx - 18, 4, cx + 18, 22), fill=colors["primary"])
    draw.arc((cx - 18, 4, cx + 18, 22), 30, 150, fill=OUTLINE, width=2)
    
    # Head pattern
    draw.ellipse((cx - 15, 7, cx + 15, 19), fill=colors["pattern"])
    draw.ellipse((cx - 12, 10, cx + 12, 16), fill=colors["secondary"])
    
    # === MULTIPLE EYES (large array) ===
    # Primary large eyes
    draw.ellipse((cx - 10, 9, cx - 6, 13), fill=colors["eye"])
    draw.point((cx - 8, 11), fill=WHITE)
    draw.ellipse((cx + 6, 9, cx + 10, 13), fill=colors["eye"])
    draw.point((cx + 8, 11), fill=WHITE)
    
    # Secondary eyes
    draw.ellipse((cx - 14, 11, cx - 12, 13), fill=colors["biolum"])
    draw.ellipse((cx + 12, 11, cx + 14, 13), fill=colors["biolum"])
    draw.ellipse((cx - 2, 7, cx + 2, 9), fill=colors["biolum"])
    draw.ellipse((cx - 2, 15, cx + 2, 17), fill=colors["biolum"])
    
    # === TENTACLES/APPENDAGES (multiple) ===
    # Left tentacles
    tentacle_positions = [(-16, 12), (-14, 16), (-12, 20)]
    for x_offset, y in tentacle_positions:
        draw.line((cx + x_offset, y, cx + x_offset - 2, y - 4), fill=colors["limb"], width=2)
        draw.ellipse((cx + x_offset - 3, y - 5, cx + x_offset - 1, y - 3), fill=colors["biolum"])
    
    # Right tentacles
    tentacle_positions = [(16, 12), (14, 16), (12, 20)]
    for x_offset, y in tentacle_positions:
        draw.line((cx + x_offset, y, cx + x_offset + 2, y - 4), fill=colors["limb"], width=2)
        draw.ellipse((cx + x_offset + 1, y - 5, cx + x_offset + 3, y - 3), fill=colors["biolum"])
    
    # === CRYSTAL GROWTHS (alien feature) ===
    # Large crystal on back
    draw.polygon([(cx - 2, 18), (cx + 2, 18), (cx, 12)], fill=colors["crystal"])
    draw.polygon([(cx - 2, 18), (cx, 12), (cx - 4, 14)], fill=colors["accent"])
    draw.polygon([(cx + 2, 18), (cx, 12), (cx + 4, 14)], fill=colors["accent"])
    # Crystal glow
    draw.point((cx, 14), fill=WHITE)
    
    # Side crystals
    draw.polygon([(cx - 18, 24), (cx - 16, 24), (cx - 17, 20)], fill=colors["crystal"])
    draw.polygon([(cx + 16, 24), (cx + 18, 24), (cx + 17, 20)], fill=colors["crystal"])
    
    return img


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Generate all boss enemy sprites."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    sprites = {
        "enemy_boss_station.png": generate_station_boss,
        "enemy_boss_asteroid.png": generate_asteroid_boss,
        "enemy_boss_planet.png": generate_planet_boss,
    }
    
    print("Generating boss enemy sprites...")
    print("=" * 50)
    
    for filename, generator in sprites.items():
        filepath = os.path.join(OUTPUT_DIR, filename)
        img = generator()
        img.save(filepath, "PNG")
        print(f"  [OK] Generated: {filename}")
    
    print("=" * 50)
    print(f"All {len(sprites)} boss enemy sprites generated successfully!")
    print(f"Output directory: {OUTPUT_DIR}")
    print("\nBoss variants:")
    print("  - STATION: Massive security mech")
    print("  - ASTEROID: Giant mining rig")
    print("  - PLANET: Massive alien alpha predator")


if __name__ == "__main__":
    main()
