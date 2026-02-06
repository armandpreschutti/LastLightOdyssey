extends Node2D
## Tactical Map - Grid management, fog of war, and pathfinding
## Supports biome-specific visual themes

signal tile_clicked(grid_pos: Vector2i)

const TILE_SIZE: int = 32
const DEFAULT_MAP_SIZE: int = 20

enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }

# Current map dimensions (set dynamically based on biome)
var map_width: int = DEFAULT_MAP_SIZE
var map_height: int = DEFAULT_MAP_SIZE

# Current biome theme (default to station)
var current_theme: Dictionary = BiomeConfig.STATION_THEME
var current_biome: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION

# Gameplay highlight colors (consistent across biomes, high visibility)
const COLOR_MOVEMENT_RANGE := Color(0.3, 0.6, 0.9, 0.35)  # Brighter blue movement highlight
const COLOR_EXECUTE_RANGE := Color(0.9, 0.2, 0.2, 0.35)  # Red execute range highlight
const COLOR_HOVER := Color(1.0, 0.9, 0.4, 0.4)     # Brighter yellow hover

@onready var units_container: Node2D = $Units
@onready var interactables_container: Node2D = $Interactables

var astar: AStarGrid2D
var tile_data: Dictionary = {}  # Vector2i -> TileType
var revealed_tiles: Dictionary = {}  # Vector2i -> bool
var movement_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within movement range)
var execute_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within execute range)
var hovered_tile: Vector2i = Vector2i(-1, -1)  # Currently hovered tile


func _ready() -> void:
	_setup_astar()


func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, map_width, map_height)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


## Set the biome theme for rendering
func set_biome(biome_type: BiomeConfig.BiomeType) -> void:
	current_biome = biome_type
	current_theme = BiomeConfig.get_theme(biome_type)


## Set map dimensions
func set_map_dimensions(width: int, height: int) -> void:
	map_width = width
	map_height = height
	# Reinitialize A* with new dimensions
	_setup_astar()


func initialize_map(layout: Dictionary, biome_type: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION) -> void:
	set_biome(biome_type)
	tile_data = layout
	_update_astar_solids()
	_initialize_fog()
	queue_redraw()


func _update_astar_solids() -> void:
	for pos in tile_data:
		var is_solid = tile_data[pos] == TileType.WALL or tile_data[pos] == TileType.HALF_COVER
		astar.set_point_solid(pos, is_solid)


func _initialize_fog() -> void:
	for x in range(map_width):
		for y in range(map_height):
			revealed_tiles[Vector2i(x, y)] = false


func reveal_around(center: Vector2i, sight_range: int) -> void:
	var changed = false
	for x in range(center.x - sight_range, center.x + sight_range + 1):
		for y in range(center.y - sight_range, center.y + sight_range + 1):
			var pos = Vector2i(x, y)
			if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
				continue
			var distance = abs(pos.x - center.x) + abs(pos.y - center.y)
			if distance <= sight_range:
				if not revealed_tiles.get(pos, false):
					revealed_tiles[pos] = true
					changed = true
					_reveal_interactables_at(pos)

	if changed:
		queue_redraw()


func _reveal_interactables_at(pos: Vector2i) -> void:
	var world_pos = grid_to_world(pos)
	for interactable in interactables_container.get_children():
		if interactable.position.distance_to(world_pos) < TILE_SIZE / 2:
			interactable.visible = true


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if astar.is_point_solid(to):
		return PackedVector2Array()

	# Temporarily unmark start position so unit can path from its own tile
	var start_was_solid = astar.is_point_solid(from)
	if start_was_solid:
		astar.set_point_solid(from, false)

	var path = astar.get_point_path(from, to)

	if start_was_solid:
		astar.set_point_solid(from, true)

	return path


func get_movement_cost(from: Vector2i, to: Vector2i) -> int:
	var path = find_path(from, to)
	if path.is_empty():
		return -1
	return path.size() - 1


func is_tile_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	return not astar.is_point_solid(pos)


## Check if a tile blocks line of sight (only walls block LOS, not cover)
func blocks_line_of_sight(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return true  # Out of bounds blocks LOS
	return tile_data.get(pos, TileType.FLOOR) == TileType.WALL


func is_extraction_tile(pos: Vector2i) -> bool:
	return tile_data.get(pos, TileType.FLOOR) == TileType.EXTRACTION


func is_tile_revealed(pos: Vector2i) -> bool:
	return revealed_tiles.get(pos, false)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2, grid_pos.y * TILE_SIZE + TILE_SIZE / 2)


func _draw() -> void:
	# Draw all tiles
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			if not revealed_tiles.get(pos, false):
				# Fog of war
				draw_rect(rect, current_theme["fog"])
			else:
				# Get tile type and draw with variation
				var tile_type = tile_data.get(pos, TileType.FLOOR)
				_draw_tile(x, y, rect, tile_type)
				
				# Movement range highlight
				if movement_range_tiles.get(pos, false):
					draw_rect(rect, COLOR_MOVEMENT_RANGE)
				
				# Execute range highlight (red)
				if execute_range_tiles.get(pos, false):
					draw_rect(rect, COLOR_EXECUTE_RANGE)
				
				# Hover effect
				if pos == hovered_tile:
					draw_rect(rect, COLOR_HOVER)


## Draw a single tile with visual variation based on biome theme
func _draw_tile(x: int, y: int, rect: Rect2, tile_type: TileType) -> void:
	# Use position for deterministic "randomness"
	var hash_val = (x * 73 + y * 137) % 100
	
	match tile_type:
		TileType.FLOOR:
			_draw_floor_tile(rect, hash_val)
		TileType.WALL:
			_draw_wall_tile(x, y, rect, hash_val)
		TileType.EXTRACTION:
			_draw_extraction_tile(rect, hash_val)
		TileType.HALF_COVER:
			_draw_cover_tile(rect, hash_val)


## Draw floor tile with biome-specific appearance
func _draw_floor_tile(rect: Rect2, hash_val: int) -> void:
	# Vary floor color slightly based on position
	var base_color = current_theme["floor_base"] if hash_val < 60 else current_theme["floor_var"]
	draw_rect(rect, base_color)
	
	# Add biome-specific detail marks
	match current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_floor_details(rect, hash_val)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_floor_details(rect, hash_val)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_floor_details(rect, hash_val)


func _draw_station_floor_details(rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var panel_line_color = current_theme.get("floor_accent", Color(0.06, 0.07, 0.10, 0.8))
	
	# Simple panel border lines (every tile has these for consistent grid look)
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), panel_line_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), panel_line_color, 1.0)
	
	# Only 2 decoration types - keep it simple (about 15% of tiles get decoration)
	if hash_val < 8:
		# Blood splatter
		var blood_color = current_theme.get("blood", Color(0.55, 0.08, 0.08, 0.75))
		draw_circle(pos + Vector2(14, 16), 3, blood_color)
		draw_circle(pos + Vector2(18, 18), 2, blood_color.darkened(0.2))
	elif hash_val > 92:
		# Cyan accent light strip
		var accent_color = current_theme.get("accent_dim", Color(0.2, 0.6, 0.75, 0.6))
		draw_rect(Rect2(pos.x + 4, pos.y + 14, 24, 4), accent_color)


