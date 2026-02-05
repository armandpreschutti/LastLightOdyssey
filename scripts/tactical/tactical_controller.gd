extends Node2D
## Tactical Controller - Manages turn-based gameplay, unit selection, and mission flow

signal mission_complete(success: bool)
signal turn_ended(turn_number: int)

@onready var tactical_map: Node2D = $MapContainer/TacticalMap
@onready var tactical_hud: Control = $UILayer/TacticalHUD
@onready var combat_camera: Camera2D = $CombatCamera
@onready var projectile: Line2D = $MapContainer/EffectsLayer/Projectile
@onready var damage_popup_container: Node2D = $MapContainer/EffectsLayer/DamagePopupContainer
@onready var ui_layer: CanvasLayer = $UILayer

var deployed_officers: Array[Node2D] = []
var enemies: Array[Node2D] = []
var selected_unit: Node2D = null
var selected_target: Vector2i = Vector2i(-1, -1)  # For targeting enemies
var breach_mode: bool = false  # When true, clicking selects breach target
var current_turn: int = 0
var current_unit_index: int = 0  # Which unit's turn it is (0-based index)
var mission_active: bool = false
var is_paused: bool = false  # Track pause state
var extraction_positions: Array[Vector2i] = []
var mission_fuel_collected: int = 0  # Fuel collected during this mission
var mission_scrap_collected: int = 0  # Scrap collected during this mission

var FuelCrateScene: PackedScene
var ScrapPileScene: PackedScene
var OfficerUnitScene: PackedScene
var EnemyUnitScene: PackedScene
var PauseMenuScene: PackedScene
var current_pause_menu: Control = null

# Combat constants
const BASE_HIT_CHANCE: float = 70.0
const RANGE_PENALTY_START: int = 5
const RANGE_PENALTY_PER_TILE: float = 5.0
const MIN_HIT_CHANCE: float = 10.0
const MAX_HIT_CHANCE: float = 95.0
const FLANK_DAMAGE_BONUS: float = 0.50  # 50% bonus damage when flanking

# Cover attack bonuses (attacker in cover gets accuracy buff)
const FULL_COVER_ATTACK_BONUS: float = 15.0   # +15% hit chance when firing from full cover
const HALF_COVER_ATTACK_BONUS: float = 10.0   # +10% hit chance when firing from half cover


func _ready() -> void:
	FuelCrateScene = load("res://scenes/tactical/fuel_crate.tscn")
	ScrapPileScene = load("res://scenes/tactical/scrap_pile.tscn")
	OfficerUnitScene = load("res://scenes/tactical/officer_unit.tscn")
	EnemyUnitScene = load("res://scenes/tactical/enemy_unit.tscn")
	PauseMenuScene = load("res://scenes/ui/pause_menu.tscn")

	tactical_map.tile_clicked.connect(_on_tile_clicked)
	tactical_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	tactical_hud.extract_pressed.connect(_on_extract_pressed)
	tactical_hud.ability_used.connect(_on_ability_used)
	tactical_hud.pause_pressed.connect(_show_pause_menu)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and mission_active and not is_paused:
		_show_pause_menu()
		get_viewport().set_input_as_handled()


func _show_pause_menu() -> void:
	if current_pause_menu != null:
		return
	
	is_paused = true
	get_tree().paused = true
	
	current_pause_menu = PauseMenuScene.instantiate()
	current_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	current_pause_menu.resume_pressed.connect(_on_pause_resume)
	current_pause_menu.abandon_pressed.connect(_on_pause_abandon)
	ui_layer.add_child(current_pause_menu)
	
	# Pass the mission haul so it can be forfeited on abandon
	current_pause_menu.set_mission_haul(mission_fuel_collected, mission_scrap_collected)
	current_pause_menu.show_menu()


func _on_pause_resume() -> void:
	is_paused = false
	get_tree().paused = false
	current_pause_menu = null


func _on_pause_abandon() -> void:
	is_paused = false
	get_tree().paused = false
	current_pause_menu = null
	
	# End mission as failure (colonist cost already applied by pause menu)
	_end_mission(false)


