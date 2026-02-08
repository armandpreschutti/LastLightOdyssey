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
	"sniper": preload("res://assets/sprites/characters/enemy_sniper.png"),
	"elite": preload("res://assets/sprites/characters/enemy_elite.png"),
}

# Enemy type stats
const ENEMY_DATA = {
	"basic": { "max_hp": 50, "max_ap": 2, "move_range": 4, "sight_range": 6, "shoot_range": 8, "damage": 20, "overwatch_range": 0 },
	"heavy": { "max_hp": 80, "max_ap": 3, "move_range": 3, "sight_range": 5, "shoot_range": 6, "damage": 35, "overwatch_range": 0 },
	"sniper": { "max_hp": 40, "max_ap": 2, "move_range": 5, "sight_range": 10, "shoot_range": 12, "damage": 30, "overwatch_range": 5 },
	"elite": { "max_hp": 100, "max_ap": 3, "move_range": 4, "sight_range": 7, "shoot_range": 9, "damage": 40, "overwatch_range": 0 },
}

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var alert_indicator: ColorRect = $AlertIndicator
@onready var half_cover_indicator: Node2D = $HalfCoverIndicator
@onready var full_cover_indicator: Node2D = $FullCoverIndicator
@onready var hit_chance_label: Label = $HitChanceLabel
@onready var target_highlight: Sprite2D = $TargetHighlight

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
var overwatch_range: int = 0  # Automatic overwatch range (0 = disabled)
var grid_position: Vector2i = Vector2i.ZERO

var is_alerted: bool = false
var is_targetable: bool = false  # Whether this enemy can be attacked by current unit
var is_in_precision_mode: bool = false  # Whether precision shot mode is active (can target any visible enemy)

var _moving: bool = false
var _move_path: PackedVector2Array = []
var _move_speed: float = 150.0

# Animation
var _idle_tween: Tween = null
var _targetable_tween: Tween = null
var _attack_tween: Tween = null
var _highlight_tween: Tween = null


func _ready() -> void:
	set_process(false)
	_update_hp_bar()
	_start_idle_animation()
	# Don't start highlight animation yet - it will be controlled by targetability
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
	overwatch_range = data.get("overwatch_range", 0)
	
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
				set_process(false)
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
	set_process(true)

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


## Start pulsing red highlight animation to indicate enemy is a target
func _start_highlight_animation() -> void:
	if not target_highlight:
		return
	
	# Stop any existing highlight animation
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	
	_highlight_tween = create_tween()
	_highlight_tween.set_loops()
	
	# Subtle pulsing effect - fade opacity and slightly scale the shadow
	_highlight_tween.tween_property(target_highlight, "modulate:a", 0.8, 1.0).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.parallel().tween_property(target_highlight, "scale", Vector2(1.15, 1.15), 1.0).set_ease(Tween.EASE_IN_OUT)
	
	# Fade back down
	_highlight_tween.tween_property(target_highlight, "modulate:a", 0.5, 1.0).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.parallel().tween_property(target_highlight, "scale", Vector2(1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)


func is_moving() -> bool:
	return _moving


## Set alert state (when enemy detects player)
func set_alerted(alerted: bool) -> void:
	is_alerted = alerted
	if alerted:
		AudioManager.play_sfx("combat_enemy_alert")
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
	# Use forgiving RNG system (enemies don't get bad luck protection by default)
	var hit = CombatRNG.roll_attack(hit_chance, false, get_instance_id())
	
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
	
	# Update red highlight visibility based on targetability or precision mode
	_update_red_highlight_visibility()
	
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


## Set precision mode state (allows targeting any visible enemy)
func set_precision_mode(active: bool) -> void:
	is_in_precision_mode = active
	_update_red_highlight_visibility()


## Update red highlight visibility based on targetability or precision mode
func _update_red_highlight_visibility() -> void:
	if not target_highlight:
		return
	
	# Show red highlight if enemy is targetable OR precision mode is active (and enemy is visible)
	var should_show = is_targetable or (is_in_precision_mode and visible)
	
	if should_show:
		if not _highlight_tween:
			_start_highlight_animation()
		target_highlight.visible = true
	else:
		if _highlight_tween:
			_highlight_tween.kill()
			_highlight_tween = null
		target_highlight.visible = false


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


#region Attack Animations

## Kill any running attack tween to prevent conflicts
func _kill_attack_tween() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
		_attack_tween = null


## Play the unique attack animation for this enemy type
func play_attack_animation() -> void:
	if not sprite:
		return
	_kill_attack_tween()
	_stop_idle_animation()
	
	match enemy_type:
		"basic": _play_basic_enemy_attack()
		"heavy": _play_heavy_enemy_attack()
		"sniper": _play_sniper_enemy_attack()
		"elite": _play_elite_enemy_attack()
		_:       _play_basic_enemy_attack()


## Basic Enemy - Aggressive snap: forward lurch, red flash, sharp recoil, fast recovery
func _play_basic_enemy_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	var lurch_dir = -recoil_dir  # Lurch toward target (opposite of recoil)
	_attack_tween = create_tween()
	# Quick forward lurch toward target
	_attack_tween.tween_property(sprite, "position:x", lurch_dir * 3.0, 0.03).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.3, 0.2, 1.0), 0.03)
	# Sharp recoil back
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 4.0, 0.04).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.5, 0.3, 1.0), 0.04)
	# Fast recovery
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.10).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.10)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
	_attack_tween.tween_callback(_start_idle_animation)


