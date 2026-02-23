extends Control
## Abilities Tech Tree — Visual progression for a single officer

const ABILITY_ICON_PATH = "res://assets/sprites/ui/icons/abilities/"

signal visibility_changed_to(is_visible: bool)

@onready var title_label = $Panel/VBox/Header/TitleLabel
@onready var data_logs_label = $Panel/VBox/Header/DataLogsLabel
@onready var close_button = $Panel/VBox/Header/CloseButton
@onready var tree_container = $Panel/VBox/TreeArea/TreeContent
@onready var connection_layer = $Panel/VBox/TreeArea/TreeContent/ConnectionLayer
@onready var main_panel = $Panel
@onready var description_label = $Panel/VBox/DescriptionBox/Margin/DescriptionLabel

const RESET_COST_DL: int = 1

var current_officer_key: String = ""
var node_map: Dictionary = {} # id -> node instance
var footer_slots_container: HBoxContainer = null
var reset_button: Button = null

func _ready():
	visible = false
	close_button.pressed.connect(hide_tree)
	_setup_footer()


func _refresh_header_stats():
	var od = GameState.get_officer(current_officer_key)
	if not od: return

	data_logs_label.text = "Data Logs: %d" % od.data_logs

	# Update XP bar and Level if they exist
	var level_lbl = $Panel/VBox/Header.get_node_or_null("LevelLabel")
	if level_lbl:
		level_lbl.text = "LEVEL %d" % od.level

	var xp_bar = $Panel/VBox/Header.get_node_or_null("XPBar")
	if xp_bar:
		var next_xp = od.get_next_xp_threshold()
		xp_bar.max_value = next_xp
		xp_bar.value = od.xp
		var xp_text = xp_bar.get_node_or_null("XPText")
		if xp_text:
			xp_text.text = "%d / %d XP" % [od.xp, next_xp]


func show_tree(officer_key: String):
	current_officer_key = officer_key
	var od = GameState.get_officer(officer_key)
	if not od: return

	var accent = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)
	title_label.text = "%s ABILITIES" % officer_key.to_upper()
	title_label.add_theme_color_override("font_color", accent)
	
	# XP/Level Header Logic
	_setup_header_progression(accent)
	_refresh_header_stats()
	
	main_panel.add_theme_stylebox_override("panel", _glass_style(accent))
	main_panel.custom_minimum_size = Vector2(920, 740) # Increased to prevent clipping
	connection_layer.officer_key = officer_key
	
	_build_tree()
	visible = true
	visibility_changed_to.emit(true)


func _setup_header_progression(accent: Color):
	var header = $Panel/VBox/Header

	# Remove existing custom elements to avoid duplicates
	# Must remove_child first so they leave the layout immediately; queue_free alone is deferred
	for child in [header.get_node_or_null("LevelLabel"), header.get_node_or_null("XPBar")]:
		if child:
			header.remove_child(child)
			child.queue_free()

	# Level Label
	var level_lbl = Label.new()
	level_lbl.name = "LevelLabel"
	level_lbl.add_theme_font_size_override("font_size", 18)
	level_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	header.add_child(level_lbl)
	header.move_child(level_lbl, 1) # Put it after title

	# XP Bar (matching BarracksMenu style)
	var bar = ProgressBar.new()
	bar.name = "XPBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(250, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.3)
	sb_bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.2, 0.6, 1.0, 0.7)
	sb_fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", sb_fill)

	var val_label = Label.new()
	val_label.name = "XPText"
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(val_label)

	header.add_child(bar)
	header.move_child(bar, 2)


func hide_tree():
	visible = false
	visibility_changed_to.emit(false)


func _glass_style(accent: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.1, 0.85) # Slightly darker for popup
	sb.border_width_left = 3
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	return sb


func _build_tree():
	# Clear previous nodes
	for child in tree_container.get_children():
		if child == connection_layer: continue
		child.queue_free()
	node_map.clear()

	var abilities = GameState.OFFICER_ABILITIES.get(current_officer_key, [])
	if abilities.is_empty(): return

	# Setup tiers
	var l1 = [abilities[0]]
	var l2 = [abilities[1], abilities[2]]
	var l3 = [abilities[3], abilities[4], abilities[5]]

	# Positioning constants (Bottom-Up) — sized to fill TreeContent (900x500) with minimal padding
	var center_x = 450
	var vertical_spacing = 195
	var horizontal_spacing = 360
	var start_y = 458 # Root near bottom

	# Instantiate nodes
	_create_node(l1[0], Vector2(center_x, start_y))
	
	_create_node(l2[0], Vector2(center_x - horizontal_spacing/2, start_y - vertical_spacing))
	_create_node(l2[1], Vector2(center_x + horizontal_spacing/2, start_y - vertical_spacing))
	
	_create_node(l3[0], Vector2(center_x - horizontal_spacing, start_y - vertical_spacing * 2))
	_create_node(l3[1], Vector2(center_x, start_y - vertical_spacing * 2))
	_create_node(l3[2], Vector2(center_x + horizontal_spacing, start_y - vertical_spacing * 2))

	_update_unlock_states()
	connection_layer.queue_redraw()


