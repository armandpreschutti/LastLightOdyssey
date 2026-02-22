extends Node2D
## Suppression Effect - Manages continuous visual tracer fire between a shooter and a suppressed target

var _shooter: Node2D
var _target: Node2D
var _timer: float = 0.0
var _fire_rate: float = 0.15 # Time between tracers

func initialize(shooter: Node2D, target: Node2D) -> void:
	_shooter = shooter
	_target = target
	z_index = 10 # Draw over the map
	
	# Initial check
	if not is_instance_valid(_shooter) or not is_instance_valid(_target):
		queue_free()

func _process(delta: float) -> void:
	# Check if target is still valid and has the pin_down effect
	if not is_instance_valid(_target) or not is_instance_valid(_shooter):
		queue_free()
		return
		
	# Assume target has 'has_status_effect' if it can be suppressed (EnemyUnit)
	if _target.has_method("has_status_effect"):
		if not _target.has_status_effect("pin_down"):
			queue_free()
			return
	else:
		# Fallback if target lost its method
		queue_free()
		return
		
	_timer -= delta
	if _timer <= 0.0:
		_fire_tracer()
		_timer = _fire_rate

func _fire_tracer() -> void:
	var tracer = Line2D.new()
	tracer.width = 3.0
	tracer.default_color = Color(1.0, 0.5, 0.1, 0.8) # Orange/yellow tracer
	
	# Add some jitter to the target position for inaccuracy
	var target_pos = _target.position
	var jitter_x = randf_range(-8.0, 8.0)
	var jitter_y = randf_range(-8.0, 8.0)
	target_pos += Vector2(jitter_x, jitter_y)
	
	add_child(tracer)
	
	tracer.add_point(_shooter.position)
	tracer.add_point(_shooter.position)
	
	var tween = create_tween()
	var duration = 0.15 # Fast travel time
	
	# Extend the line to the target
	tween.tween_method(
		func(progress: float):
			tracer.set_point_position(1, _shooter.position.lerp(target_pos, progress)),
		0.0, 1.0, duration
	)
	
	# Retract the tail of the line (so it's a moving bullet, not a solid beam)
	tween.parallel().tween_method(
		func(progress: float):
			# Delay the tail slightly so it forms a short line
			var tail_progress = maxf(0.0, (progress - 0.3) / 0.7)
			tracer.set_point_position(0, _shooter.position.lerp(target_pos, tail_progress)),
		0.0, 1.0, duration
	)
	
	# Fade out on impact
	tween.tween_property(tracer, "modulate:a", 0.0, 0.05)
	tween.tween_callback(tracer.queue_free)
	
	# Muzzle flash at shooter (tiny)
	var flash = ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.position = _shooter.position - Vector2(3, 3)
	flash.color = Color(1.0, 0.8, 0.3, 0.6)
	add_child(flash)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.05)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.05)
	flash_tween.tween_callback(flash.queue_free)