func _draw_asteroid_floor_details(rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var accent_color = current_theme.get("floor_accent", Color(0.12, 0.1, 0.08, 0.6))
	
	# Simple rocky texture lines (subtle grid-like cracks)
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), accent_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), accent_color, 1.0)
	
	# Only 2 decoration types - keep it simple (about 15% of tiles get decoration)
	if hash_val < 8:
		# Rocky crevice/crack
		draw_line(pos + Vector2(6, 8), pos + Vector2(26, 24), accent_color.darkened(0.3), 1.5)
	elif hash_val > 92:
		# Small blue mineral shimmer
		draw_circle(pos + Vector2(16, 16), 2, Color(0.3, 0.45, 0.65, 0.4))


func _draw_planet_floor_details(rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var accent_color = current_theme.get("floor_accent", Color(0.08, 0.12, 0.06))
	var highlight_color = current_theme.get("floor_highlight", Color(0.18, 0.26, 0.14))
	
	# Subtle grass texture - soft edge lines
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), accent_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), accent_color, 1.0)
	
	# Small grass blade marks on some tiles (very subtle)
	if hash_val < 25:
		# A few grass blade strokes
		draw_line(pos + Vector2(8, 20), pos + Vector2(10, 12), highlight_color, 1.0)
		draw_line(pos + Vector2(22, 22), pos + Vector2(24, 14), highlight_color, 1.0)
	elif hash_val > 75:
		# Different grass pattern
		draw_line(pos + Vector2(14, 24), pos + Vector2(16, 16), highlight_color, 1.0)
		draw_line(pos + Vector2(18, 26), pos + Vector2(19, 18), highlight_color, 1.0)


## Draw wall tile with autotiling and biome-specific appearance
func _draw_wall_tile(x: int, y: int, rect: Rect2, hash_val: int) -> void:
	var pos = Vector2i(x, y)
	
	# Check adjacent tiles for walls
	var has_wall_above = tile_data.get(pos + Vector2i(0, -1), TileType.FLOOR) == TileType.WALL
	var has_wall_below = tile_data.get(pos + Vector2i(0, 1), TileType.FLOOR) == TileType.WALL
	var has_wall_left = tile_data.get(pos + Vector2i(-1, 0), TileType.FLOOR) == TileType.WALL
	var has_wall_right = tile_data.get(pos + Vector2i(1, 0), TileType.FLOOR) == TileType.WALL
	
	var neighbor_count = int(has_wall_above) + int(has_wall_below) + int(has_wall_left) + int(has_wall_right)
	
	# Draw floor base first (dark background)
	draw_rect(rect, current_theme["floor_base"])
	
	# Biome-specific wall rendering for better visuals
	if current_biome == BiomeConfig.BiomeType.STATION:
		_draw_station_wall_tile(rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right, neighbor_count)
		return
	elif current_biome == BiomeConfig.BiomeType.PLANET:
		_draw_planet_wall_tile(rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right, neighbor_count)
		return
	
	# Build wall polygon based on connections (for other biomes)
	var wall_points: PackedVector2Array = []
	var inset = 4.0  # How much to inset non-connected edges
	var edge_var = (hash_val % 6) - 3  # Edge variation
	
	# Corners with slight irregularity based on biome
	var irregularity = 0.3 if current_biome == BiomeConfig.BiomeType.ASTEROID else 0.2
	
	var tl = rect.position + Vector2(inset if not has_wall_left else 0, inset if not has_wall_above else 0)
	var tr = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), inset if not has_wall_above else 0)
	var br = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), TILE_SIZE - (inset if not has_wall_below else 0))
	var bl = rect.position + Vector2(inset if not has_wall_left else 0, TILE_SIZE - (inset if not has_wall_below else 0))
	
	# Add irregular edges for non-connected sides
	if not has_wall_above:
		wall_points.append(tl + Vector2(0, edge_var * irregularity))
		wall_points.append(tl + Vector2(TILE_SIZE * 0.3, -1 + edge_var * irregularity * 0.6))
		wall_points.append(tr + Vector2(-TILE_SIZE * 0.3, 1 + edge_var * irregularity * 0.6))
		wall_points.append(tr + Vector2(0, edge_var * irregularity))
	else:
		wall_points.append(tl)
		wall_points.append(tr)
	
	if not has_wall_right:
		wall_points.append(tr + Vector2(edge_var * irregularity, TILE_SIZE * 0.25))
		wall_points.append(br + Vector2(-edge_var * irregularity * 0.6, -TILE_SIZE * 0.25))
	
	if not has_wall_below:
		wall_points.append(br + Vector2(0, -edge_var * irregularity))
		wall_points.append(br + Vector2(-TILE_SIZE * 0.3, 1 - edge_var * irregularity * 0.6))
		wall_points.append(bl + Vector2(TILE_SIZE * 0.3, -1 - edge_var * irregularity * 0.6))
		wall_points.append(bl + Vector2(0, -edge_var * irregularity))
	else:
		wall_points.append(br)
		wall_points.append(bl)
	
	if not has_wall_left:
		wall_points.append(bl + Vector2(-edge_var * irregularity, -TILE_SIZE * 0.25))
		wall_points.append(tl + Vector2(edge_var * irregularity * 0.6, TILE_SIZE * 0.25))
	
	# Draw shadow first
	var shadow_points: PackedVector2Array = []
	for p in wall_points:
		shadow_points.append(p + Vector2(2, 2))
	if shadow_points.size() >= 3:
		draw_polygon(shadow_points, [Color(0.08, 0.06, 0.04, 0.6)])
	
	# Draw main wall body
	if wall_points.size() >= 3:
		draw_polygon(wall_points, [current_theme["wall"]])
	
	# Draw highlights on exposed edges
	var highlight_color = current_theme["wall_highlight"]
	var shadow_color = current_theme["wall_shadow"]
	
	if not has_wall_above:
		draw_line(tl + Vector2(2, 2), tr + Vector2(-2, 2), highlight_color, 2.0)
	if not has_wall_left:
		draw_line(tl + Vector2(2, 2), bl + Vector2(2, -2), highlight_color.darkened(0.2), 2.0)
	if not has_wall_below:
		draw_line(bl + Vector2(2, -2), br + Vector2(-2, -2), shadow_color, 2.0)
	if not has_wall_right:
		draw_line(tr + Vector2(-2, 2), br + Vector2(-2, -2), shadow_color, 1.5)
	
	# Add biome-specific surface details
	var is_edge_piece = neighbor_count < 4
	if is_edge_piece:
		_draw_wall_details(rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right)


