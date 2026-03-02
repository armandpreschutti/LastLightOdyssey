extends Node

## Manager for the Voyage 2.0 Progressive Graph Map System
## Handles navigation, generation, and node state management

signal ship_moved(new_position: Vector2, node_data: NodeData, speed_mult: float)
signal ship_teleported(new_position: Vector2, node_data: NodeData)
signal map_updated
signal message_log_added(message: String)
signal story_node_spawned(node_data: NodeData)
signal story_sequence_finished
signal raider_moved(new_position: Vector2, old_node_id: String, new_node_id: String)
signal raider_spawned(node_data: NodeData)
signal raider_destroyed(raider_node_id: String)
signal raider_sequence_finished

# Core State
var current_node_id: String = ""
var nodes: Dictionary = {} # String (ID) -> NodeData
var generator: ProgressiveMapGenerator
var is_voyage_complete: bool = false
var active_story_node_id: String = ""

# Campaign Branching State
var current_story_mission_id: String = ""    # ID of mission just completed
var pending_branch_choice: String = ""       # Player's chosen next mission

# Wormhole pairs (entrance -> exit) - white pathlines when player has jumped through
var wormhole_pairs: Array[Array] = []  # Each is [exit_id, arrival_id] from teleport

# Raider State
var raider_node_ids: Array[String] = []  # All active raider node IDs, up to MAX_RAIDERS
var total_jumps_made: int = 0              # Total jumps made this voyage (for wormhole schedule)
var jumps_since_raider_cleared: int = 0   # Jumps since ALL raiders were cleared (first spawn)
var jumps_since_last_raider_spawn: int = 0 # Jumps since the last individual raider spawned
var raider_ambush_triggered: bool = false  # True when a raider has landed on the player's node
var _raider_turn_index: int = 0            # Round-robin index for per-raider turn processing
const MAX_RAIDERS: int = 3
const RAIDER_RESPAWN_JUMPS: int = 10
const RAIDER_RESPAWN_JUMPS_DEV: int = 2
const RAIDER_SPAWN_DISTANCE_MIN: float = 1900.0
const RAIDER_SPAWN_DISTANCE_MAX: float = 3100.0
const RAIDER_DETECTION_RADIUS: float = 1200.0
const RAIDER_JUMPS_PER_TURN: int = 2

## Returns effective raider jumps per player turn (1 if dev_raider_1_jump_per_turn, else RAIDER_JUMPS_PER_TURN).
static func get_raider_jumps_per_turn() -> int:
	return 1 if GameState.dev_raider_1_jump_per_turn else RAIDER_JUMPS_PER_TURN
## When true, raider spawn creates 2 bridge nodes toward the player; when false, raider spawns alone
const RAIDER_BRIDGE_ENABLED: bool = false
## Radius within which the player can direct-travel to visited nodes (same scale as raider detection)
const PLAYER_TRAVEL_RADIUS: float = 1200.0

## True if any raider ship is currently active
var is_raider_active: bool:
	get:
		return raider_node_ids.size() > 0

## Returns the raider that is on the player's node (for ambush), or the first active raider.
## Read-only compatibility shim — use is_any_raider_on_player_node() for ambush checks.
var raider_node_id: String:
	get:
		if current_node_id in raider_node_ids:
			return current_node_id
		return raider_node_ids[0] if not raider_node_ids.is_empty() else ""

