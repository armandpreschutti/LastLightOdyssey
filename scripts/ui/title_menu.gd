extends Control
## Title Menu - Main menu for Last Light Odyssey
## Features retro sci-fi animated starfield, scanline overlay, typewriter subtitle, and game entry points

signal start_game_pressed
signal settings_pressed

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/TitleContainer/SubtitleLabel
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/ButtonPanelWrapper/ButtonPanel/MarginContainer/ButtonContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ButtonPanelWrapper/ButtonPanel/MarginContainer/ButtonContainer/ContinueButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/ButtonPanelWrapper/ButtonPanel/MarginContainer/ButtonContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonPanelWrapper/ButtonPanel/MarginContainer/ButtonContainer/QuitButton
@onready var starfield: Control = $Starfield
@onready var scanline_overlay: Control = $ScanlineOverlay
@onready var version_label: Label = $VersionLabel
@onready var no_save_message: Label = $NoSaveMessage
@onready var fade_transition: Control = $FadeTransitionLayer/FadeTransition

#region Starfield particles
var stars: Array[Dictionary] = []
const STAR_COUNT: int = 250
const STAR_SPEED_MIN: float = 15.0
const STAR_SPEED_MAX: float = 120.0
#endregion

#region Title animation
var _title_tween: Tween = null
var _glow_tween: Tween = null
var _typewriter_tween: Tween = null
var _ready_for_input: bool = false
#endregion

#region Subtitle typewriter
const SUBTITLE_TEXT: String = "The final journey of humanity begins"
var _current_subtitle_char: int = 0
#endregion

#region Nebula effect
var _nebula_time: float = 0.0
var _nebula_particles: Array[Dictionary] = []
const NEBULA_COUNT: int = 8
#endregion


func _ready() -> void:
	# Apply saved display settings on startup
	_apply_startup_settings()
	
	_generate_stars()
	_generate_nebula()
	_setup_buttons()
	
	# Start with black screen, then fade in
	fade_transition.set_black()
	
	# Hide starfield initially
	starfield.modulate.a = 0.0
	scanline_overlay.modulate.a = 0.0
	
	# 1. Screen fade-in (2s)
	# --- Z-INDEX ORDERING STRATEGY ---
	# Move the global fade transition to be a local child so we can use Z-Index
	# This avoids hiding/showing elements manually and relies on draw order
	var fade_parent = fade_transition.get_parent()
	if fade_parent:
		fade_parent.remove_child(fade_transition)
	add_child(fade_transition)
	
	# Set Z-Index so:
	# 0 = Background, Starfield, Buttons (Default)
	# 10 = Black Overlay (Covers the scene)
	# 20 = Title & Subtitle (Floats on top of black overlay)
	fade_transition.z_index = 10
	title_label.z_index = 20
	subtitle_label.z_index = 20
	
	# Ensure overlay covers the screen
	fade_transition.visible = true
	fade_transition.modulate.a = 1.0
	fade_transition.set_black()
	
	# Ensure title starts invisible (but on top layer)
	title_label.modulate.a = 0.0
	
	# Wait a bit to ensure the engine has rendered the black frame
	await get_tree().process_frame
	
	# Start sequence immediately (User requested title fade at same time as black fade)
	_animate_intro()
	
	# Start title music
	MusicManager.play_title_music()
	
	# Connect starfield and scanline drawing
	starfield.draw.connect(_draw_starfield)
	scanline_overlay.draw.connect(_draw_scanlines)


func _apply_startup_settings() -> void:
	## Load and apply display settings from config file on game launch
	const CONFIG_PATH: String = "user://settings.cfg"
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	# Default to fullscreen if no config exists (better for exported games)
	var is_fullscreen: bool = true
	var resolution_index: int = 2  # 1920x1080
	
	if err == OK:
		is_fullscreen = config.get_value("display", "fullscreen", true)
		resolution_index = config.get_value("display", "resolution", 2)
	else:
		# No config file exists yet - create one with fullscreen default
		config.set_value("display", "fullscreen", true)
		config.set_value("display", "resolution", 2)
		config.save(CONFIG_PATH)
	
	# Apply display settings
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Apply resolution when windowed
		const RESOLUTIONS: Array[Vector2i] = [
			Vector2i(1280, 720),
			Vector2i(1600, 900),
			Vector2i(1920, 1080)
		]
		if resolution_index >= 0 and resolution_index < RESOLUTIONS.size():
			var res = RESOLUTIONS[resolution_index]
			DisplayServer.window_set_size(res)
			# Center window
			var screen_size = DisplayServer.screen_get_size()
			var window_pos = (screen_size - res) / 2
			DisplayServer.window_set_position(window_pos)


