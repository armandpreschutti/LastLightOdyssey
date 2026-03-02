extends Node2D
## Tactical Map - Grid management, fog of war, and pathfinding
## Supports biome-specific visual themes

# warning-ignore: INTEGER_DIVISION
# warning-ignore: INCOMPATIBLE_TERNARY
# warning-ignore: SHADOWED_VARIABLE_BASE_CLASS
# warning-ignore: UNUSED_VARIABLE

signal tile_clicked(grid_pos: Vector2i)
signal tile_hovered(grid_pos: Vector2i)

const TILE_SIZE: int = 32
const DEFAULT_MAP_SIZE: int = 20

enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }

# Current map dimensions (set dynamically based on biome)
var map_width: int = DEFAULT_MAP_SIZE
var map_height: int = DEFAULT_MAP_SIZE

# Current biome theme (default to station)
var current_theme: Dictionary = BiomeConfig.STATION_THEME
var current_biome: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION
var is_abandoned_station: bool = false  # Enables "falling apart" visual overlays

# Gameplay highlight colors (consistent across biomes, high visibility)
const COLOR_MOVEMENT_RANGE := Color(0.3, 0.6, 0.9, 0.35)  # Brighter blue movement highlight
const COLOR_EXECUTE_RANGE := Color(0.9, 0.2, 0.2, 0.35)  # Red execute range highlight
const COLOR_HEAL_RANGE := Color(0.3, 1.0, 0.4, 0.4)  # Light green heal range highlight (brighter for visibility)
const COLOR_HOVER := Color(1.0, 0.9, 0.4, 0.4)     # Brighter yellow hover
const COLOR_MISSION_HIGHLIGHT := Color(1.0, 0.84, 0.0, 0.5) # Bright Gold/Yellow for mission objectives
const COLOR_PATHFINDING_LINE := Color(0.2, 0.8, 1.0, 1.0)  # Glowing neon blue pathfinding line
const COLOR_PATHFINDING_GLOW := Color(0.2, 0.8, 1.0, 0.4)  # Glow effect for neon blue

@onready var units_container: Node2D = $Units
@onready var interactables_container: Node2D = $Interactables
@onready var static_layer: Node2D = $StaticLayer

var astar: AStarGrid2D
var tile_data: Dictionary = {}  # Vector2i -> TileType
var revealed_tiles: Dictionary = {}  # Vector2i -> bool
var movement_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within movement range)
var execute_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within execute range)
var heal_range_tiles: Dictionary = {}  # Vector2i -> bool (tiles within heal range)
var enemy_target_tiles: Dictionary = {}  # Vector2i -> bool (tiles under attackable enemies)
var mission_highlight_tiles: Dictionary = {} # Vector2i -> bool (tiles with mission objectives)
var hovered_tile: Vector2i = Vector2i(-1, -1)  # Currently hovered tile
var pathfinding_path: PackedVector2Array = PackedVector2Array()  # Current pathfinding path
var pathfinding_source: Vector2i = Vector2i(-1, -1)  # Source position for pathfinding (or -1, -1 if no source)

# Mission Highlight Pulse Effect Variables
var mission_pulse_alpha: float = 0.5
var mission_pulse_direction: float = 1.0
const PULSE_MIN_ALPHA: float = 0.2
const PULSE_MAX_ALPHA: float = 0.7
const PULSE_SPEED: float = 1.5


func _process(delta: float) -> void:
	if mission_highlight_tiles.is_empty():
		return
		
	mission_pulse_alpha += mission_pulse_direction * PULSE_SPEED * delta
	
	if mission_pulse_alpha >= PULSE_MAX_ALPHA:
		mission_pulse_alpha = PULSE_MAX_ALPHA
		mission_pulse_direction = -1.0
	elif mission_pulse_alpha <= PULSE_MIN_ALPHA:
		mission_pulse_alpha = PULSE_MIN_ALPHA
		mission_pulse_direction = 1.0
		
	queue_redraw()


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


## Mark this map as an Abandoned Station (enables decay/fire visual overlays)
func set_abandoned_station(value: bool) -> void:
	is_abandoned_station = value
	if static_layer:
		static_layer.queue_redraw()


## Set map dimensions
func set_map_dimensions(width: int, height: int) -> void:
	map_width = width
	map_height = height
	# Reinitialize A* with new dimensions
	_setup_astar()



func initialize_map(layout: Dictionary, biome_type: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION) -> void:
	# Clear previous map data first to prevent artifacts
	clear_map()

	set_biome(biome_type)
	tile_data = layout
	mission_highlight_tiles.clear()
	_update_astar_solids()
	_initialize_fog()
	static_layer.queue_redraw()
	queue_redraw()


