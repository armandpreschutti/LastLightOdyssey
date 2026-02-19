extends Control
## Voyage Recap Screen - Shows comprehensive summary of the entire voyage
## Displayed after reaching New Earth, showing final state and cumulative stats

signal main_menu_pressed
signal restart_pressed
signal view_map_requested(show_map: bool)

@onready var background: ColorRect = $Background
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var ending_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EndingLabel
@onready var ending_desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EndingDescLabel

# Final state labels
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/FuelLabel
@onready var integrity_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/IntegrityLabel
@onready var officers_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficersContainer

# Cumulative stats labels
@onready var total_fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalFuelLabel
@onready var total_enemies_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalEnemiesLabel
@onready var total_missions_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalMissionsLabel
@onready var total_turns_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalTurnsLabel
@onready var nodes_visited_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/NodesVisitedLabel

@onready var main_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MainMenuButton
@onready var restart_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/RestartButton
@onready var button_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer

var view_map_button: Button = null
var return_button: Button = null

var _stat_tween: Tween = null
var _ending_type: String = ""


func _ready() -> void:
	visible = false
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	
	_setup_view_map_buttons()


func show_recap(ending_type: String) -> void:
	_ending_type = ending_type
	
	# Set title and ending
	title_label.text = "[ VOYAGE COMPLETE ]"
	
	match ending_type:
		"5A":
			ending_label.text = "ENDING 5A — THE GOLDEN AGE"
			ending_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			ending_desc_label.text = "The Arkship arrived with all critical systems intact. The data archives are preserved. A golden era dawns."
		"5B":
			ending_label.text = "ENDING 5B — THE HARD FOUNDATION"
			ending_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
			ending_desc_label.text = "The ship sustained damage, but the core mission data survived. Rebuilding can begin on solid ground."
		"5C":
			ending_label.text = "ENDING 5C — THE NARROW ESCAPE"
			ending_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
			ending_desc_label.text = "Against all odds, the crew found a viable corridor. The colony will endure, though scars remain."
		"5D":
			ending_label.text = "ENDING 5D — THE ENDANGERED SPECIES"
			ending_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			ending_desc_label.text = "Critical failures plagued the journey. Survival is uncertain, but the signal still transmits."
		"5E":
			ending_label.text = "ENDING 5E — THE LAST BROADCAST"
			ending_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
			ending_desc_label.text = "The final beacon fires into the void. Whether anyone hears it is no longer your burden to bear."
		_:
			ending_label.text = "JOURNEY'S END"
			ending_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
			ending_desc_label.text = "The voyage is complete."
	
	# Set final state stats
	fuel_label.text = "FUEL RESERVES: %d" % GameState.fuel
	integrity_label.text = "SHIP INTEGRITY: %d%%" % GameState.ship_integrity
	
	# Clear old officer status labels
	for child in officers_container.get_children():
		child.queue_free()
	
	# Add officer status rows
	for officer_key in GameState.officers.keys():
		var officer_label = Label.new()
		officer_label.add_theme_font_size_override("font_size", 16)

		var officer_name = officer_key.to_upper()
		var od = GameState.get_officer(officer_key)

		if od and od.is_downed():
			officer_label.text = "  %s - DOWNED (%d JUMPS)" % [officer_name, od.injury_jumps]
			officer_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		elif od and od.is_injured():
			officer_label.text = "  %s - WOUNDED (%d JUMPS)" % [officer_name, od.injury_jumps]
			officer_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		elif od and od.alive:
			officer_label.text = "  %s - SURVIVED" % officer_name
			officer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			officer_label.text = "  %s - OFFLINE" % officer_name
			officer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		officers_container.add_child(officer_label)
	
	# Set cumulative mission stats
	total_fuel_label.text = "TOTAL FUEL COLLECTED: %d" % GameState.total_fuel_collected
	total_enemies_label.text = "TOTAL HOSTILES ELIMINATED: %d" % GameState.total_enemies_killed
	total_missions_label.text = "MISSIONS COMPLETED: %d" % GameState.total_missions_completed
	total_turns_label.text = "TACTICAL TURNS SURVIVED: %d" % GameState.total_tactical_turns
	nodes_visited_label.text = "SECTORS TRAVERSED: %d" % (VoyageManager.nodes.size())
	
	# Animate in
	_animate_recap_in()