# Constants
const FUEL_COST_PER_JUMP: int = 1
const HULL_DAMAGE_NO_FUEL: int = 5
const STORY_INTEL_THRESHOLD: int = 3
const STORY_INTEL_THRESHOLD_DEV: int = 1
const STORY_CHAIN_LENGTH: int = 5
const STORY_RANGE_UNITS: float = 1200.0 # Approx 3 jumps in world-space terms
const STORY_SPAWN_DISTANCE_MIN: float = 1200.0 # Min distance to spawn new story nodes
const STORY_SPAWN_DISTANCE_MAX: float = 1500.0 # Max distance to spawn new story nodes
const WORMHOLE_SPAWN_DISTANCE_MIN: float = 3600.0 # Min distance (3x story) - player only
const WORMHOLE_SPAWN_DISTANCE_MAX: float = 4500.0 # Max distance (3x story) - player only

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

	# Spawn the first wormhole in the initial cluster so it's reachable from the start node
	if initial_nodes.size() > 0:
		var wormhole_node = initial_nodes[0]
		wormhole_node.node_type = EventManager.NodeType.WORMHOLE
		wormhole_node.biome_type = -1

	# Reset Raider and wormhole state on new voyage
	wormhole_pairs.clear()
	raider_node_ids.clear()
	total_jumps_made = 0
	jumps_since_raider_cleared = 0
	jumps_since_last_raider_spawn = 0
	raider_ambush_triggered = false
	_raider_turn_index = 0
		
	# Only connect the initial cluster (start + 5 initial nodes) - no global pass
	var init_ids: Array[String] = [start_node.id]
	for node in initial_nodes:
		init_ids.append(node.id)
	_apply_proximity_connections_for_new_nodes(init_ids)
	_try_spawn_story_node()
	_try_spawn_raider()
	map_updated.emit()

## Move the ship to a target node
## Returns true if move was successful
func attempt_jump(target_node: NodeData, speed_mult: float = 1.0) -> bool:
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
	ship_moved.emit(target_node.position, target_node, speed_mult)
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

## Call exactly once after each player jump to update spawn counters and attempt spawning.
## Must be called before the process_raider_turn() loop.
func begin_player_jump_processing() -> void:
	total_jumps_made += 1
	if raider_node_ids.is_empty():
		jumps_since_raider_cleared += 1
	jumps_since_last_raider_spawn += 1
	raider_ambush_triggered = false
	_raider_turn_index = 0
	_try_spawn_raider()

## Process the next raider's move in round-robin order.
## Returns true if a raider actually moved (caller should await animation).
## Returns false if no move occurred (raider skipped or all raiders processed).
## Break the calling loop when raider_ambush_triggered becomes true.
func process_raider_turn() -> bool:
	if raider_node_ids.is_empty() or raider_ambush_triggered:
		return false
	if _raider_turn_index >= raider_node_ids.size():
		return false
	var moved = _process_single_raider_turn(_raider_turn_index)
	_raider_turn_index += 1
	return moved

## Returns true if any raider is currently on the player's node (ambush state).
func is_any_raider_on_player_node() -> bool:
	return current_node_id in raider_node_ids

## Returns the node ID of the raider that is on the player's node, or "" if none.
func get_ambushing_raider_id() -> String:
	if current_node_id in raider_node_ids:
		return current_node_id
	return ""


func get_story_progress() -> int:
	return GameState.story_chapters_completed


func get_story_chain_length() -> int:
	return STORY_CHAIN_LENGTH


func _get_story_intel_threshold() -> int:
	return STORY_INTEL_THRESHOLD_DEV if GameState.dev_story_intel else STORY_INTEL_THRESHOLD


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


## Returns true if the target node is within direct-travel radius of current position
func is_node_within_travel_radius(target_node: NodeData) -> bool:
	var current_node = get_current_node()
	if not current_node or not target_node:
		return false
	return current_node.position.distance_to(target_node.position) <= PLAYER_TRAVEL_RADIUS


## Move the ship directly to a target visited node (skipping intermediates)
func attempt_direct_travel(target_node: NodeData, speed_mult: float = 1.25) -> bool:
	if is_voyage_complete:
		return false
		
	if not target_node:
		return false

	# Cannot fast travel while within raider detection zone
	if is_player_in_raider_zone():
		message_log_added.emit("Cannot fast travel while being pursued!")
		return false

	# Cannot fast travel without fuel (drift mode)
	if GameState.fuel <= 0:
		message_log_added.emit("Cannot fast travel in Drift Mode - no fuel!")
		return false
		
	# Verify target is visited
	if target_node.state == NodeData.NodeState.UNVISITED:
		message_log_added.emit("Cannot direct travel to unvisited coordinates.")
		return false

	# Verify target is within travel radius
	if not is_node_within_travel_radius(target_node):
		message_log_added.emit("Target is beyond travel range.")
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


