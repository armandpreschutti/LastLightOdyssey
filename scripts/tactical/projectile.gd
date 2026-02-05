extends Line2D
## Projectile/Laser effect for combat
## Draws a beam from shooter to target

signal impact_reached

var _start_pos: Vector2
var _end_pos: Vector2
var _duration: float = 0.2
var _elapsed: float = 0.0
var _active: bool = false


func _ready() -> void:
	width = 3.0
	default_color = Color(1.0, 0.3, 0.0, 1.0)  # Orange laser
	visible = false


func _process(delta: float) -> void:
	if _active:
		_elapsed += delta
		var progress = minf(_elapsed / _duration, 1.0)
		
		# Animate the beam appearing
		if progress < 1.0:
			clear_points()
			add_point(_start_pos)
			add_point(_start_pos.lerp(_end_pos, progress))
		else:
			# Beam has reached target
			_active = false
			impact_reached.emit()
			# Fade out
			await get_tree().create_timer(0.1).timeout
			visible = false


## Fire projectile from start to end position
func fire(start_world_pos: Vector2, end_world_pos: Vector2) -> void:
	_start_pos = start_world_pos
	_end_pos = end_world_pos
	_elapsed = 0.0
	_active = true
	visible = true
	clear_points()
	add_point(_start_pos)
	add_point(_start_pos)
