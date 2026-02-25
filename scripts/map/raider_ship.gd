extends Node2D

## Visual representation of the Raider Ship on the voyage map

signal move_complete
signal attack_animation_complete
signal destruction_complete
signal fly_away_complete
signal surrender_depart_complete

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
		var rot_duration = min(duration * 0.5, 1.2)
		tween.tween_property(self, "rotation", current_rot + diff, rot_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Emit signal when movement completes
	tween.chain().tween_callback(func(): move_complete.emit())


#region Outcome Animations

## Raider fires at player – aggressive red flash, lurch, recoil.
## Emits attack_animation_complete when done.
func play_attack_animation() -> void:
	if not sprite:
		attack_animation_complete.emit()
		return

	if animation_player and animation_player.is_playing():
		animation_player.pause()

	var lurch_dir := 1.0
	var recoil_dir := -1.0

	var tween = create_tween()
	tween.tween_property(sprite, "position:x", lurch_dir * 8.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.25, 0.2, 1.0), 0.6)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.6)
	tween.tween_property(sprite, "position:x", recoil_dir * 5.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.4, 0.3, 1.0), 0.8)
	tween.tween_property(sprite, "position:x", 0.0, 1.6).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(sprite, "position:y", 0.0, 1.6)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.6)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 1.6)
	tween.tween_callback(func():
		if animation_player and animation_player.has_animation("pulse"):
			animation_player.play("pulse")
		attack_animation_complete.emit()
	)


## Raider takes damage and is destroyed (player wins).
## Blinding white-orange flash then rapid fade — the visual explosion is
## spawned externally (star_map._spawn_explosion_vfx) in parallel.
## Emits destruction_complete when done.
func play_destruction_sequence() -> void:
	if not sprite:
		destruction_complete.emit()
		return

	if animation_player and animation_player.is_playing():
		animation_player.pause()

	var tween = create_tween()
	# Blinding core flash (0.08s) — ship flares white before being consumed
	tween.tween_property(sprite, "modulate", Color(3.0, 2.2, 0.6, 1.0), 0.08).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08)
	# Rapid fade-out + shrink (0.5s) — sprite consumed by explosion cloud
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.0, 0.0), 0.5).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): destruction_complete.emit())


## Raider rotates away from player then flies off-screen while fading (defeat outcome).
## Emits fly_away_complete when done.
func play_fly_away() -> void:
	if not sprite:
		fly_away_complete.emit()
		return

	if animation_player and animation_player.is_playing():
		animation_player.pause()

	var current_rot = rotation
	var target_rot: float = 0.0  # Face right, away from player on left
	var diff = angle_difference(current_rot, target_rot)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", current_rot + diff, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + Vector2(220.0, 0.0), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): fly_away_complete.emit())


## Raider rotates away and departs peacefully (surrender outcome).
## No color change. Emits surrender_depart_complete when done.
func play_surrender_depart() -> void:
	if not sprite:
		surrender_depart_complete.emit()
		return

	if animation_player and animation_player.is_playing():
		animation_player.pause()

	var current_rot = rotation
	var target_rot: float = 0.0  # Face right, away from player
	var diff = angle_difference(current_rot, target_rot)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", current_rot + diff, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + Vector2(180.0, 0.0), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): surrender_depart_complete.emit())

#endregion
