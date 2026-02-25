extends Control
## Developer Overlay — floating panel with per-feature dev toggles.
## Activated by Space + D at any point during gameplay.
## All changes persist immediately to user://settings.cfg via GameState.

# Ordered list of toggle definitions: [label, GameState property name]
const TOGGLES: Array = [
	# Resources
	["PROTECT FUEL",      "dev_protect_fuel"],
	["PROTECT INTEGRITY", "dev_protect_integrity"],
	["PROTECT CASH",      "dev_protect_cash"],
	["PROTECT INTEL",     "dev_protect_intel"],
	# Progression
	["OFFICERS MAXED (L3 + 100 DL)", "dev_officers_maxed"],
	# Voyage
	["STORY INTEL COST x1 (vs 3)", "dev_story_intel"],
	["RAIDER FAST RESPAWN (2 vs 10 jumps)", "dev_raider_fast"],
	["RAIDER 1 JUMP PER TURN (vs 2)", "dev_raider_1_jump_per_turn"],
	["WORMHOLE 4x SPAWN RATE", "dev_wormhole_4x"],
	# Tactical
	["STORY TACTICAL EASE (no boss, 1 enemy)", "dev_story_tactical_ease"],
	["RAIDER AMBUSH TACTICAL EASE (no boss, 1 enemy)", "dev_raider_tactical_ease"],
	# Spawn camera
	["SKIP RAIDER SPAWN CAMERA", "dev_skip_raider_spawn_camera"],
	["SKIP STORY SIGNAL SPAWN CAMERA", "dev_skip_story_spawn_camera"],
	["SKIP MISSION RECAP ANIMATIONS", "dev_skip_mission_recap_animations"],
]

const SECTION_HEADERS: Dictionary = {
	0: "RESOURCES",
	4: "PROGRESSION",
	5: "VOYAGE",
	8: "TACTICAL",
	10: "SPAWN CAMERAS",
	12: "RECAP",
}

# Colors matching game palette
const COLOR_HEADER:  Color = Color(1.0,  0.2,  0.2,  1.0)   # red — dev section label
const COLOR_SECTION: Color = Color(0.4,  0.9,  1.0,  1.0)   # cyan — section labels
const COLOR_LABEL:   Color = Color(0.85, 0.85, 0.85, 1.0)   # light grey — toggle labels
const COLOR_TITLE:   Color = Color(1.0,  0.69, 0.0,  1.0)   # gold — title
const COLOR_HINT:    Color = Color(0.4,  0.55, 0.6,  1.0)   # muted — hotkey hint
const BG_COLOR:      Color = Color(0.04, 0.06, 0.10, 0.94)  # near-black panel

var _checks: Array[CheckButton] = []
var _panel: PanelContainer
var _master_check: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false

	_build_ui()
	_sync_from_game_state()


