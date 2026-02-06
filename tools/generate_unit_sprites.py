#!/usr/bin/env python3
"""
Generate unit sprites for Last Light Odyssey
Style: Pokemon/RPG-style pixel art with 3/4 TOP-DOWN perspective
Key: Characters appear as if viewed from slightly above - you can see the top of their heads

Reference Style Characteristics:
- Large head (40-50% of total height)
- Short, squat body
- Feet visible showing ground plane
- Top of head clearly visible (not just front face)
- Limited color palette (4-6 colors per character)
- Clear dark outlines
"""

from PIL import Image, ImageDraw
import os

# Output directory
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "characters")

# Sprite size - 32x32 for tactical game
SIZE = 32

# Common colors
OUTLINE = (25, 25, 35)           # Dark outline
SKIN_LIGHT = (255, 213, 170)     # Light skin tone
SKIN_MID = (235, 185, 145)       # Mid skin tone
SKIN_SHADOW = (200, 150, 115)    # Shadow skin tone
HAIR_DARK = (50, 40, 35)         # Dark hair
HAIR_BROWN = (100, 70, 50)       # Brown hair
HAIR_LIGHT = (180, 150, 110)     # Light/blonde hair
HAIR_GRAY = (120, 120, 130)      # Gray hair
WHITE = (255, 255, 255)
EYE_WHITE = (255, 255, 255)
EYE_DARK = (30, 30, 40)


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


def draw_chibi_body_topdown(draw, colors, cx=16):
    """
    Draw a chibi body from 3/4 top-down perspective.
    The body is SHORT and SQUAT to match reference style.
    Feet are visible and positioned to show ground plane.
    """
    # === FEET (bottom-most, showing ground plane) ===
    # Feet are small ovals at the bottom, spread slightly
    # Left foot
    draw.ellipse((cx - 6, 27, cx - 2, 30), fill=colors.get("shoes", colors["primary"]))
    draw.ellipse((cx - 6, 27, cx - 2, 29), fill=OUTLINE)  # Top outline
    # Right foot
    draw.ellipse((cx + 2, 27, cx + 6, 30), fill=colors.get("shoes", colors["primary"]))
    draw.ellipse((cx + 2, 27, cx + 6, 29), fill=OUTLINE)  # Top outline
    
    # === LEGS (very short, mostly hidden by body) ===
    # Left leg stub
    draw.rectangle((cx - 5, 24, cx - 2, 28), fill=colors.get("pants", colors["secondary"]))
    # Right leg stub  
    draw.rectangle((cx + 2, 24, cx + 5, 28), fill=colors.get("pants", colors["secondary"]))
    
    # === TORSO (compact, rounded) ===
    # Main body - wider than tall for chibi look
    draw.ellipse((cx - 8, 17, cx + 8, 27), fill=colors["primary"])
    # Body outline
    draw.arc((cx - 8, 17, cx + 8, 27), 30, 150, fill=OUTLINE, width=1)
    
    # Chest/uniform detail
    if "secondary" in colors:
        draw.ellipse((cx - 5, 19, cx + 5, 25), fill=colors["secondary"])
    
    # === ARMS (small, at sides) ===
    # Left arm - small oval
    draw.ellipse((cx - 10, 19, cx - 6, 25), fill=colors["primary"])
    draw.arc((cx - 10, 19, cx - 6, 25), 90, 270, fill=OUTLINE, width=1)
    # Left hand
    draw.ellipse((cx - 9, 23, cx - 6, 26), fill=SKIN_MID)
    
    # Right arm - small oval
    draw.ellipse((cx + 6, 19, cx + 10, 25), fill=colors["primary"])
    draw.arc((cx + 6, 19, cx + 10, 25), 270, 90, fill=OUTLINE, width=1)
    # Right hand
    draw.ellipse((cx + 6, 23, cx + 9, 26), fill=SKIN_MID)


