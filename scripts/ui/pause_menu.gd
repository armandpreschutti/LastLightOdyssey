extends Control
## Pause Menu - Allows player to abandon tactical mission at a cost
## Retro sci-fi terminal aesthetic with amber accents

signal resume_pressed
signal abandon_pressed

const ABANDON_COLONIST_COST: int = 20

@onready var panel: PanelContainer = $PanelContainer
# Updated paths for new styled layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var warning_label: Label = $PanelContainer/MarginContainer/VBoxContainer/WarningLabel
@onready var cost_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CostLabel
@onready var resume_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton
@onready var abandon_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/AbandonButton

# Ship status labels
@onready var colonists_value: Label = $PanelContainer/MarginContainer/VBoxContainer/ShipStatusContainer/StatusGrid/ColonistsValue
@onready var fuel_value: Label = $PanelContainer/MarginContainer/VBoxContainer/ShipStatusContainer/StatusGrid/FuelValue
@onready var integrity_value: Label = $PanelContainer/MarginContainer/VBoxContainer/ShipStatusContainer/StatusGrid/IntegrityValue
@onready var scrap_value: Label = $PanelContainer/MarginContainer/VBoxContainer/ShipStatusContainer/StatusGrid/ScrapValue
@onready var stability_value: Label = $PanelContainer/MarginContainer/VBoxContainer/ShipStatusContainer/StatusGrid/StabilityValue

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
	AudioManager.play_sfx("ui_dialog_close")
	resume_pressed.emit()
	queue_free()


func _on_abandon_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	# Apply colonist penalty
	GameState.colonist_count -= ABANDON_COLONIST_COST
	
	# Resources are not added to GameState until successful extraction,
	# so no forfeiture is needed - abandoning simply prevents rewards
	
	abandon_pressed.emit()
	queue_free()


func show_menu() -> void:
	visible = true
	resume_button.grab_focus()
	AudioManager.play_sfx("ui_dialog_open")
	
	# Update the cost label with all penalties
	_update_cost_label()
	
	# Update ship status display
	_update_ship_status()
	
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


func _update_ship_status() -> void:
	# Update all ship status values from GameState
	colonists_value.text = str(GameState.colonist_count)
	fuel_value.text = str(GameState.fuel)
	integrity_value.text = "%d%%" % GameState.ship_integrity
	scrap_value.text = str(GameState.scrap)
	stability_value.text = "%d%%" % GameState.cryo_stability
	
	# Color code stability based on value (similar to tactical HUD)
	if GameState.cryo_stability <= 0:
		stability_value.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	elif GameState.cryo_stability <= 25:
		stability_value.add_theme_color_override("font_color", Color(1, 1, 0.2))
	else:
		stability_value.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
	
	# Color code fuel if at 0 (drift mode)
	if GameState.fuel == 0:
		fuel_value.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	else:
		fuel_value.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# Color code integrity if low
	if GameState.ship_integrity <= 25:
		integrity_value.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	elif GameState.ship_integrity <= 50:
		integrity_value.add_theme_color_override("font_color", Color(1, 1, 0.2))
	else:
		integrity_value.add_theme_color_override("font_color", Color(1, 1, 1))


func hide_menu() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
