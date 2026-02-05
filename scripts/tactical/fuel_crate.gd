extends TacticalInteractable
## Fuel Crate - Gives +1 fuel when looted
## Now uses sprite-based graphics


func _ready() -> void:
	super._ready()


func interact() -> void:
	GameState.fuel += 1
	super.interact()


func get_interaction_text() -> String:
	return "SALVAGE FUEL (+1)"


func get_item_type() -> String:
	return "fuel"
