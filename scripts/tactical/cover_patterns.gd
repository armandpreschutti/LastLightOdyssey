extends RefCounted
## Cover Pattern System - Reusable tactical cover layouts
## Provides structured patterns for half cover placement instead of random scattering

class_name CoverPatterns

enum PatternSize { SMALL, MEDIUM, LARGE }

#region Pattern Definitions

# Small patterns (3-5 tiles) - Simple formations
const SMALL_PATTERNS := [
	# L-shapes
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],  # Small L
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)],  # Tall L
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],  # Wide L
	
	# Corners
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],  # Corner (same as small L)
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],  # Inverted corner
	
	# Small clusters
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],  # 2x2 cluster
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],  # Horizontal line (3 tiles)
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],  # Vertical line (3 tiles)
	
	# Single tile with neighbor
	[Vector2i(0, 0), Vector2i(1, 0)],  # Pair horizontal
	[Vector2i(0, 0), Vector2i(0, 1)],  # Pair vertical
]

# Medium patterns (6-9 tiles) - Tactical formations
const MEDIUM_PATTERNS := [
	# T-shapes
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],  # T-shape
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],  # Inverted T
	
	# Defensive lines
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],  # Horizontal line (4 tiles)
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],  # Vertical line (4 tiles)
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],  # L with extension
	
	# Double clusters
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), 
	 Vector2i(3, 0), Vector2i(4, 0)],  # 2x2 cluster + pair
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), 
	 Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],  # Two horizontal lines
	
	# Complex L-shapes
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],  # Big L
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],  # Tall L with base
]

# Large patterns (10+ tiles) - Complex strategic layouts
const LARGE_PATTERNS := [
	# Multiple clusters
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),  # 2x2 cluster
	 Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1),  # Second 2x2
	 Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)],  # Bottom line
	
	# Defensive formation
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),  # Top line
	 Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),  # Bottom line
	 Vector2i(1, 1)],  # Center piece
	
	# Strategic L-formation
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),  # Horizontal
	 Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),  # Vertical
	 Vector2i(2, 2), Vector2i(3, 2)],  # Extension
	
	# Scattered tactical
	[Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0),  # Spaced horizontal
	 Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2),  # Second row
	 Vector2i(1, 1), Vector2i(3, 1)],  # Center pieces
	
	# Corner defense
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),  # Corner cluster
	 Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1),  # Opposite corner
	 Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),  # Bottom corner
	 Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],  # Last corner
]

#endregion

#region Pattern Access

## Get all patterns of a specific size category
static func get_patterns(size: PatternSize) -> Array:
	match size:
		PatternSize.SMALL:
			return SMALL_PATTERNS
		PatternSize.MEDIUM:
			return MEDIUM_PATTERNS
		PatternSize.LARGE:
			return LARGE_PATTERNS
		_:
			return []


## Get a random pattern from the specified size category
static func get_random_pattern(size: PatternSize) -> Array:
	var patterns = get_patterns(size)
	if patterns.is_empty():
		return []
	return patterns[randi() % patterns.size()].duplicate()


## Determine pattern size category based on room dimensions
static func get_pattern_size_for_room(room_width: int, room_height: int) -> PatternSize:
	var area = room_width * room_height
	var min_dim = mini(room_width, room_height)
	
	# Small rooms: 5x5 or smaller, or area <= 25
	if min_dim <= 5 or area <= 25:
		return PatternSize.SMALL
	
	# Medium rooms: 6x6 to 8x8, or area 36-64
	if min_dim <= 8 and area <= 64:
		return PatternSize.MEDIUM
	
	# Large rooms: 9x9 or larger, or area > 64
	return PatternSize.LARGE


## Get pattern size for open area (cave/open field)
static func get_pattern_size_for_area(area_size: int) -> PatternSize:
	if area_size <= 5:
		return PatternSize.SMALL
	elif area_size <= 9:
		return PatternSize.MEDIUM
	else:
		return PatternSize.LARGE

#endregion

#region Pattern Transformations

## Rotate pattern 90 degrees clockwise
static func rotate_pattern(pattern: Array, times: int = 1) -> Array:
	if pattern.is_empty():
		return []
	
	var rotated = pattern.duplicate()
	for _i in range(times % 4):
		var new_pattern: Array = []
		for pos in rotated:
			# 90° clockwise: (x, y) -> (y, -x)
			new_pattern.append(Vector2i(pos.y, -pos.x))
		rotated = new_pattern
	
	return rotated


## Mirror pattern horizontally
static func mirror_pattern_horizontal(pattern: Array) -> Array:
	if pattern.is_empty():
		return []
	
	var mirrored: Array = []
	var max_x = 0
	for pos in pattern:
		max_x = maxi(max_x, pos.x)
	
	for pos in pattern:
		# Mirror: (x, y) -> (max_x - x, y)
		mirrored.append(Vector2i(max_x - pos.x, pos.y))
	
	return mirrored


## Mirror pattern vertically
static func mirror_pattern_vertical(pattern: Array) -> Array:
	if pattern.is_empty():
		return []
	
	var mirrored: Array = []
	var max_y = 0
	for pos in pattern:
		max_y = maxi(max_y, pos.y)
	
	for pos in pattern:
		# Mirror: (x, y) -> (x, max_y - y)
		mirrored.append(Vector2i(pos.x, max_y - pos.y))
	
	return mirrored


## Get pattern bounds (width and height)
static func get_pattern_bounds(pattern: Array) -> Vector2i:
	if pattern.is_empty():
		return Vector2i(0, 0)
	
	var min_x = pattern[0].x
	var max_x = pattern[0].x
	var min_y = pattern[0].y
	var max_y = pattern[0].y
	
	for pos in pattern:
		min_x = mini(min_x, pos.x)
		max_x = maxi(max_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_y = maxi(max_y, pos.y)
	
	return Vector2i(max_x - min_x + 1, max_y - min_y + 1)


## Normalize pattern to start at (0, 0)
static func normalize_pattern(pattern: Array) -> Array:
	if pattern.is_empty():
		return []
	
	var min_x = pattern[0].x
	var min_y = pattern[0].y
	
	for pos in pattern:
		min_x = mini(min_x, pos.x)
		min_y = mini(min_y, pos.y)
	
	var normalized: Array = []
	for pos in pattern:
		normalized.append(pos - Vector2i(min_x, min_y))
	
	return normalized

#endregion

#region Pattern Placement Helpers

## Get a random transformation (rotation and/or mirror) for variety
static func get_random_transformation() -> Dictionary:
	var rotation = randi() % 4  # 0, 90, 180, 270 degrees
	var mirror_h = randf() > 0.5
	var mirror_v = randf() > 0.5
	
	return {
		"rotation": rotation,
		"mirror_h": mirror_h,
		"mirror_v": mirror_v
	}


## Apply transformation to a pattern
static func apply_transformation(pattern: Array, transform: Dictionary) -> Array:
	var result = pattern.duplicate()
	
	# Apply rotation
	if transform.has("rotation") and transform["rotation"] > 0:
		result = rotate_pattern(result, transform["rotation"])
	
	# Apply mirroring
	if transform.get("mirror_h", false):
		result = mirror_pattern_horizontal(result)
	if transform.get("mirror_v", false):
		result = mirror_pattern_vertical(result)
	
	# Normalize to start at (0, 0)
	return normalize_pattern(result)

#endregion
