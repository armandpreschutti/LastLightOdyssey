extends ActivatableInteractable
## Power Core - Objective interactable for station missions
## Stays on map after activation (unlike fuel/scrap which disappear)
## Now uses sprite-based graphics


func get_initial_label() -> String:
	return "POWER"


func get_activated_label() -> String:
	return "REPAIRED"


func get_inactive_interaction_text() -> String:
	return "REPAIR POWER CORE"


func get_activated_interaction_text() -> String:
	return "POWER CORE (REPAIRED)"


func get_objective_id() -> String:
	return "repair_core"
