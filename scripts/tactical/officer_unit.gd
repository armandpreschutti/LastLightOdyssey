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
	"heavy": { "color": Color.ORANGE_RED, "move_range": 3, "sight_range": 9, "max_hp": 120 },
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

# Ability cooldown system — per-ability: {ability_id: remaining_turns}
var ability_cooldowns: Dictionary = {}
const ABILITY_MAX_COOLDOWN: int = 2

# Status effects/buffs tracking: {effect_name: remaining_turns}
var status_effects: Dictionary = {}

# Per-turn state tracking (reset at start of each turn)
var moved_this_turn: bool = false
var attacked_this_turn: bool = false
var shots_fired_this_turn: int = 0  # For Ambush (first-shot crit)

# Persistent mission-state tracking
var war_machine_bonus_damage: int = 0        # Heavy: +5 per kill, accumulates
var emergency_protocol_triggered: bool = false  # Tech: one-time trigger
var no_one_left_behind_saved: Array[String] = []  # Captain: track saved allies

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

	# Use persistent HP from GameState if the officer survived a previous mission
	var _od: OfficerData = GameState.get_officer(key)
	if _od and _od.current_hp > 0:
		current_hp = _od.current_hp
	else:
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
		var old_pos = position
		position += direction * _move_speed * delta
		
		# Debug every 60 frames or so (approx 1 sec) roughly to avoid spam, or just checking movement
		# print("DEBUG: Unit moving. Pos: ", position, " Target: ", target, " Delta: ", delta)
		
		if position.distance_to(target) < 5:
			print("DEBUG: Reached target waypoint: ", target)
			position = target
			_move_path.remove_at(0)

			if _move_path.is_empty():
				print("DEBUG: Movement path complete")
				_moving = false
				set_process(false)
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
	print("DEBUG: OfficerUnit move_along_path started. Path size: ", _move_path.size(), " First target: ", _move_path[0] if _move_path.size() > 0 else "None", " Process Mode: ", process_mode, " Is Inside Tree: ", is_inside_tree())
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
	# Reset per-turn state at the start of each new turn
	moved_this_turn = false
	attacked_this_turn = false
	shots_fired_this_turn = 0


## Reduce all ability cooldowns by 1 (called at start of each round)
func reduce_cooldown() -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0:
			ability_cooldowns[key] -= 1


## Check if a specific ability (or any ability) is on cooldown
func is_ability_on_cooldown(ability_id: String = "") -> bool:
	if ability_id != "":
		return ability_cooldowns.get(ability_id, 0) > 0
	for v in ability_cooldowns.values():
		if v > 0:
			return true
	return false


## Get remaining cooldown turns for a specific ability (or max of all)
func get_ability_cooldown(ability_id: String = "") -> int:
	if ability_id != "":
		return ability_cooldowns.get(ability_id, 0)
	var max_cd := 0
	for v in ability_cooldowns.values():
		max_cd = maxi(max_cd, v)
	return max_cd


## Start cooldown for a specific ability
func _start_cooldown(ability_id: String, cooldown_turns: int = ABILITY_MAX_COOLDOWN) -> void:
	ability_cooldowns[ability_id] = cooldown_turns


func take_damage(amount: int) -> void:
	var actual_damage = calculate_damage_received(amount)
	current_hp -= actual_damage
	_update_hp_bar()

	# Play damage SFX
	if SFXManager:
		SFXManager.play_sfx_by_name("combat", "hit")

	# Damage flash effect
	_flash_damage()

	# Emergency Protocol: first time Tech drops below 25% HP, gain +2 AP + reset turret CD
	if officer_type == "tech" and not emergency_protocol_triggered:
		var threshold = int(max_hp * 0.25)
		if current_hp <= threshold and current_hp > 0:
			var od: OfficerData = GameState.get_officer(officer_key)
			if od and od.has_ability("emergency_protocol"):
				emergency_protocol_triggered = true
				gain_bonus_ap(2)
				ability_cooldowns.erase("turret")  # Reset turret cooldown to 0
				_flash_emergency_protocol()

	if current_hp <= 0:
		current_hp = 0
		# Play death SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "death")
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

	var actual_damage = damage if damage > 0 else (base_damage + war_machine_bonus_damage)
	
	# Use forgiving RNG system
	var hit = CombatRNG.roll_attack(hit_chance, true, get_instance_id())

	attacked_this_turn = true
	shots_fired_this_turn += 1

	shot_fired.emit(target_pos, hit, actual_damage if hit else 0)
	return hit


