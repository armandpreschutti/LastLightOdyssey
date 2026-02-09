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
	"sniper": { "color": Color(0.35, 0.35, 0.4), "move_range": 4, "sight_range": 7, "max_hp": 70 },
}

# Sprite textures for different officer types
const OFFICER_SPRITES = {
	"captain": preload("res://assets/sprites/characters/officer_captain.png"),
	"scout": preload("res://assets/sprites/characters/officer_scout.png"),
	"tech": preload("res://assets/sprites/characters/officer_tech.png"),
	"medic": preload("res://assets/sprites/characters/officer_medic.png"),
	"heavy": preload("res://assets/sprites/characters/officer_heavy.png"),
	"sniper": preload("res://assets/sprites/characters/officer_sniper.png"),
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
var officer_type: String = ""  # scout, tech, medic, captain, heavy, sniper
var current_ap: int = 2
var max_ap: int = 2
var current_hp: int = 100
var max_hp: int = 100
var move_range: int = 5
var sight_range: int = 5
var shoot_range: int = 10
var base_damage: int = 25
var critical_hit_chance: float = 0.0  # Critical hit chance as percentage (0-100)
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
var _attack_tween: Tween = null
var _death_tween: Tween = null


func _ready() -> void:
	set_process(false)
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
			# Scout has increased mobility
			move_range += 1
			# Scout has moderate critical hit chance (recon-focused)
			critical_hit_chance = 12.0
		"tech":
			# Tech has extended interaction range and engineering abilities
			# Handled via helper functions
			# Tech has moderate critical hit chance (hybrid support/combat)
			critical_hit_chance = 10.0
		"medic":
			# Medic has enhanced healing and medical intel
			# Handled via helper functions
			# Medic has low critical hit chance (support-focused)
			critical_hit_chance = 5.0
		"heavy":
			# Heavy has higher base damage for heavy weapons
			base_damage = 35
			# Heavy has moderate critical hit chance (crowd control focus)
			critical_hit_chance = 10.0
		"captain":
			# Captain has leadership bonuses and combat effectiveness
			base_damage = 30
			move_range += 1
			# Captain has moderate-high critical hit chance (combat leader)
			critical_hit_chance = 12.0
		"sniper":
			# Sniper has extended sight and shoot range for long-range combat
			sight_range += 2  # 7 base + 2 = 9 total
			shoot_range += 2  # 10 base + 2 = 12 total
			base_damage = 30  # Higher than standard 25
			# Sniper has highest critical hit chance (precision unit)
			critical_hit_chance = 20.0


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
				set_process(false)
				movement_finished.emit()


func move_along_path(path: PackedVector2Array) -> void:
	if path.size() <= 1:
		movement_finished.emit()
		return

	AudioManager.play_sfx("move_step")
	# AStarGrid2D returns corner positions, but we need centered positions
	# Offset each position by half tile size (16 pixels) to center units in tiles
	var centered_path: PackedVector2Array = []
	const TILE_HALF = 16.0  # TILE_SIZE / 2
	
	for pos in path.slice(1):  # Skip the starting position
		centered_path.append(pos + Vector2(TILE_HALF, TILE_HALF))
	
	_move_path = centered_path
	_moving = true
	set_process(true)

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
	AudioManager.play_sfx("combat_damage")
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


## Perform overwatch shot if enemy moves in LOS (guaranteed hit - 100% success)
func try_overwatch_shot(enemy_pos: Vector2i, _hit_chance: float, damage: int = -1) -> bool:
	if not overwatch_active:
		return false
	
	# Overwatch shot doesn't cost AP (already paid to activate)
	# Overwatch is a GUARANTEED HIT - 100% attack success, always deals damage
	var actual_damage = damage if damage > 0 else base_damage
	
	# Always emit as a hit with full damage (100% success rate)
	shot_fired.emit(enemy_pos, true, actual_damage)
	overwatch_active = false  # Deactivate after shooting
	
	if overwatch_indicator:
		overwatch_indicator.visible = false
	
	return true  # Always hits - 100% success


## Check if this unit can detect enemies (Scout passive - fog of war reveal)
func can_detect_enemies_extended() -> bool:
	return officer_type == "scout"


## Check if this unit can see enemy positions even when not in direct LOS (Scout passive)
func can_see_fog_of_war() -> bool:
	return officer_type == "scout"


## Check if this unit can interact with tech objects from extended range (Tech passive)
func can_interact_from_range() -> bool:
	return officer_type == "tech"


## Get interaction range for tech objects (Tech passive - 5 tiles)
func get_interaction_range() -> int:
	if officer_type == "tech":
		return 5
	return 1  # Standard adjacent interaction


## Check if this unit can repair/reinforce cover (Tech passive)
func can_repair_cover() -> bool:
	return officer_type == "tech"


## Get turret damage bonus when Tech is nearby (Tech passive - +25% within 3 tiles)
func get_turret_damage_bonus() -> float:
	if officer_type == "tech":
		return 1.25  # +25% damage multiplier
	return 1.0


## Get range for turret damage bonus (Tech passive - 3 tiles)
func get_turret_bonus_range() -> int:
	if officer_type == "tech":
		return 3
	return 0


## Check if this unit can see enemy intel (Medic passive - max HP and damage taken)
func can_see_enemy_intel() -> bool:
	return officer_type == "medic"


## Get healing bonus multiplier (Medic passive - +25% healing)
func get_healing_bonus() -> float:
	if officer_type == "medic":
		return 1.25  # +25% healing (50% -> 62.5%)
	return 1.0


## Get splash damage percentage (Heavy passive - 50% to adjacent enemies)
func get_splash_damage_percent() -> float:
	if officer_type == "heavy":
		return 0.5  # 50% splash damage
	return 0.0


## Get intimidation aura range (Heavy passive - 2 tiles)
func get_intimidation_aura_range() -> int:
	if officer_type == "heavy":
		return 2
	return 0


## Get intimidation aura accuracy debuff (Heavy passive - -10% accuracy)
func get_intimidation_accuracy_debuff() -> float:
	if officer_type == "heavy":
		return -10.0  # -10% accuracy
	return 0.0


## Get leadership aura range (Captain passive - 2 tiles)
func get_leadership_aura_range() -> int:
	if officer_type == "captain":
		return 2
	return 0


## Get leadership damage bonus (Captain passive - +20 damage)
func get_leadership_damage_bonus() -> int:
	if officer_type == "captain":
		return 20
	return 0


## Get leadership accuracy bonus (Captain passive - +15% accuracy)
func get_leadership_accuracy_bonus() -> float:
	if officer_type == "captain":
		return 15.0  # +15% accuracy
	return 0.0


## Get accuracy bonus (Sniper passive - +15% accuracy)
func get_accuracy_bonus() -> float:
	if officer_type == "sniper":
		return 15.0  # +15% accuracy
	return 0.0


## Check if attacks ignore cover (Sniper passive)
func attacks_ignore_cover() -> bool:
	return officer_type == "sniper"


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
	
	if not use_ap(1):
		return false
	
	# Heal for 50% of max HP (62.5% with Medic's enhanced healing passive)
	var base_heal_percent = 0.5
	var heal_multiplier = get_healing_bonus()  # +25% bonus for Medic
	var heal_amount = int(target.max_hp * base_heal_percent * heal_multiplier)
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


## Use Precision Shot ability (Sniper) - guaranteed hit on any visible enemy for 2x damage
func use_precision_shot() -> bool:
	if officer_type != "sniper":
		return false
	
	if is_ability_on_cooldown():
		return false
	
	if not use_ap(1):
		return false
	
	_start_cooldown()
	return true


## Check if target is valid for Precision Shot (any visible enemy, no distance/cover restrictions)
func can_precision_shot_target(target_pos: Vector2i) -> bool:
	if officer_type != "sniper":
		return false
	# Precision Shot can target any visible enemy regardless of distance or cover
	# Visibility check is handled by the tactical controller
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
			return officer_type == "medic" and has_ap(1)
		"charge":
			return officer_type == "heavy" and has_ap(1)
		"execute":
			return officer_type == "captain" and has_ap(1)
		"precision":
			return officer_type == "sniper" and has_ap(1)
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


#region Attack Animations

## Kill any running attack tween to prevent conflicts
func _kill_attack_tween() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
		_attack_tween = null


## Play the unique attack animation for this officer type
func play_attack_animation() -> void:
	if not sprite:
		return
	_kill_attack_tween()
	_stop_idle_animation()
	
	match officer_type:
		"captain": _play_captain_attack()
		"scout":   _play_scout_attack()
		"tech":    _play_tech_attack()
		"medic":   _play_medic_attack()
		"heavy":   _play_heavy_attack()
		"sniper":  _play_sniper_attack()
		_:         _play_captain_attack()


## Captain - Commanding precision: controlled scale pulse, yellow flash, minimal recoil
func _play_captain_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Forward lean
	_attack_tween.tween_property(sprite, "position:y", -2.0, 0.05).set_ease(Tween.EASE_OUT)
	# Yellow command flash + scale pulse + slight recoil
	_attack_tween.tween_property(sprite, "modulate", Color(1.6, 1.4, 0.4, 1.0), 0.04)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.04)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * 2.0, 0.04)
	# Recover
	_attack_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.12)
	_attack_tween.parallel().tween_property(sprite, "position:x", 0.0, 0.10)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.10)
	_attack_tween.tween_callback(_start_idle_animation)