## Draw station-specific wall tile with high contrast industrial look
func _draw_station_wall_tile(rect: Rect2, hash_val: int, has_wall_above: bool, has_wall_below: bool, has_wall_left: bool, has_wall_right: bool, neighbor_count: int) -> void:
	var pos = rect.position
	var wall_color = current_theme["wall"]
	var highlight_color = current_theme["wall_highlight"]
	var shadow_color = current_theme["wall_shadow"]
	var panel_color = current_theme.get("wall_panel", wall_color.darkened(0.15))
	
	# Solid dark outline first (creates separation from floor)
	var outline_color = Color(0.04, 0.05, 0.07)
	var inset = 2.0
	
	# Draw dark outline/border around the wall
	if not has_wall_above:
		draw_rect(Rect2(pos.x, pos.y, TILE_SIZE, inset), outline_color)
	if not has_wall_below:
		draw_rect(Rect2(pos.x, pos.y + TILE_SIZE - inset, TILE_SIZE, inset), outline_color)
	if not has_wall_left:
		draw_rect(Rect2(pos.x, pos.y, inset, TILE_SIZE), outline_color)
	if not has_wall_right:
		draw_rect(Rect2(pos.x + TILE_SIZE - inset, pos.y, inset, TILE_SIZE), outline_color)
	
	# Main wall body - solid fill
	var wall_inset = 2.0
	var wall_rect = Rect2(
		pos.x + (wall_inset if not has_wall_left else 0),
		pos.y + (wall_inset if not has_wall_above else 0),
		TILE_SIZE - (wall_inset if not has_wall_left else 0) - (wall_inset if not has_wall_right else 0),
		TILE_SIZE - (wall_inset if not has_wall_above else 0) - (wall_inset if not has_wall_below else 0)
	)
	draw_rect(wall_rect, wall_color)
	
	# Inner panel (creates depth)
	var panel_inset = 5.0
	var panel_rect = Rect2(
		pos.x + panel_inset,
		pos.y + panel_inset,
		TILE_SIZE - panel_inset * 2,
		TILE_SIZE - panel_inset * 2
	)
	draw_rect(panel_rect, panel_color)
	
	# Highlight on top/left edges (light source from top-left)
	if not has_wall_above:
		draw_line(pos + Vector2(wall_inset, wall_inset), pos + Vector2(TILE_SIZE - wall_inset, wall_inset), highlight_color, 2.0)
	if not has_wall_left:
		draw_line(pos + Vector2(wall_inset, wall_inset), pos + Vector2(wall_inset, TILE_SIZE - wall_inset), highlight_color.darkened(0.15), 2.0)
	
	# Shadow on bottom/right edges
	if not has_wall_below:
		draw_line(pos + Vector2(wall_inset, TILE_SIZE - wall_inset - 1), pos + Vector2(TILE_SIZE - wall_inset, TILE_SIZE - wall_inset - 1), shadow_color, 2.0)
	if not has_wall_right:
		draw_line(pos + Vector2(TILE_SIZE - wall_inset - 1, wall_inset), pos + Vector2(TILE_SIZE - wall_inset - 1, TILE_SIZE - wall_inset), shadow_color, 2.0)
	
	# Add station wall details on edge pieces
	if neighbor_count < 4:
		_draw_station_wall_details(rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right)


## Draw planet-specific wall tile - alien crystal/rock formations
func _draw_planet_wall_tile(rect: Rect2, hash_val: int, has_wall_above: bool, has_wall_below: bool, has_wall_left: bool, has_wall_right: bool, _neighbor_count: int) -> void:
	var pos = rect.position
	var wall_color = current_theme["wall"]
	var highlight_color = current_theme["wall_highlight"]
	var shadow_color = current_theme["wall_shadow"]
	var crystal_color = current_theme.get("wall_crystal", Color(0.70, 0.40, 0.75))
	var glow_color = current_theme.get("wall_glow", Color(0.80, 0.50, 0.90, 0.6))
	
	# Dark purple outline for contrast
	var outline_color = Color(0.12, 0.08, 0.15)
	var inset = 2.0
	
	# Draw dark outline/border
	if not has_wall_above:
		draw_rect(Rect2(pos.x, pos.y, TILE_SIZE, inset), outline_color)
	if not has_wall_below:
		draw_rect(Rect2(pos.x, pos.y + TILE_SIZE - inset, TILE_SIZE, inset), outline_color)
	if not has_wall_left:
		draw_rect(Rect2(pos.x, pos.y, inset, TILE_SIZE), outline_color)
	if not has_wall_right:
		draw_rect(Rect2(pos.x + TILE_SIZE - inset, pos.y, inset, TILE_SIZE), outline_color)
	
	# Main alien rock body - purple tones
	var wall_inset = 2.0
	var wall_rect = Rect2(
		pos.x + (wall_inset if not has_wall_left else 0),
		pos.y + (wall_inset if not has_wall_above else 0),
		TILE_SIZE - (wall_inset if not has_wall_left else 0) - (wall_inset if not has_wall_right else 0),
		TILE_SIZE - (wall_inset if not has_wall_above else 0) - (wall_inset if not has_wall_below else 0)
	)
	draw_rect(wall_rect, wall_color)
	
	# Crystal formations based on hash (organic, irregular shapes)
	var crystal_type = hash_val % 5
	
	match crystal_type:
		0:
			# Large crystal shard pointing up
			var points: PackedVector2Array = [
				pos + Vector2(8, 28),
				pos + Vector2(16, 4),
				pos + Vector2(24, 28)
			]
			draw_polygon(points, [crystal_color])
			# Crystal highlight
			draw_line(pos + Vector2(16, 4), pos + Vector2(14, 20), crystal_color.lightened(0.4), 2.0)
			# Glow effect
			draw_circle(pos + Vector2(16, 12), 4, glow_color)
		
		1:
			# Cluster of smaller crystals
			# Left crystal
			var p1: PackedVector2Array = [pos + Vector2(6, 26), pos + Vector2(10, 8), pos + Vector2(14, 26)]
			draw_polygon(p1, [crystal_color.darkened(0.15)])
			# Right crystal
			var p2: PackedVector2Array = [pos + Vector2(18, 28), pos + Vector2(24, 6), pos + Vector2(28, 28)]
			draw_polygon(p2, [crystal_color])
			draw_line(pos + Vector2(24, 6), pos + Vector2(22, 18), crystal_color.lightened(0.35), 1.5)
		
		2:
			# Organic alien rock formation with glow spots
			draw_rect(Rect2(pos.x + 6, pos.y + 6, 20, 20), shadow_color)
			draw_rect(Rect2(pos.x + 8, pos.y + 8, 16, 16), wall_color.lightened(0.1))
			# Bioluminescent spots
			draw_circle(pos + Vector2(12, 12), 3, glow_color)
			draw_circle(pos + Vector2(20, 20), 2, glow_color.darkened(0.2))
		
		3:
			# Jagged alien rock edge
			var rock_points: PackedVector2Array = [
				pos + Vector2(4, 28),
				pos + Vector2(8, 16),
				pos + Vector2(14, 22),
				pos + Vector2(18, 8),
				pos + Vector2(24, 18),
				pos + Vector2(28, 28)
			]
			draw_polygon(rock_points, [wall_color.lightened(0.08)])
			# Highlight on peaks
			draw_line(pos + Vector2(18, 8), pos + Vector2(16, 16), highlight_color, 2.0)
		
		4:
			# Smooth alien structure with pink glow
			draw_circle(pos + Vector2(16, 16), 12, wall_color)
			draw_circle(pos + Vector2(16, 16), 8, shadow_color)
			draw_circle(pos + Vector2(16, 16), 4, current_theme.get("biolum_pink", Color(0.95, 0.45, 0.65, 0.8)))
	
	# Highlight on exposed edges
	if not has_wall_above:
		draw_line(pos + Vector2(wall_inset + 2, wall_inset + 2), pos + Vector2(TILE_SIZE - wall_inset - 2, wall_inset + 2), highlight_color, 2.0)
	if not has_wall_left:
		draw_line(pos + Vector2(wall_inset + 2, wall_inset + 2), pos + Vector2(wall_inset + 2, TILE_SIZE - wall_inset - 2), highlight_color.darkened(0.2), 1.5)
	
	# Shadow on bottom/right edges
	if not has_wall_below:
		draw_line(pos + Vector2(wall_inset, TILE_SIZE - wall_inset - 1), pos + Vector2(TILE_SIZE - wall_inset, TILE_SIZE - wall_inset - 1), shadow_color, 2.0)
	if not has_wall_right:
		draw_line(pos + Vector2(TILE_SIZE - wall_inset - 1, wall_inset), pos + Vector2(TILE_SIZE - wall_inset - 1, TILE_SIZE - wall_inset), shadow_color, 1.5)


