class_name StarMapGenerator
extends RefCounted
## Generates a semi-linear node graph for the star map
## Creates 50 nodes arranged in columns with branching paths

const TOTAL_NODES = 50
const NUM_COLUMNS = 16

# Node data structure
class MapNode:
	var id: int
	var column: int
	var row: int
	var connections: Array[int] = []  # IDs of nodes this connects to
	var node_type: int = -1  # EventManager.NodeType
	var biome_type: int = -1  # BiomeConfig.BiomeType (-1 if not a scavenge site)
	var connection_fuel_costs: Dictionary = {}  # Maps connection_id -> fuel_cost
	
	func _init(p_id: int, p_column: int, p_row: int) -> void:
		id = p_id
		column = p_column
		row = p_row

var nodes: Array[MapNode] = []


## Generate the complete node graph
func generate() -> Array[MapNode]:
	nodes.clear()
	_create_node_structure()
	_create_connections()
	_assign_node_types()
	_assign_biome_types()
	_calculate_fuel_costs()
	return nodes


## Create the node structure with semi-linear layout
func _create_node_structure() -> void:
	# Column structure: [1, 2, 3, 4, 4, 4, 4, 4, 4, 4, 3, 4, 3, 3, 2, 1]
	# This creates 50 nodes total with branching paths
	var column_sizes: Array[int] = [1, 2, 3, 4, 4, 4, 4, 4, 4, 4, 3, 4, 3, 3, 2, 1]
	
	var node_id = 0
	for col_idx in range(NUM_COLUMNS):
		var nodes_in_column = column_sizes[col_idx]
		for row_idx in range(nodes_in_column):
			var node = MapNode.new(node_id, col_idx, row_idx)
			nodes.append(node)
			node_id += 1


## Create connections between nodes
## Only creates connections between adjacent columns (no skipping nodes)
func _create_connections() -> void:
	# First, create forward connections (primary path)
	_create_forward_connections()
	
	# Then, create backward connections (secondary paths)
	_create_backward_connections()
	
	# Validate and repair to ensure no dead end nodes exist
	_validate_and_repair_connections()


## Create forward connections (to next column)
func _create_forward_connections() -> void:
	for i in range(nodes.size()):
		var current_node = nodes[i]
		var current_col = current_node.column
		
		# Don't connect the last column (New Earth)
		if current_col >= NUM_COLUMNS - 1:
			continue
		
		# Find nodes in the next column
		var next_column_nodes: Array[MapNode] = []
		for node in nodes:
			if node.column == current_col + 1:
				next_column_nodes.append(node)
		
		if next_column_nodes.is_empty():
			continue
		
		# Connect to 1-3 nodes in next column based on position
		var current_row = current_node.row
		var nodes_in_current_col = _count_nodes_in_column(current_col)
		var nodes_in_next_col = next_column_nodes.size()
		
		# Determine connection strategy based on relative positions
		if nodes_in_current_col == 1:
			# Single node connects to all in next column
			for next_node in next_column_nodes:
				current_node.connections.append(next_node.id)
		elif nodes_in_next_col == 1:
			# All connect to single node
			current_node.connections.append(next_column_nodes[0].id)
		else:
			# Create natural flow connections
			_create_flow_connections(current_node, next_column_nodes, nodes_in_current_col)


## Create backward connections (to previous column only - adjacent nodes)
func _create_backward_connections() -> void:
	for i in range(nodes.size()):
		var current_node = nodes[i]
		var current_col = current_node.column
		
		# Don't add backward connections from start node (node 0) or last node (New Earth)
		if current_node.id == 0 or current_node.id == TOTAL_NODES - 1:
			continue
		
		# Don't add backward connections from first column
		if current_col <= 0:
			continue
		
		# Reduced chance to 30% for fewer connections
		if randf() > 0.30:
			continue
		
		# Only connect to immediately previous column (adjacent nodes only)
		var target_col = current_col - 1
		
		# Find nodes in the previous column
		var prev_column_nodes: Array[MapNode] = []
		for node in nodes:
			if node.column == target_col:
				prev_column_nodes.append(node)
		
		if prev_column_nodes.is_empty():
			continue
		
		# Connect to 1 node in previous column (reduced from 1-2)
		var nodes_in_prev_col = prev_column_nodes.size()
		
		# Use similar flow logic for backward connections
		var current_row = current_node.row
		var nodes_in_current_col = _count_nodes_in_column(current_col)
		
		# Calculate target row in previous column
		var ratio = float(current_row) / max(1.0, float(nodes_in_current_col - 1))
		var target_row = int(ratio * float(nodes_in_prev_col - 1))
		
		# Connect to target node (avoid duplicates)
		var target_id = prev_column_nodes[target_row].id
		if not target_id in current_node.connections:
			current_node.connections.append(target_id)


