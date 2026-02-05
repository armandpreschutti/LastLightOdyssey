extends Node2D
## Cover Crate - Destructible object that provides cover when intact
## Now uses sprite-based graphics

signal destroyed

var grid_position: Vector2i = Vector2i.ZERO
var current_hp: int = 20
var max_hp: int = 20
var is_destroyed: bool = false

@onready var intact_sprite: Sprite2D = $IntactSprite
@onready var rubble_sprite: Sprite2D = $RubbleSprite
@onready var hp_bar: ColorRect = $HPBar


func _ready() -> void:
	intact_sprite.visible = true
	rubble_sprite.visible = false
	if hp_bar:
		hp_bar.visible = false


func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos


func get_grid_position() -> Vector2i:
	return grid_position


func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	
	current_hp -= amount
	
	# Flash damage effect
	_flash_damage()
	
	# Show HP bar when damaged
	if hp_bar and current_hp < max_hp:
		hp_bar.visible = true
		var hp_percent = float(current_hp) / float(max_hp)
		hp_bar.scale.x = hp_percent
	
	if current_hp <= 0:
		current_hp = 0
		_destroy()


func _flash_damage() -> void:
	if not intact_sprite:
		return
	var tween = create_tween()
	tween.tween_property(intact_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(intact_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _destroy() -> void:
	is_destroyed = true
	
	# Play destruction animation
	var tween = create_tween()
	tween.tween_property(intact_sprite, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(intact_sprite, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		intact_sprite.visible = false
		rubble_sprite.visible = true
		rubble_sprite.modulate.a = 0.0
	)
	
	# Fade in rubble
	var rubble_tween = create_tween()
	rubble_tween.tween_interval(0.2)
	rubble_tween.tween_property(rubble_sprite, "modulate:a", 1.0, 0.15)
	
	if hp_bar:
		hp_bar.visible = false
	
	destroyed.emit()


func provides_cover() -> bool:
	return not is_destroyed


func get_cover_value() -> float:
	return 25.0 if not is_destroyed else 0.0