func _draw_wall_details(rect: Rect2, hash_val: int, _above: bool, _below: bool, _left: bool, _right: bool) -> void:
	var detail_color = current_theme["wall_shadow"]
	var inset = 4.0
	
	match current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_wall_details(rect, hash_val, _above, _below, _left, _right)
		
		BiomeConfig.BiomeType.ASTEROID:
			# Rocky details - cracks, mineral veins
			if hash_val % 4 == 0:
				var crack_start = rect.position + Vector2(8, 4)
				var crack_end = rect.position + Vector2(24, 28)
				draw_line(crack_start, crack_end, detail_color, 1.5)
			if hash_val % 7 == 0:
				# Blue mineral vein
				draw_line(rect.position + Vector2(6, 16), rect.position + Vector2(26, 14), Color(0.3, 0.4, 0.6, 0.5), 2.0)
		
		BiomeConfig.BiomeType.PLANET:
			# Natural details - vegetation, erosion
			if hash_val % 3 == 0:
				# Moss/lichen
				draw_circle(rect.position + Vector2(10, 8), 3, current_theme["floor_accent"])
			if hash_val % 5 == 0:
				# Erosion marks
				draw_line(rect.position + Vector2(4, 20), rect.position + Vector2(14, 28), detail_color, 1.5)


## Draw extraction zone tile
func _draw_extraction_tile(rect: Rect2, hash_val: int) -> void:
	# Biome-specific extraction zone rendering
	match current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_extraction(rect, hash_val)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_extraction(rect, hash_val)
		_:
			_draw_default_extraction(rect, hash_val)


## Default extraction zone rendering (used for other biomes)
func _draw_default_extraction(rect: Rect2, _hash_val: int) -> void:
	# Base extraction floor
	draw_rect(rect, current_theme["extraction"])
	
	# Glowing center area
	var inner_rect = Rect2(rect.position.x + 4, rect.position.y + 4, TILE_SIZE - 8, TILE_SIZE - 8)
	draw_rect(inner_rect, current_theme["extraction_glow"])
	
	# Corner markers
	var corner_size = 6
	var marker_color = current_theme["extraction_marker"]
	# Top-left
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2 + corner_size, 2), marker_color, 2.0)
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2, 2 + corner_size), marker_color, 2.0)
	# Bottom-right
	draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2 - corner_size, TILE_SIZE - 2), marker_color, 2.0)
	draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2 - corner_size), marker_color, 2.0)


## Station-specific extraction zone with sci-fi landing pad look
func _draw_station_extraction(rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	
	# Dark base floor (landing pad)
	draw_rect(rect, Color(0.08, 0.12, 0.10))
	
	# Green safety zone base
	var inner_rect = Rect2(pos.x + 2, pos.y + 2, TILE_SIZE - 4, TILE_SIZE - 4)
	draw_rect(inner_rect, current_theme["extraction"])
	
	# Glowing center area
	var glow_rect = Rect2(pos.x + 6, pos.y + 6, TILE_SIZE - 12, TILE_SIZE - 12)
	draw_rect(glow_rect, current_theme["extraction_glow"])
	
	# Landing pad grid pattern
	var grid_color = current_theme["extraction_marker"].darkened(0.3)
	# Horizontal lines
	draw_line(pos + Vector2(4, TILE_SIZE / 2), pos + Vector2(TILE_SIZE - 4, TILE_SIZE / 2), grid_color, 1.0)
	# Vertical lines
	draw_line(pos + Vector2(TILE_SIZE / 2, 4), pos + Vector2(TILE_SIZE / 2, TILE_SIZE - 4), grid_color, 1.0)
	
	# Corner chevron markers (landing indicators)
	var marker_color = current_theme["extraction_marker"]
	var corner_size = 8
	
	# Top-left corner
	draw_line(pos + Vector2(2, 2), pos + Vector2(2 + corner_size, 2), marker_color, 2.0)
	draw_line(pos + Vector2(2, 2), pos + Vector2(2, 2 + corner_size), marker_color, 2.0)
	draw_line(pos + Vector2(4, 4), pos + Vector2(4 + corner_size - 2, 4), marker_color, 1.0)
	draw_line(pos + Vector2(4, 4), pos + Vector2(4, 4 + corner_size - 2), marker_color, 1.0)
	
	# Top-right corner
	draw_line(pos + Vector2(TILE_SIZE - 2, 2), pos + Vector2(TILE_SIZE - 2 - corner_size, 2), marker_color, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, 2), pos + Vector2(TILE_SIZE - 2, 2 + corner_size), marker_color, 2.0)
	
	# Bottom-left corner
	draw_line(pos + Vector2(2, TILE_SIZE - 2), pos + Vector2(2 + corner_size, TILE_SIZE - 2), marker_color, 2.0)
	draw_line(pos + Vector2(2, TILE_SIZE - 2), pos + Vector2(2, TILE_SIZE - 2 - corner_size), marker_color, 2.0)
	
	# Bottom-right corner
	draw_line(pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), pos + Vector2(TILE_SIZE - 2 - corner_size, TILE_SIZE - 2), marker_color, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2 - corner_size), marker_color, 2.0)
	
	# Central landing light (pulsing effect via color variation based on position hash)
	var pulse_factor = 0.7 + 0.3 * sin(hash_val * 0.5)
	var center_light_color = marker_color * pulse_factor
	center_light_color.a = 0.8
	draw_circle(pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2), 4, center_light_color)


