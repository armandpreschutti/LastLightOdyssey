extends Node

## Manager for the Voyage 2.0 Progressive Graph Map System
## Handles navigation, generation, and node state management

signal ship_moved(new_position: Vector2, node_data: NodeData, speed_mult: float)
signal map_updated
signal message_log_added(message: String)
signal story_node_spawned(node_data: NodeData)
signal story_sequence_finished
signal raider_moved(new_position: Vector2, node_id: String)
signal raider_spawned(node_data: NodeData)
signal raider_destroyed

# Core State
var current_node_id: String = ""
var nodes: Dictionary = {} # String (ID) -> NodeData
var generator: ProgressiveMapGenerator
var is_voyage_complete: bool = false
var active_story_node_id: String = ""

# Campaign Branching State
var current_story_mission_id: String = ""    # ID of mission just completed
var pending_branch_choice: String = ""       # Player's chosen next mission

# Raider State
var is_raider_active: bool = false
var raider_node_id: String = ""
var jumps_since_raider_cleared: int = 0
const RAIDER_RESPAWN_JUMPS: int = 10
const RAIDER_RESPAWN_JUMPS_DEV: int = 2
const RAIDER_SPAWN_DISTANCE_MIN: float = 1200.0
const RAIDER_SPAWN_DISTANCE_MAX: float = 1800.0

# Constants
const FUEL_COST_PER_JUMP: int = 1
const HULL_DAMAGE_NO_FUEL: int = 5
const STORY_INTEL_THRESHOLD: int = 3
const STORY_INTEL_THRESHOLD_DEV: int = 1
const STORY_CHAIN_LENGTH: int = 5
const STORY_RANGE_UNITS: float = 1200.0 # Approx 3 jumps in world-space terms
const STORY_SPAWN_DISTANCE_MIN: float = 1200.0 # Min distance to spawn new story nodes
const STORY_SPAWN_DISTANCE_MAX: float = 1500.0 # Max distance to spawn new story nodes

# Story node biomes and difficulty by tier (1-indexed)
const STORY_BIOMES := {
	1: BiomeConfig.BiomeType.STATION,
	2: BiomeConfig.BiomeType.ASTEROID,
	3: BiomeConfig.BiomeType.PLANET,
	4: BiomeConfig.BiomeType.ASTEROID,
	5: BiomeConfig.BiomeType.STATION,
}

const STORY_DIFFICULTY := {
	1: NodeData.DifficultyGrade.EASY,
	2: NodeData.DifficultyGrade.MEDIUM,
	3: NodeData.DifficultyGrade.HARD,
	4: NodeData.DifficultyGrade.IMPOSSIBLE,
	5: NodeData.DifficultyGrade.IMPOSSIBLE,
}
const PROXIMITY_CONNECT_DISTANCE: float = 450.0 # Auto-connect nodes within this distance

# Campaign tree structure
const CAMPAIGN_TREE: Dictionary = {
	"1A": ["2A", "2B"],
	"2A": ["3A", "3B"], "2B": ["3B", "3C"],
	"3A": ["4A", "4B"], "3B": ["4B", "4C"], "3C": ["4C", "4D"],
	"4A": ["5A", "5B"], "4B": ["5B", "5C"], "4C": ["5C", "5D"], "4D": ["5D", "5E"],
}
const TERMINAL_MISSIONS: Array[String] = ["5A", "5B", "5C", "5D", "5E"]

func _ready() -> void:
	generator = ProgressiveMapGenerator.new()
	# Ensure start node exists if no data loaded
	if nodes.is_empty():
		_initialize_voyage()

	# Connect to GameState signals to track voyage end
	GameState.game_over.connect(func(_reason): is_voyage_complete = true)
	GameState.game_won.connect(func(_type): is_voyage_complete = true)
	GameState.intel_changed.connect(_on_intel_changed)
	_try_spawn_story_node()
	_try_spawn_raider()
	
	# Debug trigger removed.

