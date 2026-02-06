extends Control
## Star Map Controller - Displays the node graph and handles navigation
## Shows all 50 nodes with connections and manages visual states

signal node_clicked(node_id: int)
signal jump_animation_complete

@onready var map_content: Control = $MapContent
@onready var nodes_container: Control = $MapContent/NodesContainer
@onready var lines_container: Control = $MapContent/LinesContainer
@onready var ship_container: Control = $MapContent/ShipContainer

var MapNodeScene: PackedScene
var node_graph: Array[StarMapGenerator.MapNode] = []
var node_visuals: Dictionary = {}  # node_id -> MapNode visual instance
var generator: StarMapGenerator = null  # Reference to generator for helper methods

const COLUMN_SPACING = 180.0  # Horizontal spacing between columns
const ROW_SPACING = 200.0  # Vertical spacing between rows
const RANDOMNESS = 25.0  # Maximum random offset for node positions

const LINE_COLOR = Color(1.0, 0.69, 0.0, 0.25)  # Amber, transparent
const LINE_COLOR_ACTIVE = Color(1.0, 0.75, 0.0, 0.5)  # Brighter amber for active connections
const LINE_COLOR_DIMMED = Color(0.3, 0.3, 0.3, 0.15)  # Very dim for locked connections
const LINE_WIDTH = 2.0
const LINE_WIDTH_ACTIVE = 3.0

var map_center_offset: Vector2 = Vector2.ZERO  # Calculated to center the map

# Panning variables
var _is_panning: bool = false
var _pan_start_pos: Vector2 = Vector2.ZERO
var _content_start_pos: Vector2 = Vector2.ZERO

# Zoom variables
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0
const ZOOM_STEP = 0.1
var _current_zoom: float = 1.0

# Camera centering variables
var _camera_tween: Tween = null
const CAMERA_ANIMATION_DURATION = 0.8  # seconds

# Ship animation variables
var _ship_sprite: Control = null
var _ship_tween: Tween = null
const SHIP_ANIMATION_DURATION = 1.5  # seconds


func _ready() -> void:
	MapNodeScene = load("res://scenes/management/map_node.tscn")


## Handle input for panning the map (right-click or middle-click drag)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start_pos = event.position
				_content_start_pos = map_content.position
			else:
				_is_panning = false
		# Mouse wheel zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(event.position, -ZOOM_STEP)
	
	if event is InputEventMouseMotion and _is_panning:
		var delta = event.position - _pan_start_pos
		map_content.position = _content_start_pos + delta


## Zoom the map at the given screen position
func _zoom_at_point(screen_pos: Vector2, zoom_delta: float) -> void:
	var old_zoom = _current_zoom
	_current_zoom = clamp(_current_zoom + zoom_delta, MIN_ZOOM, MAX_ZOOM)
	
	if old_zoom == _current_zoom:
		return
	
	# Calculate the point in map content space before zoom
	var local_pos = (screen_pos - map_content.position) / old_zoom
	
	# Apply new scale
	map_content.scale = Vector2(_current_zoom, _current_zoom)
	
	# Adjust position so the point under the mouse stays fixed
	map_content.position = screen_pos - local_pos * _current_zoom


## Initialize the star map with generated node graph
func initialize(generator: StarMapGenerator) -> void:
	# Clear any existing map artifacts from previous voyage
	_clear_existing_map()
	
	self.generator = generator
	node_graph = generator.nodes
	_calculate_map_center()
	_create_visual_nodes()
	_draw_connection_lines()
	_update_node_states()
	
	# Center camera on first node (node 0) when voyage starts (instant, no animation)
	center_on_node(0, false)


## Clear all existing visual elements from the map
func _clear_existing_map() -> void:
	# Clear all visual node instances
	for child in nodes_container.get_children():
		child.queue_free()
	node_visuals.clear()
	
	# Clear all connection lines and labels
	for child in lines_container.get_children():
		child.queue_free()
	
	# Clean up ship animation
	_cleanup_ship_animation()


## Calculate the center offset to center the map on screen
func _calculate_map_center() -> void:
	# Find bounds of the map
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for node_data in node_graph:
		var pos = _calculate_base_node_position(node_data)
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	# Calculate center of the map
	var map_size := max_pos - min_pos
	var map_center := min_pos + map_size / 2.0
	
	# Center on screen
	var screen_center := size / 2.0
	map_center_offset = screen_center - map_center