func start_mission(officer_keys: Array[String]) -> void:
	mission_active = true
	current_turn = 1
	current_unit_index = 0
	mission_fuel_collected = 0
	mission_scrap_collected = 0
	deployed_officers.clear()
	enemies.clear()
	selected_target = Vector2i(-1, -1)

	GameState.enter_tactical_mode()

	# Generate map
	var generator = MapGenerator.new()
	var layout = generator.generate()
	tactical_map.initialize_map(layout)

	extraction_positions = generator.get_extraction_positions()

	# Spawn officers
	var spawn_positions = generator.get_spawn_positions()
	for i in range(mini(officer_keys.size(), spawn_positions.size())):
		var officer = OfficerUnitScene.instantiate()
		officer.set_grid_position(spawn_positions[i])
		officer.movement_finished.connect(_on_unit_movement_finished.bind(officer))
		officer.died.connect(_on_officer_died)
		tactical_map.add_unit(officer, spawn_positions[i])
		officer.initialize(officer_keys[i])  # Must be after add_unit so @onready vars are set
		deployed_officers.append(officer)

		# Reveal around spawn
		tactical_map.reveal_around(spawn_positions[i], officer.sight_range)

	# Spawn loot
	var loot_positions = generator.get_loot_positions()
	for loot_data in loot_positions:
		var loot: Node2D
		if loot_data["type"] == "fuel":
			loot = FuelCrateScene.instantiate()
		else:
			loot = ScrapPileScene.instantiate()
		loot.set_grid_position(loot_data["position"])
		tactical_map.add_interactable(loot, loot_data["position"])
	
	# Spawn enemies
	var enemy_positions = generator.get_enemy_spawn_positions()
	var enemy_id = 1
	for enemy_pos in enemy_positions:
		var enemy = EnemyUnitScene.instantiate()
		enemy.set_grid_position(enemy_pos)
		enemy.movement_finished.connect(_on_enemy_movement_finished.bind(enemy))
		enemy.died.connect(_on_enemy_died.bind(enemy))
		tactical_map.add_unit(enemy, enemy_pos)
		# Mix of basic and heavy enemies (20% chance for heavy)
		var enemy_type = "heavy" if randf() < 0.2 else "basic"
		enemy.initialize(enemy_id, enemy_type)
		enemy.visible = false  # Start invisible until revealed
		enemies.append(enemy)
		enemy_id += 1
	
	# Update enemy visibility after spawning all units
	_update_enemy_visibility()
	
	# Update cover indicators for all units
	_update_all_cover_indicators()

	# Update HUD
	tactical_hud.update_turn(current_turn)
	tactical_hud.update_stability(GameState.cryo_stability)
	tactical_hud.set_extract_visible(false)
	tactical_hud.visible = true

	# Select first officer (start of turn order)
	if deployed_officers.size() > 0:
		current_unit_index = 0
		_select_unit(deployed_officers[current_unit_index])
	else:
		tactical_map.clear_movement_range()
	
	# Update haul display
	tactical_hud.update_haul(mission_fuel_collected, mission_scrap_collected)


func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if not mission_active:
		return
	
	# Check if it's the current unit's turn
	if not _is_current_unit_turn():
		return
	
	# Handle breach mode
	if breach_mode and selected_unit and selected_unit.officer_type == "tech":
		_try_breach_tile(grid_pos)
		return

	# Check if clicking on a unit
	var unit_at_pos = tactical_map.get_unit_at(grid_pos)
	
	# Check if clicking on an enemy (for shooting)
	var enemy_at_pos: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos:
			enemy_at_pos = enemy
			break
	
	if enemy_at_pos and selected_unit and selected_unit in deployed_officers:
		# Try to shoot the enemy (only if visible and alive)
		if enemy_at_pos.current_hp <= 0:
			print("Cannot shoot: Enemy is already dead")
			return
		
		if not _is_enemy_visible(enemy_at_pos):
			print("Cannot shoot: Enemy not visible")
			return
		
		if not selected_unit.can_shoot_at(grid_pos):
			var distance = abs(grid_pos.x - selected_unit.get_grid_position().x) + abs(grid_pos.y - selected_unit.get_grid_position().y)
			if distance > selected_unit.shoot_range:
				print("Cannot shoot: Out of range (distance: %d, max: %d)" % [distance, selected_unit.shoot_range])
			elif not selected_unit.has_ap(1):
				print("Cannot shoot: Not enough AP (current: %d)" % selected_unit.current_ap)
			return
		
		await execute_shot(selected_unit, grid_pos, enemy_at_pos)
		return
	
	if unit_at_pos and unit_at_pos in deployed_officers:
		# Only allow selecting the current unit whose turn it is
		if unit_at_pos == deployed_officers[current_unit_index]:
			_select_unit(unit_at_pos)
		return

	# Check if clicking on an interactable (and unit is adjacent)
	var interactable = tactical_map.get_interactable_at(grid_pos)
	if interactable and selected_unit:
		var unit_pos = selected_unit.get_grid_position()
		var distance = abs(grid_pos.x - unit_pos.x) + abs(grid_pos.y - unit_pos.y)
		if distance == 1 and selected_unit.has_ap(interactable.interaction_ap_cost):
			_interact_with(interactable)
			return

	# Try to move selected unit (only if it's their turn)
	if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap() and not selected_unit.is_moving():
		_try_move_unit(selected_unit, grid_pos)


func _select_unit(unit: Node2D) -> void:
	if selected_unit:
		selected_unit.set_selected(false)
		tactical_map.clear_movement_range()

	selected_unit = unit
	selected_unit.set_selected(true)
	
	# Show movement range for selected unit (only if it's their turn and has AP)
	if unit == deployed_officers[current_unit_index] and unit.has_ap():
		var unit_pos = unit.get_grid_position()
		tactical_map.set_movement_range(unit_pos, unit.move_range)
	else:
		tactical_map.clear_movement_range()
	
	# Update HUD with full unit info (include cover level for attack bonus display)
	var unit_cover_level = tactical_map.get_adjacent_cover_level(unit.get_grid_position())
	tactical_hud.update_selected_unit_full(
		unit.officer_key,
		unit.current_ap,
		unit.max_ap,
		unit.current_hp,
		unit.max_hp,
		unit.move_range,
		unit == deployed_officers[current_unit_index],  # Is it their turn?
		unit.shoot_range,
		unit_cover_level
	)
	
	# Update ability buttons
	tactical_hud.update_ability_buttons(unit.officer_type, unit.current_ap)
	
	# Update attackable enemy highlights
	_update_attackable_highlights()


