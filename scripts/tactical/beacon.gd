extends TacticalInteractable
## Beacon - Objective interactable for planet missions
## Stays on map after activation (unlike fuel/scrap which disappear)
## Now uses sprite-based graphics

var is_activated: bool = false

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	super._ready()
	if icon_label:
		icon_label.text = "BEACON"
		icon_label.visible = true


func interact() -> void:
	# Don't call super.interact() - we don't want to remove this object
	# Just mark as activated and change visual state
	if is_activated:
		return  # Already activated
	
	is_activated = true
	
	# Stop idle animation
	_stop_idle_animation()
	
	# Change visual state to show it's activated
	# Make it glow or change color to indicate activation
	if sprite:
		# Change to a greenish tint to show it's active
		sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)
	
	# Update label to show activated state
	if icon_label:
		icon_label.text = "ACTIVE"
		icon_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1.0))
	
	# Emit signal so tactical controller can complete objective
	interacted.emit()


func get_interaction_text() -> String:
	if is_activated:
		return "BEACON (ACTIVATED)"
	return "ACTIVATE BEACON"


func get_objective_id() -> String:
	return "activate_beacons"


func get_item_type() -> String:
	# Return empty string so it's not treated as loot
	return ""
