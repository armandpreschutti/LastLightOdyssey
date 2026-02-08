#!/usr/bin/env python3
"""
Generate biome-specific enemy sprites for Last Light Odyssey
- ASTEROID: Mining/industrial robots (drills, mechanical arms, rugged)
- PLANET: Mixed alien creatures (quadrupeds, insectoids, plant-like, etc.)
Style: Pokemon/RPG-style pixel art with 3/4 TOP-DOWN perspective
"""

from PIL import Image, ImageDraw
import os

# Output directory
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "characters")

# Sprite size - 32x32 for tactical game
SIZE = 32

# Common colors
OUTLINE = (25, 25, 35)           # Dark outline
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def create_base_image():
    """Create a transparent 32x32 image."""
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def draw_shadow(draw, cx=16, width=12, y=30):
    """Draw ground shadow ellipse for 3/4 top-down grounding."""
    shadow_color = (0, 0, 0, 60)
    draw.ellipse(
        (cx - width // 2, y - 2, cx + width // 2, y + 1),
        fill=shadow_color
    )


# =============================================================================
# ASTEROID ROBOTS (Mining/Industrial)
# =============================================================================

def generate_asteroid_basic():
    """
    Basic Mining Robot - Simple industrial robot with drill arm
    Boxy body, single drill arm, rugged mining aesthetic
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    # Industrial/mining colors - browns, grays, orange accents
    colors = {
        "primary": (100, 80, 70),         # Brown metal body
        "secondary": (80, 60, 50),        # Darker brown
        "metal": (120, 120, 130),        # Light gray metal
        "dark_metal": (60, 60, 70),      # Dark metal
        "accent": (200, 120, 60),        # Orange warning lights
        "drill": (50, 50, 55),           # Dark drill bit
    }
    
    draw_shadow(draw, width=14)
    cx = 16
    
    # === BASE/TREADS (bottom) ===
    # Left tread
    draw.rectangle((cx - 8, 27, cx - 3, 31), fill=colors["dark_metal"])
    draw.rectangle((cx - 8, 27, cx - 8, 31), fill=OUTLINE)
    draw.rectangle((cx - 8, 31, cx - 3, 31), fill=OUTLINE)
    # Tread detail
    draw.rectangle((cx - 7, 28, cx - 4, 30), fill=colors["metal"])
    
    # Right tread
    draw.rectangle((cx + 3, 27, cx + 8, 31), fill=colors["dark_metal"])
    draw.rectangle((cx + 8, 27, cx + 8, 31), fill=OUTLINE)
    draw.rectangle((cx + 3, 31, cx + 8, 31), fill=OUTLINE)
    # Tread detail
    draw.rectangle((cx + 4, 28, cx + 7, 30), fill=colors["metal"])
    
    # === BODY (boxy, industrial) ===
    # Main body box
    draw.rectangle((cx - 7, 15, cx + 7, 27), fill=colors["primary"])
    draw.rectangle((cx - 7, 15, cx - 7, 27), fill=OUTLINE)
    draw.rectangle((cx + 7, 15, cx + 7, 27), fill=OUTLINE)
    draw.rectangle((cx - 7, 15, cx + 7, 15), fill=OUTLINE)
    
    # Body panel detail
    draw.rectangle((cx - 5, 17, cx + 5, 25), fill=colors["secondary"])
    # Rivets
    draw.point((cx - 4, 18), fill=colors["metal"])
    draw.point((cx + 4, 18), fill=colors["metal"])
    draw.point((cx - 4, 24), fill=colors["metal"])
    draw.point((cx + 4, 24), fill=colors["metal"])
    
    # Warning light on top
    draw.ellipse((cx - 2, 13, cx + 2, 16), fill=colors["accent"])
    draw.point((cx, 14), fill=(255, 200, 150))
    
    # === DRILL ARM (right side) ===
    # Arm base
    draw.rectangle((cx + 7, 19, cx + 11, 25), fill=colors["primary"])
    draw.rectangle((cx + 11, 19, cx + 11, 25), fill=OUTLINE)
    # Drill bit (rotating)
    draw.ellipse((cx + 9, 15, cx + 13, 19), fill=colors["drill"])
    draw.ellipse((cx + 10, 16, cx + 12, 18), fill=colors["dark_metal"])
    # Drill tip
    draw.polygon([(cx + 11, 15), (cx + 9, 13), (cx + 13, 13)], fill=colors["dark_metal"])
    
    # === SENSOR HEAD ===
    # Simple sensor box on top
    draw.rectangle((cx - 4, 10, cx + 4, 14), fill=colors["dark_metal"])
    draw.rectangle((cx - 4, 10, cx - 4, 14), fill=OUTLINE)
    draw.rectangle((cx + 4, 10, cx + 4, 14), fill=OUTLINE)
    draw.rectangle((cx - 4, 10, cx + 4, 10), fill=OUTLINE)
    # Sensor lens
    draw.ellipse((cx - 2, 11, cx + 2, 13), fill=(50, 150, 200))
    draw.point((cx, 12), fill=(150, 220, 255))
    
    return img


def generate_asteroid_heavy():
    """
    Heavy Industrial Robot - Bulky mining robot with multiple drill arms
    Larger, more armored, multiple tools
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (90, 70, 60),         # Darker brown metal
        "secondary": (70, 50, 40),       # Very dark brown
        "metal": (110, 110, 120),        # Light metal
        "dark_metal": (50, 50, 60),      # Dark metal
        "accent": (220, 140, 80),        # Bright orange
        "drill": (40, 40, 45),           # Dark drill
    }
    
    draw_shadow(draw, width=16)
    cx = 16
    
    # === WIDE BASE/TREADS ===
    # Left tread (wider)
    draw.rectangle((cx - 10, 27, cx - 2, 31), fill=colors["dark_metal"])
    draw.rectangle((cx - 10, 27, cx - 10, 31), fill=OUTLINE)
    draw.rectangle((cx - 10, 31, cx - 2, 31), fill=OUTLINE)
    draw.rectangle((cx - 9, 28, cx - 3, 30), fill=colors["metal"])
    
    # Right tread
    draw.rectangle((cx + 2, 27, cx + 10, 31), fill=colors["dark_metal"])
    draw.rectangle((cx + 10, 27, cx + 10, 31), fill=OUTLINE)
    draw.rectangle((cx + 2, 31, cx + 10, 31), fill=OUTLINE)
    draw.rectangle((cx + 3, 28, cx + 9, 30), fill=colors["metal"])
    
    # === BULKY BODY ===
    # Main body (wider)
    draw.rectangle((cx - 9, 13, cx + 9, 27), fill=colors["primary"])
    draw.rectangle((cx - 9, 13, cx - 9, 27), fill=OUTLINE)
    draw.rectangle((cx + 9, 13, cx + 9, 27), fill=OUTLINE)
    draw.rectangle((cx - 9, 13, cx + 9, 13), fill=OUTLINE)
    
    # Armor panels
    draw.rectangle((cx - 7, 15, cx + 7, 25), fill=colors["secondary"])
    # Heavy rivets
    for x in [cx - 6, cx - 2, cx + 2, cx + 6]:
        for y in [16, 20, 24]:
            draw.point((x, y), fill=colors["metal"])
    
    # Warning lights (multiple)
    draw.ellipse((cx - 4, 11, cx - 1, 14), fill=colors["accent"])
    draw.ellipse((cx + 1, 11, cx + 4, 14), fill=colors["accent"])
    draw.point((cx - 2, 12), fill=(255, 220, 180))
    draw.point((cx + 2, 12), fill=(255, 220, 180))
    
    # === MULTIPLE DRILL ARMS ===
    # Left drill arm
    draw.rectangle((cx - 11, 19, cx - 7, 25), fill=colors["primary"])
    draw.ellipse((cx - 10, 15, cx - 6, 19), fill=colors["drill"])
    draw.ellipse((cx - 9, 16, cx - 7, 18), fill=colors["dark_metal"])
    draw.polygon([(cx - 8, 15), (cx - 10, 13), (cx - 6, 13)], fill=colors["dark_metal"])
    
    # Right drill arm
    draw.rectangle((cx + 7, 19, cx + 11, 25), fill=colors["primary"])
    draw.ellipse((cx + 6, 15, cx + 10, 19), fill=colors["drill"])
    draw.ellipse((cx + 7, 16, cx + 9, 18), fill=colors["dark_metal"])
    draw.polygon([(cx + 8, 15), (cx + 6, 13), (cx + 10, 13)], fill=colors["dark_metal"])
    
    # === SENSOR HEAD (larger) ===
    draw.rectangle((cx - 5, 8, cx + 5, 12), fill=colors["dark_metal"])
    draw.rectangle((cx - 5, 8, cx - 5, 12), fill=OUTLINE)
    draw.rectangle((cx + 5, 8, cx + 5, 12), fill=OUTLINE)
    draw.rectangle((cx - 5, 8, cx + 5, 8), fill=OUTLINE)
    # Multiple sensors
    draw.ellipse((cx - 3, 9, cx - 1, 11), fill=(50, 150, 200))
    draw.ellipse((cx + 1, 9, cx + 3, 11), fill=(50, 150, 200))
    draw.point((cx - 2, 10), fill=(150, 220, 255))
    draw.point((cx + 2, 10), fill=(150, 220, 255))
    
    return img


