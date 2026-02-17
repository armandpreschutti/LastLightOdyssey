import os
from PIL import Image, ImageDraw, ImageFilter

# Configuration
BASE_PATH = "C:/Users/arman/Documents/Godot/Projects/Last Light Odyssey/assets/sprites/ui/icons/abilities"
ICON_SIZE = (64, 64)

OFFICER_COLORS = {
    "captain": (255, 175, 0),    # Gold/Orange
    "scout":   (51, 255, 127),    # Green
    "tech":    (102, 230, 255),   # Cyan
    "medic":   (255, 127, 204),   # Pink
    "heavy":   (255, 102, 76),    # Red/Orange
    "sniper":  (153, 140, 178),   # Purple/Grey
}

def create_ability_icon(name, color, style="passive"):
    """
    style: 'base', 'active', 'passive', 'mastery'
    """
    img = Image.new('RGBA', ICON_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Glow effect
    glow_color = (*color, 60)
    if style == "active":
        # Diamond
        points = [(32, 4), (60, 32), (32, 60), (4, 32)]
    elif style == "passive":
        # Circle
        points = [8, 8, 56, 56]
    elif style == "mastery":
        # Hexagon
        points = [(32, 4), (56, 18), (56, 46), (32, 60), (8, 46), (8, 18)]
    else: # Base
        # Octagon
        points = [(20, 4), (44, 4), (60, 20), (60, 44), (44, 60), (20, 60), (4, 44), (4, 20)]

    # Draw Glow
    if style == "passive":
        draw.ellipse([4, 4, 60, 60], fill=glow_color)
    elif style == "active":
        draw.polygon([(32, 0), (64, 32), (32, 64), (0, 32)], fill=glow_color)
    else:
        draw.polygon(points, fill=glow_color)

    # Blur the glow slightly if needed (Pillow doesn't have great procedural blur, so we just layer)
    
    # Inner Shape
    inner_color = (*color, 255)
    border_color = (255, 255, 255, 180)
    
    if style == "passive":
        draw.ellipse([12, 12, 52, 52], fill=inner_color, outline=border_color, width=2)
        # Decorative inner ring
        draw.ellipse([24, 24, 40, 40], outline=(255, 255, 255, 100), width=1)
    elif style == "active":
        draw.polygon([(32, 10), (54, 32), (32, 54), (10, 32)], fill=inner_color, outline=border_color, width=2)
        # Crosshair detail
        draw.line([(32, 20), (32, 44)], fill=border_color, width=1)
        draw.line([(20, 32), (44, 32)], fill=border_color, width=1)
    elif style == "mastery":
        draw.polygon([(32, 10), (50, 20), (50, 44), (32, 54), (14, 44), (14, 20)], fill=inner_color, outline=border_color, width=2)
        # Core "Chip" detail
        draw.rectangle([28, 28, 36, 36], fill=(255, 255, 255, 150))
    else: # Base
        inner_points = [(22, 10), (42, 10), (54, 22), (54, 42), (42, 54), (22, 54), (10, 42), (10, 22)]
        draw.polygon(inner_points, fill=inner_color, outline=border_color, width=2)

    if not os.path.exists(BASE_PATH):
        os.makedirs(BASE_PATH)
        
    img.save(f"{BASE_PATH}/{name}.png")
    print(f"Generated {name}.png")

# Execute generation for all abilities
ABILITIES = {
    # Captain
    "captain": [
        ("execute", "base"),
        ("lead_by_example", "passive"),
        ("coordinate_fire", "active"),
        ("warlord", "mastery"),
        ("no_one_left_behind", "passive"),
        ("command_presence", "passive"),
    ],
    # Scout
    "scout": [
        ("overwatch", "base"),
        ("hit_and_run", "passive"),
        ("deep_scanner", "active"),
        ("killzone", "mastery"),
        ("phantom", "active"),
        ("untouchable", "passive"),
    ],
    # Tech
    "tech": [
        ("turret", "base"),
        ("combat_engineer", "passive"),
        ("sapper", "active"),
        ("twin_link", "mastery"),
        ("overclock", "active"),
        ("haywire_protocol", "active"),
    ],
    # Medic
    "medic": [
        ("patch", "base"),
        ("adrenaline_patch", "active"),
        ("field_surgeon", "passive"),
        ("miracle_worker", "mastery"),
        ("toxicologist", "passive"),
        ("stim_injector", "active"),
    ],
    # Heavy
    "heavy": [
        ("charge", "base"),
        ("bulldozer", "passive"),
        ("suppression_fire", "active"),
        ("juggernaut", "mastery"),
        ("rocket_salvo", "active"),
        ("intimidate", "passive"),
    ],
    # Sniper
    "sniper": [
        ("precision_shot", "base"),
        ("damn_good_ground", "passive"),
        ("snap_shot", "passive"),
        ("serial", "mastery"),
        ("apex_predator", "passive"),
        ("double_tap", "active"),
    ]
}

for officer, ability_list in ABILITIES.items():
    color = OFFICER_COLORS[officer]
    for ab_name, ab_style in ability_list:
        create_ability_icon(f"{officer}_{ab_name}", color, ab_style)

print("Icon generation complete.")
