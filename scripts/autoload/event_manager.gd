extends Node
## Random Event Manager for Last Light Odyssey
## Handles event rolling and resolution (Section 2.3 of GDD)

signal event_triggered(event_data: Dictionary)
signal event_resolved(result: String)

enum NodeType { EMPTY_SPACE, SCAVENGE_SITE, TRADING_OUTPOST }

# Event table - roll 1d10
var random_events: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Solar Flare",
		"description": "A massive solar flare threatens the ship's electronics.",
		"colonist_loss": 50,
		"integrity_loss": 10,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 10,
		"mitigated_integrity_loss": 0,
	},
	{
		"id": 2,
		"name": "Meteor Shower",
		"description": "The ship passes through a dense meteor field.",
		"colonist_loss": 30,
		"integrity_loss": 20,
		"specialist_mitigation": "scout",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 5,
	},
	{
		"id": 3,
		"name": "Disease Outbreak",
		"description": "A mysterious illness spreads through the cryo chambers.",
		"colonist_loss": 80,
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_colonist_loss": 20,
		"mitigated_integrity_loss": 0,
	},
	{
		"id": 4,
		"name": "System Malfunction",
		"description": "Critical ship systems begin to fail.",
		"colonist_loss": 20,
		"integrity_loss": 15,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 5,
	},
	{
		"id": 5,
		"name": "Pirate Ambush",
		"description": "Raiders emerge from a nearby asteroid field.",
		"colonist_loss": 40,
		"integrity_loss": 25,
		"specialist_mitigation": "scout",
		"mitigated_colonist_loss": 10,
		"mitigated_integrity_loss": 10,
	},
	{
		"id": 6,
		"name": "Supply Cache",
		"description": "You discover a drifting supply cache from a lost vessel.",
		"colonist_loss": 0,
		"integrity_loss": 0,
		"fuel_gain": 2,
		"scrap_gain": 15,
		"specialist_mitigation": "",
	},
	{
		"id": 7,
		"name": "Distress Signal",
		"description": "A faint distress signal beckons. Rescue attempt?",
		"colonist_loss": 0,
		"integrity_loss": 10,
		"colonist_gain": 50,
		"specialist_mitigation": "medic",
		"mitigated_integrity_loss": 0,
	},
	{
		"id": 8,
		"name": "Radiation Storm",
		"description": "Intense radiation bombards the ship.",
		"colonist_loss": 60,
		"integrity_loss": 5,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 15,
		"mitigated_integrity_loss": 0,
	},
	{
		"id": 9,
		"name": "Cryo Pod Failure",
		"description": "A section of cryo pods experiences catastrophic failure.",
		"colonist_loss": 100,
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_colonist_loss": 30,
		"mitigated_integrity_loss": 0,
	},
	{
		"id": 10,
		"name": "Clear Skies",
		"description": "The journey continues without incident.",
		"colonist_loss": 0,
		"integrity_loss": 0,
		"specialist_mitigation": "",
	},
]


func roll_random_event() -> Dictionary:
	var roll = randi_range(0, 9)
	return random_events[roll]


func resolve_event(event: Dictionary, use_specialist: bool = false) -> Dictionary:
	var result = {
		"colonist_change": 0,
		"integrity_change": 0,
		"fuel_change": 0,
		"scrap_change": 0,
		"mitigated": false,
	}

	var specialist_key = event.get("specialist_mitigation", "")
	var can_mitigate = specialist_key != "" and use_specialist and GameState.is_officer_alive(specialist_key)

	if can_mitigate:
		result["mitigated"] = true
		result["colonist_change"] = -event.get("mitigated_colonist_loss", event.get("colonist_loss", 0))
		result["integrity_change"] = -event.get("mitigated_integrity_loss", event.get("integrity_loss", 0))
	else:
		result["colonist_change"] = -event.get("colonist_loss", 0)
		result["integrity_change"] = -event.get("integrity_loss", 0)

	# Add any gains
	result["colonist_change"] += event.get("colonist_gain", 0)
	result["fuel_change"] = event.get("fuel_gain", 0)
	result["scrap_change"] = event.get("scrap_gain", 0)

	# Apply changes to game state
	GameState.colonist_count += result["colonist_change"]
	GameState.ship_integrity += result["integrity_change"]
	GameState.fuel += result["fuel_change"]
	GameState.scrap += result["scrap_change"]

	event_resolved.emit("mitigated" if result["mitigated"] else "standard")

	return result


func can_mitigate_event(event: Dictionary) -> bool:
	var specialist_key = event.get("specialist_mitigation", "")
	if specialist_key == "":
		return false
	return GameState.is_officer_alive(specialist_key)


func get_node_type(node_index: int = -1) -> NodeType:
	# If node_index is provided and we have a pre-rolled type, use it
	if node_index >= 0 and GameState.node_types.has(node_index):
		return GameState.node_types[node_index]
	
	# Otherwise roll randomly (legacy behavior)
	var roll = randi_range(1, 10)
	if roll <= 4:
		return NodeType.EMPTY_SPACE
	elif roll <= 8:
		return NodeType.SCAVENGE_SITE
	else:
		return NodeType.TRADING_OUTPOST
