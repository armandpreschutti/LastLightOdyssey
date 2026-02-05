extends Node2D
## Enemy Unit - Hostile unit for tactical missions
## Has HP, AP, movement, and shooting capabilities
## Now uses sprite-based graphics with proper enemy art

signal movement_finished
signal died
signal shot_fired(target_position: Vector2i, hit: bool, damage: int)

# Enemy type sprites
const ENEMY_SPRITES = {
	"basic": preload("res://assets/sprites/characters/enemy_basic.png"),
	"heavy": preload("res://assets/sprites/characters/enemy_heavy.png"),
}

# Enemy type stats
const ENEMY_DATA = {
	"basic": { "max_hp": 50, "max_ap": 2, "move_range": 4, "sight_range": 6, "shoot_range": 8, "damage": 20 },
	"heavy": { "max_hp": 80, "max_ap": 3, "move_range": 3, "sight_range": 5, "shoot_range": 6, "damage": 35 },
}

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var alert_indicator: ColorRect = $AlertIndicator
@onready var half_cover_indicator: Node2D = $HalfCoverIndicator
@onready var full_cover_indicator: Node2D = $FullCoverIndicator
@onready var hit_chance_label: Label = $HitChanceLabel

var enemy_id: int = 0
var enemy_type: String = "basic"
var current_ap: int = 2
var max_ap: int = 2
var current_hp: int = 50
var max_hp: int = 50
var move_range: int = 4
var sight_range: int = 6
var shoot_range: int = 8
var base_damage: int = 20
var grid_position: Vector2i = Vector2i.ZERO

var is_alerted: bool = false
var is_targetable: bool = false  # Whether this enemy can be attacked by current unit

var _moving: bool = false
var _move_path: PackedVector2Array = []
var _move_speed: float = 150.0

# Animation
var _idle_tween: Tween = null
var _targetable_tween: Tween = null


func _ready() -> void:
	_update_hp_bar()
	_start_idle_animation()
	if alert_indicator:
		alert_indicator.visible = false


func initialize(id: int, type: String = "basic") -> void:
	enemy_id = id
	enemy_type = type
	
	# Set sprite based on enemy type
	if sprite and ENEMY_SPRITES.has(type):
		sprite.texture = ENEMY_SPRITES[type]
	
	# Apply type-based stats
	var data = ENEMY_DATA.get(type, ENEMY_DATA["basic"])
	max_hp = data["max_hp"]
	max_ap = data["max_ap"]
	move_range = data["move_range"]
	sight_range = data["sight_range"]
	shoot_range = data["shoot_range"]
	base_damage = data["damage"]
	
	current_hp = max_hp
	current_ap = max_ap
	_update_hp_bar()


func _process(delta: float) -> void:
	if _moving and _move_path.size() > 0:
		var target = _move_path[0]
		var direction = (target - position).normalized()
		position += direction * _move_speed * delta
		
		# Flip sprite based on movement direction
		if sprite and direction.x != 0:
			sprite.flip_h = direction.x < 0

		if position.distance_to(target) < 5:
			position = target
			_move_path.remove_at(0)

			if _move_path.is_empty():
				_moving = false
				_start_idle_animation()
				movement_finished.emit()


func move_along_path(path: PackedVector2Array) -> void:
	if path.size() <= 1:
		movement_finished.emit()
		return

	# Center units in tiles (same as officer units)
	var centered_path: PackedVector2Array = []
	const TILE_HALF = 16.0
	
	for pos in path.slice(1):
		centered_path.append(pos + Vector2(TILE_HALF, TILE_HALF))
	
	_move_path = centered_path
	_moving = true
	
	# Stop idle animation while moving
	_stop_idle_animation()


func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos


func get_grid_position() -> Vector2i:
	return grid_position


func use_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		return true
	return false


func has_ap(amount: int = 1) -> bool:
	return current_ap >= amount


func reset_ap() -> void:
	current_ap = max_ap


func take_damage(amount: int) -> void:
	current_hp -= amount
	_update_hp_bar()
	
	# Damage flash effect
	_flash_damage()

	if current_hp <= 0:
		current_hp = 0
		died.emit()


func _update_hp_bar() -> void:
	var hp_percent = float(current_hp) / float(max_hp)
	hp_bar.scale.x = hp_percent

	if hp_percent > 0.5:
		hp_bar.color = Color.GREEN
	elif hp_percent > 0.25:
		hp_bar.color = Color.YELLOW
	else:
		hp_bar.color = Color.RED


