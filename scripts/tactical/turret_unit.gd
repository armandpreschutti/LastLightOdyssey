extends Node2D
## Turret Unit - Auto-firing sentry placed by Tech officer
## Fires at nearest visible enemy each turn, lasts 3 turns

@onready var sprite: Sprite2D = $Sprite
@onready var turns_label: Label = $TurnsLabel

var grid_position: Vector2i = Vector2i.ZERO
var turns_remaining: int = 3
var shoot_range: int = 6
var base_damage: int = 15


func initialize() -> void:
	turns_remaining = 3
	update_visual()


func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos


func get_grid_position() -> Vector2i:
	return grid_position


## Tick down turn timer. Returns false if turret has expired.
func tick_turn() -> bool:
	turns_remaining -= 1
	update_visual()
	return turns_remaining > 0


## Update visual indicators (remaining turns)
func update_visual() -> void:
	if turns_label:
		turns_label.text = str(turns_remaining)
		# Color based on remaining turns
		if turns_remaining <= 1:
			turns_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		elif turns_remaining == 2:
			turns_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
		else:
			turns_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
	# Subtle pulse animation
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 1.0, 1.0, 1.0), 0.2)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
