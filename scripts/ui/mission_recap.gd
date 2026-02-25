extends Control
## Mission Recap Screen - Shows post-mission summary with stats and "beaming up" animation
## Displayed after extraction before returning to management mode

signal recap_dismissed

@onready var fuel_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/FuelRow
@onready var enemies_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/EnemiesRow
@onready var turns_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/TurnsRow
@onready var objectives_header: Label = $PanelContainer/MarginContainer/VBoxContainer/ObjectivesHeader
@onready var objectives_border: ColorRect = $PanelContainer/MarginContainer/VBoxContainer/ObjectivesBorder
@onready var objectives_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ObjectivesContainer
# Updated paths for new icon-based layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var outcome_label: Label = $PanelContainer/MarginContainer/VBoxContainer/OutcomeLabel
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/FuelRow/FuelLabel
@onready var enemies_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/EnemiesRow/EnemiesLabel
@onready var turns_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/TurnsRow/TurnsLabel
@onready var officers_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficersContainer
@onready var stats_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer
@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

var cash_row: HBoxContainer
var cash_label: Label
var xp_row: HBoxContainer
var xp_label: Label
var _stat_tween: Tween = null

var _objective_labels: Array[Label] = []
var _mission_success: bool = false


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Create CashRow programmatically if not in scene
	if not stats_container.has_node("CashRow"):
		cash_row = HBoxContainer.new()
		cash_row.name = "CashRow"
		cash_row.add_theme_constant_override("separation", 10)
		
		var cash_icon = TextureRect.new()
		cash_icon.custom_minimum_size = Vector2(24, 24)
		cash_icon.texture = load("res://assets/sprites/ui/icons/icon_cash.png")
		cash_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cash_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cash_row.add_child(cash_icon)
		
		cash_label = Label.new()
		cash_label.name = "CashLabel"
		cash_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5)) # Green
		cash_label.add_theme_font_override("font", load("res://assets/fonts/VT323-Regular.ttf"))
		cash_label.add_theme_font_size_override("font_size", 20)
		cash_row.add_child(cash_label)
		
		stats_container.add_child(cash_row)
		# Position it after fuel
		stats_container.move_child(cash_row, 2)
	else:
		cash_row = stats_container.get_node("CashRow")
		cash_label = cash_row.get_node("CashLabel")

	# Create XP Row programmatically if not in scene
	if not stats_container.has_node("XPRow"):
		xp_row = HBoxContainer.new()
		xp_row.name = "XPRow"
		xp_row.add_theme_constant_override("separation", 10)
		
		var xp_icon = TextureRect.new()
		xp_icon.custom_minimum_size = Vector2(24, 24)
		xp_icon.texture = load("res://assets/sprites/ui/icons/icon_ap.png") # Reuse AP icon for progression theme
		xp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		xp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		xp_row.add_child(xp_icon)
		
		xp_label = Label.new()
		xp_label.name = "XPLabel"
		xp_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0)) # Cyan
		xp_label.add_theme_font_override("font", load("res://assets/fonts/VT323-Regular.ttf"))
		xp_label.add_theme_font_size_override("font_size", 20)
		xp_row.add_child(xp_label)
		
		stats_container.add_child(xp_row)
		# Position it after cash
		stats_container.move_child(xp_row, 3)
	else:
		xp_row = stats_container.get_node("XPRow")
		xp_label = xp_row.get_node("XPLabel")

	# HOSTILES ELIMINATED goes after TOTAL XP AWARDED (before TURNS SURVIVED)
	stats_container.move_child(enemies_row, turns_row.get_index() - 1)




