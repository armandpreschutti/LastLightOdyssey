extends Control
## Event Dialog - Modal popup for displaying and resolving random events
## Shows event details, projected losses, and mitigation options

# Updated paths for new icon-based layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var losses_header_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesHeaderLabel
@onready var losses_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesLabel
@onready var colonists_loss_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow/ColonistsLoss/ColonistsLossLabel
@onready var hull_loss_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow/HullLoss/HullLossLabel
@onready var fuel_gain_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow/FuelGain/FuelGainLabel
@onready var scrap_gain_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow/ScrapGain/ScrapGainLabel
@onready var colonists_gain_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow/ColonistsGain/ColonistsGainLabel
@onready var losses_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/LossesContainer/LossesRow
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
	AudioManager.play_sfx("ui_dialog_open")

	title_label.text = "[ %s ]" % event.get("name", "UNKNOWN EVENT").to_upper()
	description_label.text = event.get("description", "")

	# Determine if event is positive (has gains, no losses) or negative (has losses)
	var colonist_loss = event.get("colonist_loss", 0)
	var integrity_loss = event.get("integrity_loss", 0)
	var colonist_gain = event.get("colonist_gain", 0)
	var fuel_gain = event.get("fuel_gain", 0)
	var scrap_gain = event.get("scrap_gain", 0)
	
	var has_losses = colonist_loss > 0 or integrity_loss > 0
	var has_gains = colonist_gain > 0 or fuel_gain > 0 or scrap_gain > 0
	var is_positive_event = has_gains and not has_losses
	
	# Update header label text based on event type
	if is_positive_event:
		losses_header_label.text = "PROJECTED GAINS:"
	else:
		losses_header_label.text = "PROJECTED LOSSES:"
	
	# Update accept button text based on event type
	if is_positive_event:
		accept_button.text = "[ ACCEPT GAINS ]"
	else:
		accept_button.text = "[ ACCEPT LOSSES ]"
	
	# Update icon-based losses display
	if colonist_loss > 0:
		colonists_loss_label.text = "COLONISTS: -%d" % colonist_loss
		colonists_loss_label.get_parent().visible = true
	else:
		colonists_loss_label.get_parent().visible = false
	
	if integrity_loss > 0:
		hull_loss_label.text = "HULL: -%d%%" % integrity_loss
		hull_loss_label.get_parent().visible = true
	else:
		hull_loss_label.get_parent().visible = false
	
	# Update icon-based gains display
	if colonist_gain > 0:
		colonists_gain_label.text = "COLONISTS: +%d" % colonist_gain
		colonists_gain_label.get_parent().visible = true
	else:
		colonists_gain_label.get_parent().visible = false
	
	if fuel_gain > 0:
		fuel_gain_label.text = "FUEL: +%d" % fuel_gain
		fuel_gain_label.get_parent().visible = true
	else:
		fuel_gain_label.get_parent().visible = false
	
	if scrap_gain > 0:
		scrap_gain_label.text = "SCRAP: +%d" % scrap_gain
		scrap_gain_label.get_parent().visible = true
	else:
		scrap_gain_label.get_parent().visible = false
	
	# Show losses row if there are any losses or gains
	losses_row.visible = has_losses or has_gains

	# Check if mitigation is available
	var specialist_key = event.get("specialist_mitigation", "")
	var has_specialist_option = specialist_key != ""
	
	if has_specialist_option:
		mitigate_button.visible = true
		var specialist_name = _get_specialist_display_name(specialist_key)
		var specialist_desc = _get_specialist_description(specialist_key)
		var is_alive = GameState.is_officer_alive(specialist_key)
		# Calculate dynamic scrap cost based on voyage progress (capped at 15)
		var base_cost = event.get("mitigation_scrap_cost", 0)
		var cost_multiplier = EventManager.get_mitigation_cost_multiplier()
		var scrap_cost = mini(int(base_cost * cost_multiplier), 15)
		var has_enough_scrap = GameState.scrap >= scrap_cost
		
		if is_alive:
			if has_enough_scrap:
				mitigate_button.text = "[ DEPLOY %s ] (COST: %d SCRAP)" % [specialist_name, scrap_cost]
				mitigate_button.disabled = false
			else:
				mitigate_button.text = "[ DEPLOY %s ] (NEED %d SCRAP)" % [specialist_name, scrap_cost]
				mitigate_button.disabled = true
		else:
			mitigate_button.text = "[ %s - DECEASED ]" % specialist_name
			mitigate_button.disabled = true
		
		var mitigated_text = _build_losses_text(event, true)
		var scrap_cost_text = "SCRAP: -%d" % scrap_cost
		mitigated_label.text = "WITH %s:\n%s\n%s\n%s" % [specialist_name, specialist_desc, scrap_cost_text, mitigated_text]
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
	
	var original_colonist_loss = event.get("colonist_loss", 0)

	if colonist_loss > 0:
		lines.append("COLONISTS: -%d" % colonist_loss)
	elif mitigated and colonist_loss == 0 and original_colonist_loss > 0:
		lines.append("COLONISTS: SAVED")
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
	AudioManager.play_sfx("ui_click")
	visible = false
	event_choice_made.emit(false)


func _on_mitigate_pressed() -> void:
	AudioManager.play_sfx("ui_click")
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