## Attempt wormhole teleport: if this wormhole already has a pair (white pathline), go to the other end.
## Otherwise spawn a new WORMHOLE node and record the pair.
func attempt_wormhole_teleport(exit_node: NodeData) -> NodeData:
	if is_voyage_complete or not exit_node:
		return null
	if exit_node.node_type != EventManager.NodeType.WORMHOLE:
		return null

	# If we've used this wormhole before, teleport to the paired wormhole
	var paired_id = _get_paired_wormhole_id(exit_node.id)
	if paired_id != "" and nodes.has(paired_id):
		return nodes[paired_id]

	# First time through: spawn new wormhole (3x further than story spawn - player only)
	var spawn_pos = _find_story_spawn_position(exit_node.position, WORMHOLE_SPAWN_DISTANCE_MIN, WORMHOLE_SPAWN_DISTANCE_MAX)

	# Create new WORMHOLE node at destination
	var new_id = generator.generate_uuid()
	var arrival_node = NodeData.new(new_id, spawn_pos, EventManager.NodeType.WORMHOLE)
	arrival_node.state = NodeData.NodeState.VISITED

	# Register and connect via proximity
	nodes[new_id] = arrival_node
	_apply_proximity_connections_for_new_nodes([new_id])

	# Generate options in all directions (360° spread)
	var new_nodes = generator.generate_options(arrival_node, Vector2.ZERO, -1, true, nodes)
	for node in new_nodes:
		nodes[node.id] = node
	var new_ids: Array[String] = []
	for node in new_nodes:
		new_ids.append(node.id)
	_apply_proximity_connections_for_new_nodes(new_ids)

	# Remember wormhole connection for white pathline (from -> to, direction for arrows)
	wormhole_pairs.append([exit_node.id, arrival_node.id])

	return arrival_node


## Returns true if this wormhole is a destination (to end of a pair). Destinations do NOT show ENTER WORMHOLE.
## Entrances (from end) and unpaired wormholes do show the button.
func is_wormhole_destination(wormhole_id: String) -> bool:
	for pair in wormhole_pairs:
		if pair.size() == 2 and str(pair[1]) == wormhole_id:
			return true
	return false


## Returns all visited wormhole nodes, optionally excluding one (e.g. current node).
func get_visited_wormhole_nodes(exclude_id: String = "") -> Array[NodeData]:
	var result: Array[NodeData] = []
	for node in nodes.values():
		if node.node_type == EventManager.NodeType.WORMHOLE \
				and node.state != NodeData.NodeState.UNVISITED \
				and node.id != exclude_id:
			result.append(node)
	return result


## Get the paired wormhole ID for a given wormhole (the other end of the white pathline).
## Returns "" if this wormhole has no pair yet.
func _get_paired_wormhole_id(wormhole_id: String) -> String:
	for pair in wormhole_pairs:
		if pair.size() == 2:
			var id1 = str(pair[0])
			var id2 = str(pair[1])
			if id1 == wormhole_id:
				return id2
			if id2 == wormhole_id:
				return id1
	return ""


## Calculate fuel cost to jump to a target node
func get_fuel_cost(target_node: NodeData) -> int:
	var current_node = get_current_node()
	if not current_node:
		return FUEL_COST_PER_JUMP
		
	# Traveled paths (amber lines) cost 1 fuel, same as any other jump
	
	return FUEL_COST_PER_JUMP


## Check if a path between two nodes has been traveled (visited and connected)
## Used for amber lines visual display
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
	
	# Only connect the newly generated nodes to the graph - prevents cross-branch spurious links
	var new_ids: Array[String] = []
	for node in new_nodes:
		new_ids.append(node.id)
	_apply_proximity_connections_for_new_nodes(new_ids)

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
	
	# Only connect the new story node to nearby nodes - prevents cross-branch spurious links
	_apply_proximity_connections_for_new_nodes([new_id])
	
	message_log_added.emit("Signal detected: Story node locked to mission grid.")
	map_updated.emit()
	story_node_spawned.emit(new_node)