## Clear all map data and remove all units/interactables
func clear_map() -> void:
	# Clear data structures
	tile_data.clear()
	revealed_tiles.clear()
	movement_range_tiles.clear()
	execute_range_tiles.clear()
	heal_range_tiles.clear()
	enemy_target_tiles.clear()
	mission_highlight_tiles.clear()
	pathfinding_path.clear()
	hovered_tile = Vector2i(-1, -1)
	pathfinding_source = Vector2i(-1, -1)
	
	# Reset mission pulse state
	mission_pulse_alpha = 0.5
	mission_pulse_direction = 1.0
	
	# Clear A* (reset region is handled in setup/resize)
	if astar:
		astar.clear()
		_setup_astar()
	
	# Immediately free all children to prevent stale nodes on re-deploy
	if units_container:
		for child in units_container.get_children():
			units_container.remove_child(child)
			child.queue_free()
			
	if interactables_container:
		for child in interactables_container.get_children():
			interactables_container.remove_child(child)
			child.queue_free()
			
	# Force redraw so visual artifacts are cleared immediately
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
		static_layer.queue_redraw()
		queue_redraw()


func _reveal_interactables_at(pos: Vector2i) -> void:
	var world_pos = grid_to_world(pos)
	for interactable in interactables_container.get_children():
		if interactable.position.distance_to(world_pos) < TILE_SIZE / 2:
			interactable.visible = true


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	# Check if destination is blocked by terrain
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


## Check if a tile has a turret on it
func has_turret_at(pos: Vector2i) -> bool:
	var world_pos = grid_to_world(pos)
	# Check all children for turrets (turrets are added as children to tactical_map)
	for child in get_children():
		# Check if this child is a turret by checking if it has the turret-specific methods
		if child.has_method("get_grid_position") and child.has_method("tick_turn"):
			var turret_pos = child.get_grid_position()
			if turret_pos == pos:
				return true
	return false


func is_tile_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	# Check if tile is blocked by terrain
	if astar.is_point_solid(pos):
		return false
	return true


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


## Add a mission highlight to a specific tile
func add_mission_highlight(pos: Vector2i) -> void:
	mission_highlight_tiles[pos] = true
	queue_redraw()


## Remove a mission highlight from a specific tile
func remove_mission_highlight(pos: Vector2i) -> void:
	if mission_highlight_tiles.has(pos):
		mission_highlight_tiles.erase(pos)
		queue_redraw()


func _draw() -> void:
	# Static tiles are drawn by StaticLayer ($StaticLayer) — only redraws on map/fog changes.
	# This _draw() handles dynamic per-frame overlays only (highlights, hover, pathfinding).

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			if not revealed_tiles.get(pos, false):
				continue
			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			# Mission objective highlight (Gold) with pulse effect
			if mission_highlight_tiles.get(pos, false):
				var highlight_color = COLOR_MISSION_HIGHLIGHT
				highlight_color.a = mission_pulse_alpha
				draw_rect(rect, highlight_color)

			# Movement range highlight
			if movement_range_tiles.get(pos, false):
				draw_rect(rect, COLOR_MOVEMENT_RANGE)

			# Heal range highlight (light green)
			if heal_range_tiles.get(pos, false):
				draw_rect(rect, COLOR_HEAL_RANGE)

			# Execute range highlight (red)
			if execute_range_tiles.get(pos, false):
				draw_rect(rect, COLOR_EXECUTE_RANGE)

			# Enemy target tiles highlight (red - tiles under attackable enemies)
			if enemy_target_tiles.get(pos, false):
				draw_rect(rect, COLOR_EXECUTE_RANGE)

			# Hover effect
			if pos == hovered_tile:
				draw_rect(rect, COLOR_HOVER)

	# Draw pathfinding path line (draw after tiles but before units)
	if pathfinding_path.size() > 1:
		# AStarGrid2D.get_point_path() returns world positions at tile corners
		# We need to center them for better visual alignment with units
		var centered_points: PackedVector2Array = []
		const TILE_HALF = TILE_SIZE / 2.0
		
		for corner_pos in pathfinding_path:
			# Convert corner position to center position
			centered_points.append(corner_pos + Vector2(TILE_HALF, TILE_HALF))
		
		# Draw solid continuous line with glow effect
		# Draw glow effect first (larger, more transparent line behind)
		draw_polyline(centered_points, COLOR_PATHFINDING_GLOW, 8.0, true)
		# Draw main neon blue line on top
		draw_polyline(centered_points, COLOR_PATHFINDING_LINE, 4.0, true)
		
		# Draw one large arrowhead at the final destination
		if centered_points.size() >= 2:
			var final_point = centered_points[centered_points.size() - 1]
			var second_to_last = centered_points[centered_points.size() - 2]
			var direction = (final_point - second_to_last).normalized()
			
			var arrow_size = 10.0 
			# Position arrow tip so the base of the arrow just barely touches the end of the path line
			# The base is at arrow_tip - direction * arrow_size, so we position tip at final_point + direction * arrow_size
			var arrow_tip = final_point + direction * arrow_size
			# Create perpendicular vectors for arrow sides (pointing backwards from direction)
			var back_direction = -direction
			var perp = Vector2(-direction.y, direction.x)  # Perpendicular vector
			var arrow_left = arrow_tip + back_direction * arrow_size + perp * arrow_size * 0.6
			var arrow_right = arrow_tip + back_direction * arrow_size - perp * arrow_size * 0.6
			
			# Draw large arrowhead with glow
			var arrow_points: PackedVector2Array = [arrow_tip, arrow_left, arrow_right]
			draw_colored_polygon(arrow_points, COLOR_PATHFINDING_GLOW)
			draw_colored_polygon(arrow_points, COLOR_PATHFINDING_LINE)
	
