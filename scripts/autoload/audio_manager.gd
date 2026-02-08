extends Node
## AudioManager - Autoload singleton for all audio playback
## Manages music crossfading, SFX pool, and bus volume control

# Music players (for crossfading)
var _music_player_1: AudioStreamPlayer
var _music_player_2: AudioStreamPlayer
var _current_music_player: AudioStreamPlayer
var _next_music_player: AudioStreamPlayer

# SFX pool (8 players for simultaneous sounds)
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

# Audio cache (lazy loading)
var _audio_cache: Dictionary = {}

# Track to file path mapping
var _music_paths: Dictionary = {
	"title": "res://assets/audio/music/title_ambient.wav",
	"management": "res://assets/audio/music/management_ambient.wav",
	"combat": "res://assets/audio/music/combat_ambient.wav"
}

# SFX key to file path mapping
var _sfx_paths: Dictionary = {
	# UI
	"ui_click": "res://assets/audio/sfx/ui/click.wav",
	"ui_hover": "res://assets/audio/sfx/ui/hover.wav",
	"ui_dialog_open": "res://assets/audio/sfx/ui/dialog_open.wav",
	"ui_dialog_close": "res://assets/audio/sfx/ui/dialog_close.wav",
	"ui_end_turn": "res://assets/audio/sfx/ui/end_turn.wav",
	"ui_transition": "res://assets/audio/sfx/ui/transition.wav",
	# Combat
	"combat_fire": "res://assets/audio/sfx/combat/fire.wav",
	"combat_hit": "res://assets/audio/sfx/combat/hit.wav",
	"combat_miss": "res://assets/audio/sfx/combat/miss.wav",
	"combat_overwatch": "res://assets/audio/sfx/combat/overwatch.wav",
	"combat_turret_fire": "res://assets/audio/sfx/combat/turret_fire.wav",
	"combat_heal": "res://assets/audio/sfx/combat/heal.wav",
	"combat_charge": "res://assets/audio/sfx/combat/charge.wav",
	"combat_execute": "res://assets/audio/sfx/combat/execute.wav",
	"combat_precision": "res://assets/audio/sfx/combat/precision.wav",
	"combat_damage": "res://assets/audio/sfx/combat/damage.wav",
	"combat_death": "res://assets/audio/sfx/combat/death.wav",
	"combat_enemy_alert": "res://assets/audio/sfx/combat/enemy_alert.wav",
	# Alarms
	"alarm_cryo": "res://assets/audio/sfx/alarms/cryo_alarm.wav",
	"alarm_game_over": "res://assets/audio/sfx/alarms/game_over.wav",
	"alarm_victory": "res://assets/audio/sfx/alarms/victory.wav",
	# Movement
	"move_step": "res://assets/audio/sfx/movement/footstep.wav",
	"move_extraction": "res://assets/audio/sfx/movement/extraction_beam.wav",
	"move_jump": "res://assets/audio/sfx/movement/jump_warp.wav"
}


