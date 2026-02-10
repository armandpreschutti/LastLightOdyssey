extends RefCounted
## Procedural map generator for tactical missions with biome-specific generation
class_name MapGenerator

enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }

var map_width: int = 20
var map_height: int = 20
var _layout: Dictionary = {}  # Stored layout for spawn validation
var _occupied_positions: Array[Vector2i] = []  # Track positions already used for spawns
var _biome_type: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION
var _rooms: Array[Rect2i] = []  # For BSP generation - stores room rects

#region BSP Tree Node for Station Generation
class BSPNode:
	var rect: Rect2i
	var left: BSPNode = null
	var right: BSPNode = null
	var room: Rect2i = Rect2i()
	
	func _init(r: Rect2i) -> void:
		rect = r
	
	func is_leaf() -> bool:
		return left == null and right == null
#endregion


func generate(biome_type: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION, node_index: int = 0, total_nodes: int = 50) -> Dictionary:
	_biome_type = biome_type
	_occupied_positions.clear()
	_rooms.clear()
	
	# Get map size from biome config (scaled by voyage progression)
	var size = BiomeConfig.get_map_size(biome_type, node_index, total_nodes)
	map_width = size.x
	map_height = size.y
	
	var layout: Dictionary = {}
	
	# Get layout configuration
	var layout_config = BiomeConfig.get_layout_config(biome_type)
	
	# Generate based on biome type
	match layout_config["type"]:
		"bsp":
			layout = _generate_bsp_layout(layout_config)
		"cave":
			layout = _generate_cave_layout(layout_config)
		"open":
			layout = _generate_open_layout(layout_config)
		_:
			layout = _generate_bsp_layout(layout_config)
	
	# Add extraction zone
	_add_extraction_zone(layout)
	
	# Ensure perimeter walls are always present (fixes edge gaps)
	_ensure_perimeter_walls(layout)
	
	# Store layout for spawn position validation
	_layout = layout
	return layout


#region BSP Room Generation (Station Biome)

func _generate_bsp_layout(config: Dictionary) -> Dictionary:
	var layout: Dictionary = {}
	
	# Fill with walls initially
	for x in range(map_width):
		for y in range(map_height):
			layout[Vector2i(x, y)] = TileType.WALL
	
	# Calculate playable area (excluding 1-tile border)
	var playable_width = map_width - 2
	var playable_height = map_height - 2
	var playable_area = playable_width * playable_height
	
	# Calculate base area for scaling (17x17 map = 15x15 playable = 225 tiles)
	var base_playable_area = 15 * 15
	
	# Create BSP tree (1-tile border maintained)
	var root = BSPNode.new(Rect2i(1, 1, playable_width, playable_height))
	
	# Adjust splitting aggressiveness based on map size
	# Larger maps should split more aggressively to create more rooms
	var area_ratio = float(playable_area) / float(base_playable_area)
	var min_room_size = config["min_room_size"]
	var max_room_size = config["max_room_size"]
	
	# Pass map dimensions for size-aware splitting
	_split_bsp(root, min_room_size, max_room_size, playable_width, playable_height, area_ratio)
	
	# Create rooms in leaf nodes
	_create_rooms(root, min_room_size, max_room_size)
	
	# Carve out rooms and corridors
	_carve_bsp_layout(root, layout, config["corridor_width"])
	
	# Add cover crates
	_add_cover_to_rooms(layout, config["cover_density"])
	
	return layout