## Scout - Quick snap-shot: rotation jolt, fast directional kickback, green muzzle glow
func _play_scout_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	var rot_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Snap rotation + kickback + green flash
	_attack_tween.tween_property(sprite, "rotation", rot_dir * -0.1, 0.03).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * 4.0, 0.03)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.6, 0.5, 1.0), 0.03)
	# Quick snap back
	_attack_tween.tween_property(sprite, "rotation", 0.0, 0.08).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:x", 0.0, 0.08)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.08)
	_attack_tween.tween_callback(_start_idle_animation)


## Tech - Energy discharge: weapon raise, cyan pulse, scale expansion, slow recovery
func _play_tech_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Weapon raise + cyan charge-up glow
	_attack_tween.tween_property(sprite, "position:y", -4.0, 0.08).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.5, 1.6, 1.8, 1.0), 0.08)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.12, 1.12), 0.08)
	# Discharge recoil
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 3.0, 0.04)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.3, 1.0, 1.2, 1.0), 0.04)
	# Slow recovery (charging feel)
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.18).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.18)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
	_attack_tween.tween_callback(_start_idle_animation)


## Medic - Reluctant shot: gentle recoil, magenta tint, quick flinch
func _play_medic_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Flinch upward + magenta tint
	_attack_tween.tween_property(sprite, "position:y", 1.0, 0.03)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.6, 1.4, 1.0), 0.03)
	# Gentle recoil
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 2.5, 0.04)
	_attack_tween.parallel().tween_property(sprite, "position:y", -1.0, 0.04)
	# Quick return to baseline
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.10).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.10).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
	_attack_tween.tween_callback(_start_idle_animation)


