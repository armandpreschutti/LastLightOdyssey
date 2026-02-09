extends Control
## Team Selection Dialog - Choose 1-3 officers for tactical mission

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

const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 3

var officer_buttons: Dictionary = {}  # officer_key -> CheckButton
var selected_officers: Array[String] = []
var current_biome_type: int = -1  # BiomeConfig.BiomeType
var expanded_officers: Dictionary = {}  # officer_key -> bool (track expanded state)
var officer_detail_containers: Dictionary = {}  # officer_key -> VBoxContainer (detail sections)
var officer_expand_buttons: Dictionary = {}  # officer_key -> Button (expand/collapse buttons)


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
		if MIN_TEAM_SIZE == MAX_TEAM_SIZE:
			desc_label.text = "Select %d officers for deployment. All officers are available, including the Captain." % MAX_TEAM_SIZE
		else:
			desc_label.text = "Select %d-%d officers for deployment. All officers are available, including the Captain." % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]
	
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
	var mission_desc = ""
	var objective_desc = ""
	
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
	
	# Get potential reward info (for display before completion)
	var potential_rewards = MissionObjective.ObjectiveManager.get_potential_rewards(objective)
	var reward_parts: Array[String] = []
	
	if potential_rewards.get("fuel", 0) > 0:
		reward_parts.append("%d FUEL" % potential_rewards.get("fuel", 0))
	if potential_rewards.get("scrap", 0) > 0:
		reward_parts.append("%d SCRAP" % potential_rewards.get("scrap", 0))
	if potential_rewards.get("colonists", 0) > 0:
		reward_parts.append("%d COLONISTS" % potential_rewards.get("colonists", 0))
	if potential_rewards.get("hull_repair", 0) > 0:
		reward_parts.append("%d%% HULL REPAIR" % potential_rewards.get("hull_repair", 0))
	
	var reward_text = ""
	if reward_parts.size() > 0:
		reward_text = "REWARD: " + " / ".join(reward_parts)
	
	# Build detailed objective description
	match objective.id:
		"hack_security":
			if reward_text != "":
				objective_desc = "OPTIONAL: Hack security systems by interacting with security terminals found throughout the station. %s" % reward_text
			else:
				objective_desc = "OPTIONAL: Hack security systems by interacting with security terminals found throughout the station."
		"retrieve_logs":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			if reward_text != "":
				objective_desc = "OPTIONAL: Retrieve data logs by collecting data log devices scattered throughout the station%s. %s" % [progress_text, reward_text]
			else:
				objective_desc = "OPTIONAL: Retrieve data logs by collecting data log devices scattered throughout the station%s." % progress_text
		"repair_core":
			if reward_text != "":
				objective_desc = "OPTIONAL: Repair the power core by interacting with power core units found in the station. %s" % reward_text
			else:
				objective_desc = "OPTIONAL: Repair the power core by interacting with power core units found in the station."
		"clear_passages":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			if reward_text != "":
				objective_desc = "OPTIONAL: Clear cave passages by eliminating enemies blocking the tunnels%s. %s" % [progress_text, reward_text]
			else:
				objective_desc = "OPTIONAL: Clear cave passages by eliminating enemies blocking the tunnels%s." % progress_text
		"activate_mining":
			if reward_text != "":
				objective_desc = "OPTIONAL: Activate mining equipment by interacting with mining units found in the asteroid. %s" % reward_text
			else:
				objective_desc = "OPTIONAL: Activate mining equipment by interacting with mining units found in the asteroid."
		"extract_minerals":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			if reward_text != "":
				objective_desc = "OPTIONAL: Extract rare minerals by interacting with mining equipment%s. %s" % [progress_text, reward_text]
			else:
				objective_desc = "OPTIONAL: Extract rare minerals by interacting with mining equipment%s." % progress_text
		"collect_samples":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			if reward_text != "":
				objective_desc = "OPTIONAL: Collect alien samples by interacting with sample collection points found on the surface%s. %s" % [progress_text, reward_text]
			else:
				objective_desc = "OPTIONAL: Collect alien samples by interacting with sample collection points found on the surface%s." % progress_text
		"activate_beacons":
			var progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress] if objective.type == MissionObjective.ObjectiveType.PROGRESS else ""
			if reward_text != "":
				objective_desc = "OPTIONAL: Activate beacons by interacting with beacon units scattered across the planet%s. %s" % [progress_text, reward_text]
			else:
				objective_desc = "OPTIONAL: Activate beacons by interacting with beacon units scattered across the planet%s." % progress_text
		"clear_nests":
			if reward_text != "":
				objective_desc = "OPTIONAL: Clear hostile nests by interacting with nest structures found on the alien surface. %s" % reward_text
			else:
				objective_desc = "OPTIONAL: Clear hostile nests by interacting with nest structures found on the alien surface."
		_:
			if reward_text != "":
				objective_desc = "OPTIONAL: %s. %s" % [objective.description, reward_text]
			else:
				objective_desc = "OPTIONAL: %s." % objective.description
	
	# Combine into full description
	var full_text = "%s\n\n%s" % [mission_desc, objective_desc]
	return full_text