func _split_bsp(node: BSPNode, min_size: int, _max_size: int, map_width: int = 0, map_height: int = 0, area_ratio: float = 1.0) -> void:
	# Calculate size-aware minimum threshold
	# On larger maps, be more aggressive with splitting (lower threshold)
	# This creates more rooms instead of leaving wall space
	var adjusted_min_size = min_size
	if area_ratio > 1.0:
		# For larger maps, reduce the minimum size threshold to allow more splits
		# This scales down the threshold proportionally, but not too aggressively
		adjusted_min_size = maxi(min_size - 1, int(min_size * (1.0 / sqrt(area_ratio))))
	
	# Calculate node area to determine if we should continue splitting
	var node_area = node.rect.size.x * node.rect.size.y
	var base_node_area = 15 * 15  # Base map playable area
	var node_area_ratio = float(node_area) / float(base_node_area)
	
	# Stop if too small to split (using adjusted threshold)
	var min_split_threshold = adjusted_min_size * 2 + 3
	if node.rect.size.x < min_split_threshold and node.rect.size.y < min_split_threshold:
		return
	
	# On larger maps, be more likely to continue splitting even if node is relatively small
	# This ensures we create more rooms on larger maps
	var should_continue_splitting = true
	if area_ratio > 1.2:  # Maps significantly larger than base
		# On large maps, continue splitting if node is still reasonably large
		var large_map_threshold = adjusted_min_size * 2 + 2
		if node.rect.size.x < large_map_threshold and node.rect.size.y < large_map_threshold:
			# Only stop if both dimensions are very small
			if node.rect.size.x < adjusted_min_size + 2 and node.rect.size.y < adjusted_min_size + 2:
				should_continue_splitting = false
	else:
		# On normal/small maps, use standard threshold
		if node.rect.size.x < min_split_threshold and node.rect.size.y < min_split_threshold:
			should_continue_splitting = false
	
	if not should_continue_splitting:
		return
	
	# Decide split direction based on aspect ratio and randomness
	var split_horizontal: bool
	if node.rect.size.x > node.rect.size.y * 1.25:
		split_horizontal = false
	elif node.rect.size.y > node.rect.size.x * 1.25:
		split_horizontal = true
	else:
		split_horizontal = randf() > 0.5
	
	var max_split: int
	var min_split: int
	
	if split_horizontal:
		min_split = adjusted_min_size + 1
		max_split = node.rect.size.y - adjusted_min_size - 1
	else:
		min_split = adjusted_min_size + 1
		max_split = node.rect.size.x - adjusted_min_size - 1
	
	if max_split <= min_split:
		return  # Can't split
	
	var split_pos = randi_range(min_split, max_split)
	
	if split_horizontal:
		node.left = BSPNode.new(Rect2i(node.rect.position.x, node.rect.position.y, 
									   node.rect.size.x, split_pos))
		node.right = BSPNode.new(Rect2i(node.rect.position.x, node.rect.position.y + split_pos,
										node.rect.size.x, node.rect.size.y - split_pos))
	else:
		node.left = BSPNode.new(Rect2i(node.rect.position.x, node.rect.position.y,
									   split_pos, node.rect.size.y))
		node.right = BSPNode.new(Rect2i(node.rect.position.x + split_pos, node.rect.position.y,
										node.rect.size.x - split_pos, node.rect.size.y))
	
	# Recursively split children (pass along map dimensions and area ratio)
	_split_bsp(node.left, min_size, _max_size, map_width, map_height, area_ratio)
	_split_bsp(node.right, min_size, _max_size, map_width, map_height, area_ratio)


func _create_rooms(node: BSPNode, min_size: int, max_size: int) -> void:
	if node.left != null:
		_create_rooms(node.left, min_size, max_size)
	if node.right != null:
		_create_rooms(node.right, min_size, max_size)
	
	if node.is_leaf():
		# Create a room within this leaf
		var room_width = randi_range(min_size, mini(max_size, node.rect.size.x - 2))
		var room_height = randi_range(min_size, mini(max_size, node.rect.size.y - 2))
		
		var room_x = node.rect.position.x + randi_range(1, node.rect.size.x - room_width - 1)
		var room_y = node.rect.position.y + randi_range(1, node.rect.size.y - room_height - 1)
		
		node.room = Rect2i(room_x, room_y, room_width, room_height)
		_rooms.append(node.room)


func _carve_bsp_layout(node: BSPNode, layout: Dictionary, corridor_width: int) -> void:
	if node.is_leaf():
		# Carve out the room
		for x in range(node.room.position.x, node.room.position.x + node.room.size.x):
			for y in range(node.room.position.y, node.room.position.y + node.room.size.y):
				layout[Vector2i(x, y)] = TileType.FLOOR
	else:
		# Process children
		if node.left != null:
			_carve_bsp_layout(node.left, layout, corridor_width)
		if node.right != null:
			_carve_bsp_layout(node.right, layout, corridor_width)
		
		# Connect children with corridors
		if node.left != null and node.right != null:
			var left_center = _get_room_center(node.left)
			var right_center = _get_room_center(node.right)
			_carve_corridor(layout, left_center, right_center, corridor_width)


func _get_room_center(node: BSPNode) -> Vector2i:
	if node.is_leaf():
		return Vector2i(node.room.position.x + node.room.size.x / 2,
						node.room.position.y + node.room.size.y / 2)
	else:
		# Recursively find a room center
		if node.left != null:
			return _get_room_center(node.left)
		elif node.right != null:
			return _get_room_center(node.right)
		return Vector2i(node.rect.position.x + node.rect.size.x / 2,
						node.rect.position.y + node.rect.size.y / 2)


func _carve_corridor(layout: Dictionary, from: Vector2i, to: Vector2i, width: int) -> void:
	var half_width = width / 2
	
	# Decide whether to go horizontal first or vertical first
	if randf() > 0.5:
		# Horizontal then vertical
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			for w in range(-half_width, half_width + 1):
				var pos = Vector2i(x, from.y + w)
				if pos.x > 0 and pos.x < map_width - 1 and pos.y > 0 and pos.y < map_height - 1:
					layout[pos] = TileType.FLOOR
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for w in range(-half_width, half_width + 1):
				var pos = Vector2i(to.x + w, y)
				if pos.x > 0 and pos.x < map_width - 1 and pos.y > 0 and pos.y < map_height - 1:
					layout[pos] = TileType.FLOOR
	else:
		# Vertical then horizontal
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for w in range(-half_width, half_width + 1):
				var pos = Vector2i(from.x + w, y)
				if pos.x > 0 and pos.x < map_width - 1 and pos.y > 0 and pos.y < map_height - 1:
					layout[pos] = TileType.FLOOR
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			for w in range(-half_width, half_width + 1):
				var pos = Vector2i(x, to.y + w)
				if pos.x > 0 and pos.x < map_width - 1 and pos.y > 0 and pos.y < map_height - 1:
					layout[pos] = TileType.FLOOR


