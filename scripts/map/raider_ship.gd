extends Node2D

## Visual representation of the Raider Ship on the voyage map

signal move_complete

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

var current_node_id: String = ""

func _ready() -> void:
	# Ensure the pulsing animation is playing
	if animation_player.has_animation("pulse"):
		animation_player.play("pulse")

const TARGET_ROTATION_SENTINEL: float = -999.0

## Move the ship visually to a new position
## When target_rotation is provided (not TARGET_ROTATION_SENTINEL), use it instead of movement direction
func move_to(target_pos: Vector2, target_node_id: String, speed_mult: float = 1.0, target_rotation: float = TARGET_ROTATION_SENTINEL) -> void:
	current_node_id = target_node_id
	
	var distance = position.distance_to(target_pos)
	
	# Calculate duration based on distance, minimum 0.5s, max 2.0s
	# Base speed is roughly 600 pixels per second
	var duration = clamp(distance / (600.0 * speed_mult), 0.5, 2.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Position tween
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Rotation: use override if provided, else face movement direction
	var target_rot: float
	if target_rotation != TARGET_ROTATION_SENTINEL:
		target_rot = target_rotation
	elif distance > 1.0:
		var direction = (target_pos - position).normalized()
		target_rot = direction.angle()
	else:
		target_rot = rotation  # No movement, keep current
	
	if distance > 1.0 or target_rotation != TARGET_ROTATION_SENTINEL:
		var current_rot = rotation
		var diff = angle_difference(current_rot, target_rot)
		var rot_duration = min(duration * 0.5, 0.4)
		tween.tween_property(self, "rotation", current_rot + diff, rot_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Emit signal when movement completes
	tween.chain().tween_callback(func(): move_complete.emit())
