extends Node2D
## Officer Unit - Controllable unit for tactical missions
## Has AP, movement, and can interact with objects
## Now uses sprite-based graphics with proper character art

signal movement_finished
signal died(officer_key: String)
signal shot_fired(target_position: Vector2i, hit: bool, damage: int)

const OFFICER_DATA: Dictionary = {
	"captain": { "color": Color.YELLOW, "move_range": 5, "sight_range": 6, "max_hp": 100 },
	"scout": { "color": Color.GREEN, "move_range": 6, "sight_range": 8, "max_hp": 80 },
	"tech": { "color": Color.CYAN, "move_range": 4, "sight_range": 5, "max_hp": 70 },
	"medic": { "color": Color.MAGENTA, "move_range": 5, "sight_range": 5, "max_hp": 75 },
	"heavy": { "color": Color.ORANGE_RED, "move_range": 3, "sight_range": 5, "max_hp": 120 },
}

# Sprite textures for different officer types
const OFFICER_SPRITES = {
	"captain": preload("res://assets/sprites/characters/officer_captain.png"),
	"scout": preload("res://assets/sprites/characters/officer_scout.png"),
	"tech": preload("res://assets/sprites/characters/officer_tech.png"),
	"medic": preload("res://assets/sprites/characters/officer_medic.png"),
	"heavy": preload("res://assets/sprites/characters/officer_heavy.png"),
}

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var selection_indicator: Sprite2D = $SelectionIndicator
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var ap_indicator: HBoxContainer = $APIndicator
@onready var overwatch_indicator: ColorRect = $OverwatchIndicator
@onready var half_cover_indicator: Node2D = $HalfCoverIndicator
@onready var full_cover_indicator: Node2D = $FullCoverIndicator

var officer_key: String = ""
var officer_type: String = ""  # scout, tech, medic, captain
var current_ap: int = 2
var max_ap: int = 2
var current_hp: int = 100
var max_hp: int = 100
var move_range: int = 5
var sight_range: int = 5
var shoot_range: int = 10
var base_damage: int = 25
var is_selected: bool = false
var grid_position: Vector2i = Vector2i.ZERO

# Specialist abilities
var overwatch_active: bool = false  # Scout ability

# Ability cooldown system (2-turn cooldown after use)
var ability_cooldown: int = 0
const ABILITY_MAX_COOLDOWN: int = 2

var _moving: bool = false
var _move_path: PackedVector2Array = []
var _move_speed: float = 150.0

# Animation
var _idle_tween: Tween = null


func _ready() -> void:
	selection_indicator.visible = false
	if overwatch_indicator:
		overwatch_indicator.visible = false
	_start_idle_animation()


func initialize(key: String) -> void:
	officer_key = key

	# Determine type from key (e.g., "scout_2" -> "scout")
	if key.contains("_"):
		officer_type = key.split("_")[0]
	else:
		officer_type = key

	var data = OFFICER_DATA.get(key, OFFICER_DATA.get(officer_type, OFFICER_DATA["scout"]))

	# Set sprite texture based on officer type
	if sprite and OFFICER_SPRITES.has(officer_type):
		sprite.texture = OFFICER_SPRITES[officer_type]
	
	move_range = data["move_range"]
	sight_range = data["sight_range"]
	max_hp = data["max_hp"]
	current_hp = max_hp
	
	# Apply specialist bonuses
	_apply_specialist_bonuses()

	_update_hp_bar()
	_update_ap_display()


func _apply_specialist_bonuses() -> void:
	match officer_type:
		"scout":
			# Scout has extended vision for enemy detection
			sight_range += 2
		"tech":
			# Tech can see through walls to detect items
			pass  # Handled in tactical controller
		"medic":
			# Medic can see exact HP values
			pass  # Visual only, handled in UI
		"heavy":
			# Heavy has higher base damage for CHARGE
			base_damage = 35
		"captain":
			# Captain is balanced - no passive bonuses
			pass


func _process(delta: float) -> void:
	if _moving and _move_path.size() > 0:
		var target = _move_path[0]
		var direction = (target - position).normalized()
		position += direction * _move_speed * delta

		if position.distance_to(target) < 5:
			position = target
			_move_path.remove_at(0)

			if _move_path.is_empty():
				_moving = false
				movement_finished.emit()


func move_along_path(path: PackedVector2Array) -> void:
	if path.size() <= 1:
		movement_finished.emit()
		return

	# AStarGrid2D returns corner positions, but we need centered positions
	# Offset each position by half tile size (16 pixels) to center units in tiles
	var centered_path: PackedVector2Array = []
	const TILE_HALF = 16.0  # TILE_SIZE / 2
	
	for pos in path.slice(1):  # Skip the starting position
		centered_path.append(pos + Vector2(TILE_HALF, TILE_HALF))
	
	_move_path = centered_path
	_moving = true
	
	# Stop idle animation while moving
	_stop_idle_animation()


func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected
	
	# Add selection feedback
	if selected:
		# Brief scale pulse on selection
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)


func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos


func get_grid_position() -> Vector2i:
	return grid_position


func use_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		_update_ap_display()
		return true
	return false


func has_ap(amount: int = 1) -> bool:
	return current_ap >= amount


func reset_ap() -> void:
	current_ap = max_ap
	_update_ap_display()


## Reduce ability cooldown by 1 (called at start of each round)
func reduce_cooldown() -> void:
	if ability_cooldown > 0:
		ability_cooldown -= 1


## Check if ability is on cooldown
func is_ability_on_cooldown() -> bool:
	return ability_cooldown > 0


## Get remaining cooldown turns
func get_ability_cooldown() -> int:
	return ability_cooldown