def generate_asteroid_sniper():
    """
    Precision Mining Bot - Compact robot with long-range sensor
    Smaller, more precise, targeting equipment
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (110, 90, 80),        # Lighter brown
        "secondary": (85, 65, 55),       # Medium brown
        "metal": (130, 130, 140),        # Light metal
        "dark_metal": (55, 55, 65),      # Dark metal
        "accent": (180, 200, 220),       # Blue sensor glow
        "drill": (45, 45, 50),           # Dark drill
    }
    
    draw_shadow(draw, width=12)
    cx = 16
    
    # === COMPACT BASE ===
    # Smaller treads
    draw.rectangle((cx - 6, 28, cx - 2, 31), fill=colors["dark_metal"])
    draw.rectangle((cx + 2, 28, cx + 6, 31), fill=colors["dark_metal"])
    
    # === COMPACT BODY ===
    draw.rectangle((cx - 6, 17, cx + 6, 27), fill=colors["primary"])
    draw.rectangle((cx - 6, 17, cx - 6, 27), fill=OUTLINE)
    draw.rectangle((cx + 6, 17, cx + 6, 27), fill=OUTLINE)
    draw.rectangle((cx - 6, 17, cx + 6, 17), fill=OUTLINE)
    
    # Panel detail
    draw.rectangle((cx - 4, 19, cx + 4, 25), fill=colors["secondary"])
    
    # === LONG-RANGE SENSOR TOWER ===
    # Tall sensor array
    draw.rectangle((cx - 2, 6, cx + 2, 17), fill=colors["dark_metal"])
    draw.rectangle((cx - 2, 6, cx - 2, 17), fill=OUTLINE)
    draw.rectangle((cx + 2, 6, cx + 2, 17), fill=OUTLINE)
    
    # Sensor head (top)
    draw.ellipse((cx - 4, 4, cx + 4, 8), fill=colors["dark_metal"])
    draw.ellipse((cx - 3, 5, cx + 3, 7), fill=colors["accent"])
    draw.point((cx, 6), fill=(200, 230, 255))
    
    # Sensor dish/antenna
    draw.ellipse((cx - 5, 2, cx + 5, 5), fill=colors["metal"])
    draw.ellipse((cx - 4, 3, cx + 4, 4), fill=colors["accent"])
    
    # === PRECISION DRILL (smaller, on side) ===
    draw.rectangle((cx + 6, 20, cx + 9, 24), fill=colors["primary"])
    draw.ellipse((cx + 7, 18, cx + 10, 21), fill=colors["drill"])
    draw.ellipse((cx + 8, 19, cx + 9, 20), fill=colors["dark_metal"])
    
    # === TARGETING LIGHTS ===
    draw.point((cx - 3, 19), fill=colors["accent"])
    draw.point((cx + 3, 19), fill=colors["accent"])
    
    return img


def generate_asteroid_elite():
    """
    Advanced Industrial Robot - Multiple tools, heavily armored
    Most advanced mining robot with various attachments
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (80, 60, 50),         # Dark brown
        "secondary": (60, 45, 35),       # Very dark brown
        "metal": (140, 140, 150),        # Bright metal
        "dark_metal": (45, 45, 55),      # Dark metal
        "accent": (240, 160, 100),       # Bright orange
        "drill": (35, 35, 40),           # Very dark drill
        "energy": (100, 200, 255),       # Blue energy glow
    }
    
    draw_shadow(draw, width=16)
    cx = 16
    
    # === HEAVY BASE ===
    # Wide treads
    draw.rectangle((cx - 11, 26, cx - 1, 31), fill=colors["dark_metal"])
    draw.rectangle((cx + 1, 26, cx + 11, 31), fill=colors["dark_metal"])
    # Tread details
    for i in range(3):
        x = cx - 10 + i * 3
        draw.rectangle((x, 27, x + 2, 30), fill=colors["metal"])
        x = cx + 1 + i * 3
        draw.rectangle((x, 27, x + 2, 30), fill=colors["metal"])
    
    # === ARMORED BODY ===
    # Main body
    draw.rectangle((cx - 10, 12, cx + 10, 26), fill=colors["primary"])
    draw.rectangle((cx - 10, 12, cx - 10, 26), fill=OUTLINE)
    draw.rectangle((cx + 10, 12, cx + 10, 26), fill=OUTLINE)
    draw.rectangle((cx - 10, 12, cx + 10, 12), fill=OUTLINE)
    
    # Armor panels
    draw.rectangle((cx - 8, 14, cx + 8, 24), fill=colors["secondary"])
    # Reinforced corners
    draw.rectangle((cx - 8, 14, cx - 6, 16), fill=colors["metal"])
    draw.rectangle((cx + 6, 14, cx + 8, 16), fill=colors["metal"])
    draw.rectangle((cx - 8, 22, cx - 6, 24), fill=colors["metal"])
    draw.rectangle((cx + 6, 22, cx + 8, 24), fill=colors["metal"])
    
    # Energy core (glowing)
    draw.ellipse((cx - 3, 17, cx + 3, 21), fill=colors["energy"])
    draw.ellipse((cx - 2, 18, cx + 2, 20), fill=(150, 230, 255))
    draw.point((cx, 19), fill=WHITE)
    
    # Warning lights
    for x in [cx - 5, cx, cx + 5]:
        draw.ellipse((x - 1, 13, x + 1, 15), fill=colors["accent"])
        draw.point((x, 14), fill=(255, 220, 180))
    
    # === MULTIPLE TOOLS ===
    # Left: Drill arm
    draw.rectangle((cx - 12, 18, cx - 8, 24), fill=colors["primary"])
    draw.ellipse((cx - 11, 14, cx - 7, 18), fill=colors["drill"])
    draw.ellipse((cx - 10, 15, cx - 8, 17), fill=colors["dark_metal"])
    draw.polygon([(cx - 9, 14), (cx - 11, 12), (cx - 7, 12)], fill=colors["dark_metal"])
    
    # Right: Claw/grabber
    draw.rectangle((cx + 8, 18, cx + 12, 24), fill=colors["primary"])
    # Claw fingers
    draw.polygon([(cx + 9, 16), (cx + 11, 14), (cx + 12, 16)], fill=colors["dark_metal"])
    draw.polygon([(cx + 10, 16), (cx + 12, 14), (cx + 13, 16)], fill=colors["dark_metal"])
    
    # === ADVANCED SENSOR HEAD ===
    draw.rectangle((cx - 6, 7, cx + 6, 12), fill=colors["dark_metal"])
    draw.rectangle((cx - 6, 7, cx - 6, 12), fill=OUTLINE)
    draw.rectangle((cx + 6, 7, cx + 6, 12), fill=OUTLINE)
    draw.rectangle((cx - 6, 7, cx + 6, 7), fill=OUTLINE)
    
    # Multiple sensor lenses
    draw.ellipse((cx - 4, 8, cx - 2, 10), fill=colors["energy"])
    draw.ellipse((cx - 1, 8, cx + 1, 10), fill=colors["energy"])
    draw.ellipse((cx + 2, 8, cx + 4, 10), fill=colors["energy"])
    draw.point((cx - 3, 9), fill=(200, 240, 255))
    draw.point((cx, 9), fill=(200, 240, 255))
    draw.point((cx + 3, 9), fill=(200, 240, 255))
    
    # Antenna
    draw.line((cx, 7, cx, 4), fill=colors["metal"], width=1)
    draw.ellipse((cx - 1, 3, cx + 1, 5), fill=colors["accent"])
    
    return img


