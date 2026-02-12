extends Control
## Game Over Scene Dialog - Displays dramatic scenes when the game ends
## Shows procedural pixel-art scenes for each game over reason

signal scene_dismissed

@onready var scene_canvas: Control = $VBoxContainer/ImageContainer/SceneCanvas
@onready var scene_image: TextureRect = $VBoxContainer/ImageContainer/SceneImage
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
var _current_reason: String = ""
var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []
var _scene_debris: Array[Dictionary] = []

# Scene descriptions for each game over reason
const SCENE_DESCRIPTIONS: Dictionary = {
	"colonists_depleted": "The last cryosleeper has failed. All one thousand souls, lost to the void. The ship drifts silently through space, a tomb carrying the remains of humanity's last hope. The mission has failed. Extinction is complete.",
	"ship_destroyed": "Critical systems failure. Hull breach detected. The ship tears apart under the strain, metal groaning and failing. Explosions rip through the vessel. All hands lost. The void claims another victim.",
	"captain_died": "The Captain has fallen. Without leadership, the crew cannot continue. The ship drifts aimlessly, its mission abandoned. The chain of command is broken. Humanity's last hope fades into the darkness.",
}

# Scene titles for each game over reason
const SCENE_TITLES: Dictionary = {
	"colonists_depleted": "EXTINCTION",
	"ship_destroyed": "CATASTROPHIC FAILURE",
	"captain_died": "LEADERSHIP LOST",
}

# Color palettes for each game over reason
const REASON_PALETTES: Dictionary = {
	"colonists_depleted": {
		"bg": Color(0.01, 0.0, 0.02),
		"accent": Color(0.3, 0.1, 0.2),
		"detail": Color(0.5, 0.15, 0.25),
		"warning": Color(0.8, 0.2, 0.3),
		"void": Color(0.0, 0.0, 0.05),
		"pod": Color(0.05, 0.08, 0.1),
		"pod_dark": Color(0.02, 0.03, 0.04),
	},
	"ship_destroyed": {
		"bg": Color(0.02, 0.0, 0.0),
		"accent": Color(0.8, 0.2, 0.1),
		"detail": Color(1.0, 0.4, 0.2),
		"warning": Color(1.0, 0.6, 0.3),
		"explosion": Color(1.0, 0.8, 0.4),
		"debris": Color(0.3, 0.3, 0.3),
		"void": Color(0.0, 0.0, 0.05),
	},
	"captain_died": {
		"bg": Color(0.01, 0.01, 0.03),
		"accent": Color(0.2, 0.25, 0.35),
		"detail": Color(0.3, 0.35, 0.45),
		"warning": Color(0.4, 0.5, 0.6),
		"bridge": Color(0.1, 0.12, 0.15),
		"console": Color(0.15, 0.2, 0.25),
		"void": Color(0.0, 0.0, 0.05),
	},
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene(reason: String) -> void:
	_current_reason = reason
	
	# Get scene data
	var title = SCENE_TITLES.get(reason, "GAME OVER")
	var description = SCENE_DESCRIPTIONS.get(reason, "The mission has ended.")
	
	# Set title
	title_label.text = title
	
	# Set location/date flavor text
	location_label.text = "SECTOR %d-%d  |  CYCLE %d  |  FINAL STATUS" % [
		randi_range(1, 9), 
		randi_range(100, 999), 
		GameState.current_node_index + 1
	]
	
	# Load scene image
	var image_name = "game_over_" + reason.replace("colonists_depleted", "colonists").replace("ship_destroyed", "ship").replace("captain_died", "captain")
	var image_path = "res://assets/sprites/scenes/%s.png" % image_name
	
	if ResourceLoader.exists(image_path):
		scene_image.texture = load(image_path)
		scene_image.visible = true
		scene_canvas.visible = false
	else:
		scene_image.visible = false
		scene_canvas.visible = true
		_generate_scene_elements(reason)
		scene_canvas.queue_redraw()
	
	# Start typewriter effect for description
	_current_desc = description
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
	# Play reason-specific SFX
	_play_game_over_sfx(reason)
	
	# Fade in
	modulate.a = 0.0
	visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
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
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_on_dismissed)


func _on_dismissed() -> void:
	visible = false
	if SFXManager:
		SFXManager.stop_scene_sfx()
	scene_dismissed.emit()


