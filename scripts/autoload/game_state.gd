extends Node
## Global game state for Last Light Odyssey
## Manages resources, officers, and game progression

signal fuel_changed(new_value: int)
signal integrity_changed(new_value: int)
signal scrap_changed(new_value: int)
signal cash_changed(new_value: int)
signal intel_changed(new_value: int)
signal data_logs_changed(new_value: int)
signal officer_died(officer_type: String)
signal game_over(reason: String)
signal game_won(ending_type: String)
signal developer_mode_changed(enabled: bool)

var developer_mode: bool = false:
	set(value):
		developer_mode = value
		developer_mode_changed.emit(developer_mode)

# Primary Statistics (Voyage 2.0 Economy)
var fuel: int = 10:
	set(value):
		if developer_mode and value < fuel:
			value = fuel
		fuel = maxi(0, value)
		fuel_changed.emit(fuel)

var ship_integrity: int = 100:
	set(value):
		if developer_mode and value < ship_integrity:
			value = ship_integrity
		ship_integrity = clampi(value, 0, 100)
		integrity_changed.emit(ship_integrity)
		if ship_integrity <= 0:
			_trigger_game_over("ship_destroyed")

var scrap: int = 25:
	set(value):
		if developer_mode and value < scrap:
			value = scrap
		scrap = maxi(0, value)
		scrap_changed.emit(scrap)

var cash: int = 100:
	set(value):
		if developer_mode and value < cash:
			value = cash
		cash = maxi(0, value)
		cash_changed.emit(cash)

var intel: int = 0:
	set(value):
		if developer_mode and value < intel:
			value = intel
		intel = maxi(0, value)
		intel_changed.emit(intel)

var data_logs: int = 0:
	set(value):
		if developer_mode and value < data_logs:
			value = data_logs
		data_logs = maxi(0, value)
		data_logs_changed.emit(data_logs)

const SHIP_INTEGRITY_LOSS_PER_JUMP: int = 1  # Ship takes minor damage from each jump
const HULL_DAMAGE_DRIFT_MODE: int = 5 # Extra damage when drafting without fuel
const HULL_DAMAGE_PER_TURN: int = 1 # Ship takes damage each tactical turn

# Officer Roster
enum OfficerType { SCOUT, TECH, MEDIC }
# ... (rest of officer logic skipped)

# ...

func process_tactical_turn() -> void:
	tactical_turn_count += 1
	# Ship takes structural damage over time during tactical missions
	damage_ship(HULL_DAMAGE_PER_TURN)

var officers: Dictionary = {
	"captain": {"alive": true, "deployed": false},
	"scout": {"alive": true, "deployed": false},
	"tech": {"alive": true, "deployed": false},
	"medic": {"alive": true, "deployed": false},
	"heavy": {"alive": true, "deployed": false},
	"sniper": {"alive": true, "deployed": false},
}

# Game progression
# REFACTORED: Map state is now handled by VoyageManager (infinite graph system).
# The following properties have been removed to prevent usage:
# - current_node_index
# - nodes_to_new_earth
# - visited_nodes, travel_history
# - node_types, node_biomes
# Use VoyageManager.get_current_node() and related methods instead.

var is_in_tactical_mode: bool = false
var tactical_turn_count: int = 0

# Cumulative mission statistics (tracked across entire voyage)
var total_fuel_collected: int = 0
var total_scrap_collected: int = 0
var total_enemies_killed: int = 0
var total_missions_completed: int = 0
var total_tactical_turns: int = 0


func _ready() -> void:
	pass


func reset_game() -> void:
	fuel = 10
	ship_integrity = 100
	scrap = 25
	cash = 100
	intel = 0
	data_logs = 0
	
	# Reset cumulative stats
	total_fuel_collected = 0
	total_scrap_collected = 0
	total_enemies_killed = 0
	total_missions_completed = 0
	total_tactical_turns = 0

	# Reset Voyage Manager
	if VoyageManager:
		VoyageManager._initialize_voyage()

	for officer_key in officers:
		officers[officer_key]["alive"] = true
		officers[officer_key]["deployed"] = false