## Planet-specific extraction zone - alien beacon/portal aesthetic
func _draw_planet_extraction(rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	
	# Dark alien ground base
	draw_rect(rect, Color(0.10, 0.15, 0.16))
	
	# Teal extraction zone base
	var inner_rect = Rect2(pos.x + 2, pos.y + 2, TILE_SIZE - 4, TILE_SIZE - 4)
	draw_rect(inner_rect, current_theme["extraction"])
	
	# Glowing center - brighter teal
	var glow_rect = Rect2(pos.x + 6, pos.y + 6, TILE_SIZE - 12, TILE_SIZE - 12)
	draw_rect(glow_rect, current_theme["extraction_glow"])
	
	# Alien energy pattern (circular rings instead of grid)
	var marker_color = current_theme["extraction_marker"]
	var center = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	
	# Outer ring
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		var next_angle = (float(i + 1) / 16.0) * TAU
		var p1 = center + Vector2(cos(angle) * 12, sin(angle) * 12)
		var p2 = center + Vector2(cos(next_angle) * 12, sin(next_angle) * 12)
		draw_line(p1, p2, marker_color.darkened(0.2), 1.5)
	
	# Inner ring (brighter)
	for i in range(12):
		var angle = (float(i) / 12.0) * TAU
		var next_angle = (float(i + 1) / 12.0) * TAU
		var p1 = center + Vector2(cos(angle) * 8, sin(angle) * 8)
		var p2 = center + Vector2(cos(next_angle) * 8, sin(next_angle) * 8)
		draw_line(p1, p2, marker_color, 2.0)
	
	# Corner alien glyphs/markers
	var corner_offset = 4
	var glyph_size = 6
	
	# Top-left - alien symbol
	draw_line(pos + Vector2(corner_offset, corner_offset), pos + Vector2(corner_offset + glyph_size, corner_offset), marker_color, 2.0)
	draw_line(pos + Vector2(corner_offset, corner_offset), pos + Vector2(corner_offset, corner_offset + glyph_size), marker_color, 2.0)
	draw_circle(pos + Vector2(corner_offset + 2, corner_offset + 2), 2, marker_color)
	
	# Top-right
	draw_line(pos + Vector2(TILE_SIZE - corner_offset, corner_offset), pos + Vector2(TILE_SIZE - corner_offset - glyph_size, corner_offset), marker_color, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - corner_offset, corner_offset), pos + Vector2(TILE_SIZE - corner_offset, corner_offset + glyph_size), marker_color, 2.0)
	
	# Bottom-left
	draw_line(pos + Vector2(corner_offset, TILE_SIZE - corner_offset), pos + Vector2(corner_offset + glyph_size, TILE_SIZE - corner_offset), marker_color, 2.0)
	draw_line(pos + Vector2(corner_offset, TILE_SIZE - corner_offset), pos + Vector2(corner_offset, TILE_SIZE - corner_offset - glyph_size), marker_color, 2.0)
	
	# Bottom-right
	draw_line(pos + Vector2(TILE_SIZE - corner_offset, TILE_SIZE - corner_offset), pos + Vector2(TILE_SIZE - corner_offset - glyph_size, TILE_SIZE - corner_offset), marker_color, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - corner_offset, TILE_SIZE - corner_offset), pos + Vector2(TILE_SIZE - corner_offset, TILE_SIZE - corner_offset - glyph_size), marker_color, 2.0)
	
	# Central beacon glow (alien portal effect)
	var pulse_factor = 0.6 + 0.4 * sin(hash_val * 0.4)
	var beacon_color = marker_color * pulse_factor
	beacon_color.a = 0.9
	draw_circle(center, 5, beacon_color)
	draw_circle(center, 3, Color(0.9, 1.0, 0.95, 0.8))  # Bright white-cyan core


## Draw cover object with biome-specific appearance
func _draw_cover_tile(rect: Rect2, hash_val: int) -> void:
	# Floor underneath
	draw_rect(rect, current_theme["floor_base"])
	
	# Draw biome-specific cover object
	var center = rect.position + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	
	match current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_cover(center, hash_val)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_cover(center, hash_val)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_cover(center, hash_val)


## Draw detailed station wall decorations
func _draw_station_wall_details(rect: Rect2, hash_val: int, _above: bool, _below: bool, _left: bool, _right: bool) -> void:
	var pos = rect.position
	var panel_color = current_theme.get("wall_panel", Color(0.18, 0.22, 0.28))
	var highlight_color = current_theme["wall_highlight"]
	var shadow_color = current_theme["wall_shadow"]
	var accent_color = current_theme.get("accent_glow", Color(0.2, 0.8, 0.9, 0.8))
	var accent_dim = current_theme.get("accent_dim", Color(0.15, 0.5, 0.6, 0.5))
	
	# Rivets on exposed edges
	if not _left:
		draw_circle(pos + Vector2(6, 8), 2, shadow_color)
		draw_circle(pos + Vector2(6, 24), 2, shadow_color)
		# Rivet highlights
		draw_circle(pos + Vector2(5.5, 7.5), 1, highlight_color.darkened(0.3))
		draw_circle(pos + Vector2(5.5, 23.5), 1, highlight_color.darkened(0.3))
	
	if not _right:
		draw_circle(pos + Vector2(26, 8), 2, shadow_color)
		draw_circle(pos + Vector2(26, 24), 2, shadow_color)
	
	# Wall panel details based on hash
	if hash_val % 6 == 0:
		# Recessed panel
		var panel_rect = Rect2(pos.x + 6, pos.y + 6, 20, 20)
		draw_rect(panel_rect, panel_color)
		draw_line(pos + Vector2(6, 6), pos + Vector2(26, 6), shadow_color, 1.0)
		draw_line(pos + Vector2(6, 6), pos + Vector2(6, 26), shadow_color, 1.0)
		draw_line(pos + Vector2(26, 6), pos + Vector2(26, 26), highlight_color.darkened(0.4), 1.0)
		draw_line(pos + Vector2(6, 26), pos + Vector2(26, 26), highlight_color.darkened(0.4), 1.0)
	
	elif hash_val % 6 == 1:
		# Vertical pipe
		var pipe_x = pos.x + 10 + (hash_val % 8)
		draw_rect(Rect2(pipe_x - 2, pos.y, 4, TILE_SIZE), shadow_color)
		draw_line(Vector2(pipe_x - 2, pos.y), Vector2(pipe_x - 2, pos.y + TILE_SIZE), highlight_color.darkened(0.3), 1.0)
	
	elif hash_val % 6 == 2:
		# Horizontal vent/grate
		var vent_color = shadow_color.lightened(0.1)
		for i in range(5):
			var y_off = 4 + i * 5
			draw_line(pos + Vector2(6, y_off), pos + Vector2(26, y_off), vent_color, 2.0)
	
	elif hash_val % 6 == 3 and not _above:
		# Cyan accent light strip at top
		draw_rect(Rect2(pos.x + 4, pos.y + 2, 24, 3), accent_color)
		# Glow effect
		draw_rect(Rect2(pos.x + 2, pos.y + 1, 28, 5), accent_dim)
	
	elif hash_val % 6 == 4:
		# Terminal/control panel
		var terminal_rect = Rect2(pos.x + 8, pos.y + 8, 16, 12)
		draw_rect(terminal_rect, Color(0.05, 0.08, 0.12))
		# Screen
		draw_rect(Rect2(pos.x + 10, pos.y + 10, 12, 6), accent_dim)
		# Buttons below screen
		draw_circle(pos + Vector2(12, 22), 2, Color(0.8, 0.2, 0.2, 0.8))  # Red button
		draw_circle(pos + Vector2(20, 22), 2, Color(0.2, 0.8, 0.3, 0.8))  # Green button
	
	elif hash_val % 6 == 5:
		# Warning stripes (hazard marking)
		var stripe_color = Color(0.7, 0.6, 0.1, 0.6)
		for i in range(4):
			var start_x = pos.x + i * 8
			draw_line(Vector2(start_x, pos.y + 4), Vector2(start_x + 6, pos.y + 28), stripe_color, 2.0)


