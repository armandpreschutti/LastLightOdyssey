extends Control
## Team Selection Dialog - Choose 3 officers for tactical mission

signal team_selected(officer_keys: Array[String])
signal cancelled

# Updated paths for new styled layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var officer_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficerContainer
@onready var selected_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SelectedLabel
@onready var deploy_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DeployButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

const MAX_TEAM_SIZE: int = 3
const SELECTABLE_OFFICERS: int = 2  # Captain is always included

var officer_buttons: Dictionary = {}  # officer_key -> CheckButton
var selected_officers: Array[String] = []
var current_biome_type: int = -1  # BiomeConfig.BiomeType


func _ready() -> void:
	deploy_button.pressed.connect(_on_deploy_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	visible = false


func show_dialog(biome_type: int = -1) -> void:
	current_biome_type = biome_type
	_update_title()
	_populate_officers()
	_update_selected_label()
	deploy_button.disabled = true
	visible = true


func _update_title() -> void:
	if current_biome_type >= 0:
		var biome_name = BiomeConfig.get_biome_name(current_biome_type)
		title_label.text = "[ SCAVENGE: %s ]" % biome_name.to_upper()
	else:
		title_label.text = "[ SELECT AWAY TEAM ]"


func _populate_officers() -> void:
	# Clear existing buttons
	for child in officer_container.get_children():
		child.queue_free()
	officer_buttons.clear()
	selected_officers.clear()
	
	# Captain is always included (not shown in list)
	selected_officers.append("captain")

	# Create button for each alive officer (except captain who's always deployed)
	for officer_key in GameState.officers:
		if officer_key == "captain":
			continue  # Skip captain - shown at top instead
			
		if not GameState.is_officer_alive(officer_key):
			continue

		# Create container for officer entry
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		
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
		desc_label.custom_minimum_size = Vector2(600, 0)
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
			return "Long-range marksman. Ability: PRECISION SHOT - Guaranteed hit on enemies 8+ tiles away, deals 2x damage (60). (1 AP). 2-turn cooldown."
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
		# Count only non-captain selections
		var non_captain_count = 0
		for key in selected_officers:
			if key != "captain":
				non_captain_count += 1
		
		if non_captain_count < SELECTABLE_OFFICERS:
			selected_officers.append(officer_key)
		else:
			# Can't select more, uncheck
			officer_buttons[officer_key].button_pressed = false
			return
	else:
		selected_officers.erase(officer_key)

	_update_selected_label()
	# Need captain + 2 others = 3 total
	deploy_button.disabled = selected_officers.size() < MAX_TEAM_SIZE


func _update_selected_label() -> void:
	# Count non-captain selections
	var non_captain_count = 0
	for key in selected_officers:
		if key != "captain":
			non_captain_count += 1
	selected_label.text = "SELECTED: %d / %d" % [non_captain_count, SELECTABLE_OFFICERS]


func _on_deploy_pressed() -> void:
	if selected_officers.size() >= MAX_TEAM_SIZE:
		visible = false
		team_selected.emit(selected_officers.duplicate())


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