## Create natural flowing connections between nodes
## Only connects to adjacent column (next column)
func _create_flow_connections(current_node: MapNode, next_column_nodes: Array[MapNode], nodes_in_current_col: int) -> void:
	var current_row = current_node.row
	var nodes_in_next_col = next_column_nodes.size()
	
	# Calculate which rows in the next column this node should connect to
	# Use proportional mapping to create natural flow
	var ratio = float(current_row) / max(1.0, float(nodes_in_current_col - 1))
	var target_row = int(ratio * float(nodes_in_next_col - 1))
	
	# Connect to target node (guaranteed first connection)
	current_node.connections.append(next_column_nodes[target_row].id)
	
	# Enhanced connections: 2-3 connections per node (increased from 1-2)
	var num_connections = randi_range(2, 3)
	
	# Add additional connections up to the target number
	var connections_added = 1
	var available_indices: Array[int] = []
	
	# Collect available adjacent indices
	if target_row > 0:
		available_indices.append(target_row - 1)
	if target_row < nodes_in_next_col - 1:
		available_indices.append(target_row + 1)
	
	# Shuffle to add variety
	available_indices.shuffle()
	
	# Add connections until we reach the target number or run out of options
	for idx in available_indices:
		if connections_added >= num_connections:
			break
		var connection_id = next_column_nodes[idx].id
		if not connection_id in current_node.connections:
			current_node.connections.append(connection_id)
			connections_added += 1


## Validate and repair connections to ensure no dead end nodes
## Every node (except first and last) must have at least one incoming and one outgoing connection
func _validate_and_repair_connections() -> void:
	# Check and repair outgoing connections (every node except last must have at least 1)
	for node in nodes:
		# Last node (New Earth) doesn't need outgoing connections
		if node.id == TOTAL_NODES - 1:
			continue
		
		# Check if node has any outgoing connections
		if node.connections.is_empty():
			# Add connection to next column
			var next_col = node.column + 1
			if next_col < NUM_COLUMNS:
				var next_column_nodes = get_nodes_in_column(next_col)
				if not next_column_nodes.is_empty():
					# Use flow logic to determine best connection
					var nodes_in_current_col = _count_nodes_in_column(node.column)
					_create_flow_connections(node, next_column_nodes, nodes_in_current_col)
	
	# Build reverse connection map to check incoming connections
	# (Rebuild after outgoing repairs to include newly added connections)
	var incoming_connections: Dictionary = {}  # node_id -> Array of nodes that connect to it
	for node in nodes:
		incoming_connections[node.id] = []
	
	# Populate incoming connections map
	for node in nodes:
		for connection_id in node.connections:
			if incoming_connections.has(connection_id):
				incoming_connections[connection_id].append(node.id)
	
	# Check and repair incoming connections (every node except first must have at least 1)
	for node in nodes:
		# First node (start) doesn't need incoming connections
		if node.id == 0:
			continue
		
		# Check if node has any incoming connections
		if incoming_connections[node.id].is_empty():
			# Add connection from previous column
			var prev_col = node.column - 1
			if prev_col >= 0:
				var prev_column_nodes = get_nodes_in_column(prev_col)
				if not prev_column_nodes.is_empty():
					# Find a node in previous column to connect from
					# Use flow logic to determine best source node
					var nodes_in_prev_col = prev_column_nodes.size()
					var nodes_in_current_col = _count_nodes_in_column(node.column)
					
					# Calculate which node in previous column should connect to this one
					var ratio = float(node.row) / max(1.0, float(nodes_in_current_col - 1))
					var source_row = int(ratio * float(nodes_in_prev_col - 1))
					
					var source_node = prev_column_nodes[source_row]
					# Only add connection if source node is not the last node (last node shouldn't have outgoing connections)
					# Add connection if not already present
					if source_node.id != TOTAL_NODES - 1 and not node.id in source_node.connections:
						source_node.connections.append(node.id)


