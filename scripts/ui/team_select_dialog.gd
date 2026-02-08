extends Control
## Team Selection Dialog - Choose 3 officers for tactical mission

signal team_selected(officer_keys: Array[String])
signal cancelled

# Updated paths for new styled layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var objective_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var captain_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CaptainLabel
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer
@onready var officer_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OfficerContainer
@onready var selected_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SelectedLabel
@onready var deploy_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DeployButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

const MAX_TEAM_SIZE: int = 3

var officer_buttons: Dictionary = {}  # officer_key -> CheckButton
var selected_officers: Array[String] = []
var current_biome_type: int = -1  # BiomeConfig.BiomeType


func _ready() -> void:
	deploy_button.pressed.connect(_on_deploy_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	visible = false
	# Enable mouse input for scroll wheel support
	if scroll_container:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS


func show_dialog(biome_type: int = -1) -> void:
	current_biome_type = biome_type
	_update_title()
	_update_description()
	_update_objective()
	_populate_officers()
	_update_selected_label()
	deploy_button.disabled = true
	visible = true
	AudioManager.play_sfx("ui_dialog_open")


func _update_title() -> void:
	if current_biome_type >= 0:
		var biome_name = BiomeConfig.get_biome_name(current_biome_type)
		title_label.text = "[ SCAVENGE: %s ]" % biome_name.to_upper()
	else:
		title_label.text = "[ SELECT AWAY TEAM ]"


func _update_description() -> void:
	# Update description to reflect new selection system
	if desc_label:
		desc_label.text = "Select %d officers for deployment. All officers are available, including the Captain." % MAX_TEAM_SIZE
	
	# Hide or update the captain label since captain is now selectable
	if captain_label:
		captain_label.visible = false


func _update_objective() -> void:
	# Update mission objective display based on biome type
	if objective_label:
		if current_biome_type >= 0:
			# Get mission objective for this biome
			var biome = current_biome_type as BiomeConfig.BiomeType
			var objectives = MissionObjective.ObjectiveManager.get_objectives_for_biome(biome)
			
			if not objectives.is_empty():
				var objective = objectives[0]
				var objective_text = _build_objective_description(biome, objective)
				
				objective_label.text = objective_text
				objective_label.visible = true
			else:
				objective_label.visible = false
		else:
			objective_label.visible = false


func _build_objective_description(biome: BiomeConfig.BiomeType, objective: MissionObjective) -> String:
	# Build a detailed description of the mission and optional objective
	var biome_name = BiomeConfig.get_biome_name(biome)
	var mission_desc = ""
	var objective_desc = ""
	var reward_info = ""
	
	# Get biome description
	match biome:
		BiomeConfig.BiomeType.STATION:
			mission_desc = "Scavenge a derelict space station for resources. Eliminate all hostiles to extract."
		BiomeConfig.BiomeType.ASTEROID:
			mission_desc = "Scavenge an abandoned mining operation. Eliminate all hostiles to extract."
		BiomeConfig.BiomeType.PLANET:
			mission_desc = "Scavenge the alien planetary surface. Eliminate all hostiles to extract."
		_:
			mission_desc = "Scavenge this location for resources. Eliminate all hostiles to extract."
	
	# Get bonus reward info
	var bonuses = MissionObjective.ObjectiveManager.get_bonus_rewards(objective)
	var reward_text = ""
	if bonuses.get("fuel", 0) > 0:
		reward_text = "Completing this objective grants +%d FUEL bonus." % bonuses.get("fuel", 0)
	elif bonuses.get("scrap", 0) > 0:
		reward_text = "Completing this objective grants +%d SCRAP bonus." % bonuses.get("scrap", 0)
	
	# Build detailed objective description
	match objective.id:
		"hack_security":
			objective_desc = "OPTIONAL: Hack security systems by interacting with security terminals found throughout the station. %s" % reward_text
		"retrieve_logs":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			objective_desc = "OPTIONAL: Retrieve data logs by collecting data log devices scattered throughout the station%s. %s" % [progress_text, reward_text]
		"repair_core":
			objective_desc = "OPTIONAL: Repair the power core by interacting with power core units found in the station. %s" % reward_text
		"clear_passages":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			objective_desc = "OPTIONAL: Clear cave passages by eliminating enemies blocking the tunnels%s. %s" % [progress_text, reward_text]
		"activate_mining":
			objective_desc = "OPTIONAL: Activate mining equipment by interacting with mining units found in the asteroid. %s" % reward_text
		"extract_minerals":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			objective_desc = "OPTIONAL: Extract rare minerals by interacting with mining equipment%s. %s" % [progress_text, reward_text]
		"collect_samples":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			objective_desc = "OPTIONAL: Collect alien samples by interacting with sample collection points found on the surface%s. %s" % [progress_text, reward_text]
		"activate_beacons":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			objective_desc = "OPTIONAL: Activate beacons by interacting with beacon units scattered across the planet%s. %s" % [progress_text, reward_text]
		"clear_nests":
			objective_desc = "OPTIONAL: Clear hostile nests by interacting with nest structures found on the alien surface. %s" % reward_text
		_:
			objective_desc = "OPTIONAL: %s. %s" % [objective.description, reward_text]
	
	# Combine into full description
	var full_text = "%s\n\n%s" % [mission_desc, objective_desc]
	return full_text


func _populate_officers() -> void:
	# Clear existing buttons
	for child in officer_container.get_children():
		child.queue_free()
	officer_buttons.clear()
	selected_officers.clear()

	# Create button for each alive officer (including captain)
	for officer_key in GameState.officers:
		if not GameState.is_officer_alive(officer_key):
			continue

		# Create container for officer entry
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		
		# Officer name and checkbox
		var hbox = HBoxContainer.new()
		
		var check = CheckButton.new()
		check.text = _get_officer_display_name(officer_key)
		check.add_theme_color_override("font_color", _get_officer_color(officer_key))
		check.add_theme_font_size_override("font_size", 18)
		check.toggled.connect(_on_officer_toggled.bind(officer_key))

		officer_buttons[officer_key] = check
		hbox.add_child(check)
		vbox.add_child(hbox)
		
		# Officer description
		var desc_label = Label.new()
		desc_label.text = _get_officer_description(officer_key)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
		desc_label.add_theme_font_size_override("font_size", 15)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.custom_minimum_size = Vector2(0, 0)
		vbox.add_child(desc_label)
		
		officer_container.add_child(vbox)


func _get_officer_display_name(key: String) -> String:
	match key:
		"captain": return "CAPTAIN"
		"scout": return "SCOUT"
		"tech": return "TECH"
		"medic": return "MEDIC"
		"heavy": return "HEAVY"
		"sniper": return "SNIPER"
		_: return key.to_upper()


func _get_officer_description(key: String) -> String:
	match key:
		"scout":
			return "High mobility & extended vision. Ability: OVERWATCH - Guaranteed hit on the first enemy that moves in range (1 AP). 2-turn cooldown."
		"tech":
			return "Combat engineer. Ability: TURRET - Deploy an auto-firing sentry turret on an adjacent tile. Lasts 3 turns (1 AP). 2-turn cooldown."
		"medic":
			return "Field surgeon. Ability: PATCH - Heal adjacent ally for 50% max HP (2 AP). 2-turn cooldown."
		"heavy":
			return "Heavily armed bruiser. Ability: CHARGE - Rush an enemy within 4 tiles. Instant-kills basic enemies, heavy damage to elites (1 AP). 2-turn cooldown."
		"captain":
			return "Squad leader. Ability: EXECUTE - Guaranteed kill on an enemy within 4 tiles below 50% HP. Never misses (1 AP). 2-turn cooldown."
		"sniper":
			return "Long-range marksman. Ability: PRECISION SHOT - Guaranteed hit on any visible enemy, deals 2x damage (60). (1 AP). 2-turn cooldown."
		_:
			return ""


func _get_officer_color(key: String) -> Color:
	match key:
		"captain": return Color(1.0, 0.69, 0.0)  # Amber
		"scout": return Color(0.2, 1.0, 0.5)  # Green
		"tech": return Color(0.4, 0.9, 1.0)  # Cyan
		"medic": return Color(1.0, 0.5, 0.8)  # Pink
		"heavy": return Color(1.0, 0.4, 0.3)  # Red-orange
		"sniper": return Color(0.6, 0.55, 0.7)  # Dark gray with purple tint
		_: return Color.WHITE


func _on_officer_toggled(pressed: bool, officer_key: String) -> void:
	if pressed:
		if selected_officers.size() < MAX_TEAM_SIZE:
			selected_officers.append(officer_key)
		else:
			# Can't select more, uncheck
			officer_buttons[officer_key].button_pressed = false
			return
	else:
		selected_officers.erase(officer_key)

	_update_selected_label()
	deploy_button.disabled = selected_officers.size() < MAX_TEAM_SIZE


func _update_selected_label() -> void:
	selected_label.text = "SELECTED: %d / %d" % [selected_officers.size(), MAX_TEAM_SIZE]


func _on_deploy_pressed() -> void:
	if selected_officers.size() >= MAX_TEAM_SIZE:
		visible = false
		team_selected.emit(selected_officers.duplicate())


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
