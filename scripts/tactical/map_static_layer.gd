extends Node2D
## Static tile rendering layer — draws floors, walls, covers, and extraction zones.
## Only redraws when the map layout or fog-of-war changes, not every frame.
## This keeps per-frame draw work in TacticalMap._draw() minimal (overlays/highlights only).

const TILE_SIZE: int = 32

## Mirror of TacticalMap.TileType — kept in sync manually.
enum TileType { FLOOR, WALL, EXTRACTION, HALF_COVER }


func _draw() -> void:
	var m = get_parent()
	for x in range(m.map_width):
		for y in range(m.map_height):
			var pos = Vector2i(x, y)
			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not m.revealed_tiles.get(pos, false):
				draw_rect(rect, m.current_theme["fog"])
			else:
				var tile_type = m.tile_data.get(pos, TileType.FLOOR)
				_draw_tile(m, x, y, rect, tile_type)


func _draw_tile(m: Node2D, x: int, y: int, rect: Rect2, tile_type) -> void:
	var hash_val = (x * 73 + y * 137) % 100
	match tile_type:
		TileType.FLOOR:
			_draw_floor_tile(m, rect, hash_val)
		TileType.WALL:
			_draw_wall_tile(m, x, y, rect, hash_val)
		TileType.EXTRACTION:
			_draw_extraction_tile(m, rect, hash_val)
		TileType.HALF_COVER:
			_draw_cover_tile(m, rect, hash_val)


func _draw_floor_tile(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var base_color = m.current_theme["floor_base"] if hash_val < 60 else m.current_theme["floor_var"]
	draw_rect(rect, base_color)
	match m.current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_floor_details(m, rect, hash_val)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_floor_details(m, rect, hash_val)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_floor_details(m, rect, hash_val)


func _draw_station_floor_details(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var panel_line_color = m.current_theme.get("floor_accent", Color(0.06, 0.07, 0.10, 0.8))
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), panel_line_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), panel_line_color, 1.0)

	if m.is_abandoned_station:
		if hash_val < 12:
			var fire_base = Color(0.85, 0.30, 0.04, 0.55)
			var fire_hot  = Color(1.00, 0.65, 0.10, 0.70)
			draw_circle(pos + Vector2(16, 18), 7, fire_base)
			draw_circle(pos + Vector2(16, 16), 4, fire_hot)
			draw_circle(pos + Vector2(14, 14), 2, Color(1.0, 0.9, 0.6, 0.85))
		elif hash_val < 22:
			var scorch = Color(0.08, 0.06, 0.04, 0.70)
			draw_circle(pos + Vector2(16, 16), 9, scorch)
			draw_circle(pos + Vector2(13, 18), 5, scorch.darkened(0.2))
		elif hash_val < 30:
			var crack = Color(0.04, 0.04, 0.06, 0.90)
			draw_line(pos + Vector2(4, 6),  pos + Vector2(20, 26), crack, 1.5)
			draw_line(pos + Vector2(20, 4), pos + Vector2(28, 18), crack, 1.0)
		elif hash_val > 90:
			var spark_a = Color(1.0, 0.85, 0.3, 0.90)
			var spark_b = Color(1.0, 0.50, 0.1, 0.80)
			draw_circle(pos + Vector2(8,  10), 1.5, spark_a)
			draw_circle(pos + Vector2(20, 8),  1.0, spark_b)
			draw_circle(pos + Vector2(24, 20), 1.5, spark_a)
			draw_circle(pos + Vector2(12, 24), 1.0, spark_b)
	else:
		if hash_val < 8:
			var blood_color = m.current_theme.get("blood", Color(0.55, 0.08, 0.08, 0.75))
			draw_circle(pos + Vector2(14, 16), 3, blood_color)
			draw_circle(pos + Vector2(18, 18), 2, blood_color.darkened(0.2))
		elif hash_val > 92:
			var accent_color = m.current_theme.get("accent_dim", Color(0.2, 0.6, 0.75, 0.6))
			draw_rect(Rect2(pos.x + 4, pos.y + 14, 24, 4), accent_color)