func _find_story_spawn_position(from_position: Vector2, dist_min: float = STORY_SPAWN_DISTANCE_MIN, dist_max: float = STORY_SPAWN_DISTANCE_MAX) -> Vector2:
	# Sample 8-16 candidate angles around current node
	var candidate_count = 16
	var best_direction = Vector2.RIGHT
	var max_min_distance = -1.0
	
	for i in range(candidate_count):
		var angle = (TAU / candidate_count) * i
		var direction = Vector2(cos(angle), sin(angle))
		
		# Check at max distance for the "direction" check
		var check_pos = from_position + (direction * dist_max)
		
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
	var random_dist = randf_range(dist_min, dist_max)
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

## Get all known/visible nodes (excludes raider-owned spawn nodes — they are not part of the player map)
func get_visible_nodes() -> Array[NodeData]:
	var visible_nodes: Array[NodeData] = []
	for id in nodes:
		if not nodes[id].is_raider_node:
			visible_nodes.append(nodes[id])
	return visible_nodes

## Find a path between two nodes using Breadth-First Search
## Only traverses VISITED or CLEARED nodes
## Includes wormhole pairs as traversable edges (white pathlines count for fast travel)
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
		var neighbors_to_check: Array[String] = []
		neighbors_to_check.assign(current_node.connections)
		# Include paired wormhole as traversable (white pathlines = fast travel)
		var paired_id = _get_paired_wormhole_id(current_id)
		if paired_id != "" and nodes.has(paired_id):
			neighbors_to_check.append(paired_id)
		for neighbor_id in neighbors_to_check:
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
## Raiders cannot use wormholes - only normal node connections
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
		var neighbors_to_check: Array[String] = []
		neighbors_to_check.assign(current_node.connections)
		# Raiders cannot use wormholes - only use normal connections
		for neighbor_id in neighbors_to_check:
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
			"is_raider_node": node.is_raider_node,
			"campaign_mission_id": node.campaign_mission_id
		}

	return {
		"current_node_id": current_node_id,
		"nodes": nodes_data,
		"wormhole_pairs": wormhole_pairs,
		"active_story_node_id": active_story_node_id,
		"current_story_mission_id": current_story_mission_id,
		"pending_branch_choice": pending_branch_choice,
		"raider_node_ids": raider_node_ids,
		"total_jumps_made": total_jumps_made,
		"jumps_since_raider_cleared": jumps_since_raider_cleared,
		"jumps_since_last_raider_spawn": jumps_since_last_raider_spawn
	}

func load_save_data(data: Dictionary) -> void:
	nodes.clear()
	wormhole_pairs.clear()

	if data.has("current_node_id"):
		current_node_id = data["current_node_id"]
	for pair in data.get("wormhole_pairs", []):
		if pair is Array and pair.size() == 2:
			wormhole_pairs.append([str(pair[0]), str(pair[1])])
	active_story_node_id = data.get("active_story_node_id", "")
	current_story_mission_id = data.get("current_story_mission_id", "")
	pending_branch_choice = data.get("pending_branch_choice", "")
	total_jumps_made = data.get("total_jumps_made", 0)
	jumps_since_raider_cleared = data.get("jumps_since_raider_cleared", 0)
	jumps_since_last_raider_spawn = data.get("jumps_since_last_raider_spawn", 0)
	raider_node_ids.clear()
	raider_ambush_triggered = false
	_raider_turn_index = 0
	# Support both new format (raider_node_ids array) and old single-raider saves
	if data.has("raider_node_ids"):
		var loaded_ids = data["raider_node_ids"]
		for rid in loaded_ids:
			raider_node_ids.append(str(rid))
	elif data.get("is_raider_active", false):
		var old_id = data.get("raider_node_id", "")
		if old_id != "":
			raider_node_ids.append(old_id)

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
			node.is_raider_node = n_data.get("is_raider_node", false)
			node.campaign_mission_id = n_data.get("campaign_mission_id", "")

			nodes[id] = node

		# Rebuild connections from structural data only - fixes spurious links from old global proximity
		# (continued voyages had accumulated cross-branch connections; new voyages don't have this)
		_rebuild_connections_from_structure()

	# Recover active story node pointer if needed.
	if active_story_node_id == "":
		for id in nodes:
			var n: NodeData = nodes[id]
			if n.state == NodeData.NodeState.STORY:
				active_story_node_id = id
				break

	_try_spawn_story_node()
#endregion


