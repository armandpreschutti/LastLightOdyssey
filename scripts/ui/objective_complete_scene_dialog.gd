extends Control
## Objective Complete Scene Dialog - Displays a scene when optional mission objectives are completed
## Shows mission equipment/context based on objective description, pausing tactical gameplay

signal scene_dismissed

@onready var scene_image: TextureRect = $VBoxContainer/ImageContainer/SceneImage
@onready var scanline_overlay: Control = $VBoxContainer/ImageContainer/ScanlineOverlay
@onready var scene_canvas: Control = $VBoxContainer/ImageContainer/SceneCanvas
@onready var title_label: Label = $VBoxContainer/TitleBar/TitleLabel
@onready var location_label: Label = $VBoxContainer/TitleBar/LocationLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var background: ColorRect = $Background

var _prompt_tween: Tween = null
var _typewriter_tween: Tween = null
var _current_desc: String = ""
var _current_char: int = 0
var _input_ready: bool = false
var _current_biome: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION
var _objective_description: String = ""
var _rewards_text: String = ""
var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []

# Color palettes for each biome type (Oregon Trail retro sci-fi style)
const BIOME_PALETTES: Dictionary = {
	BiomeConfig.BiomeType.STATION: {"bg": Color(0.02, 0.02, 0.08), "accent": Color(0.3, 0.9, 1.0), "detail": Color(0.5, 0.95, 1.0)},  # Station - cyan/blue
	BiomeConfig.BiomeType.ASTEROID: {"bg": Color(0.05, 0.04, 0.03), "accent": Color(0.5, 0.5, 0.6), "detail": Color(0.7, 0.7, 0.8)},  # Asteroid - brown/gray
	BiomeConfig.BiomeType.PLANET: {"bg": Color(0.08, 0.05, 0.10), "accent": Color(0.8, 0.5, 0.9), "detail": Color(0.95, 0.6, 0.2)},  # Planet - purple/orange
}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Allow input when game is paused
	scanline_overlay.draw.connect(_draw_scene_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene(objective: MissionObjective, biome_type: int, alive_officers: Array[String], rewards: Dictionary) -> void:
	_current_biome = biome_type as BiomeConfig.BiomeType
	_objective_description = objective.description
	
	# Build rewards text
	var reward_parts: Array[String] = []
	if rewards.get("fuel", 0) > 0:
		reward_parts.append("+%d FUEL" % rewards.get("fuel", 0))
	if rewards.get("scrap", 0) > 0:
		reward_parts.append("+%d SCRAP" % rewards.get("scrap", 0))
	if rewards.get("colonists", 0) > 0:
		reward_parts.append("+%d COLONISTS" % rewards.get("colonists", 0))
	if rewards.get("hull_repair", 0) > 0:
		reward_parts.append("+%d%% HULL" % rewards.get("hull_repair", 0))
	
	if reward_parts.size() > 0:
		_rewards_text = " [REWARD: " + " / ".join(reward_parts) + "]"
	else:
		_rewards_text = ""
	
	var biome_name = BiomeConfig.get_biome_name(_current_biome)
	
	# Set title
	title_label.text = "OBJECTIVE COMPLETE"
	
	# Set location/date flavor text
	location_label.text = "%s  |  SECTOR %d-%d  |  CYCLE %d" % [
		biome_name.to_upper(),
		randi_range(1, 9),
		randi_range(100, 999),
		GameState.current_node_index + 1
	]
	
	# Determine objective type from description keywords
	var obj_lower = _objective_description.to_lower()
	var obj_type = "generic"
	
	if "hack" in obj_lower: obj_type = "hack"
	elif "retrieve" in obj_lower: obj_type = "retrieve"
	elif "repair" in obj_lower: obj_type = "repair"
	elif "clear" in obj_lower and "passage" in obj_lower: obj_type = "clear"
	elif "mining" in obj_lower: obj_type = "mining"
	elif "extract" in obj_lower: obj_type = "extract"
	elif "sample" in obj_lower: obj_type = "collect"
	elif "beacon" in obj_lower: obj_type = "beacon"
	elif "nest" in obj_lower: obj_type = "nest"
	
	var image_path = "res://assets/sprites/scenes/mission_%s.png" % obj_type
	if ResourceLoader.exists(image_path):
		scene_image.texture = load(image_path)
		scene_image.visible = true
		scene_canvas.visible = false
	else:
		# Use procedural generation for mission scene
		scene_image.visible = false
		scene_canvas.visible = true
		_generate_scene_elements()
		scene_canvas.queue_redraw()
	
	# Build description with objective and rewards
	var description = "%s.%s" % [_objective_description, _rewards_text]
	
	# Start typewriter effect for description
	_current_desc = description
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
	# Play objective complete SFX
	_play_objective_sfx()
	
	# Fade in
	modulate.a = 0.0
	visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_callback(_start_description_typewriter)


func _start_description_typewriter() -> void:
	_typewriter_tween = create_tween()
	_typewriter_tween.set_loops(_current_desc.length())
	_typewriter_tween.tween_callback(_add_desc_char)
	_typewriter_tween.tween_interval(0.05)
	_typewriter_tween.finished.connect(_on_typewriter_done)


func _add_desc_char() -> void:
	if _current_char < _current_desc.length():
		description_label.text = _current_desc.substr(0, _current_char + 1)
		_current_char += 1


func _on_typewriter_done() -> void:
	description_label.text = _current_desc
	_show_prompt()


func _show_prompt() -> void:
	_input_ready = true
	
	# Pulse the prompt text
	_prompt_tween = create_tween()
	_prompt_tween.set_loops()
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.6)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.6)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		if _input_ready:
			_dismiss()
		else:
			# Skip typewriter
			_skip_typewriter()
	elif event is InputEventMouseButton and event.pressed:
		if _input_ready:
			_dismiss()
		else:
			_skip_typewriter()


