extends Control
## New Earth Scene Dialog - Displays an Oregon Trail-style arrival scene when reaching New Earth
## Shows a procedural pixel art scene with the ship approaching the new planet

signal scene_dismissed

@onready var scene_canvas: Control = $VBoxContainer/ImageContainer/SceneCanvas
@onready var scanline_overlay: Control = $VBoxContainer/ImageContainer/ScanlineOverlay
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
var _ending_type: String = ""

# Color palette for New Earth (hopeful green/blue/cyan)
const PALETTE: Dictionary = {
	"bg": Color(0.01, 0.02, 0.05),
	"planet_ocean": Color(0.1, 0.4, 0.7),
	"planet_land": Color(0.2, 0.5, 0.3),
	"planet_cloud": Color(0.8, 0.9, 1.0, 0.4),
	"planet_glow": Color(0.3, 0.6, 0.9, 0.3),
	"star": Color(0.8, 0.9, 1.0),
	"ship": Color(0.3, 0.35, 0.4),
	"engine": Color(0.4, 0.9, 1.0),
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scanlines)
	scene_canvas.draw.connect(_draw_new_earth_scene)


func show_scene(ending_type: String) -> void:
	_ending_type = ending_type
	
	# Set title
	title_label.text = "NEW EARTH"
	
	# Set location text
	location_label.text = "DESTINATION REACHED  |  CYCLE %d" % (GameState.current_node_index + 1)
	
	# Set description based on ending type
	match ending_type:
		"perfect":
			_current_desc = "Against all odds, you have delivered humanity's last hope to their new home. All 1,000 colonists have survived the journey. A golden age awaits."
		"good":
			_current_desc = "The journey was long and costly, but you have reached New Earth. Though many were lost along the way, enough remain to rebuild civilization."
		"bad":
			_current_desc = "You have reached New Earth, but at a terrible cost. Only a handful of colonists remain. Humanity's survival hangs by a thread."
		_:
			_current_desc = "After a long journey through the void, you have reached your destination. A new home awaits the survivors."
	
	# Generate stars
	_generate_stars()
	scene_canvas.queue_redraw()
	
	# Start typewriter effect
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
	# Fade in
	modulate.a = 0.0
	visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_callback(_start_description_typewriter)


func _generate_stars() -> void:
	_scene_stars.clear()
	for i in range(120):
		_scene_stars.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0),
		})


func _start_description_typewriter() -> void:
	_typewriter_tween = create_tween()
	_typewriter_tween.set_loops(_current_desc.length())
	_typewriter_tween.tween_callback(_add_desc_char)
	_typewriter_tween.tween_interval(0.025)
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
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_on_dismissed)


func _on_dismissed() -> void:
	visible = false
	scene_dismissed.emit()


## Draw CRT-style scanlines
func _draw_scanlines() -> void:
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


## Draw the New Earth arrival scene
func _draw_new_earth_scene() -> void:
	var canvas_size = scene_canvas.size
	
	# Background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), PALETTE.bg)
	
	# Stars
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = PALETTE.star
		color.a = star.brightness
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw distant nebula/galaxy
	_draw_nebula(canvas_size)
	
	# Draw New Earth planet (large, on the right side)
	_draw_planet(canvas_size)
	
	# Draw the ship approaching
	_draw_ship(canvas_size)


func _draw_nebula(canvas_size: Vector2) -> void:
	# Subtle nebula clouds in the background
	var nebula_colors = [
		Color(0.2, 0.3, 0.5, 0.05),
		Color(0.3, 0.4, 0.6, 0.04),
		Color(0.1, 0.2, 0.4, 0.06),
	]
	
	for i in range(8):
		var pos = Vector2(
			canvas_size.x * (0.1 + randf() * 0.8),
			canvas_size.y * (0.1 + randf() * 0.8)
		)
		var radius = canvas_size.x * randf_range(0.1, 0.25)
		var color = nebula_colors[i % nebula_colors.size()]
		scene_canvas.draw_circle(pos, radius, color)