func _draw_asteroid_floor_details(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var accent_color = m.current_theme.get("floor_accent", Color(0.12, 0.1, 0.08, 0.6))
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), accent_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), accent_color, 1.0)
	if hash_val < 8:
		draw_line(pos + Vector2(6, 8), pos + Vector2(26, 24), accent_color.darkened(0.3), 1.5)
	elif hash_val > 92:
		draw_circle(pos + Vector2(16, 16), 2, Color(0.3, 0.45, 0.65, 0.4))


func _draw_planet_floor_details(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	var accent_color = m.current_theme.get("floor_accent", Color(0.08, 0.12, 0.06))
	var highlight_color = m.current_theme.get("floor_highlight", Color(0.18, 0.26, 0.14))
	draw_line(pos, pos + Vector2(TILE_SIZE, 0), accent_color, 1.0)
	draw_line(pos, pos + Vector2(0, TILE_SIZE), accent_color, 1.0)
	if hash_val < 25:
		draw_line(pos + Vector2(8, 20), pos + Vector2(10, 12), highlight_color, 1.0)
		draw_line(pos + Vector2(22, 22), pos + Vector2(24, 14), highlight_color, 1.0)
	elif hash_val > 75:
		draw_line(pos + Vector2(14, 24), pos + Vector2(16, 16), highlight_color, 1.0)
		draw_line(pos + Vector2(18, 26), pos + Vector2(19, 18), highlight_color, 1.0)


func _draw_wall_tile(m: Node2D, x: int, y: int, rect: Rect2, hash_val: int) -> void:
	var pos_i = Vector2i(x, y)
	var has_wall_above = m.tile_data.get(pos_i + Vector2i(0, -1), TileType.FLOOR) == TileType.WALL
	var has_wall_below = m.tile_data.get(pos_i + Vector2i(0, 1),  TileType.FLOOR) == TileType.WALL
	var has_wall_left  = m.tile_data.get(pos_i + Vector2i(-1, 0), TileType.FLOOR) == TileType.WALL
	var has_wall_right = m.tile_data.get(pos_i + Vector2i(1, 0),  TileType.FLOOR) == TileType.WALL
	var neighbor_count = int(has_wall_above) + int(has_wall_below) + int(has_wall_left) + int(has_wall_right)

	draw_rect(rect, m.current_theme["floor_base"])

	if m.current_biome == BiomeConfig.BiomeType.STATION:
		_draw_station_wall_tile(m, rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right, neighbor_count)
		return
	elif m.current_biome == BiomeConfig.BiomeType.PLANET:
		_draw_planet_wall_tile(m, rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right, neighbor_count)
		return

	# Generic wall (asteroid etc.)
	var wall_points: PackedVector2Array = []
	var inset = 4.0
	var edge_var = (hash_val % 6) - 3
	var irregularity = 0.3 if m.current_biome == BiomeConfig.BiomeType.ASTEROID else 0.2
	var tl = rect.position + Vector2(inset if not has_wall_left else 0,  inset if not has_wall_above else 0)
	var tr = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), inset if not has_wall_above else 0)
	var br = rect.position + Vector2(TILE_SIZE - (inset if not has_wall_right else 0), TILE_SIZE - (inset if not has_wall_below else 0))
	var bl = rect.position + Vector2(inset if not has_wall_left else 0, TILE_SIZE - (inset if not has_wall_below else 0))

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

	var shadow_points: PackedVector2Array = []
	for p in wall_points:
		shadow_points.append(p + Vector2(2, 2))
	if shadow_points.size() >= 3:
		draw_polygon(shadow_points, [Color(0.08, 0.06, 0.04, 0.6)])
	if wall_points.size() >= 3:
		draw_polygon(wall_points, [m.current_theme["wall"]])

	var highlight_color = m.current_theme["wall_highlight"]
	var shadow_color    = m.current_theme["wall_shadow"]
	if not has_wall_above:
		draw_line(tl + Vector2(2, 2), tr + Vector2(-2, 2), highlight_color, 2.0)
	if not has_wall_left:
		draw_line(tl + Vector2(2, 2), bl + Vector2(2, -2), highlight_color.darkened(0.2), 2.0)
	if not has_wall_below:
		draw_line(bl + Vector2(2, -2), br + Vector2(-2, -2), shadow_color, 2.0)
	if not has_wall_right:
		draw_line(tr + Vector2(-2, 2), br + Vector2(-2, -2), shadow_color, 1.5)
	if neighbor_count < 4:
		_draw_wall_details(m, rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right)