func _skip_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	description_label.text = _current_desc
	_on_typewriter_done()


func _dismiss() -> void:
	if _prompt_tween:
		_prompt_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_on_dismissed)


func _on_dismissed() -> void:
	visible = false
	if SFXManager:
		SFXManager.stop_scene_sfx()
	scene_dismissed.emit()


## Play objective complete SFX
func _play_objective_sfx() -> void:
	var sfx_file = "objective_complete.mp3"
	SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/objective_complete_scene/" + sfx_file)


## Draw CRT-style scanlines over the scene image
func _draw_scene_scanlines() -> void:
	var rect_size = scanline_overlay.size
	var scanline_color = Color(0.0, 0.0, 0.0, 0.12)
	var line_spacing: float = 2.0
	
	var y: float = 0.0
	while y < rect_size.y:
		scanline_overlay.draw_rect(
			Rect2(0, y, rect_size.x, 1.0),
			scanline_color
		)
		y += line_spacing


#region Procedural Scene Generation

func _generate_scene_elements() -> void:
	_scene_stars.clear()
	_scene_particles.clear()
	
	# Generate background stars
	for i in range(80):
		_scene_stars.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.2, 0.8),
		})
	
	# Generate biome-specific particles
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			# Station - floating debris and lights
			for i in range(20):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 6.0),
					"alpha": randf_range(0.3, 0.7),
				})
		BiomeConfig.BiomeType.ASTEROID:
			# Asteroid - rocky chunks and dust
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 5.0),
					"alpha": randf_range(0.2, 0.6),
				})
		BiomeConfig.BiomeType.PLANET:
			# Planet - bioluminescent particles
			for i in range(30):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 8.0),
					"alpha": randf_range(0.2, 0.8),
				})


func _draw_procedural_scene() -> void:
	var canvas_size = scene_canvas.size
	var palette = BIOME_PALETTES.get(_current_biome, BIOME_PALETTES[BiomeConfig.BiomeType.STATION])
	
	# Draw background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), palette.bg)
	
	# Draw stars
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = Color(0.7, 0.8, 0.9, star.brightness)
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw mission scene based on objective description
	_draw_mission_scene(canvas_size, palette)
	
	# Draw biome-specific effects
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_effects(canvas_size, palette)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_effects(canvas_size, palette)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_effects(canvas_size, palette)


