extends Control
## Star Map Controller - Displays the node graph and handles navigation
## Shows all 20 nodes with connections and manages visual states

signal node_clicked(node_id: int)

@onready var nodes_container: Control = $NodesContainer
@onready var lines_container: Control = $LinesContainer

var MapNodeScene: PackedScene
var node_graph: Array[StarMapGenerator.MapNode] = []
var node_visuals: Dictionary = {}  # node_id -> MapNode visual instance

const COLUMN_SPACING = 180.0
const ROW_SPACING = 120.0
const RANDOMNESS = 25.0  # Maximum random offset for node positions

const LINE_COLOR = Color(1.0, 0.69, 0.0, 0.25)  # Amber, transparent
const LINE_COLOR_ACTIVE = Color(1.0, 0.75, 0.0, 0.5)  # Brighter amber for active connections
const LINE_COLOR_DIMMED = Color(0.3, 0.3, 0.3, 0.15)  # Very dim for locked connections
const LINE_WIDTH = 2.0
const LINE_WIDTH_ACTIVE = 3.0

var map_center_offset: Vector2 = Vector2.ZERO  # Calculated to center the map


func _ready() -> void:
	MapNodeScene = load("res://scenes/management/map_node.tscn")


## Initialize the star map with generated node graph
func initialize(generator: StarMapGenerator) -> void:
	node_graph = generator.nodes
	_calculate_map_center()
	_create_visual_nodes()
	_draw_connection_lines()
	_update_node_states()


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
		if node_data.id != 0 and node_data.id != 19:
			var random_offset = Vector2(
				rng.randf_range(-RANDOMNESS, RANDOMNESS),
				rng.randf_range(-RANDOMNESS, RANDOMNESS)
			)
			pos += random_offset
		
		# Apply centering offset
		pos += map_center_offset
		
		# Offset by -35,-35 to center the 70x70 control node on the calculated position
		node_visual.position = pos - Vector2(35, 35)
		
		# Initialize the visual
		node_visual.initialize(node_data.id, node_data.node_type, _determine_initial_state(node_data.id))
		node_visual.clicked.connect(_on_node_clicked)
		
		node_visuals[node_data.id] = node_visual


## Calculate base world position for a node based on its column and row
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
	
	var x = column * COLUMN_SPACING
	var y = vertical_offset + row * ROW_SPACING
	
	return Vector2(x, y)


## Draw connection lines between nodes
func _draw_connection_lines() -> void:
	# Clear existing lines
	for child in lines_container.get_children():
		child.queue_free()
	
	# Draw lines for each connection
	for node_data in node_graph:
		var from_id = node_data.id
		var from_pos = node_visuals[from_id].position + Vector2(35, 35)  # Center of node
		
		for connection_id in node_data.connections:
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
	line.z_index = -1
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
	line.z_index = -1
	line.antialiased = true
	lines_container.add_child(line)
	
	# Create fuel cost label at midpoint
	var midpoint = (from + to) / 2.0
	var label = Label.new()
	label.text = "%d" % fuel_cost
	label.position = midpoint - Vector2(8, 12)  # Offset to center text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))  # Bright amber
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 14)
	label.z_index = 0
	lines_container.add_child(label)


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