## Count how many nodes are in a given column
func _count_nodes_in_column(column: int) -> int:
	var count = 0
	for node in nodes:
		if node.column == column:
			count += 1
	return count


## Assign node types to each node (pre-roll for consistency)
func _assign_node_types() -> void:
	# Node 0 is always the starting node (Empty Space)
	nodes[0].node_type = EventManager.NodeType.EMPTY_SPACE
	
	# Last node is always New Earth (Empty Space - triggers win)
	nodes[TOTAL_NODES - 1].node_type = EventManager.NodeType.EMPTY_SPACE
	
	# Assign types to remaining nodes with weighted distribution
	for i in range(1, TOTAL_NODES - 1):
		nodes[i].node_type = _roll_node_type()


## Roll a random node type using EventManager's weighting
func _roll_node_type() -> int:
	var roll = randi_range(1, 10)
	if roll <= 4:
		return EventManager.NodeType.EMPTY_SPACE
	elif roll <= 8:
		return EventManager.NodeType.SCAVENGE_SITE
	else:
		return EventManager.NodeType.TRADING_OUTPOST


## Assign biome types to scavenge site nodes
func _assign_biome_types() -> void:
	# Track biome distribution to ensure variety
	var biome_counts := {
		BiomeConfig.BiomeType.STATION: 0,
		BiomeConfig.BiomeType.ASTEROID: 0,
		BiomeConfig.BiomeType.PLANET: 0,
	}
	
	var scavenge_nodes: Array[MapNode] = []
	for node in nodes:
		if node.node_type == EventManager.NodeType.SCAVENGE_SITE:
			scavenge_nodes.append(node)
	
	# Assign biomes with some variety balancing
	for node in scavenge_nodes:
		node.biome_type = _roll_biome_type(biome_counts)
		biome_counts[node.biome_type] += 1


## Roll a biome type with slight balancing to ensure variety
func _roll_biome_type(current_counts: Dictionary) -> int:
	# Find the least used biome type
	var min_count = 999
	var min_biomes: Array[int] = []
	
	for biome_type in current_counts.keys():
		var count = current_counts[biome_type]
		if count < min_count:
			min_count = count
			min_biomes = [biome_type]
		elif count == min_count:
			min_biomes.append(biome_type)
	
	# 50% chance to pick from least used, 50% random
	if randf() < 0.5 and min_biomes.size() > 0:
		return min_biomes[randi() % min_biomes.size()]
	else:
		return BiomeConfig.get_random_biome()


## Get a specific node by ID
func get_node(node_id: int) -> MapNode:
	if node_id >= 0 and node_id < nodes.size():
		return nodes[node_id]
	return null


## Get all nodes in a specific column
func get_nodes_in_column(column: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node in nodes:
		if node.column == column:
			result.append(node)
	return result


## Calculate fuel costs for all connections based on distance
## All connections are now adjacent (column distance = 1), so base cost is simpler
func _calculate_fuel_costs() -> void:
	for node in nodes:
		for connection_id in node.connections:
			var target_node = get_node(connection_id)
			if target_node:
				var column_distance = target_node.column - node.column
				var row_distance = abs(target_node.row - node.row)
				
				# Determine if this is a backward connection
				var is_backward = column_distance < 0
				
				# Since all connections are adjacent, base cost is 2 (increased from 1)
				# (column distance should always be 1 or -1)
				var fuel_cost = 2
				
				# Add penalty for row distance (diagonal/vertical movement)
				if row_distance > 0:
					fuel_cost += 2  # Increased from +1 to +2
				
				# Add penalty for backward connections (going backward is less efficient)
				if is_backward:
					fuel_cost += 4  # Increased from +2 to +4 fuel penalty for backward travel
				
				node.connection_fuel_costs[connection_id] = fuel_cost


## Get the biome type for a node (returns -1 if not a scavenge site)
func get_node_biome(node_id: int) -> int:
	var node = get_node(node_id)
	if node:
		return node.biome_type
	return -1


## Check if a node is the New Earth node (last node)
func is_new_earth_node(node_id: int) -> bool:
	return node_id == TOTAL_NODES - 1
