extends Node2D
## Turret Unit - Auto-firing sentry placed by Tech officer
## Fires at nearest visible enemy each turn, lasts 3 turns

@onready var sprite: Sprite2D = $Sprite
@onready var turns_label: Label = $TurnsLabel

var grid_position: Vector2i = Vector2i.ZERO
var turns_remaining: int = 3
var shoot_range: int = 10  # Increased from 6 to 10 for better coverage
var base_damage: int = 45  # Increased from 15 to 45 (3x damage)


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


## Play turret firing animation - cyan rotation pulse matching turret identity
func play_attack_animation() -> void:
	if not sprite:
		return
	var tween = create_tween()
	# Bright cyan flash + quick rotation snap + scale pulse
	tween.tween_property(sprite, "modulate", Color(0.4, 1.8, 1.8, 1.0), 0.04)
	tween.parallel().tween_property(sprite, "rotation", -0.12, 0.04).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.04)
	# Snap back with slight overshoot
	tween.tween_property(sprite, "rotation", 0.03, 0.06).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.2, 1.2, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.95, 0.95), 0.06)
	# Settle to baseline
	tween.tween_property(sprite, "rotation", 0.0, 0.10).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.10)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)