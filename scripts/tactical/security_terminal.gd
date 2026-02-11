extends ActivatableInteractable
## Security Terminal - Objective interactable for station missions
## Stays on map after activation (unlike fuel/scrap which disappear)
## Now uses sprite-based graphics


func get_initial_label() -> String:
	return "SECURITY"


func get_activated_label() -> String:
	return "HACKED"


func get_inactive_interaction_text() -> String:
	return "HACK SECURITY TERMINAL"


func get_activated_interaction_text() -> String:
	return "SECURITY TERMINAL (HACKED)"


func get_objective_id() -> String:
	return "hack_security"