func _draw_station_wall_tile(m: Node2D, rect: Rect2, hash_val: int, has_wall_above: bool, has_wall_below: bool, has_wall_left: bool, has_wall_right: bool, neighbor_count: int) -> void:
	var pos = rect.position
	var wall_color      = m.current_theme["wall"]
	var highlight_color = m.current_theme["wall_highlight"]
	var shadow_color    = m.current_theme["wall_shadow"]
	var panel_color     = m.current_theme.get("wall_panel", wall_color.darkened(0.15))
	var outline_color   = Color(0.04, 0.05, 0.07)
	var inset           = 2.0

	if not has_wall_above: draw_rect(Rect2(pos.x, pos.y, TILE_SIZE, inset), outline_color)
	if not has_wall_below: draw_rect(Rect2(pos.x, pos.y + TILE_SIZE - inset, TILE_SIZE, inset), outline_color)
	if not has_wall_left:  draw_rect(Rect2(pos.x, pos.y, inset, TILE_SIZE), outline_color)
	if not has_wall_right: draw_rect(Rect2(pos.x + TILE_SIZE - inset, pos.y, inset, TILE_SIZE), outline_color)

	var wall_inset = 2.0
	var wall_rect = Rect2(
		pos.x + (wall_inset if not has_wall_left else 0),
		pos.y + (wall_inset if not has_wall_above else 0),
		TILE_SIZE - (wall_inset if not has_wall_left else 0) - (wall_inset if not has_wall_right else 0),
		TILE_SIZE - (wall_inset if not has_wall_above else 0) - (wall_inset if not has_wall_below else 0)
	)
	draw_rect(wall_rect, wall_color)

	var panel_inset = 5.0
	draw_rect(Rect2(pos.x + panel_inset, pos.y + panel_inset, TILE_SIZE - panel_inset * 2, TILE_SIZE - panel_inset * 2), panel_color)

	if not has_wall_above: draw_line(pos + Vector2(wall_inset, wall_inset), pos + Vector2(TILE_SIZE - wall_inset, wall_inset), highlight_color, 2.0)
	if not has_wall_left:  draw_line(pos + Vector2(wall_inset, wall_inset), pos + Vector2(wall_inset, TILE_SIZE - wall_inset), highlight_color.darkened(0.15), 2.0)
	if not has_wall_below: draw_line(pos + Vector2(wall_inset, TILE_SIZE - wall_inset - 1), pos + Vector2(TILE_SIZE - wall_inset, TILE_SIZE - wall_inset - 1), shadow_color, 2.0)
	if not has_wall_right: draw_line(pos + Vector2(TILE_SIZE - wall_inset - 1, wall_inset), pos + Vector2(TILE_SIZE - wall_inset - 1, TILE_SIZE - wall_inset), shadow_color, 2.0)

	if neighbor_count < 4:
		_draw_station_wall_details(m, rect, hash_val, has_wall_above, has_wall_below, has_wall_left, has_wall_right)


