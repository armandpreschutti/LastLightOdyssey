extends Control
## Barracks Menu — Officer progression, ability unlock, and status viewer

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

@onready var cards_container: VBoxContainer = $MenuPanel/Layout/ScrollContainer/VBoxContainer
@onready var close_button: Button = $MenuPanel/Layout/MarginWrap/HeaderBar/CloseButton
@onready var tech_tree_popup = $AbilitiesTechTree 


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


func show_barracks() -> void:
	_populate()
	visible = true


func _on_close_pressed() -> void:
	visible = false


func _populate() -> void:
	# Hide global data log label if it exists (no longer relevant)
	if has_node("MenuPanel/Layout/MarginWrap/HeaderBar/DataLogsLabel"):
		$MenuPanel/Layout/MarginWrap/HeaderBar/DataLogsLabel.visible = false

	# Clear existing cards
	for child in cards_container.get_children():
		child.free()

	# Build one card per officer
	for officer_key in ["captain", "scout", "tech", "medic", "heavy", "sniper"]:
		var card = _build_officer_card(officer_key)
		cards_container.add_child(card)


func _build_officer_card(officer_key: String) -> Control:
	var od: OfficerData = GameState.get_officer(officer_key)
	var accent = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)

	# Card panel
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _glass_style(accent))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Portrait
	var portrait_file = PORTRAIT_MAP.get(officer_key, "")
	if portrait_file != "":
		var tex = load(PORTRAIT_PATH + portrait_file)
		if tex:
			var portrait = TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(72, 72)
			portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			hbox.add_child(portrait)

	# Right side
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)

	# Horizontal split for stats and actions
	var stats_actions_hbox = HBoxContainer.new()
	stats_actions_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(stats_actions_hbox)

	# Left inner VBox for Stats (Name, XP, HP)
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	stats_actions_hbox.add_child(left_vbox)

	# Name + status row
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(name_row)

	var name_label = Label.new()
	name_label.text = officer_key.to_upper()
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_font_size_override("font_size", 18)
	name_row.add_child(name_label)

	var status_label = Label.new()
	if not od or not od.alive:
		status_label.text = "K.I.A."
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	elif od.is_injured():
		status_label.text = "INJURED (%d JUMPS)" % od.injury_jumps
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	else:
		status_label.text = "READY"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	status_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(status_label)

	if od == null or not od.alive:
		return panel

	# Level label
	var level_label = Label.new()
	level_label.text = "LVL %d" % od.level
	level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	level_label.add_theme_font_size_override("font_size", 13)
	name_row.add_child(level_label)

	var xp_next = od.get_next_xp_threshold()
	var xp_val_text = "%d / %d XP" % [od.xp, xp_next]
	var xp_bar_row = _create_progress_row("XP", od.xp, xp_next, Color(0.2, 0.6, 1.0), xp_val_text)
	left_vbox.add_child(xp_bar_row)


	var hp_bar_row = _create_progress_row("HP", od.current_hp, od.max_hp, Color(0.2, 0.9, 0.4), "%d / %d" % [od.current_hp, od.max_hp])
	left_vbox.add_child(hp_bar_row)

	# Right inner VBox for Actions (Upgrades + Button)
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_actions_hbox.add_child(right_vbox)

	# Upgrade Slots
	var slots_row = _create_upgrade_slots(officer_key, 24)
	right_vbox.add_child(slots_row)

	# Abilities Button
	var ab_btn = Button.new()
	ab_btn.text = "ABILITIES"
	ab_btn.custom_minimum_size = Vector2(140, 32)
	ab_btn.add_theme_font_size_override("font_size", 14)
	ab_btn.add_theme_color_override("font_color", accent)
	
	var btn_sb = _glass_style(accent)
	btn_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	ab_btn.add_theme_stylebox_override("normal", btn_sb)
	
	var btn_hover = btn_sb.duplicate()
	btn_hover.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	ab_btn.add_theme_stylebox_override("hover", btn_hover)
	
	ab_btn.pressed.connect(_on_ability_tree_requested.bind(officer_key))
	right_vbox.add_child(ab_btn)

	return panel


func _on_ability_tree_requested(officer_key: String) -> void:
	if tech_tree_popup:
		tech_tree_popup.show_tree(officer_key)


	GameState.save_game()
	_populate()


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


func _create_upgrade_slots(officer_key: String, icon_size: int) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER # Center in Barracks card
	
	var od = GameState.get_officer(officer_key)
	if not od: return hbox
	
	var abilities = GameState.OFFICER_ABILITIES.get(officer_key, [])
	if abilities.size() < 6: return hbox
	
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
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Important!
		
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
	label.custom_minimum_size = Vector2(40, 0) # Slightly wider for labels
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	hbox.add_child(label)
	
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val
	bar.value = val
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(330, 24) # 3x longer (330) and slightly taller (24)
	
	# Background style
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.3)
	sb_bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", sb_bg)
	
	# Fill style
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = bar_color
	sb_fill.bg_color.a = 0.7
	sb_fill.set_corner_radius_all(2)
	sb_fill.border_width_right = 1
	sb_fill.border_color = Color(1, 1, 1, 0.3)
	bar.add_theme_stylebox_override("fill", sb_fill)
	
	# Overlaying value text
	var val_label = Label.new()
	val_label.text = value_text
	val_label.add_theme_font_size_override("font_size", 14) # Bigger internal numbers
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(val_label)
	
	hbox.add_child(bar)
	return hbox