func _process(delta: float) -> void:
	_nebula_time += delta * 0.3
	
	# Update starfield
	for star in stars:
		star.position.x -= star.speed * delta
		# Twinkle effect
		star.twinkle_phase += star.twinkle_speed * delta
		if star.position.x < -10:
			star.position.x = get_viewport_rect().size.x + 10
			star.position.y = randf_range(0, get_viewport_rect().size.y)
	
	starfield.queue_redraw()


func _generate_stars() -> void:
	var viewport_size = get_viewport_rect().size
	stars.clear()
	
	for i in range(STAR_COUNT):
		var star = {
			"position": Vector2(
				randf_range(0, viewport_size.x),
				randf_range(0, viewport_size.y)
			),
			"speed": randf_range(STAR_SPEED_MIN, STAR_SPEED_MAX),
			"size": randf_range(0.8, 3.5),
			"brightness": randf_range(0.2, 1.0),
			"color_type": randi_range(0, 3),  # 0=white, 1=cyan, 2=blue, 3=orange
			"twinkle_phase": randf_range(0, TAU),
			"twinkle_speed": randf_range(1.0, 4.0),
		}
		stars.append(star)


func _generate_nebula() -> void:
	var viewport_size = get_viewport_rect().size
	_nebula_particles.clear()
	
	for i in range(NEBULA_COUNT):
		var nebula = {
			"position": Vector2(
				randf_range(0, viewport_size.x),
				randf_range(0, viewport_size.y)
			),
			"radius": randf_range(100, 300),
			"color_type": randi_range(0, 2),  # 0=cyan, 1=purple, 2=orange
			"alpha": randf_range(0.02, 0.06),
			"phase_offset": randf_range(0, TAU),
		}
		_nebula_particles.append(nebula)


func _setup_buttons() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Button hover effects
	new_game_button.mouse_entered.connect(_on_button_hover.bind(new_game_button))
	continue_button.mouse_entered.connect(_on_button_hover.bind(continue_button))
	settings_button.mouse_entered.connect(_on_button_hover.bind(settings_button))
	quit_button.mouse_entered.connect(_on_button_hover.bind(quit_button))
	
	# Check if save exists
	_check_save_exists()


func _check_save_exists() -> bool:
	var save_exists = GameState.has_save_file()
	continue_button.disabled = not save_exists
	if save_exists:
		continue_button.modulate = Color(1, 1, 1, 1)
	else:
		continue_button.modulate = Color(0.5, 0.5, 0.5, 0.7)
	return save_exists


func _animate_intro() -> void:
	# Disable buttons during intro
	new_game_button.disabled = true
	continue_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	
	_title_tween = create_tween()
	_title_tween.set_ease(Tween.EASE_OUT)
	_title_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Sequence:
	# 1. Fade in Title (2s) - Happens immediately when called (after _ready 1s wait)
	title_label.pivot_offset = title_label.size / 2
	title_label.scale = Vector2(0.95, 0.95)
	# Parallel scale and fade
	_title_tween.parallel().tween_property(title_label, "modulate:a", 1.0, 2.0)
	_title_tween.parallel().tween_property(title_label, "scale", Vector2(1.0, 1.0), 2.0)
	
	# Start glowing immediately after fade-in (User requested 3s earlier)
	_title_tween.tween_callback(_start_title_glow)
	
	# 2. Start Subtitle immediately after Title finishes (User requested 1s earlier)
	# _title_tween.tween_interval(1.0) # Removed delay
	
	# 3. Subtitle (on top of black)
	_title_tween.tween_callback(func(): _start_typewriter())
	
	# 4. Add 1.5 sec delay before Black Fade Out
	_title_tween.tween_interval(1.5)
	
	# 5. Fade OUT Black Overlay to reveal Background/Buttons
	_title_tween.tween_property(fade_transition, "modulate:a", 0.0, 2.0)
	
	# 6. Fade in buttons/UI (they are under the overlay so they will appear as overlay fades)
	# But we need them to be technically visible (alpha 1) before the overlay fades?
	# Or we can fade them in concurrently with the overlay fade out for extra smoothness.
	
	# Fade in starfield and scanlines to be ready when overlay fades
	var bg_tween = create_tween()
	# Wait for Title(2s) + Delay(1s) + Delay(1.5s) = 4.5s
	# Actually, let's sync it with the overlay fade out
	bg_tween.tween_interval(4.5) 
	bg_tween.parallel().tween_property(starfield, "modulate:a", 1.0, 0.5)
	bg_tween.parallel().tween_property(scanline_overlay, "modulate:a", 1.0, 0.5)
	
	# Fade in buttons with stagger (after overlay starts fading)
	var btn_start_time = 4.5
	var btn_tween = create_tween()
	btn_tween.tween_interval(btn_start_time)
	
	btn_tween.tween_property(new_game_button, "modulate:a", 1.0, 0.4)
	btn_tween.tween_interval(0.3)
	btn_tween.tween_property(continue_button, "modulate:a", 0.7 if continue_button.disabled else 1.0, 0.4)
	btn_tween.tween_interval(0.3)
	btn_tween.tween_property(settings_button, "modulate:a", 1.0, 0.4)
	btn_tween.tween_interval(0.3)
	btn_tween.tween_property(quit_button, "modulate:a", 1.0, 0.4)
	
	# Fade in version
	btn_tween.tween_property(version_label, "modulate:a", 0.5, 0.3)
	
	# Enable buttons and start glow effect after animation
	btn_tween.tween_callback(_enable_buttons)
	# btn_tween.tween_callback(_start_title_glow) # Moved to start earlier


