extends Control
## Mission Scene Dialog - Displays an Oregon Trail-style scene for scavenger missions
## Shows a pixel art scene with mission title, location, and description before beaming down

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

# Biome-specific descriptions
const BIOME_DESCRIPTIONS: Dictionary = {
	BiomeConfig.BiomeType.STATION: "A derelict space station drifts silently. Ancient corridors echo with the promise of salvage and danger.",
	BiomeConfig.BiomeType.ASTEROID: "An abandoned mining operation carved into a massive asteroid. Dark tunnels hide both resources and threats.",
	BiomeConfig.BiomeType.PLANET: "The alien surface stretches before you. Bioluminescent flora glows in the darkness, concealing unknown perils.",
}

# Color palettes for each biome type (Oregon Trail retro sci-fi style)
const BIOME_PALETTES: Dictionary = {
	BiomeConfig.BiomeType.STATION: {"bg": Color(0.02, 0.02, 0.08), "accent": Color(0.3, 0.9, 1.0), "detail": Color(0.5, 0.95, 1.0)},  # Station - cyan/blue
	BiomeConfig.BiomeType.ASTEROID: {"bg": Color(0.05, 0.04, 0.03), "accent": Color(0.5, 0.5, 0.6), "detail": Color(0.7, 0.7, 0.8)},  # Asteroid - brown/gray
	BiomeConfig.BiomeType.PLANET: {"bg": Color(0.08, 0.05, 0.10), "accent": Color(0.8, 0.5, 0.9), "detail": Color(0.95, 0.6, 0.2)},  # Planet - purple/orange
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scene_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene(biome_type: int) -> void:
	_current_biome = biome_type as BiomeConfig.BiomeType
	var biome_name = BiomeConfig.get_biome_name(_current_biome)
	var description = BIOME_DESCRIPTIONS.get(_current_biome, "An unknown location awaits.")
	
	# Set title
	title_label.text = "SCAVENGE MISSION"
	
	# Set location/date flavor text
	location_label.text = "%s  |  SECTOR %d-%d  |  CYCLE %d" % [
		biome_name.to_upper(),
		randi_range(1, 9),
		randi_range(100, 999),
		GameState.current_node_index + 1
	]
	
	# Use procedural generation for mission scenes
	scene_image.visible = false
	scene_canvas.visible = true
	_generate_scene_elements()
	scene_canvas.queue_redraw()
	
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
	
	# Generate biome-specific particles
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			# Station - floating debris and lights
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 6.0),
					"alpha": randf_range(0.3, 0.7),
				})
		BiomeConfig.BiomeType.ASTEROID:
			# Asteroid - rocky chunks and dust
			for i in range(30):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 5.0),
					"alpha": randf_range(0.2, 0.6),
				})
		BiomeConfig.BiomeType.PLANET:
			# Planet - bioluminescent particles
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
	
	# Draw ship silhouette (a simple retro pixel-art spaceship)
	_draw_ship_silhouette(canvas_size, palette)
	
	# Draw biome-specific effects
	match _current_biome:
		BiomeConfig.BiomeType.STATION:
			_draw_station_scene(canvas_size, palette)
		BiomeConfig.BiomeType.ASTEROID:
			_draw_asteroid_scene(canvas_size, palette)
		BiomeConfig.BiomeType.PLANET:
			_draw_planet_scene(canvas_size, palette)


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


func _draw_station_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw station structure on the right side
	var station_x = canvas_size.x * 0.7
	var station_y = canvas_size.y * 0.5
	var px = 3.0
	
	# Station structure (blocky)
	scene_canvas.draw_rect(Rect2(station_x - 20*px, station_y - 30*px, 40*px, 60*px), Color(0.2, 0.25, 0.3))
	# Windows with glow
	for i in range(3):
		var win_y = station_y - 20*px + i * 15*px
		scene_canvas.draw_rect(Rect2(station_x - 5*px, win_y - 3*px, 10*px, 6*px), palette.accent)
	
	# Floating debris
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_asteroid_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw asteroid on the right side
	var asteroid_x = canvas_size.x * 0.75
	var asteroid_y = canvas_size.y * 0.5
	
	# Large asteroid (irregular circle)
	scene_canvas.draw_circle(Vector2(asteroid_x, asteroid_y), 80.0, Color(0.25, 0.2, 0.18))
	scene_canvas.draw_circle(Vector2(asteroid_x + 20, asteroid_y - 15), 40.0, Color(0.2, 0.16, 0.14))
	
	# Mining entrance (dark hole)
	scene_canvas.draw_circle(Vector2(asteroid_x, asteroid_y), 25.0, palette.bg)
	
	# Dust particles
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_planet_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw alien planet surface on the bottom
	var surface_y = canvas_size.y * 0.7
	var px = 4.0
	
	# Ground
	scene_canvas.draw_rect(Rect2(0, surface_y, canvas_size.x, canvas_size.y - surface_y), Color(0.1, 0.15, 0.12))
	
	# Alien structures/plants
	for i in range(5):
		var plant_x = canvas_size.x * (0.2 + i * 0.15)
		var plant_height = randf_range(20.0, 40.0)
		# Mushroom-like structure
		scene_canvas.draw_rect(Rect2(plant_x - 3*px, surface_y - plant_height, 6*px, plant_height), palette.accent)
		scene_canvas.draw_circle(Vector2(plant_x, surface_y - plant_height - 5), 8.0, palette.detail)
	
	# Bioluminescent particles
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.detail
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)

#endregion