## Toggle overwatch mode (Scout ability)
func toggle_overwatch() -> bool:
	if officer_type != "scout":
		return false
	
	if is_ability_on_cooldown("overwatch"):
		return false

	if not overwatch_active and not use_ap(1):
		return false

	overwatch_active = not overwatch_active

	# Start cooldown when activating
	if overwatch_active:
		_start_cooldown("overwatch")
	
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


## Use Turret ability (Tech) - place auto-firing sentry within 2 tiles
func use_turret() -> bool:
	if officer_type != "tech":
		return false

	if is_ability_on_cooldown("turret"):
		return false

	if not use_ap(1):
		return false

	_start_cooldown("turret")
	return true


## Use Patch ability (Medic) - heal ally within 3 tiles
func use_patch(target: Node2D) -> bool:
	if officer_type != "medic":
		return false
	
	if is_ability_on_cooldown("patch"):
		return false

	if not use_ap(1):
		return false

	# Validate range (3 tiles manhattan distance)
	var medic_pos = get_grid_position()
	var target_pos = target.get_grid_position()
	var distance = abs(medic_pos.x - target_pos.x) + abs(medic_pos.y - target_pos.y)
	if distance > 3:
		return false
	
	# Heal for 50% of max HP (62.5% with Medic's enhanced healing passive)
	var base_heal_percent = 0.5
	var heal_multiplier = get_healing_bonus()  # +25% bonus for Medic
	var heal_amount = int(target.max_hp * base_heal_percent * heal_multiplier)
	target.heal(heal_amount)
	
	_start_cooldown("patch", 1)
	return true


## Use Charge ability (Heavy) - rush enemy within 4 tiles
func use_charge() -> bool:
	if officer_type != "heavy":
		return false

	if is_ability_on_cooldown("charge"):
		return false

	if not use_ap(1):
		return false

	_start_cooldown("charge")
	return true


## Use Execute ability (Captain) - guaranteed kill on adjacent enemy below 50% HP
func use_execute() -> bool:
	if officer_type != "captain":
		return false

	if is_ability_on_cooldown("execute"):
		return false

	if not use_ap(1):
		return false

	_start_cooldown("execute")
	# Warlord: Execute has no cooldown
	var _od: OfficerData = GameState.get_officer(officer_key)
	if _od and _od.has_ability("warlord"):
		ability_cooldowns["execute"] = 0
	return true


## Use Precision Shot ability (Sniper) - guaranteed hit on any visible enemy for 2x damage
func use_precision_shot() -> bool:
	if officer_type != "sniper":
		return false

	if is_ability_on_cooldown("precision_shot"):
		return false

	if not use_ap(1):
		return false

	# Snap Shot: Precision Shot costs 0 cooldown
	var _od: OfficerData = GameState.get_officer(officer_key)
	if not (_od and _od.has_ability("snap_shot")):
		_start_cooldown("precision_shot")
	return true


## Use an upgraded ability by ID
func use_ability_by_id(ability_id: String) -> bool:
	var ability_def = GameState.get_ability_def(ability_id)
	if ability_def.is_empty():
		return false

	var cost = ability_def.get("cost", 1)
	if not use_ap(cost):
		return false

	var ability_type = ability_def.get("type", "passive")
	if ability_type == "passive":
		# Passives don't use AP or cooldown
		return false

	# Check if this ability modifies a base ability
	var modifies = ability_def.get("modifies", "")
	if modifies != "":
		# Don't apply cooldown override here - it's handled at ability use time
		pass

	# Apply default cooldown
	var cooldown = ability_def.get("cooldown", 2)
	_start_cooldown(ability_id, cooldown)

	return true


