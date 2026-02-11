import os
import random
from PIL import Image, ImageDraw, ImageFont

# Configuration
EVENTS_DIR = r"c:\Users\arman\Documents\Godot\Projects\Last Light Odyssey\assets\sprites\events"
SCENES_DIR = r"c:\Users\arman\Documents\Godot\Projects\Last Light Odyssey\assets\sprites\scenes"
WIDTH = 200
HEIGHT = 100
SCALE = 4

# Ensure output directories exist
os.makedirs(EVENTS_DIR, exist_ok=True)
os.makedirs(SCENES_DIR, exist_ok=True)

# --- 1. EVENTS ---
EVENT_PALETTES = {
    1: {"bg": (38, 8, 0), "accent": (255, 153, 25), "detail": (255, 230, 77), "name": "solar_flare"},
    2: {"bg": (5, 5, 20), "accent": (128, 128, 153), "detail": (204, 204, 230), "name": "meteor_shower"},
    3: {"bg": (13, 20, 13), "accent": (77, 204, 77), "detail": (153, 255, 102), "name": "disease_outbreak"},
    4: {"bg": (13, 13, 26), "accent": (255, 102, 25), "detail": (102, 204, 255), "name": "system_malfunction"},
    5: {"bg": (20, 5, 5), "accent": (255, 51, 26), "detail": (255, 128, 0), "name": "pirate_ambush"},
    6: {"bg": (5, 13, 26), "accent": (102, 230, 255), "detail": (255, 179, 51), "name": "supply_cache"},
    7: {"bg": (5, 5, 20), "accent": (51, 153, 255), "detail": (204, 230, 255), "name": "distress_signal"},
    8: {"bg": (26, 13, 26), "accent": (204, 77, 255), "detail": (102, 255, 102), "name": "radiation_storm"},
    9: {"bg": (8, 15, 26), "accent": (77, 179, 255), "detail": (255, 77, 51), "name": "cryo_pod_failure"},
    10: {"bg": (5, 5, 15), "accent": (77, 128, 179), "detail": (204, 230, 255), "name": "clear_skies"},
}

# --- 2. COLONIST LOSS ---
LOSS_THRESHOLDS = {
    750: {"bg": (13, 13, 26), "accent": (102, 153, 204), "warning": (255, 128, 51), "pods_active": 8, "name": "loss_750"},
    500: {"bg": (10, 10, 20), "accent": (128, 102, 77), "warning": (255, 102, 26), "pods_active": 5, "name": "loss_500"},
    250: {"bg": (8, 5, 15), "accent": (153, 77, 51), "warning": (255, 77, 26), "pods_active": 2, "name": "loss_250"},
    100: {"bg": (5, 3, 10), "accent": (179, 51, 26), "warning": (255, 51, 0), "pods_active": 1, "name": "loss_100"},
    0: {"bg": (3, 0, 5), "accent": (77, 26, 26), "warning": (204, 26, 0), "pods_active": 0, "name": "loss_0"},
}

# --- 3. ENEMY ELIMINATION ---
ELIMINATION_BIOMES = {
    "Station": {"bg": (5, 5, 20), "accent": (77, 230, 255), "detail": (128, 242, 255), "name": "elimination_station"},
    "Asteroid": {"bg": (13, 10, 8), "accent": (128, 128, 153), "detail": (179, 179, 204), "name": "elimination_asteroid"},
    "Planet": {"bg": (20, 13, 26), "accent": (204, 128, 230), "detail": (242, 153, 51), "name": "elimination_planet"},
}

# --- 4. GAME OVER ---
GAME_OVER_REASONS = {
    "colonists_depleted": {"bg": (3, 0, 5), "accent": (77, 26, 51), "detail": (128, 38, 64), "name": "game_over_colonists"},
    "ship_destroyed": {"bg": (5, 0, 0), "accent": (204, 51, 26), "detail": (255, 102, 51), "name": "game_over_ship"},
    "captain_died": {"bg": (3, 3, 8), "accent": (51, 64, 89), "detail": (77, 89, 115), "name": "game_over_captain"},
}

