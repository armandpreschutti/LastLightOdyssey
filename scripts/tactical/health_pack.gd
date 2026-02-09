extends TacticalInteractable
## Health Pack - Restores 62.5% max HP when picked up
## Now uses sprite-based graphics

func _ready() -> void:
	super._ready()


func interact() -> void:
	# Healing is handled by tactical_controller when item is picked up
	super.interact()


func get_interaction_text() -> String:
	return "HEALTH PACK (+62.5% HP)"


func get_item_type() -> String:
	return "health_pack"
