extends Control
## Unified Officer Menu — serves as both the BARRACKS (browse) and TEAM SELECT (deploy) screens.
## Mode is set at call time: show_barracks() or show_team_select(biome_type, is_raider_ambush).

enum MenuMode { BARRACKS, TEAM_SELECT }

signal closed
signal team_selected(officer_keys: Array[String], objectives: Array[MissionObjective])
signal cancelled

const PORTRAIT_PATH = "res://assets/sprites/portraits/"
const PORTRAIT_MAP = {
	"captain": "captain_officer_portait.png",
	"scout": "scout_officer_portrait.png",
	"tech": "tech_officer_potrait.png",
	"medic": "medic_officer_portrait.png",
	"heavy": "heavy_officer_portait.png",
	"sniper": "Gemini_Generated_Image_p6wuvwp6wuvwp6wu.png",
}

const ABILITY_ICON_PATH = "res://assets/sprites/ui/icons/abilities/"
const OFFICER_KEYS: Array[String] = ["captain", "scout", "tech", "medic", "heavy", "sniper"]

const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 3

@onready var cards_container: VBoxContainer = $MenuPanel/Layout/ScrollContainer/VBoxContainer
@onready var title_label: Label = $MenuPanel/Layout/MarginWrap/HeaderBar/TitleLabel
@onready var close_button: Button = $MenuPanel/Layout/MarginWrap/HeaderBar/CloseButton
@onready var tech_tree_popup = $AbilitiesTechTree

# Team-select-only nodes (hidden in barracks mode)
@onready var mission_context_margin: MarginContainer = $MenuPanel/Layout/MissionContextMargin
@onready var desc_label: Label = $MenuPanel/Layout/MissionContextMargin/MissionContextVBox/DescLabel
@onready var objective_label: Label = $MenuPanel/Layout/MissionContextMargin/MissionContextVBox/ObjectiveLabel
@onready var separator_top: ColorRect = $MenuPanel/Layout/HSeparatorTop
@onready var separator_bottom: ColorRect = $MenuPanel/Layout/HSeparatorBottom
@onready var footer_margin: MarginContainer = $MenuPanel/Layout/FooterMargin
@onready var selected_label: Label = $MenuPanel/Layout/FooterMargin/FooterVBox/SelectedLabel
@onready var deploy_button: Button = $MenuPanel/Layout/FooterMargin/FooterVBox/ButtonContainer/DeployButton
@onready var cancel_button: Button = $MenuPanel/Layout/FooterMargin/FooterVBox/ButtonContainer/CancelButton
@onready var portrait_slots_container: HBoxContainer = $MenuPanel/Layout/FooterMargin/FooterVBox/PortraitSlots

var _portrait_slot_panels: Array[PanelContainer] = []