func _draw_planet_wall_tile(m: Node2D, rect: Rect2, hash_val: int, has_wall_above: bool, has_wall_below: bool, has_wall_left: bool, has_wall_right: bool, _neighbor_count: int) -> void:
	var pos             = rect.position
	var wall_color      = m.current_theme["wall"]
	var highlight_color = m.current_theme["wall_highlight"]
	var shadow_color    = m.current_theme["wall_shadow"]
	var crystal_color   = m.current_theme.get("wall_crystal", Color(0.70, 0.40, 0.75))
	var glow_color      = m.current_theme.get("wall_glow", Color(0.80, 0.50, 0.90, 0.6))
	var outline_color   = Color(0.12, 0.08, 0.15)
	var inset           = 2.0

	if not has_wall_above: draw_rect(Rect2(pos.x, pos.y, TILE_SIZE, inset), outline_color)
	if not has_wall_below: draw_rect(Rect2(pos.x, pos.y + TILE_SIZE - inset, TILE_SIZE, inset), outline_color)
	if not has_wall_left:  draw_rect(Rect2(pos.x, pos.y, inset, TILE_SIZE), outline_color)
	if not has_wall_right: draw_rect(Rect2(pos.x + TILE_SIZE - inset, pos.y, inset, TILE_SIZE), outline_color)

	var wall_inset = 2.0
	draw_rect(Rect2(
		pos.x + (wall_inset if not has_wall_left else 0),
		pos.y + (wall_inset if not has_wall_above else 0),
		TILE_SIZE - (wall_inset if not has_wall_left else 0) - (wall_inset if not has_wall_right else 0),
		TILE_SIZE - (wall_inset if not has_wall_above else 0) - (wall_inset if not has_wall_below else 0)
	), wall_color)

	var crystal_type = hash_val % 5
	match crystal_type:
		0:
			var points: PackedVector2Array = [pos + Vector2(8, 28), pos + Vector2(16, 4), pos + Vector2(24, 28)]
			draw_polygon(points, [crystal_color])
			draw_line(pos + Vector2(16, 4), pos + Vector2(14, 20), crystal_color.lightened(0.4), 2.0)
			draw_circle(pos + Vector2(16, 12), 4, glow_color)
		1:
			var p1: PackedVector2Array = [pos + Vector2(6, 26), pos + Vector2(10, 8), pos + Vector2(14, 26)]
			draw_polygon(p1, [crystal_color.darkened(0.15)])
			var p2: PackedVector2Array = [pos + Vector2(18, 28), pos + Vector2(24, 6), pos + Vector2(28, 28)]
			draw_polygon(p2, [crystal_color])
			draw_line(pos + Vector2(24, 6), pos + Vector2(22, 18), crystal_color.lightened(0.35), 1.5)
		2:
			draw_rect(Rect2(pos.x + 6, pos.y + 6, 20, 20), shadow_color)
			draw_rect(Rect2(pos.x + 8, pos.y + 8, 16, 16), wall_color.lightened(0.1))
			draw_circle(pos + Vector2(12, 12), 3, glow_color)
			draw_circle(pos + Vector2(20, 20), 2, glow_color.darkened(0.2))
		3:
			var rock_points: PackedVector2Array = [pos + Vector2(4, 28), pos + Vector2(8, 16), pos + Vector2(14, 22), pos + Vector2(18, 8), pos + Vector2(24, 18), pos + Vector2(28, 28)]
			draw_polygon(rock_points, [wall_color.lightened(0.08)])
			draw_line(pos + Vector2(18, 8), pos + Vector2(16, 16), highlight_color, 2.0)
		4:
			draw_circle(pos + Vector2(16, 16), 12, wall_color)
			draw_circle(pos + Vector2(16, 16), 8, shadow_color)
			draw_circle(pos + Vector2(16, 16), 4, m.current_theme.get("biolum_pink", Color(0.95, 0.45, 0.65, 0.8)))

	if not has_wall_above: draw_line(pos + Vector2(wall_inset + 2, wall_inset + 2), pos + Vector2(TILE_SIZE - wall_inset - 2, wall_inset + 2), highlight_color, 2.0)
	if not has_wall_left:  draw_line(pos + Vector2(wall_inset + 2, wall_inset + 2), pos + Vector2(wall_inset + 2, TILE_SIZE - wall_inset - 2), highlight_color.darkened(0.2), 1.5)
	if not has_wall_below: draw_line(pos + Vector2(wall_inset, TILE_SIZE - wall_inset - 1), pos + Vector2(TILE_SIZE - wall_inset, TILE_SIZE - wall_inset - 1), shadow_color, 2.0)
	if not has_wall_right: draw_line(pos + Vector2(TILE_SIZE - wall_inset - 1, wall_inset), pos + Vector2(TILE_SIZE - wall_inset - 1, TILE_SIZE - wall_inset), shadow_color, 1.5)