## Heavy Enemy - Brute force: strong recoil + crouch, orange flash, heavy scale squeeze, slow recovery
func _play_heavy_enemy_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	var rot_dir = 1.0 if not sprite.flip_h else -1.0
	_attack_tween = create_tween()
	# Heavy recoil + crouch + orange flash + scale squeeze
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 5.0, 0.05).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 3.0, 0.05)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.7, 0.2, 1.0), 0.05)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(0.88, 0.88), 0.05)
	_attack_tween.parallel().tween_property(sprite, "rotation", rot_dir * 0.04, 0.05)
	# Bounce back overshoot
	_attack_tween.tween_property(sprite, "scale", Vector2(1.06, 1.06), 0.10)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * -1.0, 0.10)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.3, 0.9, 0.5, 1.0), 0.10)
	# Slow settle to baseline (conveys weight)
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.20).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.20).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.20)
	_attack_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.20)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.20)
	_attack_tween.tween_callback(_start_idle_animation)


## Sniper Enemy - Precise aim: steady stance, blue flash, minimal recoil, quick recovery
func _play_sniper_enemy_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Steady aim - slight pull back
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * -2.0, 0.05).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.4, 0.6, 1.8, 1.0), 0.05)  # Blue flash
	# Precise shot - minimal recoil
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 2.0, 0.04).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.7, 1.5, 1.0), 0.04)
	# Quick recovery - back to steady stance
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.08).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	_attack_tween.tween_callback(_start_idle_animation)


## Elite Enemy - Advanced combat: dual flash (red+blue), strong recoil, tech-enhanced recovery
func _play_elite_enemy_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	var rot_dir = 1.0 if not sprite.flip_h else -1.0
	_attack_tween = create_tween()
	# Tech-enhanced wind-up - purple/cyan flash
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * -3.0, 0.04).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.4, 1.5, 1.0), 0.04)  # Purple flash
	# Powerful shot - strong recoil with tech glow
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 5.0, 0.05).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 2.0, 0.05)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.6, 1.8, 1.0), 0.05)  # Bright purple/cyan
	_attack_tween.parallel().tween_property(sprite, "rotation", rot_dir * 0.03, 0.05)
	# Tech-enhanced recovery - smooth return
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.15)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	_attack_tween.tween_callback(_start_idle_animation)

#endregion


#region Death Animations

var _death_tween: Tween = null