func _draw_mission_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Route to objective-specific drawing function based on description
	match _objective_description:
		"Hack security systems":
			_draw_hack_security_scene(canvas_size, palette)
		"Retrieve data logs":
			_draw_retrieve_logs_scene(canvas_size, palette)
		"Repair power core":
			_draw_repair_core_scene(canvas_size, palette)
		"Clear cave passages":
			_draw_clear_passages_scene(canvas_size, palette)
		"Activate mining equipment":
			_draw_activate_mining_scene(canvas_size, palette)
		"Extract rare minerals":
			_draw_extract_minerals_scene(canvas_size, palette)
		"Collect alien samples":
			_draw_collect_samples_scene(canvas_size, palette)
		"Activate beacons":
			_draw_activate_beacons_scene(canvas_size, palette)
		"Clear hostile nests":
			_draw_clear_nests_scene(canvas_size, palette)
		_:
			# Fallback generic mission complete scene
			_draw_generic_mission_scene(canvas_size, palette)


#region Objective-Specific Scene Drawing

func _draw_hack_security_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Security terminal/console with glowing interface, data streams, success indicators
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	var px = 4.0
	
	# Terminal body
	var term_width = 120.0
	var term_height = 80.0
	scene_canvas.draw_rect(Rect2(center_x - term_width/2, center_y - term_height/2, term_width, term_height), Color(0.15, 0.2, 0.25))
	
	# Terminal screen (glowing)
	var screen_color = Color(0.2, 0.8, 0.3)  # Terminal green
	screen_color.a = 0.8
	scene_canvas.draw_rect(Rect2(center_x - term_width/2 + 10, center_y - term_height/2 + 10, term_width - 20, term_height - 20), screen_color)
	
	# Success indicator (checkmark or "ACCESS GRANTED")
	var success_color = Color(0.3, 1.0, 0.5)
	scene_canvas.draw_rect(Rect2(center_x - 20, center_y - 10, 40, 20), success_color)
	
	# Data streams (flowing lines)
	for i in range(5):
		var stream_y = center_y - 30 + i * 15
		var stream_color = Color(0.2, 0.9, 1.0, 0.6)
		scene_canvas.draw_line(Vector2(center_x - 50, stream_y), Vector2(center_x + 50, stream_y), stream_color, 2.0)
	
	# Glow effect around terminal
	var glow_color = palette.accent
	glow_color.a = 0.3
	scene_canvas.draw_circle(Vector2(center_x, center_y), 80.0, glow_color)


func _draw_retrieve_logs_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Data storage units, glowing data chips/logs, retrieval interface
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	var px = 4.0
	
	# Data storage unit
	var storage_width = 100.0
	var storage_height = 60.0
	scene_canvas.draw_rect(Rect2(center_x - storage_width/2, center_y - storage_height/2, storage_width, storage_height), Color(0.2, 0.25, 0.3))
	
	# Glowing data chips/logs (multiple)
	for i in range(3):
		var chip_x = center_x - 30 + i * 30
		var chip_y = center_y - 20
		var chip_color = Color(0.3, 0.7, 1.0, 0.8)  # Blue data chips
		scene_canvas.draw_rect(Rect2(chip_x - 8, chip_y - 4, 16, 8), chip_color)
		# Glow
		var chip_glow = chip_color
		chip_glow.a = 0.4
		scene_canvas.draw_circle(Vector2(chip_x, chip_y), 12.0, chip_glow)
	
	# Retrieval interface indicator
	var interface_color = palette.detail
	interface_color.a = 0.7
	scene_canvas.draw_rect(Rect2(center_x - 15, center_y + 20, 30, 4), interface_color)


func _draw_repair_core_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Power core/reactor with repair indicators, energy flowing, operational status
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Power core (circular reactor)
	var core_radius = 50.0
	var core_color = Color(0.3, 0.3, 0.4)
	scene_canvas.draw_circle(Vector2(center_x, center_y), core_radius, core_color)
	
	# Inner core (glowing)
	var inner_color = Color(1.0, 0.6, 0.2, 0.8)  # Orange energy
	scene_canvas.draw_circle(Vector2(center_x, center_y), 30.0, inner_color)
	
	# Energy flowing (pulsing rings)
	for i in range(3):
		var ring_radius = core_radius + 10 + i * 15
		var ring_color = Color(1.0, 0.7, 0.3, 0.3 - i * 0.1)
		scene_canvas.draw_arc(Vector2(center_x, center_y), ring_radius, 0, TAU, 32, ring_color, 3.0)
	
	# Operational status indicator (green)
	var status_color = Color(0.2, 1.0, 0.3)
	scene_canvas.draw_rect(Rect2(center_x - 10, center_y + 60, 20, 6), status_color)


