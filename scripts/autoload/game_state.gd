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
signal officer_injured(officer_key: String)
signal game_over(reason: String)
signal game_won(ending_type: String)
signal developer_mode_changed(enabled: bool)

# --- Ability & Officer Definitions ---
const OFFICER_COLOR = {
	"captain": Color(1.0, 0.69, 0.0),
	"scout":   Color(0.2, 1.0, 0.5),
	"tech":    Color(0.4, 0.9, 1.0),
	"medic":   Color(1.0, 0.5, 0.8),
	"heavy":   Color(1.0, 0.4, 0.3),
	"sniper":  Color(0.6, 0.55, 0.7),
}

# Ability definitions: id → {name, desc, level, slot}
const ABILITY_DEFS: Dictionary = {
	"execute":            {"name": "Execute",            "desc": "Guaranteed kill on any enemy within 4 tiles that is below 50% HP. 2-turn cooldown.",                                                            "level": 1, "slot": "base"},
	"overwatch":          {"name": "Overwatch",          "desc": "Take a reaction shot at the first enemy that moves in Line of Sight. Guaranteed hit. 2-turn cooldown.",                                          "level": 1, "slot": "base"},
	"turret":             {"name": "Turret",             "desc": "Deploy an auto-firing sentry on an adjacent tile. Lasts 3 turns. 2-turn cooldown.",                                                              "level": 1, "slot": "base"},
	"patch":              {"name": "Patch",              "desc": "Heal yourself or an ally within 3 tiles for 62.5% Max HP. 2-turn cooldown.",                                                                    "level": 1, "slot": "base"},
	"charge":             {"name": "Charge",             "desc": "Rush an enemy within 4 tiles. Instant-kills basic enemies; deals 2x Base Damage to heavy enemies. 2-turn cooldown.",                             "level": 1, "slot": "base"},
	"precision_shot":     {"name": "Precision Shot",     "desc": "Guaranteed hit on any visible enemy. Deals 2x Base Damage. 2-turn cooldown.",                                                                   "level": 1, "slot": "base"},

	# Captain
	"lead_by_example":    {"name": "Lead by Example",    "desc": "When the Captain kills an enemy, all other squad members gain +1 AP on their next turn.",                                                       "level": 2, "slot": "a"},
	"coordinate_fire":    {"name": "Coordinate Fire",    "desc": "Mark a target. All allies gain +20% Accuracy and +25% Critical Chance against that target for 1 turn. (1 AP, active)",                        "level": 2, "slot": "b"},
	"warlord":            {"name": "Warlord",            "desc": "Execute no longer has a cooldown. Chain multiple executions in a single turn if you have enough AP.",                                            "level": 3, "slot": "a"},
	"no_one_left_behind": {"name": "No One Left Behind", "desc": "If an ally within 5 tiles takes lethal damage, they survive with 1 HP and become immune to all damage for 1 turn. (Once per ally per mission)", "level": 3, "slot": "b"},
	"command_presence":   {"name": "Command Presence",   "desc": "All allies within 4 tiles gain +10% Accuracy and +15% Critical Chance. The Captain gains +10 Defense per nearby ally.",                          "level": 3, "slot": "c"},
	# Scout
	"hit_and_run":        {"name": "Hit & Run",          "desc": "If the Scout moves and shoots in the same turn, they immediately gain +3 Movement Points to retreat or reposition.",                             "level": 2, "slot": "a"},
	"deep_scanner":       {"name": "Deep Scanner",       "desc": "Reveals all enemies in a large radius (15 tiles) for 1 turn, even through walls. (0 AP, 3-turn cooldown)",                                      "level": 2, "slot": "b"},
	"killzone":           {"name": "Killzone",           "desc": "Overwatch now triggers on every enemy that moves in Line of Sight during the enemy turn, not just the first.",                                   "level": 3, "slot": "a"},
	"phantom":            {"name": "Phantom",            "desc": "Become Invisible for 2 turns. First attack from invisibility deals +100% Damage but reveals you. (1 AP, active)",                               "level": 3, "slot": "b"},
	"untouchable":        {"name": "Untouchable",        "desc": "If you kill an enemy during your turn, the next attack against you during the enemy turn is guaranteed to Miss.",                                 "level": 3, "slot": "c"},
	# Tech
	"combat_engineer":    {"name": "Combat Engineer",    "desc": "Turrets gain a 20 HP shield barrier and their duration is extended to 5 turns.",                                                                 "level": 2, "slot": "a"},
	"sapper":             {"name": "Sapper",             "desc": "Throw a localized EMP grenade. Stuns robotic enemies and disables weapons in a 3×3 area for 1 turn. (1 AP, active)",                            "level": 2, "slot": "b"},
	"twin_link":          {"name": "Twin-Link",          "desc": "You can have 2 Turrets active simultaneously. Deploying a second turret does not destroy the first.",                                            "level": 3, "slot": "a"},
	"overclock":          {"name": "Overclock",          "desc": "Target your active Turret. It fires 3 times at random enemies, then self-destructs with 20 area damage. (0 AP)",                                 "level": 3, "slot": "b"},
	"haywire_protocol":   {"name": "Haywire Protocol",   "desc": "Hack a robotic enemy. It fights for you for 2 turns, then shuts down for 1 turn. (1 AP, 4-turn cooldown)",                                      "level": 3, "slot": "c"},
	# Medic
	"adrenaline_patch":   {"name": "Adrenaline Patch",   "desc": "Patch also grants the target +2 Movement and +15% Accuracy for 2 turns.",                                                                       "level": 2, "slot": "a"},
	"field_surgeon":      {"name": "Field Surgeon",      "desc": "Automatically stabilize any ally who drops to 0 HP within 4 tiles, preventing death (unless Medic is also killed).",                            "level": 2, "slot": "b"},
	"miracle_worker":     {"name": "Miracle Worker",     "desc": "Global Heal: instantly restore 50% HP to all squad members regardless of distance. (2 AP, once per mission)",                                    "level": 3, "slot": "a"},
	"toxicologist":       {"name": "Toxicologist",       "desc": "Attacks apply Poison (5 DMG/turn, -20% Aim). Patch removes all status effects from allies.",                                                     "level": 3, "slot": "b"},
	"stim_injector":      {"name": "Stim Injector",      "desc": "Inject an ally: they gain +2 AP and take -50% damage for 1 turn. (1 AP, 3-turn cooldown)",                                                      "level": 3, "slot": "c"},
	# Heavy
	"bulldozer":          {"name": "Bulldozer",          "desc": "Charge destroys all cover in its path. Gain +20 Armor after charging.",                                                                          "level": 2, "slot": "a"},
	"suppression_fire":   {"name": "Suppression Fire",   "desc": "Deal light damage to all enemies in a cone and remove their ability to move next turn (Pin Down). (2 AP, active)",                               "level": 2, "slot": "b"},
	"juggernaut":         {"name": "Juggernaut",         "desc": "Immune to Critical Hits and Knockback. If you end your turn without attacking, regenerate 15% Max HP.",                                          "level": 3, "slot": "a"},
	"rocket_salvo":       {"name": "Rocket Salvo",       "desc": "Launch a micro-missile swarm at a 3×3 area: 40 area damage and destroys all cover. (2 AP, 3-turn cooldown)",                                    "level": 3, "slot": "b"},
	"intimidate":         {"name": "Intimidate",         "desc": "Enemies within 3 tiles suffer -20% Accuracy and cannot use Overwatch or Reaction Fire.",                                                         "level": 3, "slot": "c"},
	# Sniper
	"damn_good_ground":   {"name": "Damn Good Ground",   "desc": "If you have not moved this turn, gain +15% Critical Chance and +2 Sight Range.",                                                                 "level": 2, "slot": "a"},
	"snap_shot":          {"name": "Snap Shot",          "desc": "Precision Shot has no cooldown — move and shoot or fire multiple precision shots in the same turn.",                                              "level": 2, "slot": "b"},
	"serial":             {"name": "Serial",             "desc": "Killing an enemy with your main weapon fully refunds your Action Points. Chain kills until you miss or run out of targets.",                     "level": 3, "slot": "a"},
	"apex_predator":      {"name": "Apex Predator",      "desc": "Deal +100% damage against enemies at full health. Designed for one-shotting high-value targets.",                                                 "level": 3, "slot": "b"},
	"double_tap":         {"name": "Double Tap",         "desc": "Fire two shots at the same target: second shot has -15% accuracy penalty. (1 AP, 2-turn cooldown)",                                              "level": 3, "slot": "c"},
}