## Get effective ability cooldown considering unlocked modifiers
func get_effective_ability_cooldown(ability_id: String) -> int:
	var override = GameState.get_ability_cooldown_override(ability_id)
	if override >= 0:
		return override
	return GameState.get_ability_cooldown(ability_id)


## Get damage multiplier for an ability (considering modifiers)
func get_ability_damage_multiplier(ability_id: String) -> float:
	var base_multiplier = GameState.get_ability_damage_multiplier(ability_id)
	return base_multiplier


## Check if unit has a specific ability unlocked
func has_ability_unlocked(ability_id: String) -> bool:
	var od: OfficerData = GameState.get_officer(officer_key)
	return od != null and od.has_ability(ability_id)


## Check if target is valid for Precision Shot (any visible enemy, no distance/cover restrictions)
func can_precision_shot_target(target_pos: Vector2i) -> bool:
	if officer_type != "sniper":
		return false
	# Precision Shot can target any visible enemy regardless of distance or cover
	# Visibility check is handled by the tactical controller
	return true


## Check if unit can use their special ability
func can_use_ability(ability_type: String) -> bool:
	if is_ability_on_cooldown(ability_type):
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
		"precision_shot":
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


## Add a status effect/buff to this unit
func add_status_effect(effect_name: String, duration: int) -> void:
	status_effects[effect_name] = duration
	_apply_status_visual_feedback(effect_name)
	# Apply movement bonus when adrenaline is granted
	if effect_name == "adrenaline":
		move_range += 2
		_add_adrenaline_marker(duration)


## Remove a status effect
func remove_status_effect(effect_name: String) -> void:
	if effect_name in status_effects:
		status_effects.erase(effect_name)


## Check if unit has a status effect
func has_status_effect(effect_name: String) -> bool:
	return effect_name in status_effects and status_effects[effect_name] > 0


## Decrement all status effect durations (call at end of enemy turn)
func tick_status_effects() -> void:
	# Apply poison damage before decrementing
	if has_status_effect("poison"):
		current_hp = maxi(1, current_hp - 5)  # Poison: 5 DMG/turn, doesn't kill outright
		_update_hp_bar()
		_flash_damage()

	var effects_to_remove = []
	for effect_name in status_effects:
		status_effects[effect_name] -= 1
		# Update adrenaline marker to show remaining turns
		if effect_name == "adrenaline":
			_update_adrenaline_marker()
		if status_effects[effect_name] <= 0:
			effects_to_remove.append(effect_name)

	for effect_name in effects_to_remove:
		# Remove movement bonus when adrenaline expires
		if effect_name == "adrenaline":
			move_range -= 2
			_remove_adrenaline_marker()
		remove_status_effect(effect_name)


## Apply visual feedback for status effects
func _apply_status_visual_feedback(effect_name: String) -> void:
	if not sprite:
		return

	match effect_name:
		"phantom":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.6, 1.0, 0.8, 0.6), 0.3)

		"immune":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 0.5, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

		"stim":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.0, 1.3, 0.3, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

		"adrenaline":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.2, 0.8, 1.2, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

		"marked":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.15)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

		"poison":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.4, 1.2, 0.2, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

		"pin_down":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.1, 1.0), 0.15)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

		"untouchable":
			var tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.8, 1.0), 0.1)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

		"juggernaut":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.4, 0.7, 0.2, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

		"war_machine":
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.8, 0.4, 0.1, 1.0), 0.1)
			tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.1)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25)


## Add an "ADRENALINE" visual marker to this unit
func _add_adrenaline_marker(duration: int) -> void:
	# Remove existing marker first to avoid duplicates
	_remove_adrenaline_marker()
	
	var marker_label = Label.new()
	marker_label.name = "AdrenalineMarker"
	marker_label.text = "ADRENALINE [%d]" % duration
	marker_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))  # Green
	marker_label.add_theme_font_size_override("font_size", 12)
	marker_label.position = Vector2(-30, -55)
	marker_label.z_index = 10
	add_child(marker_label)