# Runtime state
var _mode: MenuMode = MenuMode.BARRACKS
var current_biome_type: int = -1
var _is_raider_ambush: bool = false
var current_objectives: Array[MissionObjective] = []
var selected_officers: Array[String] = []
var officer_buttons: Dictionary = {}
var officer_select_buttons: Dictionary = {}
var expanded_officers: Dictionary = {}
var officer_detail_containers: Dictionary = {}
var officer_expand_buttons: Dictionary = {}
var officer_card_panels: Dictionary = {}


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if deploy_button:
		deploy_button.pressed.connect(_on_deploy_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if tech_tree_popup:
		tech_tree_popup.visibility_changed_to.connect(_on_tech_tree_visibility_changed)
	GameState.officer_progression_changed.connect(func(): if visible: _populate(), CONNECT_DEFERRED)


func _on_tech_tree_visibility_changed(is_visible: bool) -> void:
	if not is_visible and visible:
		_populate()


# ──────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────

func show_barracks() -> void:
	_mode = MenuMode.BARRACKS
	_set_team_select_ui_visible(false)
	close_button.visible = true
	title_label.text = "BARRACKS"
	_populate()
	visible = true


func show_team_select(biome_type: int = -1, is_raider_ambush: bool = false) -> void:
	_mode = MenuMode.TEAM_SELECT
	current_biome_type = biome_type
	_is_raider_ambush = is_raider_ambush
	_set_team_select_ui_visible(true)
	close_button.visible = true
	cancel_button.visible = false
	_update_title()
	_update_description()
	_update_objective()
	_populate()
	_build_portrait_slots()
	_update_selected_label()
	deploy_button.disabled = true
	visible = true


func _on_close_pressed() -> void:
	if _mode == MenuMode.TEAM_SELECT:
		_on_cancel_pressed()
		return
	closed.emit()
	visible = false


# ──────────────────────────────────────────
#  Layout helpers
# ──────────────────────────────────────────

func _set_team_select_ui_visible(show: bool) -> void:
	mission_context_margin.visible = show
	separator_top.visible = show
	separator_bottom.visible = show
	footer_margin.visible = show


# ──────────────────────────────────────────
#  Mission context (team select mode only)
# ──────────────────────────────────────────

func _update_title() -> void:
	if _is_raider_ambush:
		title_label.text = "[ RAIDER AMBUSH ]"
	elif current_biome_type >= 0:
		var biome_name = BiomeConfig.get_biome_name(current_biome_type)
		title_label.text = "[ SCAVENGE: %s ]" % biome_name.to_upper()
	else:
		title_label.text = "[ SELECT AWAY TEAM ]"


func _update_description() -> void:
	if _is_raider_ambush:
		desc_label.text = "Hostile raiders have intercepted your ship! Deploy your team to eliminate the threat."
	elif MIN_TEAM_SIZE == MAX_TEAM_SIZE:
		desc_label.text = "Select %d officers for deployment." % MAX_TEAM_SIZE
	else:
		desc_label.text = "Select %d–%d officers for deployment." % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]


func _update_objective() -> void:
	current_objectives.clear()
	if _is_raider_ambush:
		var objective = MissionObjective.ObjectiveManager.create_eliminate_hostiles()
		current_objectives = [objective]
		objective_label.text = "MISSION: Eliminate all raider units to continue your voyage."
		objective_label.visible = true
	elif current_biome_type >= 0:
		var biome = current_biome_type as BiomeConfig.BiomeType
		var objectives = MissionObjective.ObjectiveManager.get_objectives_for_biome(biome)
		if not objectives.is_empty():
			current_objectives = objectives.duplicate()
			objective_label.text = _build_objective_description(biome, objectives[0])
			objective_label.visible = true
		else:
			objective_label.visible = false
	else:
		objective_label.visible = false


func _build_objective_description(biome: BiomeConfig.BiomeType, objective: MissionObjective) -> String:
	var mission_desc := ""
	match biome:
		BiomeConfig.BiomeType.STATION:
			mission_desc = "Scavenge a derelict space station for resources. Eliminate all hostiles to extract."
		BiomeConfig.BiomeType.ASTEROID:
			mission_desc = "Scavenge an abandoned mining operation. Eliminate all hostiles to extract."
		BiomeConfig.BiomeType.PLANET:
			mission_desc = "Scavenge the alien planetary surface. Eliminate all hostiles to extract."
		_:
			mission_desc = "Scavenge this location for resources. Eliminate all hostiles to extract."

	var potential_rewards = MissionObjective.ObjectiveManager.get_potential_rewards(objective)
	var reward_parts: Array[String] = []
	if potential_rewards.get("fuel", 0) > 0:
		reward_parts.append("%d FUEL" % potential_rewards.get("fuel", 0))
	if potential_rewards.get("cash", 0) > 0:
		reward_parts.append("%d CR" % potential_rewards.get("cash", 0))
	if potential_rewards.get("hull_repair", 0) > 0:
		reward_parts.append("%d%% HULL REPAIR" % potential_rewards.get("hull_repair", 0))
	var reward_text = ""
	if reward_parts.size() > 0:
		reward_text = "REWARD: " + " / ".join(reward_parts)

	var progress_text = ""
	if objective.type == MissionObjective.ObjectiveType.PROGRESS:
		progress_text = " (%d/%d required)" % [objective.progress, objective.max_progress]

	var objective_desc := ""
	match objective.id:
		"hack_security":
			objective_desc = "OPTIONAL: Hack security systems by interacting with security terminals%s." % (". %s" % reward_text if reward_text != "" else ".")
		"retrieve_logs":
			objective_desc = "OPTIONAL: Retrieve data logs by collecting data log devices%s%s." % [progress_text, (". %s" % reward_text if reward_text != "" else "")]
		"repair_core":
			objective_desc = "OPTIONAL: Repair the power core by interacting with power core units%s." % (". %s" % reward_text if reward_text != "" else ".")
		"clear_passages":
			objective_desc = "OPTIONAL: Clear cave passages by eliminating enemies blocking the tunnels%s%s." % [progress_text, (". %s" % reward_text if reward_text != "" else "")]
		"activate_mining":
			objective_desc = "OPTIONAL: Activate mining equipment by interacting with mining units%s." % (". %s" % reward_text if reward_text != "" else ".")
		"extract_minerals":
			objective_desc = "OPTIONAL: Extract rare minerals by interacting with mining equipment%s%s." % [progress_text, (". %s" % reward_text if reward_text != "" else "")]
		"collect_samples":
			objective_desc = "OPTIONAL: Collect alien samples by interacting with sample collection points%s%s." % [progress_text, (". %s" % reward_text if reward_text != "" else "")]
		"activate_beacons":
			objective_desc = "OPTIONAL: Activate beacons by interacting with beacon units%s%s." % [progress_text, (". %s" % reward_text if reward_text != "" else "")]
		"clear_nests":
			objective_desc = "OPTIONAL: Clear hostile nests by interacting with nest structures%s." % (". %s" % reward_text if reward_text != "" else ".")
		_:
			var base = "OPTIONAL: %s%s." % [objective.description, progress_text]
			objective_desc = "%s %s" % [base, reward_text] if reward_text != "" else base

	return "%s\n\n%s" % [mission_desc, objective_desc]