func _draw_clear_passages_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Cleared passage entrance, debris removed, open tunnel
	var center_x = canvas_size.x * 0.5
	var passage_y = canvas_size.y * 0.6
	var px = 4.0
	
	# Cave passage entrance (arch shape)
	var passage_width = 150.0
	var passage_height = 100.0
	# Arch top
	scene_canvas.draw_arc(Vector2(center_x, passage_y - passage_height/2), passage_width/2, 0, PI, 32, Color(0.3, 0.25, 0.2), 8.0)
	# Passage opening (cleared, lighter)
	var cleared_color = Color(0.4, 0.35, 0.3)
	scene_canvas.draw_rect(Rect2(center_x - passage_width/2, passage_y - passage_height/2, passage_width, passage_height), cleared_color)
	
	# Debris removed (small dark spots outside passage)
	for i in range(8):
		var debris_x = center_x - 100 + (i % 4) * 60
		var debris_y = passage_y - 60 + (i / 4) * 40
		if debris_x < center_x - passage_width/2 or debris_x > center_x + passage_width/2:
			scene_canvas.draw_circle(Vector2(debris_x, debris_y), 5.0, Color(0.2, 0.15, 0.1))
	
	# Open tunnel indicator (light at end)
	var tunnel_light = Color(0.8, 0.7, 0.6, 0.5)
	scene_canvas.draw_circle(Vector2(center_x, passage_y), 20.0, tunnel_light)


func _draw_activate_mining_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Mining equipment/drills active, extraction beams, operational machinery
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	var px = 4.0
	
	# Mining equipment base
	var equip_width = 140.0
	var equip_height = 80.0
	scene_canvas.draw_rect(Rect2(center_x - equip_width/2, center_y - equip_height/2, equip_width, equip_height), Color(0.25, 0.2, 0.15))
	
	# Drill head (active, spinning)
	var drill_color = Color(0.6, 0.5, 0.4)
	scene_canvas.draw_circle(Vector2(center_x, center_y - 20), 25.0, drill_color)
	# Drill bit
	scene_canvas.draw_rect(Rect2(center_x - 4, center_y - 45, 8, 25), drill_color)
	
	# Extraction beams (glowing lines)
	for i in range(3):
		var beam_x = center_x - 40 + i * 40
		var beam_color = Color(1.0, 0.8, 0.3, 0.7)
		scene_canvas.draw_line(Vector2(beam_x, center_y + 20), Vector2(beam_x, center_y + 60), beam_color, 4.0)
	
	# Operational indicator
	var op_color = Color(0.2, 1.0, 0.3)
	scene_canvas.draw_rect(Rect2(center_x - 8, center_y + 50, 16, 4), op_color)


func _draw_extract_minerals_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Mineral deposits, extraction equipment, glowing rare materials
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Mineral deposit (glowing cluster)
	var deposit_color = Color(0.9, 0.7, 0.2, 0.9)  # Amber/gold
	scene_canvas.draw_circle(Vector2(center_x, center_y), 40.0, deposit_color)
	# Inner glow
	var inner_glow = Color(1.0, 0.9, 0.4, 0.6)
	scene_canvas.draw_circle(Vector2(center_x, center_y), 25.0, inner_glow)
	
	# Extraction equipment (arms/claws)
	for i in range(2):
		var arm_x = center_x - 30 + i * 60
		var arm_color = Color(0.4, 0.35, 0.3)
		# Arm
		scene_canvas.draw_rect(Rect2(arm_x - 4, center_y - 30, 8, 40), arm_color)
		# Claw
		scene_canvas.draw_rect(Rect2(arm_x - 8, center_y + 10, 16, 8), arm_color)
	
	# Rare material glow (pulsing)
	var rare_glow = Color(1.0, 0.8, 0.2, 0.4)
	scene_canvas.draw_circle(Vector2(center_x, center_y), 60.0, rare_glow)