func _populate_officers() -> void:
	# Clear existing buttons
	for child in officer_container.get_children():
		child.queue_free()
	officer_buttons.clear()
	selected_officers.clear()
	expanded_officers.clear()
	officer_detail_containers.clear()
	officer_expand_buttons.clear()

	# Create button for each alive officer (including captain)
	for officer_key in GameState.officers:
		if not GameState.is_officer_alive(officer_key):
			continue

		# Create main container for officer entry
		var main_vbox = VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 8)
		
		# Header container with checkbox and expand button
		var header_hbox = HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", 8)
		
		# Checkbox for selection
		var check = CheckButton.new()
		check.text = _get_officer_display_name(officer_key)
		check.add_theme_color_override("font_color", _get_officer_color(officer_key))
		check.add_theme_font_size_override("font_size", 18)
		check.toggled.connect(_on_officer_toggled.bind(officer_key))
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		officer_buttons[officer_key] = check
		header_hbox.add_child(check)
		
		# Expand/collapse button
		var expand_button = Button.new()
		expand_button.text = "[+]"
		expand_button.custom_minimum_size = Vector2(40, 30)
		expand_button.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		expand_button.add_theme_font_size_override("font_size", 16)
		expand_button.pressed.connect(_on_expand_toggled.bind(officer_key))
		header_hbox.add_child(expand_button)
		officer_expand_buttons[officer_key] = expand_button
		
		main_vbox.add_child(header_hbox)
		
		# Brief description (always visible)
		var brief_label = Label.new()
		brief_label.text = _get_officer_brief_description(officer_key)
		brief_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
		brief_label.add_theme_font_size_override("font_size", 14)
		brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brief_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(brief_label)
		
		# Detailed information container (expandable)
		var detail_container = VBoxContainer.new()
		detail_container.add_theme_constant_override("separation", 6)
		detail_container.visible = false
		detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Add detailed sections
		_build_detail_sections(detail_container, officer_key)
		
		officer_detail_containers[officer_key] = detail_container
		main_vbox.add_child(detail_container)
		
		# Separator line
		var separator = ColorRect.new()
		separator.custom_minimum_size = Vector2(0, 1)
		separator.color = Color(0.4, 0.9, 1, 0.2)
		main_vbox.add_child(separator)
		
		officer_container.add_child(main_vbox)


func _get_officer_display_name(key: String) -> String:
	match key:
		"captain": return "CAPTAIN"
		"scout": return "SCOUT"
		"tech": return "TECH"
		"medic": return "MEDIC"
		"heavy": return "HEAVY"
		"sniper": return "SNIPER"
		_: return key.to_upper()


