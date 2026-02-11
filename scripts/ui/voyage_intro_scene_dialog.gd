extends BaseSceneDialog
## Voyage Intro Scene Dialog - Displays an Oregon Trail-style scene when starting a new voyage
## Shows a pixel art scene with voyage title, location, and story setup

var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []

# Voyage intro description
const VOYAGE_DESCRIPTION: String = "The last remnants of humanity embark on their final journey. Earth lies in ruins, but hope remains in the distant stars. One thousand souls rest in cryo-sleep, their fate in your hands. New Earth awaits, but the path is treacherous and unknown."

# Color palette for voyage intro (epic, hopeful but somber)
const VOYAGE_PALETTE: Dictionary = {
	"bg": Color(0.02, 0.02, 0.08),
	"accent": Color(0.3, 0.7, 1.0),
	"detail": Color(0.5, 0.9, 1.0),
	"ship": Color(0.3, 0.35, 0.4),
}


func show_scene() -> void:
	# Set voyage description
	var description = VOYAGE_DESCRIPTION
	
	# Generate procedural scene elements
	_generate_scene_elements()
	if scene_canvas:
		scene_canvas.queue_redraw()
	
	# Play voyage intro SFX
	_play_voyage_sfx()
	
	# Load static image
	if ResourceLoader.exists("res://assets/sprites/scenes/voyage_intro.png"):
		var scene_image = find_child("SceneImage", true, false)
		if scene_image:
			scene_image.texture = load("res://assets/sprites/scenes/voyage_intro.png")
			scene_image.visible = true
			if scene_canvas: scene_canvas.visible = false
	
	# Show the scene with text (base class handles typewriter, fade, etc.)
	show_scene_with_text(
		"VOYAGE COMMENCED",
		"DEPARTURE  |  SECTOR 0-000  |  CYCLE 0",
		description
	)


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


## Play voyage intro SFX
func _play_voyage_sfx() -> void:
	var sfx_path = "res://assets/audio/sfx/scenes/voyage_intro_scene/voyage_intro.mp3"
	SFXManager.play_scene_sfx(sfx_path)


## Override base class method to draw scene-specific content
func _draw_scene_content() -> void:
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
