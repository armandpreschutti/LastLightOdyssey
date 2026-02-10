class_name BiomeConfig
extends RefCounted
## Biome configuration system for tactical maps
## Defines visual themes, map sizes, and enemy distributions for each biome type

enum BiomeType { STATION, ASTEROID, PLANET }

#region Color Themes

## Station biome - Dark industrial metal with cyan/teal accent lighting
const STATION_THEME := {
	# Floor colors - darker metal panels (more contrast with walls)
	"floor_base": Color(0.10, 0.11, 0.14),         # Dark blue-gray metal floor
	"floor_var": Color(0.12, 0.13, 0.17),          # Slightly lighter panel variation
	"floor_accent": Color(0.06, 0.07, 0.10, 0.8),  # Dark panel seam/shadow
	"floor_highlight": Color(0.18, 0.20, 0.26),    # Panel edge highlight
	
	# Wall colors - LIGHTER industrial metal (contrast with dark floor)
	"wall": Color(0.28, 0.32, 0.40),               # Lighter blue-gray metal wall
	"wall_highlight": Color(0.45, 0.50, 0.58),     # Bright wall edge highlight
	"wall_shadow": Color(0.12, 0.14, 0.18),        # Deep wall shadow
	"wall_panel": Color(0.22, 0.26, 0.34),         # Recessed panel color
	
	# Accent lighting - cyan/teal glow (brighter)
	"accent_glow": Color(0.3, 0.9, 1.0, 0.9),      # Bright cyan accent
	"accent_dim": Color(0.2, 0.6, 0.75, 0.6),      # Dimmer cyan for subtle lights
	
	# Extraction zone - green safety zone
	"extraction": Color(0.06, 0.18, 0.10),         # Dark green safe zone
	"extraction_glow": Color(0.12, 0.35, 0.18),    # Brighter extraction center
	"extraction_marker": Color(0.3, 0.95, 0.5),    # Corner marker color (brighter)
	
	# Cover objects - MORE VIBRANT cargo crates and barriers
	"cover_main": Color(0.65, 0.45, 0.25),         # Bright orange-brown cargo crate
	"cover_dark": Color(0.45, 0.30, 0.15),         # Crate shadow
	"cover_light": Color(0.80, 0.60, 0.35),        # Crate highlight (brighter)
	"cover_metal": Color(0.50, 0.55, 0.60),        # Light gray metal container
	"cover_green": Color(0.35, 0.55, 0.30),        # Brighter green supply crate
	"cover_green_dark": Color(0.22, 0.38, 0.18),   # Green crate shadow
	"cover_green_light": Color(0.45, 0.68, 0.38),  # Green crate highlight
	
	# Decoration colors
	"blood": Color(0.55, 0.08, 0.08, 0.75),        # Blood splatter (more visible)
	"rust": Color(0.45, 0.25, 0.12, 0.5),          # Rust stains
	"cables": Color(0.08, 0.10, 0.14),             # Dark cables/wires
	"debris": Color(0.30, 0.33, 0.38),             # Metal debris
	
	# Fog and atmosphere
	"fog": Color(0.01, 0.02, 0.04),                # Dark blue-black fog
	"ambient_tint": Color(0.4, 0.7, 0.9, 0.03),    # Cool blue ambient tint
}

## Asteroid biome - Rocky browns with blue accents
const ASTEROID_THEME := {
	"floor_base": Color(0.15, 0.12, 0.1),          # Dark rocky brown
	"floor_var": Color(0.2, 0.16, 0.12),           # Lighter rock variation
	"floor_accent": Color(0.12, 0.1, 0.08, 0.6),   # Dark crevice color
	"wall": Color(0.28, 0.22, 0.18),               # Dark brown rock
	"wall_highlight": Color(0.38, 0.32, 0.26),     # Rock highlight
	"wall_shadow": Color(0.12, 0.1, 0.08),         # Deep shadow
	"extraction": Color(0.1, 0.15, 0.25),          # Blue-tinted safe zone
	"extraction_glow": Color(0.15, 0.25, 0.4),     # Blue extraction glow
	"extraction_marker": Color(0.4, 0.6, 0.9),     # Blue marker color
	"cover_main": Color(0.35, 0.28, 0.22),         # Brown rock
	"cover_dark": Color(0.22, 0.18, 0.14),         # Rock shadow
	"cover_light": Color(0.45, 0.38, 0.32),        # Rock highlight
	"fog": Color(0.02, 0.02, 0.04),                # Dark blue-tinted fog
	"ambient_tint": Color(0.4, 0.5, 0.8, 0.08),    # Cool blue tint
}