func _draw_wall_details(m: Node2D, rect: Rect2, hash_val: int, _above: bool, _below: bool, _left: bool, _right: bool) -> void:
	var detail_color = m.current_theme["wall_shadow"]
	match m.current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_wall_details(m, rect, hash_val, _above, _below, _left, _right)
		BiomeConfig.BiomeType.ASTEROID:
			if hash_val % 4 == 0:
				draw_line(rect.position + Vector2(8, 4), rect.position + Vector2(24, 28), detail_color, 1.5)
			if hash_val % 7 == 0:
				draw_line(rect.position + Vector2(6, 16), rect.position + Vector2(26, 14), Color(0.3, 0.4, 0.6, 0.5), 2.0)
		BiomeConfig.BiomeType.PLANET:
			if hash_val % 3 == 0:
				draw_circle(rect.position + Vector2(10, 8), 3, m.current_theme["floor_accent"])
			if hash_val % 5 == 0:
				draw_line(rect.position + Vector2(4, 20), rect.position + Vector2(14, 28), detail_color, 1.5)


func _draw_station_wall_details(m: Node2D, rect: Rect2, hash_val: int, _above: bool, _below: bool, _left: bool, _right: bool) -> void:
	var pos             = rect.position
	var highlight_color = m.current_theme["wall_highlight"]
	var shadow_color    = m.current_theme["wall_shadow"]
	var accent_color    = m.current_theme.get("accent_glow", Color(0.2, 0.8, 0.9, 0.8))
	var accent_dim      = m.current_theme.get("accent_dim", Color(0.15, 0.5, 0.6, 0.5))

	if not _left:
		draw_circle(pos + Vector2(6, 8),  2, shadow_color)
		draw_circle(pos + Vector2(6, 24), 2, shadow_color)
		draw_circle(pos + Vector2(5.5, 7.5),  1, highlight_color.darkened(0.3))
		draw_circle(pos + Vector2(5.5, 23.5), 1, highlight_color.darkened(0.3))
	if not _right:
		draw_circle(pos + Vector2(26, 8),  2, shadow_color)
		draw_circle(pos + Vector2(26, 24), 2, shadow_color)

	if hash_val % 6 == 0:
		var panel_rect = Rect2(pos.x + 6, pos.y + 6, 20, 20)
		draw_rect(panel_rect, m.current_theme.get("wall_panel", shadow_color))
		draw_line(pos + Vector2(6, 6), pos + Vector2(26, 6), shadow_color, 1.0)
		draw_line(pos + Vector2(6, 6), pos + Vector2(6, 26), shadow_color, 1.0)
		draw_line(pos + Vector2(26, 6), pos + Vector2(26, 26), highlight_color.darkened(0.4), 1.0)
		draw_line(pos + Vector2(6, 26), pos + Vector2(26, 26), highlight_color.darkened(0.4), 1.0)
	elif hash_val % 6 == 1:
		var pipe_x = pos.x + 10 + (hash_val % 8)
		draw_rect(Rect2(pipe_x - 2, pos.y, 4, TILE_SIZE), shadow_color)
		draw_line(Vector2(pipe_x - 2, pos.y), Vector2(pipe_x - 2, pos.y + TILE_SIZE), highlight_color.darkened(0.3), 1.0)
	elif hash_val % 6 == 2:
		var vent_color = shadow_color.lightened(0.1)
		for i in range(5):
			draw_line(pos + Vector2(6, 4 + i * 5), pos + Vector2(26, 4 + i * 5), vent_color, 2.0)
	elif hash_val % 6 == 3 and not _above:
		draw_rect(Rect2(pos.x + 4, pos.y + 2, 24, 3), accent_color)
		draw_rect(Rect2(pos.x + 2, pos.y + 1, 28, 5), accent_dim)
	elif hash_val % 6 == 4:
		draw_rect(Rect2(pos.x + 8, pos.y + 8, 16, 12), Color(0.05, 0.08, 0.12))
		draw_rect(Rect2(pos.x + 10, pos.y + 10, 12, 6), accent_dim)
		draw_circle(pos + Vector2(12, 22), 2, Color(0.8, 0.2, 0.2, 0.8))
		draw_circle(pos + Vector2(20, 22), 2, Color(0.2, 0.8, 0.3, 0.8))
	elif hash_val % 6 == 5:
		var stripe_color = Color(0.7, 0.6, 0.1, 0.6)
		for i in range(4):
			draw_line(Vector2(pos.x + i * 8, pos.y + 4), Vector2(pos.x + i * 8 + 6, pos.y + 28), stripe_color, 2.0)

	if m.is_abandoned_station:
		var damage_slot = hash_val % 5
		if damage_slot == 0:
			var scorch = Color(0.06, 0.04, 0.02, 0.75)
			draw_circle(pos + Vector2(16, 12), 8, scorch)
			draw_circle(pos + Vector2(20, 18), 5, scorch.darkened(0.3))
		elif damage_slot == 1:
			var wire_orange = Color(1.0, 0.55, 0.1, 0.85)
			var wire_yellow = Color(1.0, 0.90, 0.3, 0.90)
			draw_line(pos + Vector2(10, 8),  pos + Vector2(14, 14), wire_orange, 1.5)
			draw_line(pos + Vector2(18, 10), pos + Vector2(22, 16), wire_orange, 1.5)
			draw_circle(pos + Vector2(14, 14), 2.0, wire_yellow)
			draw_circle(pos + Vector2(22, 16), 1.5, wire_yellow)
		elif damage_slot == 2:
			var crack = Color(0.03, 0.03, 0.04, 0.95)
			draw_line(pos + Vector2(5, 4),  pos + Vector2(14, 16), crack, 2.0)
			draw_line(pos + Vector2(14, 16), pos + Vector2(10, 28), crack, 1.5)
			draw_line(pos + Vector2(14, 16), pos + Vector2(24, 20), crack, 1.0)
		elif damage_slot == 3:
			var fire_base = Color(0.80, 0.25, 0.04, 0.50)
			var fire_tip  = Color(1.00, 0.60, 0.10, 0.65)
			draw_circle(pos + Vector2(10, 26), 5, fire_base)
			draw_circle(pos + Vector2(10, 22), 3, fire_tip)
			draw_circle(pos + Vector2(20, 25), 4, fire_base)
			draw_circle(pos + Vector2(20, 21), 2, fire_tip)


