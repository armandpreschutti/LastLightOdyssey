extends Node2D
## Tactical Map - Grid management, fog of war, and pathfinding
## Uses simple ColorRect drawing for "gray boxes" phase

signal tile_clicked(grid_pos: Vector2i)

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 20

enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }

# Post-apocalyptic color palette
const COLOR_FLOOR_BASE := Color(0.18, 0.16, 0.14)  # Dark brownish gray - industrial floor
const COLOR_FLOOR_VAR := Color(0.22, 0.19, 0.16)   # Slightly lighter variation
const COLOR_WALL := Color(0.35, 0.28, 0.22)        # Rusty brown - metal walls
const COLOR_WALL_HIGHLIGHT := Color(0.42, 0.35, 0.28)  # Wall edge highlight
const COLOR_EXTRACTION := Color(0.12, 0.28, 0.15)  # Dark green safe zone
const COLOR_EXTRACTION_GLOW := Color(0.2, 0.45, 0.25)  # Brighter extraction center
const COLOR_CONCRETE := Color(0.45, 0.42, 0.4)       # Gray concrete
const COLOR_CONCRETE_DARK := Color(0.32, 0.3, 0.28)  # Dark concrete shadow
const COLOR_CONCRETE_LIGHT := Color(0.55, 0.52, 0.48) # Light concrete highlight
const COLOR_ROCK := Color(0.38, 0.35, 0.32)          # Rock/stone color
const COLOR_FOG := Color(0.02, 0.02, 0.03)         # Near black fog
const COLOR_MOVEMENT_RANGE := Color(0.25, 0.5, 0.7, 0.25)  # Blue movement highlight
const COLOR_HOVER := Color(1.0, 0.9, 0.5, 0.3)     # Yellow hover

@onready var units_container: Node2D = $Units
@onready var interactables_container: Node2D = $Interactables

var astar: AStarGrid2D
var tile_data: Dictionary = {}  # Vector2i -> TileType
var revealed_tiles: Dictionary = {}  # Vector2i -> bool
var movement_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within movement range)
var hovered_tile: Vector2i = Vector2i(-1, -1)  # Currently hovered tile


func _ready() -> void:
	_setup_astar()


func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, MAP_WIDTH, MAP_HEIGHT)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


func initialize_map(layout: Dictionary) -> void:
	tile_data = layout
	_update_astar_solids()
	_initialize_fog()
	queue_redraw()


func _update_astar_solids() -> void:
	for pos in tile_data:
		var is_solid = tile_data[pos] == TileType.WALL or tile_data[pos] == TileType.HALF_COVER
		astar.set_point_solid(pos, is_solid)


func _initialize_fog() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			revealed_tiles[Vector2i(x, y)] = false


func reveal_around(center: Vector2i, sight_range: int) -> void:
	var changed = false
	for x in range(center.x - sight_range, center.x + sight_range + 1):
		for y in range(center.y - sight_range, center.y + sight_range + 1):
			var pos = Vector2i(x, y)
			if pos.x < 0 or pos.x >= MAP_WIDTH or pos.y < 0 or pos.y >= MAP_HEIGHT:
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
	if pos.x < 0 or pos.x >= MAP_WIDTH or pos.y < 0 or pos.y >= MAP_HEIGHT:
		return false
	return not astar.is_point_solid(pos)


