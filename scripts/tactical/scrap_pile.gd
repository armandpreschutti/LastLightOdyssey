extends TacticalInteractable
## Valuables Pile - Gives +Cash when looted

@export var cash_amount: int = 50
@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	super._ready()
	if icon_label:
		icon_label.text = "+%d" % cash_amount


func interact() -> void:
	# Resources are tracked by tactical_controller and only awarded on successful extraction
	super.interact()


func get_interaction_text() -> String:
	return "COLLECT VALUABLES (+%d CR)" % cash_amount


func get_item_type() -> String:
	return "cash"


func get_cash_amount() -> int:
	return cash_amount