func _add_cover_to_rooms(layout: Dictionary, density: float) -> void:
	# Use pattern-based placement instead of random density
	var placed_patterns: Array[Vector2i] = []
	
	# Process each room
	for room in _rooms:
		# Determine pattern size for this room
		var pattern_size = CoverPatterns.get_pattern_size_for_room(room.size.x, room.size.y)
		
		# Calculate how many patterns to place based on room size and density
		var room_area = room.size.x * room.size.y
		var target_patterns = maxi(1, int(room_area * density / 5.0))  # Scale down from density
		target_patterns = mini(target_patterns, 3)  # Max 3 patterns per room
		
		var patterns_placed = 0
		var attempts = 0
		var max_attempts = 20
		
		while patterns_placed < target_patterns and attempts < max_attempts:
			attempts += 1
			
			# Get random pattern of appropriate size
			var pattern = CoverPatterns.get_random_pattern(pattern_size)
			if pattern.is_empty():
				continue
			
			# Apply random transformation for variety
			var transform = CoverPatterns.get_random_transformation()
			pattern = CoverPatterns.apply_transformation(pattern, transform)
			
			# Find valid placement positions in room
			var valid_positions = _find_pattern_placement_in_room(layout, pattern, room)
			if valid_positions.is_empty():
				continue
			
			# Try a few random positions
			valid_positions.shuffle()
			for try_pos in valid_positions:
				# Check spacing from other patterns
				if not _check_pattern_spacing(placed_patterns, try_pos, 3):
					continue
				
				# Place the pattern
				if _place_pattern(layout, pattern, try_pos):
					placed_patterns.append(try_pos)
					patterns_placed += 1
					break

#endregion

#region Cellular Automata Cave Generation (Asteroid Biome)

func _generate_cave_layout(config: Dictionary) -> Dictionary:
	var layout: Dictionary = {}
	
	# Initialize with random fill
	for x in range(map_width):
		for y in range(map_height):
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				layout[Vector2i(x, y)] = TileType.WALL
			elif randf() < config["initial_fill_chance"]:
				layout[Vector2i(x, y)] = TileType.WALL
			else:
				layout[Vector2i(x, y)] = TileType.FLOOR
	
	# Apply cellular automata smoothing
	for _iteration in range(config["smoothing_iterations"]):
		layout = _smooth_cave(layout, config["wall_threshold"])
	
	# Ensure connectivity by flood-filling from a starting point
	_ensure_cave_connectivity(layout)
	
	# Add some cover in open areas
	_add_cave_cover(layout, config["cover_density"])
	
	# Create proper rooms list for spawn positioning
	_identify_cave_regions(layout)
	
	return layout


func _smooth_cave(layout: Dictionary, wall_threshold: int) -> Dictionary:
	var new_layout: Dictionary = {}
	
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			
			# Border always stays wall
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				new_layout[pos] = TileType.WALL
				continue
			
			# Count wall neighbors (including diagonals)
			var wall_count = 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var neighbor = Vector2i(x + dx, y + dy)
					if layout.get(neighbor, TileType.WALL) == TileType.WALL:
						wall_count += 1
			
			# Apply rule
			if wall_count >= wall_threshold:
				new_layout[pos] = TileType.WALL
			else:
				new_layout[pos] = TileType.FLOOR
	
	return new_layout


func _ensure_cave_connectivity(layout: Dictionary) -> void:
	# Find the largest connected region and fill others
	var visited: Dictionary = {}
	var regions: Array[Array] = []
	
	for x in range(1, map_width - 1):
		for y in range(1, map_height - 1):
			var pos = Vector2i(x, y)
			if layout.get(pos, TileType.WALL) == TileType.FLOOR and not visited.has(pos):
				var region = _flood_fill_region(layout, pos, visited)
				regions.append(region)
	
	# Keep only the largest region
	if regions.size() > 0:
		var largest_idx = 0
		var largest_size = regions[0].size()
		for i in range(1, regions.size()):
			if regions[i].size() > largest_size:
				largest_size = regions[i].size()
				largest_idx = i
		
		# Fill all other regions with walls
		for i in range(regions.size()):
			if i != largest_idx:
				for pos in regions[i]:
					layout[pos] = TileType.WALL
		
		# If the cave is too small, expand it aggressively
		var min_floor_tiles = (map_width * map_height) / 3
		while largest_size < min_floor_tiles:
			_expand_cave(layout)
			# Recount floor tiles
			largest_size = 0
			for x in range(1, map_width - 1):
				for y in range(1, map_height - 1):
					if layout.get(Vector2i(x, y), TileType.WALL) == TileType.FLOOR:
						largest_size += 1
			# Safety break to prevent infinite loop
			if largest_size >= min_floor_tiles or largest_size > (map_width * map_height) / 2:
				break
	else:
		# No floor regions found at all - carve out a cave from scratch
		_carve_emergency_cave(layout)


func _flood_fill_region(layout: Dictionary, start: Vector2i, visited: Dictionary) -> Array:
	var region: Array = []
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		region.append(pos)
		
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor = pos + dir
			if not visited.has(neighbor) and layout.get(neighbor, TileType.WALL) == TileType.FLOOR:
				visited[neighbor] = true
				queue.append(neighbor)
	
	return region