# ──────────────────────────────────────────
#  Population
# ──────────────────────────────────────────

func _populate() -> void:
	if has_node("MenuPanel/Layout/MarginWrap/HeaderBar/DataLogsLabel"):
		$MenuPanel/Layout/MarginWrap/HeaderBar/DataLogsLabel.visible = false

	for child in cards_container.get_children():
		child.queue_free()

	officer_buttons.clear()
	officer_select_buttons.clear()
	selected_officers.clear()
	expanded_officers.clear()
	officer_detail_containers.clear()
	officer_expand_buttons.clear()
	officer_card_panels.clear()

	for officer_key in OFFICER_KEYS:
		var card = _build_officer_card(officer_key)
		cards_container.add_child(card)


func _build_officer_card(officer_key: String) -> Control:
	var od: OfficerData = GameState.get_officer(officer_key)
	var accent: Color = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)
	var is_alive: bool = od != null and od.alive
	var is_injured: bool = od != null and od.is_injured()
	var is_downed: bool = od != null and od.is_downed()
	var is_offline: bool = od == null or not od.alive

	# In team select mode, gray out dead/offline officers
	var card_color: Color = accent
	if _mode == MenuMode.TEAM_SELECT and (is_offline or is_downed):
		card_color = Color(0.45, 0.45, 0.45, 1.0)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _glass_style(card_color))
	if _mode == MenuMode.TEAM_SELECT and (is_offline or is_downed):
		panel.modulate = Color(0.6, 0.6, 0.6, 1.0)
	officer_card_panels[officer_key] = panel

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Portrait (with SELECT button underneath in TEAM_SELECT mode)
	var portrait_vbox = VBoxContainer.new()
	portrait_vbox.add_theme_constant_override("separation", 6)
	portrait_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(portrait_vbox)

	var portrait_file = PORTRAIT_MAP.get(officer_key, "")
	if portrait_file != "":
		var tex = load(PORTRAIT_PATH + portrait_file)
		if tex:
			var portrait = TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(76, 76)
			portrait_vbox.add_child(portrait)


	# Right side
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	# ── Header row ─────────────────────────────
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(header_hbox)

	# Officer name label (used in both modes now)
	var name_label = Label.new()
	name_label.text = officer_key.to_upper()
	name_label.add_theme_color_override("font_color", card_color)
	name_label.add_theme_font_size_override("font_size", 18)
	header_hbox.add_child(name_label)

	# Chosen ability nodes — 3 upgrade slots, directly after the name
	if od != null:
		var header_slots = _create_upgrade_slots(officer_key, 22)
		header_slots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_hbox.add_child(header_slots)

	if _mode == MenuMode.TEAM_SELECT:
		# Injury status label
		if is_downed:
			var inj = Label.new()
			inj.text = "DOWNED (%d JUMPS)" % od.injury_jumps
			inj.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
			inj.add_theme_font_size_override("font_size", 13)
			header_hbox.add_child(inj)
		elif is_injured:
			var inj = Label.new()
			inj.text = "WOUNDED (%d JUMPS)" % od.injury_jumps
			inj.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
			inj.add_theme_font_size_override("font_size", 13)
			header_hbox.add_child(inj)
		elif is_offline:
			var inj = Label.new()
			inj.text = "OFFLINE"
			inj.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			inj.add_theme_font_size_override("font_size", 13)
			header_hbox.add_child(inj)

	else:
		var status_label = Label.new()
		if is_offline:
			status_label.text = "OFFLINE"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif is_downed:
			status_label.text = "DOWNED (%d JUMPS)" % od.injury_jumps
			status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		elif is_injured:
			status_label.text = "WOUNDED (%d JUMPS)" % od.injury_jumps
			status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		else:
			status_label.text = "READY"
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		status_label.add_theme_font_size_override("font_size", 14)
		header_hbox.add_child(status_label)

		if od != null:
			var level_label = Label.new()
			level_label.text = "LVL %d" % od.level
			level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
			level_label.add_theme_font_size_override("font_size", 13)
			header_hbox.add_child(level_label)

	# Spacer to push [+] to the right
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)

	# Expand/collapse button (always shown, right-justified)
	var expand_btn = Button.new()
	expand_btn.text = "[+]"
	expand_btn.custom_minimum_size = Vector2(40, 28)
	expand_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
	expand_btn.add_theme_font_size_override("font_size", 15)
	expand_btn.pressed.connect(_on_expand_toggled.bind(officer_key))
	header_hbox.add_child(expand_btn)
	officer_expand_buttons[officer_key] = expand_btn

	# ── XP bar row with ability nodes on the right ──────────────────
	if od != null:
		var xp_next = od.get_next_xp_threshold()
		var xp_val_text: String
		if _mode == MenuMode.TEAM_SELECT:
			xp_val_text = "LVL %d  |  %d / %d XP" % [od.level, od.xp, xp_next]
		else:
			xp_val_text = "%d / %d XP" % [od.xp, xp_next]

		var xp_bar = _create_progress_row("XP", od.xp, xp_next, Color(0.2, 0.6, 1.0), xp_val_text)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(xp_bar)

	# ── HP bar row with ABILITIES button on the right ───────────────
	if od != null:
		var ab_btn = Button.new()
		ab_btn.text = "[ ABILITIES ]"
		ab_btn.custom_minimum_size = Vector2(140, 28)
		ab_btn.add_theme_font_size_override("font_size", 14)
		ab_btn.add_theme_color_override("font_color", Color.WHITE)
		ab_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.95, 1.0, 1.0))

		ab_btn.pressed.connect(_on_ability_tree_requested.bind(officer_key))

		var hp_row = HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 8)
		var hp_bar = _create_progress_row("HP", od.current_hp, od.max_hp, Color(0.2, 0.9, 0.4), "%d / %d" % [od.current_hp, od.max_hp])
		hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_row.add_child(hp_bar)
		hp_row.add_child(ab_btn)
		right_vbox.add_child(hp_row)

		if GameState.has_available_upgrades(officer_key):
			_start_pulse(ab_btn)

	# ── Brief description (+ SELECT button on same row in team select) ──
	var brief_label = Label.new()
	brief_label.text = _get_officer_brief_description(officer_key)
	brief_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	brief_label.add_theme_font_size_override("font_size", 13)
	brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _mode == MenuMode.TEAM_SELECT and od != null:
		var desc_select_row = HBoxContainer.new()
		desc_select_row.add_theme_constant_override("separation", 8)
		desc_select_row.add_child(brief_label)

		var select_btn = Button.new()
		var can_select = is_alive and not is_downed and not is_offline
		select_btn.text = "[ SELECT ]"
		select_btn.custom_minimum_size = Vector2(161, 30)
		select_btn.add_theme_font_size_override("font_size", 14)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if not can_select:
			select_btn.disabled = true
			select_btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
		else:
			select_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
			select_btn.add_theme_color_override("font_hover_color", Color(0.6, 1, 1, 1))
			select_btn.pressed.connect(_on_select_button_pressed.bind(officer_key))
		officer_select_buttons[officer_key] = select_btn
		desc_select_row.add_child(select_btn)
		right_vbox.add_child(desc_select_row)
	else:
		right_vbox.add_child(brief_label)

	# ── Expandable detail container ─────────────
	var detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 5)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_container.visible = false
	_build_detail_sections(detail_container, officer_key)
	officer_detail_containers[officer_key] = detail_container
	right_vbox.add_child(detail_container)

	return panel