def draw_chibi_head_topdown(draw, hair_color, hair_style="short", cx=16, accessories=None):
    """
    Draw a chibi head from 3/4 top-down perspective.
    Head is LARGE relative to body.
    TOP OF HEAD is clearly visible (key for top-down look).
    """
    accessories = accessories or {}
    
    # === HEAD BASE (large oval) ===
    # Head takes up significant vertical space
    head_top = 3
    head_bottom = 18
    head_left = cx - 9
    head_right = cx + 9
    
    # Main head shape
    draw.ellipse((head_left, head_top, head_right, head_bottom), fill=SKIN_LIGHT)
    
    # Face shadow (lower portion for 3D effect)
    draw.ellipse((head_left + 2, head_top + 8, head_right - 2, head_bottom - 1), fill=SKIN_MID)
    
    # === HAIR (TOP OF HEAD - crucial for top-down view) ===
    # Hair covers the top portion of the head, clearly visible from above
    
    if hair_style == "short":
        # Short spiky hair - visible from above
        draw.ellipse((head_left - 1, head_top - 2, head_right + 1, head_top + 9), fill=hair_color)
        # Spiky bits on top (visible from above)
        draw.polygon([(cx - 6, head_top + 2), (cx - 4, head_top - 3), (cx - 2, head_top + 2)], fill=hair_color)
        draw.polygon([(cx - 2, head_top + 1), (cx, head_top - 4), (cx + 2, head_top + 1)], fill=hair_color)
        draw.polygon([(cx + 2, head_top + 2), (cx + 4, head_top - 3), (cx + 6, head_top + 2)], fill=hair_color)
        # Top-down visible hair surface
        draw.ellipse((head_left + 1, head_top - 1, head_right - 1, head_top + 7), fill=hair_color)
        
    elif hair_style == "military":
        # Short buzz cut - flat on top
        draw.ellipse((head_left, head_top - 1, head_right, head_top + 8), fill=hair_color)
        # Flat top surface (key for top-down)
        draw.rectangle((head_left + 2, head_top, head_right - 2, head_top + 5), fill=hair_color)
        
    elif hair_style == "ponytail":
        # Hair with ponytail visible from above
        draw.ellipse((head_left - 1, head_top - 1, head_right + 1, head_top + 9), fill=hair_color)
        # Top surface
        draw.ellipse((head_left + 1, head_top, head_right - 1, head_top + 6), fill=hair_color)
        # Side hair fringes
        draw.rectangle((head_left - 1, head_top + 6, head_left + 2, head_top + 12), fill=hair_color)
        draw.rectangle((head_right - 2, head_top + 6, head_right + 1, head_top + 12), fill=hair_color)
        # Ponytail (visible behind/to side from top-down)
        draw.ellipse((head_right - 2, head_top + 2, head_right + 4, head_top + 10), fill=hair_color)
        
    elif hair_style == "bald":
        # Bald/very short - shows skin on top
        draw.ellipse((head_left + 1, head_top, head_right - 1, head_top + 5), fill=SKIN_LIGHT)
        # Slight shadow on top
        draw.arc((head_left + 2, head_top + 1, head_right - 2, head_top + 4), 0, 180, fill=SKIN_MID)
    
    elif hair_style == "helmet":
        # For heavy armor - helmet instead of hair
        pass  # Helmet drawn separately in character function
    
    # === FACE ===
    # Eyes - simple dots or small shapes
    eye_y = head_top + 10
    # Left eye
    draw.rectangle((cx - 5, eye_y, cx - 3, eye_y + 2), fill=EYE_WHITE)
    draw.rectangle((cx - 4, eye_y, cx - 3, eye_y + 2), fill=EYE_DARK)
    draw.point((cx - 4, eye_y), fill=WHITE)  # Shine
    
    # Right eye
    draw.rectangle((cx + 3, eye_y, cx + 5, eye_y + 2), fill=EYE_WHITE)
    draw.rectangle((cx + 3, eye_y, cx + 4, eye_y + 2), fill=EYE_DARK)
    draw.point((cx + 4, eye_y), fill=WHITE)  # Shine
    
    # Mouth (optional simple line)
    draw.line((cx - 2, head_top + 14, cx + 2, head_top + 14), fill=SKIN_SHADOW, width=1)
    
    # === HEAD OUTLINE (only lower face, not covered by hair) ===
    # Draw outline only on the chin/jaw area (bottom arc from ~45 to ~135 degrees)
    draw.arc((head_left, head_top, head_right, head_bottom), 30, 150, fill=OUTLINE, width=1)
    
    # === ACCESSORIES ===
    if accessories.get("goggles"):
        # Goggles on forehead
        draw.rectangle((head_left + 2, head_top + 5, head_right - 2, head_top + 8), fill=(60, 60, 70))
        draw.rectangle((head_left + 3, head_top + 6, cx - 2, head_top + 7), fill=(100, 200, 230))
        draw.rectangle((cx + 2, head_top + 6, head_right - 3, head_top + 7), fill=(100, 200, 230))
        
    if accessories.get("headband"):
        # Medical headband
        draw.rectangle((head_left + 1, head_top + 6, head_right - 1, head_top + 8), fill=WHITE)
        draw.rectangle((cx - 1, head_top + 6, cx + 1, head_top + 8), fill=(255, 50, 50))
        
    if accessories.get("visor"):
        # Tech visor/glasses
        draw.rectangle((head_left + 2, eye_y - 1, head_right - 2, eye_y + 2), fill=(60, 60, 80))
        draw.rectangle((head_left + 3, eye_y, cx - 2, eye_y + 1), fill=(150, 200, 255))
        draw.rectangle((cx + 2, eye_y, head_right - 3, eye_y + 1), fill=(150, 200, 255))