func _expand_cave(layout: Dictionary) -> void:
	# Expansion - convert walls adjacent to floor to floor
	var to_convert: Array[Vector2i] = []
	
	for x in range(2, map_width - 2):
		for y in range(2, map_height - 2):
			var pos = Vector2i(x, y)
			if layout.get(pos, TileType.WALL) == TileType.WALL:
				# Count floor neighbors
				var floor_count = 0
				for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if layout.get(pos + dir, TileType.WALL) == TileType.FLOOR:
						floor_count += 1
				
				# More aggressive expansion
				if floor_count >= 1 and randf() < 0.6:
					to_convert.append(pos)
	
	for pos in to_convert:
		layout[pos] = TileType.FLOOR


func _carve_emergency_cave(layout: Dictionary) -> void:
	# Carve out a basic cave system when cellular automata fails completely
	
	# Create a winding path from top-right to bottom-left
	var current = Vector2i(map_width - 4, 4)
	var target = Vector2i(4, map_height - 4)
	
	# Carve starting area
	_carve_circle(layout, current, 3)
	
	# Random walk toward target
	var max_steps = map_width * map_height
	var steps = 0
	while current.distance_to(Vector2(target)) > 5 and steps < max_steps:
		steps += 1
		
		# Bias toward target but allow randomness
		var dx = 0
		var dy = 0
		
		if randf() < 0.6:  # 60% chance to move toward target
			if current.x > target.x:
				dx = -1
			elif current.x < target.x:
				dx = 1
			if current.y > target.y:
				dy = -1
			elif current.y < target.y:
				dy = 1
			
			# Pick one direction randomly
			if randf() > 0.5:
				dx = 0
			else:
				dy = 0
		else:
			# Random direction
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var dir = dirs[randi() % dirs.size()]
			dx = dir.x
			dy = dir.y
		
		current.x = clampi(current.x + dx, 3, map_width - 4)
		current.y = clampi(current.y + dy, 3, map_height - 4)
		
		# Carve as we go
		var radius = randi_range(1, 3)
		_carve_circle(layout, current, radius)
	
	# Carve ending area
	_carve_circle(layout, target, 3)


func _carve_circle(layout: Dictionary, center: Vector2i, radius: int) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var pos = Vector2i(x, y)
			if pos.x > 0 and pos.x < map_width - 1 and pos.y > 0 and pos.y < map_height - 1:
				var dist = abs(x - center.x) + abs(y - center.y)
				if dist <= radius:
					layout[pos] = TileType.FLOOR


func _add_cave_cover(layout: Dictionary, density: float) -> void:
	# Use pattern-based placement for caves
	# Find open areas in the cave (3x3 or larger clear spaces)
	var open_areas: Array[Dictionary] = []
	
	for x in range(3, map_width - 3):
		for y in range(3, map_height - 3):
			var pos = Vector2i(x, y)
			if layout.get(pos, TileType.WALL) != TileType.FLOOR:
				continue
			
			# Check if this is the center of an open area (3x3 clear)
			var is_open_center = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var check_pos = pos + Vector2i(dx, dy)
					if layout.get(check_pos, TileType.WALL) != TileType.FLOOR:
						is_open_center = false
						break
				if not is_open_center:
					break
			
			if is_open_center:
				# Estimate area size (simple check)
				var area_size = 5  # Default to small
				open_areas.append({
					"position": pos,
					"size": area_size
				})
	
	# Place patterns in open areas
	var placed_patterns: Array[Vector2i] = []
	var target_patterns = maxi(1, int(open_areas.size() * density * 2.0))
	target_patterns = mini(target_patterns, open_areas.size())
	
	open_areas.shuffle()
	var patterns_placed = 0
	var attempts = 0
	var max_attempts = target_patterns * 5
	
	while patterns_placed < target_patterns and attempts < max_attempts and open_areas.size() > 0:
		attempts += 1
		var area = open_areas.pop_front()
		
		# Use small patterns for caves (they're usually tighter spaces)
		var pattern_size = CoverPatterns.PatternSize.SMALL
		if area["size"] >= 7:
			pattern_size = CoverPatterns.PatternSize.MEDIUM
		
		var pattern = CoverPatterns.get_random_pattern(pattern_size)
		if pattern.is_empty():
			continue
		
		# Apply random transformation
		var transform = CoverPatterns.get_random_transformation()
		pattern = CoverPatterns.apply_transformation(pattern, transform)
		
		# Try to place near the open area center
		var center = area["position"]
		var search_radius = 2
		var valid_positions = _find_pattern_placement_in_area(
			layout, pattern,
			center.x - search_radius, center.x + search_radius,
			center.y - search_radius, center.y + search_radius
		)
		
		if valid_positions.is_empty():
			continue
		
		valid_positions.shuffle()
		for try_pos in valid_positions:
			if not _check_pattern_spacing(placed_patterns, try_pos, 4):
				continue
			
			if _place_pattern(layout, pattern, try_pos):
				placed_patterns.append(try_pos)
				patterns_placed += 1
				break