func show_recap(stats: Dictionary) -> void:
	var success: bool = stats.get("success", false)
	_mission_success = success
	var fuel_collected: int = stats.get("fuel_collected", 0)
	var enemies_killed: int = stats.get("enemies_killed", 0)
	var turns_taken: int = stats.get("turns_taken", 0)
	var officers_status: Array = stats.get("officers_status", [])
	var objectives: Array = stats.get("objectives", [])

	
	# Cash rewards
	var total_cash: int = stats.get("total_cash", 0)
	var cash_reward: int = stats.get("cash_reward", 0)
	var cash_objective_bonus: int = stats.get("cash_objective_bonus", 0)
	var cash_full_clear_bonus: int = stats.get("cash_full_clear_bonus", 0)
	var cash_no_casualties_bonus: int = stats.get("cash_no_casualties_bonus", 0)

	
	# Set outcome
	# Set outcome
	if success:
		title_label.text = "[ EXTRACTION COMPLETE ]"
		outcome_label.text = "TEAM SUCCESSFULLY EXTRACTED"
		outcome_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		if SFXManager:
			SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/common_scene/extraction_complete.mp3")
	else:
		title_label.text = "[ MISSION FAILED ]"
		outcome_label.text = "EXTRACTION FAILED - TEAM LOST"
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		if SFXManager:
			SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/common_scene/extraction_failed.mp3")
	
	# Clear old officer status labels
	for child in officers_container.get_children():
		child.queue_free()
	
	# Clear old objective labels
	_objective_labels.clear()
	for child in objectives_container.get_children():
		child.queue_free()
	
	# Set stats (initially hidden for animation)
	fuel_label.text = "FUEL COLLECTED: +%d" % fuel_collected
	cash_label.text = "CASH EARNED: +%d CR" % total_cash
	
	var total_xp: int = stats.get("xp_awarded", 0)
	xp_label.text = "TOTAL XP AWARDED: +%d XP" % total_xp
	
	# Breakdown shown in cash_label if success
	if total_cash > 0:
		var breakdown = []
		if cash_reward > 0: breakdown.append("BASE: %d" % cash_reward)
		if cash_objective_bonus > 0: breakdown.append("OBJ: %d" % cash_objective_bonus)
		if cash_full_clear_bonus > 0: breakdown.append("CLEAR: %d" % cash_full_clear_bonus)
		if cash_no_casualties_bonus > 0: breakdown.append("SURVIVAL: %d" % cash_no_casualties_bonus)
		
		if breakdown.size() > 0:
			cash_label.text += " (" + "/".join(breakdown) + ")"
			
	enemies_label.text = "HOSTILES ELIMINATED: %d" % enemies_killed
	turns_label.text = "TURNS SURVIVED: %d" % turns_taken

	
	# Show/hide objectives section based on whether objectives exist
	var has_objectives = objectives.size() > 0
	objectives_header.visible = has_objectives
	objectives_border.visible = has_objectives
	objectives_container.visible = has_objectives
	
	
	# Get bonus rewards from stats
	var bonus_fuel = stats.get("bonus_fuel", 0)
	var bonus_cash = stats.get("bonus_cash", 0)
	var bonus_hull_repair = stats.get("bonus_hull_repair", 0)
	
	# Add objective rows
	if has_objectives:
		for obj_data in objectives:
			var obj_label = Label.new()
			obj_label.add_theme_font_size_override("font_size", 16)
			
			var description = obj_data.get("description", "Unknown objective")
			var completed = obj_data.get("completed", false)
			var progress = obj_data.get("progress", 0)
			var max_progress = obj_data.get("max_progress", 1)
			var obj_type = obj_data.get("type", "BINARY")
			var potential_rewards = obj_data.get("potential_rewards", {})
			
			# Build reward text for display
			var reward_text = ""
			if completed:
				# Show actual rewards received
				var reward_parts: Array[String] = []
				if bonus_fuel > 0:
					reward_parts.append("+%d FUEL" % bonus_fuel)
				if bonus_cash > 0:
					reward_parts.append("+%d CR" % bonus_cash)
				if bonus_hull_repair > 0:
					reward_parts.append("+%d%% HULL" % bonus_hull_repair)
				
				if reward_parts.size() > 0:
					reward_text = " [REWARD: " + " / ".join(reward_parts) + "]"
			else:
				# Show potential rewards
				var reward_parts: Array[String] = []
				if potential_rewards.get("fuel", 0) > 0:
					reward_parts.append("%d FUEL" % potential_rewards.get("fuel", 0))
				if potential_rewards.get("cash", 0) > 0:
					reward_parts.append("%d CR" % potential_rewards.get("cash", 0))
				if potential_rewards.get("hull_repair", 0) > 0:
					reward_parts.append("%d%% HULL" % potential_rewards.get("hull_repair", 0))
				
				if reward_parts.size() > 0:
					reward_text = " [REWARD: " + " / ".join(reward_parts) + "]"
			
			# Format objective text based on type and completion
			if obj_type == "PROGRESS":
				if completed:
					obj_label.text = "  ✓ %s (%d/%d) - COMPLETE%s" % [description, progress, max_progress, reward_text]
					obj_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))  # Green
				elif progress > 0:
					obj_label.text = "  %s (%d/%d)%s" % [description, progress, max_progress, reward_text]
					obj_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))  # Yellow
				else:
					obj_label.text = "  %s (0/%d) - INCOMPLETE%s" % [description, max_progress, reward_text]
					obj_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray
			else:  # BINARY
				if completed:
					obj_label.text = "  ✓ %s - COMPLETE%s" % [description, reward_text]
					obj_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))  # Green
				else:
					obj_label.text = "  %s - INCOMPLETE%s" % [description, reward_text]
					obj_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray
			
			objectives_container.add_child(obj_label)
			_objective_labels.append(obj_label)
	
	# Add officer status rows
	# Add officer status rows
	for officer_data in officers_status:
		var officer_row = _create_officer_xp_row(officer_data, success)
		officers_container.add_child(officer_row)
	
	# Animate in
	_animate_recap_in(stats)