func _get_officer_brief_description(key: String) -> String:
	match key:
		"scout":
			return "High mobility scout with extended vision. Specializes in enemy detection and overwatch."
		"tech":
			return "Combat engineer. Can deploy automated turrets and detect items through walls."
		"medic":
			return "Field surgeon. Heals allies and can see exact HP values of all units."
		"heavy":
			return "Heavily armed bruiser. High damage output and tank-like durability."
		"captain":
			return "Squad leader. Balanced unit with execution ability for finishing wounded enemies."
		"sniper":
			return "Long-range marksman. Extended range and precision targeting capabilities."
		_:
			return ""


func _get_officer_stats(key: String) -> Dictionary:
	match key:
		"captain":
			return {"hp": 100, "move_range": 6, "attack_range": 10}
		"scout":
			return {"hp": 80, "move_range": 7, "attack_range": 10}
		"tech":
			return {"hp": 70, "move_range": 4, "attack_range": 10}
		"medic":
			return {"hp": 75, "move_range": 5, "attack_range": 10}
		"heavy":
			return {"hp": 120, "move_range": 3, "attack_range": 10}
		"sniper":
			return {"hp": 70, "move_range": 4, "attack_range": 12}
		_:
			return {"hp": 0, "move_range": 0, "attack_range": 0}


func _get_officer_passive_abilities(key: String) -> Array[String]:
	match key:
		"scout":
			return ["Extended sight range (+2 tiles, total 8)", "Increased move range (+1 tile, total 7)", "Can see enemy positions even when not in direct LOS"]
		"tech":
			return ["Can hack/interact with tech objects from 5 tiles away", "Can repair/reinforce cover (spend AP to upgrade adjacent cover)", "Turrets deal +25% damage when Tech is nearby (within 3 tiles)"]
		"medic":
			return ["Can see enemy max HP and damage taken this turn", "Healing abilities restore +25% more HP (Patch: 50% → 62.5%)"]
		"heavy":
			return ["Higher base damage (35 vs standard 25)", "Attacks deal 50% splash damage to adjacent enemies", "Enemies within 2 tiles have -10% accuracy (intimidation aura)"]
		"captain":
			return ["Higher base damage (30 vs standard 25)", "Increased move range (+1 tile, total 6)", "Allies within 2 tiles get +20 damage and +15% accuracy (leadership aura)"]
		"sniper":
			return ["Extended sight range (+2 tiles, total 9)", "Extended attack range (+2 tiles, total 12)", "Higher base damage (30)", "+15% accuracy (precision marksman)", "Attacks ignore cover completely"]
		_:
			return []


func _get_officer_active_ability(key: String) -> Dictionary:
	match key:
		"scout":
			return {
				"name": "OVERWATCH",
				"description": "Guaranteed hit on the first enemy that moves within range. Activates automatically when enemy enters line of sight.",
				"ap_cost": 1,
				"cooldown": 2
			}
		"tech":
			return {
				"name": "TURRET",
				"description": "Deploy an auto-firing sentry turret within 2 tiles. Turret lasts 3 turns and automatically attacks nearby enemies.",
				"ap_cost": 1,
				"cooldown": 2
			}
		"medic":
			return {
				"name": "PATCH",
				"description": "Heal yourself or an adjacent ally for 62.5% of their maximum HP (50% base + 25% from Medic's enhanced healing). Restores significant health in critical situations.",
				"ap_cost": 1,
				"cooldown": 2
			}
		"heavy":
			return {
				"name": "CHARGE",
				"description": "Rush an enemy within 4 tiles. Instant-kills basic enemies, deals heavy damage to elite enemies.",
				"ap_cost": 1,
				"cooldown": 2
			}
		"captain":
			return {
				"name": "EXECUTE",
				"description": "Guaranteed kill on an enemy within 4 tiles that is below 50% HP. Never misses, perfect for finishing wounded targets.",
				"ap_cost": 1,
				"cooldown": 2
			}
		"sniper":
			return {
				"name": "PRECISION SHOT",
				"description": "Guaranteed hit on any visible enemy regardless of distance or cover. Deals 2x damage (60 total).",
				"ap_cost": 1,
				"cooldown": 2
			}
		_:
			return {"name": "", "description": "", "ap_cost": 0, "cooldown": 0}


