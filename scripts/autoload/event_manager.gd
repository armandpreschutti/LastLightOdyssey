extends Node
## Random Event Manager for Last Light Odyssey
## Handles event rolling and resolution (Section 2.3 of GDD)

signal event_triggered(event_data: Dictionary)
signal event_resolved(result: String)

enum NodeType { EMPTY_SPACE, SCAVENGE_SITE, TRADING_OUTPOST, WORMHOLE }

# Event table - roll 1d10
# Event table - expanded to 20 entries
var random_events: Array[Dictionary] = [
	{ "id": 1, "name": "Event 1", "integrity_change_pct": -15, "specialist_mitigation": "tech", "mitigated_integrity_change_pct": -5 },
	{ "id": 2, "name": "Event 2", "integrity_change_pct": -25, "specialist_mitigation": "scout", "mitigated_integrity_change_pct": -10 },
	{ "id": 3, "name": "Event 3", "integrity_change_pct": -20, "specialist_mitigation": "medic", "mitigated_integrity_change_pct": -5 },
	{ "id": 4, "name": "Event 4", "integrity_change_pct": -20, "specialist_mitigation": "tech", "mitigated_integrity_change_pct": -10 },
	{ "id": 5, "name": "Event 5", "integrity_change_pct": -30, "specialist_mitigation": "heavy", "mitigated_integrity_change_pct": -15 },
	{ "id": 6, "name": "Event 6", "cash_change": -50, "integrity_change_pct": -10, "specialist_mitigation": "scout", "mitigated_integrity_change_pct": 0 },
	{ "id": 7, "name": "Event 7", "fuel_change": -2, "scrap_change": -15 },
	{ "id": 8, "name": "Event 8", "integrity_change_pct": -10, "specialist_mitigation": "tech", "mitigated_integrity_change_pct": -5 },
	{ "id": 9, "name": "Event 9", "cash_change": -75 },
	{ "id": 10, "name": "Event 10", "integrity_change_pct": 0 }, # Clear skies
	{ "id": 11, "name": "Event 11", "cash_change": 100 },
	{ "id": 12, "name": "Event 12", "fuel_change": 3 },
	{ "id": 13, "name": "Event 13", "integrity_change_pct": 15 },
	{ "id": 14, "name": "Event 14", "scrap_change": 40 },
	{ "id": 15, "name": "Event 15", "cash_change": 50, "fuel_change": 1 },
	{ "id": 16, "name": "Event 16", "fuel_change": 2, "integrity_change_pct": 10 },
	{ "id": 17, "name": "Event 17", "scrap_change": 20, "cash_change": 30 },
	{ "id": 18, "name": "Event 18", "integrity_change_pct": 10, "scrap_change": 15 },
	{ "id": 19, "name": "Event 19", "cash_change": 40, "fuel_change": 1, "scrap_change": 10 },
	{ "id": 20, "name": "Event 20", "cash_change": 20, "fuel_change": 1, "integrity_change_pct": 5, "scrap_change": 5 },
]


func roll_random_event() -> Dictionary:
	var roll = randi_range(0, 19)
	return random_events[roll]


## Get mitigation cost multiplier based on voyage progress
## Returns a multiplier that scales from 1.0 at node 0 to ~2.5 at node 49
## Uses similar scaling pattern to mission difficulty
func get_mitigation_cost_multiplier() -> float:
	const COST_SCALE_FACTOR: float = 0.5
	const DISTANCE_UNIT: float = 400.0
	
	# Calculate progress based on distance cycles
	var current_node = VoyageManager.get_current_node()
	var distance = current_node.position.length() if current_node else 0.0
	var cycle = distance / DISTANCE_UNIT
	
	# Scale cost: Base 1.0 + (0.5 * cycle)
	# e.g. Cycle 0 = 1.0x, Cycle 5 = 3.5x
	# Adjust formula to match desired difficulty curve
	var multiplier: float = 1.0 + (cycle * 0.1) # gentler slope: +10% cost per cycle
	
	return multiplier


func resolve_event(event: Dictionary, use_specialist: bool = false) -> Dictionary:
	var result = {
		"integrity_change": 0,
		"cash_change": 0,
		"fuel_change": 0,
		"scrap_change": 0,
		"mitigated": false,
	}

	var specialist_key = event.get("specialist_mitigation", "")
	var can_mitigate = specialist_key != "" and use_specialist and GameState.is_officer_alive(specialist_key)

	if can_mitigate:
		result["mitigated"] = true
		var integrity_pct = event.get("mitigated_integrity_change_pct", event.get("integrity_change_pct", 0))
		result["integrity_change"] = int(integrity_pct) # Assuming max integrity is 100
	else:
		var integrity_pct = event.get("integrity_change_pct", 0)
		result["integrity_change"] = int(integrity_pct)

	# Handle other resource changes
	result["cash_change"] = event.get("cash_change", 0)
	result["fuel_change"] = event.get("fuel_change", 0)
	result["scrap_change"] = event.get("scrap_change", 0)

	# Apply changes to game state
	GameState.ship_integrity += result["integrity_change"]
	GameState.cash += result["cash_change"]
	GameState.fuel += result["fuel_change"]
	GameState.scrap += result["scrap_change"]

	# warning-ignore: INCOMPATIBLE_TERNARY
	event_resolved.emit("mitigated" if result["mitigated"] else "standard")

	return result


func can_mitigate_event(_event: Dictionary) -> bool:
	return false


func get_node_type(node_index: int = -1) -> NodeType:
	# If node_index is provided and refers to current node, we can get type from VoyageManager
	var current_node = VoyageManager.get_current_node()
	if node_index >= 0 and current_node and node_index == int(current_node.position.length() / 400.0): # Approximation
		return current_node.node_type
	
	# If we can't determine it dynamically, fall back to random roll (legacy behavior)
	
	# Otherwise roll randomly (legacy behavior)
	# 50% chance for Empty Space (1-5), 50% chance for Scavenge Site (6-10)
	var roll = randi_range(1, 10)
	if roll <= 5:
		return NodeType.EMPTY_SPACE
	else:
		return NodeType.SCAVENGE_SITE