func _identify_cave_regions(layout: Dictionary) -> void:
	# Create virtual "rooms" for spawn positioning by finding open areas
	var open_areas: Array[Vector2i] = []
	
	for x in range(3, map_width - 3):
		for y in range(3, map_height - 3):
			var pos = Vector2i(x, y)
			if layout.get(pos, TileType.WALL) == TileType.FLOOR:
				# Check if this is in an open area (3x3 clear)
				var is_open = true
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if layout.get(Vector2i(x + dx, y + dy), TileType.WALL) != TileType.FLOOR:
							is_open = false
							break
					if not is_open:
						break
				
				if is_open:
					open_areas.append(pos)
	
	# Create room rectangles from clusters of open areas
	if open_areas.size() > 0:
		# Sample some positions to create virtual rooms
		for i in range(mini(4, open_areas.size())):
			var idx = randi() % open_areas.size()
			var center = open_areas[idx]
			_rooms.append(Rect2i(center.x - 2, center.y - 2, 5, 5))

#endregion

#region Open Field Generation (Planet Biome)

func _generate_open_layout(config: Dictionary) -> Dictionary:
	var layout: Dictionary = {}
	
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
	
	# Add obstacle clusters (walls/rocks)
	var cluster_count = config["obstacle_clusters"]
	for _i in range(cluster_count):
		var center = Vector2i(
			randi_range(5, map_width - 6),
			randi_range(5, map_height - 6)
		)
		var cluster_size = randi_range(config["cluster_size_min"], config["cluster_size_max"])
		_create_obstacle_cluster(layout, center, cluster_size)
	
	# Add scattered cover using Poisson-like distribution
	_add_scattered_cover(layout, config["cover_density"])
	
	# Create virtual rooms for spawn positioning
	_create_open_spawn_regions()
	
	return layout


func _create_obstacle_cluster(layout: Dictionary, center: Vector2i, size: int) -> void:
	# Create an organic cluster of walls around the center
	var cluster_positions: Array[Vector2i] = [center]
	
	for _i in range(size - 1):
		if cluster_positions.is_empty():
			break
		
		# Pick a random position from existing cluster
		var base = cluster_positions[randi() % cluster_positions.size()]
		
		# Try to add adjacent position
		var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		directions.shuffle()
		
		for dir in directions:
			var new_pos = base + dir
			# Check bounds and not already in cluster
			if new_pos.x > 2 and new_pos.x < map_width - 3 and \
			   new_pos.y > 2 and new_pos.y < map_height - 3 and \
			   new_pos not in cluster_positions:
				cluster_positions.append(new_pos)
				break
	
	# Convert cluster positions to walls
	for pos in cluster_positions:
		layout[pos] = TileType.WALL


func _add_scattered_cover(layout: Dictionary, density: float) -> void:
	# Use pattern-based placement for open fields
	# Open fields can use larger patterns strategically
	var placed_patterns: Array[Vector2i] = []
	
	# Calculate target number of patterns based on density
	var map_area = map_width * map_height
	var target_patterns = maxi(2, int(map_area * density / 8.0))  # Scale down from density
	target_patterns = mini(target_patterns, 8)  # Max 8 patterns for open field
	
	# Mix of pattern sizes for variety
	var pattern_sizes: Array = [
		CoverPatterns.PatternSize.SMALL,
		CoverPatterns.PatternSize.MEDIUM,
		CoverPatterns.PatternSize.LARGE
	]
	
	var patterns_placed = 0
	var attempts = 0
	var max_attempts = target_patterns * 15
	
	while patterns_placed < target_patterns and attempts < max_attempts:
		attempts += 1
		
		# Select pattern size (weighted toward medium/large for open fields)
		var size_roll = randf()
		var pattern_size: CoverPatterns.PatternSize
		if size_roll < 0.3:
			pattern_size = CoverPatterns.PatternSize.SMALL
		elif size_roll < 0.7:
			pattern_size = CoverPatterns.PatternSize.MEDIUM
		else:
			pattern_size = CoverPatterns.PatternSize.LARGE
		
		var pattern = CoverPatterns.get_random_pattern(pattern_size)
		if pattern.is_empty():
			continue
		
		# Apply random transformation
		var transform = CoverPatterns.get_random_transformation()
		pattern = CoverPatterns.apply_transformation(pattern, transform)
		
		# Find valid placement positions (avoid edges and obstacles)
		var margin = 4
		var valid_positions = _find_pattern_placement_in_area(
			layout, pattern,
			margin, map_width - margin,
			margin, map_height - margin
		)
		
		if valid_positions.is_empty():
			continue
		
		# Try to place near obstacles for strategic positioning (optional)
		# Otherwise use random placement
		valid_positions.shuffle()
		for try_pos in valid_positions:
			# Check spacing from other patterns (larger spacing for open fields)
			if not _check_pattern_spacing(placed_patterns, try_pos, 5):
				continue
			
			if _place_pattern(layout, pattern, try_pos):
				placed_patterns.append(try_pos)
				patterns_placed += 1
				break


