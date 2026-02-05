extends TacticalInteractable
## Scrap Pile - Gives +5 scrap when looted
## Now uses sprite-based graphics

var scrap_amount: int = 5

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	super._ready()
	if icon_label:
		icon_label.text = "+%d" % scrap_amount


func interact() -> void:
	GameState.scrap += scrap_amount
	super.interact()


func get_interaction_text() -> String:
	return "COLLECT SCRAP (+%d)" % scrap_amount


func get_item_type() -> String:
	return "scrap"


func get_scrap_amount() -> int:
	return scrap_amount
