extends Control
## Base Scene Dialog - Base class for Oregon Trail-style scene dialogs
## Provides common functionality: typewriter text, scanlines, input handling, fade transitions
## Subclasses only need to implement scene-specific rendering
class_name BaseSceneDialog

signal scene_dismissed

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var location_label: Label = $VBoxContainer/LocationLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var scene_canvas: Control = $VBoxContainer/ImageContainer/SceneCanvas
@onready var scanline_overlay: Control = $VBoxContainer/ImageContainer/ScanlineOverlay

var _typewriter_tween: Tween = null
var _prompt_tween: Tween = null
var _current_desc: String = ""
var _current_char: int = 0
var _input_ready: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Allow input when game is paused
	if scanline_overlay:
		scanline_overlay.draw.connect(_draw_scanlines)
	if scene_canvas:
		scene_canvas.draw.connect(_draw_scene_content)


## Show the scene with the given description
## Subclasses should call this and then call _generate_scene_elements()
func show_scene_with_text(title: String, location: String, description: String) -> void:
	# Set text
	if title_label:
		title_label.text = title
	if location_label:
		location_label.text = location
	
	# Setup typewriter
	_current_desc = description
	_current_char = 0
	if description_label:
		description_label.text = ""
	if prompt_label:
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
	_typewriter_tween.tween_interval(0.05)
	_typewriter_tween.finished.connect(_on_typewriter_done)


func _add_desc_char() -> void:
	if _current_char < _current_desc.length():
		if description_label:
			description_label.text = _current_desc.substr(0, _current_char + 1)
		_current_char += 1


func _on_typewriter_done() -> void:
	if description_label:
		description_label.text = _current_desc
	_show_prompt()


func _show_prompt() -> void:
	_input_ready = true
	
	# Pulse the prompt text
	if prompt_label:
		_prompt_tween = create_tween()
		_prompt_tween.set_loops()
		_prompt_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.5)
		_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.is_echo():
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
	if description_label:
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


## Draw CRT-style scanlines over the scene image
func _draw_scanlines() -> void:
	if not scanline_overlay:
		return
	
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


## Virtual method for subclasses to override - draw scene-specific content
func _draw_scene_content() -> void:
	pass  # Override in subclass