func _create_open_spawn_regions() -> void:
	# Create four corner regions for spawning
	var margin = 4
	var region_size = 6
	
	# Top-right (player spawn)
	_rooms.append(Rect2i(map_width - margin - region_size, margin, region_size, region_size))
	
	# Bottom-left (near extraction)
	_rooms.append(Rect2i(margin, map_height - margin - region_size, region_size, region_size))
	
	# Top-left (enemy spawn)
	_rooms.append(Rect2i(margin, margin, region_size, region_size))
	
	# Bottom-right
	_rooms.append(Rect2i(map_width - margin - region_size, map_height - margin - region_size, region_size, region_size))

#endregion

#region Perimeter Walls

## Ensures the entire perimeter of the map has wall tiles
## This prevents open spaces at the edges of the map
func _ensure_perimeter_walls(layout: Dictionary) -> void:
	# Top and bottom edges
	for x in range(map_width):
		layout[Vector2i(x, 0)] = TileType.WALL
		layout[Vector2i(x, map_height - 1)] = TileType.WALL
	
	# Left and right edges
	for y in range(map_height):
		layout[Vector2i(0, y)] = TileType.WALL
		layout[Vector2i(map_width - 1, y)] = TileType.WALL

#endregion

#region Extraction Zone

func _add_extraction_zone(layout: Dictionary) -> void:
	# Calculate extraction zone size based on map size
	var zone_size = 3 if map_width <= 25 else 4
	
	# Bottom-left area as extraction zone
	for x in range(1, 1 + zone_size):
		for y in range(map_height - zone_size - 1, map_height - 1):
			var pos = Vector2i(x, y)
			# Clear any walls/cover for extraction
			layout[pos] = TileType.EXTRACTION

#endregion

#region Pattern-Based Cover Placement

## Validate if a pattern can be placed at the given position
## Returns true if pattern fits and doesn't block connectivity
func _can_place_pattern(layout: Dictionary, pattern: Array, base_pos: Vector2i) -> bool:
	# Check each tile in the pattern
	var pattern_tiles: Array[Vector2i] = []
	for rel_pos in pattern:
		var abs_pos = base_pos + rel_pos
		
		# Check bounds
		if abs_pos.x < 1 or abs_pos.x >= map_width - 1 or \
		   abs_pos.y < 1 or abs_pos.y >= map_height - 1:
			return false
		
		# Check tile is floor (not wall, cover, or extraction)
		if layout.get(abs_pos, TileType.WALL) != TileType.FLOOR:
			return false
		
		pattern_tiles.append(abs_pos)
	
	# Temporarily place pattern to test connectivity
	for pos in pattern_tiles:
		layout[pos] = TileType.HALF_COVER
	
	# Check connectivity
	var is_connected = _check_map_connectivity(layout)
	
	# Revert temporary placement
	for pos in pattern_tiles:
		layout[pos] = TileType.FLOOR
	
	return is_connected


## Place a pattern at the given position
## Returns true if placement was successful
func _place_pattern(layout: Dictionary, pattern: Array, base_pos: Vector2i) -> bool:
	if not _can_place_pattern(layout, pattern, base_pos):
		return false
	
	# Place the pattern
	for rel_pos in pattern:
		var abs_pos = base_pos + rel_pos
		layout[abs_pos] = TileType.HALF_COVER
	
	return true


## Find valid placement positions for a pattern within a room
func _find_pattern_placement_in_room(layout: Dictionary, pattern: Array, room: Rect2i) -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	var pattern_bounds = CoverPatterns.get_pattern_bounds(pattern)
	
	# Ensure pattern fits in room
	if pattern_bounds.x > room.size.x or pattern_bounds.y > room.size.y:
		return valid_positions
	
	# Try positions within room (with margin for pattern bounds)
	var margin_x = room.size.x - pattern_bounds.x
	var margin_y = room.size.y - pattern_bounds.y
	
	for x_offset in range(margin_x + 1):
		for y_offset in range(margin_y + 1):
			var try_pos = room.position + Vector2i(x_offset, y_offset)
			if _can_place_pattern(layout, pattern, try_pos):
				valid_positions.append(try_pos)
	
	return valid_positions


## Find valid placement positions for a pattern in open area
func _find_pattern_placement_in_area(layout: Dictionary, pattern: Array, min_x: int, max_x: int, min_y: int, max_y: int) -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	var pattern_bounds = CoverPatterns.get_pattern_bounds(pattern)
	
	# Ensure pattern fits in area
	if pattern_bounds.x > (max_x - min_x) or pattern_bounds.y > (max_y - min_y):
		return valid_positions
	
	# Try positions within area
	for x in range(min_x, max_x - pattern_bounds.x + 1):
		for y in range(min_y, max_y - pattern_bounds.y + 1):
			var try_pos = Vector2i(x, y)
			if _can_place_pattern(layout, pattern, try_pos):
				valid_positions.append(try_pos)
	
	return valid_positions


## Check minimum spacing between placed patterns
func _check_pattern_spacing(placed_patterns: Array, new_pos: Vector2i, min_spacing: int = 2) -> bool:
	for existing_pos in placed_patterns:
		var distance = abs(new_pos.x - existing_pos.x) + abs(new_pos.y - existing_pos.y)
		if distance < min_spacing:
			return false
	return true

