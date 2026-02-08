extends TacticalInteractable
## Nest - Objective interactable for planet missions
## Removed after clearing (like enemies)
## Now uses sprite-based graphics


func _ready() -> void:
	super._ready()


func interact() -> void:
	# Call super.interact() to remove this object after clearing
	super.interact()


func get_interaction_text() -> String:
	return "CLEAR NEST"


func get_objective_id() -> String:
	return "clear_nests"


func get_item_type() -> String:
	# Return empty string so it's not treated as loot
	return ""
