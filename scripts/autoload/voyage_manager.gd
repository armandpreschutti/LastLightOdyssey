extends Node

## Manager for the Voyage 2.0 Progressive Graph Map System
## Handles navigation, generation, and node state management

signal ship_moved(new_position: Vector2, node_data: NodeData, speed_mult: float)
signal map_updated
signal message_log_added(message: String)

# Core State
var current_node_id: String = ""
var nodes: Dictionary = {} # String (ID) -> NodeData
var generator: ProgressiveMapGenerator
var is_voyage_complete: bool = false

# Constants
const FUEL_COST_PER_JUMP: int = 1
const HULL_DAMAGE_NO_FUEL: int = 5

func _ready() -> void:
	generator = ProgressiveMapGenerator.new()
	# Ensure start node exists if no data loaded
	if nodes.is_empty():
		_initialize_voyage()

	# Connect to GameState signals to track voyage end
	GameState.game_over.connect(func(_reason): is_voyage_complete = true)
	GameState.game_won.connect(func(_type): is_voyage_complete = true)

## Initialize a new voyage
func _initialize_voyage() -> void:
	is_voyage_complete = false
	nodes.clear()
	var result = generator.generate_start_node()
	var start_node = result["start_node"]
	var initial_nodes = result["initial_nodes"]
	
	# Register nodes
	nodes[start_node.id] = start_node
	current_node_id = start_node.id
	
	for node in initial_nodes:
		nodes[node.id] = node
		
	map_updated.emit()

## Move the ship to a target node
## Returns true if move was successful
func attempt_jump(target_node: NodeData) -> bool:
	if is_voyage_complete:
		message_log_added.emit("Voyage has ended. Navigation systems offline.")
		return false

	if not target_node:
		return false
	
	# Validate connection (Must be connected to current node)
	var current_node = get_current_node()
	if not current_node:
		push_error("Current node not found during jump attempt!")
		return false
		
	if not target_node.id in current_node.connections:
		message_log_added.emit("Target is not connected to current position!")
		return false
	
	if target_node.id == current_node_id:
		# Same node (re-enter?)
		_enter_node(target_node)
		return true

	# Resource Check
	var fuel_cost = get_fuel_cost(target_node)
	# You can jump with 0 fuel, but it damages hull
	
	# Consume Resources
	if fuel_cost > 0:
		if GameState.fuel >= fuel_cost:
			GameState.fuel -= fuel_cost
		else:
			# Drift Mode
			GameState.fuel = 0
			GameState.damage_ship(HULL_DAMAGE_NO_FUEL)
			message_log_added.emit("WARNING: No Fuel! Drift jump damaged hull!")
	
	# Update Position
	var previous_node_id = current_node_id
	current_node_id = target_node.id
	
	# Mark Visited & Generate New Nodes
	if target_node.state == NodeData.NodeState.UNVISITED:
		target_node.state = NodeData.NodeState.VISITED
		_handle_arrival_generation(target_node, nodes[previous_node_id])
	
	ship_moved.emit(target_node.position, target_node, 1.0)
	map_updated.emit()

	# Phase 3: Injury recovery — reduce injury_jumps by 1 for each officer
	for key in GameState.officers:
		var od: OfficerData = GameState.get_officer(key)
		if od and od.injury_jumps > 0:
			od.injury_jumps -= 1

	return true


## Move the ship directly to a target visited node (skipping intermediates)
func attempt_direct_travel(target_node: NodeData, speed_mult: float = 1.25) -> bool:
	if is_voyage_complete:
		return false
		
	if not target_node:
		return false
		
	# Verify target is visited
	if target_node.state == NodeData.NodeState.UNVISITED:
		message_log_added.emit("Cannot direct travel to unvisited coordinates.")
		return false
		
	# Verify path exists (connectivity check)
	# We use find_path to ensure the node is actually reachable via the network
	var path = find_path(current_node_id, target_node.id)
	if path.size() <= 1:
		message_log_added.emit("Target is not reachable or is current position.")
		return false
		
	# Update Position immediately (teleport logic but with travel animation)
	current_node_id = target_node.id
	
	# Emit signal with speed multiplier
	ship_moved.emit(target_node.position, target_node, speed_mult)
	map_updated.emit()
	
	return true


## Calculate fuel cost to jump to a target node
func get_fuel_cost(target_node: NodeData) -> int:
	var current_node = get_current_node()
	if not current_node:
		return FUEL_COST_PER_JUMP
		
	# Check if this is a traveled path (amber line)
	if is_path_traveled(current_node, target_node):
		return 0
		
	return FUEL_COST_PER_JUMP