## Play the death animation for this enemy type and return when complete
func play_death_animation() -> void:
	if not sprite:
		return
	
	# Stop all other animations
	_stop_idle_animation()
	_kill_attack_tween()
	if _targetable_tween:
		_targetable_tween.kill()
		_targetable_tween = null
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	if target_highlight:
		target_highlight.visible = false
	
	# Hide UI elements
	if hp_bar:
		hp_bar.visible = false
	if hp_bar_bg:
		hp_bar_bg.visible = false
	if alert_indicator:
		alert_indicator.visible = false
	if hit_chance_label:
		hit_chance_label.visible = false
	if half_cover_indicator:
		half_cover_indicator.visible = false
	if full_cover_indicator:
		full_cover_indicator.visible = false
	
	match enemy_type:
		"basic": await _play_basic_enemy_death()
		"heavy": await _play_heavy_enemy_death()
		"sniper": await _play_sniper_enemy_death()
		"elite": await _play_elite_enemy_death()
		_:       await _play_basic_enemy_death()


## Basic Enemy Death - Quick collapse with red flash, spin, and fade out
func _play_basic_enemy_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - red flash and jolt
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.2, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -8.0, 0.05).set_ease(Tween.EASE_OUT)
	
	# Collapse downward with rotation and scale
	_death_tween.tween_property(sprite, "position:y", 12.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 1.2, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.6), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.2, 0.1, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished


## Heavy Enemy Death - Slow heavy fall with orange flash, scale down, dramatic collapse
func _play_heavy_enemy_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - orange flash and stagger back
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 0.8, 0.2, 1.0), 0.08)
	_death_tween.parallel().tween_property(sprite, "position:x", 4.0, 0.08).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "position:y", -4.0, 0.08)
	
	# Stagger forward (losing balance)
	_death_tween.tween_property(sprite, "position:x", -6.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_death_tween.parallel().tween_property(sprite, "rotation", -0.15, 0.15)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.5, 0.2, 1.0), 0.15)
	
	# Heavy collapse - fall forward with weight
	_death_tween.tween_property(sprite, "position:y", 16.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 1.5, 0.35).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.7), 0.35)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.3, 0.1, 0.9), 0.35)
	
	# Ground impact - slight bounce and settle
	_death_tween.tween_property(sprite, "position:y", 14.0, 0.1).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.5), 0.1)
	
	# Final fade out
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.3), 0.3)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.3)
	
	await _death_tween.finished


## Sniper Enemy Death - Quick precise collapse with blue flash, minimal drama
func _play_sniper_enemy_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit - blue flash and slight stagger
	_death_tween.tween_property(sprite, "modulate", Color(0.4, 0.6, 2.0, 1.0), 0.04)
	_death_tween.parallel().tween_property(sprite, "position:y", -6.0, 0.04).set_ease(Tween.EASE_OUT)
	
	# Quick collapse - efficient fall
	_death_tween.tween_property(sprite, "position:y", 10.0, 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 0.8, 0.20).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 0.65), 0.20)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.3, 0.4, 0.8, 0.7), 0.20)
	
	# Fade out
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 0.4), 0.15)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.15)
	
	await _death_tween.finished


## Elite Enemy Death - Dramatic tech-enhanced death with purple/cyan flash, powerful collapse
func _play_elite_enemy_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit - bright purple/cyan flash and stagger
	_death_tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 2.0, 1.0), 0.06)
	_death_tween.parallel().tween_property(sprite, "position:x", 5.0, 0.06).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "position:y", -5.0, 0.06)
	
	# Stagger back - losing balance
	_death_tween.tween_property(sprite, "position:x", -7.0, 0.12).set_ease(Tween.EASE_IN_OUT)
	_death_tween.parallel().tween_property(sprite, "rotation", -0.12, 0.12)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.4, 1.5, 1.0), 0.12)
	
	# Powerful collapse - tech-enhanced fall
	_death_tween.tween_property(sprite, "position:y", 18.0, 0.30).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 1.3, 0.30).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.75), 0.30)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.3, 0.9, 0.85), 0.30)
	
	# Ground impact - tech spark effect
	_death_tween.tween_property(sprite, "position:y", 16.0, 0.08).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.55), 0.08)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.9, 0.5, 1.2, 0.7), 0.08)  # Brief tech glow
	
	# Final fade out
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 0.35), 0.25)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.25)
	
	await _death_tween.finished

#endregion
