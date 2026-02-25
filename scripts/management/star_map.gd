extends Control
## StarMap Controller - Progressive Graph Visualization
## Displays a graph of nodes centered on the player

signal node_clicked(node_data: NodeData)
signal jump_animation_complete
signal raider_animation_complete
signal raider_outcome_animation_complete

@onready var map_content: Control = $MapContent
@onready var raider_indicator: Control = $RaiderIndicator
@onready var story_indicator: Control = $StoryIndicator
@onready var nodes_container: Control = $MapContent/NodesContainer
@onready var lines_container: Control = $MapContent/LinesContainer
@onready var ship_container: Control = $MapContent/ShipContainer
@onready var node_info_panel: NodeInfoPanel = $NodeInfoPanel

var MapNodeScene: PackedScene
var node_visuals: Dictionary = {}  # String (ID) -> MapNode visual instance
var ship_visual: TextureRect
var raider_visual: Node2D
var raider_zone_visual: Node2D = null
var player_travel_zone_visual: Node2D = null
var _is_ship_animating: bool = false # Flag to prevent refresh from stomping animation
var _is_raider_animating: bool = false # Flag to prevent refresh from snapping raider mid-move
var _ship_pulse_tween: Tween = null
var _raider_hit_shake_tween: Tween = null  # Killed and recreated on each machine-gun hit
var _raider_hit_flash_tween: Tween = null  # Killed and recreated on each machine-gun hit
const BASE_SPEED_PPS = 300.0 # Pixels per second base speed for ship movement

const ZOOM_STEP = 0.1
const SAME_NODE_SHIP_OFFSET: float = 50.0
var _current_zoom: float = 1.0
var _input_locked: bool = false


func _both_on_same_node() -> bool:
	return VoyageManager and VoyageManager.is_raider_active and \
		VoyageManager.raider_node_id == VoyageManager.current_node_id


func _get_player_display_offset(node_pos: Vector2) -> Vector2:
	if _both_on_same_node():
		return node_pos + Vector2(-SAME_NODE_SHIP_OFFSET, 0)
	return node_pos


func _get_raider_display_offset(node_pos: Vector2) -> Vector2:
	if _both_on_same_node():
		return node_pos + Vector2(SAME_NODE_SHIP_OFFSET, 0)
	return node_pos