## Check if a tile blocks line of sight (only walls block LOS, not cover)
func blocks_line_of_sight(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= MAP_WIDTH or pos.y < 0 or pos.y >= MAP_HEIGHT:
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
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var pos = Vector2i(x, y)
			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			if not revealed_tiles.get(pos, false):
				# Fog of war
				draw_rect(rect, COLOR_FOG)
			else:
				# Get tile type and draw with variation
				var tile_type = tile_data.get(pos, TileType.FLOOR)
				_draw_tile(x, y, rect, tile_type)
				
				# Movement range highlight
				if movement_range_tiles.get(pos, false):
					draw_rect(rect, COLOR_MOVEMENT_RANGE)
				
				# Hover effect
				if pos == hovered_tile:
					draw_rect(rect, COLOR_HOVER)


## Draw a single tile with visual variation
func _draw_tile(x: int, y: int, rect: Rect2, tile_type: TileType) -> void:
	# Use position for deterministic "randomness"
	var hash_val = (x * 73 + y * 137) % 100
	
	match tile_type:
		TileType.FLOOR:
			# Vary floor color slightly based on position
			var base_color = COLOR_FLOOR_BASE if hash_val < 60 else COLOR_FLOOR_VAR
			draw_rect(rect, base_color)
			
			# Add subtle detail marks on some tiles
			if hash_val < 15:
				# Small rust spot
				var spot_rect = Rect2(rect.position.x + 8, rect.position.y + 10, 6, 4)
				draw_rect(spot_rect, Color(0.25, 0.18, 0.12, 0.5))
			elif hash_val > 85:
				# Crack line
				var start = rect.position + Vector2(4, 6)
				var end = rect.position + Vector2(28, 26)
				draw_line(start, end, Color(0.1, 0.09, 0.08), 1.0)
		
		TileType.WALL:
			_draw_wall_autotile(x, y, rect, hash_val)
		
		TileType.EXTRACTION:
			# Base extraction floor
			draw_rect(rect, COLOR_EXTRACTION)
			
			# Glowing center area
			var inner_rect = Rect2(rect.position.x + 4, rect.position.y + 4, TILE_SIZE - 8, TILE_SIZE - 8)
			draw_rect(inner_rect, COLOR_EXTRACTION_GLOW)
			
			# Corner markers
			var corner_size = 6
			# Top-left
			draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2 + corner_size, 2), Color(0.4, 0.8, 0.5), 2.0)
			draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2, 2 + corner_size), Color(0.4, 0.8, 0.5), 2.0)
			# Bottom-right
			draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2 - corner_size, TILE_SIZE - 2), Color(0.4, 0.8, 0.5), 2.0)
			draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2 - corner_size), Color(0.4, 0.8, 0.5), 2.0)
		
		TileType.HALF_COVER:
			# Floor underneath
			draw_rect(rect, COLOR_FLOOR_BASE)
			# Draw organic cover shape
			_draw_cover_object(rect, hash_val)


## Draw cover objects (concrete barriers and rocks)
func _draw_cover_object(rect: Rect2, hash_val: int) -> void:
	var center = rect.position + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var cover_type = hash_val % 3
	
	match cover_type:
		0:  # Concrete jersey barrier
			_draw_concrete_barrier(center, hash_val)
		1:  # Rock pile
			_draw_rock_pile(center, hash_val)
		2:  # Broken concrete chunks
			_draw_rubble_pile(center, hash_val)


## Draw a concrete jersey barrier shape
func _draw_concrete_barrier(center: Vector2, hash_val: int) -> void:
	var angle_var = ((hash_val % 20) - 10) * 0.015  # Slight rotation
	
	# Shadow underneath
	var shadow: PackedVector2Array = [
		center + Vector2(-12, 6).rotated(angle_var) + Vector2(2, 2),
		center + Vector2(12, 6).rotated(angle_var) + Vector2(2, 2),
		center + Vector2(10, 12).rotated(angle_var) + Vector2(2, 2),
		center + Vector2(-10, 12).rotated(angle_var) + Vector2(2, 2)
	]
	draw_polygon(shadow, [Color(0.06, 0.05, 0.04, 0.5)])
	
	# Jersey barrier shape - wider at bottom, narrower at top
	# Back face (darker)
	var back: PackedVector2Array = [
		center + Vector2(-10, -10).rotated(angle_var),
		center + Vector2(10, -10).rotated(angle_var),
		center + Vector2(12, 10).rotated(angle_var),
		center + Vector2(-12, 10).rotated(angle_var)
	]
	draw_polygon(back, [COLOR_CONCRETE_DARK])
	
	# Front face (main color)
	var front: PackedVector2Array = [
		center + Vector2(-8, -12).rotated(angle_var),
		center + Vector2(8, -12).rotated(angle_var),
		center + Vector2(11, 8).rotated(angle_var),
		center + Vector2(-11, 8).rotated(angle_var)
	]
	draw_polygon(front, [COLOR_CONCRETE])
	
	# Top surface highlight
	var top: PackedVector2Array = [
		center + Vector2(-8, -12).rotated(angle_var),
		center + Vector2(8, -12).rotated(angle_var),
		center + Vector2(10, -10).rotated(angle_var),
		center + Vector2(-10, -10).rotated(angle_var)
	]
	draw_polygon(top, [COLOR_CONCRETE_LIGHT])
	
	# Weathering/damage details
	if hash_val % 4 == 0:
		# Crack
		var crack_start = center + Vector2(-3, -8).rotated(angle_var)
		var crack_end = center + Vector2(2, 4).rotated(angle_var)
		draw_line(crack_start, crack_end, COLOR_CONCRETE_DARK, 1.5)
	
	if hash_val % 3 == 0:
		# Chip/damage mark
		draw_circle(center + Vector2(5, -2).rotated(angle_var), 3, COLOR_CONCRETE_DARK)


