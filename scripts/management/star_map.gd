extends Control
## StarMap Controller - Progressive Graph Visualization
## Displays a graph of nodes centered on the player

signal node_clicked(node_data: NodeData)
signal jump_animation_complete
signal raider_animation_complete

@onready var map_content: Control = $MapContent
@onready var nodes_container: Control = $MapContent/NodesContainer
@onready var lines_container: Control = $MapContent/LinesContainer
@onready var ship_container: Control = $MapContent/ShipContainer

var MapNodeScene: PackedScene
var node_visuals: Dictionary = {}  # String (ID) -> MapNode visual instance
var ship_visual: TextureRect
var raider_visual: Node2D
var _is_ship_animating: bool = false # Flag to prevent refresh from stomping animation
const BASE_SPEED_PPS = 300.0 # Pixels per second base speed for ship movement

const ZOOM_STEP = 0.1
var _current_zoom: float = 1.0
var _input_locked: bool = false


func _ready() -> void:
	if not VoyageManager:
		push_error("VoyageManager not found!")
		return
		
	MapNodeScene = load("res://scenes/management/map_node.tscn")
	
	# Create ship visual
	_create_ship_visual()
	
	# If raider already exists (loaded save), create visual
	if VoyageManager.is_raider_active and VoyageManager.nodes.has(VoyageManager.raider_node_id):
		_create_raider_visual(VoyageManager.nodes[VoyageManager.raider_node_id])
	
	# Connect signals
	VoyageManager.map_updated.connect(refresh)
	VoyageManager.ship_moved.connect(_on_ship_moved)
	
	# Initial draw
	refresh()
	
	# Initial ship placement
	_update_ship_position(false)
	
	# Center view
	center_view_on_ship(false)
	
	VoyageManager.story_node_spawned.connect(_on_story_node_spawned)
	VoyageManager.raider_spawned.connect(_on_raider_spawned)
	VoyageManager.raider_moved.connect(_on_raider_moved)
	VoyageManager.raider_destroyed.connect(_on_raider_destroyed)


func _on_raider_spawned(node_data: NodeData) -> void:
	_create_raider_visual(node_data)
	refresh()
	
	# Start camera sequence for raider spawn
	_run_spawn_camera_sequence(node_data)

func _on_raider_moved(new_pos: Vector2, node_id: String) -> void:
	if raider_visual:
		# Connect to the move_complete signal and relay it
		if not raider_visual.move_complete.is_connected(_on_raider_move_complete):
			raider_visual.move_complete.connect(_on_raider_move_complete)
		raider_visual.move_to(new_pos, node_id)
	refresh()

func _on_raider_move_complete() -> void:
	raider_animation_complete.emit()

func _on_raider_destroyed() -> void:
	if raider_visual:
		raider_visual.queue_free()
		raider_visual = null
	refresh()

func _on_story_node_spawned(node_data: NodeData) -> void:
	if not node_data: return
	_run_spawn_camera_sequence(node_data, true)

func _run_spawn_camera_sequence(node_data: NodeData, is_story: bool = false) -> void:
	if not node_data: return
	
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
	
	# 4. Unlock and Emit if story
	tween.tween_callback(func():
		_input_locked = false
		if is_story:
			VoyageManager.story_sequence_finished.emit()
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
		
	ship_visual.modulate = Color(0.2, 0.8, 1.0) # Cyan/Blue for the ship
	ship_visual.custom_minimum_size = Vector2(32, 32) # Icon is 64x64, maybe scale down? Or let it be larger?
	# Let's keep 32x32 logic for consistency or update if needed. 
	# If source is 64x64, expansion might look big. Let's set rect size or scale.
	ship_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship_visual.size = Vector2(48, 48) # Make ship slightly larger than nodes (usually 40-ish?)
	# Nodes are just visuals.
	ship_visual.pivot_offset = Vector2(24, 24) # Center pivot
	ship_container.add_child(ship_visual)

func _create_raider_visual(node_data: NodeData) -> void:
	if raider_visual:
		raider_visual.queue_free()
		
	var RaiderScene = load("res://scenes/map/raider_ship.tscn")
	if RaiderScene:
		raider_visual = RaiderScene.instantiate()
		ship_container.add_child(raider_visual)
		# Center the raider ship on the node (same offset as player ship)
		raider_visual.position = node_data.position

func refresh() -> void:
	_clear_visuals()
	_draw_nodes()
	_draw_connections()
	
	# Ensure ship position is updated/reset correctly (e.g. restart)
	# BUT only if we are not currently animating a jump
	if not _is_ship_animating:
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
		
		# Only highlight red if raider is ON the player's node AND this is a travelable node
		var is_raider_threatened = false
		if raider_on_player_node:
			# Highlight all nodes the player could normally jump to
			if is_reachable:
				is_raider_threatened = true
		
		visual.initialize(node_data, is_current, is_reachable, is_raider_threatened)
		visual.clicked.connect(_on_node_clicked)
		
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
				
				_draw_line(start_point, end_point, is_traveled, is_potential)
				processed_connections[key] = true

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
	
	# Animate camera centering
	center_view_on_ship(true)

func _update_ship_position(animated: bool, target_pos: Vector2 = Vector2.ZERO, speed_mult: float = 1.0) -> void:
	if not ship_visual:
		_create_ship_visual()
		
	var final_pos = Vector2.ZERO
	if target_pos != Vector2.ZERO:
		final_pos = target_pos
	else:
		var current_node = VoyageManager.get_current_node()
		if current_node:
			final_pos = current_node.position
			
	# Center ship on node (ship is 32x32, pivot is center, but position is usually topleft for control)
	# Wait, if pivot is center, setting position sets the position of the rect's top-left in local coords?
	# Standard Control: Position is top-left.
	# Let's align center to center.
	# Center ship on node
	# Visual size is 48x48 (pivot 24,24)
	var visual_pos = final_pos - Vector2(24, 24)
	
	if animated:
		_is_ship_animating = true
		
		var distance = ship_visual.position.distance_to(visual_pos)
		var duration = distance / (BASE_SPEED_PPS * speed_mult)
		# Clamp minimum duration to avoid instant snaps on tiny movements, but allow fast direct travel
		duration = max(duration, 0.1)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ship_visual, "position", visual_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		# Rotate ship to face movement direction if we have a significant move
		if distance > 1.0:
			# Calculate direction using visual positions (both are top-left, so vector is correct direction)
			var direction = (visual_pos - ship_visual.position).normalized()
			
			# Calculate target rotation
			var target_rot = direction.angle()
			
			# Determine shortest rotation path
			var current_rot = ship_visual.rotation
			var diff = angle_difference(current_rot, target_rot)
			
			# Tween rotation
			# Tween rotation
			# Tween rotation
			var rot_duration = min(duration * 0.5, 0.4) # Rotate quickly, at most 0.4s
			tween.tween_property(ship_visual, "rotation", current_rot + diff, rot_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Wait for completion to emit signal
		tween.chain().tween_callback(func(): 
			_is_ship_animating = false
			jump_animation_complete.emit()
		)
	else:
		_is_ship_animating = false
		ship_visual.position = visual_pos
		# Maintain rotation - don't reset to 0

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
		_input_locked = false
