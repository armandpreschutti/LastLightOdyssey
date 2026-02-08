extends TacticalInteractable
## Data Log - Objective interactable for station missions
## Removed after collection (like fuel/scrap)
## Now uses sprite-based graphics


func _ready() -> void:
	super._ready()


func interact() -> void:
	# Call super.interact() to remove this object after collection
	super.interact()


func get_interaction_text() -> String:
	return "RETRIEVE DATA LOG (+1)"


func get_objective_id() -> String:
	return "retrieve_logs"


func get_item_type() -> String:
	# Return empty string so it's not treated as loot
	return ""