func _try_move_unit(unit: Node2D, target_pos: Vector2i) -> void:
	var current_pos = unit.get_grid_position()
	var path = tactical_map.find_path(current_pos, target_pos)

	if path.is_empty():
		return

	var move_cost = path.size() - 1
	if move_cost <= 0 or move_cost > unit.move_range:
		return

	if not unit.use_ap(1):
		return

	# Clear old position from pathfinding
	tactical_map.set_unit_position_solid(current_pos, false)

	# Move unit
	unit.set_grid_position(target_pos)
	unit.move_along_path(path)
	
	# Tutorial: Notify that a unit moved
	TutorialManager.notify_trigger("unit_moved")

	# Update HUD (cover level will be updated after movement finishes)
	tactical_hud.update_selected_unit_full(
		unit.officer_key,
		unit.current_ap,
		unit.max_ap,
		unit.current_hp,
		unit.max_hp,
		unit.move_range,
		unit == deployed_officers[current_unit_index],
		unit.shoot_range,
		0  # Cover level updated in movement_finished callback
	)
	# Update movement range display (only if it's their turn and has AP)
	if unit == deployed_officers[current_unit_index] and unit.has_ap():
		var unit_pos = unit.get_grid_position()
		tactical_map.set_movement_range(unit_pos, unit.move_range)
	else:
		tactical_map.clear_movement_range()


func _on_unit_movement_finished(unit: Node2D) -> void:
	var pos = unit.get_grid_position()

	# Mark new position as solid
	tactical_map.set_unit_position_solid(pos, true)

	# Reveal fog around new position
	tactical_map.reveal_around(pos, unit.sight_range)
	
	# Update cover indicator for this unit
	_update_unit_cover_indicator(unit)
	
	# Update enemy visibility (also updates attackable highlights)
	_update_enemy_visibility()
	
	# Auto-pickup: Check if there's an interactable at this position
	var interactable = tactical_map.get_interactable_at(pos)
	if interactable:
		_auto_pickup(interactable)

	# Check extraction availability
	_check_extraction_available()
	
	# Update HUD with new cover level after movement
	if selected_unit == unit and unit in deployed_officers:
		var new_cover_level = tactical_map.get_adjacent_cover_level(pos)
		tactical_hud.update_selected_unit_full(
			unit.officer_key,
			unit.current_ap,
			unit.max_ap,
			unit.current_hp,
			unit.max_hp,
			unit.move_range,
			unit == deployed_officers[current_unit_index],
			unit.shoot_range,
			new_cover_level
		)
	
	# Update movement range display (only if has AP remaining)
	if selected_unit == unit and unit == deployed_officers[current_unit_index]:
		if unit.has_ap():
			var unit_pos = unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, unit.move_range)
		else:
			tactical_map.clear_movement_range()


func _interact_with(interactable: Node2D) -> void:
	if selected_unit.use_ap(interactable.interaction_ap_cost):
		_pickup_item(interactable)
		var interact_cover_level = tactical_map.get_adjacent_cover_level(selected_unit.get_grid_position())
		tactical_hud.update_selected_unit_full(
			selected_unit.officer_key,
			selected_unit.current_ap,
			selected_unit.max_ap,
			selected_unit.current_hp,
			selected_unit.max_hp,
			selected_unit.move_range,
			selected_unit == deployed_officers[current_unit_index],
			selected_unit.shoot_range,
			interact_cover_level
		)
		# Update movement range display (clear if out of AP)
		if selected_unit == deployed_officers[current_unit_index]:
			if selected_unit.has_ap():
				tactical_map.set_movement_range(selected_unit.get_grid_position(), selected_unit.move_range)
			else:
				tactical_map.clear_movement_range()
		
		# Update attackable highlights (AP spent)
		_update_attackable_highlights()


func _auto_pickup(interactable: Node2D) -> void:
	# Auto-pickup when landing on an item (no AP cost)
	_pickup_item(interactable)


func _pickup_item(interactable: Node2D) -> void:
	# Track what was collected by type
	if interactable.has_method("get_item_type"):
		var item_type = interactable.get_item_type()
		if item_type == "fuel":
			mission_fuel_collected += 1
		elif item_type == "scrap":
			if interactable.has_method("get_scrap_amount"):
				mission_scrap_collected += interactable.get_scrap_amount()
			else:
				mission_scrap_collected += 5
	
	# Interact with the item (adds to GameState and removes from map)
	interactable.interact()
	
	# Update haul display
	tactical_hud.update_haul(mission_fuel_collected, mission_scrap_collected)


## Update cover indicator for a single unit
func _update_unit_cover_indicator(unit: Node2D) -> void:
	if unit.has_method("update_cover_indicator"):
		var pos = unit.get_grid_position()
		var cover_level = tactical_map.get_adjacent_cover_level(pos)
		unit.update_cover_indicator(cover_level)


## Update cover indicators for all units
func _update_all_cover_indicators() -> void:
	for officer in deployed_officers:
		_update_unit_cover_indicator(officer)
	for enemy in enemies:
		_update_unit_cover_indicator(enemy)


func _on_end_turn_pressed() -> void:
	if not mission_active:
		return
	
	# Clear attackable highlights before changing turns
	_clear_attackable_highlights()
	
	# Advance to next unit's turn
	current_unit_index += 1
	
	# If all units have had their turn, advance to next round
	if current_unit_index >= deployed_officers.size():
		current_unit_index = 0
		
		# Execute enemy turn before starting new player round
		await _execute_enemy_turn()
		
		current_turn += 1
		
		# Process turn (stability drain) - only once per round
		GameState.process_tactical_turn()
		
		# Reset AP for all officers at start of new round
		for officer in deployed_officers:
			officer.reset_ap()
		
		# Reset AP for all enemies
		for enemy in enemies:
			enemy.reset_ap()
		
		# Update HUD
		tactical_hud.update_turn(current_turn)
		tactical_hud.update_stability(GameState.cryo_stability)
		
		# Show cryo failure warning if stability is 0
		if GameState.cryo_stability <= 0:
			tactical_hud.show_cryo_warning()
		
		turn_ended.emit(current_turn)
	
	# Select the next unit whose turn it is
	if deployed_officers.size() > 0:
		_select_unit(deployed_officers[current_unit_index])