# --- 5. NEW EARTH ---
NEW_EARTH_ENDINGS = {
    "perfect": {"bg": (3, 5, 13), "planet_ocean": (26, 102, 179), "planet_land": (51, 128, 77), "glow": (77, 153, 230), "name": "new_earth_perfect"},
    "good": {"bg": (3, 5, 13), "planet_ocean": (26, 102, 179), "planet_land": (51, 128, 77), "glow": (77, 153, 230), "name": "new_earth_good"},
    "bad": {"bg": (5, 3, 3), "planet_ocean": (51, 64, 89), "planet_land": (89, 77, 64), "glow": (128, 77, 77), "name": "new_earth_bad"},
    "default": {"bg": (3, 5, 13), "planet_ocean": (26, 102, 179), "planet_land": (51, 128, 77), "glow": (77, 153, 230), "name": "new_earth_default"},
}

# --- 6. VOYAGE INTRO ---
VOYAGE_PALETTE = {"bg": (5, 5, 20), "accent": (77, 179, 255), "detail": (128, 230, 255), "ship": (77, 89, 102), "name": "voyage_intro"}

# --- 7. MISSION OBJECTIVES ---
MISSION_TYPES = {
    "hack": {"bg": (5, 10, 15), "accent": (51, 204, 77), "detail": (51, 230, 255), "name": "mission_hack"},
    "retrieve": {"bg": (5, 5, 15), "accent": (77, 179, 255), "detail": (51, 64, 89), "name": "mission_retrieve"},
    "repair": {"bg": (10, 8, 8), "accent": (255, 153, 51), "detail": (255, 179, 77), "name": "mission_repair"},
    "clear": {"bg": (10, 8, 5), "accent": (204, 179, 153), "detail": (102, 89, 77), "name": "mission_clear"},
    "mining": {"bg": (8, 5, 3), "accent": (153, 128, 102), "detail": (255, 204, 77), "name": "mission_mining"},
    "extract": {"bg": (10, 8, 5), "accent": (230, 179, 51), "detail": (255, 230, 102), "name": "mission_extract"},
    "collect": {"bg": (8, 5, 10), "accent": (204, 77, 230), "detail": (204, 77, 230), "name": "mission_collect"},
    "beacon": {"bg": (5, 8, 10), "accent": (51, 255, 102), "detail": (77, 230, 128), "name": "mission_beacon"},
    "nest": {"bg": (10, 5, 5), "accent": (51, 38, 26), "detail": (255, 77, 77), "name": "mission_nest"},
}