## Remove the adrenaline marker from this unit
func _remove_adrenaline_marker() -> void:
	var existing = get_node_or_null("AdrenalineMarker")
	if existing:
		existing.queue_free()


## Update adrenaline marker text to show remaining turns
func _update_adrenaline_marker() -> void:
	var marker = get_node_or_null("AdrenalineMarker")
	if marker and has_status_effect("adrenaline"):
		marker.text = "ADRENALINE [%d]" % status_effects.get("adrenaline", 0)


## Gain bonus AP (used by abilities like Lead by Example, Inspire)
func gain_bonus_ap(amount: int) -> void:
	# Allow exceeding max_ap for ability-granted bonus AP (cap at max_ap + amount)
	current_ap = mini(current_ap + amount, max_ap + amount)
	_update_ap_display()


## Gain bonus movement (used by abilities like Hit & Run)
func gain_bonus_movement(amount: int) -> void:
	move_range += amount


## Calculate damage taken considering status effects
func calculate_damage_received(base_damage: int) -> int:
	var actual_damage = base_damage

	# Immune: no damage at all
	if has_status_effect("immune"):
		return 0

	# Untouchable: next attack misses (caller already checked this for hit logic,
	# but if damage is passed directly, absorb it)
	if has_status_effect("untouchable"):
		remove_status_effect("untouchable")
		return 0

	# Stim reduces damage by 50%
	if has_status_effect("stim"):
		actual_damage = int(actual_damage * 0.5)

	# Phantom reduces damage by 50%
	if has_status_effect("phantom"):
		actual_damage = int(actual_damage * 0.5)

	# Bulldozer armor reduces damage
	if has_status_effect("bulldozer_armor"):
		actual_damage = maxi(1, actual_damage - 20)

	return actual_damage


## Flash effect when Emergency Protocol triggers
func _flash_emergency_protocol() -> void:
	if not sprite:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 1.8, 2.0, 1.0), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.6, 1.8, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


## Get accuracy modifier from status effects
func get_accuracy_modifier_from_effects() -> float:
	var modifier = 0.0

	# Poison reduces accuracy
	if has_status_effect("poison"):
		modifier -= 20.0

	# Adrenaline increases accuracy
	if has_status_effect("adrenaline"):
		modifier += 15.0

	return modifier


## Get critical hit chance modifier from status effects
func get_critical_chance_modifier() -> float:
	var modifier = critical_hit_chance

	if has_status_effect("adrenaline"):
		modifier += 5.0  # Small crit bonus from adrenaline

	return modifier


#region Ability Implementations - All Classes

# CAPTAIN ABILITIES
#====================

## Captain Level 2A: Lead by Example - Passive bonus when killing enemies
## NOTE: This function is not currently used. The Lead by Example ability logic
## is handled directly by TacticalController._on_enemy_died() to properly manage
## turn order (allies who already acted get AP next round, others get it immediately).
func apply_lead_by_example_bonus(squad: Array[Node2D]) -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("lead_by_example"):
		return
	# Grants +1 AP to all other squad members immediately
	# (For proper turn-based handling, see TacticalController._on_enemy_died())
	for unit in squad:
		if unit != self and unit.has_method("gain_bonus_ap"):
			unit.gain_bonus_ap(1)


## Captain Level 2B: Coordinate Fire - Mark target for accuracy/crit bonus
func apply_coordinate_fire(target: Node2D) -> void:
	if not use_ap(1):
		return
	if is_ability_on_cooldown("coordinate_fire"):
		return

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("coordinate_fire"):
		return

	# Mark target with visual indicator
	if target.has_method("add_status_effect"):
		target.add_status_effect("marked", 2)  # Lasts 2 turns

	_start_cooldown("coordinate_fire")


## Captain Level 3A: Warlord - Remove Execute cooldown
func get_execute_cooldown_with_warlord() -> int:
	var od = GameState.get_officer(officer_key)
	if od and od.has_ability("warlord"):
		return 0  # No cooldown
	return 2