func _is_current_unit_turn() -> bool:
	if not selected_unit:
		return false
	return selected_unit == deployed_officers[current_unit_index]


func _check_extraction_available() -> void:
	var all_on_extraction = true
	var any_alive = false

	for officer in deployed_officers:
		if officer.current_hp > 0:
			any_alive = true
			var pos = officer.get_grid_position()
			if pos not in extraction_positions:
				all_on_extraction = false

	tactical_hud.set_extract_visible(all_on_extraction and any_alive)


func _on_extract_pressed() -> void:
	if not mission_active:
		return

	_end_mission(true)


func _on_officer_died(officer_key: String) -> void:
	# Remove from deployed list
	for i in range(deployed_officers.size() - 1, -1, -1):
		if deployed_officers[i].officer_key == officer_key:
			var officer = deployed_officers[i]
			var pos = officer.get_grid_position()
			tactical_map.set_unit_position_solid(pos, false)
			deployed_officers.remove_at(i)
			officer.queue_free()
			break

	# Update game state
	GameState.kill_officer(officer_key)

	# Check if all officers are dead
	if deployed_officers.is_empty():
		_end_mission(false)

	# Select another unit if the selected one died
	if selected_unit and selected_unit.officer_key == officer_key:
		selected_unit = null
		if deployed_officers.size() > 0:
			_select_unit(deployed_officers[0])


func _end_mission(success: bool) -> void:
	mission_active = false
	GameState.exit_tactical_mode()

	# Clear attackable highlights
	_clear_attackable_highlights()

	# Clear the map
	for officer in deployed_officers:
		officer.queue_free()
	deployed_officers.clear()

	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()

	for interactable in tactical_map.interactables_container.get_children():
		interactable.queue_free()

	selected_unit = null
	selected_target = Vector2i(-1, -1)
	tactical_hud.visible = false
	tactical_map.clear_movement_range()

	mission_complete.emit(success)


## Calculate hit chance for a shot from shooter_pos to target_pos
func calculate_hit_chance(shooter_pos: Vector2i, target_pos: Vector2i, shooter: Node2D = null) -> float:
	var distance = abs(target_pos.x - shooter_pos.x) + abs(target_pos.y - shooter_pos.y)
	
	# Base hit chance varies by class and distance
	var hit_chance = _get_base_hit_chance_for_shooter(shooter, distance)
	
	# Cover modifier (defender's cover reduces hit chance)
	var cover_modifier = _get_cover_modifier(shooter_pos, target_pos)
	hit_chance -= cover_modifier
	
	# Attacker's cover bonus (shooting from cover provides stability)
	var attacker_cover_bonus = _get_attacker_cover_bonus(shooter_pos)
	hit_chance += attacker_cover_bonus
	
	# Clamp to valid range
	return clampf(hit_chance, MIN_HIT_CHANCE, MAX_HIT_CHANCE)


## Get base hit chance based on shooter type and distance
func _get_base_hit_chance_for_shooter(shooter: Node2D, distance: int) -> float:
	# Adjacent shots are highly accurate for all classes
	if distance == 1:
		return 95.0
	elif distance == 2:
		return 90.0
	
	# Determine shooter type
	var shooter_type = ""
	if shooter and "officer_type" in shooter:
		shooter_type = shooter.officer_type
	
	# Class-specific distance falloff
	match shooter_type:
		"scout":
			# Scout excels at long range
			if distance <= 4:
				return 85.0
			elif distance <= 6:
				return 75.0
			elif distance <= 8:
				return 65.0
			else:
				return 50.0
		"captain":
			# Captain is balanced
			if distance <= 4:
				return 80.0
			elif distance <= 6:
				return 65.0
			elif distance <= 8:
				return 50.0
			else:
				return 35.0
		"heavy":
			# Heavy is decent at close-mid range, weaker at distance
			if distance <= 4:
				return 80.0
			elif distance <= 6:
				return 65.0
			elif distance <= 8:
				return 45.0
			else:
				return 30.0
		"tech", "medic":
			# Support classes are weaker at range
			if distance <= 4:
				return 75.0
			elif distance <= 6:
				return 55.0
			elif distance <= 8:
				return 40.0
			else:
				return 25.0
		_:
			# Default (enemies and unknown)
			if distance <= 4:
				return 75.0
			elif distance <= 6:
				return 60.0
			elif distance <= 8:
				return 45.0
			else:
				return 30.0