func _ready() -> void:
	# Ensure buses exist (create if they don't)
	_setup_audio_buses()
	
	# Verify bus layout is loaded
	var bus_count = AudioServer.bus_count
	for i in range(bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		var bus_vol = AudioServer.get_bus_volume_db(i)
		var bus_mute = AudioServer.is_bus_mute(i)
	
	# Create music players
	_music_player_1 = AudioStreamPlayer.new()
	_music_player_1.bus = "Music"
	_music_player_1.name = "MusicPlayer1"
	add_child(_music_player_1)
	
	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = "Music"
	_music_player_2.name = "MusicPlayer2"
	add_child(_music_player_2)
	
	_current_music_player = _music_player_1
	_next_music_player = _music_player_2
	
	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_sfx_players.append(player)
	
	# Load saved volume settings
	_load_volume_settings()
	
	var music_bus_idx = AudioServer.get_bus_index("Music")


func _setup_audio_buses() -> void:
	"""Ensure audio buses exist, create them if they don't"""
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		# Master should always exist, but create it if needed
		master_idx = AudioServer.bus_count
		AudioServer.add_bus(master_idx)
		AudioServer.set_bus_name(master_idx, "Master")
	
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		# Create Music bus as child of Master
		music_idx = AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		# Create SFX bus as child of Master
		sfx_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
	
	
	# Verify buses aren't muted and have reasonable volume
	if music_idx >= 0:
		if AudioServer.is_bus_mute(music_idx):
			AudioServer.set_bus_mute(music_idx, false)
	
	if master_idx >= 0:
		if AudioServer.is_bus_mute(master_idx):
			AudioServer.set_bus_mute(master_idx, false)


func _load_volume_settings() -> void:
	"""Load volume settings from config and apply to buses"""
	const CONFIG_PATH: String = "user://settings.cfg"
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	# Default values if config doesn't exist
	var master_vol: float = 80.0
	var sfx_vol: float = 100.0
	var music_vol: float = 70.0
	
	if err == OK:
		master_vol = config.get_value("audio", "master", 80.0)
		sfx_vol = config.get_value("audio", "sfx", 100.0)
		music_vol = config.get_value("audio", "music", 70.0)
	
	set_bus_volume("Master", master_vol)
	set_bus_volume("SFX", sfx_vol)
	set_bus_volume("Music", music_vol)


func _load_audio(path: String) -> AudioStream:
	"""Lazy-load audio file with caching"""
	if path in _audio_cache:
		return _audio_cache[path]
	
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: Audio file not found: %s" % path)
		return null
	
	var stream = load(path) as AudioStream
	if stream:
		_audio_cache[path] = stream
	
	return stream


func play_music(track_key: String) -> void:
	"""Crossfade to new background track"""
	if not track_key in _music_paths:
		push_warning("AudioManager: Unknown music track: %s" % track_key)
		return
	
	var path = _music_paths[track_key]
	
	# Check if file exists
	if not ResourceLoader.exists(path):
		push_error("AudioManager: Music file does not exist: %s" % path)
		return
	
	var stream = _load_audio(path)
	if not stream:
		push_error("AudioManager: Failed to load music track: %s" % path)
		return
	
	
	# If same track is already playing, do nothing
	if _current_music_player.stream == stream and _current_music_player.playing:
		return
	
	# Swap players
	var temp = _current_music_player
	_current_music_player = _next_music_player
	_next_music_player = temp
	
	# Set loop mode for music if it's a WAV file
	if stream is AudioStreamWAV:
		var wav = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	# Stop current player if playing
	if _current_music_player.playing:
		_current_music_player.stop()
	
	# Check bus index
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index < 0:
		push_error("AudioManager: Music bus not found!")
		return
	
	var music_bus_vol = AudioServer.get_bus_volume_db(music_bus_index)
	var master_bus_vol = AudioServer.get_bus_volume_db(0)
	
	# Ensure player is in scene tree
	if not _current_music_player.is_inside_tree():
		push_error("AudioManager: Music player not in scene tree!")
		return
	
	# Start new track on current player
	_current_music_player.stream = stream
	_current_music_player.volume_db = 0.0  # Start at full volume (will be controlled by bus)
	_current_music_player.bus = "Music"
	
	# Verify bus assignment
	var assigned_bus_idx = AudioServer.get_bus_index(_current_music_player.bus)
	if assigned_bus_idx < 0:
		push_error("AudioManager: Invalid bus assignment: %s" % _current_music_player.bus)
		return
	
	# Ensure stream is valid
	if _current_music_player.stream == null:
		push_error("AudioManager: Stream is null after assignment!")
		return
	
	# Play the music - use call_deferred to ensure everything is ready
	call_deferred("_play_music_deferred", track_key)
	
	
	# Crossfade: fade in new, fade out old (only if there's something to fade out)
	if _next_music_player.playing:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_next_music_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(_next_music_player.stop).set_delay(1.0)


func stop_music(fade_duration: float = 0.5) -> void:
	"""Fade out current music"""
	if not _current_music_player.playing and not _next_music_player.playing:
		return
	
	# Only create tween if there's something to fade
	var has_playing = _current_music_player.playing or _next_music_player.playing
	if not has_playing:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	if _current_music_player.playing:
		tween.tween_property(_current_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(_current_music_player.stop).set_delay(fade_duration)
	if _next_music_player.playing:
		tween.tween_property(_next_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(_next_music_player.stop).set_delay(fade_duration)


func play_sfx(sfx_key: String) -> void:
	"""Play one-shot sound effect"""
	if not sfx_key in _sfx_paths:
		push_warning("AudioManager: Unknown SFX key: %s" % sfx_key)
		return
	
	var path = _sfx_paths[sfx_key]
	var stream = _load_audio(path)
	if not stream:
		return
	
	# Find available player in pool
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	
	# All players busy - use first one (will interrupt)
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func _play_music_deferred(track_key: String) -> void:
	"""Deferred music playback to ensure everything is ready"""
	if not _current_music_player:
		push_error("AudioManager: _current_music_player is null!")
		return
	
	if not _current_music_player.stream:
		push_error("AudioManager: Stream is null in deferred play!")
		return
	
	if not _current_music_player.is_inside_tree():
		push_error("AudioManager: Player not in tree in deferred play!")
		return
	
	_current_music_player.play()
	
	# Verify it's actually playing after a short delay (give play() time to start)
	# Use timer callback instead of await since this is called via call_deferred
	get_tree().create_timer(0.1).timeout.connect(func(): _verify_music_playing(track_key))


func _verify_music_playing(track_key: String) -> void:
	"""Verify music is actually playing"""
	if not _current_music_player.playing:
		push_error("AudioManager: Music player failed to start playing track: %s" % track_key)
		var music_bus_idx = AudioServer.get_bus_index("Music")
		var master_bus_idx = AudioServer.get_bus_index("Master")
		
		# Try to diagnose the issue
		if _current_music_player.stream == null:
			push_error("AudioManager: Stream is null!")
		if not _current_music_player.is_inside_tree():
			push_error("AudioManager: Player is not in scene tree!")
		if music_bus_idx >= 0 and AudioServer.is_bus_mute(music_bus_idx):
			push_error("AudioManager: Music bus is muted!")
		if master_bus_idx >= 0 and AudioServer.is_bus_mute(master_bus_idx):
			push_error("AudioManager: Master bus is muted!")
		if music_bus_idx >= 0 and AudioServer.get_bus_volume_db(music_bus_idx) <= -80.0:
			push_error("AudioManager: Music bus volume is too low!")


func set_bus_volume(bus: String, percent: float) -> void:
	"""Set bus volume (0-100 percent)"""
	var bus_index = AudioServer.get_bus_index(bus)
	if bus_index < 0:
		push_warning("AudioManager: Bus not found: %s" % bus)
		return
	
	# Convert percent (0-100) to dB
	# 0% = -80dB (mute), 100% = 0dB (full volume)
	var volume_db: float
	if percent <= 0.0:
		volume_db = -80.0
	else:
		volume_db = linear_to_db(percent / 100.0)
	
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	
	# Mute if volume is 0
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
