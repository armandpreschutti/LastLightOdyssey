extends Control
## Pause Menu - Allows player to abandon tactical mission at a cost
## 1980s terminal aesthetic with amber text

signal resume_pressed
signal abandon_pressed

const ABANDON_COLONIST_COST: int = 20

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var warning_label: Label = $PanelContainer/MarginContainer/VBoxContainer/WarningLabel
@onready var cost_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CostLabel
@onready var resume_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton
@onready var abandon_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/AbandonButton

# Track resources collected during this mission (to forfeit on abandon)
var mission_fuel_collected: int = 0
var mission_scrap_collected: int = 0


func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	
	# Grab focus on resume button for keyboard navigation
	resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	resume_pressed.emit()
	queue_free()


func _on_abandon_pressed() -> void:
	# Apply colonist penalty
	GameState.colonist_count -= ABANDON_COLONIST_COST
	
	# Forfeit all resources collected during this mission
	GameState.fuel -= mission_fuel_collected
	GameState.scrap -= mission_scrap_collected
	
	abandon_pressed.emit()
	queue_free()


func show_menu() -> void:
	visible = true
	resume_button.grab_focus()
	
	# Update the cost label with all penalties
	_update_cost_label()
	
	# Animate appearance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Set the resources collected during this mission (to show forfeiture warning)
func set_mission_haul(fuel: int, scrap: int) -> void:
	mission_fuel_collected = fuel
	mission_scrap_collected = scrap


func _update_cost_label() -> void:
	var cost_text = "Abandoning costs %d colonists" % ABANDON_COLONIST_COST
	
	# Add resource forfeiture warning if applicable
	var forfeit_parts: Array[String] = []
	if mission_fuel_collected > 0:
		forfeit_parts.append("%d fuel" % mission_fuel_collected)
	if mission_scrap_collected > 0:
		forfeit_parts.append("%d scrap" % mission_scrap_collected)
	
	if forfeit_parts.size() > 0:
		cost_text += "\nYou will lose: " + ", ".join(forfeit_parts)
	
	cost_label.text = cost_text


func hide_menu() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