## Draw a rock pile
func _draw_rock_pile(center: Vector2, hash_val: int) -> void:
	# Shadow underneath
	var shadow_points: PackedVector2Array = []
	for i in range(8):
		var angle = (i / 8.0) * TAU
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
	draw_polygon(rock1, [COLOR_ROCK])
	
	# Highlight on top-left
	draw_line(center + Vector2(-6, -5), center + Vector2(0, -9), Color(0.48, 0.45, 0.42), 2.0)
	
	# Medium front rock
	var rock2: PackedVector2Array = [
		center + Vector2(2, 0),
		center + Vector2(8, -4),
		center + Vector2(12, 2),
		center + Vector2(9, 9),
		center + Vector2(3, 10),
		center + Vector2(-1, 6)
	]
	draw_polygon(rock2, [Color(0.42, 0.38, 0.35)])
	
	# Small rock on top
	var rock3: PackedVector2Array = [
		center + Vector2(-5, -4),
		center + Vector2(0, -7),
		center + Vector2(4, -3),
		center + Vector2(2, 1),
		center + Vector2(-4, 0)
	]
	draw_polygon(rock3, [Color(0.5, 0.46, 0.42)])
	
	# Rock surface details
	draw_line(center + Vector2(-6, 2), center + Vector2(-2, 5), COLOR_CONCRETE_DARK, 1.0)
	draw_line(center + Vector2(5, 3), center + Vector2(8, 6), COLOR_CONCRETE_DARK, 1.0)


## Draw broken concrete rubble
func _draw_rubble_pile(center: Vector2, hash_val: int) -> void:
	var offset = Vector2(((hash_val % 5) - 2) * 0.5, ((hash_val % 7) - 3) * 0.5)
	
	# Shadow
	draw_polygon([
		center + Vector2(-11, 4) + offset + Vector2(2, 2),
		center + Vector2(11, 3) + offset + Vector2(2, 2),
		center + Vector2(10, 11) + offset + Vector2(2, 2),
		center + Vector2(-10, 10) + offset + Vector2(2, 2)
	], [Color(0.06, 0.05, 0.04, 0.5)])
	
	# Large concrete chunk (tilted)
	var chunk1: PackedVector2Array = [
		center + Vector2(-10, -8) + offset,
		center + Vector2(-2, -11) + offset,
		center + Vector2(4, -6) + offset,
		center + Vector2(6, 2) + offset,
		center + Vector2(-4, 6) + offset,
		center + Vector2(-11, 1) + offset
	]
	draw_polygon(chunk1, [COLOR_CONCRETE])
	# Rebar sticking out
	draw_line(center + Vector2(3, -5) + offset, center + Vector2(8, -9) + offset, Color(0.45, 0.3, 0.2), 2.0)
	
	# Smaller chunk on top
	var chunk2: PackedVector2Array = [
		center + Vector2(3, -3) + offset,
		center + Vector2(10, -5) + offset,
		center + Vector2(12, 4) + offset,
		center + Vector2(8, 9) + offset,
		center + Vector2(2, 6) + offset
	]
	draw_polygon(chunk2, [Color(0.48, 0.45, 0.42)])
	
	# Top highlight
	draw_line(center + Vector2(4, -4) + offset, center + Vector2(9, -4) + offset, COLOR_CONCRETE_LIGHT, 2.0)
	
	# Small debris piece
	var chunk3: PackedVector2Array = [
		center + Vector2(-6, 4) + offset,
		center + Vector2(-1, 2) + offset,
		center + Vector2(1, 8) + offset,
		center + Vector2(-5, 10) + offset
	]
	draw_polygon(chunk3, [COLOR_CONCRETE_DARK])
	
	# Cracks and damage
	draw_line(center + Vector2(-7, -4) + offset, center + Vector2(-3, 2) + offset, COLOR_CONCRETE_DARK, 1.5)


