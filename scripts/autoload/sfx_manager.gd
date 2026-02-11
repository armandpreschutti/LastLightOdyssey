extends Node
## SFX Manager - Handles sound effects playback with volume control
## Manages a pool of AudioStreamPlayer nodes for concurrent SFX playback

const POOL_SIZE: int = 16  # Number of AudioStreamPlayer nodes in the pool
const CONFIG_PATH: String = "user://settings.cfg"

var audio_pool: Array[AudioStreamPlayer] = []
var pool_index: int = 0

var master_volume: float = 80.0  # 0-100
var sfx_volume: float = 100.0  # 0-100
var music_volume: float = 70.0  # 0-100
var scene_volume: float = 100.0  # 0-100 (Separate channel for narrative scene SFX)

var scene_player: AudioStreamPlayer = null


func _ready() -> void:
	# Create pool of AudioStreamPlayer nodes
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "Master"  # Use Master bus by default
		add_child(player)
		audio_pool.append(player)
	
	# Create dedicated Scene SFX player
	scene_player = AudioStreamPlayer.new()
	scene_player.name = "SceneSFXPlayer"
	scene_player.bus = "Master"
	add_child(scene_player)
	
	# Load volume settings
	_load_volume_settings()
	_update_volume()
	
	# Connect signal for auto-undocking
	if scene_player:
		scene_player.finished.connect(_on_scene_sfx_finished)


## Load volume settings from config file
func _load_volume_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		# Use defaults if no config exists
		master_volume = 80.0
		sfx_volume = 100.0
		return
	
	# Load audio settings
	master_volume = config.get_value("audio", "master", 80.0)
	sfx_volume = config.get_value("audio", "sfx", 100.0)
	music_volume = config.get_value("audio", "music", 70.0)
	scene_volume = config.get_value("audio", "scene", 100.0)


## Update volume for all SFX players
func _update_volume() -> void:
	var volume_db = _calculate_volume_db()
	
	for player in audio_pool:
		player.volume_db = volume_db
	
	# Update Scene SFX volume separately
	_update_scene_volume()


## Calculate volume in dB from percentage values
func _calculate_volume_db() -> float:
	# Convert percentage (0-100) to linear (0-1)
	var master_linear = master_volume / 100.0
	var sfx_linear = sfx_volume / 100.0
	
	# Combined volume
	var combined_linear = master_linear * sfx_linear
	
	# Convert to dB (0.0 linear = 0 dB, 0.0 linear = -80 dB)
	if combined_linear <= 0.0:
		return -80.0
	
	# Map 0-1 to -80 to 0 dB
	# Map 0-1 to -80 to 0 dB
	return linear_to_db(combined_linear)


## Calculate scene volume in dB
func _calculate_scene_volume_db() -> float:
	var master_linear = master_volume / 100.0
	var scene_linear = scene_volume / 100.0
	var combined_linear = master_linear * scene_linear
	
	if combined_linear <= 0.0:
		return -80.0
	return linear_to_db(combined_linear)


## Update Scene SFX volume
func _update_scene_volume() -> void:
	if scene_player:
		scene_player.volume_db = _calculate_scene_volume_db()


## Update master volume (called from settings menu)
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 100.0)
	_update_volume()


## Update SFX volume (called from settings menu)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 100.0)
	_update_volume()


## Update Scene volume (called from settings menu)
func set_scene_volume(volume: float) -> void:
	scene_volume = clamp(volume, 0.0, 100.0)
	_update_scene_volume()


## Play a sound effect by path
## path: Full path to audio file (e.g., "res://assets/audio/sfx/combat/shoot.mp3")
## pitch_scale: Optional pitch variation (1.0 = normal, 0.8-1.2 for variation)
func play_sfx(path: String, pitch_scale: float = 1.0) -> void:
	if path.is_empty():
		return
	
	# Get next available player from pool
	var player = _get_available_player()
	if not player:
		return  # All players busy, skip this sound
	
	# Load and play the sound
	var stream = load(path)
	if not stream:
		push_warning("SFXManager: Failed to load audio file: %s" % path)
		return
	
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()


## Play a sound effect by category and name
## category: "combat", "ui", "interactions"
## name: Name of the sound file without extension (e.g., "shoot", "click")
func play_sfx_by_name(category: String, name: String, pitch_scale: float = 1.0) -> void:
	var path = "res://assets/audio/sfx/%s/%s.mp3" % [category, name]
	play_sfx(path, pitch_scale)


## Play use Scene SFX player (dedicated channel, stops previous scene SFX)
func play_scene_sfx(path: String) -> void:
	if not scene_player:
		return
		
	# Stop any currently playing scene SFX first
	scene_player.stop()
	
	var stream = load(path)
	if not stream:
		push_warning("SFXManager: Failed to load scene audio file: %s" % path)
		return
	
	scene_player.stream = stream
	scene_player.play()
	
	# Lower music volume
	if MusicManager:
		MusicManager.set_ducking(true)


## Stop current running scene SFX immediately
func stop_scene_sfx() -> void:
	if scene_player and scene_player.playing:
		scene_player.stop()
		# Restore music volume immediately if manually stopped
		if MusicManager:
			MusicManager.set_ducking(false)


## Callback when scene SFX finishes naturally
func _on_scene_sfx_finished() -> void:
	# Restore music volume
	if MusicManager:
		MusicManager.set_ducking(false)


## Get next available player from the pool (round-robin)
func _get_available_player() -> AudioStreamPlayer:
	# Try to find a player that's not currently playing
	for i in range(POOL_SIZE):
		var index = (pool_index + i) % POOL_SIZE
		var player = audio_pool[index]
		
		if not player.playing:
			pool_index = (index + 1) % POOL_SIZE
			return player
	
	# All players busy, use round-robin to avoid cutting off sounds
	var player = audio_pool[pool_index]
	pool_index = (pool_index + 1) % POOL_SIZE
	return player


## Stop all currently playing SFX
func stop_all() -> void:
	for player in audio_pool:
		if player.playing:
			player.stop()
