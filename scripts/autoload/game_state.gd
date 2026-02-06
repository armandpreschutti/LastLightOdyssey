extends Node
## Global game state for Last Light Odyssey
## Manages colonists, resources, officers, and game progression

signal colonists_changed(new_value: int)
signal fuel_changed(new_value: int)
signal integrity_changed(new_value: int)
signal scrap_changed(new_value: int)
signal stability_changed(new_value: int)
signal officer_died(officer_type: String)
signal game_over(reason: String)
signal game_won(ending_type: String)

# Primary Statistics (Section 2.1 of GDD)
const MAX_COLONISTS: int = 1000

var colonist_count: int = 1000:
	set(value):
		colonist_count = clampi(value, 0, MAX_COLONISTS)
		colonists_changed.emit(colonist_count)
		if colonist_count <= 0:
			_trigger_game_over("colonists_depleted")

var fuel: int = 10:
	set(value):
		fuel = maxi(0, value)
		fuel_changed.emit(fuel)

var ship_integrity: int = 100:
	set(value):
		ship_integrity = clampi(value, 0, 100)
		integrity_changed.emit(ship_integrity)
		if ship_integrity <= 0:
			_trigger_game_over("ship_destroyed")

var scrap: int = 0:
	set(value):
		scrap = maxi(0, value)
		scrap_changed.emit(scrap)

# Cryo-Stability Timer (Section 4 of GDD)
var cryo_stability: int = 100:
	set(value):
		cryo_stability = clampi(value, 0, 100)
		stability_changed.emit(cryo_stability)

const STABILITY_LOSS_PER_TURN: int = 5
const COLONIST_LOSS_AT_ZERO_STABILITY: int = 10
const COLONIST_LOSS_DRIFT_MODE: int = 20

# Officer Roster (Section 3.2 of GDD)
enum OfficerType { SCOUT, TECH, MEDIC }

var officers: Dictionary = {
	"captain": {"alive": true, "deployed": false},
	"scout": {"alive": true, "deployed": false},
	"tech": {"alive": true, "deployed": false},
	"medic": {"alive": true, "deployed": false},
	"heavy": {"alive": true, "deployed": false},
}

# Game progression
var current_node_index: int = 0
var nodes_to_new_earth: int = 20
var visited_nodes: Array[int] = []  # Track which nodes have been visited
var node_types: Dictionary = {}  # Pre-rolled node types (node_id -> NodeType)
var node_biomes: Dictionary = {}  # Pre-rolled biome types for scavenge nodes (node_id -> BiomeType)
var is_in_tactical_mode: bool = false
var tactical_turn_count: int = 0


func _ready() -> void:
	pass


func reset_game() -> void:
	colonist_count = 1000
	fuel = 10
	ship_integrity = 100
	scrap = 0
	cryo_stability = 100
	current_node_index = 0
	visited_nodes.clear()
	node_types.clear()
	node_biomes.clear()
	tactical_turn_count = 0
	is_in_tactical_mode = false

	for officer_key in officers:
		officers[officer_key]["alive"] = true
		officers[officer_key]["deployed"] = false


func jump_to_next_node() -> void:
	# Legacy method - kept for compatibility, but prefer jump_to_node()
	jump_to_node(current_node_index + 1)


func jump_to_node(target_node_index: int, fuel_cost: int = 1) -> void:
	# Consume variable fuel for the jump
	if fuel >= fuel_cost:
		fuel -= fuel_cost
	else:
		# Not enough fuel: consume what we have, then drift mode for the rest
		var fuel_deficit = fuel_cost - fuel
		fuel = 0
		# Drift Mode: lose colonists due to life-support rationing (per fuel deficit)
		colonist_count -= COLONIST_LOSS_DRIFT_MODE * fuel_deficit
	
	# Mark current node as visited before moving
	if current_node_index >= 0 and not visited_nodes.has(current_node_index):
		visited_nodes.append(current_node_index)
	
	# Move to new node
	current_node_index = target_node_index
	
	# Check win condition
	if current_node_index >= nodes_to_new_earth - 1:  # Node 19 is New Earth
		_check_win_condition()


