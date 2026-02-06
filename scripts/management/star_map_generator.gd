class_name StarMapGenerator
extends RefCounted
## Generates a semi-linear node graph for the star map
## Creates 20 nodes arranged in columns with branching paths

const TOTAL_NODES = 20
const NUM_COLUMNS = 9

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
	# Column structure: [1, 2, 3, 3, 3, 2, 3, 2, 1]
	# This creates 20 nodes total with branching paths
	var column_sizes: Array[int] = [1, 2, 3, 3, 3, 2, 3, 2, 1]
	
	var node_id = 0
	for col_idx in range(NUM_COLUMNS):
		var nodes_in_column = column_sizes[col_idx]
		for row_idx in range(nodes_in_column):
			var node = MapNode.new(node_id, col_idx, row_idx)
			nodes.append(node)
			node_id += 1


## Create connections between nodes
func _create_connections() -> void:
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


## Create natural flowing connections between nodes
func _create_flow_connections(current_node: MapNode, next_column_nodes: Array[MapNode], nodes_in_current_col: int) -> void:
	var current_row = current_node.row
	var nodes_in_next_col = next_column_nodes.size()
	
	# Calculate which rows in the next column this node should connect to
	# Use proportional mapping to create natural flow
	var ratio = float(current_row) / max(1.0, float(nodes_in_current_col - 1))
	var target_row = int(ratio * float(nodes_in_next_col - 1))
	
	# Connect to target and possibly adjacent nodes
	current_node.connections.append(next_column_nodes[target_row].id)
	
	# Sometimes connect to adjacent nodes for more branching
	var num_connections = randi_range(1, 2)
	
	if num_connections >= 2:
		# Add one adjacent connection
		if target_row > 0 and randf() > 0.5:
			current_node.connections.append(next_column_nodes[target_row - 1].id)
		elif target_row < nodes_in_next_col - 1:
			current_node.connections.append(next_column_nodes[target_row + 1].id)


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
	
	# Node 19 (last node) is always New Earth (Empty Space - triggers win)
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
func _calculate_fuel_costs() -> void:
	for node in nodes:
		for connection_id in node.connections:
			var target_node = get_node(connection_id)
			if target_node:
				# Formula: fuel_cost = 1 + (target_column - source_column)
				# Since we only connect to next column, this will always be 1 + 1 = 2
				# But we can make it more interesting by varying based on row distance
				var column_distance = target_node.column - node.column
				var row_distance = abs(target_node.row - node.row)
				
				# Base cost is column distance, +1 for vertical movement
				var fuel_cost = 1 + column_distance
				if row_distance > 0:
					fuel_cost += 1  # Diagonal/vertical movement costs more
				
				node.connection_fuel_costs[connection_id] = fuel_cost


## Get the biome type for a node (returns -1 if not a scavenge site)
func get_node_biome(node_id: int) -> int:
	var node = get_node(node_id)
	if node:
		return node.biome_type
	return -1