## Draw wall with autotiling - connects adjacent walls with organic shapes
func _draw_wall_autotile(x: int, y: int, rect: Rect2, hash_val: int) -> void:
	var pos = Vector2i(x, y)
	
	# Check adjacent tiles for walls
	var has_wall_above = tile_data.get(pos + Vector2i(0, -1), TileType.FLOOR) == TileType.WALL
	var has_wall_below = tile_data.get(pos + Vector2i(0, 1), TileType.FLOOR) == TileType.WALL
	var has_wall_left = tile_data.get(pos + Vector2i(-1, 0), TileType.FLOOR) == TileType.WALL
	var has_wall_right = tile_data.get(pos + Vector2i(1, 0), TileType.FLOOR) == TileType.WALL
	
	# Check diagonal neighbors for corner connections
	var has_wall_tl = tile_data.get(pos + Vector2i(-1, -1), TileType.FLOOR) == TileType.WALL
	var has_wall_tr = tile_data.get(pos + Vector2i(1, -1), TileType.FLOOR) == TileType.WALL
	var has_wall_bl = tile_data.get(pos + Vector2i(-1, 1), TileType.FLOOR) == TileType.WALL
	var has_wall_br = tile_data.get(pos + Vector2i(1, 1), TileType.FLOOR) == TileType.WALL
	
	var center = rect.position + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	
	# Determine wall type based on neighbors
	var neighbor_count = int(has_wall_above) + int(has_wall_below) + int(has_wall_left) + int(has_wall_right)
	
	# Draw floor base first
	draw_rect(rect, COLOR_FLOOR_BASE)
	
	# Build wall polygon based on connections
	var wall_points: PackedVector2Array = []
	var inset = 4.0  # How much to inset non-connected edges
	var edge_var = (hash_val % 6) - 3  # Edge variation
	
	# Corners with slight irregularity
	var tl = rect.position + Vector2(inset if not has_wall_left else 0, inset if not has_wall_above else 0)
	var tr = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), inset if not has_wall_above else 0)
	var br = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), TILE_SIZE - (inset if not has_wall_below else 0))
	var bl = rect.position + Vector2(inset if not has_wall_left else 0, TILE_SIZE - (inset if not has_wall_below else 0))
	
	# Add irregular edges for non-connected sides
	if not has_wall_above:
		# Top edge - add some roughness
		wall_points.append(tl + Vector2(0, edge_var * 0.3))
		wall_points.append(tl + Vector2(TILE_SIZE * 0.3, -1 + edge_var * 0.2))
		wall_points.append(tr + Vector2(-TILE_SIZE * 0.3, 1 + edge_var * 0.2))
		wall_points.append(tr + Vector2(0, edge_var * 0.3))
	else:
		wall_points.append(tl)
		wall_points.append(tr)
	
	if not has_wall_right:
		# Right edge roughness
		wall_points.append(tr + Vector2(edge_var * 0.3, TILE_SIZE * 0.25))
		wall_points.append(br + Vector2(-edge_var * 0.2, -TILE_SIZE * 0.25))
	
	if not has_wall_below:
		wall_points.append(br + Vector2(0, -edge_var * 0.3))
		wall_points.append(br + Vector2(-TILE_SIZE * 0.3, 1 - edge_var * 0.2))
		wall_points.append(bl + Vector2(TILE_SIZE * 0.3, -1 - edge_var * 0.2))
		wall_points.append(bl + Vector2(0, -edge_var * 0.3))
	else:
		wall_points.append(br)
		wall_points.append(bl)
	
	if not has_wall_left:
		wall_points.append(bl + Vector2(-edge_var * 0.3, -TILE_SIZE * 0.25))
		wall_points.append(tl + Vector2(edge_var * 0.2, TILE_SIZE * 0.25))
	
	# Draw shadow first
	var shadow_points: PackedVector2Array = []
	for p in wall_points:
		shadow_points.append(p + Vector2(2, 2))
	if shadow_points.size() >= 3:
		draw_polygon(shadow_points, [Color(0.08, 0.06, 0.04, 0.6)])
	
	# Draw main wall body
	if wall_points.size() >= 3:
		draw_polygon(wall_points, [COLOR_WALL])
	
	# Draw highlights on exposed edges
	var highlight_color = COLOR_WALL_HIGHLIGHT
	var shadow_color = Color(0.2, 0.14, 0.1)
	
	if not has_wall_above:
		draw_line(tl + Vector2(2, 2), tr + Vector2(-2, 2), highlight_color, 2.0)
	if not has_wall_left:
		draw_line(tl + Vector2(2, 2), bl + Vector2(2, -2), Color(0.38, 0.3, 0.24), 2.0)
	if not has_wall_below:
		draw_line(bl + Vector2(2, -2), br + Vector2(-2, -2), shadow_color, 2.0)
	if not has_wall_right:
		draw_line(tr + Vector2(-2, 2), br + Vector2(-2, -2), shadow_color, 1.5)
	
	# Add surface details
	var detail_color = Color(0.28, 0.22, 0.16)
	var is_edge_piece = neighbor_count < 4
	
	if is_edge_piece:
		# Damage/wear marks on edges
		if hash_val % 3 == 0 and not has_wall_above:
			var notch_x = rect.position.x + 8 + (hash_val % 12)
			draw_line(Vector2(notch_x, rect.position.y + inset), Vector2(notch_x + 3, rect.position.y + inset + 4), detail_color, 2.0)
		
		# Rivets on exposed faces
		if hash_val % 2 == 0:
			if not has_wall_left:
				draw_circle(rect.position + Vector2(inset + 3, TILE_SIZE * 0.35), 2, detail_color)
				draw_circle(rect.position + Vector2(inset + 3, TILE_SIZE * 0.65), 2, detail_color)
			if not has_wall_right:
				draw_circle(rect.position + Vector2(TILE_SIZE - inset - 3, TILE_SIZE * 0.35), 2, detail_color)
				draw_circle(rect.position + Vector2(TILE_SIZE - inset - 3, TILE_SIZE * 0.65), 2, detail_color)
		
		# Pipe/cable detail on some walls
		if hash_val % 5 == 0 and has_wall_above and has_wall_below:
			var pipe_x = rect.position.x + TILE_SIZE * 0.3 + (hash_val % 8)
			draw_line(Vector2(pipe_x, rect.position.y), Vector2(pipe_x, rect.position.y + TILE_SIZE), Color(0.25, 0.2, 0.15), 3.0)
			draw_line(Vector2(pipe_x - 1, rect.position.y), Vector2(pipe_x - 1, rect.position.y + TILE_SIZE), Color(0.32, 0.26, 0.2), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse movement for hover effects
	if event is InputEventMouseMotion:
		var local_mouse = get_local_mouse_position()
		var grid_pos = world_to_grid(local_mouse)
		
		if grid_pos.x >= 0 and grid_pos.x < MAP_WIDTH and grid_pos.y >= 0 and grid_pos.y < MAP_HEIGHT:
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

		if grid_pos.x >= 0 and grid_pos.x < MAP_WIDTH and grid_pos.y >= 0 and grid_pos.y < MAP_HEIGHT:
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


func set_movement_range(center: Vector2i, range: int) -> void:
	# Clear previous movement range
	movement_range_tiles.clear()
	
	# Use BFS to find all reachable tiles within range
	# This respects walkability and pathfinding naturally
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
		
		if dist < range:
			# Check all 4 adjacent tiles
			var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for dir in directions:
				var next_pos = current + dir
				
				# Check bounds
				if next_pos.x < 0 or next_pos.x >= MAP_WIDTH or next_pos.y < 0 or next_pos.y >= MAP_HEIGHT:
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
	if pos.x >= 0 and pos.x < MAP_WIDTH and pos.y >= 0 and pos.y < MAP_HEIGHT:
		tile_data[pos] = new_type
		
		# Update pathfinding if changing walkability
		if new_type == TileType.WALL or new_type == TileType.HALF_COVER:
			astar.set_point_solid(pos, true)
		else:
			astar.set_point_solid(pos, false)
		
		queue_redraw()


## Breach a tile - destroy wall or cover (Tech ability)
func breach_tile(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= MAP_WIDTH or pos.y < 0 or pos.y >= MAP_HEIGHT:
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