## Start ability cooldown after use
func _start_cooldown() -> void:
	ability_cooldown = ABILITY_MAX_COOLDOWN


func take_damage(amount: int) -> void:
	var actual_damage = amount
	current_hp -= actual_damage
	_update_hp_bar()
	
	# Damage flash effect
	_flash_damage()

	if current_hp <= 0:
		current_hp = 0
		died.emit(officer_key)


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)
	_update_hp_bar()
	
	# Heal flash effect
	_flash_heal()


func _update_hp_bar() -> void:
	var hp_percent = float(current_hp) / float(max_hp)
	hp_bar.scale.x = hp_percent

	if hp_percent > 0.5:
		hp_bar.color = Color.GREEN
	elif hp_percent > 0.25:
		hp_bar.color = Color.YELLOW
	else:
		hp_bar.color = Color.RED


func _update_ap_display() -> void:
	if not ap_indicator:
		return
	
	var ap_nodes = ap_indicator.get_children()
	for i in range(ap_nodes.size()):
		if i < current_ap:
			ap_nodes[i].color = Color(1.0, 0.8, 0.0, 1.0)  # Gold - available
		else:
			ap_nodes[i].color = Color(0.3, 0.3, 0.3, 1.0)  # Dark - used


func _flash_damage() -> void:
	if not sprite:
		return
	var tween = create_tween()
	# Sharp white flash, then red, then back to normal with screen shake effect
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.03)  # White flash
	tween.tween_property(sprite, "modulate", Color(1.8, 0.2, 0.2, 1.0), 0.08)  # Red
	tween.parallel().tween_property(sprite, "position:x", sprite.position.x + 4.0, 0.04)  # Knockback
	tween.tween_property(sprite, "position:x", sprite.position.x - 4.0, 0.04)
	tween.tween_property(sprite, "position:x", sprite.position.x, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _flash_heal() -> void:
	if not sprite:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 1.5, 0.3, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


func _start_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
	
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	
	# Subtle breathing animation
	_idle_tween.tween_property(sprite, "position:y", -1.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "position:y", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null
	if sprite:
		sprite.position.y = 0


func is_moving() -> bool:
	return _moving


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


## Toggle overwatch mode (Scout ability)
func toggle_overwatch() -> bool:
	if officer_type != "scout":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not overwatch_active and not use_ap(1):
		return false
	
	overwatch_active = not overwatch_active
	
	# Start cooldown when activating
	if overwatch_active:
		_start_cooldown()
	
	# Update overwatch indicator
	if overwatch_indicator:
		overwatch_indicator.visible = overwatch_active
	
	return true


## Perform overwatch shot if enemy moves in LOS (guaranteed hit)
func try_overwatch_shot(enemy_pos: Vector2i, _hit_chance: float) -> bool:
	if not overwatch_active:
		return false
	
	# Overwatch shot doesn't cost AP (already paid to activate)
	# Overwatch is a GUARANTEED HIT - always deals damage
	var damage = base_damage
	
	shot_fired.emit(enemy_pos, true, damage)
	overwatch_active = false  # Deactivate after shooting
	
	if overwatch_indicator:
		overwatch_indicator.visible = false
	
	return true  # Always hits


## Check if this unit can detect enemies (Scout passive)
func can_detect_enemies_extended() -> bool:
	return officer_type == "scout"


## Check if this unit can see items through walls (Tech passive)
func can_see_items_through_walls() -> bool:
	return officer_type == "tech"


## Check if this unit can see exact HP (Medic passive)
func can_see_exact_hp() -> bool:
	return officer_type == "medic"


## Use Turret ability (Tech) - place auto-firing sentry on adjacent tile
func use_turret() -> bool:
	if officer_type != "tech":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not use_ap(1):
		return false
	
	_start_cooldown()
	return true


## Use Patch ability (Medic) - heal adjacent ally
func use_patch(target: Node2D) -> bool:
	if officer_type != "medic":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not use_ap(2):
		return false
	
	# Heal for 50% of max HP
	var heal_amount = int(target.max_hp * 0.5)
	target.heal(heal_amount)
	
	_start_cooldown()
	return true


## Use Charge ability (Heavy) - rush enemy within 4 tiles
func use_charge() -> bool:
	if officer_type != "heavy":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not use_ap(1):
		return false
	
	_start_cooldown()
	return true


## Use Execute ability (Captain) - guaranteed kill on adjacent enemy below 50% HP
func use_execute() -> bool:
	if officer_type != "captain":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not use_ap(1):
		return false
	
	_start_cooldown()
	return true


## Check if unit can use their special ability
func can_use_ability(ability_type: String) -> bool:
	if is_ability_on_cooldown():
		return false
	
	match ability_type:
		"overwatch":
			return officer_type == "scout" and has_ap(1)
		"turret":
			return officer_type == "tech" and has_ap(1)
		"patch":
			return officer_type == "medic" and has_ap(2)
		"charge":
			return officer_type == "heavy" and has_ap(1)
		"execute":
			return officer_type == "captain" and has_ap(1)
		_:
			return false


## Face towards a target position (for aiming phase)
func face_towards(target_pos: Vector2i) -> void:
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	var direction = (target_world - position).normalized()
	
	# Flip sprite based on direction
	if sprite and direction.x != 0:
		sprite.flip_h = direction.x < 0


## Update cover indicator visibility based on cover level (0=none, 1=half, 2=full)
func update_cover_indicator(cover_level: int) -> void:
	if half_cover_indicator:
		half_cover_indicator.visible = (cover_level == 1)
	if full_cover_indicator:
		full_cover_indicator.visible = (cover_level == 2)