## Get cover modifier for a shot (only defender benefits from cover if not flanked)
func _get_cover_modifier(shooter_pos: Vector2i, target_pos: Vector2i) -> float:
	# Cover only benefits the defender (target) if the cover is between them and the attacker
	# Flanking: attacking from a direction where target has no cover = no cover penalty
	var max_cover = 0.0
	
	# Get direction from target to shooter
	var dir_to_shooter = Vector2(shooter_pos - target_pos).normalized()
	
	# Check the 4 adjacent tiles to the target
	var adjacent_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for adj_dir in adjacent_dirs:
		var adj_pos = target_pos + adj_dir
		
		# Check if this adjacent tile has cover
		var cover_value = tactical_map.get_cover_value(adj_pos)
		if cover_value <= 0:
			continue
		
		# Check if this cover is between the target and shooter (protects from this angle)
		# Cover direction points FROM target TO cover
		var cover_dir = Vector2(adj_dir).normalized()
		var dot = cover_dir.dot(dir_to_shooter)
		
		# Cover provides protection only if attacker is shooting from that direction
		# dot > 0.5 means the attack is coming from roughly the same direction as the cover
		# If attacking from the opposite side (flanking), dot will be negative = no protection
		if dot > 0.5:
			if cover_value > max_cover:
				max_cover = cover_value
	
	return max_cover


## Get accuracy bonus for attacker based on their cover (stable shooting position)
func _get_attacker_cover_bonus(shooter_pos: Vector2i) -> float:
	var cover_level = tactical_map.get_adjacent_cover_level(shooter_pos)
	
	match cover_level:
		2:  # Full cover (adjacent to wall)
			return FULL_COVER_ATTACK_BONUS
		1:  # Half cover (adjacent to half cover object)
			return HALF_COVER_ATTACK_BONUS
		_:  # No cover
			return 0.0


## Check if an attack is flanking (bypasses cover)
func is_flanking_attack(shooter_pos: Vector2i, target_pos: Vector2i) -> bool:
	# If target has adjacent cover but the attack comes from an unprotected direction
	var has_any_cover = tactical_map.has_adjacent_cover(target_pos)
	if not has_any_cover:
		return false  # No cover to flank
	
	var cover_modifier = _get_cover_modifier(shooter_pos, target_pos)
	return cover_modifier == 0.0  # Has cover but modifier is 0 = flanking


## Check if shooter has line of sight to target
func has_line_of_sight(shooter_pos: Vector2i, target_pos: Vector2i) -> bool:
	# Use Bresenham's line algorithm to check each tile
	var tiles = _get_line_tiles(shooter_pos, target_pos)
	
	for tile_pos in tiles:
		# Skip shooter and target positions
		if tile_pos == shooter_pos or tile_pos == target_pos:
			continue
		
		# Check if tile blocks LOS (only walls block, cover does not)
		if tactical_map.blocks_line_of_sight(tile_pos):
			return false
	
	return true


## Get tiles along a line using Bresenham's algorithm
func _get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	while true:
		tiles.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	
	return tiles