## All tile drawing helpers have moved to map_static_layer.gd.

func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse movement for hover effects
	if event is InputEventMouseMotion:
		var local_mouse = get_local_mouse_position()
		var grid_pos = world_to_grid(local_mouse)
		
		if grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height:
			if hovered_tile != grid_pos:
				hovered_tile = grid_pos
				tile_hovered.emit(grid_pos)
				queue_redraw()
		else:
			if hovered_tile != Vector2i(-1, -1):
				hovered_tile = Vector2i(-1, -1)
				tile_hovered.emit(Vector2i(-1, -1))
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
		# Check if unit occupies this grid position
		var unit_grid_pos: Vector2i
		if unit.has_method("get_grid_position"):
			unit_grid_pos = unit.get_grid_position()
		else:
			# Fallback to distance check
			if unit.position.distance_to(world_pos) < tolerance:
				return unit
			continue
		
		# Get unit size (default to 1x1)
		var unit_size = Vector2i(1, 1)
		# Check if unit has unit_size property by trying to get it
		var size_value = unit.get("unit_size")
		if size_value != null:
			unit_size = size_value
		
		# Check if grid_pos is within the unit's occupied tiles
		var occupied_tiles = get_occupied_tiles(unit_grid_pos, unit_size)
		if grid_pos in occupied_tiles:
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


