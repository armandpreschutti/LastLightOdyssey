extends TacticalInteractable
## Fuel Crate - Gives +1 fuel when looted
## Now uses sprite-based graphics


func _ready() -> void:
	super._ready()


func interact() -> void:
	# Resources are tracked by tactical_controller and only awarded on successful extraction
	super.interact()


func get_interaction_text() -> String:
	return "SALVAGE FUEL (+1)"


func get_item_type() -> String:
	return "fuel"
