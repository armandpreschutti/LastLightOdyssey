extends Control
## Enemy Elimination Scene Dialog - Displays a scene when all enemy units are eliminated
## Shows cleared battlefield scene, pausing tactical gameplay

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


func show_scene(biome_type: int, alive_officers: Array[String]) -> void:
	_current_biome = biome_type as BiomeConfig.BiomeType
	
	var biome_name = BiomeConfig.get_biome_name(_current_biome)
	
	# Set title
	title_label.text = "ALL HOSTILES ELIMINATED"
	
	# Set location/date flavor text
	location_label.text = "%s  |  SECTOR %d-%d  |  CYCLE %d" % [
		biome_name.to_upper(),
		randi_range(1, 9),
		randi_range(100, 999),
		GameState.current_node_index + 1
	]
	
	# Use procedural generation for mission scene
	scene_image.visible = false
	scene_canvas.visible = true
	_generate_scene_elements()
	scene_canvas.queue_redraw()
	
	# Build description
	var description = "All hostiles eliminated. Extraction is now available."
	
	# Start typewriter effect for description
	_current_desc = description
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
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
	_typewriter_tween.tween_interval(0.03)
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
	scene_dismissed.emit()


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
	
	# Generate biome-specific particles (defeated enemy debris)
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			# Station - destroyed enemy equipment and sparks
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 6.0),
					"alpha": randf_range(0.3, 0.7),
				})
		BiomeConfig.BiomeType.ASTEROID:
			# Asteroid - enemy remains and dust
			for i in range(30):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 5.0),
					"alpha": randf_range(0.2, 0.6),
				})
		BiomeConfig.BiomeType.PLANET:
			# Planet - alien remains and bioluminescent particles
			for i in range(35):
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
	
	# Draw cleared battlefield scene
	_draw_cleared_battlefield_scene(canvas_size, palette)
	
	# Draw biome-specific effects
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_effects(canvas_size, palette)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_effects(canvas_size, palette)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_effects(canvas_size, palette)


func _draw_cleared_battlefield_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw a cleared battlefield with defeated enemies and extraction zone
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Draw defeated enemy remains (scattered debris)
	var debris_color = Color(0.2, 0.15, 0.1)
	for i in range(8):
		var debris_x = center_x - 150 + (i % 4) * 100
		var debris_y = center_y - 50 + (i / 4) * 100
		var debris_size = randf_range(8.0, 18.0)
		scene_canvas.draw_circle(Vector2(debris_x, debris_y), debris_size, debris_color)
		# Add smaller debris around main pieces
		for j in range(3):
			var small_x = debris_x + randf_range(-15, 15)
			var small_y = debris_y + randf_range(-15, 15)
			scene_canvas.draw_circle(Vector2(small_x, small_y), randf_range(3.0, 6.0), debris_color)
	
	# Draw extraction zone indicator (glowing circle/beacon)
	var extraction_color = Color(0.2, 1.0, 0.3, 0.6)  # Green extraction zone
	var extraction_radius = 60.0
	scene_canvas.draw_circle(Vector2(center_x, center_y + 80), extraction_radius, extraction_color)
	
	# Draw extraction beacon (vertical line/antenna)
	var beacon_color = Color(0.3, 1.0, 0.4, 0.9)
	scene_canvas.draw_rect(Rect2(center_x - 3, center_y + 20, 6, 80), beacon_color)
	# Beacon top (glowing)
	scene_canvas.draw_circle(Vector2(center_x, center_y + 20), 8.0, beacon_color)
	
	# Draw extraction signal waves (expanding rings)
	for i in range(3):
		var wave_radius = extraction_radius + 10 + i * 20
		var wave_color = Color(0.2, 1.0, 0.3, 0.3 - i * 0.1)
		scene_canvas.draw_arc(Vector2(center_x, center_y + 80), wave_radius, 0, TAU, 32, wave_color, 2.0)
	
	# Draw cleared area indicator (lighter ground around extraction zone)
	var cleared_color = Color(0.15, 0.18, 0.12, 0.4)
	scene_canvas.draw_circle(Vector2(center_x, center_y + 80), extraction_radius + 30, cleared_color)
	
	# Draw victory indicator (checkmark or success marker)
	var victory_color = Color(0.2, 1.0, 0.3)
	scene_canvas.draw_rect(Rect2(center_x - 20, center_y - 100, 40, 8), victory_color)
	scene_canvas.draw_rect(Rect2(center_x - 8, center_y - 92, 16, 30), victory_color)


func _draw_station_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Floating debris and sparks from destroyed enemies
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_asteroid_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Dust particles and enemy remains
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_planet_effects(canvas_size: Vector2, palette: Dictionary) -> void:
	# Bioluminescent particles and alien remains
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)

#endregion