# ──────────────────────────────────────────
#  Selection logic (team select mode)
# ──────────────────────────────────────────

func _on_officer_toggled(pressed: bool, officer_key: String) -> void:
	if pressed:
		if selected_officers.size() < MAX_TEAM_SIZE:
			selected_officers.append(officer_key)
		else:
			officer_buttons[officer_key].button_pressed = false
			return
	else:
		selected_officers.erase(officer_key)
	_update_selected_label()
	deploy_button.disabled = selected_officers.size() < MIN_TEAM_SIZE


func _on_select_button_pressed(officer_key: String) -> void:
	var btn = officer_select_buttons.get(officer_key)
	if not btn:
		return

	var is_selected = officer_key in selected_officers
	var accent: Color = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)
	if is_selected:
		# Deselect — restore cyan hex style
		selected_officers.erase(officer_key)
		btn.text = "[ SELECT ]"
		btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.6, 1, 1, 1))
		# Restore normal panel background
		var card_panel = officer_card_panels.get(officer_key)
		if card_panel:
			card_panel.add_theme_stylebox_override("panel", _glass_style(accent))
	else:
		# Select (if not at max)
		if selected_officers.size() >= MAX_TEAM_SIZE:
			return
		selected_officers.append(officer_key)
		btn.text = "[ SELECTED ]"
		# Yellow hex style
		btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.4, 1))
		# Brighten panel background
		var card_panel = officer_card_panels.get(officer_key)
		if card_panel:
			card_panel.add_theme_stylebox_override("panel", _glass_style_selected(accent))

	_update_selected_label()
	deploy_button.disabled = selected_officers.size() < MIN_TEAM_SIZE


