extends Control
## Biome Background - Draws repeating static patterns based on biome type
## Provides visual context for the tactical mission environment

const PATTERN_TILE_SIZE: int = 128  # Size of each pattern tile

var current_biome: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION
var biome_theme: Dictionary = BiomeConfig.STATION_THEME


func _ready() -> void:
	# Ensure we cover the full screen
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	# Initialize with default biome
	set_biome(BiomeConfig.BiomeType.STATION)
	
	# Redraw when viewport size changes
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	queue_redraw()


## Set the biome type and update the pattern
func set_biome(biome_type: BiomeConfig.BiomeType) -> void:
	current_biome = biome_type
	biome_theme = BiomeConfig.get_theme(biome_type)
	queue_redraw()


func _draw() -> void:
	# Get the actual size of this control (should be full screen)
	var control_size = size
	if control_size.x <= 0 or control_size.y <= 0:
		# Fallback to viewport size if control size not set yet
		control_size = get_viewport_rect().size
	
	# Calculate how many tiles we need to draw
	var tiles_x = int(ceil(control_size.x / PATTERN_TILE_SIZE)) + 2
	var tiles_y = int(ceil(control_size.y / PATTERN_TILE_SIZE)) + 2
	
	# Draw repeating pattern
	for x in range(tiles_x):
		for y in range(tiles_y):
			var tile_pos = Vector2(x * PATTERN_TILE_SIZE, y * PATTERN_TILE_SIZE)
			var tile_rect = Rect2(tile_pos, Vector2(PATTERN_TILE_SIZE, PATTERN_TILE_SIZE))
			_draw_pattern_tile(tile_rect, x, y)


## Draw a single pattern tile based on biome type
func _draw_pattern_tile(rect: Rect2, tile_x: int, tile_y: int) -> void:
	match current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_pattern(rect, tile_x, tile_y)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_pattern(rect, tile_x, tile_y)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_pattern(rect, tile_x, tile_y)
		_:
			_draw_station_pattern(rect, tile_x, tile_y)  # Default fallback


## Draw Station biome pattern - Industrial grid with cyan accents
func _draw_station_pattern(rect: Rect2, tile_x: int, tile_y: int) -> void:
	var pos = rect.position
	var base_color = biome_theme.get("floor_base", Color(0.10, 0.11, 0.14))
	var accent_color = biome_theme.get("accent_dim", Color(0.2, 0.6, 0.75, 0.6))
	var panel_color = biome_theme.get("floor_accent", Color(0.06, 0.07, 0.10, 0.8))
	
	# Base fill
	draw_rect(rect, base_color)
	
	# Grid lines (subtle panel seams)
	var grid_color = panel_color
	# Horizontal lines
	for i in range(0, PATTERN_TILE_SIZE + 1, 32):
		draw_line(
			pos + Vector2(0, i),
			pos + Vector2(PATTERN_TILE_SIZE, i),
			grid_color,
			1.0
		)
	# Vertical lines
	for i in range(0, PATTERN_TILE_SIZE + 1, 32):
		draw_line(
			pos + Vector2(i, 0),
			pos + Vector2(i, PATTERN_TILE_SIZE),
			grid_color,
			1.0
		)
	
	# Occasional cyan accent lines (based on tile position for variation)
	var hash_val = (tile_x * 73 + tile_y * 137) % 100
	if hash_val < 15:  # 15% of tiles get accent
		var accent_y = (hash_val % 4) * 32 + 16
		draw_line(
			pos + Vector2(0, accent_y),
			pos + Vector2(PATTERN_TILE_SIZE, accent_y),
			accent_color,
			2.0
		)
	
	# Panel corner highlights (subtle)
	if hash_val > 85:
		var corner_size = 8
		var corner_color = accent_color.darkened(0.5)
		# Top-left corner
		draw_line(pos + Vector2(0, 0), pos + Vector2(corner_size, 0), corner_color, 1.5)
		draw_line(pos + Vector2(0, 0), pos + Vector2(0, corner_size), corner_color, 1.5)


