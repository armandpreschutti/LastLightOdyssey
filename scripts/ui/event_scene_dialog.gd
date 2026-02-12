extends Control
## Event Scene Dialog - Displays an Oregon Trail-style scene for random events
## Shows a pixel art scene with event title, description, and a prompt to continue

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
var _current_event_id: int = 0
var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []

# Map event IDs to scene image paths
const EVENT_SCENES: Dictionary = {
	1: "res://assets/sprites/events/solar_flare.png",
	2: "res://assets/sprites/events/meteor_shower.png",
	3: "res://assets/sprites/events/disease_outbreak.png",
	4: "res://assets/sprites/events/system_malfunction.png",
	5: "res://assets/sprites/events/pirate_ambush.png",
	6: "res://assets/sprites/events/supply_cache.png",
	7: "res://assets/sprites/events/distress_signal.png",
	8: "res://assets/sprites/events/radiation_storm.png",
	9: "res://assets/sprites/events/cryo_pod_failure.png",
	10: "res://assets/sprites/events/clear_skies.png",
}

# Color palettes for each event type (Oregon Trail retro sci-fi style)
const EVENT_PALETTES: Dictionary = {
	1: {"bg": Color(0.15, 0.03, 0.0), "accent": Color(1.0, 0.6, 0.1), "detail": Color(1.0, 0.9, 0.3)},  # Solar Flare
	2: {"bg": Color(0.02, 0.02, 0.08), "accent": Color(0.5, 0.5, 0.6), "detail": Color(0.8, 0.8, 0.9)},  # Meteor Shower
	3: {"bg": Color(0.05, 0.08, 0.05), "accent": Color(0.3, 0.8, 0.3), "detail": Color(0.6, 1.0, 0.4)},  # Disease
	4: {"bg": Color(0.05, 0.05, 0.1), "accent": Color(1.0, 0.4, 0.1), "detail": Color(0.4, 0.8, 1.0)},   # Malfunction
	5: {"bg": Color(0.08, 0.02, 0.02), "accent": Color(1.0, 0.2, 0.1), "detail": Color(1.0, 0.5, 0.0)},   # Pirates
	6: {"bg": Color(0.02, 0.05, 0.1), "accent": Color(0.4, 0.9, 1.0), "detail": Color(1.0, 0.7, 0.2)},    # Supply Cache
	7: {"bg": Color(0.02, 0.02, 0.08), "accent": Color(0.2, 0.6, 1.0), "detail": Color(0.8, 0.9, 1.0)},   # Distress
	8: {"bg": Color(0.1, 0.05, 0.1), "accent": Color(0.8, 0.3, 1.0), "detail": Color(0.4, 1.0, 0.4)},     # Radiation
	9: {"bg": Color(0.03, 0.06, 0.1), "accent": Color(0.3, 0.7, 1.0), "detail": Color(1.0, 0.3, 0.2)},    # Cryo Failure
	10: {"bg": Color(0.02, 0.02, 0.06), "accent": Color(0.3, 0.5, 0.7), "detail": Color(0.8, 0.9, 1.0)},  # Clear Skies
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scene_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene(event: Dictionary) -> void:
	var event_id = event.get("id", 0)
	var event_name = event.get("name", "UNKNOWN EVENT")
	var description = event.get("description", "")
	_current_event_id = event_id
	
	# Set title
	title_label.text = event_name.to_upper()
	
	# Set location/date flavor text
	location_label.text = "SECTOR %d-%d  |  CYCLE %d" % [randi_range(1, 9), randi_range(100, 999), GameState.current_node_index + 1]
	
	# Load scene image if available, otherwise use procedural generation
	var image_path = EVENT_SCENES.get(event_id, "")
	if image_path != "" and ResourceLoader.exists(image_path):
		scene_image.texture = load(image_path)
		scene_image.visible = true
		scene_canvas.visible = false
	else:
		# Generate procedural scene (retro pixel-art style)
		scene_image.visible = false
		scene_canvas.visible = true
		_generate_scene_elements(event_id)
		scene_canvas.queue_redraw()
	
	# Start typewriter effect for description
	_current_desc = description
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
	# Play event-specific SFX
	_play_event_sfx(event_id)
	
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
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			return
			
		if _input_ready:
			_dismiss()
		else:
			# Skip typewriter
			_skip_typewriter()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
			
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


## Play event-specific SFX
func _play_event_sfx(event_id: int) -> void:
	# Map event IDs to SFX file names
	var sfx_files: Dictionary = {
		1: "solar_flare.mp3",
		2: "meteor_shower.mp3",
		3: "disease_outbreak.mp3",
		4: "system_malfunction.mp3",
		5: "pirate_ambush.mp3",
		6: "space_debris.mp3",
		7: "sensor_ghost.mp3",
		8: "radiation_storm.mp3",
		9: "cryo_failure.mp3",
		10: "clear_skies.mp3",
	}
	
	var sfx_file = sfx_files.get(event_id, "")
	if sfx_file == "":
		return
	
	var sfx_path = "res://assets/audio/sfx/scenes/event_scene/" + sfx_file
	SFXManager.play_scene_sfx(sfx_path)


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

func _generate_scene_elements(event_id: int) -> void:
	_scene_stars.clear()
	_scene_particles.clear()
	
	# Generate background stars
	for i in range(80):
		_scene_stars.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.2, 0.8),
		})
	
	# Generate event-specific particles
	match event_id:
		1:  # Solar Flare - rays from left side
			for i in range(30):
				_scene_particles.append({
					"pos": Vector2(randf_range(0.0, 0.4), randf()),
					"size": randf_range(3.0, 15.0),
					"alpha": randf_range(0.1, 0.5),
				})
		2:  # Meteor Shower - streaks across screen
			for i in range(20):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 8.0),
					"angle": randf_range(-0.3, 0.1),
					"length": randf_range(20.0, 60.0),
				})
		3:  # Disease - floating spores
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 6.0),
					"alpha": randf_range(0.2, 0.7),
				})
		4:  # System Malfunction - sparks
			for i in range(35):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 4.0),
					"alpha": randf_range(0.3, 1.0),
				})
		5:  # Pirate Ambush - explosions
			for i in range(15):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(5.0, 20.0),
					"alpha": randf_range(0.2, 0.6),
				})
		6:  # Supply Cache - glowing objects
			for i in range(10):
				_scene_particles.append({
					"pos": Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7)),
					"size": randf_range(4.0, 10.0),
					"alpha": randf_range(0.4, 0.8),
				})
		7:  # Distress Signal - pulsing waves
			for i in range(8):
				_scene_particles.append({
					"pos": Vector2(0.7, 0.5),
					"size": randf_range(20.0, 80.0),
					"alpha": randf_range(0.05, 0.15),
				})
		8:  # Radiation Storm - waves
			for i in range(20):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(3.0, 12.0),
					"alpha": randf_range(0.15, 0.5),
				})
		9:  # Cryo Pod Failure - ice shards
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 8.0),
					"alpha": randf_range(0.3, 0.8),
				})
		10:  # Clear Skies - peaceful nebula
			for i in range(5):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(40.0, 100.0),
					"alpha": randf_range(0.03, 0.08),
				})