## Initialize a new voyage
func _initialize_voyage() -> void:
	is_voyage_complete = false
	active_story_node_id = ""
	nodes.clear()
	var result = generator.generate_start_node()
	var start_node = result["start_node"]
	var initial_nodes = result["initial_nodes"]
	
	# Register nodes
	nodes[start_node.id] = start_node
	current_node_id = start_node.id
	
	for node in initial_nodes:
		nodes[node.id] = node
	
	# Reset Raider state on new voyage
	is_raider_active = false
	raider_node_id = ""
	jumps_since_raider_cleared = 0
		
	_apply_proximity_connections()
	_try_spawn_story_node()
	_try_spawn_raider()
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

	# Check if this is new exploration (unvisited or story node on first visit)
	var is_new_exploration = target_node.state == NodeData.NodeState.UNVISITED or target_node.state == NodeData.NodeState.STORY

	# Mark Visited & Generate New Nodes
	if target_node.state == NodeData.NodeState.UNVISITED:
		target_node.state = NodeData.NodeState.VISITED
		_handle_arrival_generation(target_node, nodes[previous_node_id])
	elif target_node.state == NodeData.NodeState.STORY:
		# Keep STORY state until mission completion logic resolves it.
		# Generate forward options on first arrival so story nodes don't dead-end map growth.
		if target_node.connections.size() <= 1:
			_handle_arrival_generation(target_node, nodes[previous_node_id])

	_try_spawn_story_node()
	ship_moved.emit(target_node.position, target_node, 1.0)
	map_updated.emit()

	# Award 1 Intel only for new exploration - jumping to unvisited nodes or new story missions (capped at intel threshold)
	if is_new_exploration:
		var intel_cap = _get_story_intel_threshold()
		GameState.intel = mini(GameState.intel + 1, intel_cap)

	# Phase 3: Injury recovery  reduce injury_jumps by 1 for each officer
	if is_new_exploration:
		for key in GameState.officers:
			var od: OfficerData = GameState.get_officer(key)
			if od and od.injury_jumps > 0:
				od.injury_jumps -= 1
				# When injury_jumps reaches 0, heal officer fully
				if od.injury_jumps == 0:
					od.current_hp = od.max_hp
					od.downed = false

	return true

## Process raider turn after player jump animation completes
## Returns true if raider moved, false if no raider or couldn't move
func process_raider_turn() -> bool:
	if not is_raider_active:
		jumps_since_raider_cleared += 1
		_try_spawn_raider()
		return false
	
	return _process_raider_turn()


func get_story_progress() -> int:
	return GameState.story_chapters_completed


func get_story_chain_length() -> int:
	return STORY_CHAIN_LENGTH


func _get_story_intel_threshold() -> int:
	return STORY_INTEL_THRESHOLD_DEV if GameState.is_developer_mode_enabled() else STORY_INTEL_THRESHOLD


func complete_story_node(node_id: String, mission_success: bool) -> Dictionary:
	var result := {
		"completed": false,
		"story_chain_complete": false,
		"chapters_completed": GameState.story_chapters_completed,
		"next_choices": [],
		"is_terminal": false,
	}

	if not mission_success:
		return result
	if node_id == "":
		return result
	if not nodes.has(node_id):
		return result

	var node: NodeData = nodes[node_id]
	if node.state != NodeData.NodeState.STORY:
		return result

	var intel_threshold = _get_story_intel_threshold()

	# Intel is spent on chapter completion (not on story-node spawn).
	GameState.intel = maxi(0, GameState.intel - intel_threshold)
	GameState.story_chapters_completed += 1
	node.state = NodeData.NodeState.CLEARED
	active_story_node_id = ""

	# Store the mission ID that was just completed
	current_story_mission_id = node.campaign_mission_id
	print("DEBUG VoyageManager: campaign_mission_id=%s" % node.campaign_mission_id)

	result["completed"] = true
	result["chapters_completed"] = GameState.story_chapters_completed
	result["story_chain_complete"] = GameState.story_chapters_completed >= STORY_CHAIN_LENGTH
	result["next_choices"] = CAMPAIGN_TREE.get(current_story_mission_id, [])
	result["is_terminal"] = current_story_mission_id in TERMINAL_MISSIONS
	print("DEBUG VoyageManager: next_choices=%s, is_terminal=%s" % [result["next_choices"], result["is_terminal"]])

	# If there is enough remaining intel for another chapter, spawn immediately.
	_try_spawn_story_node()
	map_updated.emit()

	return result


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
		
	# Both nodes must be visited/cleared/story — only UNVISITED means not traveled
	var a_visited = node_a.state != NodeData.NodeState.UNVISITED
	var b_visited = node_b.state != NodeData.NodeState.UNVISITED
	
	return a_visited and b_visited

## Generate new nodes upon arrival at a fresh node
func _handle_arrival_generation(target_node: NodeData, previous_node: NodeData) -> void:
	# Calculate direction vector
	var incoming_vector = target_node.position - previous_node.position
	
	# Generate new options
	var new_nodes = generator.generate_options(target_node, incoming_vector, -1, false, nodes)
	
	# Register and link new nodes
	for node in new_nodes:
		nodes[node.id] = node
		# Connection logic is handled inside generator (bidirectional link)
		# Just need to make sure the target_node's connections are updated if not already done by reference?
		# GDScript objects are passed by reference, so modifying source_node.connections in generator works.
	
	# Auto-connect any nodes that are within proximity distance
	_apply_proximity_connections()

