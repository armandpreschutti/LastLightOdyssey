class_name ProgressiveMapGenerator
extends RefCounted

## Procedurally generates map nodes in a directed graph
## Spawns nodes progressively as the player travels
## Ensures forward movement by spawning nodes away from the previous node

const MIN_DISTANCE: float = 300.0
const MAX_DISTANCE: float = 500.0
const SPREAD_ANGLE: float = 60.0 # Degrees
const NODE_COUNT_MIN: int = 2
const NODE_COUNT_MAX: int = 3
const NOISE_SEED = 12345

var rng: RandomNumberGenerator

func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = NOISE_SEED

## Generate the initial start node and its first connections
func generate_start_node() -> Dictionary: # Returns { "start_node": NodeData, "initial_nodes": Array[NodeData] }
	var start_node = NodeData.new(generate_uuid(), Vector2.ZERO, EventManager.NodeType.EMPTY_SPACE)
	start_node.state = NodeData.NodeState.VISITED # Start is practically visited
	
	# Generate initial options (spreading out 360 degrees for first node)
	# Default direction: Right (positive X) but ignored if we pass ignore_direction=true
	var initial_direction = Vector2.RIGHT
	
	# Override: Spawn 5 nodes, ignore directional constraints (360 degrees)
	var next_nodes = generate_options(start_node, initial_direction, 5, true)
	
	return {
		"start_node": start_node,
		"initial_nodes": next_nodes
	}

## Generate new options from a source node, biased by the incoming direction
func generate_options(source_node: NodeData, incoming_vector: Vector2, override_count: int = -1, ignore_direction: bool = false) -> Array[NodeData]:
	var new_nodes: Array[NodeData] = []
	
	var count = 0
	if override_count > 0:
		count = override_count
	else:
		count = rng.randi_range(NODE_COUNT_MIN, NODE_COUNT_MAX)
	
	# Base direction is the incoming vector (direction of travel)
	# If incoming is ZERO (start), use RIGHT
	var base_dir = incoming_vector.normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
		
	# Calculate angle steps to spread nodes
	var base_angle = base_dir.angle()
	var current_spread_angle = SPREAD_ANGLE
	
	if ignore_direction:
		current_spread_angle = 360.0
	
	var attempts = 0
	var max_attempts = count * 5 # Safety break
	
	while new_nodes.size() < count and attempts < max_attempts:
		attempts += 1
		
		# Determine angle for this node
		var angle_offset = rng.randf_range(-deg_to_rad(current_spread_angle / 2.0), deg_to_rad(current_spread_angle / 2.0))
		
		# If ignoring direction (360 spread), we can just pick a random angle in full circle
		if ignore_direction:
			angle_offset = rng.randf_range(-PI, PI)
		
		var final_angle = base_angle + angle_offset
		var distance = rng.randf_range(MIN_DISTANCE, MAX_DISTANCE)
		
		var offset = Vector2.from_angle(final_angle) * distance
		var new_pos = source_node.position + offset
		
		# ---- OVERLAP CHECK ----
		var too_close = false
		for existing_new_node in new_nodes:
			if new_pos.distance_to(existing_new_node.position) < (MIN_DISTANCE * 0.8): # 80% of min travel distance
				too_close = true
				break
		
		if too_close:
			continue # Try again
			
		# Create Node
		var new_id = generate_uuid()
		var new_node = NodeData.new(new_id, new_pos)
		
		# Set Parent
		new_node.parent_id = source_node.id
		
		# Roll Type
		new_node.node_type = _roll_node_type()
		if new_node.node_type == EventManager.NodeType.SCAVENGE_SITE:
			new_node.biome_type = _roll_biome_type()
			_assign_difficulty_grade(new_node)
		
		# Connect
		source_node.connections.append(new_id)
		new_node.connections.append(source_node.id)
		
		new_nodes.append(new_node)
		
	return new_nodes

## Assign a difficulty grade based on distance and randomized bias
func _assign_difficulty_grade(node: NodeData) -> void:
	var distance = node.position.length()
	# avg step distance is ~400. Let's use that as a metric.
	var steps = distance / 400.0
	
	# Randomized bias: distance increases probabilities of higher grades
	# Probabilities: [Easy, Medium, Hard, Impossible]
	var weights = [1.0, 0.0, 0.0, 0.0]
	
	if steps < 5:
		weights = [0.7, 0.3, 0.0, 0.0]
	elif steps < 10:
		weights = [0.4, 0.4, 0.2, 0.0]
	elif steps < 20:
		weights = [0.2, 0.4, 0.3, 0.1]
	else:
		weights = [0.1, 0.2, 0.4, 0.3]
	
	var total_weight = 0.0
	for w in weights:
		total_weight += w
		
	var roll = rng.randf() * total_weight
	var current_weight = 0.0
	var selected_grade = NodeData.DifficultyGrade.EASY
	
	for i in range(weights.size()):
		current_weight += weights[i]
		if roll <= current_weight:
			selected_grade = i as NodeData.DifficultyGrade
			break
			
	node.difficulty_grade = selected_grade
	
	# Assign multiplier based on grade
	match selected_grade:
		NodeData.DifficultyGrade.EASY:
			node.difficulty_multiplier = rng.randf_range(0.8, 1.2)
		NodeData.DifficultyGrade.MEDIUM:
			node.difficulty_multiplier = rng.randf_range(1.3, 2.0)
		NodeData.DifficultyGrade.HARD:
			node.difficulty_multiplier = rng.randf_range(2.1, 3.0)
		NodeData.DifficultyGrade.IMPOSSIBLE:
			node.difficulty_multiplier = rng.randf_range(3.1, 4.5)

## Roll node type
func _roll_node_type() -> int:
	var roll = rng.randf()
	if roll < 0.40:
		return EventManager.NodeType.SCAVENGE_SITE
	elif roll < 0.80:
		return EventManager.NodeType.EMPTY_SPACE
	else:
		return EventManager.NodeType.EMPTY_SPACE # Placeholder for others
		
## Roll biome type
func _roll_biome_type() -> int:
	var biomes = [
		BiomeConfig.BiomeType.STATION,
		BiomeConfig.BiomeType.ASTEROID,
		BiomeConfig.BiomeType.PLANET
	]
	return biomes[rng.randi() % biomes.size()]

## Simple UUID generator (random string)
func generate_uuid() -> String:
	# GDScript 2.0 doesn't have native UUID, using random hex helper or similar
	# Using timestamp + random
	var chars = "0123456789abcdef"
	var uuid = ""
	for i in range(16): # 16 chars is enough for local session
		uuid += chars[rng.randi() % 16]
	return uuid