func _update_selected_label() -> void:
	selected_label.text = "SELECTED: %d / %d" % [selected_officers.size(), MAX_TEAM_SIZE]
	_update_portrait_slots()


func _build_portrait_slots() -> void:
	_portrait_slot_panels.clear()
	for child in portrait_slots_container.get_children():
		child.queue_free()
	for i in range(MAX_TEAM_SIZE):
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(50, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.12, 0.6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.4, 0.9, 1, 0.35)
		sb.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", sb)
		portrait_slots_container.add_child(slot)
		_portrait_slot_panels.append(slot)


func _update_portrait_slots() -> void:
	if _portrait_slot_panels.is_empty():
		return
	for i in range(MAX_TEAM_SIZE):
		var slot = _portrait_slot_panels[i]
		# Remove old contents
		for child in slot.get_children():
			child.queue_free()
		if i < selected_officers.size():
			var key = selected_officers[i]

			# Use a plain Control wrapper so PanelContainer doesn't manage layout
			var wrapper = Control.new()
			wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(wrapper)

			var portrait_file = PORTRAIT_MAP.get(key, "")
			if portrait_file != "":
				var tex = load(PORTRAIT_PATH + portrait_file)
				if tex:
					var portrait = TextureRect.new()
					portrait.texture = tex
					portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					portrait.offset_left = 2.5
					portrait.offset_top = 2.5
					portrait.offset_right = -2.5
					portrait.offset_bottom = -2.5
					portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
					wrapper.add_child(portrait)

			# Close badge — 12x12 red circle with white "x", top-right inside slot
			var x_btn = Button.new()
			x_btn.text = "x"
			x_btn.flat = false
			x_btn.custom_minimum_size = Vector2(12, 12)
			x_btn.add_theme_font_size_override("font_size", 8)
			x_btn.add_theme_color_override("font_color", Color.WHITE)
			x_btn.add_theme_color_override("font_hover_color", Color.WHITE)
			x_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
			# Circle style — normal
			var sb_normal = StyleBoxFlat.new()
			sb_normal.bg_color = Color(0.7, 0.15, 0.15, 0.9)
			sb_normal.set_corner_radius_all(6)
			sb_normal.set_content_margin_all(0)
			x_btn.add_theme_stylebox_override("normal", sb_normal)
			# Circle style — hover
			var sb_hover = StyleBoxFlat.new()
			sb_hover.bg_color = Color(0.9, 0.2, 0.2, 1.0)
			sb_hover.set_corner_radius_all(6)
			sb_hover.set_content_margin_all(0)
			x_btn.add_theme_stylebox_override("hover", sb_hover)
			# Circle style — pressed
			var sb_pressed = StyleBoxFlat.new()
			sb_pressed.bg_color = Color(0.5, 0.1, 0.1, 1.0)
			sb_pressed.set_corner_radius_all(6)
			sb_pressed.set_content_margin_all(0)
			x_btn.add_theme_stylebox_override("pressed", sb_pressed)
			# Position: top-right corner, fully inside the slot
			x_btn.anchor_left = 1.0
			x_btn.anchor_top = 0.0
			x_btn.anchor_right = 1.0
			x_btn.anchor_bottom = 0.0
			x_btn.offset_left = -14
			x_btn.offset_top = 2
			x_btn.offset_right = -2
			x_btn.offset_bottom = 14
			x_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			x_btn.pressed.connect(_on_portrait_deselect.bind(key))
			wrapper.add_child(x_btn)