## Create visual instances for all nodes
func _create_visual_nodes() -> void:
	# Seed RNG with a consistent value for reproducible randomness
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent layout
	
	for node_data in node_graph:
		var node_visual = MapNodeScene.instantiate()
		nodes_container.add_child(node_visual)
		
		# Calculate base position
		var pos = _calculate_base_node_position(node_data)
		
		# Add random offset for organic feel (but not to START or NEW EARTH nodes)
		var is_start_node = node_data.id == 0
		var is_new_earth = generator != null and generator.is_new_earth_node(node_data.id)
		if not is_start_node and not is_new_earth:
			var random_offset = Vector2(
				rng.randf_range(-RANDOMNESS, RANDOMNESS),
				rng.randf_range(-RANDOMNESS, RANDOMNESS)
			)
			pos += random_offset
		
		# Apply centering offset
		pos += map_center_offset
		
		# Offset by -35,-35 to center the 70x70 control node on the calculated position
		node_visual.position = pos - Vector2(35, 35)
		
		# Initialize the visual (include biome type for scavenge sites and New Earth flag)
		# Reuse is_new_earth variable declared above
		node_visual.initialize(node_data.id, node_data.node_type, _determine_initial_state(node_data.id), node_data.biome_type, is_new_earth)
		node_visual.clicked.connect(_on_node_clicked)
		
		node_visuals[node_data.id] = node_visual


## Calculate base world position for a node based on its column and row
## Uses a mix of vertical and circular/spiral layout
func _calculate_base_node_position(node_data: StarMapGenerator.MapNode) -> Vector2:
	var column = node_data.column
	var row = node_data.row
	
	# Count nodes in this column to center them
	var nodes_in_column = 0
	for n in node_graph:
		if n.column == column:
			nodes_in_column += 1
	
	# Center the nodes vertically within the column
	var vertical_offset = -(nodes_in_column - 1) * ROW_SPACING / 2.0
	var base_y = vertical_offset + row * ROW_SPACING
	
	# Base column-based X position
	var base_x = column * COLUMN_SPACING
	
	# Add circular/spiral component for more organic layout
	# Spiral radius increases with column
	var spiral_radius = column * 40.0
	# Angle based on column position (creates spiral pattern)
	var angle = column * 0.3
	
	# Mix the spiral offset with the base position
	# Use spiral for Y offset, keep X mostly column-based with slight spiral
	var spiral_x_offset = spiral_radius * cos(angle) * 0.3  # Subtle X spiral
	var spiral_y_offset = spiral_radius * sin(angle) * 0.5  # More pronounced Y spiral
	
	# Combine base position with spiral offset
	var x = base_x + spiral_x_offset
	var y = base_y + spiral_y_offset
	
	return Vector2(x, y)


## Draw connection lines between nodes
func _draw_connection_lines() -> void:
	# Clear existing lines
	for child in lines_container.get_children():
		child.queue_free()
	
	# Track drawn connections to avoid duplicates
	var drawn_connections: Dictionary = {}  # "from_id:to_id" -> true
	
	# Draw lines for each connection
	for node_data in node_graph:
		var from_id = node_data.id
		var from_pos = node_visuals[from_id].position + Vector2(35, 35)  # Center of node
		
		for connection_id in node_data.connections:
			# Only draw each connection once (avoid duplicates from bidirectional connections)
			var connection_key = "%d:%d" % [min(from_id, connection_id), max(from_id, connection_id)]
			if drawn_connections.has(connection_key):
				continue
			drawn_connections[connection_key] = true
			
			if node_visuals.has(connection_id):
				var to_pos = node_visuals[connection_id].position + Vector2(35, 35)  # Center of node
				var fuel_cost = node_data.connection_fuel_costs.get(connection_id, 1)
				
				# Only draw connections from current/available nodes
				var from_state = _determine_initial_state(from_id)
				if from_state == StarMapNode.NodeState.CURRENT or from_state == StarMapNode.NodeState.AVAILABLE:
					_draw_line_with_label(from_pos, to_pos, fuel_cost)
				else:
					# Draw dimmer line for locked connections
					_draw_line(from_pos, to_pos, true)


## Draw a single connection line
func _draw_line(from: Vector2, to: Vector2, dimmed: bool = false) -> void:
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.default_color = LINE_COLOR if not dimmed else LINE_COLOR_DIMMED
	line.width = LINE_WIDTH
	line.antialiased = true
	lines_container.add_child(line)


