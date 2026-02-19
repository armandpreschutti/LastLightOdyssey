extends TacticalInteractable
## Fuel Crate - Gives +1 fuel when looted
## Now uses sprite-based graphics

var amount: int = 1

func set_amount(val: int) -> void:
	amount = val


func _ready() -> void:
	super._ready()


func interact() -> void:
	# Resources are tracked by tactical_controller and only awarded on successful extraction
	super.interact()


func get_interaction_text() -> String:
	if amount > 1:
		return "SALVAGE FUEL (+%d)" % amount
	return "SALVAGE FUEL (+1)"


func get_item_type() -> String:
	return "fuel"
