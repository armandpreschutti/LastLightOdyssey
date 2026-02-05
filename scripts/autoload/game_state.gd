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
var colonist_count: int = 1000:
	set(value):
		colonist_count = maxi(0, value)
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
}

# Game progression
var current_node_index: int = 0
var nodes_to_new_earth: int = 20
var visited_nodes: Array[int] = []  # Track which nodes have been visited
var node_types: Dictionary = {}  # Pre-rolled node types (node_id -> NodeType)
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