## Draw a connection line with fuel cost label
func _draw_line_with_label(from: Vector2, to: Vector2, fuel_cost: int) -> void:
	# Draw the line
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.default_color = LINE_COLOR_ACTIVE
	line.width = LINE_WIDTH_ACTIVE
	line.antialiased = true
	lines_container.add_child(line)
	
	# Calculate offset perpendicular to the line for cleaner label placement
	var midpoint = (from + to) / 2.0
	var direction = (to - from).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # Rotate 90 degrees
	var label_offset = perpendicular * 14.0  # Offset distance from line
	
	# Create fuel cost badge container
	var badge = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Style the badge
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(1.0, 0.69, 0.0, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", style)
	
	# Create fuel cost label
	var label = Label.new()
	label.text = "%d" % fuel_cost
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	
	# Position the badge offset from the line
	badge.position = midpoint + label_offset - Vector2(12, 10)
	lines_container.add_child(badge)


## Determine initial state for a node
func _determine_initial_state(node_id: int) -> int:
	if node_id == GameState.current_node_index:
		return StarMapNode.NodeState.CURRENT
	elif node_id < GameState.current_node_index or GameState.visited_nodes.has(node_id):
		return StarMapNode.NodeState.VISITED
	elif _is_node_reachable(node_id):
		return StarMapNode.NodeState.AVAILABLE
	else:
		return StarMapNode.NodeState.LOCKED


## Check if a node is reachable from current position
func _is_node_reachable(node_id: int) -> bool:
	var current_node_id = GameState.current_node_index
	
	# Find the current node in the graph
	var current_node: StarMapGenerator.MapNode = null
	for node_data in node_graph:
		if node_data.id == current_node_id:
			current_node = node_data
			break
	
	if not current_node:
		return false
	
	# Check if node_id is in the connections
	return node_id in current_node.connections


## Update all node visual states
func _update_node_states() -> void:
	for node_id in node_visuals.keys():
		var node_visual = node_visuals[node_id]
		var new_state = _determine_initial_state(node_id)
		node_visual.set_state(new_state)


## Handle node click
func _on_node_clicked(node_id: int) -> void:
	print("StarMap: Node %d clicked" % node_id)
	print("StarMap: Current node: %d" % GameState.current_node_index)
	print("StarMap: Is reachable: %s" % _is_node_reachable(node_id))
	
	if _is_node_reachable(node_id):
		print("StarMap: Emitting node_clicked signal for node %d" % node_id)
		node_clicked.emit(node_id)
	else:
		print("StarMap: Node %d is not reachable!" % node_id)


## Refresh the map after a jump
func refresh() -> void:
	_update_node_states()
	_draw_connection_lines()  # Redraw lines to show new available connections
	
	# Center camera on the current node after jump
	center_on_node(GameState.current_node_index, true)


## Get the node type for a specific node ID
func get_node_type(node_id: int) -> int:
	for node_data in node_graph:
		if node_data.id == node_id:
			return node_data.node_type
	return EventManager.NodeType.EMPTY_SPACE


## Get fuel cost to jump from current node to target node
func get_fuel_cost(from_node_id: int, to_node_id: int) -> int:
	for node_data in node_graph:
		if node_data.id == from_node_id:
			return node_data.connection_fuel_costs.get(to_node_id, 1)
	return 1  # Default cost


## Get biome type for a specific node ID
func get_node_biome(node_id: int) -> int:
	for node_data in node_graph:
		if node_data.id == node_id:
			return node_data.biome_type
	return -1  # Not a scavenge site or invalid


## Center the camera/view on a specific node
func center_on_node(node_id: int, animated: bool = true) -> void:
	if not node_visuals.has(node_id):
		return
	
	var node_visual = node_visuals[node_id]
	# Get the node's center position in map content space
	var node_center = node_visual.position + Vector2(35, 35)  # Node is 70x70, center is at 35,35
	
	# Calculate the target position for map_content to center this node on screen
	var screen_center = size / 2.0
	var target_content_pos = screen_center - node_center * _current_zoom
	
	if animated:
		# Stop any existing camera tween
		if _camera_tween:
			_camera_tween.kill()
		
		# Create new tween for smooth animation
		_camera_tween = create_tween()
		_camera_tween.set_ease(Tween.EASE_IN_OUT)
		_camera_tween.set_trans(Tween.TRANS_CUBIC)
		_camera_tween.tween_property(map_content, "position", target_content_pos, CAMERA_ANIMATION_DURATION)
	else:
		# Instant snap
		map_content.position = target_content_pos


## Animate ship jumping from one node to another
func animate_jump(from_node_id: int, to_node_id: int) -> void:
	if not node_visuals.has(from_node_id) or not node_visuals.has(to_node_id):
		return
	
	# Clean up any existing ship animation
	_cleanup_ship_animation()
	
	# Get start and end positions (node centers)
	var from_node = node_visuals[from_node_id]
	var to_node = node_visuals[to_node_id]
	var start_pos = from_node.position + Vector2(35, 35)
	var end_pos = to_node.position + Vector2(35, 35)
	
	# Create ship sprite container
	_ship_sprite = Control.new()
	ship_container.add_child(_ship_sprite)
	_ship_sprite.position = start_pos - Vector2(20, 16)  # Center the ship
	_ship_sprite.custom_minimum_size = Vector2(40, 32)
	
	# Ship design matching event scenes (blocky pixel-art style)
	var px = 2.0  # Pixel size for retro look (scaled down from event scenes)
	var ship_color = Color(0.3, 0.35, 0.4)  # Dark gray ship body
	var detail_color = Color(0.4, 0.9, 1.0, 0.8)  # Cyan accent for windows/glow
	var engine_color = Color(1.0, 0.69, 0.0, 0.8)  # Amber engine glow
	
	# Main hull (24px wide, 6px tall in event scenes, scaled)
	var hull = ColorRect.new()
	hull.size = Vector2(24*px, 6*px)
	hull.color = ship_color
	hull.position = Vector2(8*px, 13*px)  # Offset to center
	_ship_sprite.add_child(hull)
	
	# Nose (pointed front)
	var nose1 = ColorRect.new()
	nose1.size = Vector2(8*px, 4*px)
	nose1.color = ship_color
	nose1.position = Vector2(32*px, 14*px)
	_ship_sprite.add_child(nose1)
	
	var nose2 = ColorRect.new()
	nose2.size = Vector2(4*px, 2*px)
	nose2.color = ship_color
	nose2.position = Vector2(40*px, 15*px)
	_ship_sprite.add_child(nose2)
	
	# Top wing
	var top_wing = ColorRect.new()
	top_wing.size = Vector2(12*px, 3*px)
	top_wing.color = ship_color
	top_wing.position = Vector2(10*px, 5*px)
	_ship_sprite.add_child(top_wing)
	
	# Bottom wing
	var bottom_wing = ColorRect.new()
	bottom_wing.size = Vector2(12*px, 3*px)
	bottom_wing.color = ship_color
	bottom_wing.position = Vector2(10*px, 24*px)
	_ship_sprite.add_child(bottom_wing)
	
	# Engine glow (rear)
	var engine1 = ColorRect.new()
	engine1.size = Vector2(3*px, 4*px)
	engine1.color = engine_color
	engine1.position = Vector2(2*px, 14*px)
	_ship_sprite.add_child(engine1)
	
	var engine2 = ColorRect.new()
	engine2.size = Vector2(3*px, 2*px)
	engine2.color = Color(1.0, 0.85, 0.3, 0.9)  # Brighter engine core
	engine2.position = Vector2(-1*px, 15*px)
	_ship_sprite.add_child(engine2)
	
	# Windows (three small windows along the hull)
	var window1 = ColorRect.new()
	window1.size = Vector2(2*px, 2*px)
	window1.color = detail_color
	window1.position = Vector2(24*px, 15*px)
	_ship_sprite.add_child(window1)
	
	var window2 = ColorRect.new()
	window2.size = Vector2(2*px, 2*px)
	window2.color = detail_color
	window2.position = Vector2(16*px, 15*px)
	_ship_sprite.add_child(window2)
	
	var window3 = ColorRect.new()
	window3.size = Vector2(2*px, 2*px)
	window3.color = detail_color
	window3.position = Vector2(12*px, 15*px)
	_ship_sprite.add_child(window3)
	
	# Add a subtle glow effect behind the ship
	var glow = ColorRect.new()
	glow.size = Vector2(48*px, 40*px)
	glow.color = Color(0.4, 0.6, 1.0, 0.3)  # Blue glow
	glow.position = Vector2(-4*px, -4*px)
	_ship_sprite.add_child(glow)
	glow.z_index = -1
	
	# Calculate direction and rotation
	var direction = (end_pos - start_pos).normalized()
	var angle = atan2(direction.y, direction.x)
	_ship_sprite.rotation = angle
	
	# Animate ship along the line
	_ship_tween = create_tween()
	_ship_tween.set_ease(Tween.EASE_IN_OUT)
	_ship_tween.set_trans(Tween.TRANS_QUART)
	
	# Animate position
	var target_pos = end_pos - Vector2(16, 16)
	_ship_tween.tween_property(_ship_sprite, "position", target_pos, SHIP_ANIMATION_DURATION)
	
	# Add a subtle scale pulse during animation
	var original_scale = Vector2(1.0, 1.0)
	_ship_tween.parallel().tween_property(_ship_sprite, "scale", original_scale * 1.2, SHIP_ANIMATION_DURATION * 0.5)
	_ship_tween.parallel().tween_property(_ship_sprite, "scale", original_scale, SHIP_ANIMATION_DURATION * 0.5).set_delay(SHIP_ANIMATION_DURATION * 0.5)
	
	# Clean up when animation completes and emit signal
	_ship_tween.tween_callback(_on_ship_animation_complete)


## Called when ship animation completes
func _on_ship_animation_complete() -> void:
	_cleanup_ship_animation()
	jump_animation_complete.emit()


## Clean up ship animation
func _cleanup_ship_animation() -> void:
	if _ship_tween:
		_ship_tween.kill()
		_ship_tween = null
	
	if _ship_sprite:
		_ship_sprite.queue_free()
		_ship_sprite = null