## Play reason-specific SFX
func _play_game_over_sfx(reason: String) -> void:
	# Map game over reasons to SFX file names
	var sfx_files: Dictionary = {
		"colonists_depleted": "extinction.mp3",
		"ship_destroyed": "ship_destroyed.mp3",
		"captain_died": "captain_died.mp3",
	}
	
	var sfx_file = sfx_files.get(reason, "extinction.mp3")  # Default to extinction
	
	var sfx_path = "res://assets/audio/sfx/scenes/game_over_scene/" + sfx_file
	SFXManager.play_scene_sfx(sfx_path)


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


#region Procedural Scene Generation

func _generate_scene_elements(reason: String) -> void:
	_scene_stars.clear()
	_scene_particles.clear()
	_scene_debris.clear()
	
	match reason:
		"colonists_depleted":
			# Few stars, very dim
			for i in range(30):
				_scene_stars.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 2.0),
					"brightness": randf_range(0.1, 0.3),
				})
		"ship_destroyed":
			# Stars with explosion particles
			for i in range(80):
				_scene_stars.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 3.0),
					"brightness": randf_range(0.2, 0.6),
				})
			# Explosion particles
			for i in range(40):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 8.0),
					"alpha": randf_range(0.4, 1.0),
					"type": "explosion",
				})
			# Ship debris
			for i in range(20):
				_scene_debris.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(3.0, 12.0),
					"rotation": randf() * TAU,
				})
		"captain_died":
			# Moderate stars
			for i in range(60):
				_scene_stars.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 2.5),
					"brightness": randf_range(0.2, 0.5),
				})


func _draw_procedural_scene() -> void:
	var canvas_size = scene_canvas.size
	var palette = REASON_PALETTES.get(_current_reason, REASON_PALETTES["colonists_depleted"])
	
	# Draw background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), palette.bg)
	
	# Draw stars
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = Color(0.7, 0.8, 0.9, star.brightness)
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw reason-specific scene
	match _current_reason:
		"colonists_depleted":
			_draw_colonists_depleted_scene(canvas_size, palette)
		"ship_destroyed":
			_draw_ship_destroyed_scene(canvas_size, palette)
		"captain_died":
			_draw_captain_died_scene(canvas_size, palette)


func _draw_colonists_depleted_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	var px = 4.0
	var floor_y = canvas_size.y * 0.7
	
	# Floor
	scene_canvas.draw_rect(Rect2(0, floor_y, canvas_size.x, canvas_size.y - floor_y), Color(0.05, 0.06, 0.08))
	
	# Empty cryo pods (all dark)
	var total_pods = 10
	for i in range(total_pods):
		var pod_x = canvas_size.x * (0.05 + i * 0.09)
		
		# Pod body (all dark/inactive)
		scene_canvas.draw_rect(Rect2(pod_x - 6*px, floor_y - 14*px, 12*px, 14*px), palette.pod_dark)
		
		# Pod window (dark)
		var window_color = Color(0.02, 0.03, 0.04, 0.2)
		scene_canvas.draw_rect(Rect2(pod_x - 4*px, floor_y - 12*px, 8*px, 8*px), window_color)
		
		# Status light (off)
		scene_canvas.draw_rect(Rect2(pod_x - 1*px, floor_y - 14*px, 2*px, 2*px), Color(0.1, 0.05, 0.05))
	
	# Memorial plaque in center
	var memorial_x = canvas_size.x * 0.5
	var memorial_y = canvas_size.y * 0.3
	var memorial_color = palette.accent
	memorial_color.a = 0.4
	scene_canvas.draw_rect(Rect2(memorial_x - 40*px, memorial_y - 20*px, 80*px, 40*px), memorial_color)
	# Cross symbol
	scene_canvas.draw_rect(Rect2(memorial_x - 2*px, memorial_y - 15*px, 4*px, 30*px), palette.detail)
	scene_canvas.draw_rect(Rect2(memorial_x - 10*px, memorial_y - 2*px, 20*px, 4*px), palette.detail)
	
	# Dark void overlay
	var void_overlay = palette.void
	void_overlay.a = 0.6
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), void_overlay)