func _draw_planet(canvas_size: Vector2) -> void:
	var planet_center = Vector2(canvas_size.x * 0.7, canvas_size.y * 0.45)
	var planet_radius = canvas_size.x * 0.28
	
	# Planet glow (atmosphere)
	var glow_color = PALETTE.planet_glow
	for i in range(5):
		var glow_radius = planet_radius + (5 - i) * 8
		glow_color.a = 0.05 + i * 0.02
		scene_canvas.draw_circle(planet_center, glow_radius, glow_color)
	
	# Planet base (ocean)
	scene_canvas.draw_circle(planet_center, planet_radius, PALETTE.planet_ocean)
	
	# Continents (simplified pixel-art style)
	var px = 6.0  # pixel size
	var land_color = PALETTE.planet_land
	
	# Main continent shapes (blocky for retro feel)
	var continent_offsets = [
		Vector2(-0.15, -0.1), Vector2(-0.1, -0.15), Vector2(-0.05, -0.1),
		Vector2(0.0, -0.05), Vector2(0.05, 0.0), Vector2(0.1, 0.05),
		Vector2(-0.2, 0.1), Vector2(-0.15, 0.15), Vector2(-0.1, 0.1),
		Vector2(0.15, -0.2), Vector2(0.2, -0.15), Vector2(0.15, -0.1),
		Vector2(0.0, 0.15), Vector2(0.05, 0.2), Vector2(-0.05, 0.18),
	]
	
	for offset in continent_offsets:
		var land_pos = planet_center + Vector2(offset.x * planet_radius * 2, offset.y * planet_radius * 2)
		var land_size = randf_range(2, 5) * px
		# Only draw if within planet circle
		if land_pos.distance_to(planet_center) < planet_radius - land_size:
			scene_canvas.draw_rect(Rect2(land_pos, Vector2(land_size, land_size)), land_color)
	
	# Cloud layer
	var cloud_color = PALETTE.planet_cloud
	for i in range(12):
		var angle = randf() * TAU
		var dist = randf_range(0.3, 0.85) * planet_radius
		var cloud_pos = planet_center + Vector2(cos(angle), sin(angle)) * dist
		var cloud_size = randf_range(15, 40)
		if cloud_pos.distance_to(planet_center) < planet_radius - 5:
			scene_canvas.draw_circle(cloud_pos, cloud_size, cloud_color)
	
	# Terminator shadow (day/night line)
	var shadow_offset = planet_radius * 0.3
	var shadow_color = Color(0.0, 0.0, 0.1, 0.4)
	scene_canvas.draw_circle(planet_center + Vector2(shadow_offset, shadow_offset * 0.5), planet_radius * 0.95, shadow_color)


func _draw_ship(canvas_size: Vector2) -> void:
	# Ship approaching from the left
	var ship_x = canvas_size.x * 0.2
	var ship_y = canvas_size.y * 0.55
	var px = 4.0  # pixel size
	var ship_color = PALETTE.ship
	var engine_color = PALETTE.engine
	
	# Main hull (blocky pixel-art style)
	scene_canvas.draw_rect(Rect2(ship_x - 15*px, ship_y - 4*px, 30*px, 8*px), ship_color)
	# Nose
	scene_canvas.draw_rect(Rect2(ship_x + 15*px, ship_y - 3*px, 10*px, 6*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x + 25*px, ship_y - 2*px, 6*px, 4*px), ship_color)
	# Wings
	scene_canvas.draw_rect(Rect2(ship_x - 8*px, ship_y - 10*px, 16*px, 4*px), ship_color)
	scene_canvas.draw_rect(Rect2(ship_x - 8*px, ship_y + 6*px, 16*px, 4*px), ship_color)
	# Engine glow
	scene_canvas.draw_rect(Rect2(ship_x - 18*px, ship_y - 3*px, 4*px, 6*px), engine_color)
	scene_canvas.draw_rect(Rect2(ship_x - 22*px, ship_y - 2*px, 4*px, 4*px), Color(1.0, 1.0, 1.0, 0.8))
	# Engine trail
	for i in range(8):
		var trail_alpha = 0.4 - i * 0.05
		var trail_width = 4 - i * 0.3
		var trail_color = engine_color
		trail_color.a = trail_alpha
		scene_canvas.draw_rect(
			Rect2(ship_x - 26*px - i*6*px, ship_y - trail_width*px * 0.5, 5*px, trail_width*px),
			trail_color
		)
	# Windows
	var window_color = Color(0.4, 0.8, 1.0, 0.8)
	scene_canvas.draw_rect(Rect2(ship_x + 10*px, ship_y - 1*px, 2*px, 2*px), window_color)
	scene_canvas.draw_rect(Rect2(ship_x + 5*px, ship_y - 1*px, 2*px, 2*px), window_color)
	scene_canvas.draw_rect(Rect2(ship_x, ship_y - 1*px, 2*px, 2*px), window_color)