func _start_typewriter() -> void:
	_current_subtitle_char = 0
	_typewriter_tween = create_tween()
	_typewriter_tween.set_loops(SUBTITLE_TEXT.length())
	_typewriter_tween.tween_callback(_add_subtitle_char)
	_typewriter_tween.tween_interval(0.04)


func _add_subtitle_char() -> void:
	if _current_subtitle_char < SUBTITLE_TEXT.length():
		subtitle_label.text = SUBTITLE_TEXT.substr(0, _current_subtitle_char + 1)
		_current_subtitle_char += 1


func _start_title_glow() -> void:
	# Create pulsing glow effect on title - retro sci-fi cyan glow
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.set_trans(Tween.TRANS_SINE)
	
	# Pulse the shadow color alpha for a subtle cyan glow effect
	var base_color = Color(0.2, 0.6, 1.0, 0.3)
	var glow_color = Color(0.3, 0.8, 1.0, 0.7)
	
	_glow_tween.tween_property(title_label, "theme_override_colors/font_shadow_color", glow_color, 2.0)
	_glow_tween.tween_property(title_label, "theme_override_colors/font_shadow_color", base_color, 2.0)


func _enable_buttons() -> void:
	new_game_button.disabled = false
	settings_button.disabled = false
	quit_button.disabled = false
	_check_save_exists()  # Re-check to set continue button state
	_ready_for_input = true


func _disable_buttons() -> void:
	new_game_button.disabled = true
	continue_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	_ready_for_input = false


func _on_button_hover(button: Button) -> void:
	if not _ready_for_input:
		return
	
	if button.disabled:
		return
	
	# Subtle scale pulse on hover
	button.pivot_offset = button.size / 2
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


func _on_new_game_pressed() -> void:
	if not _ready_for_input:
		return
		
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	
	# Check if save exists - show confirmation dialog if so
	if GameState.has_save_file():
		# Temporarily disable input while dialog is shown
		_disable_buttons()
		_show_new_game_confirmation()
		return
	
	_disable_buttons()
	_proceed_with_new_game()


