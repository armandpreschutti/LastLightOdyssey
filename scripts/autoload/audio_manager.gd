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
	"combat_crit": "res://assets/audio/sfx/combat/crit.wav",
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
	# Set process mode to always so audio continues during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_audio_buses()

	# Create music players
	_music_player_1 = AudioStreamPlayer.new()
	_music_player_1.bus = "Music"
	_music_player_1.name = "MusicPlayer1"
	_music_player_1.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player_1)

	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = "Music"
	_music_player_2.name = "MusicPlayer2"
	_music_player_2.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player_2)

	_current_music_player = _music_player_1
	_next_music_player = _music_player_2

	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.name = "SFXPlayer%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)

	_load_volume_settings()


func _setup_audio_buses() -> void:
	# Ensure Master bus exists and is not muted
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		master_idx = 0
		if AudioServer.bus_count == 0:
			AudioServer.add_bus(0)
		AudioServer.set_bus_name(0, "Master")
	AudioServer.set_bus_mute(master_idx, false)
	# Ensure Master bus has volume
	if AudioServer.get_bus_volume_db(master_idx) < -79.0:
		AudioServer.set_bus_volume_db(master_idx, 0.0)
	
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		music_idx = AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	AudioServer.set_bus_mute(music_idx, false)
	# Ensure Music bus has volume
	if AudioServer.get_bus_volume_db(music_idx) < -79.0:
		AudioServer.set_bus_volume_db(music_idx, 0.0)

	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		sfx_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
	AudioServer.set_bus_mute(sfx_idx, false)
	# Ensure SFX bus has volume
	if AudioServer.get_bus_volume_db(sfx_idx) < -79.0:
		AudioServer.set_bus_volume_db(sfx_idx, 0.0)


func _load_volume_settings() -> void:
	const CONFIG_PATH: String = "user://settings.cfg"
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	var master_vol: float = 80.0
	var sfx_vol: float = 100.0
	var music_vol: float = 70.0

	if err == OK:
		master_vol = config.get_value("audio", "master", 80.0)
		sfx_vol = config.get_value("audio", "sfx", 100.0)
		music_vol = config.get_value("audio", "music", 70.0)

	# Ensure volumes are not zero
	if master_vol <= 0.0:
		master_vol = 80.0
	if music_vol <= 0.0:
		music_vol = 70.0
	if sfx_vol <= 0.0:
		sfx_vol = 100.0

	set_bus_volume("Master", master_vol)
	set_bus_volume("SFX", sfx_vol)
	set_bus_volume("Music", music_vol)


func _load_audio(path: String) -> AudioStream:
	if path in _audio_cache:
		return _audio_cache[path]

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: Audio file not found: %s" % path)
		return null

	# Use ResourceLoader.load() for more reliable loading, especially for Godot 4.6
	var stream = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE) as AudioStream
	if not stream:
		push_warning("AudioManager: Failed to load audio stream: %s" % path)
		return null
	
	_audio_cache[path] = stream
	return stream


func play_music(track_key: String) -> void:
	if not track_key in _music_paths:
		push_warning("AudioManager: Unknown music track: %s" % track_key)
		return

	# Ensure players are initialized
	if not _current_music_player or not _next_music_player:
		return

	var stream = _load_audio(_music_paths[track_key])
	if not stream:
		return

	# If same track is already playing, do nothing
	if _current_music_player.stream == stream and _current_music_player.playing:
		return

	# Swap players
	var temp = _current_music_player
	_current_music_player = _next_music_player
	_next_music_player = temp

	# Stop current player before switching
	if _current_music_player.playing:
		_current_music_player.stop()

	# Set loop mode for WAV files BEFORE assigning to player
	if stream is AudioStreamWAV:
		var wav_stream = stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	# Start new track - set all properties before play()
	_current_music_player.stream = stream
	_current_music_player.volume_db = 0.0
	_current_music_player.bus = "Music"  # Explicitly set bus
	_current_music_player.autoplay = false  # Ensure autoplay is off
	
	# Workaround for Godot 4.6 editor audio bug - force initialization
	# Call play() and verify it started
	_current_music_player.play()
	
	# Force update to ensure playback starts (workaround for 4.6 editor bug)
	# Use call_deferred to retry if playback didn't start
	if not _current_music_player.playing:
		call_deferred("_retry_play_music", _current_music_player)

	# Crossfade out old player
	if _next_music_player.playing:
		var tween = create_tween()
		tween.tween_property(_next_music_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(_next_music_player.stop)


func _retry_play_music(player: AudioStreamPlayer) -> void:
	if player and not player.playing and player.stream:
		player.play()


func stop_music(fade_duration: float = 0.5) -> void:
	if not _current_music_player.playing and not _next_music_player.playing:
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
	if not sfx_key in _sfx_paths:
		push_warning("AudioManager: Unknown SFX key: %s" % sfx_key)
		return

	var stream = _load_audio(_sfx_paths[sfx_key])
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


func set_bus_volume(bus: String, percent: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus)
	if bus_index < 0:
		push_warning("AudioManager: Bus not found: %s" % bus)
		return

	var volume_db: float
	if percent <= 0.0:
		volume_db = -80.0
	else:
		volume_db = linear_to_db(percent / 100.0)

	AudioServer.set_bus_volume_db(bus_index, volume_db)
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
