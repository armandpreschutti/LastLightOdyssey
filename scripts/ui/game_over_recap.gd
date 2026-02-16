extends Control
## Game Over Recap Screen - Shows comprehensive summary when the game ends
## Displayed after game over scene, showing final state and cumulative stats

signal main_menu_pressed
signal restart_pressed
signal view_map_requested(show_map: bool)

@onready var background: ColorRect = $Background
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var reason_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ReasonLabel
@onready var reason_desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ReasonDescLabel

# Final state labels
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/FuelLabel
@onready var integrity_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/IntegrityLabel
@onready var scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/ScrapLabel
@onready var officers_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficersContainer

# Cumulative stats labels
@onready var total_fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalFuelLabel
@onready var total_scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalScrapLabel
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
var _reason: String = ""


func _ready() -> void:
	visible = false
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	
	_setup_view_map_buttons()


func show_recap(reason: String) -> void:
	_reason = reason
	
	if SFXManager:
		SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/common_scene/voyage_failure.mp3")
	
	# Set title
	title_label.text = "[ MISSION FAILED ]"
	
	# Get game over text from GameState
	var game_over_text = GameState.get_game_over_text(reason)
	var lines = game_over_text.split("\n")
	
	if lines.size() >= 2:
		reason_label.text = lines[0]  # Title line
		reason_desc_label.text = lines[1]  # Description line
	else:
		reason_label.text = game_over_text
		reason_desc_label.text = ""
	
	# Set color based on reason
	match reason:
		"hull_depleted":
			reason_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.3))
		"fuel_depleted":
			reason_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
		"ship_destroyed":
			reason_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		"captain_died":
			reason_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_:
			reason_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	
	# Set final state stats
	fuel_label.text = "FUEL RESERVES: %d" % GameState.fuel
	integrity_label.text = "SHIP INTEGRITY: %d%%" % GameState.ship_integrity
	scrap_label.text = "SCRAP STOCKPILE: %d" % GameState.scrap
	
	# Clear old officer status labels
	for child in officers_container.get_children():
		child.queue_free()
	
	# Add officer status rows
	for officer_key in GameState.officers.keys():
		var officer_label = Label.new()
		officer_label.add_theme_font_size_override("font_size", 16)
		
		var officer_name = officer_key.to_upper()
		var is_alive = GameState.officers[officer_key]["alive"]
		
		if is_alive:
			# Show different messages based on failure reason
			match _reason:
				"ship_destroyed", "hull_depleted":
					# CATASTROPHIC FAILURE: They went down with the ship
					officer_label.text = "  %s - WENT DOWN WITH THE SHIP" % officer_name
				"fuel_depleted":
					# DRIFT: Lost in the void
					officer_label.text = "  %s - LOST TO THE VOID" % officer_name
				_:
					# Other failure reasons: Just show survived
					officer_label.text = "  %s - SURVIVED" % officer_name
			officer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			officer_label.text = "  %s - K.I.A." % officer_name
			officer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		
		officers_container.add_child(officer_label)
	
	# Set cumulative mission stats
	total_fuel_label.text = "TOTAL FUEL COLLECTED: %d" % GameState.total_fuel_collected
	total_scrap_label.text = "TOTAL SCRAP COLLECTED: %d" % GameState.total_scrap_collected
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
	reason_label.modulate.a = 0.0
	reason_desc_label.modulate.a = 0.0
	fuel_label.modulate.a = 0.0
	integrity_label.modulate.a = 0.0
	scrap_label.modulate.a = 0.0
	total_fuel_label.modulate.a = 0.0
	total_scrap_label.modulate.a = 0.0
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
	
	# Reveal reason
	_stat_tween.tween_property(reason_label, "modulate:a", 1.0, 0.4)
	_stat_tween.tween_interval(0.2)
	_stat_tween.tween_property(reason_desc_label, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.4)
	
	# Reveal final state stats
	_stat_tween.tween_property(fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(integrity_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(scrap_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.2)
	
	# Reveal officer statuses
	for child in officers_container.get_children():
		_stat_tween.tween_property(child, "modulate:a", 1.0, 0.2)
		_stat_tween.tween_interval(0.08)
	
	_stat_tween.tween_interval(0.3)
	
	# Reveal cumulative stats
	_stat_tween.tween_property(total_fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_scrap_label, "modulate:a", 1.0, 0.25)
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
		
	if SFXManager:
		SFXManager.stop_scene_sfx()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		visible = false
		main_menu_pressed.emit()
	)


func _on_restart_pressed() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
		
	if SFXManager:
		SFXManager.stop_scene_sfx()
	
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
	reason_label.modulate.a = 1.0
	reason_desc_label.modulate.a = 1.0
	fuel_label.modulate.a = 1.0
	integrity_label.modulate.a = 1.0
	scrap_label.modulate.a = 1.0
	total_fuel_label.modulate.a = 1.0
	total_scrap_label.modulate.a = 1.0
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
	
	# Create Return button (floating) - though Main.gd handles returning via HUD button now
	# We'll keep this as a backup or for consistency, but disable its visibility if HUD is preferred
	# Actually, the requirement was to Replace Quit with View Recap in HUD.
	# But having a button on screen is also good.
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
	
	# Let input pass through to map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# We DON'T show the return button here because we are using the HUD button instead
	# return_button.visible = true 
	
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