## Captain Level 3B: No One Left Behind - Save ally from death (once per ally)
func try_save_ally(target: Node2D) -> bool:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("no_one_left_behind"):
		return false
	if target.current_hp > 0:
		return false
	# Only save each ally once per mission
	var target_key = target.officer_key if "officer_key" in target else ""
	if target_key != "" and target_key in no_one_left_behind_saved:
		return false

	# Restore to 1 HP and grant 1-turn immunity
	target.current_hp = 1
	target._update_hp_bar()
	if target.has_method("add_status_effect"):
		target.add_status_effect("immune", 1)
	if target_key != "":
		no_one_left_behind_saved.append(target_key)

	return true


## Captain Level 3C: Inspire - Grant one ally +1 AP on their next turn
func apply_inspire(target: Node2D) -> bool:
	if not use_ap(1):
		return false
	if is_ability_on_cooldown("inspire"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("inspire"):
		return false

	# Note: AP is granted by tactical_controller when target's turn starts
	# Visual: gold pulse on target (indicates they are inspired)
	if target.has_method("_apply_status_visual_feedback"):
		target._apply_status_visual_feedback("inspire_flash")
	else:
		var sp = target.get_node_or_null("Sprite")
		if sp:
			var tween = target.create_tween()
			tween.tween_property(sp, "modulate", Color(2.0, 1.6, 0.3, 1.0), 0.1)
			tween.tween_property(sp, "scale", Vector2(1.2, 1.2), 0.08)
			tween.tween_property(sp, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
			tween.parallel().tween_property(sp, "scale", Vector2(1.0, 1.0), 0.2)

	_start_cooldown("inspire", 3)
	return true


# SCOUT ABILITIES
#==================

## Scout Level 2A: Hit & Run - Bonus movement after shooting
func apply_hit_and_run_bonus() -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("hit_and_run"):
		return

	# Grant +3 movement range next turn (tracked by caller)
	if has_method("gain_bonus_movement"):
		gain_bonus_movement(3)


## Scout Level 2B: Deep Scanner - Reveal enemies through walls
func apply_deep_scanner() -> bool:
	if not use_ap(0):  # 0 AP cost
		return false
	if is_ability_on_cooldown("deep_scanner"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("deep_scanner"):
		return false

	# Triggers fog of war reveal (handled by tactical controller)
	_start_cooldown("deep_scanner", 3)
	return true


## Scout Level 3A: Ambush - First shot is auto-crit if Scout hasn't moved
## Returns true if the next shot should be a critical hit
func check_ambush_crit() -> bool:
	if officer_type != "scout":
		return false
	if moved_this_turn:
		return false
	if shots_fired_this_turn > 0:
		return false  # Only first shot
	var od = GameState.get_officer(officer_key)
	return od != null and od.has_ability("ambush")


## Scout Level 3B: Phantom - Become invisible for 2 turns
func apply_phantom_invisibility() -> bool:
	if not use_ap(1):
		return false
	if is_ability_on_cooldown("phantom"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("phantom"):
		return false

	# Add invisibility status (reduces damage taken by 50%, prevents targeting)
	if has_method("add_status_effect"):
		add_status_effect("phantom", 2)

	# Visual feedback: fade out slightly
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.5), 0.3)

	_start_cooldown("phantom")
	return true


## Scout Level 3C: Untouchable - Miss guarantee after kill
func apply_untouchable_protection() -> bool:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("untouchable"):
		return false

	# Grants next attack against self guaranteed miss
	if has_method("add_status_effect"):
		add_status_effect("untouchable", 1)

	return true


# TECH ABILITIES
#=================

## Tech Level 2A: Combat Engineer - Upgrade turrets
func get_turret_stats_with_engineer() -> Dictionary:
	var od = GameState.get_officer(officer_key)
	var stats = {"duration": 3, "damage": 15, "range": 6}

	if od and od.has_ability("combat_engineer"):
		# stats["hp"] = 40  # REMOVED: Turrets have no HP
		stats["duration"] = 5  # Extended duration

	return stats


## Tech Level 2B: Field Repair - Heal nearest turret
func apply_field_repair(turret: Node2D) -> bool:
	if is_ability_on_cooldown("field_repair"):
		return false
	# 0 AP cost
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("field_repair"):
		return false

	# Reset turret's turns
	var reset_duration = get_turret_stats_with_engineer().get("duration", 3)
	if "turns_remaining" in turret:
		turret.turns_remaining = reset_duration
		if turret.has_method("update_visual"):
			turret.update_visual()

	# Visual: cyan healing pulse on tech unit
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.3, 1.8, 2.0, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

	_start_cooldown("field_repair", 3)
	return true


## Tech Level 3A: Twin-Link - Deploy 2 turrets
func get_max_turrets_with_twinlink() -> int:
	var od = GameState.get_officer(officer_key)
	if od and od.has_ability("twin_link"):
		return 2
	return 1


## Tech Level 3B: Remote Detonation — returns true so controller can handle explosion
func can_remote_detonate() -> bool:
	var od = GameState.get_officer(officer_key)
	return od != null and od.has_ability("remote_detonation") and officer_type == "tech"


## Tech Level 3C: Emergency Protocol — handled in take_damage


# MEDIC ABILITIES
#==================

## Medic Level 2A: Adrenaline Patch - Patch + movement/accuracy buff
func apply_adrenaline_patch(target: Node2D) -> bool:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("adrenaline_patch"):
		return false

	# Standard patch healing
	var heal_amount = int(target.max_hp * 0.625)  # 62.5% with medic bonus
	target.heal(heal_amount)

	# Add buff (marker is created in add_status_effect)
	if target.has_method("add_status_effect"):
		target.add_status_effect("adrenaline", 2)  # +2 movement, +15% accuracy for 2 turns

	return true


## Medic Level 2B: Field Surgeon - Auto-stabilize allies
func try_auto_stabilize(target: Node2D) -> bool:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("field_surgeon"):
		return false

	var distance = abs(get_grid_position().x - target.get_grid_position().x) + \
				   abs(get_grid_position().y - target.get_grid_position().y)

	if distance > 4:
		return false

	# Save from death
	if target.current_hp <= 0:
		target.current_hp = 1
		target._update_hp_bar()
		return true

	return false


## Medic Level 3A: Miracle Worker - Global heal all allies
func apply_miracle_worker(squad: Array[Node2D]) -> bool:
	if not use_ap(2):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("miracle_worker"):
		return false

	# Heal all squad members for 50% HP
	for unit in squad:
		var heal_amount = int(unit.max_hp * 0.5)
		unit.heal(heal_amount)

	_start_cooldown("miracle_worker", 999)  # One use per mission
	return true


## Medic Level 3B: Toxicologist - Poison enemies with attacks
func apply_toxicologist_poison(target: Node2D) -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("toxicologist"):
		return

	# Apply poison status (5 DMG/turn, -20% accuracy)
	if target.has_method("add_status_effect"):
		target.add_status_effect("poison", 3)
		
		# Visual marker
		var label = Label.new()
		label.text = "POISONED"
		label.name = "PoisonMarker"
		label.add_theme_color_override("font_color", Color(0.8, 0.2, 1.0))
		label.add_theme_font_size_override("font_size", 12)
		label.position = Vector2(-20, -50)
		target.add_child(label)
		var tween = target.create_tween()
		tween.tween_callback(label.queue_free).set_delay(5.0) 




## Medic Level 3C: Stim Injector - Boost ally with AP + damage reduction
func apply_stim_injector(target: Node2D) -> bool:
	if not use_ap(1):
		return false
	if is_ability_on_cooldown("stim_injector"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("stim_injector"):
		return false

	# Grant -50% damage taken for 1 turn (AP is queued for next turn in tactical_controller)
	if target.has_method("add_status_effect"):
		target.add_status_effect("stim", 1)

	_start_cooldown("stim_injector", 3)
	return true


# HEAVY ABILITIES
#===================

## Heavy Level 2A: Bulldozer - Charge grants armor
func apply_bulldozer_armor() -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("bulldozer"):
		return
	add_status_effect("bulldozer_armor", 2)
	# Visual: orange armor flash
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.6, 0.8, 0.2, 1.0), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.1)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)