func _draw_ship_destroyed_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	var px = 4.0
	var center_x = canvas_size.x * 0.5
	var center_y = canvas_size.y * 0.5
	
	# Main explosion in center
	var explosion_radius = canvas_size.x * 0.15
	for i in range(5):
		var radius = explosion_radius + i * 8
		var alpha = 0.3 - i * 0.05
		var color = palette.explosion
		color.a = alpha
		scene_canvas.draw_circle(Vector2(center_x, center_y), radius, color)
	
	# Ship debris scattered
	for debris in _scene_debris:
		var pos = Vector2(debris.pos.x * canvas_size.x, debris.pos.y * canvas_size.y)
		var size = debris.size
		var color = palette.debris
		# Draw rotated rectangle for debris
		var points = PackedVector2Array()
		points.append(pos + Vector2(-size*0.5, -size*0.5).rotated(debris.rotation))
		points.append(pos + Vector2(size*0.5, -size*0.5).rotated(debris.rotation))
		points.append(pos + Vector2(size*0.5, size*0.5).rotated(debris.rotation))
		points.append(pos + Vector2(-size*0.5, size*0.5).rotated(debris.rotation))
		scene_canvas.draw_colored_polygon(points, color)
	
	# Explosion particles
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.warning
		color.a = particle.alpha
		scene_canvas.draw_circle(pos, particle.size, color)
		# Glow
		var glow = palette.explosion
		glow.a = particle.alpha * 0.3
		scene_canvas.draw_circle(pos, particle.size * 2.0, glow)
	
	# Ship fragments (remnants of the ship)
	var fragment_color = palette.detail
	for i in range(8):
		var angle = (i / 8.0) * TAU
		var dist = explosion_radius * 1.5
		var frag_pos = Vector2(center_x, center_y) + Vector2(cos(angle), sin(angle)) * dist
		var frag_size = randf_range(8, 16)
		scene_canvas.draw_rect(Rect2(frag_pos - Vector2(frag_size*0.5, frag_size*0.5), Vector2(frag_size, frag_size)), fragment_color)


func _draw_captain_died_scene(canvas_size: Vector2, palette: Dictionary) -> void:
	var px = 4.0
	var floor_y = canvas_size.y * 0.75
	
	# Bridge floor
	scene_canvas.draw_rect(Rect2(0, floor_y, canvas_size.x, canvas_size.y - floor_y), Color(0.08, 0.1, 0.12))
	
	# Bridge console (large panel at back)
	var console_y = canvas_size.y * 0.4
	var console_height = canvas_size.y * 0.35
	scene_canvas.draw_rect(Rect2(0, console_y, canvas_size.x, console_height), palette.console)
	
	# Console screens (all dark/offline)
	for i in range(6):
		var screen_x = canvas_size.x * (0.1 + i * 0.15)
		var screen_y = console_y + 20*px
		scene_canvas.draw_rect(Rect2(screen_x - 15*px, screen_y, 30*px, 20*px), Color(0.05, 0.05, 0.08))
		# Offline indicator (dim red)
		scene_canvas.draw_rect(Rect2(screen_x - 2*px, screen_y + 8*px, 4*px, 4*px), Color(0.3, 0.1, 0.1))
	
	# Empty command chair (center, slightly forward)
	var chair_x = canvas_size.x * 0.5
	var chair_y = floor_y - 30*px
	# Chair base
	scene_canvas.draw_rect(Rect2(chair_x - 8*px, chair_y, 16*px, 8*px), palette.bridge)
	# Chair back
	scene_canvas.draw_rect(Rect2(chair_x - 8*px, chair_y - 12*px, 16*px, 12*px), palette.bridge)
	# Empty seat (darker)
	scene_canvas.draw_rect(Rect2(chair_x - 6*px, chair_y - 2*px, 12*px, 6*px), Color(0.05, 0.06, 0.08))
	
	# Ship drifting (subtle motion lines)
	var drift_color = palette.accent
	drift_color.a = 0.2
	for i in range(5):
		var line_x = canvas_size.x * (0.1 + i * 0.2)
		var line_y = canvas_size.y * 0.2
		scene_canvas.draw_line(
			Vector2(line_x, line_y),
			Vector2(line_x + 20*px, line_y + 10*px),
			drift_color,
			2.0
		)
	
	# Somber void overlay
	var void_overlay = palette.void
	void_overlay.a = 0.4
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), void_overlay)

#endregion