func _show_new_game_confirmation() -> void:
	var dialog_scene = load("res://scenes/ui/confirm_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	# Ensure dialog is above title (Z=20)
	dialog.z_index = 30
	add_child(dialog)
	
	dialog.setup(
		"[ ABANDON VOYAGE? ]",
		"Starting a new voyage will erase\nyour existing save data.\n\nThis cannot be undone!",
		"ERASE & START",
		"CANCEL"
	)
	
	dialog.confirmed.connect(_on_new_game_confirmed)
	dialog.cancelled.connect(_on_new_game_cancelled)
	dialog.show_dialog()


func _on_new_game_confirmed() -> void:
	# Delete existing save and start new game
	GameState.delete_save()
	_proceed_with_new_game()


func _on_new_game_cancelled() -> void:
	# Dialog closes itself, re-enable buttons
	_enable_buttons()


func _proceed_with_new_game() -> void:
	# Stop glow effect
	if _glow_tween:
		_glow_tween.kill()
	
	# Fade to black and transition to game
	fade_transition.fade_out(0.6)
	await fade_transition.fade_complete
	MusicManager.stop_music()
	_start_new_game()


func _start_new_game() -> void:
	if not is_inside_tree():
		return
	# Reset game state and load main scene
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_continue_pressed() -> void:
	if not _ready_for_input:
		return
		
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	
	if continue_button.disabled:
		# Show "no save found" message
		_show_no_save_message()
		return
	
	_disable_buttons()
	
	# Load saved game
	if GameState.load_game():
		_proceed_with_continue()
	else:
		_enable_buttons()
		_show_no_save_message()


func _proceed_with_continue() -> void:
	# Stop glow effect
	if _glow_tween:
		_glow_tween.kill()
	
	# Fade to black and transition to game (loaded state)
	fade_transition.fade_out(0.6)
	await fade_transition.fade_complete
	MusicManager.stop_music()
	_continue_game()


func _continue_game() -> void:
	if not is_inside_tree():
		return
	# Load main scene - it will use the loaded GameState
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_no_save_message() -> void:
	no_save_message.visible = true
	no_save_message.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(no_save_message, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(no_save_message, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): no_save_message.visible = false)


func _on_settings_pressed() -> void:
	if not _ready_for_input:
		return
		
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	
	_disable_buttons()
	
	# Load and show settings menu
	var settings_scene = load("res://scenes/ui/settings_menu.tscn")
	var settings_instance = settings_scene.instantiate()
	# Ensure settings menu is above title (Z=20)
	settings_instance.z_index = 30
	settings_instance.back_pressed.connect(_on_settings_back)
	add_child(settings_instance)


func _on_settings_back() -> void:
	# Settings menu removes itself when back is pressed
	_enable_buttons()


func _on_quit_pressed() -> void:
	if not _ready_for_input:
		return
		
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	
	_disable_buttons()
	
	# Stop glow effect
	if _glow_tween:
		_glow_tween.kill()
	
	# Fade to black then quit
	fade_transition.fade_out(0.6)
	await fade_transition.fade_complete
	MusicManager.stop_music()
	get_tree().quit()


## Draw the animated starfield with retro sci-fi colored stars and nebula clouds
func _draw_starfield() -> void:
	# Draw nebula clouds first (behind stars)
	for nebula in _nebula_particles:
		var breathing = sin(_nebula_time + nebula.phase_offset) * 0.5 + 0.5
		var base_color: Color
		match nebula.color_type:
			0: base_color = Color(0.1, 0.3, 0.5)  # Cyan nebula
			1: base_color = Color(0.3, 0.1, 0.4)   # Purple nebula
			_: base_color = Color(0.4, 0.2, 0.05)   # Orange nebula
		base_color.a = nebula.alpha * (0.6 + 0.4 * breathing)
		starfield.draw_circle(nebula.position, nebula.radius, base_color)
	
	# Draw stars with color variety and twinkle
	for star in stars:
		var twinkle = (sin(star.twinkle_phase) * 0.3 + 0.7)
		var alpha = star.brightness * twinkle
		var color: Color
		match star.color_type:
			0: color = Color(0.9, 0.95, 1.0, alpha)       # White
			1: color = Color(0.4, 0.9, 1.0, alpha)         # Cyan
			2: color = Color(0.5, 0.6, 1.0, alpha)         # Blue
			_: color = Color(1.0, 0.7, 0.3, alpha)         # Orange
		starfield.draw_circle(star.position, star.size, color)
		
		# Draw a small glow around brighter stars
		if star.brightness > 0.7 and star.size > 2.0:
			var glow_color = color
			glow_color.a = alpha * 0.15
			starfield.draw_circle(star.position, star.size * 3.0, glow_color)


## Draw CRT-style scanline overlay for retro feel
func _draw_scanlines() -> void:
	var viewport_size = get_viewport_rect().size
	var scanline_color = Color(0.0, 0.0, 0.0, 0.08)
	var line_spacing: float = 3.0
	
	var y: float = 0.0
	while y < viewport_size.y:
		scanline_overlay.draw_rect(
			Rect2(0, y, viewport_size.x, 1.0),
			scanline_color
		)
		y += line_spacing
