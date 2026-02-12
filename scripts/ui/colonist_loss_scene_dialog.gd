extends Control
## Colonist Loss Scene Dialog - Displays emotional scenes when colonist count crosses thresholds
## Shows the psychological impact of losing colonists on the ship's commander

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
var _current_threshold: int = 0
var _scene_stars: Array[Dictionary] = []
var _scene_particles: Array[Dictionary] = []

# Scene descriptions for each threshold
const SCENE_DESCRIPTIONS: Dictionary = {
	750: "The reports keep coming in. Two hundred and fifty souls lost. The weight of command grows heavier with each passing cycle. The cryo-bay grows quieter, the ship feels emptier.",
	500: "Half the mission is gone. Five hundred colonists, lost to the void. The commander stares at the reports, the numbers blurring together. Every decision feels like a gamble with lives.",
	250: "Only a quarter remain. Seven hundred and fifty dead. The commander's hands shake as they review the logs. Sleep comes less often. The mission feels like a slow march to extinction.",
	100: "One hundred souls remain. Nine hundred lost. Hope is a distant memory. The commander speaks to empty corridors, making decisions that feel meaningless. The ship is a tomb.",
	0: "The last cryosleeper has failed. All one thousand souls, lost. The commander stands alone on the bridge, watching the stars drift by. Humanity's last hope, extinguished in the void.",
}

# Scene titles for each threshold
const SCENE_TITLES: Dictionary = {
	750: "CASUALTIES MOUNT",
	500: "THE WEIGHT OF COMMAND",
	250: "DESPERATION",
	100: "ALL HOPE LOST",
	0: "EXTINCTION",
}

# Color palettes for each threshold (getting darker/more desperate)
const THRESHOLD_PALETTES: Dictionary = {
	750: {"bg": Color(0.05, 0.05, 0.1), "accent": Color(0.4, 0.6, 0.8), "detail": Color(0.6, 0.7, 0.9), "warning": Color(1.0, 0.5, 0.2)},
	500: {"bg": Color(0.04, 0.04, 0.08), "accent": Color(0.5, 0.4, 0.3), "detail": Color(0.7, 0.5, 0.3), "warning": Color(1.0, 0.4, 0.1)},
	250: {"bg": Color(0.03, 0.02, 0.06), "accent": Color(0.6, 0.3, 0.2), "detail": Color(0.8, 0.4, 0.2), "warning": Color(1.0, 0.3, 0.1)},
	100: {"bg": Color(0.02, 0.01, 0.04), "accent": Color(0.7, 0.2, 0.1), "detail": Color(0.9, 0.3, 0.1), "warning": Color(1.0, 0.2, 0.0)},
	0: {"bg": Color(0.01, 0.0, 0.02), "accent": Color(0.3, 0.1, 0.1), "detail": Color(0.5, 0.1, 0.1), "warning": Color(0.8, 0.1, 0.0)},
}


func _ready() -> void:
	visible = false
	scanline_overlay.draw.connect(_draw_scene_scanlines)
	scene_canvas.draw.connect(_draw_procedural_scene)


func show_scene(threshold: int) -> void:
	_current_threshold = threshold
	
	# Get scene data
	var title = SCENE_TITLES.get(threshold, "MILESTONE REACHED")
	var description = SCENE_DESCRIPTIONS.get(threshold, "")
	
	# Set title
	title_label.text = title
	
	# Set location/date flavor text
	location_label.text = "SECTOR %d-%d  |  CYCLE %d  |  COLONISTS: %d" % [
		randi_range(1, 9), 
		randi_range(100, 999), 
		GameState.current_node_index + 1,
		GameState.colonist_count
	]
	
	# Load scene image
	var image_path = "res://assets/sprites/scenes/loss_%d.png" % threshold
	if ResourceLoader.exists(image_path):
		scene_image.texture = load(image_path)
		scene_image.visible = true
		scene_canvas.visible = false
	else:
		# Fallback to procedural if image missing
		scene_image.visible = false
		scene_canvas.visible = true
		_generate_scene_elements(threshold)
		scene_canvas.queue_redraw()
	
	# Start typewriter effect for description
	_current_desc = description
	_current_char = 0
	description_label.text = ""
	
	# Hide prompt initially
	prompt_label.modulate.a = 0.0
	_input_ready = false
	
	# Play threshold-specific SFX
	_play_milestone_sfx(threshold)
	
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


