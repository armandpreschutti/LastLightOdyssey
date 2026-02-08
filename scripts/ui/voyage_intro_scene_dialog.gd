extends Control
## Voyage Intro Scene Dialog - Displays an Oregon Trail-style scene when starting a new voyage
## Shows a pixel art scene with voyage title, location, and story setup

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
var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []

# Voyage intro descriptions (randomly selected)
const VOYAGE_DESCRIPTIONS: Array[String] = [
	"The last remnants of humanity embark on their final journey. Earth lies in ruins, but hope remains in the distant stars. One thousand souls rest in cryo-sleep, their fate in your hands. New Earth awaits, but the path is treacherous and unknown.",
	"With the old world consumed by fire and ash, the great ark ship sets course for salvation. One thousand souls in cryo-sleep, six officers to guide them. The voyage begins.",
	"From the ashes of a dying planet, humanity's last hope launches into the void. One thousand colonists slumber in cryo-pods, their lives depending on every decision you make. The journey to New Earth will test every resource, every choice, every life aboard.",
	"The starship departs the dying Earth, carrying the last of humanity. One thousand cryosleepers dream of a new world as the ship drifts through unknown sectors, past derelict stations and alien worlds. The crew must navigate to a new beginning.",
	"Humanity's final exodus begins. The ship's engines ignite, leaving behind a world that can no longer sustain life. One thousand souls rest in cryo-stasis, their future uncertain. Ahead lies New Earth, but the journey will demand sacrifice.",
]

# Color palette for voyage intro (epic, hopeful but somber)
const VOYAGE_PALETTE: Dictionary = {
	"bg": Color(0.02, 0.02, 0.08),
	"accent": Color(0.3, 0.7, 1.0),
	"detail": Color(0.5, 0.9, 1.0),
	"ship": Color(0.3, 0.35, 0.4),
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scene_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene() -> void:
	# Randomly select a voyage description
	var description = VOYAGE_DESCRIPTIONS[randi() % VOYAGE_DESCRIPTIONS.size()]
	
	# Set title
	title_label.text = "VOYAGE COMMENCED"
	
	# Set location/date flavor text
	location_label.text = "DEPARTURE  |  SECTOR 0-000  |  CYCLE 0"
	
	# Use procedural generation for voyage intro scene
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
	for i in range(100):
		_scene_stars.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.2, 0.8),
		})
	
	# Generate voyage-specific particles (nebula, distant planets, etc.)
	for i in range(8):
		_scene_particles.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(40.0, 120.0),
			"alpha": randf_range(0.05, 0.12),
		})


func _draw_procedural_scene() -> void:
	var canvas_size = scene_canvas.size
	var palette = VOYAGE_PALETTE
	
	# Draw background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), palette.bg)
	
	# Draw stars
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = Color(0.7, 0.8, 0.9, star.brightness)
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw ship silhouette (larger, more prominent for voyage start)
	_draw_ship_silhouette(canvas_size, palette)
	
	# Draw nebula clouds in background
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)
	
	# Draw Earth in background (small, distant, dying)
	_draw_distant_earth(canvas_size, palette)
	
	# Draw New Earth in distance (small, hopeful glow)
	_draw_distant_new_earth(canvas_size, palette)


func _draw_ship_silhouette(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw a larger, more prominent retro spaceship in the center-left area
	var ship_x = canvas_size.x * 0.25
	var ship_y = canvas_size.y * 0.5
	var ship_color = palette.ship
	var detail_color = palette.accent * 0.6
	detail_color.a = 0.9
	
	# Ship body (blocky pixel-art style, larger for voyage intro)
	var px = 5.0  # pixel size for retro look
	
	# Main hull (larger)
	scene_canvas.draw_rect(Rect2(ship_x - 16*px, ship_y - 4*px, 32*px, 8*px), ship_color)
	# Nose
	scene_canvas.draw_rect(Rect2(ship_x + 16*px, ship_y - 3*px, 10*px, 6*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x + 26*px, ship_y - 2*px, 5*px, 4*px), ship_color)
	# Wings (larger)
	scene_canvas.draw_rect(Rect2(ship_x - 8*px, ship_y - 10*px, 16*px, 4*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x - 8*px, ship_y + 6*px, 16*px, 4*px), ship_color)
	# Engine glow (more prominent)
	scene_canvas.draw_rect(Rect2(ship_x - 18*px, ship_y - 3*px, 4*px, 6*px), palette.accent)
	scene_canvas.draw_rect(Rect2(ship_x - 22*px, ship_y - 2*px, 4*px, 4*px), palette.detail)
	# Windows (more visible)
	for i in range(4):
		var win_x = ship_x - 8*px + i * 4*px
		scene_canvas.draw_rect(Rect2(win_x, ship_y - 1*px, 2*px, 2*px), detail_color)


func _draw_distant_earth(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw Earth in the background (left side, small, dim)
	var earth_x = canvas_size.x * 0.1
	var earth_y = canvas_size.y * 0.3
	var earth_radius = 30.0
	
	# Earth (dim, dying)
	var earth_color = Color(0.3, 0.2, 0.15, 0.4)
	scene_canvas.draw_circle(Vector2(earth_x, earth_y), earth_radius, earth_color)
	# Some detail (continents, but faded)
	var detail_color = Color(0.2, 0.15, 0.1, 0.3)
	scene_canvas.draw_circle(Vector2(earth_x - 8, earth_y - 5), 8.0, detail_color)
	scene_canvas.draw_circle(Vector2(earth_x + 10, earth_y + 8), 6.0, detail_color)


func _draw_distant_new_earth(canvas_size: Vector2, palette: Dictionary) -> void:
	# Draw New Earth in the distance (right side, small, hopeful glow)
	var new_earth_x = canvas_size.x * 0.85
	var new_earth_y = canvas_size.y * 0.4
	var new_earth_radius = 25.0
	
	# New Earth (glowing, hopeful)
	var new_earth_color = palette.accent
	new_earth_color.a = 0.6
	scene_canvas.draw_circle(Vector2(new_earth_x, new_earth_y), new_earth_radius, new_earth_color)
	# Glow effect
	var glow_color = palette.detail
	glow_color.a = 0.2
	scene_canvas.draw_circle(Vector2(new_earth_x, new_earth_y), new_earth_radius * 1.5, glow_color)
	# Some surface detail (brighter)
	var surface_color = palette.detail
	surface_color.a = 0.4
	scene_canvas.draw_circle(Vector2(new_earth_x - 5, new_earth_y - 3), 5.0, surface_color)
	scene_canvas.draw_circle(Vector2(new_earth_x + 6, new_earth_y + 4), 4.0, surface_color)

#endregion
