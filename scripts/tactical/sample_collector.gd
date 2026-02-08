extends TacticalInteractable
## Sample Collector - Objective interactable for planet missions
## Removed after collection (like fuel/scrap)
## Now uses sprite-based graphics


func _ready() -> void:
	super._ready()


func interact() -> void:
	# Call super.interact() to remove this object after collection
	super.interact()


func get_interaction_text() -> String:
	return "COLLECT SAMPLE (+1)"


func get_objective_id() -> String:
	return "collect_samples"


func get_item_type() -> String:
	# Return empty string so it's not treated as loot
	return ""