## Play threshold-specific SFX
func _play_milestone_sfx(threshold: int) -> void:
	# Map thresholds to SFX file names
	var sfx_files: Dictionary = {
		750: "casualties_mount.mp3",
		500: "weight_of_command.mp3",
		250: "desperation.mp3",
		100: "all_hope_lost.mp3",
		0: "extinction.mp3",
	}
	
	var sfx_file = sfx_files.get(threshold, "")
	if sfx_file == "":
		return
	
	var sfx_path = "res://assets/audio/sfx/scenes/colonist_loss_scene/" + sfx_file
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

func _generate_scene_elements(threshold: int) -> void:
	_scene_stars.clear()
	_scene_particles.clear()
	
	# Generate background stars (fewer and dimmer as threshold decreases)
	var star_count = 60 - (threshold / 20)  # Fewer stars as we lose colonists
	for i in range(int(star_count)):
		_scene_stars.append({
			"pos": Vector2(randf(), randf()),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.1, 0.5 - (threshold / 2000.0)),  # Dimmer as threshold decreases
		})
	
	# Generate threshold-specific particles
	match threshold:
		750:  # Warning lights, some pods offline
			for i in range(15):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 6.0),
					"alpha": randf_range(0.3, 0.7),
					"type": "warning",
				})
		500:  # More warning lights, dimmer pods
			for i in range(20):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(2.0, 8.0),
					"alpha": randf_range(0.4, 0.8),
					"type": "warning",
				})
		250:  # Flickering lights, many pods dark
			for i in range(25):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 5.0),
					"alpha": randf_range(0.5, 1.0),
					"type": "flicker",
				})
		100:  # Emergency lighting, most pods dark
			for i in range(30):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(1.0, 4.0),
					"alpha": randf_range(0.6, 1.0),
					"type": "emergency",
				})
		0:  # Darkness, all pods dark
			for i in range(10):
				_scene_particles.append({
					"pos": Vector2(randf(), randf()),
					"size": randf_range(0.5, 2.0),
					"alpha": randf_range(0.2, 0.4),
					"type": "darkness",
				})


func _draw_procedural_scene() -> void:
	var canvas_size = scene_canvas.size
	var palette = THRESHOLD_PALETTES.get(_current_threshold, THRESHOLD_PALETTES[750])
	
	# Draw background
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), palette.bg)
	
	# Draw stars (fewer and dimmer)
	for star in _scene_stars:
		var pos = Vector2(star.pos.x * canvas_size.x, star.pos.y * canvas_size.y)
		var color = Color(0.7, 0.8, 0.9, star.brightness)
		scene_canvas.draw_rect(Rect2(pos, Vector2(star.size, star.size)), color)
	
	# Draw cryo pod interior (main visual element)
	_draw_cryo_pod_interior(canvas_size, palette)
	
	# Draw threshold-specific effects
	match _current_threshold:
		750: _draw_warning_lights(canvas_size, palette)
		500: _draw_dimming_pods(canvas_size, palette)
		250: _draw_flickering_lights(canvas_size, palette)
		100: _draw_emergency_lighting(canvas_size, palette)
		0: _draw_darkness(canvas_size, palette)


