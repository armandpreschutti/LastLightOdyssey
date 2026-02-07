extends Control
## Settings Menu - Manages display, audio, and tutorial settings
## Persists settings to user://settings.cfg

signal back_pressed

const CONFIG_PATH: String = "user://settings.cfg"

# Resolution options (width, height)
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

@onready var fullscreen_toggle: CheckButton = $PanelContainer/MarginContainer/VBoxContainer/DisplaySection/FullscreenContainer/FullscreenToggle
@onready var resolution_selector: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/DisplaySection/ResolutionContainer/ResolutionSelector
@onready var master_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/MasterContainer/MasterSlider
@onready var master_value: Label = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/MasterContainer/MasterValue
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/SFXContainer/SFXSlider
@onready var sfx_value: Label = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/SFXContainer/SFXValue
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/MusicContainer/MusicSlider
@onready var music_value: Label = $PanelContainer/MarginContainer/VBoxContainer/AudioSection/MusicContainer/MusicValue
@onready var reset_tutorial_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TutorialSection/ResetTutorialButton
@onready var apply_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/BackButton

# Pending settings (applied on "Apply")
var _pending_fullscreen: bool = false
var _pending_resolution: int = 1
var _pending_master: float = 80.0
var _pending_sfx: float = 100.0
var _pending_music: float = 70.0


func _ready() -> void:
	_connect_signals()
	_load_settings()
	_update_ui_from_pending()
	
	# Fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _connect_signals() -> void:
	print("SettingsMenu: Connecting signals...")
	
	# Verify all nodes exist
	if not fullscreen_toggle:
		push_error("SettingsMenu: fullscreen_toggle is null!")
	else:
		fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
		
	if not resolution_selector:
		push_error("SettingsMenu: resolution_selector is null!")
	else:
		resolution_selector.item_selected.connect(_on_resolution_selected)
		
	if not master_slider:
		push_error("SettingsMenu: master_slider is null!")
	else:
		master_slider.value_changed.connect(_on_master_changed)
		
	if not sfx_slider:
		push_error("SettingsMenu: sfx_slider is null!")
	else:
		sfx_slider.value_changed.connect(_on_sfx_changed)
		
	if not music_slider:
		push_error("SettingsMenu: music_slider is null!")
	else:
		music_slider.value_changed.connect(_on_music_changed)
		
	if not reset_tutorial_button:
		push_error("SettingsMenu: reset_tutorial_button is null!")
	else:
		reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
		
	if not apply_button:
		push_error("SettingsMenu: apply_button is null!")
	else:
		apply_button.pressed.connect(_on_apply_pressed)
		print("SettingsMenu: Apply button connected successfully")
		
	if not back_button:
		push_error("SettingsMenu: back_button is null!")
	else:
		back_button.pressed.connect(_on_back_pressed)
		print("SettingsMenu: Back button connected successfully")


func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		# Use defaults if no config exists
		_pending_fullscreen = false
		_pending_resolution = 1  # 1600x900
		_pending_master = 80.0
		_pending_sfx = 100.0
		_pending_music = 70.0
		return
	
	# Load display settings
	_pending_fullscreen = config.get_value("display", "fullscreen", false)
	_pending_resolution = config.get_value("display", "resolution", 1)
	
	# Load audio settings
	_pending_master = config.get_value("audio", "master", 80.0)
	_pending_sfx = config.get_value("audio", "sfx", 100.0)
	_pending_music = config.get_value("audio", "music", 70.0)


func _save_settings() -> void:
	var config = ConfigFile.new()
	
	# Try to load existing config to preserve other values (like tutorial state)
	config.load(CONFIG_PATH)
	
	# Save display settings
	config.set_value("display", "fullscreen", _pending_fullscreen)
	config.set_value("display", "resolution", _pending_resolution)
	
	# Save audio settings
	config.set_value("audio", "master", _pending_master)
	config.set_value("audio", "sfx", _pending_sfx)
	config.set_value("audio", "music", _pending_music)
	
	config.save(CONFIG_PATH)


func _update_ui_from_pending() -> void:
	fullscreen_toggle.button_pressed = _pending_fullscreen
	resolution_selector.selected = _pending_resolution
	master_slider.value = _pending_master
	sfx_slider.value = _pending_sfx
	music_slider.value = _pending_music
	
	_update_volume_labels()


func _update_volume_labels() -> void:
	master_value.text = "%d%%" % int(_pending_master)
	sfx_value.text = "%d%%" % int(_pending_sfx)
	music_value.text = "%d%%" % int(_pending_music)


func _apply_display_settings() -> void:
	# Check if running in editor - display settings have limitations there
	if OS.has_feature("editor"):
		print("SettingsMenu: Running in editor - display settings saved but window changes may not apply fully")
		print("SettingsMenu: Settings will apply correctly when running exported build")
		return
	
	# Apply fullscreen
	if _pending_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Apply resolution when windowed
		var res = RESOLUTIONS[_pending_resolution]
		DisplayServer.window_set_size(res)
		# Center window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - res) / 2
		DisplayServer.window_set_position(window_pos)


func _apply_audio_settings() -> void:
	AudioManager.set_bus_volume("Master", _pending_master)
	AudioManager.set_bus_volume("SFX", _pending_sfx)
	AudioManager.set_bus_volume("Music", _pending_music)


func _on_fullscreen_toggled(toggled: bool) -> void:
	_pending_fullscreen = toggled


func _on_resolution_selected(index: int) -> void:
	_pending_resolution = index


func _on_master_changed(value: float) -> void:
	_pending_master = value
	master_value.text = "%d%%" % int(value)


func _on_sfx_changed(value: float) -> void:
	_pending_sfx = value
	sfx_value.text = "%d%%" % int(value)


func _on_music_changed(value: float) -> void:
	_pending_music = value
	music_value.text = "%d%%" % int(value)


func _on_reset_tutorial_pressed() -> void:
	print("SettingsMenu: Reset Tutorial pressed!")
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("tutorial", "completed", false)
	config.save(CONFIG_PATH)
	
	# Notify TutorialManager (it's an autoload, not a singleton)
	if TutorialManager:
		TutorialManager.reset_tutorial()
		print("SettingsMenu: TutorialManager.reset_tutorial() called")
	
	# Visual feedback
	reset_tutorial_button.text = "[ TUTORIAL RESET! ]"
	reset_tutorial_button.disabled = true
	
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		reset_tutorial_button.text = "[ RESET TUTORIAL ]"
		reset_tutorial_button.disabled = false
	)


func _on_apply_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	print("SettingsMenu: Apply pressed!")
	print("SettingsMenu: Fullscreen = %s, Resolution = %d" % [_pending_fullscreen, _pending_resolution])
	_save_settings()
	_apply_display_settings()
	_apply_audio_settings()
	
	# Visual feedback - show different message in editor
	var feedback_text: String
	if OS.has_feature("editor"):
		feedback_text = "[ SAVED! ]"  # Settings saved but display changes limited in editor
	else:
		feedback_text = "[ APPLIED! ]"
	
	apply_button.text = feedback_text
	apply_button.disabled = true
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		apply_button.text = "[ APPLY ]"
		apply_button.disabled = false
	)


func _on_back_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		back_pressed.emit()
		queue_free()
	)


## Static helper to load a specific setting value
static func get_setting(section: String, key: String, default_value: Variant) -> Variant:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		return default_value
	return config.get_value(section, key, default_value)


## Static helper to set a specific setting value
static func set_setting(section: String, key: String, value: Variant) -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)