func _create_node(ab_id: String, pos: Vector2):
	var node = preload("res://scenes/ui/ability_tree_node.tscn").instantiate()
	tree_container.add_child(node)
	node.position = pos - Vector2(40, 40) # Center the 80x80 node
	node.setup(ab_id, current_officer_key)
	node.unlock_requested.connect(_on_unlock_requested)
	node.hovered.connect(_on_node_hovered)
	node.unhovered.connect(_on_node_unhovered)
	node_map[ab_id] = node


func _update_unlock_states():
	var od = GameState.get_officer(current_officer_key)
	for ab_id in node_map:
		var node = node_map[ab_id]
		var def = GameState.ABILITY_DEFS.get(ab_id, {})
		var tier = def.get("level", 1)
		
		# Tier 1 is always unlocked
		if tier == 1 and not od.has_ability(ab_id):
			od.unlock_ability(ab_id)
			
		var is_unlocked = od.has_ability(ab_id)
		var is_available = false
		var cost = 0
		
		if not is_unlocked:
			if tier == 2:
				is_available = od.can_unlock_level2(od.data_logs)
				cost = OfficerData.DATA_LOGS_LEVEL2_COST
			elif tier == 3:
				is_available = od.can_unlock_level3(od.data_logs)
				cost = OfficerData.DATA_LOGS_LEVEL3_COST
		
		# Check if another ability in the same tier is already unlocked
		var tier_locked = false
		if not is_unlocked and tier > 1:
			var tier_abs = []
			var all_abs = GameState.OFFICER_ABILITIES[current_officer_key]
			if tier == 2: tier_abs = [all_abs[1], all_abs[2]]
			elif tier == 3: tier_abs = [all_abs[3], all_abs[4], all_abs[5]]
			
			for other_ab in tier_abs:
				if od.has_ability(other_ab):
					tier_locked = true
					break
		
		if tier_locked:
			is_available = false
			
		# Connectivity check: Node must be connected to an unlocked node
		if not is_unlocked and is_available:
			var all_abs = GameState.OFFICER_ABILITIES[current_officer_key]
			var idx = all_abs.find(ab_id)
			
			if tier == 2:
				# Level 2 nodes (idx 1, 2) require Level 1 (idx 0)
				if not od.has_ability(all_abs[0]):
					is_available = false
			elif tier == 3:
				# Level 3 nodes (idx 3, 4, 5) requirements based on layout:
				# idx 3 (Left) requires idx 1 (Left L2)
				# idx 4 (Center) requires idx 1 OR idx 2 (Either L2)
				# idx 5 (Right) requires idx 2 (Right L2)
				if idx == 3:
					if not od.has_ability(all_abs[1]):
						is_available = false
				elif idx == 4:
					if not (od.has_ability(all_abs[1]) or od.has_ability(all_abs[2])):
						is_available = false
				elif idx == 5:
					if not od.has_ability(all_abs[2]):
						is_available = false

		node.update_state(is_unlocked, is_available, cost)
	
	if connection_layer:
		connection_layer.queue_redraw()
	
	_update_footer_slots()


func _on_unlock_requested(ab_id: String, cost: int):
	var od = GameState.get_officer(current_officer_key)
	if od.data_logs >= cost:
		od.data_logs -= cost
		od.unlock_ability(ab_id)
		
		# Advance level logic is now internal to unlock_ability/add_xp but let's ensure consistency
		# Actually, unlock_ability just adds to the list. 
		# If it's a higher tier, we might want to ensure level matches, but add_xp already handles auto-level.
		# For manual unlocks, we just deduct DL and add ability.
			
		GameState.save_game()
		GameState.officer_progression_changed.emit()
		_update_unlock_states()
		_refresh_header_stats()
		# Add a nice effect here if possible


# Signal Handlers for Node Hover
func _on_node_hovered(desc: String):
	description_label.text = desc
	description_label.modulate = Color(1, 1, 1, 1)

func _on_node_unhovered():
	description_label.text = "Hover over an ability to see details."
	description_label.modulate = Color(0.9, 0.9, 0.9, 0.8)


# Connection Layer Drawing
func _draw_connections():
	connection_layer.clear() # If using Custom Drawing
	# We'll put drawing logic in the ConnectionLayer child script
	pass


func _setup_footer():
	# Create a footer section for the chosen upgrades
	var footer_panel = PanelContainer.new()
	footer_panel.custom_minimum_size = Vector2(0, 60)
	
	# Glassy style for footer
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.3)
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.1)
	footer_panel.add_theme_stylebox_override("panel", sb)
	
	$Panel/VBox.add_child(footer_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	footer_panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var label = Label.new()
	label.text = "CHOSEN UPGRADES:"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 0.6))
	hbox.add_child(label)
	
	footer_slots_container = HBoxContainer.new()
	footer_slots_container.add_theme_constant_override("separation", 12)
	footer_slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(footer_slots_container)

	# Reset button - use same outline style as CloseButton / other UI buttons
	reset_button = Button.new()
	reset_button.text = "[ RESET ABILITIES (1 DL) ]"
	reset_button.pressed.connect(_on_reset_abilities_pressed)
	reset_button.add_theme_stylebox_override("normal", load("res://assets/themes/style_btn_red.tres") as StyleBox)
	reset_button.add_theme_stylebox_override("hover", load("res://assets/themes/style_btn_red_hover.tres") as StyleBox)
	reset_button.add_theme_stylebox_override("pressed", load("res://assets/themes/style_btn_red_pressed.tres") as StyleBox)
	reset_button.add_theme_stylebox_override("disabled", load("res://assets/themes/style_btn_red.tres") as StyleBox)
	reset_button.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	reset_button.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.3))
	reset_button.add_theme_font_size_override("font_size", 12)
	reset_button.tooltip_text = "Clear all L2 and L3 ability choices. Level 1 ability is kept. Costs 1 Data Log."
	hbox.add_child(reset_button)