## Rebuild connections from parent_id structure only. Used on load for continued voyages.
## Removes spurious cross-branch connections that accumulated from old global proximity.
## Orphan nodes (story, wormhole, raider) get proximity connections to link into the graph.
func _rebuild_connections_from_structure() -> void:
	# Clear all connections
	for id in nodes:
		nodes[id].connections.clear()
	
	# Restore parent-child links (bidirectional)
	for id in nodes:
		var node = nodes[id]
		if node.parent_id != "" and nodes.has(node.parent_id):
			if not node.parent_id in node.connections:
				node.connections.append(node.parent_id)
			if not node.id in nodes[node.parent_id].connections:
				nodes[node.parent_id].connections.append(node.id)
	
	# Orphan nodes (no parent or start node): connect via proximity.
	# Raider-tagged nodes are excluded — they must never be connected to the
	# player map graph. Without this, raider spawn nodes become orphans on
	# load and get spurious proximity links, causing long lines on the star map.
	var orphan_ids: Array[String] = []
	for id in nodes:
		if nodes[id].connections.is_empty() and not nodes[id].is_raider_node:
			orphan_ids.append(id)
	if orphan_ids.size() > 0:
		_apply_proximity_connections_for_new_nodes(orphan_ids)


## Connect only NEW nodes to the graph via proximity (within PROXIMITY_CONNECT_DISTANCE).
## Only adds links where at least one endpoint is in new_node_ids. This prevents the
## "leak" where a global O(n²) pass would link unrelated existing nodes from different
## branches when new nodes are added (e.g. after a jump).
func _apply_proximity_connections_for_new_nodes(new_node_ids: Array) -> void:
	for new_id in new_node_ids:
		if not nodes.has(new_id):
			continue
		var node_a: NodeData = nodes[new_id]
		for other_id in nodes:
			if other_id == new_id:
				continue
			var node_b: NodeData = nodes[other_id]
			if node_a.position.distance_to(node_b.position) <= PROXIMITY_CONNECT_DISTANCE:
				if not node_b.id in node_a.connections:
					node_a.connections.append(node_b.id)
				if not node_a.id in node_b.connections:
					node_b.connections.append(node_a.id)


#region Raider Mechanics

## Returns true if the player's current node is within ANY raider's detection radius.
func is_player_in_raider_zone() -> bool:
	if raider_node_ids.is_empty():
		return false
	var current_node = get_current_node()
	if not current_node:
		return false
	for rid in raider_node_ids:
		if not nodes.has(rid):
			continue
		if current_node.position.distance_to(nodes[rid].position) <= RAIDER_DETECTION_RADIUS:
			return true
	return false


func _try_spawn_raider() -> void:
	if is_voyage_complete or raider_node_ids.size() >= MAX_RAIDERS:
		return

	var required_jumps = RAIDER_RESPAWN_JUMPS_DEV if GameState.dev_raider_fast else RAIDER_RESPAWN_JUMPS

	# When no raiders exist use the "since cleared" counter; otherwise use "since last spawn"
	var jumps_to_check = jumps_since_raider_cleared if raider_node_ids.is_empty() else jumps_since_last_raider_spawn
	if jumps_to_check < required_jumps:
		return

	var current_node = get_current_node()
	if not current_node:
		return

	# Find a spawn position well away from the player
	var spawn_pos = _find_story_spawn_position(current_node.position, RAIDER_SPAWN_DISTANCE_MIN, RAIDER_SPAWN_DISTANCE_MAX)
	var incoming_vector = (current_node.position - spawn_pos).normalized()

	# Create the raider map node
	var new_id = generator.generate_uuid()
	var new_node = NodeData.new(new_id, spawn_pos)
	new_node.node_type = EventManager.NodeType.EMPTY_SPACE
	new_node.biome_type = BiomeConfig.BiomeType.ASTEROID
	new_node.difficulty_grade = NodeData.DifficultyGrade.EASY
	new_node.is_raider_node = true  # Mark as raider-only — excluded from map visuals and connection rebuild
	nodes[new_id] = new_node

	# Register as active raider
	raider_node_ids.append(new_id)
	jumps_since_last_raider_spawn = 0

	print("DEBUG VoyageManager: Spawned Raider #%d at %s" % [raider_node_ids.size(), new_node.id])

	if RAIDER_BRIDGE_ENABLED:
		_generate_raider_bridge(new_node, incoming_vector)

	var msg = "WARNING: Hostile Raider signature detected on long-range scanners!" \
		if raider_node_ids.size() == 1 \
		else "WARNING: Additional Raider signature detected! %d hostiles closing." % raider_node_ids.size()
	message_log_added.emit(msg)
	map_updated.emit()
	raider_spawned.emit(new_node)