func _flash_damage() -> void:
	if not sprite:
		return
	var tween = create_tween()
	# Sharp white flash, then red, then back to normal with recoil effect
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.03)  # White flash
	tween.tween_property(sprite, "modulate", Color(1.8, 0.2, 0.2, 1.0), 0.08)  # Red
	tween.parallel().tween_property(sprite, "position:x", sprite.position.x + 5.0, 0.04)  # Knockback
	tween.tween_property(sprite, "position:x", sprite.position.x - 5.0, 0.04)
	tween.tween_property(sprite, "position:x", sprite.position.x, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _start_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
	
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	
	# Subtle menacing sway
	_idle_tween.tween_property(sprite, "position:y", -1.5, 0.6).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "position:y", 1.5, 0.6).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null
	if sprite:
		sprite.position.y = 0


func is_moving() -> bool:
	return _moving


## Set alert state (when enemy detects player)
func set_alerted(alerted: bool) -> void:
	is_alerted = alerted
	if alert_indicator:
		alert_indicator.visible = alerted
		
		# Flash alert indicator
		if alerted:
			var tween = create_tween()
			tween.tween_property(alert_indicator, "modulate:a", 0.3, 0.2)
			tween.tween_property(alert_indicator, "modulate:a", 1.0, 0.2)
			tween.set_loops(3)


## Check if a position is within shooting range
func can_shoot_at(target_pos: Vector2i) -> bool:
	var distance = abs(target_pos.x - grid_position.x) + abs(target_pos.y - grid_position.y)
	return distance <= shoot_range and has_ap(1)


## Attempt to shoot at a target position
func shoot_at(target_pos: Vector2i, hit_chance: float, damage: int = -1) -> bool:
	if not use_ap(1):
		return false
	
	var actual_damage = damage if damage > 0 else base_damage
	var roll = randf()
	var hit = roll <= (hit_chance / 100.0)
	
	shot_fired.emit(target_pos, hit, actual_damage if hit else 0)
	return hit


## Face towards a target position (for aiming phase)
func face_towards(target_pos: Vector2i) -> void:
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	var direction = (target_world - position).normalized()
	
	# Flip sprite based on direction
	if sprite and direction.x != 0:
		sprite.flip_h = direction.x < 0


## Set targetable state (highlights enemy when player can attack them)
## hit_chance: -1 means don't show hit chance, otherwise show the percentage
func set_targetable(targetable: bool, hit_chance: float = -1.0) -> void:
	is_targetable = targetable
	
	# Stop any existing targetable animation
	if _targetable_tween:
		_targetable_tween.kill()
		_targetable_tween = null
	
	if targetable:
		_start_targetable_highlight()
		_show_hit_chance(hit_chance)
	else:
		_stop_targetable_highlight()
		_hide_hit_chance()


## Show hit chance label
func _show_hit_chance(hit_chance: float) -> void:
	if not hit_chance_label:
		return
	
	if hit_chance < 0:
		hit_chance_label.visible = false
		return
	
	hit_chance_label.text = "%d%%" % int(hit_chance)
	hit_chance_label.visible = true
	
	# Color based on hit chance
	if hit_chance >= 75:
		hit_chance_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))  # Green - high chance
	elif hit_chance >= 50:
		hit_chance_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # Yellow - medium chance
	else:
		hit_chance_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))  # Red - low chance


## Hide hit chance label
func _hide_hit_chance() -> void:
	if hit_chance_label:
		hit_chance_label.visible = false


## Start pulsing highlight effect for targetable enemies
func _start_targetable_highlight() -> void:
	if not sprite:
		return
	
	_targetable_tween = create_tween()
	_targetable_tween.set_loops()
	
	# Pulsing red/orange glow to indicate enemy can be attacked
	_targetable_tween.tween_property(sprite, "modulate", Color(1.4, 0.6, 0.3, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)
	_targetable_tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.2, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)


## Stop targetable highlight effect
func _stop_targetable_highlight() -> void:
	if not sprite:
		return
	
	# Reset modulate to normal
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


## Update cover indicator visibility based on cover level (0=none, 1=half, 2=full)
func update_cover_indicator(cover_level: int) -> void:
	if half_cover_indicator:
		half_cover_indicator.visible = (cover_level == 1)
	if full_cover_indicator:
		full_cover_indicator.visible = (cover_level == 2)
