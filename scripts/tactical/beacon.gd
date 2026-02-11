extends ActivatableInteractable
## Beacon - Objective interactable for planet missions
## Stays on map after activation (unlike fuel/scrap which disappear)
## Now uses sprite-based graphics


func get_initial_label() -> String:
	return "BEACON"


func get_activated_label() -> String:
	return "ACTIVE"


func get_inactive_interaction_text() -> String:
	return "ACTIVATE BEACON"


func get_activated_interaction_text() -> String:
	return "BEACON (ACTIVATED)"


func get_objective_id() -> String:
	return "activate_beacons"