#endregion

#region Connectivity Check

## Check if the map remains connected after placing a cover
## Returns true if all floor tiles are reachable from each other
func _check_map_connectivity(layout: Dictionary) -> bool:
	# Find all walkable tiles (FLOOR and EXTRACTION)
	var walkable_tiles: Array[Vector2i] = []
	for x in range(1, map_width - 1):
		for y in range(1, map_height - 1):
			var pos = Vector2i(x, y)
			var tile_type = layout.get(pos, TileType.WALL)
			if tile_type == TileType.FLOOR or tile_type == TileType.EXTRACTION:
				walkable_tiles.append(pos)
	
	# If no walkable tiles, consider it connected (edge case)
	if walkable_tiles.is_empty():
		return true
	
	# Use flood-fill from the first walkable tile to see how many we can reach
	var start_pos = walkable_tiles[0]
	var visited: Dictionary = {}
	var reachable_count = _flood_fill_walkable(layout, start_pos, visited)
	
	# Map is connected if we can reach all walkable tiles
	return reachable_count == walkable_tiles.size()


## Flood-fill to count reachable walkable tiles (FLOOR and EXTRACTION)
func _flood_fill_walkable(layout: Dictionary, start: Vector2i, visited: Dictionary) -> int:
	var count = 0
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		count += 1
		
		# Check all 4 cardinal directions
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor = pos + dir
			
			# Skip if out of bounds or already visited
			if neighbor.x < 1 or neighbor.x >= map_width - 1 or \
			   neighbor.y < 1 or neighbor.y >= map_height - 1 or \
			   visited.has(neighbor):
				continue
			
			# Check if neighbor is walkable (FLOOR or EXTRACTION, not WALL or HALF_COVER)
			var tile_type = layout.get(neighbor, TileType.WALL)
			if tile_type == TileType.FLOOR or tile_type == TileType.EXTRACTION:
				visited[neighbor] = true
				queue.append(neighbor)
	
	return count

#endregion

#region Spawn Position Functions

func get_spawn_positions() -> Array[Vector2i]:
	# Top-right spawn points - scale with map size
	var positions: Array[Vector2i] = []
	var spawn_offset = 3 if map_width <= 25 else 4
	
	# Find valid floor positions in top-right area
	var base_positions: Array[Vector2i] = [
		Vector2i(map_width - spawn_offset, spawn_offset - 1),
		Vector2i(map_width - spawn_offset - 1, spawn_offset - 1),
		Vector2i(map_width - spawn_offset, spawn_offset),
	]
	
	for base_pos in base_positions:
		var valid_pos = _find_valid_spawn_position(
			base_pos.x - 2, base_pos.x + 2,
			base_pos.y - 2, base_pos.y + 2,
			20
		)
		if valid_pos != Vector2i(-1, -1):
			positions.append(valid_pos)
	
	# Ensure at least 3 spawn positions
	while positions.size() < 3:
		var fallback = _find_valid_spawn_position(
			map_width - 8, map_width - 2,
			2, 8,
			50
		)
		if fallback != Vector2i(-1, -1) and fallback not in positions:
			positions.append(fallback)
		else:
			break
	
	return positions


## Check if a position is valid for spawning (floor tile, not occupied)
func _is_valid_spawn_position(pos: Vector2i) -> bool:
	# Must be within bounds
	if pos.x < 1 or pos.x >= map_width - 1 or pos.y < 1 or pos.y >= map_height - 1:
		return false
	
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
	for _attempt in range(max_attempts):
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
	var loot_config = BiomeConfig.get_loot_config(_biome_type)
	
	# Biome-specific spawn rate multipliers
	var fuel_multiplier: float = 0.5  # Default: 50% reduction
	var scrap_multiplier: float = 0.5  # Default: 50% reduction
	
	match _biome_type:
		BiomeConfig.BiomeType.STATION:
			# Space Station: More fuel crates vs scrap piles
			fuel_multiplier = 0.75  # Reduce fuel by 25% (keep 75%)
			scrap_multiplier = 0.25  # Reduce scrap by 75% (keep 25%)
		BiomeConfig.BiomeType.ASTEROID:
			# Asteroid: More scrap piles vs fuel crates
			fuel_multiplier = 0.25  # Reduce fuel by 75% (keep 25%)
			scrap_multiplier = 0.75  # Reduce scrap by 25% (keep 75%)
		BiomeConfig.BiomeType.PLANET:
			# Planetary Surface: No change (50% reduction for both)
			fuel_multiplier = 0.5
			scrap_multiplier = 0.5
	
	# Fuel crates
	var num_fuel = randi_range(loot_config["min_fuel"], loot_config["max_fuel"])
	num_fuel = (num_fuel * fuel_multiplier) as int  # Apply biome-specific reduction
	for _i in range(num_fuel):
		var pos = _find_valid_spawn_position(3, map_width - 4, 3, map_height - 4)
		if pos != Vector2i(-1, -1):
			positions.append({
				"type": "fuel",
				"position": pos
			})
	
	# Scrap piles
	var num_scrap = randi_range(loot_config["min_scrap"], loot_config["max_scrap"])
	num_scrap = (num_scrap * scrap_multiplier) as int  # Apply biome-specific reduction
	for _i in range(num_scrap):
		var pos = _find_valid_spawn_position(3, map_width - 4, 3, map_height - 4)
		if pos != Vector2i(-1, -1):
			positions.append({
				"type": "scrap",
				"position": pos
			})
	
	# Health packs (1-2 per mission, spawn in all biomes)
	var num_health_packs = randi_range(1, 2)
	for _i in range(num_health_packs):
		var pos = _find_valid_spawn_position(3, map_width - 4, 3, map_height - 4)
		if pos != Vector2i(-1, -1):
			positions.append({
				"type": "health_pack",
				"position": pos
			})
	
	return positions


