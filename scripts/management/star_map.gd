extends Control
## StarMap Controller - Progressive Graph Visualization
## Displays a graph of nodes centered on the player

signal node_clicked(node_data: NodeData)
signal jump_animation_complete
signal raider_animation_complete
signal raider_outcome_animation_complete
signal wormhole_destination_selected(node_data: NodeData)
signal wormhole_select_cancelled
## Emitted at the moment the last raider laser hits the player (failure path).
## main.gd connects this ONE_SHOT to apply hull damage in sync with the impact.
signal raider_attack_impact

@onready var map_content: Control = $MapContent
var raider_indicators: Dictionary = {}  # raider_node_id -> RaiderOffScreenIndicator
var RaiderIndicatorScene: PackedScene
@onready var story_indicator: Control = $StoryIndicator
@onready var nodes_container: Control = $MapContent/NodesContainer
@onready var lines_container: Control = $MapContent/LinesContainer
@onready var ship_container: Control = $MapContent/ShipContainer
@onready var node_info_panel: NodeInfoPanel = $NodeInfoPanel

var MapNodeScene: PackedScene
var node_visuals: Dictionary = {}  # String (ID) -> MapNode visual instance
var ship_visual: TextureRect
var raider_visuals: Dictionary = {}       # current_node_id -> RaiderShip Node2D
var raider_zone_visuals: Dictionary = {}  # current_node_id -> Node2D (detection circle)
var player_travel_zone_visual: Node2D = null
var _is_ship_animating: bool = false # Flag to prevent refresh from stomping animation
var _ship_recenter_tween: Tween = null # Tracked so we can kill it before jumps
var _raiders_animating: int = 0  # Count of raiders currently mid-move animation
var _ship_pulse_tween: Tween = null
var _raider_hit_shake_tween: Tween = null   # Killed and recreated on each raider-side hit
var _raider_hit_flash_tween: Tween = null   # Killed and recreated on each raider-side hit
var _player_hit_shake_tween: Tween = null   # Killed and recreated on each player-side hit
var _player_hit_flash_tween: Tween = null   # Killed and recreated on each player-side hit
var _outcome_raider_id: String = ""  # ID of the raider currently undergoing outcome animation
var _wormhole_select_mode: bool = false
var _wormhole_eligible_ids: Array[String] = []
const BASE_SPEED_PPS = 300.0 # Pixels per second base speed for ship movement

const ZOOM_STEP = 0.1
const SAME_NODE_SHIP_OFFSET: float = 50.0
var _current_zoom: float = 1.0
var _input_locked: bool = false


func _both_on_same_node() -> bool:
	return VoyageManager and VoyageManager.is_any_raider_on_player_node()


func is_animating() -> bool:
	return _is_ship_animating or _raiders_animating > 0 or _input_locked


func _get_player_display_offset(node_pos: Vector2) -> Vector2:
	if _both_on_same_node():
		return node_pos + Vector2(-SAME_NODE_SHIP_OFFSET, 0)
	return node_pos


## For a raider at the given node_pos, offset it only if it is on the player's current node.
func _get_raider_display_offset(node_pos: Vector2, is_on_player_node: bool = false) -> Vector2:
	if is_on_player_node:
		return node_pos + Vector2(SAME_NODE_SHIP_OFFSET, 0)
	return node_pos