func process_tactical_turn() -> void:
	tactical_turn_count += 1
	cryo_stability -= STABILITY_LOSS_PER_TURN

	if cryo_stability <= 0:
		colonist_count -= COLONIST_LOSS_AT_ZERO_STABILITY


func enter_tactical_mode() -> void:
	is_in_tactical_mode = true
	tactical_turn_count = 0
	cryo_stability = 100


func exit_tactical_mode() -> void:
	is_in_tactical_mode = false


func kill_officer(officer_key: String) -> void:
	if officers.has(officer_key):
		officers[officer_key]["alive"] = false
		officer_died.emit(officer_key)

		if officer_key == "captain":
			_trigger_game_over("captain_died")


func is_officer_alive(officer_key: String) -> bool:
	if officers.has(officer_key):
		return officers[officer_key]["alive"]
	return false


func damage_ship(amount: int) -> void:
	ship_integrity -= amount


func repair_ship(amount: int) -> void:
	ship_integrity += amount


func _check_win_condition() -> void:
	if colonist_count >= 1000:
		game_won.emit("perfect")  # The Golden Age
	elif colonist_count >= 500:
		game_won.emit("good")     # The Hard Foundation
	elif colonist_count > 0:
		game_won.emit("bad")      # The Endangered Species


func _trigger_game_over(reason: String) -> void:
	game_over.emit(reason)


func get_ending_text(ending_type: String) -> String:
	match ending_type:
		"perfect":
			return "THE GOLDEN AGE\n1,000 colonists reached New Earth. Humanity will flourish."
		"good":
			return "THE HARD FOUNDATION\nEnough survived to rebuild. The road ahead is difficult, but hope remains."
		"bad":
			return "THE ENDANGERED SPECIES\nA mere handful reached New Earth. Humanity clings to existence by a thread."
		_:
			return ""


func get_game_over_text(reason: String) -> String:
	match reason:
		"colonists_depleted":
			return "EXTINCTION\nThe last colonist has perished. Humanity's light has been extinguished."
		"ship_destroyed":
			return "CATASTROPHIC FAILURE\nThe ship has been destroyed. All souls aboard are lost to the void."
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
		"version": 2,
		"colonist_count": colonist_count,
		"fuel": fuel,
		"ship_integrity": ship_integrity,
		"scrap": scrap,
		"current_node_index": current_node_index,
		"visited_nodes": visited_nodes,
		"node_types": node_types,
		"node_biomes": node_biomes,
		"officers": officers,
		"star_map_data": saved_star_map_data,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()
	
	print("Game saved successfully!")
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
	
	# Restore game state (avoid triggering setters that emit signals during load)
	colonist_count = int(save_data.get("colonist_count", 1000))
	fuel = int(save_data.get("fuel", 10))
	ship_integrity = int(save_data.get("ship_integrity", 100))
	scrap = int(save_data.get("scrap", 0))
	current_node_index = int(save_data.get("current_node_index", 0))
	
	# Restore visited nodes (JSON parses arrays as generic arrays)
	visited_nodes.clear()
	var loaded_visited = save_data.get("visited_nodes", [])
	for node_id in loaded_visited:
		visited_nodes.append(int(node_id))
	
	# Restore node types
	node_types.clear()
	var loaded_types = save_data.get("node_types", {})
	for key in loaded_types.keys():
		node_types[int(key)] = int(loaded_types[key])
	
	# Restore node biomes
	node_biomes.clear()
	var loaded_biomes = save_data.get("node_biomes", {})
	for key in loaded_biomes.keys():
		node_biomes[int(key)] = int(loaded_biomes[key])
	
	# Restore officers
	var loaded_officers = save_data.get("officers", {})
	for officer_key in loaded_officers.keys():
		if officers.has(officer_key):
			officers[officer_key]["alive"] = loaded_officers[officer_key].get("alive", true)
			officers[officer_key]["deployed"] = loaded_officers[officer_key].get("deployed", false)
	
	# Restore star map data
	saved_star_map_data = save_data.get("star_map_data", {})
	
	# Reset tactical state
	cryo_stability = 100
	tactical_turn_count = 0
	is_in_tactical_mode = false
	
	print("Game loaded successfully!")
	return true


## Check if a save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted!")


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