## Planet biome - Hostile alien world with alien grass and bioluminescence
const PLANET_THEME := {
	# Floor colors - alien grass/vegetation terrain
	"floor_base": Color(0.12, 0.18, 0.10),         # Dark green grass base
	"floor_var": Color(0.15, 0.22, 0.12),          # Slightly lighter grass variation
	"floor_accent": Color(0.08, 0.12, 0.06, 0.6),  # Darker grass shadow/seam
	"floor_highlight": Color(0.18, 0.26, 0.14),    # Lighter grass highlight
	
	# Wall colors - alien purple/magenta crystal formations
	"wall": Color(0.45, 0.28, 0.50),               # Purple alien rock/crystal
	"wall_highlight": Color(0.65, 0.45, 0.70),     # Bright purple highlight
	"wall_shadow": Color(0.25, 0.15, 0.30),        # Deep purple shadow
	"wall_crystal": Color(0.70, 0.40, 0.75),       # Bright crystal accent
	"wall_glow": Color(0.80, 0.50, 0.90, 0.6),     # Crystal glow effect
	
	# Accent colors - bioluminescent orange/yellow
	"biolum_orange": Color(0.95, 0.60, 0.15, 0.9), # Bright orange glow
	"biolum_yellow": Color(1.0, 0.85, 0.30, 0.85), # Yellow mushroom glow
	"biolum_pink": Color(0.95, 0.45, 0.65, 0.8),   # Pink accent glow
	
	# Extraction zone - safe zone with alien tech
	"extraction": Color(0.15, 0.30, 0.28),         # Dark teal safe zone
	"extraction_glow": Color(0.25, 0.50, 0.45),    # Brighter teal center
	"extraction_marker": Color(0.4, 0.95, 0.85),   # Bright cyan marker
	
	# Cover objects - alien mushrooms and crystals
	"cover_main": Color(0.35, 0.55, 0.58),         # Teal mushroom cap
	"cover_dark": Color(0.22, 0.38, 0.42),         # Mushroom shadow
	"cover_light": Color(0.50, 0.70, 0.72),        # Mushroom highlight
	"cover_stem": Color(0.45, 0.40, 0.35),         # Mushroom stem (tan)
	"cover_crystal": Color(0.55, 0.35, 0.60),      # Purple crystal cover
	"cover_crystal_glow": Color(0.75, 0.50, 0.80), # Crystal highlight
	"cover_orange": Color(0.85, 0.55, 0.20),       # Orange mushroom
	"cover_orange_glow": Color(1.0, 0.70, 0.30),   # Orange glow
	
	# Decoration colors
	"alien_plant": Color(0.30, 0.55, 0.50),        # Teal alien vegetation
	"alien_plant_dark": Color(0.20, 0.40, 0.38),   # Dark vegetation
	"spore": Color(0.90, 0.75, 0.40, 0.7),         # Floating spore particles
	"tendril": Color(0.50, 0.35, 0.55),            # Purple tendrils/vines
	
	# Fog and atmosphere - pink/purple alien sky influence
	"fog": Color(0.08, 0.05, 0.10),                # Dark purple-tinted fog
	"ambient_tint": Color(0.7, 0.5, 0.8, 0.04),    # Purple/pink ambient tint
}

#endregion

#region Map Size Configuration

const MAP_SIZES := {
	BiomeType.STATION: { "min": 17, "max": 20 },
	BiomeType.ASTEROID: { "min": 14, "max": 17 },
	BiomeType.PLANET: { "min": 24, "max": 27 },
}

#endregion

#region Enemy Configuration

const ENEMY_CONFIG := {
	BiomeType.STATION: {
		"min_enemies": 4,
		"max_enemies": 6,
		"heavy_chance": 0.30,  # 30% chance for heavy
	},
	BiomeType.ASTEROID: {
		"min_enemies": 3,
		"max_enemies": 5,
		"heavy_chance": 0.50,  # 50% chance for heavy
	},
	BiomeType.PLANET: {
		"min_enemies": 5,
		"max_enemies": 8,
		"heavy_chance": 0.20,  # 20% chance for heavy
	},
}

#endregion

#region Loot Configuration

const LOOT_CONFIG := {
	BiomeType.STATION: {
		"min_fuel": 2,
		"max_fuel": 4,
		"min_scrap": 4,
		"max_scrap": 6,
	},
	BiomeType.ASTEROID: {
		"min_fuel": 1,
		"max_fuel": 3,
		"min_scrap": 5,
		"max_scrap": 8,  # More scrap in mines
	},
	BiomeType.PLANET: {
		"min_fuel": 3,
		"max_fuel": 5,
		"min_scrap": 3,
		"max_scrap": 5,
	},
}