func _create_officer_xp_row(data: Dictionary, mission_success: bool) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var name = data.get("name", "UNKNOWN").to_upper()
	var alive = data.get("alive", false)
	var hp = data.get("hp", 0)
	var max_hp = data.get("max_hp", 100)
	var status = data.get("status", "OK")
	var xp_earned = data.get("xp_earned", 0)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var name_label = Label.new()
	name_label.text = " " + name
	name_label.add_theme_font_size_override("font_size", 16)

	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)

	if not alive and status == "DOWNED":
		name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		status_label.text = " - DOWNED (4 JUMPS TO RECOVER)"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		header.add_child(name_label)
		header.add_child(status_label)
		return vbox
	elif alive:
		name_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		if status == "WOUNDED":
			status_label.text = " - WOUNDED (2 JUMPS TO RECOVER)"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			header.add_child(name_label)
			header.add_child(status_label)
	else:
		name_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	header.add_child(name_label)

	# HP display
	var hp_text = "HP: %d/%d" % [hp, max_hp]
	var hp_label = Label.new()
	hp_label.text = hp_text
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	header.add_child(hp_label)

	# XP Display (static bar on failure, animated on success)
	var od = GameState.get_officer(name.to_lower())
	if od:
		var xp_total = od.xp
		var xp_start = xp_total - xp_earned
		var level_start = _calculate_level_for_xp(xp_start)
		var threshold = _get_threshold_for_level(level_start)

		var xp_hbox = HBoxContainer.new()
		xp_hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(xp_hbox)

		var xp_title = Label.new()
		xp_title.text = "  XP:"
		xp_title.add_theme_font_size_override("font_size", 14)
		xp_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		xp_hbox.add_child(xp_title)

		var bar = ProgressBar.new()
		bar.name = "XPBar_" + name
		bar.min_value = 0
		bar.max_value = threshold
		bar.value = xp_start
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(280, 14)

		# Styles (reusing logic from barracks)
		var sb_bg = StyleBoxFlat.new()
		sb_bg.bg_color = Color(0, 0, 0, 0.4)
		sb_bg.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", sb_bg)

		var sb_fill = StyleBoxFlat.new()
		sb_fill.bg_color = Color(0.2, 0.6, 1.0, 0.7)
		sb_fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", sb_fill)

		xp_hbox.add_child(bar)

		var level_label = Label.new()
		level_label.name = "LevelLabel_" + name
		level_label.text = "LVL %d" % level_start
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		level_label.pivot_offset = Vector2(25, 10) # For scaling flash
		xp_hbox.add_child(level_label)

		# Gain label only shown on success (animated)
		if mission_success:
			var gain_label = Label.new()
			gain_label.name = "GainLabel_" + name
			gain_label.text = "+%d XP" % xp_earned
			gain_label.add_theme_font_size_override("font_size", 14)
			gain_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
			gain_label.modulate.a = 0.0 # Initially hidden
			xp_hbox.add_child(gain_label)

	return vbox


