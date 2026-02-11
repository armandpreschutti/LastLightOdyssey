extends TacticalInteractable
## Activatable Interactable - Base class for objective interactables that can be activated
## Handles common activation state management and visual feedback
## Subclasses only need to override label and objective ID methods
class_name ActivatableInteractable

var is_activated: bool = false

@onready var icon_label: Label = $IconLabel


func _ready() -> void:
	super._ready()
	if icon_label:
		icon_label.text = get_initial_label()
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
	if sprite:
		sprite.modulate = get_activation_color()
	
	# Update label to show activated state
	if icon_label:
		icon_label.text = get_activated_label()
		icon_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1.0))
	
	# Emit signal so tactical controller can complete objective
	interacted.emit()


func get_interaction_text() -> String:
	if is_activated:
		return get_activated_interaction_text()
	return get_inactive_interaction_text()


func get_item_type() -> String:
	# Return empty string so it's not treated as loot
	return ""


## Virtual methods for subclasses to override

## Get the initial label text (e.g., "BEACON", "POWER", "SECURITY")
func get_initial_label() -> String:
	return "OBJECTIVE"


## Get the activated label text (e.g., "ACTIVE", "REPAIRED", "HACKED")
func get_activated_label() -> String:
	return "ACTIVATED"


## Get the interaction text when inactive (e.g., "ACTIVATE BEACON")
func get_inactive_interaction_text() -> String:
	return "ACTIVATE OBJECTIVE"


## Get the interaction text when activated (e.g., "BEACON (ACTIVATED)")
func get_activated_interaction_text() -> String:
	return "OBJECTIVE (ACTIVATED)"


## Get the activation color (greenish tint by default)
func get_activation_color() -> Color:
	return Color(0.5, 1.0, 0.5, 1.0)