func _draw_station_cover(center: Vector2, hash_val: int) -> void:
	var cover_type = hash_val % 4  # More variety
	
	# Stronger shadow underneath for depth
	var shadow: PackedVector2Array = [
		center + Vector2(-13, 9) + Vector2(3, 3),
		center + Vector2(13, 9) + Vector2(3, 3),
		center + Vector2(11, 14) + Vector2(3, 3),
		center + Vector2(-11, 14) + Vector2(3, 3)
	]
	draw_polygon(shadow, [Color(0.0, 0.0, 0.02, 0.7)])
	
	# Black outline color for all crates
	var outline_color = Color(0.02, 0.02, 0.04)
	
	match cover_type:
		0:  # Brown/orange cargo crate - BRIGHTER
			var main_color = current_theme["cover_main"]
			var dark_color = current_theme["cover_dark"]
			var light_color = current_theme["cover_light"]
			
			# Black outline/back
			var outline: PackedVector2Array = [
				center + Vector2(-12, -11),
				center + Vector2(12, -11),
				center + Vector2(13, 10),
				center + Vector2(-13, 10)
			]
			draw_polygon(outline, [outline_color])
			
			# Front face
			var front: PackedVector2Array = [
				center + Vector2(-11, -10),
				center + Vector2(11, -10),
				center + Vector2(11, 8),
				center + Vector2(-11, 8)
			]
			draw_polygon(front, [main_color])
			
			# Top face (bright highlight)
			var top: PackedVector2Array = [
				center + Vector2(-11, -10),
				center + Vector2(11, -10),
				center + Vector2(10, -7),
				center + Vector2(-10, -7)
			]
			draw_polygon(top, [light_color])
			
			# Metal bands (darker)
			draw_rect(Rect2(center.x - 11, center.y - 3, 22, 3), dark_color)
			draw_rect(Rect2(center.x - 11, center.y + 3, 22, 3), dark_color)
			
			# Bright highlight lines on top
			draw_line(center + Vector2(-11, -10), center + Vector2(11, -10), light_color.lightened(0.2), 2.0)
			
			# Label/marking
			draw_rect(Rect2(center.x - 5, center.y - 8, 10, 4), Color(0.9, 0.85, 0.6))
		
		1:  # Green supply/ammo crate - MORE VIBRANT
			var green_main = current_theme.get("cover_green", Color(0.35, 0.55, 0.30))
			var green_dark = current_theme.get("cover_green_dark", Color(0.22, 0.38, 0.18))
			var green_light = current_theme.get("cover_green_light", green_main.lightened(0.25))
			
			# Black outline
			var outline: PackedVector2Array = [
				center + Vector2(-11, -10),
				center + Vector2(11, -10),
				center + Vector2(11, 10),
				center + Vector2(-11, 10)
			]
			draw_polygon(outline, [outline_color])
			
			# Main body
			var body: PackedVector2Array = [
				center + Vector2(-10, -9),
				center + Vector2(10, -9),
				center + Vector2(10, 9),
				center + Vector2(-10, 9)
			]
			draw_polygon(body, [green_main])
			
			# Top highlight strip
			draw_rect(Rect2(center.x - 10, center.y - 9, 20, 3), green_light)
			
			# Bottom shadow strip
			draw_rect(Rect2(center.x - 10, center.y + 6, 20, 3), green_dark)
			
			# Left highlight edge
			draw_line(center + Vector2(-10, -9), center + Vector2(-10, 9), green_light, 2.0)
			# Right shadow edge
			draw_line(center + Vector2(10, -9), center + Vector2(10, 9), green_dark, 2.0)
			
			# Military stencil marking (white star or marking)
			draw_rect(Rect2(center.x - 5, center.y - 3, 10, 6), green_dark)
			draw_rect(Rect2(center.x - 3, center.y - 1, 6, 2), Color(0.85, 0.85, 0.75))
		
		2:  # Gray metal container/barrier - LIGHTER GRAY
			var metal_color = current_theme.get("cover_metal", Color(0.50, 0.55, 0.60))
			var metal_dark = metal_color.darkened(0.35)
			var metal_light = metal_color.lightened(0.25)
			
			# Black outline
			var outline: PackedVector2Array = [
				center + Vector2(-12, -11),
				center + Vector2(12, -11),
				center + Vector2(12, 9),
				center + Vector2(-12, 9)
			]
			draw_polygon(outline, [outline_color])
			
			# Main body
			var body: PackedVector2Array = [
				center + Vector2(-11, -10),
				center + Vector2(11, -10),
				center + Vector2(11, 8),
				center + Vector2(-11, 8)
			]
			draw_polygon(body, [metal_color])
			
			# Top highlight
			draw_rect(Rect2(center.x - 11, center.y - 10, 22, 3), metal_light)
			
			# Vertical ridges (ribbed container)
			for i in range(6):
				var x_off = -9 + i * 4
				draw_line(center + Vector2(x_off, -7), center + Vector2(x_off, 6), metal_dark, 2.0)
			
			# Bottom shadow
			draw_line(center + Vector2(-11, 8), center + Vector2(11, 8), metal_dark, 2.0)
		
		3:  # Yellow/orange barrel cluster - HAZARD COLORS
			var barrel_main = Color(0.75, 0.55, 0.15)  # Orange-yellow
			var barrel_dark = Color(0.50, 0.35, 0.10)
			var barrel_light = Color(0.90, 0.70, 0.25)
			
			# Black outline base
			draw_circle(center + Vector2(0, 2), 12, outline_color)
			
			# Main barrel body
			draw_circle(center + Vector2(0, 2), 11, barrel_main)
			
			# Inner darker ring
			draw_circle(center + Vector2(0, 2), 8, barrel_dark)
			
			# Center highlight
			draw_circle(center + Vector2(0, 2), 5, barrel_main.lightened(0.15))
			
			# Top rim highlight (arc)
			for i in range(12):
				var angle = PI + (float(i) / 11.0) * PI
				var p1 = center + Vector2(0, 2) + Vector2(cos(angle) * 11, sin(angle) * 4)
				var p2 = center + Vector2(0, 2) + Vector2(cos(angle + 0.3) * 11, sin(angle + 0.3) * 4)
				draw_line(p1, p2, barrel_light, 2.0)
			
			# Hazard symbol (biohazard/radiation style)
			draw_circle(center + Vector2(0, 0), 4, Color(0.1, 0.1, 0.1, 0.8))
			draw_circle(center + Vector2(0, 0), 2, Color(0.9, 0.2, 0.1, 0.9))


