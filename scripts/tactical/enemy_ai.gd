extends Node
## Enemy AI - Controls enemy behavior in tactical combat
## Smart AI: Considers flanking, repositions when cover is ineffective

class_name EnemyAI


## Decide action for an enemy unit
static func decide_action(enemy: Node2D, officers: Array[Node2D], tactical_map: Node2D, tactical_controller: Node2D = null) -> Dictionary:
	# Check if this is a boss enemy - route to boss AI
	if enemy.get("enemy_type") != null and enemy.enemy_type == "boss":
		return decide_boss_action(enemy, officers, tactical_map)
	
	var enemy_pos = enemy.get_grid_position()
	var result = {"action": "idle", "target": null, "path": null}
	
	# Check for taunting Heavy - must prioritize them if visible
	var taunted_heavy: Node2D = null
	var taunted_heavy_distance = 999
	const TAUNT_RANGE = 5  # Taunt affects enemies within 5 tiles
	
	# Also track all visible officers for flanking calculations
	var visible_officers: Array[Node2D] = []
	
	# Find best target using scoring system (hit chance + health)
	var best_target: Node2D = null
	var best_score = -1.0
	var best_distance = 999
	var best_target_hit_chance = 0.0  # Store hit chance for best target
	
	# Fallback: nearest officer for movement purposes
	var nearest_officer: Node2D = null
	var nearest_distance = 999
	
	for officer in officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
		
		# Check if officer is visible (in sight range)
		if distance <= enemy.sight_range:
			visible_officers.append(officer)
			
			# Check if this officer is a Heavy with taunt active and within taunt range
			if officer.has_method("has_taunt_active") and officer.has_taunt_active() and distance <= TAUNT_RANGE:
				taunted_heavy = officer
				taunted_heavy_distance = distance
			
			# Track nearest for fallback movement
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_officer = officer
			
			# Only evaluate targets within attack range and with line of sight
			if distance <= enemy.shoot_range and _has_line_of_sight(enemy_pos, officer_pos, tactical_map):
				# Calculate hit chance if tactical_controller is available
				var hit_chance = 50.0  # Default fallback if no controller
				if tactical_controller and tactical_controller.has_method("calculate_hit_chance"):
					hit_chance = tactical_controller.calculate_hit_chance(enemy_pos, officer_pos, enemy)
				
				# Calculate health score (lower HP = higher priority)
				var health_percent = float(officer.current_hp) / float(officer.max_hp) if officer.max_hp > 0 else 1.0
				var health_score = 1.0 - health_percent  # Lower HP = higher score
				
				# Normalize hit chance to 0-1 range
				var hit_chance_score = hit_chance / 100.0
				
				# Combined score: 50% hit chance, 50% health (balanced)
				var combined_score = (hit_chance_score * 0.5) + (health_score * 0.5)
				
				# Select target with highest score
				if combined_score > best_score:
					best_score = combined_score
					best_target = officer
					best_distance = distance
					best_target_hit_chance = hit_chance  # Store hit chance for attack priority check
	
	# If a taunted Heavy is within range, prioritize them absolutely
	if taunted_heavy:
		best_target = taunted_heavy
		best_distance = taunted_heavy_distance
		# Recalculate hit chance for taunted heavy if tactical_controller is available
		if tactical_controller and tactical_controller.has_method("calculate_hit_chance"):
			best_target_hit_chance = tactical_controller.calculate_hit_chance(enemy_pos, taunted_heavy.get_grid_position(), enemy)
		else:
			best_target_hit_chance = 50.0  # Default fallback
	
	# Use best target if found, otherwise fall back to nearest for movement
	var selected_target = best_target if best_target else nearest_officer
	var selected_distance = best_distance if best_target else nearest_distance
	
	# No officer detected - idle
	if not selected_target:
		result["action"] = "idle"
		return result
	
	var target_pos = selected_target.get_grid_position()
	
	# Check if currently in cover AND if that cover is effective against threats
	var has_adjacent_cover = tactical_map.has_adjacent_cover(enemy_pos)
	var is_effectively_covered = _is_cover_effective_against_threats(enemy_pos, visible_officers, tactical_map)
	var is_being_flanked = has_adjacent_cover and not is_effectively_covered
	var can_shoot = selected_distance <= enemy.shoot_range and enemy.has_ap(1) and _has_line_of_sight(enemy_pos, target_pos, tactical_map)

	# Pre-compute reachable positions once (BFS is expensive) for all movement queries
	var reachable: Array[Vector2i] = []
	if enemy.has_ap(1):
		reachable = _get_reachable_positions(enemy_pos, enemy.move_range, tactical_map)

	# PRIORITY 0: If attack success chance >90% against best target, prioritize shooting over ALL cover-seeking
	if best_target and best_target_hit_chance > 90.0:
		var best_target_pos = best_target.get_grid_position()
		var can_shoot_best = best_distance <= enemy.shoot_range and enemy.has_ap(1) and _has_line_of_sight(enemy_pos, best_target_pos, tactical_map)
		if can_shoot_best:
			result["action"] = "shoot"
			result["target"] = best_target
			result["target_pos"] = best_target_pos
			return result

	# PRIORITY 1: If flanked (in useless cover) and can reach better cover, reposition!
	if is_being_flanked and enemy.has_ap(1):
		var better_cover_pos = _find_cover_against_threats(enemy_pos, visible_officers, enemy.move_range, tactical_map, reachable)
		if better_cover_pos != enemy_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(enemy_pos, better_cover_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = better_cover_pos
				return result
	
	# PRIORITY 2: If exposed (no cover at all) and can reach cover, move to cover first
	if not has_adjacent_cover and enemy.has_ap(1):
		var cover_pos = _find_cover_against_threats(enemy_pos, visible_officers, enemy.move_range, tactical_map, reachable)
		if cover_pos != enemy_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(enemy_pos, cover_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = cover_pos
				return result
	
	# PRIORITY 3: If can shoot (either in effective cover or no better option), shoot
	if can_shoot:
		result["action"] = "shoot"
		result["target"] = selected_target
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 4: Can't shoot - try to move to a better tactical position
	if enemy.has_ap(1):
		
		var move_destination = _find_tactical_position(enemy_pos, target_pos, visible_officers, enemy.move_range, selected_distance, tactical_map, reachable)
		
		if move_destination != enemy_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(enemy_pos, move_destination), tactical_map)
			
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = move_destination
				return result
	
	# PRIORITY 5: Visible enemy with AP remaining - ALWAYS move towards closest officer
	if enemy.has_ap(1) and enemy.visible:
		# Find the closest officer (regardless of sight range) to move towards
		var closest_officer: Node2D = null
		var closest_dist = 999
		for officer in officers:
			if officer.current_hp <= 0:
				continue
			var officer_pos = officer.get_grid_position()
			var dist = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
			if dist < closest_dist:
				closest_dist = dist
				closest_officer = officer
		
		if closest_officer and reachable.size() > 0:
			var closest_officer_pos = closest_officer.get_grid_position()
			var move_target_pos = _get_closest_position_to_target(enemy_pos, closest_officer_pos, reachable)
			
			if move_target_pos != enemy_pos:
				var path = _filter_extraction_tiles_from_path(tactical_map.find_path(enemy_pos, move_target_pos), tactical_map)
				if path and path.size() > 1:
					result["action"] = "move"
					result["path"] = path
					result["target_pos"] = move_target_pos
					return result
	
	# Can't do anything useful
	result["action"] = "idle"
	return result


## Check if any adjacent cover provides protection against at least one visible threat
static func _is_cover_effective_against_threats(defender_pos: Vector2i, threats: Array[Node2D], tactical_map: Node2D) -> bool:
	if threats.is_empty():
		return true  # No threats means cover doesn't matter
	
	var adjacent_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	# For each threat, check if there's cover protecting from that direction
	for threat in threats:
		var threat_pos = threat.get_grid_position()
		var dir_to_threat = Vector2(threat_pos - defender_pos).normalized()
		
		# Check each adjacent tile for cover that protects against this threat
		var protected_from_this_threat = false
		
		for adj_dir in adjacent_dirs:
			var adj_pos = defender_pos + adj_dir
			var cover_value = tactical_map.get_cover_value(adj_pos)
			
			if cover_value <= 0:
				continue
			
			# Cover direction points FROM defender TO cover
			var cover_dir = Vector2(adj_dir).normalized()
			var dot = cover_dir.dot(dir_to_threat)
			
			# Cover protects if it's between defender and threat (dot > 0.5)
			if dot > 0.5:
				protected_from_this_threat = true
				break
		
		# If protected from at least one threat, consider cover effective
		if protected_from_this_threat:
			return true
	
	# No cover protects from any threat - we're being flanked
	return false


## Find a position with cover that protects against the given threats
static func _find_cover_against_threats(from: Vector2i, threats: Array[Node2D], max_range: int, tactical_map: Node2D, precomputed_reachable: Array[Vector2i] = []) -> Vector2i:
	var reachable = precomputed_reachable if precomputed_reachable.size() > 0 else _get_reachable_positions(from, max_range, tactical_map)
	var best_pos = from
	var best_score = -999.0
	
	# Get average threat direction for scoring
	var avg_threat_dir = Vector2.ZERO
	for threat in threats:
		var threat_pos = threat.get_grid_position()
		avg_threat_dir += Vector2(threat_pos - from).normalized()
	if threats.size() > 0:
		avg_threat_dir = avg_threat_dir.normalized()
	
	for pos in reachable:
		if pos == from:
			continue
		
		var score = 0.0
		var threats_covered = 0
		
		# Check how many threats this position has cover against
		var adjacent_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		
		for threat in threats:
			var threat_pos = threat.get_grid_position()
			var dir_to_threat = Vector2(threat_pos - pos).normalized()
			
			for adj_dir in adjacent_dirs:
				var adj_pos = pos + adj_dir
				var cover_value = tactical_map.get_cover_value(adj_pos)
				
				if cover_value <= 0:
					continue
				
				var cover_dir = Vector2(adj_dir).normalized()
				var dot = cover_dir.dot(dir_to_threat)
				
				# This cover protects against this threat
				if dot > 0.5:
					threats_covered += 1
					score += cover_value  # Higher cover = better
					break
		
		# Strong bonus for covering multiple threats
		score += threats_covered * 50.0
		
		# Must cover at least one threat to be considered
		if threats_covered == 0:
			continue
		
		# Prefer positions with LOS to primary threat (can shoot back)
		if threats.size() > 0:
			var primary_threat_pos = threats[0].get_grid_position()
			if _has_line_of_sight(pos, primary_threat_pos, tactical_map):
				score += 30.0
		
		# Slight penalty for distance (don't move too far)
		var dist_from_start = abs(pos.x - from.x) + abs(pos.y - from.y)
		score -= dist_from_start * 3.0
		
		# Prefer medium range to threats
		if threats.size() > 0:
			var primary_threat_pos = threats[0].get_grid_position()
			var dist_to_threat = abs(pos.x - primary_threat_pos.x) + abs(pos.y - primary_threat_pos.y)
			if dist_to_threat >= 3 and dist_to_threat <= 6:
				score += 15.0
		
		if score > best_score:
			best_score = score
			best_pos = pos
	
	return best_pos


## Check if there's line of sight between two positions
static func _has_line_of_sight(from: Vector2i, to: Vector2i, tactical_map: Node2D) -> bool:
	var tiles = _get_line_tiles(from, to)
	var blocking_wall: Vector2i = Vector2i(-1, -1)
	
	for tile_pos in tiles:
		if tile_pos == from or tile_pos == to:
			continue
		
		# Only walls block LOS, cover does not
		if tactical_map.blocks_line_of_sight(tile_pos):
			blocking_wall = tile_pos
			break
	
	# If no blocking wall, LOS is clear
	if blocking_wall == Vector2i(-1, -1):
		return true
	
	# Check if we can peek around the corner
	return _can_peek_around_corner(from, to, blocking_wall, tactical_map)


## Check if shooter can peek around an adjacent wall corner
static func _can_peek_around_corner(shooter_pos: Vector2i, target_pos: Vector2i, blocking_wall: Vector2i, tactical_map: Node2D) -> bool:
	# Check if blocking wall is adjacent to shooter
	var adjacent_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var is_adjacent = false
	for dir in adjacent_dirs:
		if shooter_pos + dir == blocking_wall:
			is_adjacent = true
			break
	
	if not is_adjacent:
		return false  # Wall is not adjacent, can't peek
	
	# Check LOS from adjacent positions (excluding the wall)
	for dir in adjacent_dirs:
		var peek_pos = shooter_pos + dir
		if peek_pos == blocking_wall:
			continue  # Skip the wall tile itself
		
		# Check if this peek position is valid and has LOS
		if tactical_map.is_tile_walkable(peek_pos) and not tactical_map.blocks_line_of_sight(peek_pos):
			# Check LOS from this peek position
			var peek_tiles = _get_line_tiles(peek_pos, target_pos)
			var has_clear_los = true
			for tile_pos in peek_tiles:
				if tile_pos == peek_pos or tile_pos == target_pos:
					continue
				if tactical_map.blocks_line_of_sight(tile_pos):
					has_clear_los = false
					break
			if has_clear_los:
				return true  # Can peek from this position
	
	return false  # Cannot peek around corner


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


## Find a tactical position to move to (considers cover effectiveness, range, and threats)
static func _find_tactical_position(from: Vector2i, target_pos: Vector2i, threats: Array[Node2D], max_range: int, current_distance: int, tactical_map: Node2D, precomputed_reachable: Array[Vector2i] = []) -> Vector2i:
	var best_position = from
	var best_score = -999.0

	# Ideal engagement range (stay at medium range if possible)
	const IDEAL_MIN_RANGE = 4
	const IDEAL_MAX_RANGE = 7

	# Check if currently has effective cover against threats
	var has_effective_cover = _is_cover_effective_against_threats(from, threats, tactical_map)
	var is_exposed = not has_effective_cover

	# Use pre-computed reachable positions if available, otherwise compute via BFS
	var checked_positions = precomputed_reachable if precomputed_reachable.size() > 0 else _get_reachable_positions(from, max_range, tactical_map)
	
	
	for pos in checked_positions:
		if pos == from:
			continue  # Skip current position initially
		
		var distance_to_target = abs(pos.x - target_pos.x) + abs(pos.y - target_pos.y)
		var score = 0.0
		
		# Check if this position has effective cover against threats
		var pos_has_effective_cover = _is_cover_effective_against_threats(pos, threats, tactical_map)
		var has_any_cover = tactical_map.has_adjacent_cover(pos)
		
		# PRIORITY: If exposed/flanked and this position has effective cover, heavily prioritize
		if is_exposed and pos_has_effective_cover:
			score += 80.0  # Very high priority to get into effective cover
		elif pos_has_effective_cover:
			score += 50.0  # Good bonus for effective cover
		elif has_any_cover:
			score += 20.0  # Some bonus for any cover, but less if it doesn't protect
		
		# Score based on range to target
		if distance_to_target >= IDEAL_MIN_RANGE and distance_to_target <= IDEAL_MAX_RANGE:
			# Ideal range - high score
			score += 40.0
		elif distance_to_target < IDEAL_MIN_RANGE:
			# Too close - penalize
			score += 15.0 - (IDEAL_MIN_RANGE - distance_to_target) * 8.0
		else:
			# Too far - moderate penalty
			score += 25.0 - (distance_to_target - IDEAL_MAX_RANGE) * 4.0
		
		# Bonus for line of sight to target
		if _has_line_of_sight(pos, target_pos, tactical_map):
			score += 25.0
		else:
			score -= 20.0  # Penalty for no LOS (but less severe if seeking cover)
		
		# Slight bonus for moving closer if far away
		if current_distance > IDEAL_MAX_RANGE and distance_to_target < current_distance:
			score += 10.0
		
		if score > best_score:
			best_score = score
			best_position = pos
	
	# If no good position found, at least try to move to effective cover or closer
	if best_position == from and checked_positions.size() > 1:
		# PRIORITY: Try to find any position with effective cover against threats
		for pos in checked_positions:
			if _is_cover_effective_against_threats(pos, threats, tactical_map):
				best_position = pos
				break
		
		# Try any cover if no effective cover
		if best_position == from:
			for pos in checked_positions:
				if tactical_map.has_adjacent_cover(pos):
					best_position = pos
					break
		
		# If still no cover, just move closer
		if best_position == from:
			best_position = _get_closest_position_to_target(from, target_pos, checked_positions)
	
	var _final_cover_status = "effective cover" if _is_cover_effective_against_threats(best_position, threats, tactical_map) else ("any cover" if tactical_map.has_adjacent_cover(best_position) else "no cover")
	return best_position


## Filter extraction tiles from a path (enemies should never move through extraction tiles)
## Path contains world positions from AStarGrid2D, need to convert to grid positions to check
static func _filter_extraction_tiles_from_path(path: PackedVector2Array, tactical_map: Node2D) -> PackedVector2Array:
	if path.is_empty():
		return path
	
	var filtered_path: PackedVector2Array = []
	for world_pos in path:
		# Convert world position (tile corner) to grid position
		var grid_pos = tactical_map.world_to_grid(world_pos)
		
		# Only add non-extraction tiles
		if not tactical_map.is_extraction_tile(grid_pos):
			filtered_path.append(world_pos)
	
	return filtered_path


## Get all reachable positions within movement range using BFS
static func _get_reachable_positions(from: Vector2i, max_range: int, tactical_map: Node2D) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var queue: Array[Vector2i] = [from]
	var visited: Dictionary = {from: true}
	var distances: Dictionary = {from: 0}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var dist = distances[current]
		
		# Only add to reachable if not an extraction tile and not a turret tile
		if not tactical_map.is_extraction_tile(current) and not tactical_map.has_turret_at(current):
			reachable.append(current)
		
		if dist < max_range:
			var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for dir in directions:
				var next_pos = current + dir
				
				# Skip extraction tiles, turret tiles, and non-walkable tiles
				if not visited.has(next_pos) and tactical_map.is_tile_walkable(next_pos) and not tactical_map.is_extraction_tile(next_pos) and not tactical_map.has_turret_at(next_pos):
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


## Find a position within attack range of the target officer
## Prefers positions that are exactly at or just within attack range (not too close)
static func _find_position_within_attack_range(enemy_pos: Vector2i, officer_pos: Vector2i, attack_range: int, move_range: int, tactical_map: Node2D, precomputed_reachable: Array[Vector2i] = []) -> Vector2i:
	var reachable = precomputed_reachable if precomputed_reachable.size() > 0 else _get_reachable_positions(enemy_pos, move_range, tactical_map)
	var best_pos = enemy_pos
	var best_score = -999.0
	
	# Current distance to officer
	var current_distance = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
	
	# If already within range, don't move
	if current_distance <= attack_range:
		return enemy_pos
	
	for pos in reachable:
		if pos == enemy_pos:
			continue
		
		var distance_to_officer = abs(officer_pos.x - pos.x) + abs(officer_pos.y - pos.y)
		var score = 0.0
		
		# High priority: positions within attack range
		if distance_to_officer <= attack_range:
			# Prefer positions that are at optimal range (not too close, not at the edge)
			# Ideal range is around 70-90% of attack range
			var ideal_min = int(attack_range * 0.7)
			var ideal_max = int(attack_range * 0.9)
			
			if distance_to_officer >= ideal_min and distance_to_officer <= ideal_max:
				score += 100.0  # Very high score for ideal range
			elif distance_to_officer < ideal_min:
				# Too close, but still in range - lower score
				score += 60.0 - (ideal_min - distance_to_officer) * 5.0
			else:
				# At the edge of range - still good
				score += 80.0
		else:
			# Not in range yet - score based on how much closer we get
			var distance_improvement = current_distance - distance_to_officer
			if distance_improvement > 0:
				# Moving closer is good, but prioritize getting into range
				score += distance_improvement * 2.0
				# Bonus if we're getting close to range
				if distance_to_officer <= attack_range + 2:
					score += 30.0
			else:
				# Moving away - penalize
				score -= 50.0
		
		# Bonus for line of sight to officer
		if _has_line_of_sight(pos, officer_pos, tactical_map):
			score += 20.0
		
		if score > best_score:
			best_score = score
			best_pos = pos
	
	return best_pos


## Decide action for boss enemies (biome-specific behavior)
static func decide_boss_action(boss: Node2D, officers: Array[Node2D], tactical_map: Node2D) -> Dictionary:
	# Get biome type from tactical_map using the getter method
	var biome = BiomeConfig.BiomeType.STATION
	if tactical_map.has_method("get_biome_type"):
		biome = tactical_map.get_biome_type()
	
	match biome:
		BiomeConfig.BiomeType.STATION:
			return _decide_station_boss_action(boss, officers, tactical_map)
		BiomeConfig.BiomeType.ASTEROID:
			return _decide_asteroid_boss_action(boss, officers, tactical_map)
		BiomeConfig.BiomeType.PLANET:
			return _decide_planet_boss_action(boss, officers, tactical_map)
		_:
			return _decide_station_boss_action(boss, officers, tactical_map)


## Station Boss AI - Tactical positioning, defensive, uses cover
static func _decide_station_boss_action(boss: Node2D, officers: Array[Node2D], tactical_map: Node2D) -> Dictionary:
	var boss_pos = boss.get_grid_position()
	var result = {"action": "idle", "target": null, "path": null}
	
	# Find nearest visible officer
	var nearest_officer: Node2D = null
	var nearest_distance = 999
	var visible_officers: Array[Node2D] = []
	
	for officer in officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(officer_pos.x - boss_pos.x) + abs(officer_pos.y - boss_pos.y)
		
		if distance <= boss.sight_range:
			visible_officers.append(officer)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_officer = officer
	
	if not nearest_officer:
		return result
	
	var target_pos = nearest_officer.get_grid_position()
	var can_shoot = nearest_distance <= boss.shoot_range and boss.has_ap(1) and _has_line_of_sight(boss_pos, target_pos, tactical_map)
	
	# Station boss prioritizes defensive positioning and cover
	var _has_cover = tactical_map.has_adjacent_cover(boss_pos)
	var is_effectively_covered = _is_cover_effective_against_threats(boss_pos, visible_officers, tactical_map)
	
	# PRIORITY 1: If can shoot from effective cover, shoot
	if can_shoot and is_effectively_covered:
		result["action"] = "shoot"
		result["target"] = nearest_officer
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 2: If exposed, move to effective cover
	if not is_effectively_covered and boss.has_ap(1):
		var cover_pos = _find_cover_against_threats(boss_pos, visible_officers, boss.move_range, tactical_map)
		if cover_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, cover_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = cover_pos
				return result
	
	# PRIORITY 3: If can shoot (even without perfect cover), shoot
	if can_shoot:
		result["action"] = "shoot"
		result["target"] = nearest_officer
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 4: Move to better tactical position (maintain medium range)
	if boss.has_ap(1):
		var tactical_pos = _find_tactical_position(boss_pos, target_pos, visible_officers, boss.move_range, nearest_distance, tactical_map)
		if tactical_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, tactical_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = tactical_pos
				return result
	
	# PRIORITY 5: Visible boss - always move towards closest officer
	if boss.has_ap(1) and boss.visible and nearest_officer:
		var reachable = _get_reachable_positions(boss_pos, boss.move_range, tactical_map)
		var move_pos = _get_closest_position_to_target(boss_pos, target_pos, reachable)
		if move_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, move_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = move_pos
				return result
	
	return result


## Asteroid Boss AI - Aggressive, charges players, area attacks
static func _decide_asteroid_boss_action(boss: Node2D, officers: Array[Node2D], tactical_map: Node2D) -> Dictionary:
	var boss_pos = boss.get_grid_position()
	var result = {"action": "idle", "target": null, "path": null}
	
	# Find nearest visible officer
	var nearest_officer: Node2D = null
	var nearest_distance = 999
	
	for officer in officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(officer_pos.x - boss_pos.x) + abs(officer_pos.y - boss_pos.y)
		
		if distance <= boss.sight_range and distance < nearest_distance:
			nearest_distance = distance
			nearest_officer = officer
	
	if not nearest_officer:
		return result
	
	var target_pos = nearest_officer.get_grid_position()
	var can_shoot = nearest_distance <= boss.shoot_range and boss.has_ap(1) and _has_line_of_sight(boss_pos, target_pos, tactical_map)
	
	# Asteroid boss is aggressive - charges toward players
	# PRIORITY 1: If can shoot, shoot
	if can_shoot:
		result["action"] = "shoot"
		result["target"] = nearest_officer
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 2: Charge toward nearest officer (aggressive movement)
	if boss.has_ap(1):
		var reachable = _get_reachable_positions(boss_pos, boss.move_range, tactical_map)
		var charge_pos = _get_closest_position_to_target(boss_pos, target_pos, reachable)
		
		if charge_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, charge_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = charge_pos
				return result
	
	# PRIORITY 3: Visible boss - always move towards closest officer
	if boss.has_ap(1) and boss.visible and nearest_officer:
		var reachable_fallback = _get_reachable_positions(boss_pos, boss.move_range, tactical_map)
		var move_pos = _get_closest_position_to_target(boss_pos, target_pos, reachable_fallback)
		if move_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, move_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = move_pos
				return result
	
	return result


## Planet Boss AI - Spawns minions, uses hit-and-run tactics
static func _decide_planet_boss_action(boss: Node2D, officers: Array[Node2D], tactical_map: Node2D) -> Dictionary:
	var boss_pos = boss.get_grid_position()
	var result = {"action": "idle", "target": null, "path": null}
	
	# Find nearest visible officer
	var nearest_officer: Node2D = null
	var nearest_distance = 999
	var visible_officers: Array[Node2D] = []
	
	for officer in officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(officer_pos.x - boss_pos.x) + abs(officer_pos.y - boss_pos.y)
		
		if distance <= boss.sight_range:
			visible_officers.append(officer)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_officer = officer
	
	if not nearest_officer:
		return result
	
	var target_pos = nearest_officer.get_grid_position()
	var can_shoot = nearest_distance <= boss.shoot_range and boss.has_ap(1) and _has_line_of_sight(boss_pos, target_pos, tactical_map)
	
	# Planet boss uses hit-and-run: shoot then reposition
	# PRIORITY 1: If can shoot and has AP for movement after, shoot
	if can_shoot and boss.has_ap(2):
		result["action"] = "shoot"
		result["target"] = nearest_officer
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 2: If can shoot (even without extra AP), shoot
	if can_shoot:
		result["action"] = "shoot"
		result["target"] = nearest_officer
		result["target_pos"] = target_pos
		return result
	
	# PRIORITY 3: Hit-and-run: move to medium range, maintain distance
	if boss.has_ap(1):
		# Prefer positions at medium range (5-7 tiles)
		var reachable = _get_reachable_positions(boss_pos, boss.move_range, tactical_map)
		var best_pos = boss_pos
		var best_score = -999.0
		
		for pos in reachable:
			if pos == boss_pos:
				continue
			
			var distance_to_target = abs(pos.x - target_pos.x) + abs(pos.y - target_pos.y)
			var score = 0.0
			
			# Prefer medium range (5-7 tiles)
			if distance_to_target >= 5 and distance_to_target <= 7:
				score += 50.0
			elif distance_to_target < 5:
				# Too close - move away
				score -= (5 - distance_to_target) * 10.0
			else:
				# Too far - move closer but not too close
				score += max(0.0, 30.0 - (distance_to_target - 7) * 5.0)
			
			# Bonus for line of sight
			if _has_line_of_sight(pos, target_pos, tactical_map):
				score += 20.0
			
			# Prefer positions with cover
			if tactical_map.has_adjacent_cover(pos):
				score += 15.0
			
			if score > best_score:
				best_score = score
				best_pos = pos
		
		if best_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, best_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = best_pos
				return result
	
	# PRIORITY 4: Visible boss - always move towards closest officer
	if boss.has_ap(1) and boss.visible and nearest_officer:
		var reachable_fallback = _get_reachable_positions(boss_pos, boss.move_range, tactical_map)
		var move_pos = _get_closest_position_to_target(boss_pos, target_pos, reachable_fallback)
		if move_pos != boss_pos:
			var path = _filter_extraction_tiles_from_path(tactical_map.find_path(boss_pos, move_pos), tactical_map)
			if path and path.size() > 1:
				result["action"] = "move"
				result["path"] = path
				result["target_pos"] = move_pos
				return result
	
	return result