# =============================================================================
# OFFICER SPRITES
# =============================================================================

def generate_captain():
    """
    Captain - Command leader with officer's cap
    Gold/yellow uniform, authoritative look
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (200, 160, 50),       # Gold uniform
        "secondary": (170, 130, 30),     # Darker gold details
        "pants": (50, 50, 60),           # Dark pants
        "shoes": (40, 35, 30),           # Dark shoes
        "accent": (255, 210, 60),        # Bright gold
    }
    
    draw_shadow(draw)
    draw_chibi_body_topdown(draw, colors)
    draw_chibi_head_topdown(draw, HAIR_DARK, "military")
    
    cx = 16
    # === CAPTAIN'S CAP (visible from top-down) ===
    # Cap base (visible from above)
    draw.ellipse((cx - 9, 1, cx + 9, 8), fill=colors["primary"])
    draw.ellipse((cx - 7, 2, cx + 7, 6), fill=colors["secondary"])  # Top surface
    # Cap visor (front)
    draw.ellipse((cx - 7, 6, cx + 7, 10), fill=(40, 40, 50))
    # Cap emblem
    draw.rectangle((cx - 2, 3, cx + 2, 5), fill=colors["accent"])
    # Cap outline
    draw.arc((cx - 9, 1, cx + 9, 8), 180, 360, fill=OUTLINE, width=1)
    
    # === RANK INSIGNIA ===
    # Shoulder epaulettes (visible from top-down angle)
    draw.rectangle((cx - 10, 18, cx - 6, 20), fill=colors["accent"])
    draw.rectangle((cx + 6, 18, cx + 10, 20), fill=colors["accent"])
    
    # Chest medal
    draw.ellipse((cx - 3, 21, cx - 1, 23), fill=colors["accent"])
    draw.point((cx - 2, 21), fill=WHITE)
    
    # Belt
    draw.rectangle((cx - 7, 24, cx + 7, 25), fill=(70, 60, 45))
    draw.rectangle((cx - 2, 24, cx + 2, 25), fill=colors["accent"])  # Buckle
    
    return img


def generate_scout():
    """
    Scout - Agile recon specialist with tactical gear
    Green camouflage, goggles, radio antenna
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (70, 100, 70),        # Forest green
        "secondary": (55, 80, 55),       # Darker green
        "pants": (60, 85, 60),           # Green pants
        "shoes": (45, 40, 35),           # Dark boots
        "accent": (140, 190, 140),       # Light green
    }
    
    draw_shadow(draw)
    draw_chibi_body_topdown(draw, colors)
    draw_chibi_head_topdown(draw, HAIR_BROWN, "short", accessories={"goggles": True})
    
    cx = 16
    # === TACTICAL VEST (visible from above) ===
    draw.ellipse((cx - 6, 18, cx + 6, 25), fill=(60, 75, 60))
    # Pouches
    draw.rectangle((cx - 5, 21, cx - 2, 24), fill=(50, 65, 50))
    draw.rectangle((cx + 2, 21, cx + 5, 24), fill=(50, 65, 50))
    
    # High collar
    draw.arc((cx - 6, 15, cx + 6, 19), 0, 180, fill=colors["primary"], width=2)
    
    # === RADIO ANTENNA ===
    # Antenna sticking up (visible from top-down)
    draw.line((cx + 8, 8, cx + 10, 2), fill=(50, 50, 55), width=1)
    draw.point((cx + 10, 2), fill=(255, 60, 60))  # Red light
    
    return img