## Heavy Level 2B: Suppression Fire - all visible enemies -25% accuracy for 1 turn
func apply_suppression_fire() -> bool:
	if not use_ap(2):
		return false
	if is_ability_on_cooldown("suppression_fire"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("suppression_fire"):
		return false

	attacked_this_turn = true
	_start_cooldown("suppression_fire", 3)
	# Visual: orange muzzle blast
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.8, 0.6, 0.1, 1.0), 0.04)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
	return true


## Heavy Level 3A: Juggernaut - Crit immunity + regen if idle this turn
func apply_juggernaut_regeneration() -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("juggernaut"):
		return
	if attacked_this_turn:
		return  # Only regen if Heavy didn't attack

	var regen_amount = int(max_hp * 0.15)
	heal(regen_amount)

	# Visual: green-gold regen pulse
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 1.8, 0.5, 1.0), 0.15)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25)


## Check if Juggernaut crit immunity is active
func is_juggernaut_crit_immune() -> bool:
	var od = GameState.get_officer(officer_key)
	return od != null and od.has_ability("juggernaut")


## Heavy Level 3B: Rocket Salvo - 40 damage in 3x3 area (no cover destruction)
func apply_rocket_salvo(_target_pos: Vector2i) -> bool:
	if not use_ap(2):
		return false
	if is_ability_on_cooldown("rocket_salvo"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("rocket_salvo"):
		return false

	attacked_this_turn = true
	_start_cooldown("rocket_salvo", 3)
	return true


## Heavy Level 3C: War Machine - +5 base damage per kill (called by controller on kill)
func apply_war_machine_kill() -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("war_machine"):
		return
	war_machine_bonus_damage += 5
	# Visual: red-orange power surge
	_apply_status_visual_feedback("war_machine")


# SNIPER ABILITIES
#===================

## Sniper Level 2A: Damn Good Ground - Activate "Last Stand" stance
## Spends 1 AP. Next shot is guaranteed hit with no cover penalty. Cooldown 2.
func apply_damn_good_ground() -> bool:
	if not use_ap(1):
		return false
	if is_ability_on_cooldown("damn_good_ground"):
		return false

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("damn_good_ground"):
		return false

	add_status_effect("last_stand", 1)  # lasts 1 turn — consumed on next shot
	_start_cooldown("damn_good_ground", 2)
	# Visual: purple/silver flash
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.4, 0.9, 1.8, 1.0), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
	return true


