extends Node
## Music Manager - Handles background music playback
## Manages navigation and tactical mission music tracks

@onready var navigation_player: AudioStreamPlayer = null
@onready var tactical_player: AudioStreamPlayer = null
@onready var title_player: AudioStreamPlayer = null

var current_track: AudioStreamPlayer = null
const CONFIG_PATH: String = "user://settings.cfg"

var master_volume: float = 80.0  # 0-100
var music_volume: float = 70.0  # 0-100


func _ready() -> void:
	# Create title music player
	title_player = AudioStreamPlayer.new()
	title_player.name = "TitlePlayer"
	var title_stream = load("res://assets/audio/music/title_menu_music.mp3")
	if title_stream:
		title_stream.loop = true
		title_player.stream = title_stream
		title_player.autoplay = false
		add_child(title_player)

	# Create navigation music player
	navigation_player = AudioStreamPlayer.new()
	navigation_player.name = "NavigationPlayer"
	var nav_stream = load("res://assets/audio/music/navigation_system_music.mp3")
	if nav_stream:
		# Enable looping for continuous playback
		nav_stream.loop = true
		navigation_player.stream = nav_stream
		navigation_player.autoplay = false
		add_child(navigation_player)
	
	# Create tactical mission music player
	tactical_player = AudioStreamPlayer.new()
	tactical_player.name = "TacticalPlayer"
	var tactical_stream = load("res://assets/audio/music/tactical_mission_music.mp3")
	if tactical_stream:
		# Enable looping for continuous playback
		tactical_stream.loop = true
		tactical_player.stream = tactical_stream
		tactical_player.autoplay = false
		add_child(tactical_player)
	
	# Load volume settings
	_load_volume_settings()
	_update_volume()


## Play title music
func play_title_music() -> void:
	if current_track == title_player:
		return  # Already playing
	
	_switch_track(title_player)


## Play navigation music
func play_navigation_music() -> void:
	if current_track == navigation_player:
		return  # Already playing
	
	_switch_track(navigation_player)


## Play tactical mission music
func play_tactical_music() -> void:
	if current_track == tactical_player:
		return  # Already playing
	
	_switch_track(tactical_player)


## Stop all music
func stop_music() -> void:
	if current_track == null:
		return
	
	current_track.stop()
	current_track = null


## Switch from current track to new track
func _switch_track(new_track: AudioStreamPlayer) -> void:
	var old_track = current_track
	current_track = new_track
	
	# Stop old track immediately
	if old_track and old_track.playing:
		old_track.stop()
	
	# Set volume and start new track immediately
	var target_volume_db = _calculate_volume_db()
	new_track.volume_db = target_volume_db
	if not new_track.playing:
		new_track.play()


## Load volume settings from config file
func _load_volume_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		# Use defaults if no config exists
		master_volume = 80.0
		music_volume = 70.0
		return
	
	# Load audio settings
	master_volume = config.get_value("audio", "master", 80.0)
	music_volume = config.get_value("audio", "music", 70.0)



# Ducking settings
var ducking_tween: Tween = null
var ducking_db: float = 0.0
const DUCKING_AMOUNT: float = -12.0  # dB reduction during ducking
const DUCKING_FADE_IN_TIME: float = 0.5  # Time to lower volume
const DUCKING_FADE_OUT_TIME: float = 1.0  # Time to restore volume


## Set ducking state (lower music volume temporarily)
func set_ducking(active: bool) -> void:
	if ducking_tween and ducking_tween.is_running():
		ducking_tween.kill()
	
	ducking_tween = create_tween()
	var target_db = DUCKING_AMOUNT if active else 0.0
	var duration = DUCKING_FADE_IN_TIME if active else DUCKING_FADE_OUT_TIME
	
	ducking_tween.tween_method(_set_ducking_db, ducking_db, target_db, duration)


## Internal callback for tweening ducking volume
func _set_ducking_db(value: float) -> void:
	ducking_db = value
	_update_volume()


## Update volume for all music players
func _update_volume() -> void:
	var target_volume_db = _calculate_volume_db() + ducking_db
	
	# Update both players if they exist
	if navigation_player:
		navigation_player.volume_db = target_volume_db
	
	if tactical_player:
		tactical_player.volume_db = target_volume_db

	if title_player:
		title_player.volume_db = target_volume_db

## Calculate volume in dB from percentage values
func _calculate_volume_db() -> float:
	# Convert percentage (0-100) to linear (0-1)
	var master_linear = master_volume / 100.0
	var music_linear = music_volume / 100.0
	
	# Combined volume
	var combined_linear = master_linear * music_linear
	
	# Convert to dB (0.0 linear = -80 dB, 1.0 linear = 0 dB)
	if combined_linear <= 0.0:
		return -80.0
	
	# Map 0-1 to -80 to 0 dB
	return linear_to_db(combined_linear)


## Update master volume (called from settings menu)
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 100.0)
	_update_volume()


## Update music volume (called from settings menu)
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 100.0)
	_update_volume()