## Get all tiles occupied by a unit (handles multi-tile units)
func get_occupied_tiles(grid_pos: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for dx in range(size.x):
		for dy in range(size.y):
			occupied.append(grid_pos + Vector2i(dx, dy))
	return occupied


func add_unit(unit: Node2D, grid_pos: Vector2i) -> void:
	# Check if unit has unit_size property (for multi-tile units like bosses)
	var unit_size = Vector2i(1, 1)
	if unit.has_method("get") and unit.get("unit_size"):
		unit_size = unit.unit_size
	
	if unit_size == Vector2i(2, 2):
		# For 2x2 units, center on the 2x2 area
		var center_grid = grid_pos + Vector2i(1, 1)
		unit.position = grid_to_world(center_grid)
	else:
		# For 1x1 units, center on the tile
		unit.position = grid_to_world(grid_pos)
	
	units_container.add_child(unit)
	# Removed: set_unit_position_solid(grid_pos, true) - Units are no longer solid
	
	# Mark all occupied tiles as solid for multi-tile units
	if unit_size == Vector2i(2, 2):
		pass # Multi-tile units are also traversable now
		for dx in range(2):
			for dy in range(2):
				var occupied_pos = grid_pos + Vector2i(dx, dy)
				set_unit_position_solid(occupied_pos, true)


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
				
				# Check if walkable (not solid terrain) and not visited
				# Note: astar.is_point_solid now only checks terrain, not units
				if not visited.has(next_pos) and not astar.is_point_solid(next_pos):
					visited[next_pos] = true
					distances[next_pos] = dist + 1
					
					# Only mark as valid destination if NOT occupied by another unit or turret
					# Self is okay (though effectively a no-op move)
					var interactable = get_interactable_at(next_pos)
					var unit_at_pos = get_unit_at(next_pos)
					
					# Valid destination if:
					# 1. No unit at position OR unit is self
					# 2. No turret at position (turrets are separate from units list)
					# 3. No interactable that blocks movement (optional, but keep consistent)
					var is_occupied = (unit_at_pos != null and unit_at_pos.get_grid_position() != center) or has_turret_at(next_pos)
					
					if not is_occupied:
						movement_range_tiles[next_pos] = true
					
					# Always continue pathfinding through tiles (even occupied ones)
					queue.append(next_pos)
	
	# Restore center solidity
	if center_was_solid:
		astar.set_point_solid(center, true)
	
	queue_redraw()


func clear_movement_range(preserve_pathfinding: bool = false) -> void:
	movement_range_tiles.clear()
	hovered_tile = Vector2i(-1, -1)
	if not preserve_pathfinding:
		clear_pathfinding_path()
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


## Set turret placement range highlight (manhattan distance, red tiles, filtered to walkable and empty tiles only)
func set_turret_placement_range(center: Vector2i, placement_range: int) -> void:
	execute_range_tiles.clear()
	
	for x in range(center.x - placement_range, center.x + placement_range + 1):
		for y in range(center.y - placement_range, center.y + placement_range + 1):
			var pos = Vector2i(x, y)
			if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
				continue
			if pos == center:
				continue
			var distance = abs(pos.x - center.x) + abs(pos.y - center.y)
			if distance <= placement_range and revealed_tiles.get(pos, false):
				# Only show tiles that are walkable and empty (no units, interactables, or turrets)
				if is_tile_walkable(pos) and get_unit_at(pos) == null and get_interactable_at(pos) == null and not has_turret_at(pos):
					execute_range_tiles[pos] = true
	
	queue_redraw()


## Clear execute range highlight
func clear_execute_range() -> void:
	execute_range_tiles.clear()
	queue_redraw()


## Set enemy target tile highlight (red tint for tiles under attackable enemies)
func set_enemy_target_tile(grid_pos: Vector2i, unit_size: Vector2i = Vector2i(1, 1)) -> void:
	# Handle multi-tile units (like bosses)
	var occupied_tiles = get_occupied_tiles(grid_pos, unit_size)
	for pos in occupied_tiles:
		if pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height:
			if revealed_tiles.get(pos, false):
				enemy_target_tiles[pos] = true
	queue_redraw()


## Clear enemy target tile highlight
func clear_enemy_target_tile(grid_pos: Vector2i, unit_size: Vector2i = Vector2i(1, 1)) -> void:
	var occupied_tiles = get_occupied_tiles(grid_pos, unit_size)
	for pos in occupied_tiles:
		enemy_target_tiles.erase(pos)
	queue_redraw()


## Clear all enemy target tile highlights
func clear_all_enemy_target_tiles() -> void:
	enemy_target_tiles.clear()
	queue_redraw()


## Set heal range highlight (manhattan distance, light green tiles, shows all tiles within range)
func set_heal_range(center: Vector2i, heal_range: int, medic_unit: Node2D, deployed_officers: Array) -> void:
	heal_range_tiles.clear()
	
	for x in range(center.x - heal_range, center.x + heal_range + 1):
		for y in range(center.y - heal_range, center.y + heal_range + 1):
			var pos = Vector2i(x, y)
			if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
				continue
			var distance = abs(pos.x - center.x) + abs(pos.y - center.y)
			if distance <= heal_range and revealed_tiles.get(pos, false):
				# Show all tiles within range (potential heal targets, including self)
				heal_range_tiles[pos] = true
	
	queue_redraw()


## Clear heal range highlight
func clear_heal_range() -> void:
	heal_range_tiles.clear()
	queue_redraw()


## Update pathfinding path from source to target
func update_pathfinding_path(source_pos: Vector2i, target_pos: Vector2i) -> void:
	pathfinding_source = source_pos
	
	# If source and target are the same, show empty path
	if source_pos == target_pos:
		pathfinding_path.clear()
		queue_redraw()
		return
	
	# Check if target is within movement range
	if not movement_range_tiles.get(target_pos, false):
		pathfinding_path.clear()
		queue_redraw()
		return
	
	# Calculate path using A*
	var path = find_path(source_pos, target_pos)
	
	if path.is_empty() or path.size() < 2:
		pathfinding_path.clear()
	else:
		pathfinding_path = path
	
	queue_redraw()


## Clear pathfinding path
func clear_pathfinding_path() -> void:
	pathfinding_path.clear()
	pathfinding_source = Vector2i(-1, -1)


## Update pathfinding path for Bulldozer Charge - shows straight line path through half-cover
func update_charge_pathfinding_path(source_pos: Vector2i, target_pos: Vector2i) -> void:
	pathfinding_source = source_pos
	
	if source_pos == target_pos:
		pathfinding_path.clear()
		queue_redraw()
		return
	
	# Use Bresenham line algorithm for straight-line path (bulldozer goes through half-cover)
	var line_tiles = _get_line_tiles(source_pos, target_pos)
	
	# Convert to world positions for pathfinding display
	var path = PackedVector2Array()
	for tile in line_tiles:
		path.append(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE))
	
	if path.is_empty():
		pathfinding_path.clear()
	else:
		pathfinding_path = path
	queue_redraw()


## Get tiles along a line using Bresenham's algorithm (internal use)
func _get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	while true:
		tiles.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	
	return tiles


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