func _draw_collect_samples_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Sample collectors, bioluminescent samples, collection containers
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Sample collector device
	var collector_width = 100.0
	var collector_height = 60.0
	scene_canvas.draw_rect(Rect2(center_x - collector_width/2, center_y - collector_height/2, collector_width, collector_height), Color(0.3, 0.25, 0.3))
	
	# Bioluminescent samples (glowing purple/pink)
	for i in range(4):
		var sample_x = center_x - 30 + (i % 2) * 60
		var sample_y = center_y - 20 + (i / 2) * 40
		var sample_color = Color(0.8, 0.3, 0.9, 0.8)  # Purple/pink
		scene_canvas.draw_circle(Vector2(sample_x, sample_y), 12.0, sample_color)
		# Glow
		var sample_glow = sample_color
		sample_glow.a = 0.4
		scene_canvas.draw_circle(Vector2(sample_x, sample_y), 20.0, sample_glow)
	
	# Collection container
	var container_color = Color(0.2, 0.2, 0.25)
	scene_canvas.draw_rect(Rect2(center_x - 20, center_y + 30, 40, 20), container_color)


func _draw_activate_beacons_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Activated beacon with signal waves, transmission indicators, active status
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Beacon tower
	var beacon_width = 20.0
	var beacon_height = 80.0
	scene_canvas.draw_rect(Rect2(center_x - beacon_width/2, center_y - beacon_height/2, beacon_width, beacon_height), Color(0.3, 0.3, 0.35))
	
	# Beacon top (active, glowing)
	var beacon_top_color = Color(0.2, 1.0, 0.3, 0.9)  # Green active
	scene_canvas.draw_circle(Vector2(center_x, center_y - 30), 12.0, beacon_top_color)
	
	# Signal waves (expanding rings)
	for i in range(4):
		var wave_radius = 40.0 + i * 25
		var wave_color = Color(0.3, 0.9, 0.5, 0.3 - i * 0.07)
		scene_canvas.draw_arc(Vector2(center_x, center_y - 30), wave_radius, 0, TAU, 32, wave_color, 2.0)
	
	# Transmission indicator
	var trans_color = Color(0.2, 1.0, 0.4)
	scene_canvas.draw_rect(Rect2(center_x - 6, center_y - 40, 12, 4), trans_color)


func _draw_clear_nests_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Destroyed nest debris, cleared area, safety indicators
	var center_x = canvas_size.x * 0.5
	var nest_y = canvas_size.y * 0.6
	
	# Destroyed nest (debris)
	var nest_color = Color(0.2, 0.15, 0.1)
	# Main nest structure (destroyed, scattered)
	for i in range(6):
		var debris_x = center_x - 40 + (i % 3) * 40
		var debris_y = nest_y - 20 + (i / 3) * 20
		var debris_size = randf_range(8.0, 15.0)
		scene_canvas.draw_circle(Vector2(debris_x, debris_y), debris_size, nest_color)
	
	# Cleared area indicator (lighter ground)
	var cleared_color = Color(0.15, 0.18, 0.12, 0.5)
	scene_canvas.draw_circle(Vector2(center_x, nest_y), 60.0, cleared_color)
	
	# Safety indicator (green checkmark or cleared marker)
	var safety_color = Color(0.2, 1.0, 0.3)
	scene_canvas.draw_rect(Rect2(center_x - 15, nest_y + 40, 30, 6), safety_color)


func _draw_generic_mission_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Fallback generic mission complete scene
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Generic equipment/console
	var equip_width = 120.0
	var equip_height = 70.0
	scene_canvas.draw_rect(Rect2(center_x - equip_width/2, center_y - equip_height/2, equip_width, equip_height), Color(0.25, 0.3, 0.35))
	
	# Success indicator
	var success_color = palette.accent
	success_color.a = 0.8
	scene_canvas.draw_circle(Vector2(center_x, center_y), 30.0, success_color)

#endregion


func _draw_station_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Floating debris and lights
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_asteroid_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Dust particles
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_planet_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Bioluminescent particles
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)

#endregion