func _draw_asteroid_cover(center: Vector2, hash_val: int) -> void:
	# Rock pile cover
	var shadow_points: PackedVector2Array = []
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var radius = 12.0 + (hash_val % 4)
		shadow_points.append(center + Vector2(cos(angle) * radius + 2, sin(angle) * radius * 0.7 + 3))
	draw_polygon(shadow_points, [Color(0.06, 0.05, 0.04, 0.5)])
	
	# Large back rock
	var rock1: PackedVector2Array = [
		center + Vector2(-8, -6),
		center + Vector2(-2, -10),
		center + Vector2(6, -7),
		center + Vector2(10, -2),
		center + Vector2(8, 6),
		center + Vector2(-4, 8),
		center + Vector2(-10, 3)
	]
	draw_polygon(rock1, [current_theme["cover_main"]])
	draw_line(center + Vector2(-6, -5), center + Vector2(0, -9), current_theme["cover_light"], 2.0)
	
	# Medium front rock
	var rock2: PackedVector2Array = [
		center + Vector2(2, 0),
		center + Vector2(8, -4),
		center + Vector2(12, 2),
		center + Vector2(9, 9),
		center + Vector2(3, 10),
		center + Vector2(-1, 6)
	]
	draw_polygon(rock2, [current_theme["cover_dark"].lightened(0.1)])
	
	# Blue mineral accent
	if hash_val % 3 == 0:
		draw_circle(center + Vector2(-3, 2), 3, Color(0.3, 0.4, 0.6, 0.4))


func _draw_planet_cover(center: Vector2, hash_val: int) -> void:
	var cover_type = hash_val % 4  # More variety for alien planet
	
	# Get alien colors
	var cap_color = current_theme.get("cover_main", Color(0.35, 0.55, 0.58))
	var cap_dark = current_theme.get("cover_dark", Color(0.22, 0.38, 0.42))
	var cap_light = current_theme.get("cover_light", Color(0.50, 0.70, 0.72))
	var stem_color = current_theme.get("cover_stem", Color(0.45, 0.40, 0.35))
	var crystal_color = current_theme.get("cover_crystal", Color(0.55, 0.35, 0.60))
	var crystal_glow = current_theme.get("cover_crystal_glow", Color(0.75, 0.50, 0.80))
	var orange_color = current_theme.get("cover_orange", Color(0.85, 0.55, 0.20))
	var orange_glow = current_theme.get("cover_orange_glow", Color(1.0, 0.70, 0.30))
	var biolum_yellow = current_theme.get("biolum_yellow", Color(1.0, 0.85, 0.30, 0.85))
	
	# Dark shadow underneath
	draw_circle(center + Vector2(2, 10), 10, Color(0.05, 0.08, 0.10, 0.6))
	
	# Black outline color
	var outline_color = Color(0.08, 0.10, 0.12)
	
	match cover_type:
		0:  # Teal alien mushroom (like reference images)
			# Stem
			var stem_points: PackedVector2Array = [
				center + Vector2(-4, 10),
				center + Vector2(-3, -2),
				center + Vector2(3, -2),
				center + Vector2(4, 10)
			]
			draw_polygon(stem_points, [stem_color])
			draw_line(center + Vector2(-3, -2), center + Vector2(-3, 8), stem_color.lightened(0.2), 1.5)
			
			# Mushroom cap (teal, curved top)
			var cap_points: PackedVector2Array = [
				center + Vector2(-12, 2),
				center + Vector2(-10, -6),
				center + Vector2(-4, -10),
				center + Vector2(4, -10),
				center + Vector2(10, -6),
				center + Vector2(12, 2),
				center + Vector2(8, 4),
				center + Vector2(0, 2),
				center + Vector2(-8, 4)
			]
			draw_polygon(cap_points, [cap_color])
			
			# Cap highlight (top curve)
			draw_line(center + Vector2(-8, -8), center + Vector2(8, -8), cap_light, 3.0)
			draw_line(center + Vector2(-10, -6), center + Vector2(10, -6), cap_color.lightened(0.15), 2.0)
			
			# Cap underside shadow
			draw_line(center + Vector2(-10, 2), center + Vector2(10, 2), cap_dark, 2.0)
			
			# Bioluminescent spots on cap
			draw_circle(center + Vector2(-5, -4), 2, biolum_yellow)
			draw_circle(center + Vector2(4, -5), 1.5, biolum_yellow.darkened(0.2))
		
		1:  # Orange glowing mushroom cluster
			# Main mushroom stem
			draw_rect(Rect2(center.x - 3, center.y - 2, 6, 12), stem_color.darkened(0.1))
			
			# Main orange cap
			draw_circle(center + Vector2(0, -6), 10, orange_color)
			draw_circle(center + Vector2(0, -6), 7, orange_glow)
			draw_circle(center + Vector2(0, -6), 4, biolum_yellow)  # Bright glow center
			
			# Small secondary mushroom
			draw_rect(Rect2(center.x + 6, center.y + 2, 3, 6), stem_color)
			draw_circle(center + Vector2(8, 0), 5, orange_color.darkened(0.2))
			draw_circle(center + Vector2(8, 0), 3, orange_glow.darkened(0.15))
			
			# Outline for pop
			draw_circle(center + Vector2(0, -6), 10, outline_color)
		
		2:  # Purple crystal formation
			# Dark base
			draw_polygon([
				center + Vector2(-10, 10),
				center + Vector2(-8, 4),
				center + Vector2(8, 4),
				center + Vector2(10, 10)
			], [outline_color])
			
			# Main large crystal
			var main_crystal: PackedVector2Array = [
				center + Vector2(-6, 8),
				center + Vector2(-2, -12),
				center + Vector2(4, 8)
			]
			draw_polygon(main_crystal, [crystal_color])
			draw_line(center + Vector2(-2, -12), center + Vector2(-1, 0), crystal_glow, 2.0)
			
			# Secondary crystal (leaning right)
			var side_crystal: PackedVector2Array = [
				center + Vector2(4, 8),
				center + Vector2(8, -6),
				center + Vector2(12, 8)
			]
			draw_polygon(side_crystal, [crystal_color.darkened(0.15)])
			draw_line(center + Vector2(8, -6), center + Vector2(8, 2), crystal_glow.darkened(0.1), 1.5)
			
			# Small crystal
			var small_crystal: PackedVector2Array = [
				center + Vector2(-10, 8),
				center + Vector2(-8, -2),
				center + Vector2(-5, 8)
			]
			draw_polygon(small_crystal, [crystal_color.lightened(0.1)])
			
			# Glow at crystal tips
			draw_circle(center + Vector2(-2, -10), 3, current_theme.get("wall_glow", Color(0.80, 0.50, 0.90, 0.6)))
		
		3:  # Alien plant/coral formation
			var plant_color = current_theme.get("alien_plant", Color(0.30, 0.55, 0.50))
			var plant_dark = current_theme.get("alien_plant_dark", Color(0.20, 0.40, 0.38))
			
			# Base/roots
			draw_circle(center + Vector2(0, 6), 8, plant_dark)
			
			# Main stalks (branching)
			# Left branch
			draw_line(center + Vector2(-2, 6), center + Vector2(-8, -8), plant_color, 4.0)
			draw_line(center + Vector2(-8, -8), center + Vector2(-12, -12), plant_color.lightened(0.1), 3.0)
			draw_circle(center + Vector2(-12, -12), 4, plant_color.lightened(0.2))
			
			# Right branch
			draw_line(center + Vector2(2, 6), center + Vector2(6, -6), plant_color, 4.0)
			draw_line(center + Vector2(6, -6), center + Vector2(10, -10), plant_color.lightened(0.1), 3.0)
			draw_circle(center + Vector2(10, -10), 3, plant_color.lightened(0.15))
			
			# Center stalk
			draw_line(center + Vector2(0, 6), center + Vector2(0, -10), plant_color, 3.0)
			draw_circle(center + Vector2(0, -10), 5, plant_color.lightened(0.25))
			
			# Bioluminescent tips
			draw_circle(center + Vector2(-12, -12), 2, biolum_yellow)
			draw_circle(center + Vector2(10, -10), 1.5, biolum_yellow.darkened(0.2))
			draw_circle(center + Vector2(0, -10), 2.5, biolum_yellow)


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse movement for hover effects
	if event is InputEventMouseMotion:
		var local_mouse = get_local_mouse_position()
		var grid_pos = world_to_grid(local_mouse)
		
		if grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height:
			if hovered_tile != grid_pos:
				hovered_tile = grid_pos
				queue_redraw()
		else:
			if hovered_tile != Vector2i(-1, -1):
				hovered_tile = Vector2i(-1, -1)
				queue_redraw()
	
	# Handle mouse clicks on the tactical map
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = get_local_mouse_position()
		var grid_pos = world_to_grid(local_mouse)

		if grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height:
			tile_clicked.emit(grid_pos)
			get_viewport().set_input_as_handled()  # Mark as handled to prevent other processing