func _generate_raider_bridge(raider_start_node: NodeData, direction_to_player: Vector2) -> void:
	var new_node_ids: Array[String] = [raider_start_node.id]
	var current_bridge_node = raider_start_node
	for i in range(2):
		var new_bridge_nodes = generator.generate_options(current_bridge_node, direction_to_player, 1, false, nodes)
		if new_bridge_nodes.size() > 0:
			var bridge = new_bridge_nodes[0]
			nodes[bridge.id] = bridge
			new_node_ids.append(bridge.id)
			current_bridge_node = bridge
	_apply_proximity_connections_for_new_nodes(new_node_ids)


## Process the move for the raider at the given index in raider_node_ids.
## Returns true if the raider actually moved.
func _process_single_raider_turn(index: int) -> bool:
	if index >= raider_node_ids.size():
		return false

	var rid = raider_node_ids[index]
	if not nodes.has(rid):
		return false

	# Player jumped onto this raider's node
	if rid == current_node_id:
		print("DEBUG VoyageManager: Player jumped onto raider %s" % rid)
		_trigger_raider_ambush()
		return false

	# Idle if player is outside detection radius
	if not _is_raider_in_detection_range(rid):
		print("DEBUG VoyageManager: Raider %s outside detection zone, idling" % rid)
		return false

	# --- "Never Same Node" blocking rule ---
	# Only one raider may occupy the player's node at any time.
	# If the player's node is already taken by another active raider, skip this raider's move.
	if is_any_raider_on_player_node():
		print("DEBUG VoyageManager: Raider %s skipping – player node already occupied" % rid)
		return false

	var path_to_player = find_path_for_raider(rid, current_node_id)
	if path_to_player.size() > 1:
		var next_step = path_to_player[1]

		# If next step is the player's node but another raider already occupies it, skip
		if next_step.id == current_node_id and is_any_raider_on_player_node():
			print("DEBUG VoyageManager: Raider %s blocked from player node – already occupied" % rid)
			return false

		# Move this raider
		raider_node_ids[index] = next_step.id
		raider_moved.emit(next_step.position, rid, next_step.id)
		print("DEBUG VoyageManager: Raider %s moved to %s" % [rid, next_step.id])

		if next_step.id == current_node_id:
			print("DEBUG VoyageManager: Raider %s caught player at %s" % [rid, current_node_id])
			# Update index entry to new id before triggering ambush
			_trigger_raider_ambush()
		return true
	else:
		print("DEBUG VoyageManager: No path found for raider %s, creating emergency path" % rid)
		_create_emergency_path_for_raider(index)
		return true


func _is_raider_in_detection_range(rid: String) -> bool:
	var current_node = get_current_node()
	if not current_node or not nodes.has(rid):
		return false
	return current_node.position.distance_to(nodes[rid].position) <= RAIDER_DETECTION_RADIUS


func _trigger_raider_ambush() -> void:
	raider_ambush_triggered = true
	print("DEBUG VoyageManager: RAIDER AMBUSH TRIGGERED ON NODE %s" % current_node_id)
	message_log_added.emit("CRITICAL: Intercepted by Raiders! Prepare to deploy!")


