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
		"colonist_loss": 70,
		"integrity_loss": 15,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 5,
		"mitigation_scrap_cost": 18,
	},
	{
		"id": 2,
		"name": "Meteor Shower",
		"description": "The ship passes through a dense meteor field.",
		"colonist_loss": 50,
		"integrity_loss": 25,
		"specialist_mitigation": "scout",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 22,
	},
	{
		"id": 3,
		"name": "Disease Outbreak",
		"description": "A mysterious illness spreads through the cryo chambers.",
		"colonist_loss": 100,
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 0,
		"mitigation_scrap_cost": 30,
	},
	{
		"id": 4,
		"name": "System Malfunction",
		"description": "Critical ship systems begin to fail.",
		"colonist_loss": 40,
		"integrity_loss": 20,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 15,
	},
	{
		"id": 5,
		"name": "Pirate Ambush",
		"description": "Raiders emerge from a nearby asteroid field.",
		"colonist_loss": 60,
		"integrity_loss": 30,
		"specialist_mitigation": "heavy",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 15,
		"mitigation_scrap_cost": 28,
	},
	{
		"id": 6,
		"name": "Space Debris Field",
		"description": "The ship navigates through a field of wreckage from past conflicts.",
		"colonist_loss": 30,
		"integrity_loss": 20,
		"specialist_mitigation": "scout",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 10,
		"mitigation_scrap_cost": 20,
	},
	{
		"id": 7,
		"name": "Sensor Ghost",
		"description": "False readings on the sensors cause momentary alarm, but nothing materializes.",
		"colonist_loss": 0,
		"integrity_loss": 0,
		"specialist_mitigation": "",
		"mitigation_scrap_cost": 0,
	},
	{
		"id": 8,
		"name": "Radiation Storm",
		"description": "Intense radiation bombards the ship.",
		"colonist_loss": 80,
		"integrity_loss": 10,
		"specialist_mitigation": "tech",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 5,
		"mitigation_scrap_cost": 25,
	},
	{
		"id": 9,
		"name": "Cryo Pod Failure",
		"description": "A section of cryo pods experiences catastrophic failure.",
		"colonist_loss": 100,
		"integrity_loss": 0,
		"specialist_mitigation": "medic",
		"mitigated_colonist_loss": 0,
		"mitigated_integrity_loss": 0,
		"mitigation_scrap_cost": 35,
	},
	{
		"id": 10,
		"name": "Clear Skies",
		"description": "The journey continues without incident.",
		"colonist_loss": 0,
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
	const COST_SCALE_FACTOR: float = 1.5
	const FINAL_STAGE_START: int = 35  # Nodes 35+ get reduced scaling
	const FINAL_STAGE_SCALE_REDUCTION: float = 0.4  # Reduce scaling by 40% in final stages
	
	var progress_ratio: float = float(GameState.current_node_index) / float(GameState.nodes_to_new_earth)
	
	# Reduce cost scaling in final stages
	if GameState.current_node_index >= FINAL_STAGE_START:
		# Calculate what the multiplier would be at node 35
		var final_stage_progress: float = float(FINAL_STAGE_START) / float(GameState.nodes_to_new_earth)
		var base_multiplier_at_35: float = 1.0 + (final_stage_progress * COST_SCALE_FACTOR)
		
		# Calculate remaining progress after node 35
		var remaining_progress: float = progress_ratio - final_stage_progress
		var remaining_scale_factor: float = COST_SCALE_FACTOR * (1.0 - FINAL_STAGE_SCALE_REDUCTION)
		
		# Apply reduced scaling for final stages
		var multiplier: float = base_multiplier_at_35 + (remaining_progress * remaining_scale_factor)
		return multiplier
	else:
		# Normal scaling for early/mid stages
		var multiplier: float = 1.0 + (progress_ratio * COST_SCALE_FACTOR)
		return multiplier


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
		# Deduct scrap cost for mitigation (with dynamic scaling, capped at 15)
		var base_cost = event.get("mitigation_scrap_cost", 0)
		var cost_multiplier = get_mitigation_cost_multiplier()
		var scrap_cost = mini(int(base_cost * cost_multiplier), 15)
		result["scrap_change"] -= scrap_cost
	else:
		result["colonist_change"] = -event.get("colonist_loss", 0)
		result["integrity_change"] = -event.get("integrity_loss", 0)

	# Add any gains
	result["colonist_change"] += event.get("colonist_gain", 0)
	result["fuel_change"] = event.get("fuel_gain", 0)
	result["scrap_change"] += event.get("scrap_gain", 0)

	# Apply changes to game state
	GameState.colonist_count += result["colonist_change"]
	GameState.ship_integrity += result["integrity_change"]
	GameState.fuel += result["fuel_change"]
	GameState.scrap += result["scrap_change"]

	# warning-ignore: INCOMPATIBLE_TERNARY
	event_resolved.emit("mitigated" if result["mitigated"] else "standard")

	return result


func can_mitigate_event(event: Dictionary) -> bool:
	var specialist_key = event.get("specialist_mitigation", "")
	if specialist_key == "":
		return false
	if not GameState.is_officer_alive(specialist_key):
		return false
	# Check if player has enough scrap (with dynamic scaling, capped at 15)
	var base_cost = event.get("mitigation_scrap_cost", 0)
	var cost_multiplier = get_mitigation_cost_multiplier()
	var scrap_cost = mini(int(base_cost * cost_multiplier), 15)
	return GameState.scrap >= scrap_cost


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