## Draw Asteroid biome pattern - Rocky texture with blue mineral accents
func _draw_asteroid_pattern(rect: Rect2, tile_x: int, tile_y: int) -> void:
	var pos = rect.position
	var base_color = biome_theme.get("floor_base", Color(0.15, 0.12, 0.1))
	var accent_color = biome_theme.get("floor_accent", Color(0.12, 0.1, 0.08, 0.6))
	var mineral_color = Color(0.3, 0.4, 0.6, 0.4)  # Blue mineral
	
	# Base fill
	draw_rect(rect, base_color)
	
	# Rocky texture - irregular lines and cracks
	var hash_val = (tile_x * 73 + tile_y * 137) % 100
	var variation = hash_val % 4
	
	# Draw irregular rock texture lines
	for i in range(3 + variation):
		var start_x = (hash_val * 7 + i * 23) % PATTERN_TILE_SIZE
		var start_y = (hash_val * 11 + i * 31) % PATTERN_TILE_SIZE
		var end_x = (hash_val * 13 + i * 37) % PATTERN_TILE_SIZE
		var end_y = (hash_val * 17 + i * 41) % PATTERN_TILE_SIZE
		
		draw_line(
			pos + Vector2(start_x, start_y),
			pos + Vector2(end_x, end_y),
			accent_color,
			1.5
		)
	
	# Blue mineral veins (occasional)
	if hash_val < 20:  # 20% of tiles get mineral accents
		var vein_count = 1 + (hash_val % 3)
		for i in range(vein_count):
			var vein_x = (hash_val * 19 + i * 29) % PATTERN_TILE_SIZE
			var vein_y = (hash_val * 23 + i * 43) % PATTERN_TILE_SIZE
			var vein_length = 20 + (hash_val % 30)
			
			# Draw mineral vein
			draw_line(
				pos + Vector2(vein_x, vein_y),
				pos + Vector2(vein_x + vein_length, vein_y + vein_length * 0.3),
				mineral_color,
				2.5
			)
			# Add glow effect
			draw_circle(pos + Vector2(vein_x, vein_y), 3, mineral_color.lightened(0.3))


## Draw Planet biome pattern - Alien organic with bioluminescent spots
func _draw_planet_pattern(rect: Rect2, tile_x: int, tile_y: int) -> void:
	var pos = rect.position
	var base_color = biome_theme.get("floor_base", Color(0.12, 0.18, 0.10))
	var accent_color = biome_theme.get("floor_accent", Color(0.08, 0.12, 0.06, 0.6))
	var biolum_color = biome_theme.get("biolum_yellow", Color(1.0, 0.85, 0.30, 0.85))
	var plant_color = biome_theme.get("alien_plant", Color(0.30, 0.55, 0.50))
	
	# Base fill (dark alien ground)
	draw_rect(rect, base_color)
	
	# Organic texture - curved lines and growth patterns
	var hash_val = (tile_x * 73 + tile_y * 137) % 100
	
	# Draw organic growth lines (curved, flowing)
	for i in range(2 + (hash_val % 3)):
		var center_x = (hash_val * 7 + i * 23) % PATTERN_TILE_SIZE
		var center_y = (hash_val * 11 + i * 31) % PATTERN_TILE_SIZE
		var radius = 15 + (hash_val % 20)
		
		# Draw partial circle arcs (organic curves)
		for angle in range(0, 360, 30):
			var angle_rad = deg_to_rad(angle)
			var next_angle_rad = deg_to_rad(angle + 30)
			var p1 = pos + Vector2(center_x, center_y) + Vector2(cos(angle_rad) * radius, sin(angle_rad) * radius)
			var p2 = pos + Vector2(center_x, center_y) + Vector2(cos(next_angle_rad) * radius, sin(next_angle_rad) * radius)
			draw_line(p1, p2, accent_color, 1.0)
	
	# Bioluminescent spots (glowing dots)
	if hash_val < 25:  # 25% of tiles get bioluminescent spots
		var spot_count = 1 + (hash_val % 4)
		for i in range(spot_count):
			var spot_x = (hash_val * 19 + i * 29) % PATTERN_TILE_SIZE
			var spot_y = (hash_val * 23 + i * 43) % PATTERN_TILE_SIZE
			var spot_size = 2 + (hash_val % 3)
			
			# Outer glow
			draw_circle(pos + Vector2(spot_x, spot_y), spot_size + 2, biolum_color.darkened(0.3))
			# Inner bright spot
			draw_circle(pos + Vector2(spot_x, spot_y), spot_size, biolum_color)
	
	# Alien plant tendrils (occasional)
	if hash_val > 70:
		var tendril_start_x = (hash_val * 13) % PATTERN_TILE_SIZE
		var tendril_start_y = (hash_val * 17) % PATTERN_TILE_SIZE
		var tendril_length = 30 + (hash_val % 40)
		
		# Draw curved tendril
		for i in range(tendril_length):
			var t = float(i) / tendril_length
			var offset_x = tendril_start_x + i * 0.8
			var offset_y = tendril_start_y + sin(t * PI * 2) * 8
			var next_offset_x = tendril_start_x + (i + 1) * 0.8
			var next_offset_y = tendril_start_y + sin((t + 1.0 / tendril_length) * PI * 2) * 8
			
			if next_offset_x < PATTERN_TILE_SIZE:
				draw_line(
					pos + Vector2(offset_x, offset_y),
					pos + Vector2(next_offset_x, next_offset_y),
					plant_color.darkened(0.2),
					1.5
				)