func _on_intel_changed(_new_value: int) -> void:
	_try_spawn_story_node()


func _try_spawn_story_node() -> void:
	if is_voyage_complete:
		return
	if GameState.story_chapters_completed >= STORY_CHAIN_LENGTH:
		return
	if GameState.intel < _get_story_intel_threshold():
		return

	# One active story node at a time.
	if active_story_node_id != "" and nodes.has(active_story_node_id):
		var active_node: NodeData = nodes[active_story_node_id]
		if active_node.state == NodeData.NodeState.STORY:
			return
	active_story_node_id = ""

	# Campaign branching: only spawn if we have a pending choice OR it's the first mission
	if GameState.story_chapters_completed == 0 and pending_branch_choice == "":
		# First mission: auto-set to 1A and spawn immediately
		pending_branch_choice = "1A"
	elif pending_branch_choice == "":
		# No pending choice yet (waiting for player to choose)
		return

	var current_node = get_current_node()
	if not current_node:
		return

	# Calculate spawn position and create new node
	var spawn_pos = _find_story_spawn_position(current_node.position)
	var new_id = generator.generate_uuid()
	
	# Create node with random characteristics
	var new_node = NodeData.new(new_id, spawn_pos)
	new_node.node_type = generator._roll_node_type()
	new_node.biome_type = generator._roll_biome_type()
	
	# Add to dictionary
	nodes[new_id] = new_node

	# Setup as story node with tier (chapters_completed + 1 = current tier)
	var story_tier = GameState.story_chapters_completed + 1
	_mark_node_as_story(new_node, story_tier)
	new_node.campaign_mission_id = pending_branch_choice
	print("DEBUG VoyageManager: Spawned story node %s at %s with campaign_mission_id=%s" % [new_node.id, spawn_pos, pending_branch_choice])
	
	pending_branch_choice = ""  # Clear after assigning
	
	# Check for proximity connections immediately
	_apply_proximity_connections()
	
	message_log_added.emit("Signal detected: Story node locked to mission grid.")
	map_updated.emit()
	story_node_spawned.emit(new_node)


func _find_story_spawn_position(from_position: Vector2) -> Vector2:
	# Sample 8-16 candidate angles around current node
	var candidate_count = 16
	var best_direction = Vector2.RIGHT
	var max_min_distance = -1.0
	
	for i in range(candidate_count):
		var angle = (TAU / candidate_count) * i
		var direction = Vector2(cos(angle), sin(angle))
		
		# Check at max distance for the "direction" check
		var check_pos = from_position + (direction * STORY_SPAWN_DISTANCE_MAX)
		
		# For each angle, check distance to all existing nodes
		var min_dist_to_existing = INF
		for id in nodes:
			var node = nodes[id]
			var dist = check_pos.distance_to(node.position)
			if dist < min_dist_to_existing:
				min_dist_to_existing = dist
		
		# We want to maximize the distance to the nearest existing node (avoid clustering)
		if min_dist_to_existing > max_min_distance:
			max_min_distance = min_dist_to_existing
			best_direction = direction
			
	# Return position at random distance in best direction
	var random_dist = randf_range(STORY_SPAWN_DISTANCE_MIN, STORY_SPAWN_DISTANCE_MAX)
	return from_position + (best_direction * random_dist)


func _mark_node_as_story(node: NodeData, story_tier: int = 0) -> void:
	if node == null:
		return
	node.state = NodeData.NodeState.STORY
	node.is_story_node = true
	node.node_type = EventManager.NodeType.SCAVENGE_SITE

	# Set biome based on story tier (1-5)
	if story_tier > 0 and story_tier <= STORY_CHAIN_LENGTH:
		node.biome_type = STORY_BIOMES.get(story_tier, BiomeConfig.BiomeType.STATION)
		node.difficulty_grade = STORY_DIFFICULTY.get(story_tier, NodeData.DifficultyGrade.MEDIUM)
	else:
		# Fallback for non-standard tiers
		node.biome_type = generator._roll_biome_type()
		node.difficulty_grade = NodeData.DifficultyGrade.MEDIUM

	active_story_node_id = node.id

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