func _draw_extraction_tile(m: Node2D, rect: Rect2, hash_val: int) -> void:
	match m.current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_extraction(m, rect, hash_val)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_extraction(m, rect, hash_val)
		_:
			_draw_default_extraction(m, rect, hash_val)


func _draw_default_extraction(m: Node2D, rect: Rect2, _hash_val: int) -> void:
	draw_rect(rect, m.current_theme["extraction"])
	draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, TILE_SIZE - 8, TILE_SIZE - 8), m.current_theme["extraction_glow"])
	var corner_size = 6
	var mc = m.current_theme["extraction_marker"]
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2 + corner_size, 2), mc, 2.0)
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2, 2 + corner_size), mc, 2.0)
	draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2 - corner_size, TILE_SIZE - 2), mc, 2.0)
	draw_line(rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 2 - corner_size), mc, 2.0)


func _draw_station_extraction(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	draw_rect(rect, Color(0.08, 0.12, 0.10))
	draw_rect(Rect2(pos.x + 2, pos.y + 2, TILE_SIZE - 4, TILE_SIZE - 4), m.current_theme["extraction"])
	draw_rect(Rect2(pos.x + 6, pos.y + 6, TILE_SIZE - 12, TILE_SIZE - 12), m.current_theme["extraction_glow"])
	var grid_color = m.current_theme["extraction_marker"].darkened(0.3)
	draw_line(pos + Vector2(4, TILE_SIZE / 2), pos + Vector2(TILE_SIZE - 4, TILE_SIZE / 2), grid_color, 1.0)
	draw_line(pos + Vector2(TILE_SIZE / 2, 4), pos + Vector2(TILE_SIZE / 2, TILE_SIZE - 4), grid_color, 1.0)
	var mc = m.current_theme["extraction_marker"]
	var cs = 8
	draw_line(pos + Vector2(2, 2), pos + Vector2(2 + cs, 2), mc, 2.0)
	draw_line(pos + Vector2(2, 2), pos + Vector2(2, 2 + cs), mc, 2.0)
	draw_line(pos + Vector2(4, 4), pos + Vector2(4 + cs - 2, 4), mc, 1.0)
	draw_line(pos + Vector2(4, 4), pos + Vector2(4, 4 + cs - 2), mc, 1.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, 2), pos + Vector2(TILE_SIZE - 2 - cs, 2), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, 2), pos + Vector2(TILE_SIZE - 2, 2 + cs), mc, 2.0)
	draw_line(pos + Vector2(2, TILE_SIZE - 2), pos + Vector2(2 + cs, TILE_SIZE - 2), mc, 2.0)
	draw_line(pos + Vector2(2, TILE_SIZE - 2), pos + Vector2(2, TILE_SIZE - 2 - cs), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), pos + Vector2(TILE_SIZE - 2 - cs, TILE_SIZE - 2), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2 - cs), mc, 2.0)
	var pulse_factor = 0.7 + 0.3 * sin(hash_val * 0.5)
	var center_light_color = mc * pulse_factor
	center_light_color.a = 0.8
	draw_circle(pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2), 4, center_light_color)


