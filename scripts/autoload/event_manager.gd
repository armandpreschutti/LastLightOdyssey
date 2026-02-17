extends Node
## Random Event Manager for Last Light Odyssey
## Handles event rolling and resolution (Section 2.3 of GDD)

signal event_triggered(event_data: Dictionary)
signal event_resolved(result: String)

enum NodeType { EMPTY_SPACE, SCAVENGE_SITE, TRADING_OUTPOST, WORMHOLE }

# Event table - roll 1d10
var random_events: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Solar Flare",
		"description": "A massive solar flare threatens the ship's electronics.",
		"integrity_loss": 15,
		"specialist_mitigation": "tech",
		"mitigated_integrity_loss": 5,
		"mitigation_scrap_cost": 18,
	},
	{
		"id": 2,
		"name": "Meteor Shower",
		"description": "The ship passes through a dense meteor field.",
		"integrity_loss": 25,
		"specialist_mitigation": "scout",
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 22,
	},
	{
		"id": 3,
		"name": "Disease Outbreak",
		"description": "A mysterious illness spreads through the cryo chambers.",
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_integrity_loss": 0,
		"mitigation_scrap_cost": 30,
	},
	{
		"id": 4,
		"name": "System Malfunction",
		"description": "Critical ship systems begin to fail.",
		"integrity_loss": 20,
		"specialist_mitigation": "tech",
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 15,
	},
	{
		"id": 5,
		"name": "Pirate Ambush",
		"description": "Raiders emerge from a nearby asteroid field.",
		"integrity_loss": 30,
		"specialist_mitigation": "heavy",
		"mitigated_integrity_loss": 15,
		"mitigation_scrap_cost": 28,
	},
	{
		"id": 6,
		"name": "Space Debris Field",
		"description": "The ship navigates through a field of wreckage from past conflicts.",
		"integrity_loss": 20,
		"specialist_mitigation": "scout",
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 20,
	},
	{
		"id": 7,
		"name": "Sensor Ghost",
		"description": "False readings on the sensors cause momentary alarm, but nothing materializes.",
		"integrity_loss": 0,
		"specialist_mitigation": "",
		"mitigation_scrap_cost": 0,
	},
	{
		"id": 8,
		"name": "Radiation Storm",
		"description": "Intense radiation bombards the ship.",
		"integrity_loss": 10,
		"specialist_mitigation": "tech",
		"mitigated_integrity_loss": 5,
		"mitigation_scrap_cost": 25,
	},
	{
		"id": 9,
		"name": "Cryo Pod Failure",
		"description": "A section of cryo pods experiences catastrophic failure.",
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_integrity_loss": 0,
		"mitigation_scrap_cost": 35,
	},
	{
		"id": 10,
		"name": "Clear Skies",
		"description": "The journey continues without incident.",
		"integrity_loss": 0,
		"specialist_mitigation": "",
		"mitigation_scrap_cost": 0,
	},
]


func roll_random_event() -> Dictionary:
	var roll = randi_range(0, 9)
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
		"fuel_change": 0,
		"scrap_change": 0,
		"mitigated": false,
	}

	var specialist_key = event.get("specialist_mitigation", "")
	var can_mitigate = specialist_key != "" and use_specialist and GameState.is_officer_alive(specialist_key)

	if can_mitigate:
		result["mitigated"] = true
		result["integrity_change"] = -event.get("mitigated_integrity_loss", event.get("integrity_loss", 0))
		# Scrap cost for mitigation removed per user request
		result["scrap_change"] = 0
	else:
		result["integrity_change"] = -event.get("integrity_loss", 0)

	# Add any gains
	result["fuel_change"] = event.get("fuel_gain", 0)
	result["scrap_change"] += event.get("scrap_gain", 0)

	# Apply changes to game state
	GameState.ship_integrity += result["integrity_change"]
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