# =============================================================================
# PLANET CREATURES (Alien Non-Humanoid)
# =============================================================================

def generate_planet_basic():
    """
    Basic Alien Creature - Quadruped alien with organic design
    Four-legged creature, alien colors, bioluminescent accents
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    # Alien/planet colors - purples, teals, bioluminescent
    colors = {
        "primary": (120, 80, 140),        # Purple body
        "secondary": (100, 60, 120),     # Darker purple
        "accent": (200, 120, 200),        # Bright purple glow
        "biolum": (100, 200, 180),       # Teal bioluminescence
        "eye": (150, 250, 200),          # Bright teal eyes
        "limb": (90, 70, 100),           # Darker limb color
    }
    
    draw_shadow(draw, width=14)
    cx = 16
    
    # === HIND LEGS (back) ===
    # Left hind leg
    draw.ellipse((cx - 8, 24, cx - 4, 30), fill=colors["limb"])
    draw.ellipse((cx - 8, 24, cx - 4, 28), fill=OUTLINE)
    # Foot/paw
    draw.ellipse((cx - 9, 28, cx - 3, 31), fill=colors["secondary"])
    
    # Right hind leg
    draw.ellipse((cx + 4, 24, cx + 8, 30), fill=colors["limb"])
    draw.ellipse((cx + 4, 24, cx + 8, 28), fill=OUTLINE)
    # Foot/paw
    draw.ellipse((cx + 3, 28, cx + 9, 31), fill=colors["secondary"])
    
    # === BODY (organic, rounded) ===
    # Main body
    draw.ellipse((cx - 8, 14, cx + 8, 26), fill=colors["primary"])
    draw.arc((cx - 8, 14, cx + 8, 26), 30, 150, fill=OUTLINE, width=1)
    
    # Body pattern/markings
    draw.ellipse((cx - 5, 17, cx + 5, 23), fill=colors["secondary"])
    # Bioluminescent spots
    draw.point((cx - 3, 19), fill=colors["biolum"])
    draw.point((cx + 3, 19), fill=colors["biolum"])
    draw.point((cx, 21), fill=colors["biolum"])
    
    # === FRONT LEGS ===
    # Left front leg
    draw.ellipse((cx - 7, 18, cx - 3, 24), fill=colors["limb"])
    draw.arc((cx - 7, 18, cx - 3, 24), 90, 270, fill=OUTLINE, width=1)
    
    # Right front leg
    draw.ellipse((cx + 3, 18, cx + 7, 24), fill=colors["limb"])
    draw.arc((cx + 3, 18, cx + 7, 24), 270, 90, fill=OUTLINE, width=1)
    
    # === HEAD (alien, elongated) ===
    # Head shape
    draw.ellipse((cx - 6, 8, cx + 6, 18), fill=colors["primary"])
    draw.arc((cx - 6, 8, cx + 6, 18), 30, 150, fill=OUTLINE, width=1)
    
    # Snout/mouth area
    draw.ellipse((cx - 3, 12, cx + 3, 16), fill=colors["secondary"])
    
    # === EYES (bioluminescent) ===
    # Left eye
    draw.ellipse((cx - 4, 10, cx - 2, 12), fill=colors["eye"])
    draw.point((cx - 3, 11), fill=WHITE)
    # Right eye
    draw.ellipse((cx + 2, 10, cx + 4, 12), fill=colors["eye"])
    draw.point((cx + 3, 11), fill=WHITE)
    
    # === ALIEN FEATURES ===
    # Antennae/tendrils
    draw.line((cx - 5, 9, cx - 6, 6), fill=colors["accent"], width=1)
    draw.ellipse((cx - 7, 5, cx - 5, 7), fill=colors["biolum"])
    draw.line((cx + 5, 9, cx + 6, 6), fill=colors["accent"], width=1)
    draw.ellipse((cx + 5, 5, cx + 7, 7), fill=colors["biolum"])
    
    return img


def generate_planet_heavy():
    """
    Heavy Armored Creature - Bulky shelled alien
    Large, armored, shell-like protection, bioluminescent patterns
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (100, 70, 110),       # Dark purple body
        "secondary": (80, 50, 90),       # Very dark purple
        "shell": (130, 100, 150),         # Lighter shell color
        "accent": (220, 140, 240),       # Bright purple glow
        "biolum": (120, 220, 200),       # Teal bioluminescence
        "eye": (160, 255, 220),          # Bright eyes
        "limb": (70, 50, 80),            # Dark limbs
    }
    
    draw_shadow(draw, width=16)
    cx = 16
    
    # === HEAVY BASE/LEGS ===
    # Thick legs (4 total, but only 2 visible from top-down)
    # Left leg
    draw.ellipse((cx - 9, 24, cx - 3, 31), fill=colors["limb"])
    draw.ellipse((cx - 9, 24, cx - 3, 29), fill=OUTLINE)
    # Right leg
    draw.ellipse((cx + 3, 24, cx + 9, 31), fill=colors["limb"])
    draw.ellipse((cx + 3, 24, cx + 9, 29), fill=OUTLINE)
    
    # === SHELLED BODY (bulky, armored) ===
    # Main body (large)
    draw.ellipse((cx - 10, 12, cx + 10, 26), fill=colors["primary"])
    draw.arc((cx - 10, 12, cx + 10, 26), 30, 150, fill=OUTLINE, width=1)
    
    # Shell plates (armor segments)
    # Top shell
    draw.ellipse((cx - 8, 10, cx + 8, 20), fill=colors["shell"])
    draw.arc((cx - 8, 10, cx + 8, 20), 0, 180, fill=OUTLINE, width=1)
    
    # Shell segments
    draw.ellipse((cx - 7, 12, cx - 3, 16), fill=colors["secondary"])
    draw.ellipse((cx + 3, 12, cx + 7, 16), fill=colors["secondary"])
    draw.ellipse((cx - 5, 18, cx - 1, 22), fill=colors["secondary"])
    draw.ellipse((cx + 1, 18, cx + 5, 22), fill=colors["secondary"])
    
    # Bioluminescent patterns on shell
    draw.point((cx - 5, 13), fill=colors["biolum"])
    draw.point((cx + 5, 13), fill=colors["biolum"])
    draw.point((cx - 3, 19), fill=colors["biolum"])
    draw.point((cx + 3, 19), fill=colors["biolum"])
    draw.point((cx, 15), fill=colors["biolum"])
    
    # === HEAD (protected by shell) ===
    # Head (smaller, peeking from shell)
    draw.ellipse((cx - 5, 8, cx + 5, 14), fill=colors["primary"])
    draw.arc((cx - 5, 8, cx + 5, 14), 30, 150, fill=OUTLINE, width=1)
    
    # === EYES (glowing) ===
    draw.ellipse((cx - 3, 9, cx - 1, 11), fill=colors["eye"])
    draw.point((cx - 2, 10), fill=WHITE)
    draw.ellipse((cx + 1, 9, cx + 3, 11), fill=colors["eye"])
    draw.point((cx + 2, 10), fill=WHITE)
    
    # === CLAWS/TALONS ===
    # Front claws (visible)
    draw.polygon([(cx - 8, 20), (cx - 9, 22), (cx - 7, 22)], fill=colors["limb"])
    draw.polygon([(cx + 7, 20), (cx + 6, 22), (cx + 8, 22)], fill=colors["limb"])
    
    return img


