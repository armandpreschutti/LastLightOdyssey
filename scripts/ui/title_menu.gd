extends Control
## Title Menu - Main menu for Last Light Odyssey
## Features animated starfield background and game entry points

signal start_game_pressed

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/TitleContainer/SubtitleLabel
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/ButtonContainer/NewGameButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var starfield: Control = $Starfield
@onready var version_label: Label = $VersionLabel

# Starfield particles
var stars: Array[Dictionary] = []
const STAR_COUNT: int = 200
const STAR_SPEED_MIN: float = 20.0
const STAR_SPEED_MAX: float = 100.0

# Title animation
var _title_tween: Tween = null
var _ready_for_input: bool = false


func _ready() -> void:
	_generate_stars()
	_setup_buttons()
	_animate_intro()
	
	# Connect starfield drawing
	starfield.draw.connect(_draw_starfield)


func _process(delta: float) -> void:
	# Update starfield
	for star in stars:
		star.position.x -= star.speed * delta
		if star.position.x < -10:
			star.position.x = get_viewport_rect().size.x + 10
			star.position.y = randf_range(0, get_viewport_rect().size.y)
	
	starfield.queue_redraw()


func _generate_stars() -> void:
	var viewport_size = get_viewport_rect().size
	stars.clear()
	
	for i in range(STAR_COUNT):
		var star = {
			"position": Vector2(
				randf_range(0, viewport_size.x),
				randf_range(0, viewport_size.y)
			),
			"speed": randf_range(STAR_SPEED_MIN, STAR_SPEED_MAX),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0)
		}
		stars.append(star)


func _setup_buttons() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Button hover effects
	new_game_button.mouse_entered.connect(_on_button_hover.bind(new_game_button))
	quit_button.mouse_entered.connect(_on_button_hover.bind(quit_button))


func _animate_intro() -> void:
	# Start with elements invisible
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	new_game_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0
	version_label.modulate.a = 0.0
	
	# Disable buttons during intro
	new_game_button.disabled = true
	quit_button.disabled = true
	
	_title_tween = create_tween()
	_title_tween.set_ease(Tween.EASE_OUT)
	_title_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in title
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 1.5)
	
	# Fade in subtitle
	_title_tween.tween_property(subtitle_label, "modulate:a", 0.7, 1.0)
	
	# Fade in buttons with stagger
	_title_tween.tween_property(new_game_button, "modulate:a", 1.0, 0.5)
	_title_tween.tween_property(quit_button, "modulate:a", 1.0, 0.5)
	
	# Fade in version
	_title_tween.tween_property(version_label, "modulate:a", 0.5, 0.3)
	
	# Enable buttons after animation
	_title_tween.tween_callback(_enable_buttons)


func _enable_buttons() -> void:
	new_game_button.disabled = false
	quit_button.disabled = false
	_ready_for_input = true


func _on_button_hover(button: Button) -> void:
	if not _ready_for_input:
		return
	
	# Subtle scale pulse on hover
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


func _on_new_game_pressed() -> void:
	if not _ready_for_input:
		return
	
	# Fade out and transition to game
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(_start_game)


func _start_game() -> void:
	# Reset game state and load main scene
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_pressed() -> void:
	if not _ready_for_input:
		return
	
	# Fade out then quit
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(get_tree().quit)


## Draw the animated starfield
func _draw_starfield() -> void:
	for star in stars:
		var color = Color(1.0, 0.95, 0.8, star.brightness)
		starfield.draw_circle(star.position, star.size, color)
