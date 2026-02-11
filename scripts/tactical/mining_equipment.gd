extends ActivatableInteractable
## Mining Equipment - Objective interactable for asteroid missions
## Stays on map after activation (unlike fuel/scrap which disappear)
## Now uses sprite-based graphics


func get_initial_label() -> String:
	return "MINING"


func get_activated_label() -> String:
	return "ACTIVE"


func get_inactive_interaction_text() -> String:
	return "ACTIVATE MINING EQUIPMENT"


func get_activated_interaction_text() -> String:
	return "MINING EQUIPMENT (ACTIVATED)"


func get_objective_id() -> String:
	return "activate_mining"