func _animate_recap_in(stats: Dictionary) -> void:
	visible = true

	# Dev mode: skip all animations and show immediately
	if GameState.dev_skip_mission_recap_animations:
		_show_recap_immediately()
		return

	# Start with everything hidden
	modulate.a = 0.0
	continue_button.modulate.a = 0.0
	continue_button.disabled = true
	
	# Fade rows (with icons)
	fuel_row.modulate.a = 0.0
	cash_row.modulate.a = 0.0
	xp_row.modulate.a = 0.0
	enemies_row.modulate.a = 0.0
	turns_row.modulate.a = 0.0

	
	# Fade objectives section if visible
	if objectives_header.visible:
		objectives_header.modulate.a = 0.0
		objectives_border.modulate.a = 0.0
		for label in _objective_labels:
			label.modulate.a = 0.0
	
	for child in officers_container.get_children():
		child.modulate.a = 0.0
	
	_stat_tween = create_tween()
	_stat_tween.set_ease(Tween.EASE_OUT)
	_stat_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in background and title
	_stat_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	_stat_tween.tween_interval(0.3)
	
	# Reveal stats one by one with typewriter feel (Fuel → Cash → XP → Enemies → Turns)
	_stat_tween.tween_property(fuel_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(cash_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(xp_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(enemies_row, "modulate:a", 1.0, 0.3)  # HOSTILES ELIMINATED after XP
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(turns_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.3)

	
	# Reveal objectives section if visible
	if objectives_header.visible:
		_stat_tween.tween_property(objectives_border, "modulate:a", 1.0, 0.3)
		_stat_tween.tween_interval(0.1)
		_stat_tween.tween_property(objectives_header, "modulate:a", 1.0, 0.3)
		_stat_tween.tween_interval(0.1)
		for label in _objective_labels:
			_stat_tween.tween_property(label, "modulate:a", 1.0, 0.25)
			_stat_tween.tween_interval(0.1)
		_stat_tween.tween_interval(0.2)
	
	# Reveal officer statuses and animate XP (only on success)
	for i in range(officers_container.get_child_count()):
		var child = officers_container.get_child(i)
		_stat_tween.tween_property(child, "modulate:a", 1.0, 0.25)

		# If child has an XP bar, animate it only on mission success
		if _mission_success:
			var xp_bar = child.find_child("XPBar_*", true, false)
			if xp_bar:
				var name_split = xp_bar.name.split("_")
				if name_split.size() > 1:
					var officer_name = name_split[1]
					# Find the original data for this officer to get gain
					var gain = 0
					for st in stats.get("officers_status", []):
						if st.get("name", "").to_upper() == officer_name:
							gain = st.get("xp_earned", 0)
							break

					if gain > 0:
						_stat_tween.tween_callback(_animate_officer_xp.bind(child, officer_name, gain))
						_stat_tween.tween_interval(0.6) # Allow some time for animation to start

		_stat_tween.tween_interval(0.1)
	
	_stat_tween.tween_interval(0.3)
	
	# Show continue button
	_stat_tween.tween_property(continue_button, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_callback(func(): continue_button.disabled = false)






func _calculate_level_for_xp(xp_val: int) -> int:
	var lvl = 1
	while xp_val >= _get_threshold_for_level(lvl):
		lvl += 1
	return lvl


func _get_threshold_for_level(lvl: int) -> int:
	return 50 * lvl * (lvl + 1)


func _animate_officer_xp(vbox: Control, officer_name: String, total_gain: int) -> void:
	var xp_bar: ProgressBar = vbox.find_child("XPBar_" + officer_name, true, false)
	var lvl_label: Label = vbox.find_child("LevelLabel_" + officer_name, true, false)
	var gain_label: Label = vbox.find_child("GainLabel_" + officer_name, true, false)

	if not xp_bar or not total_gain: return

	# Show the gain label with a fade-in
	var label_tween = create_tween()
	label_tween.tween_property(gain_label, "modulate:a", 1.0, 0.2)

	var start_xp = xp_bar.value
	var end_xp = start_xp + total_gain

	var main_tween = create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.set_trans(Tween.TRANS_QUAD)

	# We use a custom method to handle potential level-ups during animation
	main_tween.tween_method(
		func(val: float):
			_update_xp_bar_during_tween(xp_bar, lvl_label, val),
		start_xp,
		end_xp,
		1.2
	)

	# Subtle scale pulse on the bar during animation
	var pulse = create_tween().set_loops()
	pulse.tween_property(xp_bar, "custom_minimum_size:y", 16, 0.3)
	pulse.tween_property(xp_bar, "custom_minimum_size:y", 14, 0.3)

	main_tween.finished.connect(func(): pulse.kill())


func _update_xp_bar_during_tween(bar: ProgressBar, lvl_label: Label, current_total_xp: float) -> void:
	var current_lvl = _calculate_level_for_xp(int(current_total_xp))
	var threshold = _get_threshold_for_level(current_lvl)

	# Check if we just leveled up manually to trigger a flash (visual only)
	var displayed_lvl = int(lvl_label.text.split(" ")[1])
	if current_lvl > displayed_lvl:
		lvl_label.text = "LVL %d" % current_lvl
		_flash_label(lvl_label, Color(1, 1, 1), Color(0.9, 0.85, 0.4))
		# Flash bar too
		var bf = bar.get_theme_stylebox("fill").duplicate()
		bf.bg_color = Color(1, 1, 1, 0.9)
		bar.add_theme_stylebox_override("fill", bf)
		create_tween().tween_property(bf, "bg_color", Color(0.2, 0.6, 1.0, 0.7), 0.3)
		if SFXManager:
			SFXManager.play_sfx_by_name("ui", "objective_complete") # Reusing a positive fan-fare

	bar.max_value = threshold
	bar.value = current_total_xp


func _flash_label(target: Label, flash_color: Color, original_color: Color) -> void:
	var t = create_tween()
	t.tween_property(target, "theme_override_colors/font_color", flash_color, 0.1)
	t.tween_property(target, "theme_override_colors/font_color", original_color, 0.2)
	t.parallel().tween_property(target, "scale", Vector2(1.2, 1.2), 0.1)
	t.tween_property(target, "scale", Vector2(1.0, 1.0), 0.1)


func _show_recap_immediately() -> void:
	modulate.a = 1.0
	fuel_row.modulate.a = 1.0
	cash_row.modulate.a = 1.0
	xp_row.modulate.a = 1.0
	enemies_row.modulate.a = 1.0
	turns_row.modulate.a = 1.0
	if objectives_header.visible:
		objectives_header.modulate.a = 1.0
		objectives_border.modulate.a = 1.0
		for label in _objective_labels:
			label.modulate.a = 1.0
	for child in officers_container.get_children():
		child.modulate.a = 1.0
		var xp_bar = child.find_child("XPBar_*", true, false)
		if xp_bar:
			var name_split = xp_bar.name.split("_")
			if name_split.size() > 1:
				var officer_name = name_split[1]
				var od = GameState.get_officer(officer_name.to_lower())
				if od:
					xp_bar.max_value = od.get_next_xp_threshold()
					xp_bar.value = od.xp
				var lvl_label = child.find_child("LevelLabel_*", true, false)
				if lvl_label and od:
					lvl_label.text = "LVL %d" % od.level
				var gain_label = child.find_child("GainLabel_*", true, false)
				if gain_label:
					gain_label.modulate.a = 1.0
	continue_button.modulate.a = 1.0
	continue_button.disabled = false


func _on_continue_pressed() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_dismiss)


func _dismiss() -> void:
	if SFXManager:
		SFXManager.stop_scene_sfx()
	visible = false
	recap_dismissed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if continue_button.disabled:
			if _stat_tween and _stat_tween.is_running():
				_stat_tween.kill()
			_show_recap_immediately()
		else:
			_on_continue_pressed()