func _animate_recap_in() -> void:
	# Start with everything hidden
	modulate.a = 0.0
	visible = true
	main_menu_button.modulate.a = 0.0
	main_menu_button.disabled = true
	restart_button.modulate.a = 0.0
	restart_button.disabled = true
	
	# Hide all stat labels initially
	ending_label.modulate.a = 0.0
	ending_desc_label.modulate.a = 0.0
	fuel_label.modulate.a = 0.0
	integrity_label.modulate.a = 0.0
	total_fuel_label.modulate.a = 0.0
	total_enemies_label.modulate.a = 0.0
	total_missions_label.modulate.a = 0.0
	total_turns_label.modulate.a = 0.0
	nodes_visited_label.modulate.a = 0.0
	
	for child in officers_container.get_children():
		child.modulate.a = 0.0
	
	_stat_tween = create_tween()
	_stat_tween.set_ease(Tween.EASE_OUT)
	_stat_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in background and title
	_stat_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	_stat_tween.tween_interval(0.3)
	
	# Reveal ending type
	_stat_tween.tween_property(ending_label, "modulate:a", 1.0, 0.4)
	_stat_tween.tween_interval(0.2)
	_stat_tween.tween_property(ending_desc_label, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.4)
	
	# Reveal final state stats
	_stat_tween.tween_property(fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(integrity_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.2)
	
	# Reveal officer statuses
	for child in officers_container.get_children():
		_stat_tween.tween_property(child, "modulate:a", 1.0, 0.2)
		_stat_tween.tween_interval(0.08)
	
	_stat_tween.tween_interval(0.3)
	
	# Reveal cumulative stats
	_stat_tween.tween_property(total_fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_enemies_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_missions_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_turns_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(nodes_visited_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.3)
	
	# Show buttons
	_stat_tween.tween_property(main_menu_button, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_property(view_map_button, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_property(restart_button, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_callback(func(): 
		main_menu_button.disabled = false
		view_map_button.disabled = false
		restart_button.disabled = false
	)


func _on_main_menu_pressed() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		visible = false
		main_menu_pressed.emit()
	)


func _on_restart_pressed() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		visible = false
		restart_pressed.emit()
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if main_menu_button.disabled:
			# Skip animation
			_skip_animation()


func _skip_animation() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	modulate.a = 1.0
	ending_label.modulate.a = 1.0
	ending_desc_label.modulate.a = 1.0
	fuel_label.modulate.a = 1.0
	integrity_label.modulate.a = 1.0
	total_fuel_label.modulate.a = 1.0
	total_enemies_label.modulate.a = 1.0
	total_missions_label.modulate.a = 1.0
	total_turns_label.modulate.a = 1.0
	nodes_visited_label.modulate.a = 1.0
	
	for child in officers_container.get_children():
		child.modulate.a = 1.0
	
	main_menu_button.modulate.a = 1.0
	main_menu_button.disabled = false
	view_map_button.modulate.a = 1.0
	view_map_button.disabled = false
	restart_button.modulate.a = 1.0
	restart_button.disabled = false

func _setup_view_map_buttons() -> void:
	# create view map button
	view_map_button = Button.new()
	view_map_button.text = "[ VIEW MAP ]"
	view_map_button.custom_minimum_size = Vector2(200, 45)
	view_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_map_button.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	view_map_button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 1.0))
	view_map_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.6, 0.8))
	
	# Try to load the font from the other buttons to match
	if main_menu_button.get_theme_font("font"):
		view_map_button.add_theme_font_override("font", main_menu_button.get_theme_font("font"))
		view_map_button.add_theme_font_size_override("font_size", 20)
		
	button_container.add_child(view_map_button)
	# Move to be between Main Menu and Restart
	button_container.move_child(view_map_button, 1)
	
	view_map_button.pressed.connect(_on_view_map_pressed)
	
	# Create Return button (floating)
	return_button = Button.new()
	return_button.text = "[ RETURN TO RECAP ]"
	return_button.visible = false
	return_button.custom_minimum_size = Vector2(200, 45)
	return_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold color
	
	if main_menu_button.get_theme_font("font"):
		return_button.add_theme_font_override("font", main_menu_button.get_theme_font("font"))
		return_button.add_theme_font_size_override("font_size", 20)
	
	add_child(return_button)
	# Position top right
	return_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	return_button.position = Vector2(-220, 20) # Offset from top right
	return_button.pressed.connect(_on_return_pressed)


func _on_view_map_pressed() -> void:
	# Hide recap content
	$Background.visible = false
	$PanelContainer.visible = false
	
	# Show return button -> DISABLED in favor of HUD button
	# return_button.visible = true
	
	# Let input pass through to map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	view_map_requested.emit(true)


func _on_return_pressed() -> void:
	# Show recap content
	$Background.visible = true
	$PanelContainer.visible = true
	
	# Hide return button
	return_button.visible = false
	
	# Block input again
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	view_map_requested.emit(false)