func _on_reset_abilities_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	var od = GameState.get_officer(current_officer_key)
	if not od: return
	if od.data_logs < RESET_COST_DL:
		return
	var abilities = GameState.OFFICER_ABILITIES.get(current_officer_key, [])
	if abilities.size() < 2:
		return
	# Check if there are any L2/L3 to reset
	var has_l2_or_l3 := false
	for i in range(1, abilities.size()):
		if od.has_ability(abilities[i]):
			has_l2_or_l3 = true
			break
	if not has_l2_or_l3:
		return
	_show_reset_confirmation()


func _show_reset_confirmation() -> void:
	var dialog_scene = load("res://scenes/ui/confirm_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.z_index = 100
	add_child(dialog)
	dialog.setup(
		"[ RESET ABILITIES? ]",
		"This will clear all Level 2 and Level 3 ability choices.\nThe Level 1 ability will be kept.\n\nCosts 1 Data Log. This cannot be undone!",
		"RESET",
		"CANCEL"
	)
	dialog.confirmed.connect(_do_reset_abilities)
	dialog.show_dialog()


func _do_reset_abilities() -> void:
	var od = GameState.get_officer(current_officer_key)
	if not od: return
	od.data_logs -= RESET_COST_DL
	od.reset_abilities_above_level1()
	GameState.save_game()
	GameState.officer_progression_changed.emit()
	_update_unlock_states()
	_refresh_header_stats()


func _update_footer_slots():
	if not footer_slots_container: return
	
	# Update reset button state
	if reset_button:
		var od = GameState.get_officer(current_officer_key)
		var can_reset = false
		if od:
			var abilities = GameState.OFFICER_ABILITIES.get(current_officer_key, [])
			if abilities.size() >= 2 and od.data_logs >= RESET_COST_DL:
				for i in range(1, abilities.size()):
					if od.has_ability(abilities[i]):
						can_reset = true
						break
		reset_button.disabled = not can_reset
	
	# Clear previous (use immediate free to avoid one-frame doubling with deferred queue_free)
	for child in footer_slots_container.get_children():
		child.free()
		
	var od = GameState.get_officer(current_officer_key)
	if not od: return
	
	var abilities = GameState.OFFICER_ABILITIES.get(current_officer_key, [])
	if abilities.size() < 6: return
	
	var tiers = [
		[abilities[0]],
		[abilities[1], abilities[2]],
		[abilities[3], abilities[4], abilities[5]]
	]
	
	var accent = GameState.OFFICER_COLOR.get(current_officer_key, Color.WHITE)
	var icon_size = 32
	
	for i in range(3):
		var slot_vbox = VBoxContainer.new() # To add Level Label
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		footer_slots_container.add_child(slot_vbox)
		
		var lvl_label = Label.new()
		lvl_label.text = "LVL %d" % (i + 1)
		lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_label.add_theme_font_size_override("font_size", 10)
		lvl_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.4))
		slot_vbox.add_child(lvl_label)
		
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(icon_size + 6, icon_size + 6)
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.05)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.2)
		sb.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", sb)
		slot_vbox.add_child(slot_panel)
		
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
			var def = GameState.ABILITY_DEFS.get(unlocked_ab_id, {})
			var ab_name = def.get("name", "Unknown")
			var ab_desc = def.get("desc", "")
			var tooltip_text = "%s: %s" % [ab_name, ab_desc]

			# Use tooltip_area for proper tooltip support
			slot_panel.set_script(preload("res://scripts/ui/tooltip_area.gd"))
			slot_panel.tooltip_delay_sec = 0.25
			slot_panel.tooltip_text = tooltip_text

			# Also update the static description box immediately on hover
			slot_panel.mouse_entered.connect(_on_node_hovered.bind(def.get("desc", "")))
			slot_panel.mouse_exited.connect(_on_node_unhovered)

			var icon_file = "%s_%s.png" % [current_officer_key, unlocked_ab_id]
			var tex = load(ABILITY_ICON_PATH + icon_file)
			if tex:
				icon_rect.texture = tex
				icon_rect.modulate = Color(1, 1, 1, 1)
			else:
				icon_rect.modulate = Color(accent.r, accent.g, accent.b, 0.5)
		else:
			icon_rect.modulate = Color(0.2, 0.2, 0.2, 0.3)
		
		slot_panel.add_child(icon_rect)
