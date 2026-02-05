extends Node
## Enemy AI - Controls enemy behavior in tactical combat
## Simple AI: Shoot if in range, move toward player if detected, idle otherwise

class_name EnemyAI


## Decide action for an enemy unit
static func decide_action(enemy: Node2D, officers: Array[Node2D], tactical_map: Node2D) -> Dictionary:
	var enemy_pos = enemy.get_grid_position()
	var result = {"action": "idle", "target": null, "path": null}
	
	# Find nearest visible officer
	var nearest_officer: Node2D = null
	var nearest_distance = 999
	
	print("  Enemy at %s checking for targets (sight: %d, shoot: %d, AP: %d)" % [enemy_pos, enemy.sight_range, enemy.shoot_range, enemy.current_ap])
	
	for officer in officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
		
		print("    Officer at %s, distance: %d" % [officer_pos, distance])
		
		# Check if officer is visible (in sight range)
		if distance <= enemy.sight_range:
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_officer = officer
				print("    -> Target acquired!")
	
	# No officer detected - idle
	if not nearest_officer:
		print("  -> No targets in sight range")
		result["action"] = "idle"
		return result
	
	var target_pos = nearest_officer.get_grid_position()
	
	# Check if can shoot (in range and has LOS)
	if nearest_distance <= enemy.shoot_range and enemy.has_ap(1):
		print("  -> Target in shoot range (%d <= %d)" % [nearest_distance, enemy.shoot_range])
		# Check line of sight
		if _has_line_of_sight(enemy_pos, target_pos, tactical_map):
			print("  -> Has LOS, shooting!")
			result["action"] = "shoot"
			result["target"] = nearest_officer
			result["target_pos"] = target_pos
			return result
		else:
			print("  -> No LOS to target")
	else:
		if nearest_distance > enemy.shoot_range:
			print("  -> Target too far for shooting (%d > %d)" % [nearest_distance, enemy.shoot_range])
		elif not enemy.has_ap(1):
			print("  -> Not enough AP to shoot")
	
	# Can't shoot - try to move
	if enemy.has_ap(1):
		print("  -> Attempting to find tactical position (move_range: %d)" % enemy.move_range)
		
		# Decide movement strategy based on situation
		var move_destination = _find_tactical_position(enemy_pos, target_pos, enemy.move_range, nearest_distance, tactical_map)
		
		if move_destination != enemy_pos:
			var path = tactical_map.find_path(enemy_pos, move_destination)
			
			if path and path.size() > 1:
				print("  -> Path found! Moving to grid %s (path length: %d)" % [move_destination, path.size()])
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = move_destination
				return result
			else:
				print("  -> No valid path found to tactical position")
		else:
			print("  -> No better position found, staying put")
	
	# Can't do anything useful
	print("  -> Idle (no AP or no actions available)")
	result["action"] = "idle"
	return result


## Check if there's line of sight between two positions
static func _has_line_of_sight(from: Vector2i, to: Vector2i, tactical_map: Node2D) -> bool:
	var tiles = _get_line_tiles(from, to)
	
	for tile_pos in tiles:
		if tile_pos == from or tile_pos == to:
			continue
		
		if not tactical_map.is_tile_walkable(tile_pos):
			return false
	
	return true


## Get tiles along a line using Bresenham's algorithm
static func _get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
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


## Find a tactical position to move to (considers cover, range, and threat)
static func _find_tactical_position(from: Vector2i, target_pos: Vector2i, max_range: int, current_distance: int, tactical_map: Node2D) -> Vector2i:
	var best_position = from
	var best_score = -999.0
	
	# Ideal engagement range (stay at medium range if possible)
	const IDEAL_MIN_RANGE = 4
	const IDEAL_MAX_RANGE = 7
	
	# Check all tiles within movement range using BFS
	var checked_positions = _get_reachable_positions(from, max_range, tactical_map)
	
	print("    Evaluating %d reachable positions" % checked_positions.size())
	
	for pos in checked_positions:
		if pos == from:
			continue  # Skip current position initially
		
		var distance_to_target = abs(pos.x - target_pos.x) + abs(pos.y - target_pos.y)
		var score = 0.0
		
		# Score based on range to target
		if distance_to_target >= IDEAL_MIN_RANGE and distance_to_target <= IDEAL_MAX_RANGE:
			# Ideal range - high score
			score += 50.0
		elif distance_to_target < IDEAL_MIN_RANGE:
			# Too close - penalize
			score += 20.0 - (IDEAL_MIN_RANGE - distance_to_target) * 10.0
		else:
			# Too far - moderate penalty
			score += 30.0 - (distance_to_target - IDEAL_MAX_RANGE) * 5.0
		
		# Bonus for cover
		var cover_value = tactical_map.get_cover_value(pos)
		score += cover_value  # +25 for half cover, +50 for full cover
		
		# Bonus for line of sight to target
		if _has_line_of_sight(pos, target_pos, tactical_map):
			score += 20.0
		else:
			score -= 30.0  # Penalty for no LOS
		
		# Slight bonus for moving closer if far away
		if current_distance > IDEAL_MAX_RANGE and distance_to_target < current_distance:
			score += 10.0
		
		# Slight bonus for moving to cover if exposed
		if tactical_map.get_cover_value(from) == 0.0 and cover_value > 0.0:
			score += 15.0
		
		if score > best_score:
			best_score = score
			best_position = pos
	
	# If no good position found, at least try to move closer or to cover
	if best_position == from and checked_positions.size() > 1:
		# Try to find any position with cover
		for pos in checked_positions:
			if tactical_map.get_cover_value(pos) > 0.0:
				best_position = pos
				print("    Fallback: Moving to cover at %s" % pos)
				break
		
		# If still no cover, just move closer
		if best_position == from:
			best_position = _get_closest_position_to_target(from, target_pos, checked_positions)
			print("    Fallback: Moving closer to target at %s" % best_position)
	
	print("    Best tactical position: %s (score: %.1f)" % [best_position, best_score])
	return best_position


## Get all reachable positions within movement range using BFS
static func _get_reachable_positions(from: Vector2i, max_range: int, tactical_map: Node2D) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var queue: Array[Vector2i] = [from]
	var visited: Dictionary = {from: true}
	var distances: Dictionary = {from: 0}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var dist = distances[current]
		
		reachable.append(current)
		
		if dist < max_range:
			var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for dir in directions:
				var next_pos = current + dir
				
				if not visited.has(next_pos) and tactical_map.is_tile_walkable(next_pos):
					visited[next_pos] = true
					distances[next_pos] = dist + 1
					queue.append(next_pos)
	
	return reachable


## Get position from list that's closest to target
static func _get_closest_position_to_target(from: Vector2i, target: Vector2i, positions: Array[Vector2i]) -> Vector2i:
	var best_pos = from
	var best_distance = abs(from.x - target.x) + abs(from.y - target.y)
	
	for pos in positions:
		if pos == from:
			continue
		var distance = abs(pos.x - target.x) + abs(pos.y - target.y)
		if distance < best_distance:
			best_distance = distance
			best_pos = pos
	
	return best_pos