func _draw_cryo_pod_interior(canvas_size: Vector2, palette: Dictionary) -> void:
	# Interior scene: cryo pods along the bottom
	var floor_y = canvas_size.y * 0.7
	var px = 4.0
	
	# Floor
	scene_canvas.draw_rect(Rect2(0, floor_y, canvas_size.x, canvas_size.y - floor_y), Color(0.08, 0.1, 0.12))
	
	# Calculate how many pods should be active based on threshold
	var total_pods = 8
	var active_pods = int((float(GameState.colonist_count) / float(GameState.MAX_COLONISTS)) * total_pods)
	
	# Draw cryo pods
	for i in range(total_pods):
		var pod_x = canvas_size.x * (0.1 + i * 0.11)
		var is_active = i < active_pods
		
		# Pod body (darker if inactive)
		var pod_color = Color(0.15, 0.25, 0.35) if is_active else Color(0.05, 0.08, 0.1)
		scene_canvas.draw_rect(Rect2(pod_x - 6*px, floor_y - 14*px, 12*px, 14*px), pod_color)
		
		# Pod window (dimmer if inactive)
		var window_color = Color(0.1, 0.3, 0.5, 0.6) if is_active else Color(0.05, 0.1, 0.15, 0.3)
		scene_canvas.draw_rect(Rect2(pod_x - 4*px, floor_y - 12*px, 8*px, 8*px), window_color)
		
		# Status light
		var light_color: Color
		if is_active:
			light_color = Color(0.3, 0.8, 0.3)  # Green
		else:
			light_color = Color(0.3, 0.1, 0.1)  # Dark red (off)
		scene_canvas.draw_rect(Rect2(pod_x - 1*px, floor_y - 14*px, 2*px, 2*px), light_color)
	
	# Draw commander silhouette (small figure in center)
	var commander_x = canvas_size.x * 0.5
	var commander_y = floor_y - 20*px
	var commander_color = palette.accent
	commander_color.a = 0.6
	# Simple stick figure silhouette
	scene_canvas.draw_rect(Rect2(commander_x - 2*px, commander_y - 8*px, 4*px, 8*px), commander_color)  # Body
	scene_canvas.draw_rect(Rect2(commander_x - 3*px, commander_y - 10*px, 6*px, 2*px), commander_color)  # Head


func _draw_warning_lights(canvas_size: Vector2, palette: Dictionary) -> void:
	# Warning lights flashing
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.warning
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)


func _draw_dimming_pods(canvas_size: Vector2, palette: Dictionary) -> void:
	# More warning lights, some pods dimming
	_draw_warning_lights(canvas_size, palette)
	# Add some dimming effect
	for i in range(3):
		var dim_x = canvas_size.x * (0.2 + i * 0.3)
		var dim_y = canvas_size.y * 0.65
		var dim_color = palette.warning
		dim_color.a = 0.2
		scene_canvas.draw_circle(Vector2(dim_x, dim_y), 15.0, dim_color)


func _draw_flickering_lights(canvas_size: Vector2, palette: Dictionary) -> void:
	# Flickering emergency lights
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.warning
		color.a = particle.alpha * randf_range(0.5, 1.0)  # Flicker effect
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)
		# Add glow
		var glow = palette.warning
		glow.a = particle.alpha * 0.3
		scene_canvas.draw_circle(pos, particle.size * 2.0, glow)


func _draw_emergency_lighting(canvas_size: Vector2, palette: Dictionary) -> void:
	# Sparse emergency lighting
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.warning
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)
		# Dim glow
		var glow = palette.warning
		glow.a = particle.alpha * 0.2
		scene_canvas.draw_circle(pos, particle.size * 1.5, glow)


func _draw_darkness(canvas_size: Vector2, palette: Dictionary) -> void:
	# Almost complete darkness, just a few dim lights
	for particle in _scene_particles:
		var pos = Vector2(particle.pos.x * canvas_size.x, particle.pos.y * canvas_size.y)
		var color = palette.accent
		color.a = particle.alpha
		scene_canvas.draw_rect(Rect2(pos, Vector2(particle.size, particle.size)), color)
	
	# Add dark overlay
	var dark_overlay = Color(0.0, 0.0, 0.0, 0.5)
	scene_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), dark_overlay)

#endregion