func _draw_planet_extraction(m: Node2D, rect: Rect2, hash_val: int) -> void:
	var pos = rect.position
	draw_rect(rect, Color(0.10, 0.15, 0.16))
	draw_rect(Rect2(pos.x + 2, pos.y + 2, TILE_SIZE - 4, TILE_SIZE - 4), m.current_theme["extraction"])
	draw_rect(Rect2(pos.x + 6, pos.y + 6, TILE_SIZE - 12, TILE_SIZE - 12), m.current_theme["extraction_glow"])
	var mc = m.current_theme["extraction_marker"]
	var center = pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	for i in range(16):
		var a1 = (float(i) / 16.0) * TAU
		var a2 = (float(i + 1) / 16.0) * TAU
		draw_line(center + Vector2(cos(a1) * 12, sin(a1) * 12), center + Vector2(cos(a2) * 12, sin(a2) * 12), mc.darkened(0.2), 1.5)
	for i in range(12):
		var a1 = (float(i) / 12.0) * TAU
		var a2 = (float(i + 1) / 12.0) * TAU
		draw_line(center + Vector2(cos(a1) * 8, sin(a1) * 8), center + Vector2(cos(a2) * 8, sin(a2) * 8), mc, 2.0)
	var co = 4
	var gs = 6
	draw_line(pos + Vector2(co, co), pos + Vector2(co + gs, co), mc, 2.0)
	draw_line(pos + Vector2(co, co), pos + Vector2(co, co + gs), mc, 2.0)
	draw_circle(pos + Vector2(co + 2, co + 2), 2, mc)
	draw_line(pos + Vector2(TILE_SIZE - co, co), pos + Vector2(TILE_SIZE - co - gs, co), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - co, co), pos + Vector2(TILE_SIZE - co, co + gs), mc, 2.0)
	draw_line(pos + Vector2(co, TILE_SIZE - co), pos + Vector2(co + gs, TILE_SIZE - co), mc, 2.0)
	draw_line(pos + Vector2(co, TILE_SIZE - co), pos + Vector2(co, TILE_SIZE - co - gs), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - co, TILE_SIZE - co), pos + Vector2(TILE_SIZE - co - gs, TILE_SIZE - co), mc, 2.0)
	draw_line(pos + Vector2(TILE_SIZE - co, TILE_SIZE - co), pos + Vector2(TILE_SIZE - co, TILE_SIZE - co - gs), mc, 2.0)
	var pulse_factor = 0.6 + 0.4 * sin(hash_val * 0.4)
	var beacon_color = mc * pulse_factor
	beacon_color.a = 0.9
	draw_circle(center, 5, beacon_color)
	draw_circle(center, 3, Color(0.9, 1.0, 0.95, 0.8))


