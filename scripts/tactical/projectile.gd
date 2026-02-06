extends Line2D
## Projectile/Laser effect for combat
## Draws a beam from shooter to target

signal impact_reached

var _start_pos: Vector2
var _end_pos: Vector2
var _duration: float = 0.25  # Balanced projectile speed
var _elapsed: float = 0.0
var _active: bool = false
var _flash_active: bool = false


func _ready() -> void:
	width = 5.0  # Thicker beam for better visibility
	default_color = Color(1.0, 0.5, 0.1, 1.0)  # Brighter orange laser
	visible = false


func _process(delta: float) -> void:
	if _active:
		_elapsed += delta
		var progress = minf(_elapsed / _duration, 1.0)
		
		# Animate the beam appearing with slight expansion effect
		if progress < 1.0:
			clear_points()
			add_point(_start_pos)
			add_point(_start_pos.lerp(_end_pos, progress))
			# Pulse the beam width during travel
			width = 5.0 + sin(progress * PI) * 2.0
		else:
			# Beam has reached target - create impact flash
			_active = false
			
			# Impact flash effect - widen beam momentarily (balanced timing)
			var tween = create_tween()
			tween.tween_property(self, "width", 12.0, 0.06)
			tween.tween_property(self, "default_color", Color(1.0, 1.0, 0.5, 1.0), 0.06)
			tween.tween_property(self, "width", 3.0, 0.12)
			tween.tween_property(self, "default_color", Color(1.0, 0.5, 0.1, 0.0), 0.12)
			
			impact_reached.emit()
			
			# Fade out after impact
			await tween.finished
			visible = false
			default_color = Color(1.0, 0.5, 0.1, 1.0)  # Reset for next shot


## Fire projectile from start to end position
func fire(start_world_pos: Vector2, end_world_pos: Vector2) -> void:
	_start_pos = start_world_pos
	_end_pos = end_world_pos
	_elapsed = 0.0
	_active = true
	visible = true
	width = 5.0
	default_color = Color(1.0, 0.5, 0.1, 1.0)
	clear_points()
	add_point(_start_pos)
	add_point(_start_pos)
	
	# Muzzle flash effect - brief bright start
	_create_muzzle_flash()


## Create muzzle flash at shooter position
func _create_muzzle_flash() -> void:
	var flash = ColorRect.new()
	flash.size = Vector2(16, 16)
	flash.position = _start_pos - Vector2(8, 8)
	flash.color = Color(1.0, 0.8, 0.3, 1.0)
	get_parent().add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.06).from(Vector2(0.5, 0.5))
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)