#endregion

#region Layout Configuration

const LAYOUT_CONFIG := {
	BiomeType.STATION: {
		"type": "bsp",
		"min_room_size": 5,
		"max_room_size": 9,
		"corridor_width": 2,
		"cover_density": 0.08,  # Moderate cover
	},
	BiomeType.ASTEROID: {
		"type": "cave",
		"initial_fill_chance": 0.38,
		"smoothing_iterations": 4,
		"wall_threshold": 5,  # Need 5+ wall neighbors to become wall (more open caves)
		"cover_density": 0.04,  # Less cover in caves
	},
	BiomeType.PLANET: {
		"type": "open",
		"obstacle_clusters": 8,
		"cluster_size_min": 2,
		"cluster_size_max": 5,
		"cover_density": 0.12,  # More cover scattered
	},
}

#endregion

#region Static Helper Functions

static func get_theme(biome_type: BiomeType) -> Dictionary:
	match biome_type:
		BiomeType.STATION:
			return STATION_THEME
		BiomeType.ASTEROID:
			return ASTEROID_THEME
		BiomeType.PLANET:
			return PLANET_THEME
		_:
			return STATION_THEME


static func get_map_size(biome_type: BiomeType, node_index: int = 0, total_nodes: int = 50) -> Vector2i:
	var config = MAP_SIZES.get(biome_type, MAP_SIZES[BiomeType.STATION])
	
	# Calculate size scaling based on voyage progression
	# Maps get slightly bigger as difficulty ramps up
	# Scale factor: +1 tile per ~12 nodes, capped at +4 tiles total
	var progress_ratio: float = float(node_index) / float(total_nodes)
	var size_increase: int = int(progress_ratio * 4.0)  # Max +4 tiles by end of voyage
	
	# Apply scaling to both min and max
	var scaled_min = config["min"] + size_increase
	var scaled_max = config["max"] + size_increase
	
	# Cap maximum size to prevent maps from getting too large
	# Station: max 24, Asteroid: max 21, Planet: max 31
	var max_cap: int
	match biome_type:
		BiomeType.STATION:
			max_cap = 24
		BiomeType.ASTEROID:
			max_cap = 21
		BiomeType.PLANET:
			max_cap = 31
		_:
			max_cap = 24
	
	scaled_min = mini(scaled_min, max_cap)
	scaled_max = mini(scaled_max, max_cap)
	
	# Ensure min doesn't exceed max
	scaled_min = mini(scaled_min, scaled_max)
	
	var size = randi_range(scaled_min, scaled_max)
	return Vector2i(size, size)


static func get_enemy_config(biome_type: BiomeType, difficulty_multiplier: float = 1.0) -> Dictionary:
	var base_config = ENEMY_CONFIG.get(biome_type, ENEMY_CONFIG[BiomeType.STATION]).duplicate()
	
	# Scale enemy counts based on difficulty
	var scaled_min = int(base_config["min_enemies"] * difficulty_multiplier)
	var scaled_max = int(base_config["max_enemies"] * difficulty_multiplier)
	
	# Cap maximum at reasonable limit (15 enemies max)
	scaled_min = mini(scaled_min, base_config["min_enemies"] * 2)  # Cap at 2x base
	scaled_max = mini(scaled_max, 15)  # Hard cap at 15 enemies
	
	# Ensure minimum is at least base value
	scaled_min = maxi(scaled_min, base_config["min_enemies"])
	scaled_max = maxi(scaled_max, base_config["max_enemies"])
	
	base_config["min_enemies"] = scaled_min
	base_config["max_enemies"] = scaled_max
	
	# Note: heavy_chance is no longer used for spawn selection
	# Enemy spawn rates are now calculated based on voyage progression in tactical_controller.gd
	# Keeping base heavy_chance value in config for potential future use
	# (No scaling applied since it's not used)
	
	return base_config


static func get_loot_config(biome_type: BiomeType) -> Dictionary:
	return LOOT_CONFIG.get(biome_type, LOOT_CONFIG[BiomeType.STATION])


static func get_layout_config(biome_type: BiomeType) -> Dictionary:
	return LAYOUT_CONFIG.get(biome_type, LAYOUT_CONFIG[BiomeType.STATION])


static func get_biome_name(biome_type: BiomeType) -> String:
	match biome_type:
		BiomeType.STATION:
			return "Derelict Station"
		BiomeType.ASTEROID:
			return "Asteroid Mine"
		BiomeType.PLANET:
			return "Planetary Surface"
		_:
			return "Unknown"


static func get_random_biome() -> BiomeType:
	var roll = randi() % 3
	return roll as BiomeType

#endregion