def generate_planet_sniper():
    """
    Long-Range Creature - Tentacled alien with ranged appendages
    Multiple tentacles, elongated body, bioluminescent targeting
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (110, 90, 130),       # Light purple body
        "secondary": (90, 70, 110),      # Medium purple
        "accent": (180, 100, 220),       # Bright purple
        "biolum": (100, 220, 200),       # Teal bioluminescence
        "eye": (150, 250, 220),          # Bright teal eyes
        "tentacle": (80, 60, 100),       # Dark tentacle color
    }
    
    draw_shadow(draw, width=14)
    cx = 16
    
    # === TENTACLES (multiple, organic) ===
    # Left tentacles
    draw.ellipse((cx - 10, 22, cx - 6, 28), fill=colors["tentacle"])
    draw.ellipse((cx - 9, 23, cx - 7, 27), fill=OUTLINE)
    draw.ellipse((cx - 8, 24, cx - 4, 30), fill=colors["tentacle"])
    
    # Right tentacles
    draw.ellipse((cx + 6, 22, cx + 10, 28), fill=colors["tentacle"])
    draw.ellipse((cx + 7, 23, cx + 9, 27), fill=OUTLINE)
    draw.ellipse((cx + 4, 24, cx + 8, 30), fill=colors["tentacle"])
    
    # Back tentacles (ranged appendages)
    draw.ellipse((cx - 3, 20, cx + 3, 26), fill=colors["tentacle"])
    # Ranged appendage (extended)
    draw.ellipse((cx - 2, 16, cx + 2, 22), fill=colors["tentacle"])
    draw.ellipse((cx - 1, 17, cx + 1, 21), fill=colors["biolum"])
    draw.point((cx, 19), fill=colors["accent"])
    
    # === ELONGATED BODY ===
    # Main body (slim, elongated)
    draw.ellipse((cx - 6, 12, cx + 6, 22), fill=colors["primary"])
    draw.arc((cx - 6, 12, cx + 6, 22), 30, 150, fill=OUTLINE, width=1)
    
    # Body segments
    draw.ellipse((cx - 4, 14, cx + 4, 20), fill=colors["secondary"])
    # Bioluminescent spots (targeting)
    for y in [15, 17, 19]:
        draw.point((cx - 2, y), fill=colors["biolum"])
        draw.point((cx + 2, y), fill=colors["biolum"])
    
    # === HEAD (with targeting sensors) ===
    # Head
    draw.ellipse((cx - 5, 6, cx + 5, 14), fill=colors["primary"])
    draw.arc((cx - 5, 6, cx + 5, 14), 30, 150, fill=OUTLINE, width=1)
    
    # === MULTIPLE EYES (targeting array) ===
    # Primary eyes
    draw.ellipse((cx - 3, 8, cx - 1, 10), fill=colors["eye"])
    draw.point((cx - 2, 9), fill=WHITE)
    draw.ellipse((cx + 1, 8, cx + 3, 10), fill=colors["eye"])
    draw.point((cx + 2, 9), fill=WHITE)
    
    # Secondary eyes (sensors)
    draw.point((cx - 4, 9), fill=colors["biolum"])
    draw.point((cx + 4, 9), fill=colors["biolum"])
    draw.point((cx, 7), fill=colors["biolum"])
    
    # === TENTACLE EXTENSIONS (ranged) ===
    # Extended targeting tentacles
    draw.line((cx - 6, 10, cx - 8, 6), fill=colors["tentacle"], width=1)
    draw.ellipse((cx - 9, 5, cx - 7, 7), fill=colors["biolum"])
    draw.line((cx + 6, 10, cx + 8, 6), fill=colors["tentacle"], width=1)
    draw.ellipse((cx + 7, 5, cx + 9, 7), fill=colors["biolum"])
    
    return img


def generate_planet_elite():
    """
    Elite Alien - Hybrid design with advanced bioluminescence
    Most advanced creature, multiple features, glowing patterns
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (130, 100, 150),      # Bright purple body
        "secondary": (100, 70, 120),      # Medium purple
        "accent": (240, 160, 255),        # Very bright purple glow
        "biolum": (120, 240, 220),       # Bright teal bioluminescence
        "eye": (180, 255, 240),          # Very bright eyes
        "limb": (90, 70, 110),           # Limb color
        "crystal": (200, 150, 255),      # Crystal growths
    }
    
    draw_shadow(draw, width=16)
    cx = 16
    
    # === MULTIPLE LEGS/APPENDAGES ===
    # Four legs visible
    for x_offset in [-8, -2, 2, 8]:
        draw.ellipse((cx + x_offset - 1, 24, cx + x_offset + 1, 30), fill=colors["limb"])
        draw.ellipse((cx + x_offset - 1, 24, cx + x_offset + 1, 28), fill=OUTLINE)
    
    # === ADVANCED BODY (hybrid design) ===
    # Main body (larger, more complex)
    draw.ellipse((cx - 9, 11, cx + 9, 25), fill=colors["primary"])
    draw.arc((cx - 9, 11, cx + 9, 25), 30, 150, fill=OUTLINE, width=1)
    
    # Body segments with patterns
    draw.ellipse((cx - 7, 13, cx + 7, 23), fill=colors["secondary"])
    # Complex bioluminescent pattern
    for x in [-5, -2, 0, 2, 5]:
        for y in [15, 18, 21]:
            draw.point((cx + x, y), fill=colors["biolum"])
    
    # Energy core (glowing center)
    draw.ellipse((cx - 3, 17, cx + 3, 21), fill=colors["accent"])
    draw.ellipse((cx - 2, 18, cx + 2, 20), fill=(255, 200, 255))
    draw.point((cx, 19), fill=WHITE)
    
    # === CRYSTAL GROWTHS (alien feature) ===
    # Crystal on back
    draw.polygon([(cx - 1, 12), (cx + 1, 12), (cx, 9)], fill=colors["crystal"])
    draw.polygon([(cx - 1, 12), (cx, 9), (cx - 2, 10)], fill=colors["accent"])
    draw.polygon([(cx + 1, 12), (cx, 9), (cx + 2, 10)], fill=colors["accent"])
    
    # === ADVANCED HEAD ===
    # Head (larger, more detailed)
    draw.ellipse((cx - 6, 5, cx + 6, 13), fill=colors["primary"])
    draw.arc((cx - 6, 5, cx + 6, 13), 30, 150, fill=OUTLINE, width=1)
    
    # Head pattern
    draw.ellipse((cx - 4, 7, cx + 4, 11), fill=colors["secondary"])
    
    # === MULTIPLE EYES (advanced array) ===
    # Primary large eyes
    draw.ellipse((cx - 4, 7, cx - 2, 9), fill=colors["eye"])
    draw.point((cx - 3, 8), fill=WHITE)
    draw.ellipse((cx + 2, 7, cx + 4, 9), fill=colors["eye"])
    draw.point((cx + 3, 8), fill=WHITE)
    
    # Secondary sensor eyes
    draw.point((cx - 5, 8), fill=colors["biolum"])
    draw.point((cx + 5, 8), fill=colors["biolum"])
    draw.point((cx, 6), fill=colors["biolum"])
    draw.point((cx, 10), fill=colors["biolum"])
    
    # === TENTACLES/APPENDAGES (multiple) ===
    # Left tentacles
    draw.line((cx - 7, 11, cx - 9, 7), fill=colors["limb"], width=1)
    draw.ellipse((cx - 10, 6, cx - 8, 8), fill=colors["biolum"])
    draw.line((cx - 6, 13, cx - 8, 9), fill=colors["limb"], width=1)
    draw.ellipse((cx - 9, 8, cx - 7, 10), fill=colors["biolum"])
    
    # Right tentacles
    draw.line((cx + 7, 11, cx + 9, 7), fill=colors["limb"], width=1)
    draw.ellipse((cx + 8, 6, cx + 10, 8), fill=colors["biolum"])
    draw.line((cx + 6, 13, cx + 8, 9), fill=colors["limb"], width=1)
    draw.ellipse((cx + 7, 8, cx + 9, 10), fill=colors["biolum"])
    
    # === BIOLUMINESCENT MARKINGS ===
    # Glowing patterns along body
    for i in range(3):
        y = 14 + i * 3
        draw.point((cx - 6, y), fill=colors["accent"])
        draw.point((cx + 6, y), fill=colors["accent"])
    
    return img


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Generate all biome-specific enemy sprites."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    sprites = {
        # ASTEROID robots
        "enemy_basic_asteroid.png": generate_asteroid_basic,
        "enemy_heavy_asteroid.png": generate_asteroid_heavy,
        "enemy_sniper_asteroid.png": generate_asteroid_sniper,
        "enemy_elite_asteroid.png": generate_asteroid_elite,
        # PLANET creatures
        "enemy_basic_planet.png": generate_planet_basic,
        "enemy_heavy_planet.png": generate_planet_heavy,
        "enemy_sniper_planet.png": generate_planet_sniper,
        "enemy_elite_planet.png": generate_planet_elite,
    }
    
    print("Generating biome-specific enemy sprites...")
    print("=" * 50)
    
    for filename, generator in sprites.items():
        filepath = os.path.join(OUTPUT_DIR, filename)
        img = generator()
        img.save(filepath, "PNG")
        print(f"  [OK] Generated: {filename}")
    
    print("=" * 50)
    print(f"All {len(sprites)} biome-specific enemy sprites generated successfully!")
    print(f"Output directory: {OUTPUT_DIR}")
    print("\nBiome variants:")
    print("  - ASTEROID: Mining/industrial robots")
    print("  - PLANET: Mixed alien creatures")


if __name__ == "__main__":
    main()