def generate_tech():
    """
    Tech - Engineer with tools and tech visor
    Teal/cyan uniform, utility belt, backpack
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (50, 130, 140),       # Teal
        "secondary": (35, 100, 110),     # Darker teal
        "pants": (45, 45, 55),           # Dark pants
        "shoes": (55, 50, 45),           # Work boots
        "accent": (100, 220, 235),       # Bright cyan
    }
    
    draw_shadow(draw)
    draw_chibi_body_topdown(draw, colors)
    draw_chibi_head_topdown(draw, HAIR_GRAY, "short", accessories={"visor": True})
    
    cx = 16
    # === UTILITY SUIT DETAILS ===
    # Chest panel/display
    draw.rectangle((cx - 4, 20, cx + 4, 24), fill=(35, 40, 45))
    draw.rectangle((cx - 3, 21, cx + 3, 23), fill=(25, 30, 35))
    # LED lights on display
    draw.point((cx - 2, 22), fill=colors["accent"])
    draw.point((cx, 22), fill=(100, 255, 100))
    draw.point((cx + 2, 22), fill=(255, 180, 80))
    
    # === TOOL BELT ===
    draw.rectangle((cx - 8, 24, cx + 8, 26), fill=(75, 65, 50))
    # Tools hanging from belt
    draw.rectangle((cx - 7, 24, cx - 5, 27), fill=(140, 140, 150))  # Wrench
    draw.rectangle((cx + 5, 24, cx + 7, 27), fill=(170, 170, 60))   # Tool
    
    # === BACKPACK (visible from top-down angle) ===
    # Shows as side bulges from this angle
    draw.ellipse((cx - 11, 17, cx - 7, 24), fill=colors["secondary"])
    draw.ellipse((cx + 7, 17, cx + 11, 24), fill=colors["secondary"])
    
    return img


def generate_medic():
    """
    Medic - Field medic with medical cross and kit
    Magenta/purple uniform, white cross, med bag
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (170, 70, 130),       # Magenta
        "secondary": (140, 50, 105),     # Darker magenta
        "pants": (130, 60, 100),         # Matching pants
        "shoes": (70, 65, 70),           # Gray boots
        "accent": (255, 255, 255),       # White
    }
    
    draw_shadow(draw)
    draw_chibi_body_topdown(draw, colors)
    draw_chibi_head_topdown(draw, HAIR_LIGHT, "ponytail", accessories={"headband": True})
    
    cx = 16
    # === MEDICAL CROSS ON CHEST ===
    # Large white cross (prominent)
    draw.rectangle((cx - 1, 19, cx + 1, 25), fill=WHITE)  # Vertical
    draw.rectangle((cx - 3, 21, cx + 3, 23), fill=WHITE)  # Horizontal
    
    # === MED KIT BAG ===
    # Bag on hip (visible from side at this angle)
    draw.rectangle((cx + 7, 21, cx + 11, 26), fill=WHITE)
    draw.rectangle((cx + 7, 21, cx + 11, 21), fill=OUTLINE)
    draw.rectangle((cx + 11, 21, cx + 11, 26), fill=OUTLINE)
    draw.rectangle((cx + 7, 26, cx + 11, 26), fill=OUTLINE)
    # Cross on bag
    draw.rectangle((cx + 8, 22, cx + 10, 25), fill=(255, 50, 50))
    draw.rectangle((cx + 8, 23, cx + 10, 24), fill=(255, 50, 50))
    
    # Arm patch (red cross)
    draw.rectangle((cx - 10, 20, cx - 7, 23), fill=WHITE)
    draw.point((cx - 8, 21), fill=(255, 50, 50))
    draw.point((cx - 9, 21), fill=(255, 50, 50))
    draw.point((cx - 8, 20), fill=(255, 50, 50))
    draw.point((cx - 8, 22), fill=(255, 50, 50))
    
    return img