## Find a path for the raider (can traverse ANY connected nodes, including unvisited)
## Returns an array of NodeData representing the path (including start and end)
func find_path_for_raider(start_id: String, target_id: String) -> Array[NodeData]:
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
				
			# Raider can traverse any connected node, no state check
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				var new_path = path.duplicate()
				new_path.append(neighbor_id)
				queue.push_back(new_path)
				
	return [] # No path found


## Set the player's branch choice and attempt to spawn the next story node
func set_branch_choice(mission_id: String) -> void:
	pending_branch_choice = mission_id
	_try_spawn_story_node()   # Attempt to spawn immediately if intel is sufficient
	map_updated.emit()


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
			"new_earth": node.is_new_earth,
			"is_story_node": node.is_story_node,
			"campaign_mission_id": node.campaign_mission_id
		}

	return {
		"current_node_id": current_node_id,
		"nodes": nodes_data,
		"active_story_node_id": active_story_node_id,
		"current_story_mission_id": current_story_mission_id,
		"pending_branch_choice": pending_branch_choice,
		"is_raider_active": is_raider_active,
		"raider_node_id": raider_node_id,
		"jumps_since_raider_cleared": jumps_since_raider_cleared
	}

func load_save_data(data: Dictionary) -> void:
	nodes.clear()

	if data.has("current_node_id"):
		current_node_id = data["current_node_id"]
	active_story_node_id = data.get("active_story_node_id", "")
	current_story_mission_id = data.get("current_story_mission_id", "")
	pending_branch_choice = data.get("pending_branch_choice", "")
	is_raider_active = data.get("is_raider_active", false)
	raider_node_id = data.get("raider_node_id", "")
	jumps_since_raider_cleared = data.get("jumps_since_raider_cleared", 0)

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
			node.is_story_node = n_data.get("is_story_node", false)
			node.campaign_mission_id = n_data.get("campaign_mission_id", "")

			nodes[id] = node

	# Recover active story node pointer if needed.
	if active_story_node_id == "":
		for id in nodes:
			var n: NodeData = nodes[id]
			if n.state == NodeData.NodeState.STORY:
				active_story_node_id = id
				break

	_apply_proximity_connections()
	_try_spawn_story_node()
#endregion


## Auto-connect any two nodes within PROXIMITY_CONNECT_DISTANCE of each other (bidirectional)
func _apply_proximity_connections() -> void:
	var node_ids = nodes.keys()
	for i in range(node_ids.size()):
		var node_a: NodeData = nodes[node_ids[i]]
		for j in range(i + 1, node_ids.size()):
			var node_b: NodeData = nodes[node_ids[j]]
			if node_a.position.distance_to(node_b.position) <= PROXIMITY_CONNECT_DISTANCE:
				if not node_b.id in node_a.connections:
					node_a.connections.append(node_b.id)
				if not node_a.id in node_b.connections:
					node_b.connections.append(node_a.id)


#region Raider Mechanics

func _try_spawn_raider() -> void:
	if is_voyage_complete or is_raider_active:
		return
		
	var required_jumps = RAIDER_RESPAWN_JUMPS_DEV if GameState.is_developer_mode_enabled() else RAIDER_RESPAWN_JUMPS
	if jumps_since_raider_cleared < required_jumps:
		return
		
	var current_node = get_current_node()
	if not current_node:
		return
		
	# Find spawn position (reusing logic from story nodes)
	var spawn_pos = _find_story_spawn_position(current_node.position)
	
	# Calculate direction vector to make it look like it's coming from outside
	var incoming_vector = (current_node.position - spawn_pos).normalized()
	
	# Create the actual Raider node
	var new_id = generator.generate_uuid()
	var new_node = NodeData.new(new_id, spawn_pos)
	new_node.node_type = EventManager.NodeType.EMPTY_SPACE
	new_node.biome_type = BiomeConfig.BiomeType.ASTEROID
	new_node.difficulty_grade = NodeData.DifficultyGrade.EASY
	nodes[new_id] = new_node
	
	# Set state
	is_raider_active = true
	raider_node_id = new_id
	jumps_since_raider_cleared = 0
	
	print("DEBUG VoyageManager: Spawned Raider ship at %s" % new_node.id)
	
	# Generate a bridge of nodes leading towards the player's graph
	_generate_raider_bridge(new_node, incoming_vector)

	message_log_added.emit("WARNING: Hostile Raider signature detected on long-range scanners!")
	map_updated.emit()
	raider_spawned.emit(new_node)