## Add mission stats to cumulative totals (called after successful missions)
func add_mission_stats(fuel_collected: int, scrap_collected: int, enemies_killed: int, turns_taken: int) -> void:
	total_fuel_collected += fuel_collected
	total_scrap_collected += scrap_collected
	total_enemies_killed += enemies_killed
	total_tactical_turns += turns_taken
	total_missions_completed += 1


func jump_to_node(_target_node_index: int, _fuel_cost: int = 1) -> void:
	# DEPRECATED - Use VoyageManager.attempt_jump()
	pass


func enter_tactical_mode() -> void:
	is_in_tactical_mode = true
	tactical_turn_count = 0


func exit_tactical_mode() -> void:
	is_in_tactical_mode = false


func kill_officer(officer_key: String) -> void:
	if officers.has(officer_key):
		officers[officer_key]["alive"] = false
		officer_died.emit(officer_key)
	
	# Check for crew wipe game over
	var any_alive = false
	for key in officers:
		if officers[key]["alive"]:
			any_alive = true
			break
	
	if not any_alive:
		_trigger_game_over("crew_wipe") 


func is_officer_alive(officer_key: String) -> bool:
	if officers.has(officer_key):
		return officers[officer_key]["alive"]
	return false


func damage_ship(amount: int) -> void:
	ship_integrity -= amount


func repair_ship(amount: int) -> void:
	ship_integrity += amount


func _check_win_condition() -> void:
	# Placeholder for new Victory Condition (Story Mission)
	game_won.emit("good")


func _trigger_game_over(reason: String) -> void:
	game_over.emit(reason)


func get_ending_text(ending_type: String) -> String:
	match ending_type:
		"perfect":
			return "THE GOLDEN AGE\nHumanity will flourish."
		"good":
			return "THE HARD FOUNDATION\nEnough survived to rebuild."
		"bad":
			return "THE ENDANGERED SPECIES\nHumanity clings to existence."
		_:
			return ""


func get_game_over_text(reason: String) -> String:
	match reason:
		"ship_destroyed":
			return "CATASTROPHIC FAILURE\nThe ship has been destroyed. All souls aboard are lost to the void."
		"crew_wipe":
			return "MISSION FAILED\nThe entire crew has been lost. The ship drifts silently in the dark."
		"captain_died":
			return "LEADERSHIP LOST\nThe Captain has fallen. Without leadership, the mission cannot continue."
		_:
			return "GAME OVER"


#region Save/Load System
const SAVE_PATH = "user://savegame.dat"

## Star map data (saved to preserve the exact node layout)
var saved_star_map_data: Dictionary = {}