## Heavy - Heavy ordnance: strong recoil + crouch, orange-red flash, scale squeeze, rotation torque
func _play_heavy_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	var rot_dir = 1.0 if not sprite.flip_h else -1.0
	_attack_tween = create_tween()
	# Strong recoil + crouch + orange-red flash + rotation + scale squeeze
	_attack_tween.tween_property(sprite, "position:x", recoil_dir * 5.0, 0.04).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 2.0, 0.04)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.5, 0.2, 1.0), 0.04)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(0.92, 0.92), 0.04)
	_attack_tween.parallel().tween_property(sprite, "rotation", rot_dir * 0.05, 0.04)
	# Bounce back overshoot
	_attack_tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), 0.08)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * -1.0, 0.08)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.8, 0.5, 1.0), 0.08)
	# Settle to baseline
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.14).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.14)
	_attack_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.14)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)
	_attack_tween.tween_callback(_start_idle_animation)


## Sniper - Precision shot: deliberate aim, scope glint, controlled recoil, professional
func _play_sniper_attack() -> void:
	var recoil_dir = -1.0 if not sprite.flip_h else 1.0
	_attack_tween = create_tween()
	# Phase 1: Settle into position - crouch slightly, darken (focusing)
	_attack_tween.tween_property(sprite, "position:y", 1.5, 0.12).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.7, 0.8, 1.0), 0.12)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 0.96), 0.12)
	# Phase 2: Scope glint - brief bright purple flash (acquiring target)
	_attack_tween.tween_property(sprite, "modulate", Color(0.9, 0.7, 1.4, 1.0), 0.06)
	# Phase 3: Hold breath - slight pause, scale tightens
	_attack_tween.tween_property(sprite, "scale", Vector2(0.98, 0.94), 0.1)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.6, 1.2, 1.0), 0.1)
	# Phase 4: FIRE - sharp white-purple muzzle flash, controlled recoil
	_attack_tween.tween_property(sprite, "modulate", Color(1.8, 1.4, 2.2, 1.0), 0.02)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * 3.0, 0.02)
	_attack_tween.parallel().tween_property(sprite, "position:y", 2.5, 0.02)
	# Phase 5: Absorb recoil - professional recovery
	_attack_tween.tween_property(sprite, "modulate", Color(1.1, 0.9, 1.3, 1.0), 0.06)
	_attack_tween.parallel().tween_property(sprite, "position:x", recoil_dir * 1.0, 0.06)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.02, 1.02), 0.06)
	# Phase 6: Return to ready - smooth and controlled
	_attack_tween.tween_property(sprite, "position:x", 0.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
	_attack_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	_attack_tween.tween_callback(_start_idle_animation)

#endregion


#region Death Animations

## Play the death animation for this officer type and return when complete
func play_death_animation() -> void:
	if not sprite:
		return
	
	# Stop all other animations
	_stop_idle_animation()
	_kill_attack_tween()
	
	# Hide UI elements
	if hp_bar:
		hp_bar.visible = false
	if hp_bar_bg:
		hp_bar_bg.visible = false
	if ap_indicator:
		ap_indicator.visible = false
	if selection_indicator:
		selection_indicator.visible = false
	if overwatch_indicator:
		overwatch_indicator.visible = false
	if half_cover_indicator:
		half_cover_indicator.visible = false
	if full_cover_indicator:
		full_cover_indicator.visible = false
	
	match officer_type:
		"captain": await _play_captain_death()
		"scout":   await _play_scout_death()
		"tech":    await _play_tech_death()
		"medic":   await _play_medic_death()
		"heavy":   await _play_heavy_death()
		"sniper":  await _play_sniper_death()
		_:         await _play_captain_death()


## Captain Death - Dignified fall with yellow flash, controlled collapse
func _play_captain_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - yellow flash and stagger
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 1.8, 0.4, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -6.0, 0.05).set_ease(Tween.EASE_OUT)
	
	# Controlled collapse with rotation
	_death_tween.tween_property(sprite, "position:y", 10.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 0.8, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 0.65), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.9, 0.7, 0.2, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished


## Scout Death - Quick collapse with green flash, agile fall
func _play_scout_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - green flash and jolt
	_death_tween.tween_property(sprite, "modulate", Color(0.4, 2.0, 0.5, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -8.0, 0.05).set_ease(Tween.EASE_OUT)
	
	# Quick collapse with spin
	_death_tween.tween_property(sprite, "position:y", 12.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 1.2, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.6), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.3, 0.8, 0.2, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished


## Tech Death - Energy discharge fade with cyan flash, tech collapse
func _play_tech_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - cyan flash and energy discharge
	_death_tween.tween_property(sprite, "modulate", Color(0.3, 1.6, 2.0, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -7.0, 0.05).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
	
	# Energy fade collapse
	_death_tween.tween_property(sprite, "position:y", 11.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 0.9, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.6), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.2, 0.6, 0.9, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished


## Medic Death - Gentle fall with magenta flash, compassionate collapse
func _play_medic_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - magenta flash and gentle stagger
	_death_tween.tween_property(sprite, "modulate", Color(1.8, 0.5, 1.6, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -6.0, 0.05).set_ease(Tween.EASE_OUT)
	
	# Gentle collapse
	_death_tween.tween_property(sprite, "position:y", 10.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 0.7, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 0.65), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.3, 0.7, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished


## Heavy Death - Slow heavy fall with orange-red flash, dramatic collapse
func _play_heavy_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - orange-red flash and stagger back
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 0.6, 0.2, 1.0), 0.08)
	_death_tween.parallel().tween_property(sprite, "position:x", 4.0, 0.08).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(sprite, "position:y", -4.0, 0.08)
	
	# Stagger forward (losing balance)
	_death_tween.tween_property(sprite, "position:x", -6.0, 0.15).set_ease(Tween.EASE_IN_OUT)
	_death_tween.parallel().tween_property(sprite, "rotation", -0.15, 0.15)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.4, 0.1, 1.0), 0.15)
	
	# Heavy collapse - fall forward with weight
	_death_tween.tween_property(sprite, "position:y", 16.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 1.5, 0.35).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.7), 0.35)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.2, 0.1, 0.9), 0.35)
	
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


## Sniper Death - Professional fall with purple flash, controlled collapse
func _play_sniper_death() -> void:
	_death_tween = create_tween()
	
	# Initial hit reaction - purple flash and controlled stagger
	_death_tween.tween_property(sprite, "modulate", Color(1.6, 0.8, 2.0, 1.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "position:y", -7.0, 0.05).set_ease(Tween.EASE_OUT)
	
	# Controlled collapse with slight rotation
	_death_tween.tween_property(sprite, "position:y", 11.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_death_tween.parallel().tween_property(sprite, "rotation", 0.9, 0.25).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 0.65), 0.25)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.4, 0.9, 0.8), 0.25)
	
	# Fade out and shrink
	_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.3), 0.2)
	
	# Fade shadow
	if shadow:
		_death_tween.parallel().tween_property(shadow, "modulate:a", 0.0, 0.2)
	
	await _death_tween.finished

#endregion