func _update_raider_position_for_same_node(animated: bool = false) -> void:
	## When player and raider share a node, reposition the raider to standoff layout.
	## Needed when player jumps to raider's node (raider doesn't move, so no raider_moved signal).
	## Skip when raider is animating (e.g. moving to player node) to avoid snapping mid-move.
	if not raider_visual or not _both_on_same_node() or _is_raider_animating:
		return
	var raider_node = VoyageManager.nodes[VoyageManager.raider_node_id]
	if not raider_node:
		return
	var target_pos = _get_raider_display_offset(raider_node.position)
	const ROT_DURATION: float = 1.2  # Smooth, deliberate rotation to face opponent
	if animated:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(raider_visual, "position", target_pos, ROT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var current_rot = raider_visual.rotation
		var diff = angle_difference(current_rot, PI)
		tween.tween_property(raider_visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		raider_visual.position = target_pos
		# Always smoothly rotate to face player (never snap)
		var current_rot = raider_visual.rotation
		var diff = angle_difference(current_rot, PI)
		if abs(diff) > 0.01:
			var rot_tween = create_tween()
			rot_tween.tween_property(raider_visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			raider_visual.rotation = PI


func _process(_delta: float) -> void:
	_update_raider_indicator()
	_update_story_indicator()


func _update_raider_indicator() -> void:
	if not raider_indicator:
		return
	if not VoyageManager or not VoyageManager.is_raider_active:
		raider_indicator.visible = false
		return
	if not VoyageManager.nodes.has(VoyageManager.raider_node_id):
		raider_indicator.visible = false
		return

	var raider_world_pos: Vector2
	if raider_visual:
		raider_world_pos = raider_visual.position
	else:
		var raider_node = VoyageManager.nodes[VoyageManager.raider_node_id]
		raider_world_pos = raider_node.position

	var raider_screen_pos := map_content.position + raider_world_pos * _current_zoom
	raider_indicator.update_indicator(raider_screen_pos, size)

	# Update detection circle brightness based on whether player is inside it
	_update_raider_zone_brightness()


func _update_raider_zone_brightness() -> void:
	if not raider_zone_visual:
		return
	var in_zone := VoyageManager.is_player_in_raider_zone()
	if raider_zone_visual.get("player_in_zone") != in_zone:
		raider_zone_visual.set("player_in_zone", in_zone)
		raider_zone_visual.queue_redraw()


func _update_story_indicator() -> void:
	if not story_indicator:
		return
	if not VoyageManager or VoyageManager.active_story_node_id.is_empty():
		story_indicator.visible = false
		return
	if not VoyageManager.nodes.has(VoyageManager.active_story_node_id):
		story_indicator.visible = false
		return

	var story_node = VoyageManager.nodes[VoyageManager.active_story_node_id]
	if story_node.state != NodeData.NodeState.STORY:
		story_indicator.visible = false
		return

	var story_world_pos: Vector2 = story_node.position
	var story_screen_pos: Vector2 = map_content.position + story_world_pos * _current_zoom
	story_indicator.update_indicator(story_screen_pos, size)


func _ready() -> void:
	if not VoyageManager:
		push_error("VoyageManager not found!")
		return
		
	MapNodeScene = load("res://scenes/management/map_node.tscn")

	if story_indicator:
		story_indicator.set_indicator_color(StarMapNode.COLOR_STORY)

	# Create ship visual
	_create_ship_visual()
	
	# If raider already exists (loaded save), restore visuals
	if VoyageManager.is_raider_active and VoyageManager.nodes.has(VoyageManager.raider_node_id):
		var raider_node_data = VoyageManager.nodes[VoyageManager.raider_node_id]
		_create_raider_zone_visual(raider_node_data.position, VoyageManager.RAIDER_DETECTION_RADIUS)
		_create_raider_visual(raider_node_data)
	
	# Create green travel radius circle (always visible around player)
	_create_player_travel_zone_visual()
	
	# Connect signals
	VoyageManager.map_updated.connect(refresh)
	VoyageManager.ship_moved.connect(_on_ship_moved)
	VoyageManager.ship_teleported.connect(_on_ship_teleported)
	GameState.fuel_changed.connect(func(_v): refresh())
	
	# Initial draw
	refresh()
	
	# Initial ship placement
	_update_ship_position(false)
	
	# Center view
	center_view_on_ship(false)
	
	# Show info for the starting node
	_update_node_info_panel()
	
	VoyageManager.story_node_spawned.connect(_on_story_node_spawned)
	VoyageManager.raider_spawned.connect(_on_raider_spawned)
	VoyageManager.raider_moved.connect(_on_raider_moved)
	VoyageManager.raider_destroyed.connect(_on_raider_destroyed)


func _on_raider_spawned(node_data: NodeData) -> void:
	_create_raider_zone_visual(node_data.position, VoyageManager.RAIDER_DETECTION_RADIUS)
	_create_raider_visual(node_data)
	refresh()
	
	# Start camera sequence for raider spawn
	_run_spawn_camera_sequence(node_data)

func _on_raider_moved(new_pos: Vector2, node_id: String) -> void:
	if raider_visual:
		_is_raider_animating = true
		# Connect to the move_complete signal and relay it
		if not raider_visual.move_complete.is_connected(_on_raider_move_complete):
			raider_visual.move_complete.connect(_on_raider_move_complete)
		var display_pos = _get_raider_display_offset(new_pos)
		var target_rot = PI if _both_on_same_node() else -999.0  # Sentinel = use movement direction
		raider_visual.move_to(display_pos, node_id, 1.0, target_rot)
	# Smoothly animate the detection circle to follow the raider (match raider ship speed)
	if raider_zone_visual:
		var dist = raider_zone_visual.position.distance_to(new_pos)
		var duration = clampf(dist / 600.0, 0.5, 2.0)
		var tween = create_tween()
		tween.tween_property(raider_zone_visual, "position", new_pos, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	refresh()

func _on_raider_move_complete() -> void:
	_is_raider_animating = false
	raider_animation_complete.emit()

func _on_raider_destroyed() -> void:
	_is_raider_animating = false
	if raider_visual:
		raider_visual.queue_free()
		raider_visual = null
	if raider_zone_visual:
		raider_zone_visual.queue_free()
		raider_zone_visual = null
	refresh()

func _on_story_node_spawned(node_data: NodeData) -> void:
	if not node_data: return
	_run_spawn_camera_sequence(node_data, true)

func _run_spawn_camera_sequence(node_data: NodeData, is_story: bool = false) -> void:
	if not node_data: return

	# Dev mode: skip camera animation if requested
	var should_skip = (is_story and GameState.dev_skip_story_spawn_camera) or (not is_story and GameState.dev_skip_raider_spawn_camera)
	if should_skip:
		if _is_ship_animating:
			await jump_animation_complete
		if is_story:
			VoyageManager.story_sequence_finished.emit()
		else:
			VoyageManager.raider_sequence_finished.emit()
		return
	
	# If ship is jumping, wait for it to finish before stealing camera
	if _is_ship_animating:
		await jump_animation_complete
	
	_input_locked = true
	
	# Calculate target position to center on the new node
	var target_pos = (size / 2.0) - (node_data.position * _current_zoom)
	
	var tween = create_tween()
	
	# 1. Pan to node (1.5s)
	tween.tween_property(map_content, "position", target_pos, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Wait at node (2.0s)
	tween.tween_interval(2.0)
	
	# 3. Pan back to ship (1.5s)
	var ship_node = VoyageManager.get_current_node()
	if ship_node:
		var ship_pos = (size / 2.0) - (ship_node.position * _current_zoom)
		tween.tween_property(map_content, "position", ship_pos, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 4. Unlock and Emit finished signal
	tween.tween_callback(func():
		_input_locked = false
		if is_story:
			VoyageManager.story_sequence_finished.emit()
		else:
			VoyageManager.raider_sequence_finished.emit()
	)


func _create_ship_visual() -> void:
	if ship_visual:
		return
		
	ship_visual = TextureRect.new()
	# Load dedicated ship icon
	ship_visual.texture = load("res://assets/sprites/navigation/ship_icon.png") 
	if not ship_visual.texture:
		# Fallback if icon missing
		ship_visual.texture = preload("res://assets/sprites/navigation/waypoint.png")

	ship_visual.custom_minimum_size = Vector2(96, 96) # 3x base size for visibility
	ship_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship_visual.size = Vector2(144, 144) # 3x larger ship icon for voyage menu visibility
	ship_visual.pivot_offset = Vector2(72, 72) # Center pivot (half of 144)
	ship_container.add_child(ship_visual)
	_start_ship_idle_pulse()


func _start_ship_idle_pulse() -> void:
	_stop_ship_idle_pulse()
	if not ship_visual:
		return
	_ship_pulse_tween = ship_visual.create_tween()
	_ship_pulse_tween.set_loops()
	_ship_pulse_tween.tween_property(ship_visual, "scale", Vector2(1.05, 1.05), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ship_pulse_tween.tween_property(ship_visual, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_ship_idle_pulse() -> void:
	if _ship_pulse_tween:
		_ship_pulse_tween.kill()
		_ship_pulse_tween = null
	if ship_visual:
		ship_visual.scale = Vector2(1.0, 1.0)


func _create_raider_zone_visual(origin: Vector2, radius: float) -> void:
	if raider_zone_visual:
		raider_zone_visual.queue_free()
	raider_zone_visual = Node2D.new()
	raider_zone_visual.position = origin
	# Attach a minimal inline script so _draw() renders the filled circle
	var script = GDScript.new()
	script.source_code = """extends Node2D
var zone_radius: float = 1200.0
var player_in_zone: bool = false

const FILL_NORMAL := Color(1.0, 0.1, 0.1, 0.07)
const OUTLINE_NORMAL := Color(1.0, 0.2, 0.2, 0.25)
const FILL_ALERTED := Color(1.0, 0.2, 0.2, 0.18)
const OUTLINE_ALERTED := Color(1.0, 0.45, 0.45, 0.55)

func _draw() -> void:
	var fill = FILL_ALERTED if player_in_zone else FILL_NORMAL
	var outline = OUTLINE_ALERTED if player_in_zone else OUTLINE_NORMAL
	draw_circle(Vector2.ZERO, zone_radius, fill)
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 128, outline, 4.0)
"""
	script.reload()
	raider_zone_visual.set_script(script)
	raider_zone_visual.set("zone_radius", radius)
	# Insert at index 0 so it renders beneath lines and nodes
	map_content.add_child(raider_zone_visual)
	map_content.move_child(raider_zone_visual, 0)


func _create_player_travel_zone_visual() -> void:
	if player_travel_zone_visual:
		return
	player_travel_zone_visual = Node2D.new()
	var current_node = VoyageManager.get_current_node()
	player_travel_zone_visual.position = current_node.position if current_node else Vector2.ZERO
	var script = GDScript.new()
	script.source_code = """extends Node2D
var zone_radius: float = 1200.0

const OUTLINE_COLOR := Color(0.2, 0.75, 0.35, 0.4)
const OUTLINE_WIDTH := 4.0

func _draw() -> void:
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 128, OUTLINE_COLOR, OUTLINE_WIDTH)
"""
	script.reload()
	player_travel_zone_visual.set_script(script)
	player_travel_zone_visual.set("zone_radius", VoyageManager.PLAYER_TRAVEL_RADIUS)
	player_travel_zone_visual.visible = not VoyageManager.is_player_in_raider_zone()
	map_content.add_child(player_travel_zone_visual)
	map_content.move_child(player_travel_zone_visual, 0)


func _create_raider_visual(node_data: NodeData) -> void:
	if raider_visual:
		raider_visual.queue_free()
		
	var RaiderScene = load("res://scenes/map/raider_ship.tscn")
	if RaiderScene:
		raider_visual = RaiderScene.instantiate()
		ship_container.add_child(raider_visual)
		raider_visual.position = _get_raider_display_offset(node_data.position)
		if _both_on_same_node():
			# Smoothly rotate to face player (never snap)
			const ROT_DURATION: float = 1.2
			var current_rot = raider_visual.rotation
			var diff = angle_difference(current_rot, PI)
			if abs(diff) > 0.01:
				var rot_tween = create_tween()
				rot_tween.tween_property(raider_visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				raider_visual.rotation = PI

func refresh() -> void:
	_clear_visuals()
	_draw_nodes()
	_draw_connections()
	
	# Update player travel zone: hide when pursued, position when visible
	if player_travel_zone_visual:
		player_travel_zone_visual.visible = not VoyageManager.is_player_in_raider_zone()
		if player_travel_zone_visual.visible and not _is_ship_animating:
			var current_node = VoyageManager.get_current_node()
			if current_node:
				player_travel_zone_visual.position = current_node.position
	
	# Ensure ship position is updated (smoothly recenter when raider leaves; instant on other updates)
	if not _is_ship_animating:
		var current_node = VoyageManager.get_current_node()
		if current_node:
			var display_center = _get_player_display_offset(current_node.position)
			var target_visual = display_center - Vector2(72, 72)
			var dist = 0.0
			if ship_visual:
				dist = ship_visual.position.distance_to(target_visual)
			# Smoothly animate when ship needs to recenter (e.g. raider left standoff)
			if dist > 2.0:
				_update_ship_position(true, current_node.position, 1.0, false)  # animate, no jump_complete emit
			else:
				_update_ship_position(false)

func _clear_visuals() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	node_visuals.clear()
	
	for child in lines_container.get_children():
		child.queue_free()

func _draw_nodes() -> void:
	var nodes = VoyageManager.get_visible_nodes()
	var current_node = VoyageManager.get_current_node()
	
	# Check if raider is ON the player's current node (ambush active)
	var raider_on_player_node = VoyageManager.is_raider_active and \
		VoyageManager.raider_node_id == VoyageManager.current_node_id
	
	for node_data in nodes:
		var visual = MapNodeScene.instantiate()
		nodes_container.add_child(visual)
		
		# Position is now directly from world position
		visual.position = node_data.position - Vector2(40, 40) # Center (80x80 node)
		
		# Determine if reachable (Connected to current)
		var is_current = (node_data.id == VoyageManager.current_node_id)
		var is_reachable = false
		
		if current_node and node_data.id in current_node.connections:
			is_reachable = true
		
		# Direct travel: visited nodes within green circle can be jumped to (disabled when pursued by raider or out of fuel)
		var is_direct_travelable = is_reachable
		if not is_reachable and node_data.state != NodeData.NodeState.UNVISITED:
			is_direct_travelable = not VoyageManager.is_player_in_raider_zone() \
				and GameState.fuel > 0 \
				and VoyageManager.is_node_within_travel_radius(node_data)
		
		# Only highlight red if raider is ON the player's node AND this is a travelable node
		var is_raider_threatened = false
		if raider_on_player_node:
			# Highlight all nodes the player could normally jump to
			if is_reachable:
				is_raider_threatened = true
		
		visual.initialize(node_data, is_current, is_reachable, is_raider_threatened, is_direct_travelable)
		visual.clicked.connect(_on_node_clicked)
		visual.hovered.connect(_on_node_hovered)
		visual.hover_ended.connect(_on_node_hover_ended)

		node_visuals[node_data.id] = visual

func _draw_connections() -> void:
	# Draw lines based on actual connections in data
	
	var processed_connections = {} # "id1-id2" -> true
	
	for source_id in node_visuals:
		var start_visual = node_visuals[source_id]
		var source_node = start_visual.node_data
		var start_point = start_visual.position + Vector2(40, 40)
		
		for target_id in source_node.connections:
			if node_visuals.has(target_id):
				# Check if already processed
				var key = _get_connection_key(source_id, target_id)
				if processed_connections.has(key):
					continue
					
				var end_visual = node_visuals[target_id]
				var end_point = end_visual.position + Vector2(40, 40)
				
				# Determine if this is a traveled path
				var target_node = end_visual.node_data
				var is_traveled = false
				var is_potential = false
				
				# A path is "traveled" (amber) if both endpoints have been visited/cleared/story.
				# This covers parent-child, proximity, and story connections.
				var source_visited = source_node.state != NodeData.NodeState.UNVISITED
				var target_visited = target_node.state != NodeData.NodeState.UNVISITED
				if source_visited and target_visited:
					is_traveled = true
				
				# A path is "potential" (pulsing blue) if one end is the current node
				# and the other is unvisited — i.e. a jump the player can make right now.
				if not is_traveled:
					var current_id = VoyageManager.current_node_id
					if (source_id == current_id and target_node.state == NodeData.NodeState.UNVISITED) or \
					   (target_id == current_id and source_node.state == NodeData.NodeState.UNVISITED):
						is_potential = true
				
				# Skip drawing normal line if this is a wormhole pair (draw separately as white)
				var is_wormhole_pair = _is_wormhole_pair(source_id, target_id)
				if not is_wormhole_pair:
					_draw_line(start_point, end_point, is_traveled, is_potential)
				processed_connections[key] = true

	# Draw wormhole pair pathlines (white) with directional arrows
	for pair in VoyageManager.wormhole_pairs:
		var from_id = str(pair[0])
		var to_id = str(pair[1])
		if node_visuals.has(from_id) and node_visuals.has(to_id):
			var v_from = node_visuals[from_id]
			var v_to = node_visuals[to_id]
			var from_point = v_from.position + Vector2(40, 40)
			var to_point = v_to.position + Vector2(40, 40)
			_draw_wormhole_line(from_point, to_point)

func _is_wormhole_pair(id1: String, id2: String) -> bool:
	var key = _get_connection_key(id1, id2)
	for pair in VoyageManager.wormhole_pairs:
		var pk = _get_connection_key(str(pair[0]), str(pair[1]))
		if pk == key:
			return true
	return false

func _get_connection_key(id1: String, id2: String) -> String:
	if id1 < id2:
		return id1 + "-" + id2
	else:
		return id2 + "-" + id1

func _draw_line(from: Vector2, to: Vector2, is_traveled: bool = false, is_potential: bool = false) -> void:
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.width = 3.0
	
	if is_traveled:
		line.default_color = Color(1.0, 0.75, 0.0, 0.8) # Amber for traveled path
		line.width = 4.0 # Slightly thicker
	elif is_potential:
		line.default_color = Color(0.4, 0.6, 0.8, 0.5) # Default start color
		
		# Pulse animation
		var tween = line.create_tween()
		tween.set_loops()
		tween.tween_property(line, "default_color", Color(0.6, 0.9, 1.0, 0.9), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(line, "default_color", Color(0.4, 0.6, 0.8, 0.5), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		line.default_color = Color(0.4, 0.6, 0.8, 0.5) # Default blueish
	
	lines_container.add_child(line)

const WORMHOLE_ARROW_SPACING: float = 100.0
const WORMHOLE_ARROW_SIZE: float = 10.0

func _draw_wormhole_line(from: Vector2, to: Vector2) -> void:
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.width = 4.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.9)  # White for wormhole path (matches legend)
	lines_container.add_child(line)

	# Add directional triangles along the line (pointing towards destination)
	var direction = (to - from).normalized()
	var line_length = from.distance_to(to)
	var num_arrows = max(1, int(line_length / WORMHOLE_ARROW_SPACING))
	for i in range(num_arrows):
		var t = (float(i) + 1.0) / (num_arrows + 1.0)  # Distribute evenly, away from endpoints
		var pos = from.lerp(to, t)
		_draw_wormhole_arrow(pos, direction)


func _draw_wormhole_arrow(pos: Vector2, direction: Vector2) -> void:
	# Triangle pointing right (0 rad), then rotate to match direction
	var s = WORMHOLE_ARROW_SIZE
	var triangle = Polygon2D.new()
	triangle.polygon = PackedVector2Array([
		Vector2(s, 0),           # Tip
		Vector2(-s * 0.6, s * 0.8),   # Base left
		Vector2(-s * 0.6, -s * 0.8)   # Base right
	])
	triangle.color = Color(1.0, 1.0, 1.0, 0.9)  # Match wormhole line
	triangle.position = pos
	triangle.rotation = direction.angle()
	lines_container.add_child(triangle)

func _gui_input(event: InputEvent) -> void:
	if not visible or _input_locked:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_in(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_out(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				# Start panning
				pass
			else:
				# Stop panning
				pass
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			map_content.position += event.relative

func _zoom_in(center_point: Vector2 = Vector2.ZERO) -> void:
	var old_zoom = _current_zoom
	_current_zoom = min(_current_zoom + ZOOM_STEP, 2.0)
	_update_zoom(center_point, old_zoom)

func _zoom_out(center_point: Vector2 = Vector2.ZERO) -> void:
	var old_zoom = _current_zoom
	_current_zoom = max(_current_zoom - ZOOM_STEP, 0.2)
	_update_zoom(center_point, old_zoom)

func _update_zoom(center_point: Vector2, old_zoom: float) -> void:
	if center_point == Vector2.ZERO:
		# Fallback to center of screen if no point provided (e.g. initial set)
		center_point = size / 2.0
		
	# Calculate the position relative to the map_content before zoom
	# local_mouse = (global_mouse - node_position) / scale
	var local_mouse = (center_point - map_content.position) / old_zoom
	
	# Apply new scale
	map_content.scale = Vector2(_current_zoom, _current_zoom)
	
	# Calculate new position to keep local_mouse at the same global position
	# new_position = global_mouse - (local_mouse * new_scale)
	map_content.position = center_point - (local_mouse * _current_zoom)


func _on_node_clicked(node_data: NodeData) -> void:
	if _input_locked:
		return
	node_clicked.emit(node_data)

func _on_ship_moved(new_pos: Vector2, node_data: NodeData, speed_mult: float = 1.0) -> void:
	_input_locked = true
	# Animate ship movement
	_update_ship_position(true, new_pos, speed_mult)
	
	# Smoothly animate player travel circle to new position (match ship speed)
	if player_travel_zone_visual:
		var dist = player_travel_zone_visual.position.distance_to(new_pos)
		var duration = maxf(dist / (BASE_SPEED_PPS * speed_mult), 0.1)
		var tween = create_tween()
		tween.tween_property(player_travel_zone_visual, "position", new_pos, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Animate camera centering
	center_view_on_ship(true)
	
	_update_node_info_panel()


const TELEPORT_DURATION: float = 0.45  # demat 0.2s + materialize 0.25s

func _on_ship_teleported(new_pos: Vector2, _node_data: NodeData) -> void:
	_input_locked = true
	_is_ship_animating = true
	# Teleport: dematerialize -> snap to destination -> materialize (camera animates same as jump)
	_play_teleport_animation(new_pos)
	# Smoothly animate player travel circle to new position during teleport
	if player_travel_zone_visual:
		var tween = create_tween()
		tween.tween_property(player_travel_zone_visual, "position", new_pos, TELEPORT_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_update_node_info_panel()


func _on_node_hovered(node_data: NodeData) -> void:
	if node_info_panel:
		node_info_panel.show_node(node_data)


func _on_node_hover_ended() -> void:
	_update_node_info_panel()


func _update_node_info_panel() -> void:
	if not node_info_panel:
		return
	var current_node := VoyageManager.get_current_node()
	if not current_node:
		node_info_panel.hide_panel()
		return
	# Waypoints (EMPTY_SPACE) that are not story nodes or special endpoints are excluded
	var is_plain_waypoint := (current_node.node_type == EventManager.NodeType.EMPTY_SPACE
		and not current_node.is_story_node
		and not current_node.is_new_earth
		and current_node.position != Vector2.ZERO)
	if is_plain_waypoint:
		node_info_panel.hide_panel()
	else:
		node_info_panel.show_node(current_node)

func _update_ship_position(animated: bool, target_pos: Vector2 = Vector2.ZERO, speed_mult: float = 1.0, emit_jump_complete: bool = true) -> void:
	if not ship_visual:
		_create_ship_visual()
		
	var final_pos = Vector2.ZERO
	if target_pos != Vector2.ZERO:
		final_pos = target_pos
	else:
		var current_node = VoyageManager.get_current_node()
		if current_node:
			final_pos = current_node.position
	
	# Reposition raider when player jumps to its node (raider doesn't move, so no raider_moved signal)
	_update_raider_position_for_same_node(animated)
	
	# Apply same-node offset when player and raider share a node
	var display_center = _get_player_display_offset(final_pos)
	# Center ship on node (ship is 144x144, pivot 72,72)
	var visual_pos = display_center - Vector2(72, 72)
	
	if animated:
		_is_ship_animating = true
		
		var distance = ship_visual.position.distance_to(visual_pos)
		var duration = distance / (BASE_SPEED_PPS * speed_mult)
		# Clamp minimum duration to avoid instant snaps on tiny movements, but allow fast direct travel
		duration = max(duration, 0.1)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ship_visual, "position", visual_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		# Rotation: face opponent when same node (0 rad = right), else face movement direction
		var target_rot: float
		if _both_on_same_node():
			target_rot = 0.0  # Face right toward raider
		elif distance > 1.0:
			var direction = (visual_pos - ship_visual.position).normalized()
			target_rot = direction.angle()
		else:
			target_rot = ship_visual.rotation  # No movement, keep current
		
		if distance > 1.0 or _both_on_same_node():
			var current_rot = ship_visual.rotation
			var diff = angle_difference(current_rot, target_rot)
			var rot_duration = min(duration * 0.5, 1.2)
			tween.tween_property(ship_visual, "rotation", current_rot + diff, rot_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Wait for completion to emit signal (skip for recenter animation)
		tween.chain().tween_callback(func():
			_is_ship_animating = false
			if emit_jump_complete:
				jump_animation_complete.emit()
		)
	else:
		_is_ship_animating = false
		ship_visual.position = visual_pos
		if _both_on_same_node():
			# Smoothly rotate to face raider (never snap)
			const ROT_DURATION: float = 1.2
			var current_rot = ship_visual.rotation
			var diff = angle_difference(current_rot, 0.0)
			if abs(diff) > 0.01:
				var rot_tween = create_tween()
				rot_tween.tween_property(ship_visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				ship_visual.rotation = 0.0
		# Else maintain rotation

func _play_teleport_animation(target_pos: Vector2) -> void:
	if not ship_visual:
		_create_ship_visual()
	_stop_ship_idle_pulse()
	# Reposition raider when player teleports to its node (smoothly animate to face player)
	_update_raider_position_for_same_node(true)
	var display_center = _get_player_display_offset(target_pos)
	var visual_pos = display_center - Vector2(72, 72)

	# Dematerialize: fade out + shrink (0.2s)
	var demat_tween = create_tween()
	demat_tween.set_parallel(true)
	demat_tween.tween_property(ship_visual, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	demat_tween.tween_property(ship_visual, "scale", Vector2(0.3, 0.3), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	demat_tween.tween_property(ship_visual, "rotation", 0.0, 0.2)  # Reset rotation for clean reappearance

	# Snap to destination then materialize (fade in + scale up in parallel)
	demat_tween.tween_callback(func():
		ship_visual.position = visual_pos
		ship_visual.modulate.a = 0.0
		ship_visual.scale = Vector2(0.3, 0.3)
	)
	demat_tween.set_parallel(true)
	demat_tween.tween_property(ship_visual, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	demat_tween.tween_property(ship_visual, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	demat_tween.set_parallel(false)
	demat_tween.tween_callback(func():
		_is_ship_animating = false
		_start_ship_idle_pulse()
		jump_animation_complete.emit()
	)

	# Camera animates same as jump
	center_view_on_ship(true)


## Smoothly pan the camera to center on any NodeData world position.
## Called by the NavigationLegendStrip when a legend entry is clicked.
func center_view_on_node(node_data: NodeData) -> void:
	if not node_data:
		return
	var target_pos = (size / 2.0) - (node_data.position * _current_zoom)
	var tween = create_tween()
	tween.tween_property(map_content, "position", target_pos, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func center_view_on_ship(animated: bool) -> void:
	var current_node = VoyageManager.get_current_node()
	if not current_node:
		return
		
	# Calculate target position based on current zoom
	# We want: (size / 2.0) = map_content.position + (current_node.position * _current_zoom)
	var target_pos = (size / 2.0) - (current_node.position * _current_zoom)
	
	if animated:
		var tween = create_tween()
		tween.tween_property(map_content, "position", target_pos, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func(): _input_locked = false)
	else:
		map_content.position = target_pos


#region Raider Outcome Attack Animations

## Orchestrate ship attack animation based on raider mission outcome.
## success=true              → player fires laser at raider, raider destroyed
## success=false, no surrender → raider fires laser at player, raider flies away
## success=false, is_surrender → raider rotates away and departs (no attack)
## Emits raider_outcome_animation_complete when sequence is finished.
func play_raider_outcome_animation(success: bool, is_surrender: bool = false) -> void:
	center_view_on_ship(false)

	if is_surrender:
		await get_tree().create_timer(0.3).timeout
		await _play_raider_surrender_depart()
		await get_tree().create_timer(0.2).timeout
	elif success:
		await get_tree().create_timer(0.5).timeout
		# Player lurch fires in the background — do NOT await it.
		# Machine-gun lasers + raider shake run in parallel with the lurch,
		# then the explosion fires immediately after the last hit (no gap).
		_start_player_ship_attack_lurch()
		await _spawn_machine_gun_lasers(_get_player_center(), _get_raider_center())
		await _play_raider_destruction()
		await get_tree().create_timer(0.3).timeout
	else:
		await get_tree().create_timer(0.5).timeout
		_spawn_laser_beam(_get_raider_center(), _get_player_center(), false)
		await _play_raider_ship_attack()
		await _play_raider_fly_away()
		await get_tree().create_timer(0.3).timeout

	raider_outcome_animation_complete.emit()


## Center of the player ship visual in ship_container local space.
func _get_player_center() -> Vector2:
	if not ship_visual:
		return Vector2.ZERO
	return ship_visual.position + Vector2(72.0, 72.0)


## Center of the raider visual in ship_container local space.
func _get_raider_center() -> Vector2:
	if not raider_visual:
		return Vector2.ZERO
	return raider_visual.position


## Spawn a temporary laser beam Line2D from from_pos to to_pos.
## is_player=true: gold beam; is_player=false: red beam.
## quick=true uses shorter timings for machine-gun bursts (appear 0.03s / hold 0.06s / fade 0.12s).
## Normal timings: appear 0.05s / hold 0.15s / fade 0.2s.
func _spawn_laser_beam(from_pos: Vector2, to_pos: Vector2, is_player: bool, quick: bool = false) -> void:
	if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
		return

	var beam := Line2D.new()
	beam.add_point(from_pos)
	beam.add_point(to_pos)
	beam.width = 4.5 if quick else 3.5
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND

	var base_color := Color(1.0, 0.9, 0.3) if is_player else Color(1.0, 0.2, 0.2)
	beam.default_color = Color(base_color.r, base_color.g, base_color.b, 0.0)
	ship_container.add_child(beam)

	var full_color := Color(base_color.r, base_color.g, base_color.b, 1.0)
	var fade_color := Color(base_color.r, base_color.g, base_color.b, 0.0)
	var appear := 0.03 if quick else 0.05
	var hold   := 0.06 if quick else 0.15
	var fade   := 0.12 if quick else 0.2
	var tween := beam.create_tween()
	tween.tween_property(beam, "default_color", full_color, appear)
	tween.tween_interval(hold)
	tween.tween_property(beam, "default_color", fade_color, fade)
	tween.tween_callback(func(): beam.queue_free())


## Player ship fires – yellow flash, scale pulse, lurch and recoil.
func _play_player_ship_attack() -> void:
	if not ship_visual:
		return
	_stop_ship_idle_pulse()

	var forward := Vector2(cos(ship_visual.rotation), sin(ship_visual.rotation))
	var lurch_offset := forward * 6.0
	var recoil_offset := -forward * 4.0
	var base_pos := ship_visual.position

	var tween = create_tween()
	tween.tween_property(ship_visual, "position", base_pos + lurch_offset, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.6, 1.4, 0.4, 1.0), 0.6)
	tween.parallel().tween_property(ship_visual, "scale", Vector2(1.08, 1.08), 0.6)
	tween.tween_property(ship_visual, "position", base_pos + recoil_offset, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.2, 1.1, 0.6, 1.0), 0.8)
	tween.tween_property(ship_visual, "position", base_pos, 1.6).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.6)
	tween.parallel().tween_property(ship_visual, "scale", Vector2(1.0, 1.0), 1.6)
	tween.tween_callback(_start_ship_idle_pulse)

	await tween.finished


## Raider fires on player – delegates to raider_ship.play_attack_animation().
func _play_raider_ship_attack() -> void:
	if not raider_visual or not raider_visual.has_method("play_attack_animation"):
		return

	raider_visual.play_attack_animation()
	await raider_visual.attack_animation_complete


## Raider destruction sequence after player wins – spawns explosion VFX then
## delegates sprite fade to play_destruction_sequence().
func _play_raider_destruction() -> void:
	if not raider_visual or not raider_visual.has_method("play_destruction_sequence"):
		return

	# Explosion cloud runs in parallel with the sprite flash-and-fade.
	_spawn_explosion_vfx(raider_visual.position)
	raider_visual.play_destruction_sequence()
	await raider_visual.destruction_complete


## Raider fly-away after defeat – delegates to play_fly_away().
func _play_raider_fly_away() -> void:
	if not raider_visual or not raider_visual.has_method("play_fly_away"):
		return

	raider_visual.play_fly_away()
	await raider_visual.fly_away_complete


## Raider surrender depart – delegates to play_surrender_depart().
func _play_raider_surrender_depart() -> void:
	if not raider_visual or not raider_visual.has_method("play_surrender_depart"):
		return

	raider_visual.play_surrender_depart()
	await raider_visual.surrender_depart_complete


## Kick off the player ship lurch/recoil without awaiting — runs in background
## alongside machine-gun lasers so the explosion happens immediately after hits.
func _start_player_ship_attack_lurch() -> void:
	if not ship_visual:
		return
	_stop_ship_idle_pulse()

	var forward := Vector2(cos(ship_visual.rotation), sin(ship_visual.rotation))
	var base_pos := ship_visual.position

	var tween := create_tween()
	tween.tween_property(ship_visual, "position", base_pos + forward * 6.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.6, 1.4, 0.4, 1.0), 0.35)
	tween.parallel().tween_property(ship_visual, "scale", Vector2(1.08, 1.08), 0.35)
	tween.tween_property(ship_visual, "position", base_pos - forward * 4.0, 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.2, 1.1, 0.6, 1.0), 0.45)
	tween.tween_property(ship_visual, "position", base_pos, 0.9).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ship_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.9)
	tween.parallel().tween_property(ship_visual, "scale", Vector2(1.0, 1.0), 0.9)
	tween.tween_callback(_start_ship_idle_pulse)


## Fire 4 rapid laser shots from player to raider, shaking the raider on each hit.
## Each beam is a quick flash (appear 0.03s / hold 0.06s / fade 0.12s).
## Awaitable — resolves once the last beam has faded.
func _spawn_machine_gun_lasers(from_pos: Vector2, to_pos: Vector2) -> void:
	var shots := 4
	var interval := 0.11  # seconds between shots
	for i in range(shots):
		if i > 0:
			await get_tree().create_timer(interval).timeout
		# Slight random spread per shot for a machine-gun feel
		var spread := Vector2(randf_range(-3.0, 3.0), randf_range(-2.5, 2.5))
		_spawn_laser_beam(from_pos, to_pos + spread, true, true)
		_hit_shake_raider()
	# Wait for the last beam to finish fading before returning
	await get_tree().create_timer(0.22).timeout


## Shake the raider sprite and flash it red-orange to sell each laser impact.
## Kills any in-progress shake/flash tweens first to avoid property conflicts.
func _hit_shake_raider() -> void:
	if not raider_visual:
		return
	var sprite: Sprite2D = raider_visual.get_node_or_null("Sprite2D")
	if not sprite:
		return

	if _raider_hit_shake_tween:
		_raider_hit_shake_tween.kill()
	if _raider_hit_flash_tween:
		_raider_hit_flash_tween.kill()

	var jx := randf_range(-4.0, 4.0)
	var jy := randf_range(-2.5, 2.5)

	_raider_hit_shake_tween = sprite.create_tween()
	_raider_hit_shake_tween.tween_property(sprite, "position", Vector2(jx, jy), 0.04).set_ease(Tween.EASE_OUT)
	_raider_hit_shake_tween.tween_property(sprite, "position", Vector2(-jx * 0.5, jy * 0.4), 0.04)
	_raider_hit_shake_tween.tween_property(sprite, "position", Vector2.ZERO, 0.06)

	_raider_hit_flash_tween = sprite.create_tween()
	_raider_hit_flash_tween.tween_property(sprite, "modulate", Color(2.2, 0.5, 0.2, 1.0), 0.03)
	_raider_hit_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


## Three-stage explosion cloud centred on `center` in ship_container local space.
## Stage 1 – blinding white-yellow core burst (quick expand + fade).
## Stage 2 – orange blast ring (wider, slower).
## Stage 3 – dark smoke ring (widest, slowest).
func _spawn_explosion_vfx(center: Vector2) -> void:
	# Stage 1: Core flash
	var core := ColorRect.new()
	core.size = Vector2(44, 44)
	core.pivot_offset = Vector2(22, 22)
	core.position = center - Vector2(22, 22)
	core.color = Color(1.0, 1.0, 0.75, 1.0)
	ship_container.add_child(core)
	var t1 := core.create_tween()
	t1.tween_property(core, "scale", Vector2(3.5, 3.5), 0.14)
	t1.parallel().tween_property(core, "color", Color(1.0, 0.6, 0.1, 0.0), 0.32)
	t1.tween_callback(core.queue_free)

	# Stage 2: Orange blast ring
	var blast := ColorRect.new()
	blast.size = Vector2(64, 64)
	blast.pivot_offset = Vector2(32, 32)
	blast.position = center - Vector2(32, 32)
	blast.color = Color(1.0, 0.4, 0.05, 0.8)
	ship_container.add_child(blast)
	var t2 := blast.create_tween()
	t2.tween_property(blast, "scale", Vector2(4.0, 4.0), 0.45)
	t2.parallel().tween_property(blast, "color:a", 0.0, 0.55)
	t2.tween_callback(blast.queue_free)

	# Stage 3: Smoke ring
	var smoke := ColorRect.new()
	smoke.size = Vector2(52, 52)
	smoke.pivot_offset = Vector2(26, 26)
	smoke.position = center - Vector2(26, 26)
	smoke.color = Color(0.28, 0.18, 0.08, 0.55)
	ship_container.add_child(smoke)
	var t3 := smoke.create_tween()
	t3.set_ease(Tween.EASE_OUT)
	t3.tween_property(smoke, "scale", Vector2(5.0, 5.0), 0.75)
	t3.parallel().tween_property(smoke, "color:a", 0.0, 0.9)
	t3.tween_callback(smoke.queue_free)

#endregion