func get_unit_at(grid_pos: Vector2i) -> Node2D:
	var world_pos = grid_to_world(grid_pos)
	# Check units with a slightly larger tolerance to make clicking easier
	var tolerance = TILE_SIZE * 0.6
	for unit in units_container.get_children():
		if unit.position.distance_to(world_pos) < tolerance:
			return unit
	return null


func get_interactable_at(grid_pos: Vector2i) -> Node2D:
	var world_pos = grid_to_world(grid_pos)
	for interactable in interactables_container.get_children():
		if interactable.position.distance_to(world_pos) < TILE_SIZE / 2 and interactable.visible:
			return interactable
	return null


func set_unit_position_solid(pos: Vector2i, is_solid: bool) -> void:
	if tile_data.get(pos, TileType.FLOOR) != TileType.WALL:
		astar.set_point_solid(pos, is_solid)


func add_unit(unit: Node2D, grid_pos: Vector2i) -> void:
	unit.position = grid_to_world(grid_pos)
	units_container.add_child(unit)
	set_unit_position_solid(grid_pos, true)


func add_interactable(interactable: Node2D, grid_pos: Vector2i) -> void:
	interactable.position = grid_to_world(grid_pos)
	interactable.visible = revealed_tiles.get(grid_pos, false)
	interactables_container.add_child(interactable)


func set_movement_range(center: Vector2i, move_range: int) -> void:
	# Clear previous movement range
	movement_range_tiles.clear()
	
	# Use BFS to find all reachable tiles within range
	var queue: Array[Vector2i] = [center]
	var visited: Dictionary = {center: true}
	var distances: Dictionary = {center: 0}
	
	# Temporarily unmark center as solid for pathfinding
	var center_was_solid = astar.is_point_solid(center)
	if center_was_solid:
		astar.set_point_solid(center, false)
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var dist = distances[current]
		
		if dist < move_range:
			# Check all 4 adjacent tiles
			var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for dir in directions:
				var next_pos = current + dir
				
				# Check bounds
				if next_pos.x < 0 or next_pos.x >= map_width or next_pos.y < 0 or next_pos.y >= map_height:
					continue
				
				# Check if walkable and not visited
				if not visited.has(next_pos) and not astar.is_point_solid(next_pos):
					visited[next_pos] = true
					distances[next_pos] = dist + 1
					movement_range_tiles[next_pos] = true
					queue.append(next_pos)
	
	# Restore center solidity
	if center_was_solid:
		astar.set_point_solid(center, true)
	
	queue_redraw()


func clear_movement_range() -> void:
	movement_range_tiles.clear()
	hovered_tile = Vector2i(-1, -1)
	queue_redraw()


## Set execute range highlight (manhattan distance, red tiles)
func set_execute_range(center: Vector2i, exec_range: int) -> void:
	execute_range_tiles.clear()
	
	for x in range(center.x - exec_range, center.x + exec_range + 1):
		for y in range(center.y - exec_range, center.y + exec_range + 1):
			var pos = Vector2i(x, y)
			if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
				continue
			if pos == center:
				continue
			var distance = abs(pos.x - center.x) + abs(pos.y - center.y)
			if distance <= exec_range and revealed_tiles.get(pos, false):
				execute_range_tiles[pos] = true
	
	queue_redraw()


## Clear execute range highlight
func clear_execute_range() -> void:
	execute_range_tiles.clear()
	queue_redraw()


## Get cover value at a position (0 = no cover, 25 = half, 50 = full)
func get_cover_value(pos: Vector2i) -> float:
	var tile_type = tile_data.get(pos, TileType.FLOOR)
	match tile_type:
		TileType.WALL:
			return 50.0  # Full cover
		TileType.HALF_COVER:
			return 25.0  # Half cover
		_:
			return 0.0  # No cover


## Check if a tile provides cover
func provides_cover(pos: Vector2i) -> bool:
	return get_cover_value(pos) > 0.0


## Change a tile type (for destructible cover)
func set_tile_type(pos: Vector2i, new_type: TileType) -> void:
	if pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height:
		tile_data[pos] = new_type
		
		# Update pathfinding if changing walkability
		if new_type == TileType.WALL or new_type == TileType.HALF_COVER:
			astar.set_point_solid(pos, true)
		else:
			astar.set_point_solid(pos, false)
		
		queue_redraw()


## Breach a tile - destroy wall or cover (Tech ability)
func breach_tile(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return
	
	var current_type = tile_data.get(pos, TileType.FLOOR)
	
	# Walls and cover become floor
	if current_type == TileType.WALL or current_type == TileType.HALF_COVER:
		set_tile_type(pos, TileType.FLOOR)
		print("Breached tile at %s (was: %s)" % [pos, current_type])


## Check if a position has adjacent cover (for cover indicator)
## Returns: 0 = no cover, 1 = half cover, 2 = full cover
func get_adjacent_cover_level(pos: Vector2i) -> int:
	var adjacent_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var max_cover_level = 0
	
	for dir in adjacent_dirs:
		var adj_pos = pos + dir
		var tile_type = tile_data.get(adj_pos, TileType.FLOOR)
		if tile_type == TileType.WALL:
			max_cover_level = 2  # Full cover
		elif tile_type == TileType.HALF_COVER and max_cover_level < 2:
			max_cover_level = 1  # Half cover
	
	return max_cover_level


## Check if a position has adjacent cover (for cover indicator) - legacy compatibility
func has_adjacent_cover(pos: Vector2i) -> bool:
	return get_adjacent_cover_level(pos) > 0


## Get the current biome type
func get_biome_type() -> BiomeConfig.BiomeType:
	return current_biome