func _draw_procedural_scene() -> void:
	var canvas_size = scene_canvas.size
	var palette = EVENT_PALETTES.get(_current_event_id, EVENT_PALETTES[10])
	
	# Draw background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), palette.bg)
	
	# Draw stars
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = Color(0.7, 0.8, 0.9, star.brightness)
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw ship silhouette (a simple retro pixel-art spaceship)
	_draw_ship_silhouette(canvas_size, palette)
	
	# Draw event-specific effects
	match _current_event_id:
		1: _draw_solar_flare(canvas_size, palette)
		2: _draw_meteor_shower(canvas_size, palette)
		3: _draw_disease_scene(canvas_size, palette)
		4: _draw_malfunction_scene(canvas_size, palette)
		5: _draw_pirate_scene(canvas_size, palette)
		6: _draw_supply_cache_scene(canvas_size, palette)
		7: _draw_distress_scene(canvas_size, palette)
		8: _draw_radiation_scene(canvas_size, palette)
		9: _draw_cryo_failure_scene(canvas_size, palette)
		10: _draw_clear_skies_scene(canvas_size, palette)


func _draw_ship_silhouette(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw a simple retro spaceship in the center-left area
	var ship_x = canvas_size.x * 0.25
	var ship_y = canvas_size.y * 0.5
	var ship_color = Color(0.3, 0.35, 0.4)
	var detail_color = palette.accent * 0.5
	detail_color.a = 0.8
	
	# Ship body (blocky pixel-art style)
	var px = 4.0  # pixel size for retro look
	
	# Main hull
	scene_canvas.draw_rect(Rect2(ship_x - 12*px, ship_y - 3*px, 24*px, 6*px), ship_color)
	# Nose
	scene_canvas.draw_rect(Rect2(ship_x + 12*px, ship_y - 2*px, 8*px, 4*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x + 20*px, ship_y - 1*px, 4*px, 2*px), ship_color)
	# Wings
	scene_canvas.draw_rect(Rect2(ship_x - 6*px, ship_y - 8*px, 12*px, 3*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x - 6*px, ship_y + 5*px, 12*px, 3*px), ship_color)
	# Engine glow
	scene_canvas.draw_rect(Rect2(ship_x - 14*px, ship_y - 2*px, 3*px, 4*px), palette.accent)
	scene_canvas.draw_rect(Rect2(ship_x - 17*px, ship_y - 1*px, 3*px, 2*px), palette.detail)
	# Windows
	scene_canvas.draw_rect(Rect2(ship_x + 8*px, ship_y - 1*px, 2*px, 2*px), detail_color)
	scene_canvas.draw_rect(Rect2(ship_x + 4*px, ship_y - 1*px, 2*px, 2*px), detail_color)
	scene_canvas.draw_rect(Rect2(ship_x, ship_y - 1*px, 2*px, 2*px), detail_color)


func _draw_solar_flare(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw sun on the right side with rays
	var sun_center = Vector2(canvas_size.x * 0.85, canvas_size.y * 0.35)
	scene_canvas.draw_circle(sun_center, 60.0, palette.accent)
	scene_canvas.draw_circle(sun_center, 45.0, palette.detail)
	
	# Flare rays
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var dir = (pos - sun_center).normalized()
		var ray_color = palette.accent
		ray_color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size * 3, particle.size)), ray_color)