func get_extraction_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var zone_size = 3 if map_width <= 25 else 4
	
	for x in range(1, 1 + zone_size):
		for y in range(map_height - zone_size - 1, map_height - 1):
			positions.append(Vector2i(x, y))
	
	return positions


func get_enemy_spawn_positions(difficulty_multiplier: float = 1.0, min_enemies: int = 0) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var enemy_config = BiomeConfig.get_enemy_config(_biome_type, difficulty_multiplier)
	var num_enemies = randi_range(enemy_config["min_enemies"], enemy_config["max_enemies"])
	
	# Ensure we spawn at least the minimum required enemies for objectives
	if min_enemies > 0:
		num_enemies = maxi(num_enemies, min_enemies)
	
	# Calculate extraction zone area to avoid (bottom-left)
	var zone_size = 3 if map_width <= 25 else 4
	var extraction_x_max = 1 + zone_size
	var extraction_y_min = map_height - zone_size - 1
	
	# Define multiple spawn zones across the map to spread enemies out
	# Avoid extraction zone (bottom-left) and player spawn area (top-right)
	var spawn_zones: Array[Dictionary] = []
	var margin = 3
	
	# Zone 1: Top-left area
	spawn_zones.append({
		"x_min": margin,
		"x_max": map_width / 2 - 2,
		"y_min": margin,
		"y_max": map_height / 3
	})
	
	# Zone 2: Left-middle area (avoiding extraction zone)
	spawn_zones.append({
		"x_min": margin,
		"x_max": map_width / 2 - 2,
		"y_min": map_height / 3,
		"y_max": extraction_y_min - 2  # Stop before extraction zone
	})
	
	# Zone 3: Middle-left to center area
	spawn_zones.append({
		"x_min": map_width / 4,
		"x_max": map_width * 2 / 3,
		"y_min": map_height / 4,
		"y_max": map_height * 2 / 3
	})
	
	# Zone 4: Bottom-center area (avoiding extraction zone)
	spawn_zones.append({
		"x_min": extraction_x_max + 2,  # Start after extraction zone
		"x_max": map_width * 2 / 3,
		"y_min": map_height * 2 / 3,
		"y_max": map_height - margin - 1
	})
	
	# Zone 5: Right side (avoiding player spawn top-right)
	spawn_zones.append({
		"x_min": map_width / 2 + 2,
		"x_max": map_width - margin - 1,
		"y_min": margin + 5,  # Avoid top-right player spawn
		"y_max": map_height - margin - 1
	})
	
	# Distribute enemies across zones for better spread
	var enemies_per_zone = num_enemies / spawn_zones.size()
	var remaining_enemies = num_enemies % spawn_zones.size()
	
	for zone_idx in range(spawn_zones.size()):
		var zone = spawn_zones[zone_idx]
		var enemies_in_zone = enemies_per_zone
		if zone_idx < remaining_enemies:
			enemies_in_zone += 1
		
		for _i in range(enemies_in_zone):
			var pos = _find_valid_spawn_position(
				zone["x_min"], zone["x_max"],
				zone["y_min"], zone["y_max"]
			)
			if pos != Vector2i(-1, -1):
				positions.append(pos)
	
	# If we didn't get enough positions, try filling from any zone
	while positions.size() < num_enemies:
		var random_zone = spawn_zones[randi() % spawn_zones.size()]
		var pos = _find_valid_spawn_position(
			random_zone["x_min"], random_zone["x_max"],
			random_zone["y_min"], random_zone["y_max"]
		)
		if pos != Vector2i(-1, -1) and pos not in positions:
			positions.append(pos)
		else:
			# Last resort: try anywhere except extraction and player spawn
			pos = _find_valid_spawn_position(
				margin, map_width - margin - 1,
				margin + 5, map_height - margin - 1
			)
			if pos != Vector2i(-1, -1) and pos not in positions:
				positions.append(pos)
			else:
				break  # Can't find more valid positions
	
	return positions


func get_cover_crate_positions() -> Array[Vector2i]:
	# Return positions where destructible cover crates are (already in layout as HALF_COVER)
	var positions: Array[Vector2i] = []
	
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			if _layout.get(pos, TileType.WALL) == TileType.HALF_COVER:
				positions.append(pos)
	
	return positions


func get_biome_type() -> BiomeConfig.BiomeType:
	return _biome_type


func get_map_dimensions() -> Vector2i:
	return Vector2i(map_width, map_height)


func get_layout() -> Dictionary:
	return _layout

#endregion
