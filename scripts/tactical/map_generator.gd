extends RefCounted
## Simple procedural map generator for tactical missions
class_name MapGenerator

enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }

var map_width: int = 20
var map_height: int = 20
var _layout: Dictionary = {}  # Stored layout for spawn validation
var _occupied_positions: Array[Vector2i] = []  # Track positions already used for spawns


func generate() -> Dictionary:
	var layout: Dictionary = {}
	_occupied_positions.clear()

	# Fill with floor
	for x in range(map_width):
		for y in range(map_height):
			layout[Vector2i(x, y)] = TileType.FLOOR

	# Add border walls
	for x in range(map_width):
		layout[Vector2i(x, 0)] = TileType.WALL
		layout[Vector2i(x, map_height - 1)] = TileType.WALL
	for y in range(map_height):
		layout[Vector2i(0, y)] = TileType.WALL
		layout[Vector2i(map_width - 1, y)] = TileType.WALL

	# Add some random interior walls (simple rooms)
	_add_random_walls(layout)
	
	# Add cover crates
	_add_cover_crates(layout)

	# Add extraction zone (bottom-left corner area)
	_add_extraction_zone(layout)

	# Store layout for spawn position validation
	_layout = layout
	return layout


func _add_random_walls(layout: Dictionary) -> void:
	# Add a few vertical wall segments
	for i in range(3):
		var start_x = randi_range(4, map_width - 5)
		var start_y = randi_range(3, map_height - 6)
		var length = randi_range(3, 6)

		for j in range(length):
			var pos = Vector2i(start_x, start_y + j)
			# Don't block the spawn area (top-right) or extraction (bottom-left)
			if pos.x > 3 and pos.x < map_width - 4:
				layout[pos] = TileType.WALL

	# Add a few horizontal wall segments
	for i in range(3):
		var start_x = randi_range(4, map_width - 6)
		var start_y = randi_range(4, map_height - 5)
		var length = randi_range(3, 5)

		for j in range(length):
			var pos = Vector2i(start_x + j, start_y)
			if pos.y > 3 and pos.y < map_height - 4:
				layout[pos] = TileType.WALL

	# Add some scattered obstacles
	for i in range(10):
		var pos = Vector2i(randi_range(3, map_width - 4), randi_range(3, map_height - 4))
		layout[pos] = TileType.WALL


func _add_extraction_zone(layout: Dictionary) -> void:
	# Bottom-left 3x3 area as extraction zone
	for x in range(1, 4):
		for y in range(map_height - 4, map_height - 1):
			layout[Vector2i(x, y)] = TileType.EXTRACTION


func get_spawn_positions() -> Array[Vector2i]:
	# Top-right corner spawn points
	var positions: Array[Vector2i] = [
		Vector2i(map_width - 3, 2),
		Vector2i(map_width - 4, 2),
		Vector2i(map_width - 3, 3),
	]
	# Mark these as occupied
	for pos in positions:
		_occupied_positions.append(pos)
	return positions


## Check if a position is valid for spawning (floor tile, not occupied)
func _is_valid_spawn_position(pos: Vector2i) -> bool:
	# Must be a floor tile (not wall, cover, or extraction)
	var tile_type = _layout.get(pos, TileType.WALL)
	if tile_type != TileType.FLOOR:
		return false
	# Must not already be occupied
	if pos in _occupied_positions:
		return false
	return true


## Find a valid spawn position within the given bounds
func _find_valid_spawn_position(min_x: int, max_x: int, min_y: int, max_y: int, max_attempts: int = 50) -> Vector2i:
	for attempt in range(max_attempts):
		var pos = Vector2i(randi_range(min_x, max_x), randi_range(min_y, max_y))
		if _is_valid_spawn_position(pos):
			_occupied_positions.append(pos)
			return pos
	# Fallback: search exhaustively if random attempts fail
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			if _is_valid_spawn_position(pos):
				_occupied_positions.append(pos)
				return pos
	return Vector2i(-1, -1)  # No valid position found


func get_loot_positions() -> Array[Dictionary]:
	var positions: Array[Dictionary] = []

	# Fuel crates (2-3)
	var num_fuel = randi_range(2, 3)
	for i in range(num_fuel):
		var pos = _find_valid_spawn_position(5, map_width - 6, 5, map_height - 6)
		if pos != Vector2i(-1, -1):
			positions.append({
				"type": "fuel",
				"position": pos
			})

	# Scrap piles (3-5)
	var num_scrap = randi_range(3, 5)
	for i in range(num_scrap):
		var pos = _find_valid_spawn_position(4, map_width - 5, 4, map_height - 5)
		if pos != Vector2i(-1, -1):
			positions.append({
				"type": "scrap",
				"position": pos
			})

	return positions


func get_extraction_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in range(1, 4):
		for y in range(map_height - 4, map_height - 1):
			positions.append(Vector2i(x, y))
	return positions


func get_enemy_spawn_positions() -> Array[Vector2i]:
	# Spawn enemies in the middle-left area, away from player spawn
	var positions: Array[Vector2i] = []
	var num_enemies = randi_range(3, 5)
	
	for i in range(num_enemies):
		var pos = _find_valid_spawn_position(3, 8, 5, map_height - 6)
		if pos != Vector2i(-1, -1):
			positions.append(pos)
	
	return positions


func get_cover_crate_positions() -> Array[Vector2i]:
	# Return positions where destructible cover crates should be placed
	var positions: Array[Vector2i] = []
	
	# Place 5-8 cover crates scattered around the map
	for i in range(randi_range(5, 8)):
		var pos = Vector2i(
			randi_range(5, map_width - 6),
			randi_range(4, map_height - 5)
		)
		# Don't place on spawn or extraction zones
		if pos.x > 4 and pos.x < map_width - 5:
			positions.append(pos)
	
	return positions


func _add_cover_crates(layout: Dictionary) -> void:
	# Add some HALF_COVER tiles (these will be destructible crates)
	for i in range(randi_range(6, 10)):
		var pos = Vector2i(
			randi_range(5, map_width - 6),
			randi_range(5, map_height - 6)
		)
		# Only place on floor tiles, not in spawn or extraction areas
		if layout.get(pos, TileType.FLOOR) == TileType.FLOOR:
			if pos.x > 4 and pos.x < map_width - 5:
				layout[pos] = TileType.HALF_COVER