func _on_portrait_deselect(officer_key: String) -> void:
	if officer_key not in selected_officers:
		return
	# Update the SELECT button on the card
	var btn = officer_select_buttons.get(officer_key)
	if btn:
		btn.text = "[ SELECT ]"
		btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.6, 1, 1, 1))
	# Restore card panel background
	var accent: Color = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)
	var card_panel = officer_card_panels.get(officer_key)
	if card_panel:
		card_panel.add_theme_stylebox_override("panel", _glass_style(accent))
	# Remove from selection
	selected_officers.erase(officer_key)
	_update_selected_label()
	deploy_button.disabled = selected_officers.size() < MIN_TEAM_SIZE


func _on_deploy_pressed() -> void:
	if selected_officers.size() >= MIN_TEAM_SIZE and selected_officers.size() <= MAX_TEAM_SIZE:
		deploy_button.disabled = true
		team_selected.emit(selected_officers.duplicate(), current_objectives.duplicate())


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()


# ──────────────────────────────────────────
#  Expand / collapse detail
# ──────────────────────────────────────────

func _on_expand_toggled(officer_key: String) -> void:
	if not officer_detail_containers.has(officer_key):
		return
	var is_expanded = not expanded_officers.get(officer_key, false)
	expanded_officers[officer_key] = is_expanded
	officer_detail_containers[officer_key].visible = is_expanded
	officer_expand_buttons[officer_key].text = "[-]" if is_expanded else "[+]"


# ──────────────────────────────────────────
#  Abilities tech tree
# ──────────────────────────────────────────

func _on_ability_tree_requested(officer_key: String) -> void:
	if tech_tree_popup:
		tech_tree_popup.show_tree(officer_key)