func _draw_cover_tile(m: Node2D, rect: Rect2, hash_val: int) -> void:
	if m.current_theme.is_empty():
		return
	draw_rect(rect, m.current_theme["floor_base"])
	var base_rect = Rect2(rect.position.x + 4, rect.position.y + 4, TILE_SIZE - 8, TILE_SIZE - 8)
	var base_color: Color
	match m.current_biome:
		BiomeConfig.BiomeType.STATION:  base_color = m.current_theme.get("wall_shadow", Color(0.12, 0.14, 0.18))
		BiomeConfig.BiomeType.ASTEROID: base_color = m.current_theme.get("floor_accent", Color(0.12, 0.1, 0.08, 0.6))
		BiomeConfig.BiomeType.PLANET:   base_color = m.current_theme.get("floor_accent", Color(0.08, 0.12, 0.06, 0.6))
	draw_rect(base_rect, base_color)
	var center = rect.position + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	match m.current_biome:
		BiomeConfig.BiomeType.STATION:  _draw_station_cover(m, center, hash_val)
		BiomeConfig.BiomeType.ASTEROID: _draw_asteroid_cover(m, center, hash_val)
		BiomeConfig.BiomeType.PLANET:   _draw_planet_cover(m, center, hash_val)


func _draw_station_cover(m: Node2D, center: Vector2, hash_val: int) -> void:
	var main_color    = m.current_theme["cover_main"]
	var dark_color    = m.current_theme["cover_dark"]
	var light_color   = m.current_theme["cover_light"]
	var outline_color = Color(0.02, 0.02, 0.04)
	draw_polygon([center + Vector2(-10, -8), center + Vector2(10, -8), center + Vector2(10, 10), center + Vector2(-10, 10)], [main_color])
	draw_polygon([center + Vector2(-10, -8), center + Vector2(10, -8), center + Vector2(8, -5), center + Vector2(-8, -5)], [light_color])
	draw_rect(Rect2(center.x - 7, center.y - 2, 14, 8), dark_color)
	draw_line(center + Vector2(-10, -8), center + Vector2(10, -8), outline_color, 1.0)
	draw_line(center + Vector2(-10, 10), center + Vector2(10, 10), outline_color, 1.0)
	if hash_val % 4 == 0:
		draw_circle(center + Vector2(4, 2), 2, m.current_theme.get("accent_glow", Color(0.3, 0.9, 1.0)))
	draw_rect(Rect2(center.x - 4, center.y + 1, 8, 2), Color(0.9, 0.8, 0.2, 0.8))


func _draw_asteroid_cover(m: Node2D, center: Vector2, hash_val: int) -> void:
	var rock_color = m.current_theme["cover_main"]
	var rock_dark  = m.current_theme["cover_dark"]
	var rock_light = m.current_theme["cover_light"]
	draw_polygon([center + Vector2(-8, 10), center + Vector2(-10, 0), center + Vector2(-4, -8), center + Vector2(6, -10), center + Vector2(10, 4), center + Vector2(8, 10)], [rock_color])
	draw_line(center + Vector2(-4, -8), center + Vector2(0, 2),   rock_dark,  1.5)
	draw_line(center + Vector2(-10, 0), center + Vector2(-4, -8), rock_light, 2.0)
	if hash_val % 3 == 0:
		draw_circle(center + Vector2(3, -2), 3, Color(0.3, 0.5, 0.8, 0.4))


func _draw_planet_cover(m: Node2D, center: Vector2, hash_val: int) -> void:
	var foliage_color = m.current_theme.get("cover_main",  Color(0.35, 0.55, 0.58))
	var foliage_dark  = m.current_theme.get("cover_dark",  Color(0.22, 0.38, 0.42))
	var stem_color    = m.current_theme.get("cover_stem",  Color(0.45, 0.40, 0.35))
	var biolum_yellow = m.current_theme.get("biolum_yellow", Color(1.0, 0.85, 0.30, 0.85))
	draw_rect(Rect2(center.x - 3, center.y - 2, 6, 11), stem_color)
	draw_polygon([center + Vector2(-12, 0), center + Vector2(-10, -8), center + Vector2(0, -14), center + Vector2(10, -8), center + Vector2(12, 0), center + Vector2(0, 2)], [foliage_color])
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), foliage_dark, 2.0)
	draw_circle(center + Vector2(-4, -6), 2, biolum_yellow)
	draw_circle(center + Vector2(5, -4),  1.5, biolum_yellow)
	draw_circle(center + Vector2(8, 6),   4, foliage_dark)