def generate_heavy():
    """
    Heavy - Armored tank with helmet and heavy armor
    Orange-red armor, bulky silhouette, protective helmet
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (170, 85, 50),        # Orange-red armor
        "secondary": (140, 65, 35),      # Darker orange
        "pants": (65, 60, 55),           # Dark gray
        "shoes": (45, 40, 35),           # Dark boots
        "accent": (255, 140, 50),        # Bright orange
        "metal": (130, 130, 140),        # Metal gray
        "dark_metal": (80, 80, 90),      # Dark metal
    }
    
    draw_shadow(draw, width=14)  # Wider shadow for bulky character
    
    cx = 16
    
    # === BULKIER BODY (heavier proportions) ===
    # Feet
    draw.ellipse((cx - 7, 27, cx - 2, 31), fill=colors["shoes"])
    draw.ellipse((cx + 2, 27, cx + 7, 31), fill=colors["shoes"])
    
    # Legs (with armor)
    draw.rectangle((cx - 6, 24, cx - 2, 28), fill=colors["pants"])
    draw.rectangle((cx + 2, 24, cx + 6, 28), fill=colors["pants"])
    # Knee pads
    draw.rectangle((cx - 6, 25, cx - 2, 27), fill=colors["metal"])
    draw.rectangle((cx + 2, 25, cx + 6, 27), fill=colors["metal"])
    
    # Bulky torso (wider)
    draw.ellipse((cx - 10, 15, cx + 10, 27), fill=colors["primary"])
    draw.ellipse((cx - 7, 17, cx + 7, 25), fill=colors["secondary"])
    
    # === SHOULDER PAULDRONS (big, armored) ===
    draw.ellipse((cx - 12, 16, cx - 6, 22), fill=colors["metal"])
    draw.arc((cx - 12, 16, cx - 6, 22), 0, 180, fill=(180, 180, 190), width=1)  # Highlight
    draw.ellipse((cx + 6, 16, cx + 12, 22), fill=colors["metal"])
    draw.arc((cx + 6, 16, cx + 12, 22), 0, 180, fill=(180, 180, 190), width=1)
    
    # Arms
    draw.ellipse((cx - 12, 19, cx - 7, 26), fill=colors["primary"])
    draw.ellipse((cx + 7, 19, cx + 12, 26), fill=colors["primary"])
    # Armored gauntlets
    draw.ellipse((cx - 11, 23, cx - 7, 27), fill=colors["dark_metal"])
    draw.ellipse((cx + 7, 23, cx + 11, 27), fill=colors["dark_metal"])
    
    # Chest armor emblem
    draw.polygon([(cx - 2, 19), (cx, 17), (cx + 2, 19), (cx + 2, 23), (cx, 24), (cx - 2, 23)], 
                 fill=colors["accent"])
    draw.point((cx, 20), fill=WHITE)
    
    # Heavy belt
    draw.rectangle((cx - 8, 24, cx + 8, 26), fill=colors["dark_metal"])
    draw.rectangle((cx - 3, 24, cx + 3, 26), fill=colors["metal"])
    draw.point((cx, 25), fill=colors["accent"])
    
    # === HELMET (instead of hair, visible from above) ===
    head_top = 3
    head_left = cx - 10
    head_right = cx + 10
    
    # Helmet base
    draw.ellipse((head_left, head_top, head_right, head_top + 15), fill=colors["metal"])
    # Helmet top surface (visible from above)
    draw.ellipse((head_left + 2, head_top + 1, head_right - 2, head_top + 9), fill=(150, 150, 160))
    # Central stripe on helmet
    draw.rectangle((cx - 2, head_top, cx + 2, head_top + 8), fill=colors["accent"])
    
    # Visor
    draw.rectangle((head_left + 2, head_top + 9, head_right - 2, head_top + 12), fill=(40, 40, 50))
    draw.rectangle((head_left + 3, head_top + 9, head_right - 3, head_top + 11), fill=(80, 60, 50))
    draw.line((head_left + 3, head_top + 9, head_right - 3, head_top + 9), fill=(120, 100, 80))
    
    # Helmet outline
    draw.arc((head_left, head_top, head_right, head_top + 15), 0, 360, fill=OUTLINE, width=1)
    
    return img


# =============================================================================
# ENEMY SPRITES
# =============================================================================

def generate_enemy_basic():
    """
    Basic Enemy - Standard hostile unit
    Red/dark color scheme, menacing but simple design
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (140, 50, 50),         # Dark red
        "secondary": (110, 35, 35),       # Darker red
        "pants": (50, 45, 45),            # Dark pants
        "shoes": (35, 30, 30),            # Dark boots
        "accent": (200, 80, 80),          # Bright red
    }
    
    draw_shadow(draw)
    draw_chibi_body_topdown(draw, colors)
    draw_chibi_head_topdown(draw, (40, 35, 30), "military")
    
    cx = 16
    # === HOSTILE MARKINGS ===
    # Red eye glow effect (replace normal eyes)
    eye_y = 13
    draw.rectangle((cx - 5, eye_y, cx - 3, eye_y + 2), fill=(200, 50, 50))
    draw.point((cx - 4, eye_y), fill=(255, 100, 100))
    draw.rectangle((cx + 3, eye_y, cx + 5, eye_y + 2), fill=(200, 50, 50))
    draw.point((cx + 4, eye_y), fill=(255, 100, 100))
    
    # Tactical mask/face cover
    draw.rectangle((cx - 6, 14, cx + 6, 17), fill=(40, 35, 35))
    
    # Ammo belt across chest
    draw.line((cx - 7, 19, cx + 5, 24), fill=(100, 90, 60), width=2)
    # Ammo bumps
    for i in range(4):
        px = cx - 6 + i * 3
        py = 20 + i
        draw.point((px, py), fill=(120, 110, 70))
    
    return img