## Clear a specific raider by the node ID it currently occupies.
## success=true → raider was defeated; success=false → player retreated.
func clear_raider(cleared_raider_node_id: String, success: bool) -> void:
	raider_node_ids.erase(cleared_raider_node_id)
	raider_ambush_triggered = false

	if raider_node_ids.is_empty():
		jumps_since_raider_cleared = 0
		jumps_since_last_raider_spawn = 0

	raider_destroyed.emit(cleared_raider_node_id)

	if success:
		message_log_added.emit("Raider vessel destroyed. Threat eliminated.")
	else:
		message_log_added.emit("Retreated from raiders. Squad sustained massive injuries!")
		var available_officers = []
		for key in GameState.officers.keys():
			if GameState.is_officer_available(key):
				available_officers.append(key)
		available_officers.shuffle()
		var num_to_down = min(available_officers.size(), 2)
		for i in range(num_to_down):
			GameState.down_officer(available_officers[i])
			print("DEBUG Raider: Downing %s as penalty" % available_officers[i])


## Clear a specific raider as a surrender outcome (no penalty fight).
func clear_raider_surrender(cleared_raider_node_id: String) -> void:
	raider_node_ids.erase(cleared_raider_node_id)
	raider_ambush_triggered = false

	if raider_node_ids.is_empty():
		jumps_since_raider_cleared = 0
		jumps_since_last_raider_spawn = 0

	raider_destroyed.emit(cleared_raider_node_id)
	message_log_added.emit("Surrendered to raiders. Hull compromised.")


## Create an emergency path toward the player for the raider at the given index.
## Prefers reusing an existing nearby node to avoid map clutter.
func _create_emergency_path_for_raider(index: int) -> void:
	if index >= raider_node_ids.size():
		return
	var rid = raider_node_ids[index]
	if not nodes.has(rid) or not nodes.has(current_node_id):
		return

	var raider_node = nodes[rid]
	var player_node = nodes[current_node_id]
	var direction = (player_node.position - raider_node.position).normalized()
	var proposed_pos = raider_node.position + direction * 400.0

	const MAX_RAIDER_JUMP_DISTANCE: float = 500.0
	var best_existing_id: String = ""
	var best_dist_to_player: float = INF
	for node_id in nodes:
		if node_id == rid:
			continue
		var candidate = nodes[node_id]
		if candidate.position.distance_to(proposed_pos) > PROXIMITY_CONNECT_DISTANCE:
			continue
		if candidate.position.distance_to(raider_node.position) > MAX_RAIDER_JUMP_DISTANCE:
			continue
		var to_candidate = (candidate.position - raider_node.position).normalized()
		if to_candidate.dot(direction) <= 0.0:
			continue
		var dist_to_player = candidate.position.distance_to(player_node.position)
		if dist_to_player < best_dist_to_player:
			best_dist_to_player = dist_to_player
			best_existing_id = node_id

	var new_node_id: String
	if best_existing_id != "":
		var existing_node = nodes[best_existing_id]
		if not best_existing_id in raider_node.connections:
			raider_node.connections.append(best_existing_id)
		if not rid in existing_node.connections:
			existing_node.connections.append(rid)
		new_node_id = best_existing_id
		print("DEBUG VoyageManager: Raider %s emergency → existing node %s" % [rid, best_existing_id])
	else:
		var new_id = generator.generate_uuid()
		var new_node = NodeData.new(new_id, proposed_pos)
		new_node.node_type = EventManager.NodeType.EMPTY_SPACE
		new_node.biome_type = BiomeConfig.BiomeType.ASTEROID
		new_node.difficulty_grade = NodeData.DifficultyGrade.EASY
		nodes[new_id] = new_node
		if not new_id in raider_node.connections:
			raider_node.connections.append(new_id)
		if not rid in new_node.connections:
			new_node.connections.append(rid)
		_apply_proximity_connections_for_new_nodes([new_id])
		new_node_id = new_id
		print("DEBUG VoyageManager: Raider %s emergency → new node %s" % [rid, new_id])

	# Block landing on player node if another raider is already there
	if new_node_id == current_node_id and is_any_raider_on_player_node():
		print("DEBUG VoyageManager: Raider %s emergency blocked from player node" % rid)
		return

	raider_node_ids[index] = new_node_id
	var final_pos = nodes[new_node_id].position if nodes.has(new_node_id) else proposed_pos
	raider_moved.emit(final_pos, rid, new_node_id)

	if new_node_id == current_node_id:
		print("DEBUG VoyageManager: Raider %s emergency caught player at %s" % [rid, current_node_id])
		_trigger_raider_ambush()

#endregion