## Check if a path between two nodes has been traveled (visited and connected)
## Used for amber lines and 0 fuel cost
func is_path_traveled(node_a: NodeData, node_b: NodeData) -> bool:
	if not node_a or not node_b:
		return false
		
	# Both nodes must be visited (or cleared)
	if node_a.state == NodeData.NodeState.UNVISITED or node_b.state == NodeData.NodeState.UNVISITED:
		return false
		
	# Must have a parent-child relationship
	# Logic: If both are visited, and one is the parent of the other, it's a traveled path.
	if node_a.parent_id == node_b.id or node_b.parent_id == node_a.id:
		return true
		
	return false

## Generate new nodes upon arrival at a fresh node
func _handle_arrival_generation(target_node: NodeData, previous_node: NodeData) -> void:
	# Calculate direction vector
	var incoming_vector = target_node.position - previous_node.position
	
	# Generate new options
	var new_nodes = generator.generate_options(target_node, incoming_vector)
	
	# Register and link new nodes
	for node in new_nodes:
		nodes[node.id] = node
		# Connection logic is handled inside generator (bidirectional link)
		# Just need to make sure the target_node's connections are updated if not already done by reference?
		# GDScript objects are passed by reference, so modifying source_node.connections in generator works.

## Get current node data
func get_current_node() -> NodeData:
	if nodes.has(current_node_id):
		return nodes[current_node_id]
	return null

## Get all known/visible nodes
func get_visible_nodes() -> Array[NodeData]:
	var visible_nodes: Array[NodeData] = []
	for id in nodes:
		visible_nodes.append(nodes[id])
	return visible_nodes

## Find a path between two nodes using Breadth-First Search
## Only traverses VISITED or CLEARED nodes
## Returns an array of NodeData representing the path (including start and end)
func find_path(start_id: String, target_id: String) -> Array[NodeData]:
	if not nodes.has(start_id) or not nodes.has(target_id):
		return []
		
	if start_id == target_id:
		return [nodes[start_id]]
		
	var queue = [[start_id]]
	var visited = {start_id: true}
	
	while queue.size() > 0:
		var path = queue.pop_front()
		var current_id = path[-1]
		
		if current_id == target_id:
			# Convert IDs back to NodeData
			var node_path: Array[NodeData] = []
			for id in path:
				node_path.append(nodes[id])
			return node_path
			
		var current_node = nodes[current_id]
		for neighbor_id in current_node.connections:
			if not nodes.has(neighbor_id):
				continue
				
			var neighbor = nodes[neighbor_id]
			# Only traverse visited nodes (except target, though target should be visited too per requirement)
			var can_traverse = neighbor.state != NodeData.NodeState.UNVISITED
			
			if not visited.has(neighbor_id) and can_traverse:
				visited[neighbor_id] = true
				var new_path = path.duplicate()
				new_path.append(neighbor_id)
				queue.push_back(new_path)
				
	return [] # No path found

## Enter Logic (Trigger Event/Tactical)
func _enter_node(node: NodeData) -> void:
	# This would trigger the standard event processing
	# Delegation to EventManager for now?
	pass

#region Save/Load
func get_save_data() -> Dictionary:
	var nodes_data = {}
	for id in nodes:
		var node = nodes[id]
		# Serialize node
		nodes_data[id] = {
			"pos_x": node.position.x,
			"pos_y": node.position.y,
			"type": node.node_type,
			"biome": node.biome_type,
			"state": node.state,
			"connections": node.connections,
			"parent": node.parent_id,
			"new_earth": node.is_new_earth
		}
		
	return {
		"current_node_id": current_node_id,
		"nodes": nodes_data
	}

func load_save_data(data: Dictionary) -> void:
	nodes.clear()
	
	if data.has("current_node_id"):
		current_node_id = data["current_node_id"]
	
	if data.has("nodes"):
		var nodes_data = data["nodes"]
		for id in nodes_data:
			var n_data = nodes_data[id]
			var pos = Vector2(n_data["pos_x"], n_data["pos_y"])
			
			var node = NodeData.new(id, pos, int(n_data["type"]))
			node.biome_type = int(n_data["biome"])
			node.state = int(n_data["state"])
			node.connections.assign(n_data["connections"]) # Ensure typed array
			node.parent_id = n_data.get("parent", "")
			node.is_new_earth = n_data.get("new_earth", false)
			
			nodes[id] = node
#endregion