def generate_enemy_heavy():
    """
    Heavy Enemy - Armored hostile tank
    Dark armor with red accents, bulky and threatening
    """
    img = create_base_image()
    draw = ImageDraw.Draw(img)
    
    colors = {
        "primary": (60, 55, 55),          # Dark gray armor
        "secondary": (45, 40, 40),        # Darker gray
        "pants": (40, 38, 38),            # Dark pants
        "shoes": (30, 28, 28),            # Very dark boots
        "accent": (180, 50, 50),          # Red accent
        "metal": (90, 85, 85),            # Metal
        "dark_metal": (50, 45, 45),       # Dark metal
    }
    
    draw_shadow(draw, width=14)
    
    cx = 16
    
    # === BULKY ENEMY BODY ===
    # Feet
    draw.ellipse((cx - 7, 27, cx - 2, 31), fill=colors["shoes"])
    draw.ellipse((cx + 2, 27, cx + 7, 31), fill=colors["shoes"])
    
    # Legs
    draw.rectangle((cx - 6, 24, cx - 2, 28), fill=colors["pants"])
    draw.rectangle((cx + 2, 24, cx + 6, 28), fill=colors["pants"])
    draw.rectangle((cx - 6, 25, cx - 2, 27), fill=colors["metal"])
    draw.rectangle((cx + 2, 25, cx + 6, 27), fill=colors["metal"])
    
    # Bulky torso
    draw.ellipse((cx - 10, 15, cx + 10, 27), fill=colors["primary"])
    draw.ellipse((cx - 7, 17, cx + 7, 25), fill=colors["secondary"])
    
    # Shoulder armor
    draw.ellipse((cx - 12, 16, cx - 6, 22), fill=colors["metal"])
    draw.ellipse((cx + 6, 16, cx + 12, 22), fill=colors["metal"])
    # Red stripe on shoulders
    draw.line((cx - 11, 19, cx - 7, 19), fill=colors["accent"], width=1)
    draw.line((cx + 7, 19, cx + 11, 19), fill=colors["accent"], width=1)
    
    # Arms
    draw.ellipse((cx - 12, 19, cx - 7, 26), fill=colors["primary"])
    draw.ellipse((cx + 7, 19, cx + 12, 26), fill=colors["primary"])
    draw.ellipse((cx - 11, 23, cx - 7, 27), fill=colors["dark_metal"])
    draw.ellipse((cx + 7, 23, cx + 11, 27), fill=colors["dark_metal"])
    
    # Red hostile emblem on chest
    draw.polygon([(cx - 2, 19), (cx, 17), (cx + 2, 19), (cx + 2, 23), (cx, 24), (cx - 2, 23)], 
                 fill=colors["accent"])
    draw.polygon([(cx - 1, 20), (cx, 19), (cx + 1, 20), (cx + 1, 22), (cx, 23), (cx - 1, 22)], 
                 fill=(220, 80, 80))
    
    # Belt
    draw.rectangle((cx - 8, 24, cx + 8, 26), fill=colors["dark_metal"])
    
    # === MENACING HELMET ===
    head_top = 3
    head_left = cx - 10
    head_right = cx + 10
    
    draw.ellipse((head_left, head_top, head_right, head_top + 15), fill=colors["metal"])
    draw.ellipse((head_left + 2, head_top + 1, head_right - 2, head_top + 9), fill=colors["primary"])
    # Red stripe
    draw.rectangle((cx - 2, head_top, cx + 2, head_top + 8), fill=colors["accent"])
    
    # Angry visor (slanted)
    draw.polygon([
        (head_left + 2, head_top + 10),
        (head_left + 4, head_top + 8),
        (head_right - 4, head_top + 8),
        (head_right - 2, head_top + 10),
        (head_right - 2, head_top + 12),
        (head_left + 2, head_top + 12)
    ], fill=(30, 25, 25))
    # Red glowing eyes through visor
    draw.rectangle((cx - 5, head_top + 9, cx - 3, head_top + 11), fill=(200, 40, 40))
    draw.point((cx - 4, head_top + 9), fill=(255, 100, 100))
    draw.rectangle((cx + 3, head_top + 9, cx + 5, head_top + 11), fill=(200, 40, 40))
    draw.point((cx + 4, head_top + 9), fill=(255, 100, 100))
    
    draw.arc((head_left, head_top, head_right, head_top + 15), 0, 360, fill=OUTLINE, width=1)
    
    return img


def main():
    """Generate all unit sprites."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    sprites = {
        # Officers
        "officer_captain.png": generate_captain,
        "officer_scout.png": generate_scout,
        "officer_tech.png": generate_tech,
        "officer_medic.png": generate_medic,
        "officer_heavy.png": generate_heavy,
        # Enemies
        "enemy_basic.png": generate_enemy_basic,
        "enemy_heavy.png": generate_enemy_heavy,
    }
    
    print("Generating unit sprites with 3/4 top-down perspective...")
    print("=" * 50)
    
    for filename, generator in sprites.items():
        filepath = os.path.join(OUTPUT_DIR, filename)
        img = generator()
        img.save(filepath, "PNG")
        print(f"  [OK] Generated: {filename}")
    
    print("=" * 50)
    print(f"All {len(sprites)} sprites generated successfully!")
    print(f"Output directory: {OUTPUT_DIR}")
    print("\nKey style features:")
    print("  - 3/4 top-down perspective (view from above)")
    print("  - Large heads (chibi proportions)")
    print("  - Visible top of head (crucial for top-down look)")
    print("  - Short, squat bodies")
    print("  - Ground shadow for depth")


if __name__ == "__main__":
    main()