func _generate_raider_bridge(raider_start_node: NodeData, direction_to_player: Vector2) -> void:
	# Generate 2 nodes bridging the gap to the main graph
	var current_bridge_node = raider_start_node
	var bridge_length = 2
	
	for i in range(bridge_length):
		# Override parameters to force 1 node in the specific direction
		var new_bridge_nodes = generator.generate_options(current_bridge_node, direction_to_player, 1, false, nodes)
		if new_bridge_nodes.size() > 0:
			var bridge = new_bridge_nodes[0]
			nodes[bridge.id] = bridge
			current_bridge_node = bridge
			
	# Then apply proximity links to lock this new disconnected string into the main graph
	_apply_proximity_connections()


func _process_raider_turn() -> bool:
	if not is_raider_active or not nodes.has(raider_node_id):
		return false
	
	# Check if player landed on raider's node (player jumped onto raider)
	if raider_node_id == current_node_id:
		print("DEBUG VoyageManager: Player jumped onto raider at %s" % current_node_id)
		_trigger_raider_ambush()
		return false
		
	var raider_node = nodes[raider_node_id]
	# Use raider-specific pathfinding that can traverse unvisited nodes
	var path_to_player = find_path_for_raider(raider_node_id, current_node_id)
	
	if path_to_player.size() > 1:
		# Index 0 is the raider's current node, Index 1 is the next step
		var next_step = path_to_player[1]
		raider_node_id = next_step.id
		raider_moved.emit(next_step.position, next_step.id)
		print("DEBUG VoyageManager: Raider moved to %s" % next_step.id)
		
		# Did the raider catch the player?
		if raider_node_id == current_node_id:
			print("DEBUG VoyageManager: Raider caught player at %s" % current_node_id)
			_trigger_raider_ambush()
		return true
	else:
		# No path found - create a new node toward the player
		print("DEBUG VoyageManager: No path found, creating emergency path toward player")
		_create_emergency_path_toward_player()
		return true

func _trigger_raider_ambush() -> void:
	print("DEBUG VoyageManager: RAIDER AMBUSH TRIGGERED ON NODE %s" % current_node_id)
	message_log_added.emit("CRITICAL: Intercepted by Raiders! Prepare to deploy!")

func clear_raider(success: bool) -> void:
	is_raider_active = false
	raider_node_id = ""
	jumps_since_raider_cleared = 0
	raider_destroyed.emit()
	if success:
		message_log_added.emit("Raider vessel destroyed. Threat eliminated.")
	else:
		message_log_added.emit("Retreated from raiders. Squad sustained massive injuries!")
		
		# Apply mechanical penalty: Down 1-2 random officers if they aren't already injured
		var available_officers = []
		for key in GameState.officers.keys():
			if GameState.is_officer_available(key):
				available_officers.append(key)
		
		available_officers.shuffle()
		var num_to_down = min(available_officers.size(), 2)
		for i in range(num_to_down):
			GameState.down_officer(available_officers[i])
			print("DEBUG Raider: Downing %s as penalty" % available_officers[i])

## Create an emergency path toward player when normal pathfinding fails
func _create_emergency_path_toward_player() -> void:
	if not nodes.has(raider_node_id) or not nodes.has(current_node_id):
		return
		
	var raider_node = nodes[raider_node_id]
	var player_node = nodes[current_node_id]
	
	# Calculate direction from raider to player
	var direction = (player_node.position - raider_node.position).normalized()
	
	# Create a new node in that direction (standard jump distance ~400-500 units)
	var new_pos = raider_node.position + direction * 400.0
	
	# Create the node
	var new_id = generator.generate_uuid()
	var new_node = NodeData.new(new_id, new_pos)
	new_node.node_type = EventManager.NodeType.EMPTY_SPACE
	new_node.biome_type = BiomeConfig.BiomeType.ASTEROID
	new_node.difficulty_grade = NodeData.DifficultyGrade.EASY
	
	# Register node
	nodes[new_id] = new_node
	
	# Connect raider's current node to new node
	if not new_id in raider_node.connections:
		raider_node.connections.append(new_id)
	if not raider_node_id in new_node.connections:
		new_node.connections.append(raider_node_id)
	
	print("DEBUG VoyageManager: Created emergency path node %s at %s" % [new_id, new_pos])
	
	# Try to connect to nearby nodes via proximity
	_apply_proximity_connections()
	
	# Move raider to the new node
	raider_node_id = new_id
	raider_moved.emit(new_pos, new_id)
	print("DEBUG VoyageManager: Raider emergency moved to %s" % new_id)
	
	# Check if we caught the player (rare but possible)
	if raider_node_id == current_node_id:
		print("DEBUG VoyageManager: Raider caught player at %s" % current_node_id)
		_trigger_raider_ambush()

#endregion
