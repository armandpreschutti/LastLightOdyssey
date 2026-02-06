extends Node2D
## Base class for interactable objects on the tactical map
## Now uses sprite-based graphics
class_name TacticalInteractable

signal interacted

@onready var sprite: Sprite2D = $Sprite
@onready var highlight: ColorRect = $Highlight

var grid_position: Vector2i = Vector2i.ZERO
var interaction_ap_cost: int = 1
var is_highlighted: bool = false

# Hover tween
var _hover_tween: Tween = null

# Idle animation tweens
var _idle_position_tween: Tween = null
var _idle_scale_tween: Tween = null

# Store original position for idle animation
var _original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if highlight:
		highlight.visible = false
	
	# Store original position for idle animation
	_original_position = position
	
	# Start idle animation
	_start_idle_animation()


func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos


func get_grid_position() -> Vector2i:
	return grid_position


func can_interact() -> bool:
	return true


func interact() -> void:
	# Stop idle animation
	_stop_idle_animation()
	
	# Play collection effect before removing
	_play_collect_effect()
	interacted.emit()
	
	# Delay queue_free to allow effect to play
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func get_interaction_text() -> String:
	return "INTERACT"


func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	if highlight:
		highlight.visible = highlighted
	
	if highlighted:
		_start_hover_effect()
	else:
		_stop_hover_effect()


func _start_hover_effect() -> void:
	if _hover_tween:
		_hover_tween.kill()
	
	_hover_tween = create_tween()
	_hover_tween.set_loops()
	_hover_tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.3)
	_hover_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)


func _stop_hover_effect() -> void:
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _start_idle_animation() -> void:
	if _idle_position_tween:
		_idle_position_tween.kill()
	if _idle_scale_tween:
		_idle_scale_tween.kill()
	
	if not sprite:
		return
	
	# Create position floating animation (up and down)
	_idle_position_tween = create_tween()
	_idle_position_tween.set_loops()
	_idle_position_tween.tween_property(self, "position:y", _original_position.y - 2.0, 1.5)
	_idle_position_tween.tween_property(self, "position:y", _original_position.y + 2.0, 1.5)
	_idle_position_tween.tween_property(self, "position:y", _original_position.y, 1.5)
	
	# Create scale pulsing animation (subtle pulse)
	_idle_scale_tween = create_tween()
	_idle_scale_tween.set_loops()
	_idle_scale_tween.tween_property(sprite, "scale", Vector2(0.98, 0.98), 1.5)
	_idle_scale_tween.tween_property(sprite, "scale", Vector2(1.02, 1.02), 1.5)
	_idle_scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 1.5)


func _stop_idle_animation() -> void:
	if _idle_position_tween:
		_idle_position_tween.kill()
		_idle_position_tween = null
	if _idle_scale_tween:
		_idle_scale_tween.kill()
		_idle_scale_tween = null
	
	# Reset to original position and scale
	if sprite:
		sprite.scale = Vector2(1.0, 1.0)
	position = _original_position


func _play_collect_effect() -> void:
	# Scale up and fade out effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