# Per-officer ability lists: [L1, L2-A, L2-B, L3-A, L3-B, L3-C]
const OFFICER_ABILITIES: Dictionary = {
	"captain": ["execute", "lead_by_example", "coordinate_fire", "warlord", "no_one_left_behind", "command_presence"],
	"scout":   ["overwatch", "hit_and_run",     "deep_scanner",    "killzone", "phantom",            "untouchable"],
	"tech":    ["turret", "combat_engineer", "sapper",          "twin_link","overclock",           "haywire_protocol"],
	"medic":   ["patch", "adrenaline_patch","field_surgeon",   "miracle_worker","toxicologist",   "stim_injector"],
	"heavy":   ["charge", "bulldozer",       "suppression_fire","juggernaut","rocket_salvo",       "intimidate"],
	"sniper":  ["precision_shot", "damn_good_ground","snap_shot",       "serial",   "apex_predator",       "double_tap"],
}

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

## Officer roster — values are OfficerData instances, populated in _init_officers()
var officers: Dictionary = {}

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
	_init_officers()


## Create fresh OfficerData for all 6 officers
func _init_officers() -> void:
	for key in ["captain", "scout", "tech", "medic", "heavy", "sniper"]:
		var od = OfficerData.new()
		od.initialize(key)
		# Unlock Level 1 ability by default
		var abilities = OFFICER_ABILITIES.get(key, [])
		if not abilities.is_empty():
			od.unlock_ability(abilities[0])
		officers[key] = od