func _build_ui() -> void:
	# Outer centering container — fill viewport so panel centers; click-through when overlay visible
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Panel itself blocks clicks

	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.9, 1.0, 0.6)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)

	var title_label = Label.new()
	title_label.text = "[ DEV PANEL ]"
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "[ CLOSE ]"
	close_btn.add_theme_color_override("font_color", COLOR_HINT)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(toggle)
	title_row.add_child(close_btn)

	_add_separator(vbox)

	# Master Developer Mode toggle
	var master_row = HBoxContainer.new()
	master_row.add_theme_constant_override("separation", 16)
	vbox.add_child(master_row)
	_master_check = CheckButton.new()
	_master_check.toggle_mode = true
	_master_check.add_theme_font_size_override("font_size", 20)
	_master_check.add_theme_color_override("font_color", COLOR_HEADER)
	_master_check.toggled.connect(_on_master_toggled)
	master_row.add_child(_master_check)
	var master_lbl = Label.new()
	master_lbl.text = "DEVELOPER MODE  (all on/off)"
	master_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	master_lbl.add_theme_font_size_override("font_size", 20)
	master_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	master_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_row.add_child(master_lbl)

	_add_separator(vbox)

	# Toggle rows with section headers
	for i in range(TOGGLES.size()):
		var toggle_def: Array = TOGGLES[i]

		if SECTION_HEADERS.has(i):
			if i > 0:
				_add_separator(vbox)
			var sec_label = Label.new()
			sec_label.text = SECTION_HEADERS[i]
			sec_label.add_theme_color_override("font_color", COLOR_SECTION)
			sec_label.add_theme_font_size_override("font_size", 16)
			vbox.add_child(sec_label)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vbox.add_child(row)

		var check = CheckButton.new()
		check.toggle_mode = true
		check.add_theme_font_size_override("font_size", 17)
		var prop_name: String = toggle_def[1]
		check.toggled.connect(_on_toggled.bind(prop_name))
		row.add_child(check)
		_checks.append(check)

		var lbl = Label.new()
		lbl.text = toggle_def[0]
		lbl.add_theme_color_override("font_color", COLOR_LABEL)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

	_add_separator(vbox)

	# Active indicator
	var active_row = HBoxContainer.new()
	vbox.add_child(active_row)
	var active_lbl = Label.new()
	active_lbl.text = "Any flags active:"
	active_lbl.add_theme_color_override("font_color", COLOR_HINT)
	active_lbl.add_theme_font_size_override("font_size", 15)
	active_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_row.add_child(active_lbl)

	var active_val = Label.new()
	active_val.name = "ActiveVal"
	active_val.add_theme_font_size_override("font_size", 15)
	active_row.add_child(active_val)
	_update_active_indicator()

	_add_separator(vbox)

	var reset_row = HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(reset_row)
	var reset_tutorial_btn = Button.new()
	reset_tutorial_btn.name = "ResetTutorialButton"
	reset_tutorial_btn.custom_minimum_size = Vector2(0, 40)
	reset_tutorial_btn.text = "[ RESET TUTORIAL ]"
	reset_tutorial_btn.add_theme_color_override("font_color", COLOR_TITLE)
	reset_tutorial_btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4, 1.0))
	reset_tutorial_btn.add_theme_font_size_override("font_size", 18)
	reset_tutorial_btn.pressed.connect(_on_reset_tutorial_pressed)
	reset_row.add_child(reset_tutorial_btn)


func _add_separator(parent: Control) -> void:
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.4, 0.9, 1.0, 0.2)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


## Sync all CheckButtons and master toggle to match current GameState dev flags.
func _sync_from_game_state() -> void:
	for i in range(TOGGLES.size()):
		var prop_name: String = TOGGLES[i][1]
		var val: bool = GameState.get(prop_name)
		_checks[i].set_pressed_no_signal(val)
	if _master_check:
		_master_check.set_pressed_no_signal(GameState.is_any_dev_flag_active())
	_update_active_indicator()


## Master toggle: enable or disable all developer flags at once.
func _on_master_toggled(toggled_on: bool) -> void:
	for i in range(TOGGLES.size()):
		var prop_name: String = TOGGLES[i][1]
		GameState.set(prop_name, toggled_on)
		_checks[i].set_pressed_no_signal(toggled_on)
	GameState.save_developer_flags()
	_update_active_indicator()


## Called when any individual toggle is flipped.
func _on_toggled(toggled_on: bool, prop_name: String) -> void:
	GameState.set(prop_name, toggled_on)
	GameState.save_developer_flags()
	if _master_check:
		_master_check.set_pressed_no_signal(GameState.is_any_dev_flag_active())
	_update_active_indicator()


func _update_active_indicator() -> void:
	var active_val = _panel.find_child("ActiveVal", true, false) as Label
	if not active_val:
		return
	if GameState.is_any_dev_flag_active():
		active_val.text = "YES"
		active_val.add_theme_color_override("font_color", COLOR_HEADER)
	else:
		active_val.text = "NO"
		active_val.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1.0))


func _on_reset_tutorial_pressed() -> void:
	TutorialManager.reset_all_tutorials()
	var btn = _panel.find_child("ResetTutorialButton", true, false) as Button
	if btn:
		btn.text = "[ TUTORIAL RESET! ]"
		btn.disabled = true
		var t = get_tree().create_timer(1.5)
		t.timeout.connect(func():
			btn.text = "[ RESET TUTORIAL ]"
			btn.disabled = false
		)


## Toggle visibility and re-sync when opening.
func toggle() -> void:
	visible = not visible
	if visible:
		_sync_from_game_state()