## Save the current game state to disk
func save_game() -> bool:
	var save_data = {
		"version": 5, # Voyage 2.0 (Infinite Map)
		"fuel": fuel,
		"ship_integrity": ship_integrity,
		"scrap": scrap,
		"cash": cash,
		"intel": intel,
		"data_logs": data_logs,
		"officers": officers,
		# VoyageManager Data
		"voyage_data": VoyageManager.get_save_data(),
		# Cumulative mission stats (v3)
		"total_fuel_collected": total_fuel_collected,
		"total_scrap_collected": total_scrap_collected,
		"total_enemies_killed": total_enemies_killed,
		"total_missions_completed": total_missions_completed,
		"total_tactical_turns": total_tactical_turns,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()
	
	return true


## Load a saved game from disk
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("No save file found!")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return false
	
	var save_data = json.data
	if not save_data is Dictionary:
		push_error("Invalid save file format!")
		return false
	

	
	# Version Check
	var version = int(save_data.get("version", 0))
	if version < 5:
		# Wipe save for new version compatibility
		print("Save version %d is too old (requires 5). Deleting save..." % version)
		delete_save()
		return false
	
	# Restore game state
	fuel = int(save_data.get("fuel", 10))
	ship_integrity = int(save_data.get("ship_integrity", 100))
	scrap = int(save_data.get("scrap", 0))
	cash = int(save_data.get("cash", 100))
	intel = int(save_data.get("intel", 0))
	data_logs = int(save_data.get("data_logs", 0))
	
	# Restore VoyageManager Data
	if save_data.has("voyage_data"):
		VoyageManager.load_save_data(save_data["voyage_data"])
	
	# Restore officers
	var loaded_officers = save_data.get("officers", {})
	for officer_key in loaded_officers.keys():
		if officers.has(officer_key):
			officers[officer_key]["alive"] = loaded_officers[officer_key].get("alive", true)
			officers[officer_key]["deployed"] = loaded_officers[officer_key].get("deployed", false)
	
	# Restore cumulative mission stats
	total_fuel_collected = int(save_data.get("total_fuel_collected", 0))
	total_scrap_collected = int(save_data.get("total_scrap_collected", 0))
	total_enemies_killed = int(save_data.get("total_enemies_killed", 0))
	total_missions_completed = int(save_data.get("total_missions_completed", 0))
	total_tactical_turns = int(save_data.get("total_tactical_turns", 0))
	
	# Reset tactical state
	tactical_turn_count = 0
	is_in_tactical_mode = false
	
	return true


## Check if a save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Store star map data for saving
func store_star_map_data(generator: StarMapGenerator) -> void:
	saved_star_map_data.clear()
	var nodes_data = []
	
	for node in generator.nodes:
		var node_data = {
			"id": node.id,
			"column": node.column,
			"row": node.row,
			"connections": node.connections,
			"node_type": node.node_type,
			"biome_type": node.biome_type,
			"connection_fuel_costs": node.connection_fuel_costs,
		}
		nodes_data.append(node_data)
	
	saved_star_map_data["nodes"] = nodes_data


## Check if we have saved star map data
func has_saved_star_map_data() -> bool:
	return saved_star_map_data.has("nodes") and saved_star_map_data["nodes"].size() > 0


## Get mission difficulty multiplier based on current node index
## Returns a multiplier (1.0 = base difficulty, increases as player progresses)
## Formula: 1.0 + (current_node_index / nodes_to_new_earth) * difficulty_scale_factor
## This gives: 1.0x at start (node 0), ~2.5x at end (node 49)
## Reduced scaling in final stages (nodes 35+) to decrease difficulty
func get_mission_difficulty() -> float:
	const _DIFFICULTY_SCALE_FACTOR: float = 1.5
	const _FINAL_STAGE_START: int = 35  # Nodes 35+ get reduced scaling
	const _FINAL_STAGE_SCALE_REDUCTION: float = 0.4  # Reduce scaling by 40% in final stages
	
	# New infinite map difficulty scaling
	# Base off distance from origin (manhattan or euclidean)
	var current_node = VoyageManager.get_current_node()
	var distance = current_node.position.length() if current_node else 0.0
	
	# Approximate steps (avg node distance ~400 units)
	var steps = distance / 400.0
	
	# Roughly every 10 steps = +0.5 difficulty?
	return 1.0 + (steps * 0.05)


## Recreate a StarMapGenerator from saved data
func restore_star_map_generator() -> StarMapGenerator:
	if not has_saved_star_map_data():
		return null
	
	var generator = StarMapGenerator.new()
	generator.nodes.clear()
	
	var nodes_data = saved_star_map_data["nodes"]
	for node_dict in nodes_data:
		var node = StarMapGenerator.MapNode.new(
			int(node_dict["id"]),
			int(node_dict["column"]),
			int(node_dict["row"])
		)
		
		# Restore connections
		for conn_id in node_dict["connections"]:
			node.connections.append(int(conn_id))
		
		node.node_type = int(node_dict["node_type"])
		node.biome_type = int(node_dict.get("biome_type", -1))
		
		# Restore fuel costs
		var fuel_costs = node_dict.get("connection_fuel_costs", {})
		for key in fuel_costs.keys():
			node.connection_fuel_costs[int(key)] = int(fuel_costs[key])
		
		generator.nodes.append(node)
	
	return generator
#endregion