func _update_raider_position_for_same_node(animated: bool = false) -> void:
	## When a raider and the player share a node, reposition that raider to standoff layout.
	## Needed when player jumps to the raider's node (raider doesn't move, so no raider_moved signal).
	if _raiders_animating > 0 or not _both_on_same_node():
		return
	var ambush_id = VoyageManager.get_ambushing_raider_id()
	if ambush_id == "" or not raider_visuals.has(ambush_id):
		return
	var raider_visual = raider_visuals[ambush_id]
	var raider_node = VoyageManager.nodes[ambush_id]
	if not raider_node:
		return
	var target_pos = _get_raider_display_offset(raider_node.position, true)
	const ROT_DURATION: float = 1.2
	if animated:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(raider_visual, "position", target_pos, ROT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var current_rot = raider_visual.rotation
		var diff = angle_difference(current_rot, PI)
		tween.tween_property(raider_visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		raider_visual.position = target_pos
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
	if not VoyageManager or not VoyageManager.is_raider_active:
		for ind in raider_indicators.values():
			ind.visible = false
		return

	# Track which raider IDs are still active so we can clean up stale indicators
	var active_ids := {}

	for rid in VoyageManager.raider_node_ids:
		if not VoyageManager.nodes.has(rid):
			continue
		active_ids[rid] = true

		# Create indicator if it doesn't exist yet
		if not raider_indicators.has(rid):
			var ind = RaiderIndicatorScene.instantiate()
			add_child(ind)
			raider_indicators[rid] = ind

		var raider_world_pos: Vector2
		if raider_visuals.has(rid):
			raider_world_pos = raider_visuals[rid].position
		else:
			raider_world_pos = VoyageManager.nodes[rid].position

		var raider_screen_pos := map_content.position + raider_world_pos * _current_zoom
		raider_indicators[rid].update_indicator(raider_screen_pos, size)

	# Remove indicators for raiders that no longer exist
	for rid in raider_indicators.keys():
		if not active_ids.has(rid):
			raider_indicators[rid].queue_free()
			raider_indicators.erase(rid)

	# Update detection circle brightness for all zones
	_update_raider_zone_brightness()


func _update_raider_zone_brightness() -> void:
	var in_zone := VoyageManager.is_player_in_raider_zone()
	for zone in raider_zone_visuals.values():
		if zone and zone.get("player_in_zone") != in_zone:
			zone.set("player_in_zone", in_zone)
			zone.queue_redraw()


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
	RaiderIndicatorScene = load("res://scenes/ui/raider_off_screen_indicator.tscn")

	# Remove the hardcoded RaiderIndicator node (now spawned dynamically)
	var old_indicator = get_node_or_null("RaiderIndicator")
	if old_indicator:
		old_indicator.queue_free()

	if story_indicator:
		story_indicator.set_indicator_color(StarMapNode.COLOR_STORY)

	# Create ship visual
	_create_ship_visual()
	
	# If raiders already exist (loaded save), restore all visuals
	for rid in VoyageManager.raider_node_ids:
		if VoyageManager.nodes.has(rid):
			var raider_node_data = VoyageManager.nodes[rid]
			_create_raider_zone_visual(rid, raider_node_data.position, VoyageManager.RAIDER_DETECTION_RADIUS)
			_create_raider_visual(rid, raider_node_data)
	
	# Fast travel disabled — green travel radius circle hidden
	# _create_player_travel_zone_visual()
	
	# Connect signals
	VoyageManager.map_updated.connect(refresh)
	VoyageManager.ship_moved.connect(_on_ship_moved)
	VoyageManager.ship_teleported.connect(_on_ship_teleported)
	GameState.fuel_changed.connect(func(_v): refresh())
	
	# Initial ship placement (must run BEFORE refresh so the ship is at the
	# correct position — otherwise refresh sees dist > 2 and spawns a slow
	# recenter tween that fights subsequent jump tweens).
	_update_ship_position(false)

	# Initial draw
	refresh()
	
	# Center view
	center_view_on_ship(false)
	
	# Show info for the starting node
	_update_node_info_panel()
	
	VoyageManager.story_node_spawned.connect(_on_story_node_spawned)
	VoyageManager.raider_spawned.connect(_on_raider_spawned)
	VoyageManager.raider_moved.connect(_on_raider_moved)
	VoyageManager.raider_destroyed.connect(_on_raider_destroyed)


func _on_raider_spawned(node_data: NodeData) -> void:
	_create_raider_zone_visual(node_data.id, node_data.position, VoyageManager.RAIDER_DETECTION_RADIUS)
	_create_raider_visual(node_data.id, node_data)
	refresh()
	_run_spawn_camera_sequence(node_data)

func _on_raider_moved(new_pos: Vector2, old_id: String, new_id: String) -> void:
	# Migrate the visual and zone to the new node_id key
	if raider_visuals.has(old_id):
		var visual = raider_visuals[old_id]
		raider_visuals.erase(old_id)
		raider_visuals[new_id] = visual

		_raiders_animating += 1
		if not visual.move_complete.is_connected(_on_raider_move_complete):
			visual.move_complete.connect(_on_raider_move_complete)

		var is_on_player_node = (new_id == VoyageManager.current_node_id)
		var display_pos = _get_raider_display_offset(new_pos, is_on_player_node)
		var target_rot = PI if is_on_player_node else -999.0
		visual.move_to(display_pos, new_id, 1.0, target_rot)

	if raider_indicators.has(old_id):
		var ind = raider_indicators[old_id]
		raider_indicators.erase(old_id)
		raider_indicators[new_id] = ind

	if raider_zone_visuals.has(old_id):
		var zone = raider_zone_visuals[old_id]
		raider_zone_visuals.erase(old_id)
		raider_zone_visuals[new_id] = zone
		var dist = zone.position.distance_to(new_pos)
		var duration = clampf(dist / 600.0, 0.5, 2.0)
		var tween = create_tween()
		tween.tween_property(zone, "position", new_pos, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	refresh()

func _on_raider_move_complete() -> void:
	_raiders_animating = max(0, _raiders_animating - 1)
	if _raiders_animating == 0:
		raider_animation_complete.emit()

func _on_raider_destroyed(destroyed_id: String) -> void:
	if raider_visuals.has(destroyed_id):
		raider_visuals[destroyed_id].queue_free()
		raider_visuals.erase(destroyed_id)
	if raider_zone_visuals.has(destroyed_id):
		raider_zone_visuals[destroyed_id].queue_free()
		raider_zone_visuals.erase(destroyed_id)
	if raider_indicators.has(destroyed_id):
		raider_indicators[destroyed_id].queue_free()
		raider_indicators.erase(destroyed_id)
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

	# 4. Emit finished signal
	tween.tween_callback(func():
		if is_story:
			VoyageManager.story_sequence_finished.emit()
		else:
			VoyageManager.raider_sequence_finished.emit()
	)

	# Unlock zoom 1s before the sequence ends (total = 5.0s, unlock at 4.0s)
	var unlock_tween = create_tween()
	unlock_tween.tween_interval(4.0)
	unlock_tween.tween_callback(func(): _input_locked = false)


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


func _create_raider_zone_visual(raider_id: String, origin: Vector2, radius: float) -> void:
	# Remove previous zone for this raider if it exists
	if raider_zone_visuals.has(raider_id):
		raider_zone_visuals[raider_id].queue_free()
	var zone = Node2D.new()
	zone.position = origin
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
	zone.set_script(script)
	zone.set("zone_radius", radius)
	map_content.add_child(zone)
	map_content.move_child(zone, 0)
	raider_zone_visuals[raider_id] = zone


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


func _create_raider_visual(raider_id: String, node_data: NodeData) -> void:
	if raider_visuals.has(raider_id):
		raider_visuals[raider_id].queue_free()

	var RaiderScene = load("res://scenes/map/raider_ship.tscn")
	if RaiderScene:
		var visual = RaiderScene.instantiate()
		ship_container.add_child(visual)
		var is_on_player_node = (raider_id == VoyageManager.current_node_id)
		visual.position = _get_raider_display_offset(node_data.position, is_on_player_node)
		raider_visuals[raider_id] = visual
		if is_on_player_node:
			const ROT_DURATION: float = 1.2
			var current_rot = visual.rotation
			var diff = angle_difference(current_rot, PI)
			if abs(diff) > 0.01:
				var rot_tween = create_tween()
				rot_tween.tween_property(visual, "rotation", current_rot + diff, ROT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				visual.rotation = PI

func refresh() -> void:
	_clear_visuals()
	_draw_nodes()
	_draw_connections()
	
	# Fast travel disabled — player travel zone update skipped
	# if player_travel_zone_visual:
	# 	player_travel_zone_visual.visible = not VoyageManager.is_player_in_raider_zone()
	# 	if player_travel_zone_visual.visible and not _is_ship_animating:
	# 		var current_node = VoyageManager.get_current_node()
	# 		if current_node:
	# 			player_travel_zone_visual.position = current_node.position
	
	# Ensure ship position is updated (smoothly recenter when raider leaves; instant on other updates)
	if not _is_ship_animating:
		var current_node = VoyageManager.get_current_node()
		if current_node:
			var display_center = _get_player_display_offset(current_node.position)
			var target_visual = display_center - Vector2(72, 72)
			var dist = 0.0
			if ship_visual:
				dist = ship_visual.position.distance_to(target_visual)
			# Smoothly animate when ship needs to recenter (e.g. raider left standoff).
			# Use a slow speed_mult so the short 50 px standoff gap glides over ~1s
			# instead of snapping in ~0.17s.
			if dist > 2.0:
				if _ship_recenter_tween and _ship_recenter_tween.is_valid():
					_ship_recenter_tween.kill()
				_ship_recenter_tween = _update_ship_position(true, current_node.position, 0.15, false)  # animate, no jump_complete emit
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
	
	# Check if any raider is ON the player's current node (ambush active)
	var raider_on_player_node = VoyageManager.is_any_raider_on_player_node()
	
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
		
		# Visited nodes are clickable for auto-path travel (hop-by-hop along visited path)
		var is_direct_travelable = is_reachable
		if not is_reachable and (node_data.state == NodeData.NodeState.VISITED or node_data.state == NodeData.NodeState.CLEARED):
			is_direct_travelable = true
		
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

## Enter wormhole selection mode: highlight eligible nodes.
func begin_wormhole_select_mode(eligible_ids: Array[String]) -> void:
	_wormhole_select_mode = true
	_wormhole_eligible_ids = eligible_ids
	for node_id in eligible_ids:
		if node_visuals.has(node_id):
			node_visuals[node_id].set_wormhole_selectable(true)


## Exit wormhole selection mode and clean up highlights.
func end_wormhole_select_mode() -> void:
	_wormhole_select_mode = false
	_wormhole_eligible_ids.clear()
	for visual in node_visuals.values():
		visual.set_wormhole_selectable(false)


func _gui_input(event: InputEvent) -> void:
	if not visible or _input_locked:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _wormhole_select_mode:
			end_wormhole_select_mode()
			wormhole_select_cancelled.emit()
			get_viewport().set_input_as_handled()
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
	if _wormhole_select_mode:
		if node_data.id in _wormhole_eligible_ids:
			end_wormhole_select_mode()
			wormhole_destination_selected.emit(node_data)
		return
	node_clicked.emit(node_data)

var _suppress_camera_follow: bool = false

func _on_ship_moved(new_pos: Vector2, node_data: NodeData, speed_mult: float = 1.0) -> void:
	_input_locked = true
	# Animate ship movement
	_update_ship_position(true, new_pos, speed_mult)

	# Fast travel disabled — player travel circle animation skipped
	# if player_travel_zone_visual:
	# 	var dist = player_travel_zone_visual.position.distance_to(new_pos)
	# 	var duration = maxf(dist / (BASE_SPEED_PPS * speed_mult), 0.1)
	# 	var tween = create_tween()
	# 	tween.tween_property(player_travel_zone_visual, "position", new_pos, duration) \
	# 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Animate camera centering (suppressed during auto-travel)
	if not _suppress_camera_follow:
		center_view_on_ship(true)

	_update_node_info_panel()


## Pan the camera smoothly to a world-space position without moving the ship.
func pan_to_world_pos(world_pos: Vector2, duration: float) -> void:
	var target = (size / 2.0) - (world_pos * _current_zoom)
	var tween = create_tween()
	tween.tween_property(map_content, "position", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


const TELEPORT_DURATION: float = 0.45  # demat 0.2s + materialize 0.25s

func _on_ship_teleported(new_pos: Vector2, _node_data: NodeData) -> void:
	_input_locked = true
	_is_ship_animating = true
	# Teleport: dematerialize -> snap to destination -> materialize (camera animates same as jump)
	_play_teleport_animation(new_pos)
	# Fast travel disabled — player travel circle teleport animation skipped
	# if player_travel_zone_visual:
	# 	var tween = create_tween()
	# 	tween.tween_property(player_travel_zone_visual, "position", new_pos, TELEPORT_DURATION) \
	# 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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

func _update_ship_position(animated: bool, target_pos: Vector2 = Vector2.ZERO, speed_mult: float = 1.0, emit_jump_complete: bool = true) -> Tween:
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
		# Kill any hit-shake tweens that animate ship_visual.position — if left
		# running they fight this tween and snap the ship back to the shake's
		# captured base_pos, causing an infinite recenter loop.
		if _player_hit_shake_tween:
			_player_hit_shake_tween.kill()
			_player_hit_shake_tween = null
		# Kill any lingering recenter tween so it doesn't fight the jump tween.
		if _ship_recenter_tween and _ship_recenter_tween.is_valid():
			_ship_recenter_tween.kill()
			_ship_recenter_tween = null

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
		return tween
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
	return null

func _play_teleport_animation(target_pos: Vector2) -> void:
	if not ship_visual:
		_create_ship_visual()
	_stop_ship_idle_pulse()
	# Reposition raider when player teleports to its node (smoothly animate to face player)
	_update_raider_position_for_same_node(true)
	var display_center = _get_player_display_offset(target_pos)
	var visual_pos = display_center - Vector2(72, 72)

	# Dematerialize: fade out + shrink in parallel (0.2s)
	var demat_tween = create_tween()
	demat_tween.set_parallel(true)
	demat_tween.tween_property(ship_visual, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	demat_tween.tween_property(ship_visual, "scale", Vector2(0.3, 0.3), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	demat_tween.tween_property(ship_visual, "rotation", 0.0, 0.2)

	# Wait for dematerialize to finish, then snap to destination
	demat_tween.set_parallel(false)
	demat_tween.tween_callback(func():
		ship_visual.position = visual_pos
		ship_visual.modulate.a = 0.0
		ship_visual.scale = Vector2(0.3, 0.3)
	)

	# Materialize: fade in + scale up in parallel (0.25s)
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
func play_raider_outcome_animation(success: bool, is_surrender: bool = false, raider_id: String = "") -> void:
	# If no specific raider given, use the one on the player's node (or first available)
	if raider_id == "":
		raider_id = VoyageManager.get_ambushing_raider_id()
	if raider_id == "" and not VoyageManager.raider_node_ids.is_empty():
		raider_id = VoyageManager.raider_node_ids[0]
	_outcome_raider_id = raider_id
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
		await _spawn_machine_gun_lasers(_get_player_center(), _get_raider_center(), true)
		await _play_raider_destruction()
		await get_tree().create_timer(0.3).timeout
	else:
		await get_tree().create_timer(0.5).timeout
		# Raider lurch fires in the background.
		# Machine-gun red lasers + player shake run in parallel,
		# then raider_attack_impact is emitted (hull damage applied by main.gd),
		# then the raider flies away.
		_start_raider_attack_lurch()
		await _spawn_machine_gun_lasers(_get_raider_center(), _get_player_center(), false)
		raider_attack_impact.emit()
		await _play_raider_fly_away()
		await get_tree().create_timer(0.3).timeout

	raider_outcome_animation_complete.emit()


## Center of the player ship visual in ship_container local space.
func _get_player_center() -> Vector2:
	if not ship_visual:
		return Vector2.ZERO
	return ship_visual.position + Vector2(72.0, 72.0)


## Center of the raider currently involved in an outcome animation.
func _get_raider_center() -> Vector2:
	if raider_visuals.has(_outcome_raider_id):
		return raider_visuals[_outcome_raider_id].position
	# Fallback: first available raider visual
	for visual in raider_visuals.values():
		if is_instance_valid(visual):
			return visual.position
	return Vector2.ZERO


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
	var visual = raider_visuals.get(_outcome_raider_id)
	if not visual or not visual.has_method("play_attack_animation"):
		return
	visual.play_attack_animation()
	await visual.attack_animation_complete


## Raider destruction sequence after player wins – spawns explosion VFX then
## delegates sprite fade to play_destruction_sequence().
func _play_raider_destruction() -> void:
	var visual = raider_visuals.get(_outcome_raider_id)
	if not visual or not visual.has_method("play_destruction_sequence"):
		return
	_spawn_explosion_vfx(visual.position)
	visual.play_destruction_sequence()
	await visual.destruction_complete


## Raider fly-away after defeat – delegates to play_fly_away().
func _play_raider_fly_away() -> void:
	var visual = raider_visuals.get(_outcome_raider_id)
	if not visual or not visual.has_method("play_fly_away"):
		return
	visual.play_fly_away()
	await visual.fly_away_complete


## Raider surrender depart – delegates to play_surrender_depart().
func _play_raider_surrender_depart() -> void:
	var visual = raider_visuals.get(_outcome_raider_id)
	if not visual or not visual.has_method("play_surrender_depart"):
		return
	visual.play_surrender_depart()
	await visual.surrender_depart_complete


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


## Fire a sustained machine-gun burst between the two ships.
## is_player=true  → gold beams, raider shakes (success path).
## is_player=false → red beams, player ship shakes (failure path).
## Each beam: appear 0.03s / hold 0.06s / fade 0.12s.
## Spawns a small impact explosion on every hit.
## Awaitable — resolves once the last beam has faded.
func _spawn_machine_gun_lasers(from_pos: Vector2, to_pos: Vector2, is_player: bool) -> void:
	var shots := 10
	var interval := 0.10  # seconds between shots
	for i in range(shots):
		if i > 0:
			await get_tree().create_timer(interval).timeout
		# Slight random spread per shot for a machine-gun feel
		var spread := Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
		_spawn_laser_beam(from_pos, to_pos + spread, is_player, true)
		if is_player:
			_hit_shake_raider()
		else:
			_hit_shake_player_ship()
		_spawn_impact_vfx(to_pos + spread)
	# Wait for the last beam to finish fading before returning
	await get_tree().create_timer(0.25).timeout


## Small two-stage impact burst spawned on each machine-gun hit.
## Smaller and faster than the final explosion — gives a chain-of-pops feel.
func _spawn_impact_vfx(center: Vector2) -> void:
	# Stage 1: Bright core pop
	var core := ColorRect.new()
	core.size = Vector2(20, 20)
	core.pivot_offset = Vector2(10, 10)
	core.position = center - Vector2(10, 10)
	core.color = Color(1.0, 0.9, 0.4, 1.0)
	ship_container.add_child(core)
	var t1 := core.create_tween()
	t1.tween_property(core, "scale", Vector2(2.8, 2.8), 0.08)
	t1.parallel().tween_property(core, "color", Color(1.0, 0.5, 0.1, 0.0), 0.18)
	t1.tween_callback(core.queue_free)

	# Stage 2: Small orange blast ring
	var blast := ColorRect.new()
	blast.size = Vector2(28, 28)
	blast.pivot_offset = Vector2(14, 14)
	blast.position = center - Vector2(14, 14)
	blast.color = Color(1.0, 0.35, 0.05, 0.7)
	ship_container.add_child(blast)
	var t2 := blast.create_tween()
	t2.tween_property(blast, "scale", Vector2(3.0, 3.0), 0.22)
	t2.parallel().tween_property(blast, "color:a", 0.0, 0.28)
	t2.tween_callback(blast.queue_free)


## Shake the raider sprite and flash it red-orange to sell each laser impact.
## Kills any in-progress shake/flash tweens first to avoid property conflicts.
func _hit_shake_raider() -> void:
	var raider_visual = raider_visuals.get(_outcome_raider_id)
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


## Shake the player ship and flash it red on each raider laser impact (failure path).
## Uses scale squish instead of position jitter so it never touches ship_visual.position
## and cannot fight _update_ship_position's position tween.
func _hit_shake_player_ship() -> void:
	if not ship_visual:
		return

	if _player_hit_shake_tween:
		_player_hit_shake_tween.kill()
	if _player_hit_flash_tween:
		_player_hit_flash_tween.kill()

	# Squish/stretch impact — doesn't touch position, no tween conflict
	var sx := randf_range(0.88, 0.94)
	var sy := 2.0 - sx  # opposite axis expands to preserve rough area
	_player_hit_shake_tween = ship_visual.create_tween()
	_player_hit_shake_tween.tween_property(ship_visual, "scale", Vector2(sx, sy), 0.04).set_ease(Tween.EASE_OUT)
	_player_hit_shake_tween.tween_property(ship_visual, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)

	_player_hit_flash_tween = ship_visual.create_tween()
	_player_hit_flash_tween.tween_property(ship_visual, "modulate", Color(1.9, 0.3, 0.3, 1.0), 0.03)
	_player_hit_flash_tween.tween_property(ship_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


## Start the raider lurch/recoil in the background (no await) so it plays
## alongside the machine-gun burst during the failure path.
func _start_raider_attack_lurch() -> void:
	var raider_visual = raider_visuals.get(_outcome_raider_id)
	if not raider_visual or not raider_visual.has_method("play_attack_animation"):
		return
	raider_visual.play_attack_animation()  # fire and forget — signal ignored here


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