## Execute a shot from shooter to target with cinematic phases
func execute_shot(shooter: Node2D, target_pos: Vector2i, target: Node2D) -> void:
	var shooter_pos = shooter.get_grid_position()
	
	# Check LOS
	if not has_line_of_sight(shooter_pos, target_pos):
		print("No line of sight! Blocked by walls.")
		tactical_hud.show_combat_message("NO LINE OF SIGHT", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	# Calculate hit chance (pass shooter for class-specific calculations)
	var hit_chance = calculate_hit_chance(shooter_pos, target_pos, shooter)
	var base_damage = shooter.base_damage if "base_damage" in shooter else 25
	
	# Check for flanking and calculate bonus damage
	var is_flanking = is_flanking_attack(shooter_pos, target_pos)
	var damage = base_damage
	if is_flanking:
		damage = int(base_damage * (1.0 + FLANK_DAMAGE_BONUS))
		print("Flanking attack! Base damage: %d -> Flanking damage: %d (+%d%%)" % [base_damage, damage, int(FLANK_DAMAGE_BONUS * 100)])
	
	# Tutorial: Notify that a unit attacked
	TutorialManager.notify_trigger("unit_attacked")
	
	# PHASE 1: AIMING (0.8s)
	await _phase_aiming(shooter, shooter_pos, target_pos, hit_chance, is_flanking, damage)
	
	# PHASE 2: FIRING (0.3s)
	var hit = await _phase_firing(shooter, shooter_pos, target_pos, hit_chance, damage)
	
	# PHASE 3: IMPACT (0.7s)
	await _phase_impact(shooter, target_pos, target, hit, damage, is_flanking)
	
	# PHASE 4: RESOLUTION (0.5s)
	await _phase_resolution(shooter)


## Phase 1: Aiming
func _phase_aiming(shooter: Node2D, shooter_pos: Vector2i, target_pos: Vector2i, hit_chance: float, is_flanking: bool = false, damage: int = 0) -> void:
	# Focus camera on action
	var shooter_world = shooter.position
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	combat_camera.focus_on_action(shooter_world, target_world)
	
	# Shooter faces target
	shooter.face_towards(target_pos)
	
	# Check for cover bonus to display
	var attacker_cover_bonus = _get_attacker_cover_bonus(shooter_pos)
	var cover_level = tactical_map.get_adjacent_cover_level(shooter_pos)
	
	# Display aiming message with flanking indicator, damage preview, and cover bonus
	if is_flanking:
		tactical_hud.show_combat_message("FLANKING! %d%% (+%d%% DMG)" % [int(hit_chance), int(FLANK_DAMAGE_BONUS * 100)], Color(1, 0.6, 0.2))
	elif cover_level == 2:
		tactical_hud.show_combat_message("STABLE AIM [FULL COVER] %d%%" % int(hit_chance), Color(0.4, 0.9, 1.0))
	elif cover_level == 1:
		tactical_hud.show_combat_message("STABLE AIM [HALF COVER] %d%%" % int(hit_chance), Color(0.6, 0.9, 0.8))
	else:
		tactical_hud.show_combat_message("AIMING... %d%%" % int(hit_chance), Color(1, 1, 0.2))
	
	await get_tree().create_timer(0.8).timeout


## Phase 2: Firing
func _phase_firing(shooter: Node2D, _shooter_pos: Vector2i, target_pos: Vector2i, hit_chance: float, damage: int) -> bool:
	# Display firing message
	tactical_hud.show_combat_message("FIRING...", Color(1, 0.5, 0))
	
	# Calculate hit/miss
	var hit = shooter.shoot_at(target_pos, hit_chance, damage)
	
	# Fire projectile effect
	var shooter_world = shooter.position
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	projectile.fire(shooter_world, target_world)
	
	# Wait for projectile to reach target
	await projectile.impact_reached
	
	return hit


## Phase 3: Impact
func _phase_impact(_shooter: Node2D, target_pos: Vector2i, target: Node2D, hit: bool, damage: int, is_flanking: bool = false) -> void:
	# Display hit/miss message with flanking indicator
	if hit:
		if is_flanking:
			tactical_hud.show_combat_message("FLANKING HIT!", Color(1, 0.5, 0.1))
		else:
			tactical_hud.show_combat_message("HIT!", Color(1, 0.2, 0.2))
		
		# Apply damage
		if target:
			target.take_damage(damage)
			if is_flanking:
				print("Flanking Hit! Dealt %d damage (includes +%d%% bonus)" % [damage, int(FLANK_DAMAGE_BONUS * 100)])
			else:
				print("Hit! Dealt %d damage" % damage)
			
			# Show damage popup (flanking hits use special color via is_crit parameter)
			_spawn_damage_popup(damage, true, target.position, false, is_flanking)
	else:
		tactical_hud.show_combat_message("MISS!", Color(0.6, 0.6, 0.6))
		print("Miss! (Hit chance was calculated)")
		
		# Show miss popup
		var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
		_spawn_damage_popup(0, false, target_world)
	
	await get_tree().create_timer(0.7).timeout


## Phase 4: Resolution
func _phase_resolution(shooter: Node2D) -> void:
	# Hide combat message
	tactical_hud.hide_combat_message()
	
	# Return camera to tactical view
	combat_camera.return_to_tactical()
	
	# Update HUD
	if shooter in deployed_officers:
		var shooter_cover_level = tactical_map.get_adjacent_cover_level(shooter.get_grid_position())
		tactical_hud.update_selected_unit_full(
			shooter.officer_key,
			shooter.current_ap,
			shooter.max_ap,
			shooter.current_hp,
			shooter.max_hp,
			shooter.move_range,
			shooter == deployed_officers[current_unit_index],
			shooter.shoot_range,
			shooter_cover_level
		)
		# Update movement range display (clear if out of AP)
		if shooter == selected_unit and shooter == deployed_officers[current_unit_index]:
			if shooter.has_ap():
				tactical_map.set_movement_range(shooter.get_grid_position(), shooter.move_range)
			else:
				tactical_map.clear_movement_range()
		
		# Update attackable enemy highlights (AP spent, enemy may have died)
		_update_attackable_highlights()
	
	await get_tree().create_timer(0.5).timeout


## Spawn a damage popup number
func _spawn_damage_popup(damage: int, is_hit: bool, world_pos: Vector2, is_heal: bool = false, is_flank: bool = false) -> void:
	var popup = Label.new()
	popup.script = load("res://scripts/tactical/damage_popup.gd")
	damage_popup_container.add_child(popup)
	popup.initialize(damage, is_hit, world_pos, is_heal, is_flank)


## Execute AI turn for all enemies
func _execute_enemy_turn() -> void:
	print("=== ENEMY TURN ===")
	
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		# Enemies always act (they can see and move even if players can't see them)
		# The AI itself will handle whether they can detect players
		print("Enemy %d taking action" % enemy.enemy_id)
		
		# Enemy takes their action
		var decision = EnemyAI.decide_action(enemy, deployed_officers, tactical_map)
		
		match decision["action"]:
			"shoot":
				print("Enemy %d shooting at officer at %s" % [enemy.enemy_id, decision["target_pos"]])
				await execute_shot(enemy, decision["target_pos"], decision["target"])
				await get_tree().create_timer(0.3).timeout  # Small delay for visual feedback
			
			"move":
				var old_pos = enemy.get_grid_position()
				var new_pos = decision["target_pos"]
				print("Enemy %d moving from %s to %s (path length: %d)" % [enemy.enemy_id, old_pos, new_pos, decision["path"].size()])
				
				# Clear old position
				tactical_map.set_unit_position_solid(old_pos, false)
				
				# Move enemy
				enemy.set_grid_position(new_pos)
				enemy.use_ap(1)
				enemy.move_along_path(decision["path"])
				
				# Wait for movement to finish
				await enemy.movement_finished
				
				# Mark new position as solid
				tactical_map.set_unit_position_solid(new_pos, true)
				
				# Update enemy visibility after movement
				_update_enemy_visibility()
				
				# Check for overwatch shots
				await _check_overwatch_shots(enemy, new_pos)
				
				await get_tree().create_timer(0.2).timeout  # Small delay
			
			"idle":
				print("Enemy %d idle (no targets in range, AP: %d)" % [enemy.enemy_id, enemy.current_ap])
				await get_tree().create_timer(0.1).timeout  # Small delay
	
	print("=== ENEMY TURN END ===")


func _on_enemy_movement_finished(_enemy: Node2D) -> void:
	# Enemy movement completed
	pass


func _on_enemy_died(enemy: Node2D) -> void:
	print("Enemy %d died" % enemy.enemy_id)
	
	# Remove from enemies list
	var idx = enemies.find(enemy)
	if idx >= 0:
		enemies.remove_at(idx)
	
	# Clear from map
	var pos = enemy.get_grid_position()
	tactical_map.set_unit_position_solid(pos, false)
	
	# Remove node
	enemy.queue_free()
	
	# Check if all enemies defeated
	if enemies.is_empty():
		print("All enemies defeated!")
		# Could show a message or auto-complete mission


## Check if an enemy is visible to any player unit
func _is_enemy_visible(enemy: Node2D) -> bool:
	var enemy_pos = enemy.get_grid_position()
	
	# Check if enemy tile is revealed
	if not tactical_map.is_tile_revealed(enemy_pos):
		return false
	
	# Check if any officer can see the enemy (within sight range)
	for officer in deployed_officers:
		if officer.current_hp <= 0:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(enemy_pos.x - officer_pos.x) + abs(enemy_pos.y - officer_pos.y)
		
		if distance <= officer.sight_range:
			return true
	
	return false


## Update enemy visibility based on revealed tiles
func _update_enemy_visibility() -> void:
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		enemy.visible = _is_enemy_visible(enemy)
	
	# Also update attackable highlights (visibility affects targeting)
	_update_attackable_highlights()


## Update which enemies are highlighted as attackable by the current unit
func _update_attackable_highlights() -> void:
	# First clear all highlights
	for enemy in enemies:
		if enemy.current_hp > 0:
			enemy.set_targetable(false)
	
	# If no unit selected or selected unit can't attack, don't highlight anything
	if not selected_unit or selected_unit not in deployed_officers:
		return
	
	# Check if it's the current unit's turn and they have AP to attack
	if selected_unit != deployed_officers[current_unit_index]:
		return
	
	if not selected_unit.has_ap(1):
		return
	
	var shooter_pos = selected_unit.get_grid_position()
	
	# Check each visible enemy
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		if not enemy.visible:
			continue
		
		var enemy_pos = enemy.get_grid_position()
		
		# Check if in range
		var distance = abs(enemy_pos.x - shooter_pos.x) + abs(enemy_pos.y - shooter_pos.y)
		if distance > selected_unit.shoot_range:
			continue
		
		# Check line of sight
		if not has_line_of_sight(shooter_pos, enemy_pos):
			continue
		
		# Calculate hit chance for this enemy
		var hit_chance = calculate_hit_chance(shooter_pos, enemy_pos, selected_unit)
		
		# This enemy is attackable - highlight it with hit chance!
		enemy.set_targetable(true, hit_chance)


## Clear all attackable enemy highlights
func _clear_attackable_highlights() -> void:
	for enemy in enemies:
		if enemy.current_hp > 0:
			enemy.set_targetable(false)


func _on_ability_used(ability_type: String) -> void:
	if not selected_unit or selected_unit not in deployed_officers:
		return
	
	if selected_unit != deployed_officers[current_unit_index]:
		print("Not this unit's turn!")
		tactical_hud.show_combat_message("NOT YOUR TURN", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	match ability_type:
		"overwatch":
			if selected_unit.officer_type != "scout":
				print("Only Scouts can use Overwatch!")
				return
			
			if selected_unit.toggle_overwatch():
				var status = "ACTIVATED" if selected_unit.overwatch_active else "DEACTIVATED"
				print("Overwatch %s" % status)
				tactical_hud.show_combat_message("OVERWATCH %s" % status, Color(0.2, 1, 0.2) if selected_unit.overwatch_active else Color(1, 0.5, 0))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				# Update HUD to reflect AP change
				_select_unit(selected_unit)
			else:
				print("Not enough AP for Overwatch")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
		
		"breach":
			if selected_unit.officer_type != "tech":
				print("Only Techs can use Breach!")
				return
			
			if not selected_unit.has_ap(1):
				print("Not enough AP for Breach")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter breach targeting mode
			breach_mode = true
			print("Breach ability - click an adjacent wall or cover tile to destroy it")
			tactical_hud.show_combat_message("SELECT ADJACENT TILE TO BREACH", Color(0, 1, 1))
			# Message stays until target selected or cancelled
		
		"patch":
			if selected_unit.officer_type != "medic":
				print("Only Medics can use Patch!")
				return
			
			# Try to auto-heal adjacent ally
			_try_auto_patch()
		
		"taunt":
			if selected_unit.officer_type != "heavy":
				print("Only Heavy can use Taunt!")
				return
			
			if selected_unit.taunt_active:
				print("Taunt is already active!")
				tactical_hud.show_combat_message("TAUNT ALREADY ACTIVE", Color(1, 0.5, 0))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			if selected_unit.use_taunt():
				print("Heavy activates TAUNT!")
				tactical_hud.show_combat_message("TAUNT ACTIVATED! ENEMIES WILL TARGET YOU", Color(1, 0.5, 0.1))
				await get_tree().create_timer(1.5).timeout
				tactical_hud.hide_combat_message()
				# Update HUD to reflect AP change
				_select_unit(selected_unit)
			else:
				print("Not enough AP for Taunt")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()


## Try to breach a tile (destroy wall/cover)
func _try_breach_tile(grid_pos: Vector2i) -> void:
	breach_mode = false
	tactical_hud.hide_combat_message()
	
	if not selected_unit or selected_unit.officer_type != "tech":
		return
	
	var tech_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - tech_pos.x) + abs(grid_pos.y - tech_pos.y)
	
	# Must be adjacent
	if distance != 1:
		print("Breach target must be adjacent (distance: %d)" % distance)
		tactical_hud.show_combat_message("TARGET TOO FAR", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	# Check if tile is breachable (wall or cover)
	if not tactical_map.is_tile_walkable(grid_pos):
		# It's a wall - can breach it
		if selected_unit.use_breach():
			print("Breaching wall at %s" % grid_pos)
			tactical_map.breach_tile(grid_pos)
			tactical_hud.show_combat_message("WALL BREACHED!", Color(0, 1, 1))
			await get_tree().create_timer(1.0).timeout
			tactical_hud.hide_combat_message()
			_select_unit(selected_unit)
		else:
			print("Failed to use breach (no AP)")
	else:
		# Check if there's cover
		var cover_value = tactical_map.get_cover_value(grid_pos)
		if cover_value > 0:
			# Has cover - breach it
			if selected_unit.use_breach():
				print("Breaching cover at %s" % grid_pos)
				tactical_map.breach_tile(grid_pos)
				tactical_hud.show_combat_message("COVER DESTROYED!", Color(0, 1, 1))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				_select_unit(selected_unit)
			else:
				print("Failed to use breach (no AP)")
		else:
			print("Nothing to breach at %s" % grid_pos)
			tactical_hud.show_combat_message("NOTHING TO BREACH", Color(1, 0.5, 0))
			await get_tree().create_timer(1.0).timeout
			tactical_hud.hide_combat_message()


## Check if any officer on overwatch can shoot the enemy
func _check_overwatch_shots(enemy: Node2D, enemy_pos: Vector2i) -> void:
	# Check each officer for overwatch
	for officer in deployed_officers:
		if officer.current_hp <= 0:
			continue
		
		if not officer.overwatch_active:
			continue
		
		var officer_pos = officer.get_grid_position()
		var distance = abs(enemy_pos.x - officer_pos.x) + abs(enemy_pos.y - officer_pos.y)
		
		# Check if enemy is in range and visible
		if distance > officer.shoot_range:
			continue
		
		if not _is_enemy_visible(enemy):
			continue
		
		# Check line of sight
		if not has_line_of_sight(officer_pos, enemy_pos):
			continue
		
		# Overwatch triggered!
		print("Overwatch triggered by %s on Enemy %d!" % [officer.officer_key, enemy.enemy_id])
		tactical_hud.show_combat_message("OVERWATCH TRIGGERED!", Color(1, 1, 0.2))
		await get_tree().create_timer(0.8).timeout
		
		# Check for flanking and calculate damage
		var is_flanking = is_flanking_attack(officer_pos, enemy_pos)
		var damage = officer.base_damage
		if is_flanking:
			damage = int(officer.base_damage * (1.0 + FLANK_DAMAGE_BONUS))
			print("Flanking overwatch! Base damage: %d -> Flanking damage: %d" % [officer.base_damage, damage])
		
		# Take the shot
		var hit_chance = calculate_hit_chance(officer_pos, enemy_pos, officer)
		var hit = officer.try_overwatch_shot(enemy_pos, hit_chance)
		
		# Fire projectile
		var officer_world = officer.position
		var enemy_world = enemy.position
		projectile.fire(officer_world, enemy_world)
		await projectile.impact_reached
		
		# Apply damage if hit
		if hit:
			if is_flanking:
				tactical_hud.show_combat_message("FLANKING HIT!", Color(1, 0.5, 0.1))
			else:
				tactical_hud.show_combat_message("HIT!", Color(1, 0.2, 0.2))
			enemy.take_damage(damage)
			_spawn_damage_popup(damage, true, enemy.position, false, is_flanking)
		else:
			tactical_hud.show_combat_message("MISS!", Color(0.6, 0.6, 0.6))
			_spawn_damage_popup(0, false, enemy.position)
		
		await get_tree().create_timer(0.7).timeout
		tactical_hud.hide_combat_message()
		
		# Only one overwatch shot per enemy movement
		break


func _try_auto_patch() -> void:
	if not selected_unit or selected_unit.officer_type != "medic":
		return
	
	if not selected_unit.has_ap(2):
		print("Not enough AP for Patch (needs 2)")
		tactical_hud.show_combat_message("NOT ENOUGH AP (NEEDS 2)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	var medic_pos = selected_unit.get_grid_position()
	
	# Find adjacent allies
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in directions:
		var check_pos = medic_pos + dir
		for officer in deployed_officers:
			if officer == selected_unit:
				continue
			if officer.get_grid_position() == check_pos and officer.current_hp < officer.max_hp:
				# Found injured adjacent ally
				if selected_unit.use_patch(officer):
					var heal_amount = int(officer.max_hp * 0.5)
					print("Healed %s for %d HP!" % [officer.officer_key, heal_amount])
					tactical_hud.show_combat_message("HEALED %s (+%d HP)" % [officer.officer_key.to_upper(), heal_amount], Color(0.2, 1, 0.2))
					
					# Show heal popup
					_spawn_damage_popup(heal_amount, true, officer.position, true)
					
					await get_tree().create_timer(1.0).timeout
					tactical_hud.hide_combat_message()
					_select_unit(selected_unit)
					return
	
	print("No injured allies adjacent to heal!")
	tactical_hud.show_combat_message("NO INJURED ALLIES NEARBY", Color(1, 0.5, 0))
	await get_tree().create_timer(1.0).timeout
	tactical_hud.hide_combat_message()