func _draw_meteor_shower(canvas_size: Vector2, palette: Dictionary) -> void:
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var end = pos + Vector2(particle.length, particle.length * particle.angle)
		var color = palette.detail
		color.a = 0.6
		scene_canvas.draw_line(pos, end, color, particle.size)
		# Meteor head
		scene_canvas.draw_circle(pos, particle.size * 1.5, palette.accent)


func _draw_disease_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Interior scene - cryo pods
	_draw_cryo_pod_interior(canvas_size)
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)


func _draw_malfunction_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Sparks and warning lights
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent if randf() > 0.5 else palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_pirate_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Enemy ships on the right
	var px = 3.0
	var enemy_positions = [Vector2(0.7, 0.3), Vector2(0.8, 0.6), Vector2(0.65, 0.7)]
	for epos in enemy_positions:
		var ex = epos.x * canvas_size.x
		var ey = epos.y * canvas_size.y
		scene_canvas.draw_rect(Rect2(ex - 6*px, ey - 2*px, 12*px, 4*px), Color(0.6, 0.2, 0.1))
		scene_canvas.draw_rect(Rect2(ex - 8*px, ey - 1*px, 4*px, 2*px), palette.accent)
	
	# Explosions
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)
		var inner = palette.detail
		inner.a = particle.alpha * 0.7
		scene_canvas.draw_circle(pos, particle.size * 0.5, inner)


func _draw_supply_cache_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Floating crate/container
	var cx = canvas_size.x * 0.6
	var cy = canvas_size.y * 0.45
	var px = 4.0
	scene_canvas.draw_rect(Rect2(cx - 8*px, cy - 6*px, 16*px, 12*px), Color(0.3, 0.3, 0.4))
	scene_canvas.draw_rect(Rect2(cx - 7*px, cy - 5*px, 14*px, 10*px), Color(0.2, 0.25, 0.35))
	# Glowing beacon
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)


func _draw_distress_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Signal waves emanating from a beacon
	var beacon_pos = Vector2(canvas_size.x * 0.7, canvas_size.y * 0.5)
	scene_canvas.draw_rect(Rect2(beacon_pos.x - 4, beacon_pos.y - 8, 8, 16), palette.detail)
	
	for particle in _scene_particles:
		var radius = particle.size
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_arc(beacon_pos, radius, 0, TAU, 32, color, 2.0)


func _draw_radiation_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Radiation waves across the screen
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)
		# Add glow
		var glow = palette.detail
		glow.a = particle.alpha * 0.3
		scene_canvas.draw_circle(pos, particle.size * 2.0, glow)


func _draw_cryo_failure_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	_draw_cryo_pod_interior(canvas_size)
	# Ice shards and warning lights
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		# Diamond shapes for ice
		var points = PackedVector2Array([
			pos + Vector2(0, -particle.size),
			pos + Vector2(particle.size * 0.5, 0),
			pos + Vector2(0, particle.size),
			pos + Vector2(-particle.size * 0.5, 0),
		])
		scene_canvas.draw_colored_polygon(points, color)


func _draw_clear_skies_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Peaceful nebula clouds
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)


func _draw_cryo_pod_interior(canvas_size: Vector2) -> void:
	# Simple interior: pods along the bottom
	var floor_y = canvas_size.y * 0.7
	var px = 4.0
	
	# Floor
	scene_canvas.draw_rect(Rect2(0, floor_y, canvas_size.x, canvas_size.y - floor_y), Color(0.1, 0.12, 0.15))
	
	# Cryo pods
	for i in range(5):
		var pod_x = canvas_size.x * (0.15 + i * 0.17)
		var pod_color = Color(0.15, 0.25, 0.35)
		scene_canvas.draw_rect(Rect2(pod_x - 5*px, floor_y - 12*px, 10*px, 12*px), pod_color)
		# Pod window
		scene_canvas.draw_rect(Rect2(pod_x - 3*px, floor_y - 10*px, 6*px, 6*px), Color(0.1, 0.3, 0.5, 0.6))
		# Status light
		var light_color = Color(0.3, 0.8, 0.3) if i != 2 else Color(1.0, 0.2, 0.1)
		scene_canvas.draw_rect(Rect2(pod_x - 1*px, floor_y - 12*px, 2*px, 2*px), light_color)

#endregion