func _build_detail_sections(container: VBoxContainer, officer_key: String) -> void:
	# Base Stats Section
	var stats_label = Label.new()
	stats_label.text = "STATS:"
	stats_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_font_override("font", null)  # Use bold if available
	container.add_child(stats_label)
	
	var stats = _get_officer_stats(officer_key)
	var stats_text = "  HP: %d  |  Move Range: %d tiles  |  Attack Range: %d tiles" % [stats.hp, stats.move_range, stats.attack_range]
	var stats_value_label = Label.new()
	stats_value_label.text = stats_text
	stats_value_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	stats_value_label.add_theme_font_size_override("font_size", 13)
	stats_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(stats_value_label)
	
	# Passive Abilities Section
	var passives = _get_officer_passive_abilities(officer_key)
	if passives.size() > 0:
		var passive_label = Label.new()
		passive_label.text = "PASSIVE ABILITIES:"
		passive_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		passive_label.add_theme_font_size_override("font_size", 14)
		container.add_child(passive_label)
		
		for passive in passives:
			var passive_item = Label.new()
			passive_item.text = "  • %s" % passive
			passive_item.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
			passive_item.add_theme_font_size_override("font_size", 13)
			passive_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(passive_item)
	else:
		var passive_label = Label.new()
		passive_label.text = "PASSIVE ABILITIES: None (balanced unit)"
		passive_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		passive_label.add_theme_font_size_override("font_size", 14)
		container.add_child(passive_label)
	
	# Active Ability Section
	var ability = _get_officer_active_ability(officer_key)
	if ability.has("name") and ability.name != "":
		var ability_label = Label.new()
		ability_label.text = "ACTIVE ABILITY:"
		ability_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		ability_label.add_theme_font_size_override("font_size", 14)
		container.add_child(ability_label)
		
		var ability_name_label = Label.new()
		ability_name_label.text = "  %s" % ability.name
		ability_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		ability_name_label.add_theme_font_size_override("font_size", 13)
		container.add_child(ability_name_label)
		
		var ability_desc_label = Label.new()
		ability_desc_label.text = "  %s" % ability.description
		ability_desc_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
		ability_desc_label.add_theme_font_size_override("font_size", 13)
		ability_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(ability_desc_label)
		
		var ability_cost_label = Label.new()
		ability_cost_label.text = "  Cost: %d AP  |  Cooldown: %d turns" % [ability.ap_cost, ability.cooldown]
		ability_cost_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
		ability_cost_label.add_theme_font_size_override("font_size", 12)
		container.add_child(ability_cost_label)


func _on_expand_toggled(officer_key: String) -> void:
	if not officer_detail_containers.has(officer_key) or not officer_expand_buttons.has(officer_key):
		return
	
	var is_expanded = expanded_officers.get(officer_key, false)
	is_expanded = not is_expanded
	expanded_officers[officer_key] = is_expanded
	
	var detail_container = officer_detail_containers[officer_key]
	detail_container.visible = is_expanded
	
	# Update button text
	var expand_button = officer_expand_buttons[officer_key]
	expand_button.text = "[-]" if is_expanded else "[+]"


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
	deploy_button.disabled = selected_officers.size() < MIN_TEAM_SIZE


func _update_selected_label() -> void:
	selected_label.text = "SELECTED: %d / %d" % [selected_officers.size(), MAX_TEAM_SIZE]


func _on_deploy_pressed() -> void:
	if selected_officers.size() >= MIN_TEAM_SIZE and selected_officers.size() <= MAX_TEAM_SIZE:
		visible = false
		team_selected.emit(selected_officers.duplicate())


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