func _start_pulse(target_btn: Button) -> void:
	if not target_btn:
		return
	var base_color: Color = target_btn.get_theme_color("font_color")
	var bright_color := Color(1.0, 0.95, 0.5, 1.0)  # bright yellow-white highlight
	var tween = target_btn.create_tween().set_loops()
	tween.tween_method(func(c: Color): target_btn.add_theme_color_override("font_color", c), base_color, bright_color, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(c: Color): target_btn.add_theme_color_override("font_color", c), bright_color, base_color, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ──────────────────────────────────────────
#  Officer detail helpers
# ──────────────────────────────────────────

func _build_detail_sections(container: VBoxContainer, officer_key: String) -> void:
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.4, 0.9, 1, 0.2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sep)

	var stats_header = _detail_label("STATS:", Color(0.4, 0.9, 1, 1), 13)
	container.add_child(stats_header)

	var stats = _get_officer_stats(officer_key)
	var stats_val = _detail_label(
		"  Move: %d tiles  |  Range: %d tiles" % [stats.move_range, stats.attack_range],
		Color(0.6, 0.8, 0.9), 12)
	stats_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(stats_val)

	var passives = _get_officer_passive_abilities(officer_key)
	if passives.size() > 0:
		container.add_child(_detail_label("PASSIVES:", Color(0.4, 0.9, 1, 1), 13))
		for p in passives:
			var pl = _detail_label("  • %s" % p, Color(0.7, 0.9, 1), 12)
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(pl)
	else:
		container.add_child(_detail_label("PASSIVES: None (balanced unit)", Color(0.4, 0.9, 1, 1), 13))

	var ability = _get_officer_active_ability(officer_key)
	if ability.get("name", "") != "":
		container.add_child(_detail_label("ACTIVE ABILITY:", Color(0.4, 0.9, 1, 1), 13))
		container.add_child(_detail_label("  %s" % ability.name, Color(1.0, 0.85, 0.3), 12))
		var desc_lbl = _detail_label("  %s" % ability.description, Color(0.7, 0.9, 1), 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(desc_lbl)
		container.add_child(_detail_label(
			"  Cost: %d AP  |  Cooldown: %d turns" % [ability.ap_cost, ability.cooldown],
			Color(0.6, 0.8, 0.9), 12))


func _detail_label(text: String, color: Color, font_size: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _get_officer_brief_description(key: String) -> String:
	match key:
		"captain": return "Squad leader. Balanced unit with execution ability for finishing wounded enemies."
		"scout":   return "High mobility scout with extended vision. Specializes in enemy detection and overwatch."
		"tech":    return "Combat engineer. Can deploy automated turrets and detect items through walls."
		"medic":   return "Field surgeon. Heals allies and can see exact HP values of all units."
		"heavy":   return "Heavily armed bruiser. High damage output and tank-like durability."
		"sniper":  return "Long-range marksman. Extended range and precision targeting capabilities."
		_:         return ""


func _get_officer_stats(key: String) -> Dictionary:
	match key:
		"captain": return {"hp": 100, "move_range": 6, "attack_range": 10}
		"scout":   return {"hp": 80,  "move_range": 7, "attack_range": 10}
		"tech":    return {"hp": 70,  "move_range": 4, "attack_range": 10}
		"medic":   return {"hp": 75,  "move_range": 5, "attack_range": 10}
		"heavy":   return {"hp": 120, "move_range": 3, "attack_range": 10}
		"sniper":  return {"hp": 70,  "move_range": 4, "attack_range": 12}
		_:         return {"hp": 0, "move_range": 0, "attack_range": 0}


func _get_officer_passive_abilities(key: String) -> Array[String]:
	match key:
		"scout":
			return [
				"Extended sight range (+2 tiles, total 8)",
				"Increased move range (+1 tile, total 7)",
				"Can see enemy positions even when not in direct LOS"
			]
		"tech":
			return [
				"Can hack/interact with tech objects from 5 tiles away",
				"Can repair/reinforce cover",
				"Turrets deal +25% damage when Tech is nearby (within 3 tiles)"
			]
		"medic":
			return [
				"Can see enemy max HP and damage taken this turn",
				"Healing abilities restore +25% more HP"
			]
		"heavy":
			return [
				"Higher base damage (35 vs standard 25)",
				"Attacks deal 50% splash damage to adjacent enemies",
				"Enemies within 2 tiles have -10% accuracy (intimidation aura)"
			]
		"captain":
			return [
				"Higher base damage (30 vs standard 25)",
				"Increased move range (+1 tile, total 6)",
				"Allies within 2 tiles get +20 damage and +15% accuracy (leadership aura)"
			]
		"sniper":
			return [
				"Extended sight range (+2 tiles, total 9)",
				"Extended attack range (+2 tiles, total 12)",
				"Higher base damage (30)",
				"+15% accuracy (precision marksman)",
				"Attacks ignore cover completely"
			]
		_:
			return []


func _get_officer_active_ability(key: String) -> Dictionary:
	match key:
		"scout":
			return {
				"name": "OVERWATCH",
				"description": "Guaranteed hit on the first enemy that moves within range.",
				"ap_cost": 1, "cooldown": 2
			}
		"tech":
			return {
				"name": "TURRET",
				"description": "Deploy an auto-firing sentry turret within 2 tiles. Lasts 3 turns.",
				"ap_cost": 1, "cooldown": 2
			}
		"medic":
			return {
				"name": "PATCH",
				"description": "Heal yourself or an adjacent ally for 62.5% of their max HP.",
				"ap_cost": 1, "cooldown": 2
			}
		"heavy":
			return {
				"name": "CHARGE",
				"description": "Rush an enemy within 4 tiles. Instant-kills basic enemies, deals heavy damage to elites.",
				"ap_cost": 1, "cooldown": 2
			}
		"captain":
			return {
				"name": "EXECUTE",
				"description": "Guaranteed kill on an enemy within 4 tiles that is below 50% HP.",
				"ap_cost": 1, "cooldown": 2
			}
		"sniper":
			return {
				"name": "PRECISION SHOT",
				"description": "Guaranteed hit on any visible enemy. Deals 2x damage (60 total).",
				"ap_cost": 1, "cooldown": 2
			}
		_:
			return {"name": "", "description": "", "ap_cost": 0, "cooldown": 0}


# ──────────────────────────────────────────
#  Shared UI builders
# ──────────────────────────────────────────

func _create_upgrade_slots(officer_key: String, icon_size: int) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_END # Right-justify slots

	var od = GameState.get_officer(officer_key)
	if not od:
		return hbox

	var abilities = GameState.OFFICER_ABILITIES.get(officer_key, [])
	if abilities.size() < 6:
		return hbox

	var tiers = [
		[abilities[0]],
		[abilities[1], abilities[2]],
		[abilities[3], abilities[4], abilities[5]]
	]
	var accent = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)

	for i in range(3):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(icon_size + 4, icon_size + 4)

		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.05)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.2)
		sb.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", sb)

		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var unlocked_ab_id = ""
		for ab_id in tiers[i]:
			if od.has_ability(ab_id):
				unlocked_ab_id = ab_id
				break

		if unlocked_ab_id != "":
			var tooltip_handler = preload("res://scripts/ui/ability_tooltip_handler.gd").new()
			slot_panel.add_child(tooltip_handler)
			tooltip_handler.setup(slot_panel, unlocked_ab_id)

			var icon_file = "%s_%s.png" % [officer_key, unlocked_ab_id]
			var tex = load(ABILITY_ICON_PATH + icon_file)
			if tex:
				icon_rect.texture = tex
				icon_rect.modulate = Color(1, 1, 1, 1)
			else:
				icon_rect.modulate = Color(accent.r, accent.g, accent.b, 0.5)
		else:
			icon_rect.modulate = Color(0.2, 0.2, 0.2, 0.3)

		slot_panel.add_child(icon_rect)
		hbox.add_child(slot_panel)

	return hbox


func _create_progress_row(label_text: String, val: float, max_val: float, bar_color: Color, value_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(40, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	hbox.add_child(label)

	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(max_val, 1)
	bar.value = val
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(330, 24)

	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.3)
	sb_bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = bar_color
	sb_fill.bg_color.a = 0.7
	sb_fill.set_corner_radius_all(2)
	sb_fill.border_width_right = 1
	sb_fill.border_color = Color(1, 1, 1, 0.3)
	bar.add_theme_stylebox_override("fill", sb_fill)

	var val_label = Label.new()
	val_label.text = value_text
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(val_label)

	hbox.add_child(bar)
	return hbox


func _glass_style(accent: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.08, 0.65)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	sb.shadow_size = 5
	return sb


func _glass_style_selected(accent: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.shadow_size = 8
	return sb