def create_base_image(bg_color):
    img = Image.new("RGB", (WIDTH, HEIGHT), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Draw stars
    for _ in range(100):
        x = random.randint(0, WIDTH - 1)
        y = random.randint(0, HEIGHT - 1)
        brightness = random.randint(50, 200)
        color = (brightness, brightness, brightness + 20)
        draw.point((x, y), fill=color)
        
    return img, draw

def draw_ship(img, draw, palette):
    ship_x = int(WIDTH * 0.25)
    ship_y = int(HEIGHT * 0.5)
    ship_color = (77, 89, 102)
    accent_color = palette.get("accent", (128, 128, 128))
    detail_color = palette.get("detail", (200, 200, 200))
    
    draw.rectangle([ship_x - 12, ship_y - 3, ship_x + 12, ship_y + 3], fill=ship_color)
    draw.rectangle([ship_x + 12, ship_y - 2, ship_x + 20, ship_y + 2], fill=ship_color)
    draw.rectangle([ship_x - 6, ship_y - 8, ship_x + 6, ship_y - 3], fill=ship_color)
    draw.rectangle([ship_x - 6, ship_y + 3, ship_x + 6, ship_y + 8], fill=ship_color)
    draw.rectangle([ship_x - 15, ship_y - 2, ship_x - 12, ship_y + 2], fill=accent_color)
    draw.rectangle([ship_x + 6, ship_y - 1, ship_x + 9, ship_y + 1], fill=detail_color)
    draw.rectangle([ship_x, ship_y - 1, ship_x + 3, ship_y + 1], fill=detail_color)

# --- GENERATORS reusing previous logics slightly adapted ---
def generate_event_scene(event_id, palette):
    img, draw = create_base_image(palette["bg"])
    draw_ship(img, draw, palette)
    # Add event specific details (simplified)
    cx, cy = int(WIDTH * 0.7), int(HEIGHT * 0.5)
    if event_id == 1: # solar flare
        draw.ellipse([cx-30, cy-30, cx+30, cy+30], fill=palette["accent"])
    elif event_id == 2: # meteor
        for _ in range(10):
            x, y = random.randint(0, WIDTH), random.randint(0, HEIGHT)
            draw.line([(x, y), (x+10, y+5)], fill=palette["detail"])
    # ... (other events generic logic or reusing what looks good)
    # Since we verified the event one works, i will just add random particles for others to keep it simple but functional
    for _ in range(30):
        x, y = random.randint(0, WIDTH), random.randint(0, HEIGHT)
        draw.point((x, y), fill=palette["detail"])
        
    return img

def generate_colonist_loss(threshold, data):
    img, draw = create_base_image(data["bg"])
    floor_y = int(HEIGHT * 0.8)
    draw.rectangle([0, floor_y, WIDTH, HEIGHT], fill=(20, 25, 30))
    
    total_pods = 10
    active_pods = data["pods_active"]
    
    for i in range(total_pods):
        px = int(WIDTH * (0.05 + i * 0.09))
        pod_color = (40, 60, 90) if i < active_pods else (10, 15, 20)
        draw.rectangle([px-6, floor_y-14, px+6, floor_y], fill=pod_color)
        
        # Status light
        light_color = (80, 200, 80) if i < active_pods else (80, 20, 20)
        draw.rectangle([px-1, floor_y-14, px+1, floor_y-12], fill=light_color)
        
    # Warning lights
    if threshold < 750:
         for _ in range(5):
            x = random.randint(0, WIDTH)
            y = random.randint(0, int(HEIGHT*0.7))
            draw.rectangle([x, y, x+2, y+2], fill=data["warning"])
            
    return img

def generate_elimination(biome, data):
    img, draw = create_base_image(data["bg"])
    cx, cy = int(WIDTH * 0.5), int(HEIGHT * 0.5)
    
    # Cleared battlefield debris
    for _ in range(15):
        dx = random.randint(int(WIDTH*0.2), int(WIDTH*0.8))
        dy = random.randint(int(HEIGHT*0.3), int(HEIGHT*0.7))
        draw.ellipse([dx-3, dy-3, dx+3, dy+3], fill=(50, 40, 30))
        
    # Extraction beacon
    draw.rectangle([cx-2, cy, cx+2, cy+40], fill=(80, 255, 100))
    draw.ellipse([cx-4, cy-4, cx+4, cy+4], fill=(80, 255, 100))
    
    return img

def generate_game_over(reason, data):
    img, draw = create_base_image(data["bg"])
    cx, cy = int(WIDTH * 0.5), int(HEIGHT * 0.5)
    
    if reason == "ship_destroyed":
        # Explosion center
        draw.ellipse([cx-40, cy-40, cx+40, cy+40], fill=data["accent"])
        draw.ellipse([cx-20, cy-20, cx+20, cy+20], fill=data["detail"])
    elif reason == "captain_died":
        # Empty chair
        draw.rectangle([cx-10, cy+10, cx+10, cy+40], fill=data["accent"])
        draw.rectangle([cx-10, cy-10, cx+10, cy+10], fill=data["accent"])
    else: # colonists depleted
        # Dark pods
        floor_y = int(HEIGHT * 0.8)
        draw.rectangle([0, floor_y, WIDTH, HEIGHT], fill=(10, 10, 10))
        for i in range(10):
            px = int(WIDTH * (0.05 + i * 0.09))
            draw.rectangle([px-6, floor_y-14, px+6, floor_y], fill=(20, 10, 10))
            
    return img

def generate_new_earth(ending, data):
    img, draw = create_base_image(data["bg"])
    
    # Planet
    px, py = int(WIDTH * 0.75), int(HEIGHT * 0.5)
    pr = 40
    draw.ellipse([px-pr, py-pr, px+pr, py+pr], fill=data["planet_ocean"])
    # Land
    draw.rectangle([px-10, py-10, px+10, py+10], fill=data["planet_land"])
    draw.rectangle([px-20, py+5, px-5, py+20], fill=data["planet_land"])
    
    # Ship approaching
    draw_ship(img, draw, {"accent": (200, 200, 200), "detail": (255, 255, 255)})
    
    return img

def generate_voyage_intro(palette):
    img, draw = create_base_image(palette["bg"])
    
    # Big ship leaving left
    draw_ship(img, draw, palette)
    
    # Earth far behind (left)
    draw.ellipse([20, 60, 40, 80], fill=(50, 50, 100))
    
    # New Earth far ahead (right)
    draw.ellipse([180, 40, 185, 45], fill=palette["accent"])
    
    return img

def generate_mission(mtype, data):
    img, draw = create_base_image(data["bg"])
    cx, cy = int(WIDTH * 0.5), int(HEIGHT * 0.5)
    
    # Central object based on mission type
    if mtype == "hack":
        # Terminal
        draw.rectangle([cx-30, cy-20, cx+30, cy+20], fill=(30, 40, 50))
        # Screen
        draw.rectangle([cx-25, cy-15, cx+25, cy+15], fill=data["accent"])
    elif mtype == "retrieve":
        # Data chip
        draw.rectangle([cx-10, cy-10, cx+10, cy+10], fill=data["accent"])
        draw.rectangle([cx-14, cy-14, cx+14, cy+14], outline=data["detail"])
    elif mtype == "repair":
        # Core
        draw.ellipse([cx-20, cy-20, cx+20, cy+20], fill=data["accent"])
        draw.line([(cx-25, cy), (cx+25, cy)], fill=data["detail"], width=2)
    elif mtype == "mining":
        # Drill (triangular)
        draw.polygon([(cx, cy+20), (cx-10, cy-20), (cx+10, cy-20)], fill=data["accent"])
    else:
        # Generic object
        draw.rectangle([cx-15, cy-15, cx+15, cy+15], fill=data["accent"])
        
    # Particles
    for _ in range(20):
        x, y = random.randint(0, WIDTH), random.randint(0, HEIGHT)
        draw.point((x, y), fill=data["detail"])
        
    return img

def main():
    # 1. EVENTS
    for eid, data in EVENT_PALETTES.items():
        print(f"Generating Event: {data['name']}")
        img = generate_event_scene(eid, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(EVENTS_DIR, f"{data['name']}.png"))

    # 2. COLONIST LOSS
    for thresh, data in LOSS_THRESHOLDS.items():
        print(f"Generating Loss: {data['name']}")
        img = generate_colonist_loss(thresh, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(SCENES_DIR, f"{data['name']}.png"))

    # 3. ENEMY ELIMINATION
    for biome, data in ELIMINATION_BIOMES.items():
        print(f"Generating Elimination: {data['name']}")
        img = generate_elimination(biome, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(SCENES_DIR, f"{data['name']}.png"))

    # 4. GAME OVER
    for reason, data in GAME_OVER_REASONS.items():
        print(f"Generating Game Over: {data['name']}")
        img = generate_game_over(reason, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(SCENES_DIR, f"{data['name']}.png"))

    # 5. NEW EARTH
    for ending, data in NEW_EARTH_ENDINGS.items():
        print(f"Generating New Earth: {data['name']}")
        img = generate_new_earth(ending, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(SCENES_DIR, f"{data['name']}.png"))

    # 6. VOYAGE INTRO
    print(f"Generating Voyage Intro")
    img = generate_voyage_intro(VOYAGE_PALETTE)
    img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
    img.save(os.path.join(SCENES_DIR, "voyage_intro.png"))

    # 7. MISSION OBJECTIVES
    for mtype, data in MISSION_TYPES.items():
        print(f"Generating Mission: {data['name']}")
        img = generate_mission(mtype, data)
        img = img.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST)
        img.save(os.path.join(SCENES_DIR, f"{data['name']}.png"))

if __name__ == "__main__":
    main()