## Sniper Level 2B: Snap Shot - Precision Shot has no cooldown
func get_precision_shot_cooldown_with_snapshot() -> int:
	var od = GameState.get_officer(officer_key)
	if od and od.has_ability("snap_shot"):
		return 0  # No cooldown
	return 2


## Sniper Level 3A: Serial - Refund AP on kills
func apply_serial_refund() -> void:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("serial"):
		return

	# Refund all AP spent on killing shot
	reset_ap()


## Sniper Level 3B: Apex Predator - 2x damage vs full health enemies
func get_apex_predator_damage_multiplier(target: Node2D) -> float:
	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("apex_predator"):
		return 1.0

	if target.current_hp == target.max_hp:
		return 2.0  # Double damage

	return 1.0


## Sniper Level 3C: Double Tap - Fire twice with accuracy penalty
func apply_double_tap(target_pos: Vector2i, hit_chance: float) -> Dictionary:
	if not use_ap(1):
		return {"success": false}
	if is_ability_on_cooldown("double_tap"):
		return {"success": false}

	var od = GameState.get_officer(officer_key)
	if not od or not od.has_ability("double_tap"):
		return {"success": false}

	# Fire twice with -15% accuracy on second shot
	var first_hit = randf() <= (hit_chance / 100.0)
	var second_hit = randf() <= ((hit_chance - 15.0) / 100.0)

	_start_cooldown("double_tap", 2)
	return {"success": true, "hits": [first_hit, second_hit]}

#endregion


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