## Get OfficerData for a given officer key
func get_officer(key: String) -> OfficerData:
	return officers.get(key, null)


## Returns true if officer is alive AND not injured (available for deployment)
func is_officer_available(key: String) -> bool:
	var od: OfficerData = get_officer(key)
	return od != null and od.is_available()


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

	_init_officers()


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
	var od: OfficerData = get_officer(officer_key)
	if od:
		od.alive = false
		od.current_hp = 0
		officer_died.emit(officer_key)

	# Check for crew wipe game over
	var any_alive = false
	for key in officers:
		var o: OfficerData = officers[key]
		if o.alive:
			any_alive = true
			break

	if not any_alive:
		_trigger_game_over("crew_wipe")


func is_officer_alive(officer_key: String) -> bool:
	var od: OfficerData = get_officer(officer_key)
	return od != null and od.alive


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
	# Serialize officer progression
	var officers_data: Dictionary = {}
	for key in officers:
		officers_data[key] = (officers[key] as OfficerData).to_dict()

	var save_data = {
		"version": 6, # Voyage 2.0 + RPG layer (Phase 3/4)
		"fuel": fuel,
		"ship_integrity": ship_integrity,
		"scrap": scrap,
		"cash": cash,
		"intel": intel,
		"data_logs": data_logs,
		"officers": officers_data,
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

	# Restore officers (must be initialised first so keys exist)
	_init_officers()
	var loaded_officers = save_data.get("officers", {})
	for officer_key in officers.keys():
		var od: OfficerData = get_officer(officer_key)
		if loaded_officers.has(officer_key):
			if version >= 6:
				# Full v6 restore
				od.from_dict(loaded_officers[officer_key])
			else:
				# v5 migration: only restore alive flag, reset HP to full
				od.alive = loaded_officers[officer_key].get("alive", true)
				od.current_hp = od.max_hp
	
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
	var current_node = VoyageManager.get_current_node()
	if current_node and current_node.difficulty_multiplier > 0:
		return current_node.difficulty_multiplier
		
	# Fallback to old distance-based logic if node data is missing multiplier
	var distance = current_node.position.length() if current_node else 0.0
	var steps = distance / 400.0
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
