extends Control
## Event Dialog - Modal popup for displaying and resolving random events
## Shows event details, projected losses, and mitigation options

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var losses_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesLabel
@onready var mitigated_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/MitigatedLabel
@onready var accept_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/AcceptButton
@onready var mitigate_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MitigateButton

signal event_choice_made(use_specialist: bool)

var current_event: Dictionary = {}


func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)
	mitigate_button.pressed.connect(_on_mitigate_pressed)
	visible = false


func show_event(event: Dictionary) -> void:
	current_event = event

	title_label.text = "[ %s ]" % event.get("name", "UNKNOWN EVENT").to_upper()
	description_label.text = event.get("description", "")

	# Build losses text
	var losses_text = _build_losses_text(event, false)
	losses_label.text = losses_text

	# Check if mitigation is available
	var specialist_key = event.get("specialist_mitigation", "")
	var has_specialist_option = specialist_key != ""
	
	if has_specialist_option:
		mitigate_button.visible = true
		var specialist_name = _get_specialist_display_name(specialist_key)
		var specialist_desc = _get_specialist_description(specialist_key)
		var is_alive = GameState.is_officer_alive(specialist_key)
		
		if is_alive:
			mitigate_button.text = "[ DEPLOY %s ]" % specialist_name
			mitigate_button.disabled = false
		else:
			mitigate_button.text = "[ %s - DECEASED ]" % specialist_name
			mitigate_button.disabled = true
		
		var mitigated_text = _build_losses_text(event, true)
		mitigated_label.text = "WITH %s:\n%s\n%s" % [specialist_name, specialist_desc, mitigated_text]
		mitigated_label.visible = true
	else:
		mitigate_button.visible = false
		mitigated_label.visible = false

	visible = true


func _build_losses_text(event: Dictionary, mitigated: bool) -> String:
	var lines: Array[String] = []

	var colonist_loss: int
	var integrity_loss: int

	if mitigated:
		colonist_loss = event.get("mitigated_colonist_loss", event.get("colonist_loss", 0))
		integrity_loss = event.get("mitigated_integrity_loss", event.get("integrity_loss", 0))
	else:
		colonist_loss = event.get("colonist_loss", 0)
		integrity_loss = event.get("integrity_loss", 0)

	var colonist_gain = event.get("colonist_gain", 0)
	var fuel_gain = event.get("fuel_gain", 0)
	var scrap_gain = event.get("scrap_gain", 0)

	if colonist_loss > 0:
		lines.append("COLONISTS: -%d" % colonist_loss)
	if integrity_loss > 0:
		lines.append("HULL: -%d%%" % integrity_loss)
	if colonist_gain > 0:
		lines.append("COLONISTS: +%d" % colonist_gain)
	if fuel_gain > 0:
		lines.append("FUEL: +%d" % fuel_gain)
	if scrap_gain > 0:
		lines.append("SCRAP: +%d" % scrap_gain)

	if lines.is_empty():
		return "NO EFFECT"

	return "\n".join(lines)


func _on_accept_pressed() -> void:
	visible = false
	event_choice_made.emit(false)


func _on_mitigate_pressed() -> void:
	visible = false
	event_choice_made.emit(true)


func hide_dialog() -> void:
	visible = false


func _get_specialist_display_name(specialist_key: String) -> String:
	match specialist_key:
		"scout": return "SCOUT"
		"tech": return "TECH"
		"medic": return "MEDIC"
		_: return specialist_key.to_upper()


func _get_specialist_description(specialist_key: String) -> String:
	match specialist_key:
		"scout": return "(Navigation & early warning specialist)"
		"tech": return "(Engineering & systems specialist)"
		"medic": return "(Medical & life support specialist)"
		_: return ""
