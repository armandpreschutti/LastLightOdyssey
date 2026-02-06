extends Node2D
## Tactical Controller - Manages turn-based gameplay, unit selection, and mission flow

signal mission_complete(success: bool, stats: Dictionary)
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
var execute_mode: bool = false  # When true, clicking selects execute target
var charge_mode: bool = false  # When true, clicking selects charge target
var turret_mode: bool = false  # When true, clicking selects turret placement tile
var precision_mode: bool = false  # When true, clicking selects precision shot target (Sniper)
var current_turn: int = 0
var current_unit_index: int = 0  # Which unit's turn it is (0-based index)
var mission_active: bool = false
var is_paused: bool = false  # Track pause state
var is_animating: bool = false  # Track when animations are playing to prevent input
var extraction_positions: Array[Vector2i] = []
var mission_fuel_collected: int = 0  # Fuel collected during this mission
var mission_scrap_collected: int = 0  # Scrap collected during this mission
var mission_enemies_killed: int = 0  # Enemies killed during this mission
var current_biome: BiomeConfig.BiomeType = BiomeConfig.BiomeType.STATION

var FuelCrateScene: PackedScene
var ScrapPileScene: PackedScene
var OfficerUnitScene: PackedScene
var EnemyUnitScene: PackedScene
var TurretUnitScene: PackedScene
var PauseMenuScene: PackedScene
var ConfirmDialogScene: PackedScene
var current_pause_menu: Control = null

# Active turrets placed by Tech officer
var active_turrets: Array[Node2D] = []

# Combat constants
const BASE_HIT_CHANCE: float = 70.0
const RANGE_PENALTY_START: int = 5
const RANGE_PENALTY_PER_TILE: float = 5.0
const MIN_HIT_CHANCE: float = 10.0
const MAX_HIT_CHANCE: float = 95.0
const FLANK_DAMAGE_BONUS: float = 0.50  # 50% bonus damage when flanking

# Cover attack bonuses (attacker in cover gets accuracy buff)
const FULL_COVER_ATTACK_BONUS: float = 10.0   # +10% hit chance when firing from full cover
const HALF_COVER_ATTACK_BONUS: float = 5.0   # +5% hit chance when firing from half cover


func _ready() -> void:
	FuelCrateScene = load("res://scenes/tactical/fuel_crate.tscn")
	ScrapPileScene = load("res://scenes/tactical/scrap_pile.tscn")
	OfficerUnitScene = load("res://scenes/tactical/officer_unit.tscn")
	EnemyUnitScene = load("res://scenes/tactical/enemy_unit.tscn")
	TurretUnitScene = load("res://scenes/tactical/turret_unit.tscn")
	PauseMenuScene = load("res://scenes/ui/pause_menu.tscn")
	ConfirmDialogScene = load("res://scenes/ui/confirm_dialog.tscn")

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


func start_mission(officer_keys: Array[String], biome_type: int = BiomeConfig.BiomeType.STATION) -> void:
	mission_active = true
	current_turn = 1
	current_unit_index = 0
	mission_fuel_collected = 0
	mission_scrap_collected = 0
	mission_enemies_killed = 0
	deployed_officers.clear()
	enemies.clear()
	selected_target = Vector2i(-1, -1)

	GameState.enter_tactical_mode()

	# Generate map with biome type
	current_biome = biome_type as BiomeConfig.BiomeType
	var generator = MapGenerator.new()
	var layout = generator.generate(current_biome)
	
	# Set tactical map dimensions and biome theme
	var map_dims = generator.get_map_dimensions()
	tactical_map.set_map_dimensions(map_dims.x, map_dims.y)
	tactical_map.initialize_map(layout, current_biome)

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
	
	# Spawn enemies with biome-specific distribution
	var enemy_positions = generator.get_enemy_spawn_positions()
	var enemy_config = BiomeConfig.get_enemy_config(current_biome)
	var heavy_chance = enemy_config["heavy_chance"]
	
	var enemy_id = 1
	for enemy_pos in enemy_positions:
		var enemy = EnemyUnitScene.instantiate()
		enemy.set_grid_position(enemy_pos)
		enemy.movement_finished.connect(_on_enemy_movement_finished.bind(enemy))
		enemy.died.connect(_on_enemy_died.bind(enemy))
		tactical_map.add_unit(enemy, enemy_pos)
		# Mix of basic and heavy enemies based on biome config
		var enemy_type = "heavy" if randf() < heavy_chance else "basic"
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
		# Center camera on the active unit
		_center_camera_on_unit(deployed_officers[current_unit_index])
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
	
	# Handle ability targeting modes
	if turret_mode and selected_unit and selected_unit.officer_type == "tech":
		_try_place_turret(grid_pos)
		return
	
	if charge_mode and selected_unit and selected_unit.officer_type == "heavy":
		_try_charge_enemy(grid_pos)
		return
	
	if execute_mode and selected_unit and selected_unit.officer_type == "captain":
		_try_execute_enemy(grid_pos)
		return
	
	if precision_mode and selected_unit and selected_unit.officer_type == "sniper":
		_try_precision_shot(grid_pos)
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
		tactical_map.clear_execute_range()

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
		unit_cover_level,
		unit.officer_type
	)
	
	# Update ability buttons (with cooldown info)
	tactical_hud.update_ability_buttons(unit.officer_type, unit.current_ap, unit.get_ability_cooldown())
	
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
	
	# Disable end turn button during movement animation
	_set_animating(true)

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
		0,  # Cover level updated in movement_finished callback
		unit.officer_type
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
			new_cover_level,
			unit.officer_type
		)
	
	# Update movement range display (only if has AP remaining)
	if selected_unit == unit and unit == deployed_officers[current_unit_index]:
		if unit.has_ap():
			var unit_pos = unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, unit.move_range)
		else:
			tactical_map.clear_movement_range()
	
	# Center camera on unit after movement (only for player units)
	if unit in deployed_officers:
		_center_camera_on_unit(unit)
	
	# Re-enable end turn button after player unit movement completes
	if unit in deployed_officers:
		_set_animating(false)
	
	# Check if unit is out of AP and auto-end turn
	if unit == deployed_officers[current_unit_index]:
		_check_auto_end_turn()


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
			interact_cover_level,
			selected_unit.officer_type
		)
		# Update movement range display (clear if out of AP)
		if selected_unit == deployed_officers[current_unit_index]:
			if selected_unit.has_ap():
				tactical_map.set_movement_range(selected_unit.get_grid_position(), selected_unit.move_range)
			else:
				tactical_map.clear_movement_range()
		
		# Update attackable highlights (AP spent)
		_update_attackable_highlights()
		
		# Check if unit is out of AP and auto-end turn
		if selected_unit == deployed_officers[current_unit_index]:
			_check_auto_end_turn()


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


## Check if current unit is out of AP and automatically end their turn
func _check_auto_end_turn() -> void:
	if not mission_active:
		return
	
	# Only check if it's a player unit's turn
	if current_unit_index >= deployed_officers.size():
		return
	
	var current_unit = deployed_officers[current_unit_index]
	if not current_unit:
		return
	
	# If unit has no AP remaining, automatically end their turn
	if not current_unit.has_ap():
		print("Unit %s out of AP, auto-ending turn" % current_unit.officer_key)
		_on_end_turn_pressed()


func _on_end_turn_pressed() -> void:
	if not mission_active:
		return
	
	# Prevent ending turn while animations are playing
	if is_animating:
		return
	
	# Clear attackable highlights before changing turns
	_clear_attackable_highlights()
	
	# Advance to next unit's turn
	current_unit_index += 1
	
	# If all units have had their turn, advance to next round
	if current_unit_index >= deployed_officers.size():
		current_unit_index = 0
		
		# Disable end turn button during enemy turn and animations
		_set_animating(true)
		
		# Execute enemy turn before starting new player round
		await _execute_enemy_turn()
		
		current_turn += 1
		
		# Process turn (stability drain) - only once per round
		GameState.process_tactical_turn()
		
		# Reset AP and reduce cooldowns for all officers at start of new round
		for officer in deployed_officers:
			officer.reset_ap()
			officer.reduce_cooldown()
		
		# Process turret auto-fire before player actions
		await _process_turrets()
		
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
		
		# Re-enable end turn button now that new turn has started
		_set_animating(false)
	
	# Select the next unit whose turn it is
	if deployed_officers.size() > 0:
		_select_unit(deployed_officers[current_unit_index])
		# Center camera on the active unit
		_center_camera_on_unit(deployed_officers[current_unit_index])


func _is_current_unit_turn() -> bool:
	if not selected_unit:
		return false
	return selected_unit == deployed_officers[current_unit_index]


## Set animation state and update UI accordingly
func _set_animating(animating: bool) -> void:
	is_animating = animating
	tactical_hud.set_end_turn_enabled(not animating)


## Center camera on a unit's position (used when turn starts)
func _center_camera_on_unit(unit: Node2D) -> void:
	var unit_pos = unit.get_grid_position()
	var world_pos = tactical_map.grid_to_world(unit_pos)
	combat_camera.center_on_unit(world_pos)


func _check_extraction_available() -> void:
	var any_on_extraction = false
	var any_alive = false

	for officer in deployed_officers:
		if officer.current_hp > 0:
			any_alive = true
			var pos = officer.get_grid_position()
			if pos in extraction_positions:
				any_on_extraction = true
				break  # At least one unit is in extraction zone

	tactical_hud.set_extract_visible(any_on_extraction and any_alive)


func _on_extract_pressed() -> void:
	if not mission_active:
		return

	# Center camera on extraction zone with zoom
	if extraction_positions.size() > 0:
		# Calculate center point of all extraction positions
		var center_sum = Vector2i.ZERO
		for pos in extraction_positions:
			center_sum += pos
		var center_grid = Vector2i(center_sum.x / extraction_positions.size(), center_sum.y / extraction_positions.size())
		
		# Convert to world coordinates and center camera with zoom
		var world_pos = tactical_map.grid_to_world(center_grid)
		# Use moderate zoom (1.5x) for extraction focus - noticeable but not too extreme
		var extraction_zoom = Vector2(1.5, 1.5)
		combat_camera.center_on_position_with_zoom(world_pos, extraction_zoom)

	# Check which units are in the extraction zone
	var units_in_zone: Array[Node2D] = []
	var units_outside_zone: Array[Node2D] = []
	
	for officer in deployed_officers:
		if officer.current_hp > 0:
			var pos = officer.get_grid_position()
			if pos in extraction_positions:
				units_in_zone.append(officer)
			else:
				units_outside_zone.append(officer)
	
	# Check if captain would be left behind - captain must always be extracted
	for unit in units_outside_zone:
		if unit.officer_type == "captain":
			_show_captain_required_warning()
			return
	
	# If some units are outside the zone, show warning
	if units_outside_zone.size() > 0:
		_show_extraction_warning(units_in_zone, units_outside_zone)
	else:
		# All units are in zone, extract normally
		_end_mission(true)


func _show_captain_required_warning() -> void:
	var dialog = ConfirmDialogScene.instantiate()
	ui_layer.add_child(dialog)
	
	var message = "Your CAPTAIN must be in the extraction zone to initiate extraction.\n\nMove your Captain to the extraction tiles before extracting. The Captain cannot be left behind."
	
	dialog.setup("[ EXTRACTION DENIED ]", message, "UNDERSTOOD", "")
	dialog.show_dialog()
	
	# Hide the cancel button for info-only dialog and focus confirm button
	dialog.no_button.visible = false
	dialog.yes_button.grab_focus()


func _show_extraction_warning(units_in_zone: Array[Node2D], units_outside_zone: Array[Node2D]) -> void:
	# Create confirmation dialog
	var dialog = ConfirmDialogScene.instantiate()
	ui_layer.add_child(dialog)
	
	# Build warning message
	var in_zone_names: Array[String] = []
	for unit in units_in_zone:
		in_zone_names.append(unit.officer_key.to_upper())
	
	var outside_zone_names: Array[String] = []
	for unit in units_outside_zone:
		outside_zone_names.append(unit.officer_key.to_upper())
	
	var message = "WARNING: %d unit(s) will be EXTRACTED:\n%s\n\n%d unit(s) will be LEFT BEHIND:\n%s\n\nUnits left behind will be treated as KIA.\n\nProceed with extraction?" % [
		units_in_zone.size(),
		", ".join(in_zone_names),
		units_outside_zone.size(),
		", ".join(outside_zone_names)
	]
	
	dialog.setup("[ EXTRACTION WARNING ]", message, "EXTRACT", "CANCEL")
	dialog.show_dialog()
	
	# Connect confirmed signal directly to handler (avoids GDScript lambda capture-by-value issue)
	dialog.confirmed.connect(_on_extraction_warning_confirmed.bind(units_outside_zone))
	# cancelled signal just closes the dialog via confirm_dialog.gd - no action needed


func _on_extraction_warning_confirmed(units_outside_zone: Array[Node2D]) -> void:
	# Mark units outside zone as dead (iterate over copy to avoid modification issues)
	var units_to_kill = units_outside_zone.duplicate()
	for unit in units_to_kill:
		# Check if unit is still valid (may have been removed by previous call)
		if is_instance_valid(unit) and unit in deployed_officers:
			_on_officer_died(unit.officer_key)
	
	# Extract with remaining units
	_end_mission(true)


func _on_officer_died(officer_key: String) -> void:
	# Find the officer and play death animation
	var dying_officer: Node2D = null
	var officer_index: int = -1
	
	for i in range(deployed_officers.size()):
		if deployed_officers[i].officer_key == officer_key:
			dying_officer = deployed_officers[i]
			officer_index = i
			break
	
	if dying_officer == null:
		return
	
	# Clear position from map immediately
	var pos = dying_officer.get_grid_position()
	tactical_map.set_unit_position_solid(pos, false)
	
	# Remove from deployed list before animation (so they can't be selected)
	if officer_index >= 0:
		deployed_officers.remove_at(officer_index)
	
	# Select another unit if the selected one died
	if selected_unit and selected_unit.officer_key == officer_key:
		selected_unit = null
		if deployed_officers.size() > 0:
			_select_unit(deployed_officers[0])
	
	# Play death animation
	if dying_officer.has_method("play_death_animation"):
		await dying_officer.play_death_animation()
	
	# Remove node after animation
	dying_officer.queue_free()

	# Update game state
	GameState.kill_officer(officer_key)

	# Check if all officers are dead
	if deployed_officers.is_empty():
		_end_mission(false)


func _end_mission(success: bool) -> void:
	mission_active = false
	GameState.exit_tactical_mode()

	# Clear attackable highlights
	_clear_attackable_highlights()

	# Collect officer stats BEFORE cleanup
	var officers_status: Array = []
	for officer in deployed_officers:
		officers_status.append({
			"name": officer.officer_key,
			"alive": officer.current_hp > 0,
			"hp": officer.current_hp,
			"max_hp": officer.max_hp,
		})
	
	# Build stats dictionary
	var mission_stats: Dictionary = {
		"success": success,
		"fuel_collected": mission_fuel_collected,
		"scrap_collected": mission_scrap_collected,
		"enemies_killed": mission_enemies_killed,
		"turns_taken": current_turn,
		"officers_status": officers_status,
	}
	
	# Accumulate stats to GameState for voyage recap (only on success)
	if success:
		GameState.add_mission_stats(mission_fuel_collected, mission_scrap_collected, mission_enemies_killed, current_turn)

	# Play beam-up animation on successful extraction
	if success and deployed_officers.size() > 0:
		await _play_beam_up_animation()

	# Clear the map
	for officer in deployed_officers:
		officer.queue_free()
	deployed_officers.clear()

	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	
	# Clear turrets
	for turret in active_turrets:
		turret.queue_free()
	active_turrets.clear()

	for interactable in tactical_map.interactables_container.get_children():
		interactable.queue_free()

	selected_unit = null
	selected_target = Vector2i(-1, -1)
	tactical_hud.visible = false
	tactical_map.clear_movement_range()

	mission_complete.emit(success, mission_stats)


## Play beam-up extraction animation - units float up with a light beam effect
func _play_beam_up_animation() -> void:
	# Hide HUD during animation
	tactical_hud.show_combat_message("EXTRACTION IN PROGRESS...", Color(0.4, 0.9, 1.0))
	
	# Center camera on the group
	if deployed_officers.size() > 0:
		var avg_pos = Vector2.ZERO
		for officer in deployed_officers:
			avg_pos += officer.position
		avg_pos /= deployed_officers.size()
		combat_camera.position = avg_pos
	
	await get_tree().create_timer(0.5).timeout
	
	# Create beam effects and animate each officer
	var beam_tweens: Array[Tween] = []
	
	for i in range(deployed_officers.size()):
		var officer = deployed_officers[i]
		if officer.current_hp <= 0:
			continue
		
		# Create a vertical beam of light under the officer
		var beam = Line2D.new()
		beam.width = 20.0
		beam.default_color = Color(0.3, 0.9, 1.0, 0.0)
		beam.add_point(officer.position + Vector2(0, 40))
		beam.add_point(officer.position + Vector2(0, -200))
		tactical_map.add_child(beam)
		
		# Stagger the beam appearance
		var delay = i * 0.3
		
		var beam_tween = create_tween()
		beam_tween.tween_interval(delay)
		
		# Fade in the beam
		beam_tween.tween_property(beam, "default_color:a", 0.5, 0.3)
		
		# Float the officer upward while fading out
		beam_tween.parallel().tween_property(officer, "position:y", officer.position.y - 150, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(0.2)
		beam_tween.parallel().tween_property(officer, "modulate:a", 0.0, 1.0).set_delay(0.4)
		
		# Add a subtle white flash to the officer
		beam_tween.parallel().tween_property(officer, "modulate", Color(2.0, 2.5, 3.0, 1.0), 0.3).set_delay(0.1)
		
		# Narrow and fade the beam after officer is gone
		beam_tween.tween_property(beam, "width", 2.0, 0.4)
		beam_tween.parallel().tween_property(beam, "default_color:a", 0.0, 0.4)
		beam_tween.tween_callback(beam.queue_free)
		
		beam_tweens.append(beam_tween)
	
	# Wait for all animations to complete
	if beam_tweens.size() > 0:
		await beam_tweens[-1].finished
	
	await get_tree().create_timer(0.3).timeout
	tactical_hud.hide_combat_message()
	combat_camera.return_to_tactical()


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
		return 90.0
	elif distance == 2:
		return 85.0
	
	# Determine shooter type
	var shooter_type = ""
	if shooter and "officer_type" in shooter:
		shooter_type = shooter.officer_type
	
	# Class-specific distance falloff
	match shooter_type:
		"scout":
			# Scout excels at long range
			if distance <= 4:
				return 80.0
			elif distance <= 6:
				return 70.0
			elif distance <= 8:
				return 60.0
			else:
				return 45.0
		"sniper":
			# Sniper has the best long-range accuracy, slightly weaker at close range
			if distance <= 2:
				return 80.0
			elif distance <= 4:
				return 80.0
			elif distance <= 6:
				return 75.0
			elif distance <= 8:
				return 70.0
			elif distance <= 10:
				return 65.0
			else:
				return 60.0
		"captain":
			# Captain is balanced
			if distance <= 4:
				return 75.0
			elif distance <= 6:
				return 60.0
			elif distance <= 8:
				return 45.0
			else:
				return 30.0
		"heavy":
			# Heavy is decent at close-mid range, weaker at distance
			if distance <= 4:
				return 75.0
			elif distance <= 6:
				return 60.0
			elif distance <= 8:
				return 40.0
			else:
				return 25.0
		"tech", "medic":
			# Support classes are weaker at range
			if distance <= 4:
				return 70.0
			elif distance <= 6:
				return 50.0
			elif distance <= 8:
				return 35.0
			else:
				return 20.0
		_:
			# Default (enemies and unknown)
			if distance <= 4:
				return 70.0
			elif distance <= 6:
				return 55.0
			elif distance <= 8:
				return 40.0
			else:
				return 25.0


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
	
	# Disable end turn button during combat animation
	_set_animating(true)
	
	# Check LOS
	if not has_line_of_sight(shooter_pos, target_pos):
		print("No line of sight! Blocked by walls.")
		tactical_hud.show_combat_message("NO LINE OF SIGHT", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
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
	
	# PHASE 1: AIMING (1.0s - balanced timing)
	await _phase_aiming(shooter, shooter_pos, target_pos, hit_chance, is_flanking, damage)
	
	# Safety: abort if shooter or target was freed during aiming phase
	if not is_instance_valid(shooter):
		print("Shot aborted: shooter was destroyed during aiming")
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 2: FIRING (slower projectile travel)
	var hit = await _phase_firing(shooter, shooter_pos, target_pos, hit_chance, damage)
	
	# Safety: abort if shooter was freed during firing phase
	if not is_instance_valid(shooter):
		print("Shot aborted: shooter was destroyed during firing")
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 3: IMPACT (0.9s - balanced impact reaction)
	# Target may have been freed - _phase_impact already has a null check
	var valid_target = target if is_instance_valid(target) else null
	await _phase_impact(shooter, target_pos, valid_target, hit, damage, is_flanking)
	
	# Safety: abort if shooter was freed during impact phase
	if not is_instance_valid(shooter):
		print("Shot aborted: shooter was destroyed during impact")
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 4: RESOLUTION (0.7s - balanced transition back)
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
	
	# Balanced aiming phase timing
	await get_tree().create_timer(1.0).timeout


## Phase 2: Firing
func _phase_firing(shooter: Node2D, _shooter_pos: Vector2i, target_pos: Vector2i, hit_chance: float, damage: int) -> bool:
	# Display firing message
	tactical_hud.show_combat_message("FIRING...", Color(1, 0.5, 0))
	
	# Calculate hit/miss
	var hit = shooter.shoot_at(target_pos, hit_chance, damage)
	
	# Brief pause before firing for better sequencing
	await get_tree().create_timer(0.15).timeout
	
	# Play unique attack animation for the shooter
	if shooter.has_method("play_attack_animation"):
		shooter.play_attack_animation()
	
	# Fire projectile effect
	var shooter_world = shooter.position
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	projectile.fire(shooter_world, target_world)
	
	# Wait for projectile to reach target
	await projectile.impact_reached
	
	# Brief pause after impact before showing results
	await get_tree().create_timer(0.1).timeout
	
	return hit


## Phase 3: Impact
func _phase_impact(_shooter: Node2D, target_pos: Vector2i, target: Node2D, hit: bool, damage: int, is_flanking: bool = false) -> void:
	# Display hit/miss message with flanking indicator
	if hit:
		if is_flanking:
			tactical_hud.show_combat_message("FLANKING HIT!", Color(1, 0.5, 0.1))
		else:
			tactical_hud.show_combat_message("HIT!", Color(1, 0.2, 0.2))
		
		# Apply damage (check validity in case target was freed during earlier phases)
		if is_instance_valid(target):
			target.take_damage(damage)
			if is_flanking:
				print("Flanking Hit! Dealt %d damage (includes +%d%% bonus)" % [damage, int(FLANK_DAMAGE_BONUS * 100)])
			else:
				print("Hit! Dealt %d damage" % damage)
			
			# Show damage popup (flanking hits use special color via is_crit parameter)
			_spawn_damage_popup(damage, true, target.position, false, is_flanking)
		else:
			# Target was freed - show popup at grid position instead
			var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
			_spawn_damage_popup(damage, true, target_world, false, is_flanking)
	else:
		tactical_hud.show_combat_message("MISS!", Color(0.6, 0.6, 0.6))
		print("Miss! (Hit chance was calculated)")
		
		# Show miss popup
		var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
		_spawn_damage_popup(0, false, target_world)
	
	# Balanced impact phase timing
	await get_tree().create_timer(0.9).timeout


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
			shooter_cover_level,
			shooter.officer_type
		)
		# Update movement range display (clear if out of AP)
		if shooter == selected_unit and shooter == deployed_officers[current_unit_index]:
			if shooter.has_ap():
				tactical_map.set_movement_range(shooter.get_grid_position(), shooter.move_range)
			else:
				tactical_map.clear_movement_range()
		
		# Update attackable enemy highlights (AP spent, enemy may have died)
		_update_attackable_highlights()
		
		# Re-enable end turn button BEFORE checking auto-end turn
		# so that _check_auto_end_turn can properly trigger _on_end_turn_pressed
		_set_animating(false)
		
		# Check if unit is out of AP and auto-end turn
		if shooter == deployed_officers[current_unit_index]:
			_check_auto_end_turn()
	else:
		# For non-player shooters (enemies), just re-enable the button
		_set_animating(false)
	
	# Balanced resolution transition
	await get_tree().create_timer(0.7).timeout


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


## Calculate resource drop amount based on enemy type
func _calculate_enemy_resource_drop(enemy_type: String) -> int:
	match enemy_type:
		"basic":
			return randi_range(3, 5)
		"heavy":
			return randi_range(8, 12)
		_:
			# Default fallback for unknown enemy types
			return 3


func _on_enemy_died(enemy: Node2D) -> void:
	print("Enemy %d died" % enemy.enemy_id)
	mission_enemies_killed += 1
	
	# Get enemy position before removal
	var pos = enemy.get_grid_position()
	var enemy_type = enemy.enemy_type
	
	# Remove from enemies list
	var idx = enemies.find(enemy)
	if idx >= 0:
		enemies.remove_at(idx)
	
	# Clear from map
	tactical_map.set_unit_position_solid(pos, false)
	
	# Play death animation before removing
	if enemy.has_method("play_death_animation"):
		await enemy.play_death_animation()
	
	# Spawn resource drop at enemy's death position
	var resource_amount = _calculate_enemy_resource_drop(enemy_type)
	var scrap_pile = ScrapPileScene.instantiate()
	scrap_pile.scrap_amount = resource_amount
	scrap_pile.set_grid_position(pos)
	tactical_map.add_interactable(scrap_pile, pos)
	
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
	
	# Check cooldown first
	if selected_unit.is_ability_on_cooldown():
		print("Ability on cooldown! %d turns remaining" % selected_unit.get_ability_cooldown())
		tactical_hud.show_combat_message("COOLDOWN: %d TURNS" % selected_unit.get_ability_cooldown(), Color(1, 0.5, 0))
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
				
				# Check if unit is out of AP and auto-end turn
				_check_auto_end_turn()
			else:
				print("Not enough AP for Overwatch")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
		
		"turret":
			if selected_unit.officer_type != "tech":
				print("Only Tech can use Turret!")
				return
			
			if not selected_unit.has_ap(1):
				print("Not enough AP for Turret")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter turret placement mode
			turret_mode = true
			print("Turret ability - click an adjacent walkable tile to place turret")
			tactical_hud.show_combat_message("SELECT ADJACENT TILE FOR TURRET", Color(0, 1, 1))
		
		"patch":
			if selected_unit.officer_type != "medic":
				print("Only Medics can use Patch!")
				return
			
			# Try to auto-heal adjacent ally
			_try_auto_patch()
		
		"charge":
			if selected_unit.officer_type != "heavy":
				print("Only Heavy can use Charge!")
				return
			
			if not selected_unit.has_ap(1):
				print("Not enough AP for Charge")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter charge targeting mode - show red range tiles
			charge_mode = true
			tactical_map.clear_movement_range()
			tactical_map.set_execute_range(selected_unit.get_grid_position(), 4)  # Reuse execute range (red tiles)
			print("Charge ability - click an enemy within 4 tiles to rush them")
			tactical_hud.show_combat_message("SELECT ENEMY TO CHARGE (4 TILES)", Color(1, 0.5, 0.1))
		
		"execute":
			if selected_unit.officer_type != "captain":
				print("Only Captain can use Execute!")
				return
			
			if not selected_unit.has_ap(1):
				print("Not enough AP for Execute")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter execute targeting mode - show red range tiles
			execute_mode = true
			tactical_map.clear_movement_range()
			tactical_map.set_execute_range(selected_unit.get_grid_position(), 4)
			print("Execute ability - click an enemy within 4 tiles below 50%% HP")
			tactical_hud.show_combat_message("SELECT ENEMY WITHIN 4 TILES (<50%% HP)", Color(1, 0.2, 0.2))
		
		"precision":
			if selected_unit.officer_type != "sniper":
				print("Only Sniper can use Precision Shot!")
				return
			
			if not selected_unit.has_ap(1):
				print("Not enough AP for Precision Shot")
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter precision targeting mode - can target any visible enemy
			precision_mode = true
			tactical_map.clear_movement_range()
			# No range display needed - can target any visible enemy
			print("Precision Shot - click any visible enemy for guaranteed 2x damage hit")
			tactical_hud.show_combat_message("SELECT ANY VISIBLE ENEMY", Color(0.6, 0.55, 0.8))


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
		
		# Take the shot (Overwatch is GUARANTEED HIT - 100% success)
		var hit_chance = 100.0  # Overwatch always hits - 100% attack success
		# Pass calculated damage (including flanking bonus) to ensure consistency
		var hit = officer.try_overwatch_shot(enemy_pos, hit_chance, damage)
		
		# Play attack animation for the overwatch shooter
		if officer.has_method("play_attack_animation"):
			officer.play_attack_animation()
		
		# Fire projectile
		var officer_world = officer.position
		var enemy_world = enemy.position
		projectile.fire(officer_world, enemy_world)
		await projectile.impact_reached
		
		# Overwatch always hits - 100% success, always apply damage
		# hit will always be true, but keeping check for safety
		if hit:
			if is_flanking:
				tactical_hud.show_combat_message("OVERWATCH FLANKING HIT!", Color(1, 0.5, 0.1))
			else:
				tactical_hud.show_combat_message("OVERWATCH HIT!", Color(0.2, 1, 0.2))
			enemy.take_damage(damage)
			_spawn_damage_popup(damage, true, enemy.position, false, is_flanking)
		
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
	
	# Disable end turn button during patch animation
	_set_animating(true)
	
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
					# Focus camera on healing action
					var medic_world = selected_unit.position
					var target_world = officer.position
					combat_camera.focus_on_action(medic_world, target_world)
					await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
					
					var heal_amount = int(officer.max_hp * 0.5)
					print("Healed %s for %d HP!" % [officer.officer_key, heal_amount])
					tactical_hud.show_combat_message("HEALED %s (+%d HP)" % [officer.officer_key.to_upper(), heal_amount], Color(0.2, 1, 0.2))
					
					# Show heal popup
					_spawn_damage_popup(heal_amount, true, officer.position, true)
					
					await get_tree().create_timer(1.0).timeout
					tactical_hud.hide_combat_message()
					
					# Return camera to tactical view
					combat_camera.return_to_tactical()
					
					_select_unit(selected_unit)
					
					# Re-enable end turn button after patch animation completes
					_set_animating(false)
					
					# Check if unit is out of AP and auto-end turn
					_check_auto_end_turn()
					return
	
	print("No injured allies adjacent to heal!")
	tactical_hud.show_combat_message("NO INJURED ALLIES NEARBY", Color(1, 0.5, 0))
	await get_tree().create_timer(1.0).timeout
	tactical_hud.hide_combat_message()
	_set_animating(false)


## Try to place a turret on an adjacent tile (Tech ability)
func _try_place_turret(grid_pos: Vector2i) -> void:
	turret_mode = false
	tactical_hud.hide_combat_message()
	
	if not selected_unit or selected_unit.officer_type != "tech":
		return
	
	# Disable end turn button during turret placement animation
	_set_animating(true)
	
	var tech_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - tech_pos.x) + abs(grid_pos.y - tech_pos.y)
	
	# Must be adjacent
	if distance != 1:
		print("Turret must be placed on adjacent tile (distance: %d)" % distance)
		tactical_hud.show_combat_message("MUST BE ADJACENT", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Must be a walkable, empty tile
	if not tactical_map.is_tile_walkable(grid_pos):
		print("Cannot place turret on non-walkable tile")
		tactical_hud.show_combat_message("INVALID TILE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Check no unit is already there
	var unit_at = tactical_map.get_unit_at(grid_pos)
	if unit_at:
		print("Cannot place turret on occupied tile")
		tactical_hud.show_combat_message("TILE OCCUPIED", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if selected_unit.use_turret():
		var turret = TurretUnitScene.instantiate()
		turret.set_grid_position(grid_pos)
		turret.position = Vector2(grid_pos.x * 32 + 16, grid_pos.y * 32 + 16)
		tactical_map.add_child(turret)
		turret.initialize()
		active_turrets.append(turret)
		
		# Focus camera on turret placement
		var tech_world = selected_unit.position
		var turret_world = turret.position
		combat_camera.focus_on_action(tech_world, turret_world)
		await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
		
		print("Turret placed at %s! Will auto-fire for 3 turns." % grid_pos)
		tactical_hud.show_combat_message("TURRET DEPLOYED!", Color(0, 1, 1))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		
		# Return camera to tactical view
		combat_camera.return_to_tactical()
		
		_select_unit(selected_unit)
		
		# Re-enable end turn button after turret placement animation completes
		_set_animating(false)
		
		# Check if unit is out of AP and auto-end turn
		_check_auto_end_turn()
	else:
		print("Failed to place turret (no AP or cooldown)")
		_set_animating(false)


## Try to charge an enemy (Heavy ability)
func _try_charge_enemy(grid_pos: Vector2i) -> void:
	charge_mode = false
	tactical_map.clear_execute_range()  # Clear red charge range tiles
	tactical_hud.hide_combat_message()
	
	if not selected_unit or selected_unit.officer_type != "heavy":
		return
	
	# Disable end turn button during charge animation
	_set_animating(true)
	
	var heavy_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - heavy_pos.x) + abs(grid_pos.y - heavy_pos.y)
	
	# Must be within 4 tiles
	if distance > 4 or distance < 1:
		print("Charge target must be within 4 tiles (distance: %d)" % distance)
		tactical_hud.show_combat_message("TARGET OUT OF RANGE (MAX 4)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Must be clicking on an enemy
	var target_enemy: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos and enemy.current_hp > 0:
			target_enemy = enemy
			break
	
	if not target_enemy:
		print("No enemy at that position")
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Must be visible
	if not _is_enemy_visible(target_enemy):
		print("Cannot charge: Enemy not visible")
		tactical_hud.show_combat_message("ENEMY NOT VISIBLE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not selected_unit.use_charge():
		print("Failed to use Charge (no AP or cooldown)")
		_set_animating(false)
		return
	
	# Find adjacent position to the enemy to move to
	var charge_destination = _find_charge_destination(heavy_pos, grid_pos)
	
	if charge_destination == heavy_pos:
		# Can't find path, but still deal damage at range
		print("No path for charge, attacking from current position")
	else:
		# Move heavy to adjacent tile of enemy
		tactical_map.set_unit_position_solid(heavy_pos, false)
		selected_unit.set_grid_position(charge_destination)
		
		# Animate rush movement (fast)
		var path = tactical_map.find_path(heavy_pos, charge_destination)
		if path and path.size() > 1:
			tactical_hud.show_combat_message("CHARGING!", Color(1, 0.5, 0.1))
			selected_unit.move_along_path(path)
			await selected_unit.movement_finished
		else:
			# Direct teleport if no path
			selected_unit.position = Vector2(charge_destination.x * 32 + 16, charge_destination.y * 32 + 16)
		
		tactical_map.set_unit_position_solid(charge_destination, true)
	
	# Calculate damage - instant kill basic enemies, heavy damage to heavy enemies
	var charge_damage: int
	var is_instant_kill: bool = false
	if target_enemy.enemy_type == "basic":
		# Instant kill basic enemies
		charge_damage = target_enemy.current_hp
		is_instant_kill = true
		print("CHARGE instant-kills basic enemy!")
	else:
		# Heavy damage to heavy enemies (2x base damage)
		charge_damage = selected_unit.base_damage * 2
		print("CHARGE deals %d damage to heavy enemy!" % charge_damage)
	
	# Face the enemy
	selected_unit.face_towards(grid_pos)
	
	# Perform melee attack animation
	await _perform_charge_melee_attack(selected_unit, target_enemy, charge_damage, is_instant_kill)
	
	await get_tree().create_timer(0.5).timeout
	tactical_hud.hide_combat_message()
	
	# Update fog/visibility/cover
	tactical_map.reveal_around(selected_unit.get_grid_position(), selected_unit.sight_range)
	_update_enemy_visibility()
	_update_unit_cover_indicator(selected_unit)
	_select_unit(selected_unit)
	
	# Re-enable end turn button after charge animation completes
	_set_animating(false)
	
	# Check if unit is out of AP and auto-end turn
	_check_auto_end_turn()


## Find the best adjacent tile to move to when charging an enemy
func _find_charge_destination(from: Vector2i, enemy_pos: Vector2i) -> Vector2i:
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var best_pos = from
	var best_distance = 999
	
	for dir in directions:
		var adjacent = enemy_pos + dir
		if adjacent == from:
			return from  # Already adjacent
		if tactical_map.is_tile_walkable(adjacent) and not tactical_map.get_unit_at(adjacent):
			var path = tactical_map.find_path(from, adjacent)
			if path and path.size() > 1:
				var path_distance = path.size() - 1
				if path_distance < best_distance:
					best_distance = path_distance
					best_pos = adjacent
	
	return best_pos


## Perform melee attack animation for charge ability
func _perform_charge_melee_attack(attacker: Node2D, target: Node2D, damage: int, is_instant_kill: bool) -> void:
	var attacker_sprite = attacker.get_node_or_null("Sprite")
	if not attacker_sprite:
		# Fallback: just deal damage without animation
		target.take_damage(damage)
		_spawn_damage_popup(damage, true, target.position)
		return
	
	# Focus camera on action (like normal attacks)
	var attacker_world = attacker.position
	var target_world = target.position
	combat_camera.focus_on_action(attacker_world, target_world)
	await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
	
	var original_pos = attacker_sprite.position
	var target_direction = (target.position - attacker.position).normalized()
	var lunge_distance = 12.0  # How far to lunge toward enemy
	
	# Phase 1: Wind-up (pull back slightly)
	tactical_hud.show_combat_message("CHARGE!", Color(1, 0.5, 0.1))
	var windup_tween = create_tween()
	windup_tween.tween_property(attacker_sprite, "position", original_pos - Vector2(target_direction.x * 4, 0), 0.1)
	windup_tween.parallel().tween_property(attacker_sprite, "modulate", Color(1.5, 0.8, 0.3, 1.0), 0.1)  # Orange glow
	await windup_tween.finished
	
	# Phase 2: Lunge forward (fast strike)
	var strike_tween = create_tween()
	strike_tween.tween_property(attacker_sprite, "position", original_pos + Vector2(target_direction.x * lunge_distance, target_direction.y * lunge_distance * 0.5), 0.08).set_ease(Tween.EASE_OUT)
	await strike_tween.finished
	
	# Phase 3: Impact - deal damage and show effects
	if is_instant_kill:
		tactical_hud.show_combat_message("DEVASTATING BLOW!", Color(1, 0.2, 0.1))
	else:
		tactical_hud.show_combat_message("HEAVY STRIKE! %d DMG" % damage, Color(1, 0.5, 0.1))
	
	# Impact flash on attacker
	var impact_tween = create_tween()
	impact_tween.tween_property(attacker_sprite, "modulate", Color(2.0, 1.5, 0.5, 1.0), 0.03)  # Bright flash
	
	# Deal damage and spawn popup
	target.take_damage(damage)
	_spawn_damage_popup(damage, true, target.position, false, true)  # Use flank style for charge hits
	
	# Screen shake effect (subtle)
	var camera_offset = combat_camera.offset
	var shake_tween = create_tween()
	shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(4, 2), 0.03)
	shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(-4, -2), 0.03)
	shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(2, -1), 0.03)
	shake_tween.tween_property(combat_camera, "offset", camera_offset, 0.05)
	
	await get_tree().create_timer(0.15).timeout
	
	# Phase 4: Return to original position
	var return_tween = create_tween()
	return_tween.tween_property(attacker_sprite, "position", original_pos, 0.15).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(attacker_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	await return_tween.finished
	
	# Return camera to tactical view (like normal attacks)
	combat_camera.return_to_tactical()


## Try to execute an enemy (Captain ability)
func _try_execute_enemy(grid_pos: Vector2i) -> void:
	execute_mode = false
	tactical_map.clear_execute_range()
	tactical_hud.hide_combat_message()
	
	if not selected_unit or selected_unit.officer_type != "captain":
		return
	
	# Disable end turn button during execute animation
	_set_animating(true)
	
	var captain_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - captain_pos.x) + abs(grid_pos.y - captain_pos.y)
	
	# Must be within 4 tiles
	if distance < 1 or distance > 4:
		print("Execute target must be within 4 tiles (distance: %d)" % distance)
		tactical_hud.show_combat_message("OUT OF RANGE (MAX 4 TILES)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Check line of sight
	if not has_line_of_sight(captain_pos, grid_pos):
		print("No line of sight for Execute")
		tactical_hud.show_combat_message("NO LINE OF SIGHT", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Must be clicking on an enemy
	var target_enemy: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos and enemy.current_hp > 0:
			target_enemy = enemy
			break
	
	if not target_enemy:
		print("No enemy at that position")
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Enemy must be below 50% HP
	var hp_percent = float(target_enemy.current_hp) / float(target_enemy.max_hp)
	if hp_percent > 0.5:
		print("Execute requires enemy below 50%% HP (currently %.0f%%)" % (hp_percent * 100))
		tactical_hud.show_combat_message("ENEMY HP TOO HIGH (NEED <50%%)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not selected_unit.use_execute():
		print("Failed to use Execute (no AP or cooldown)")
		_set_animating(false)
		return
	
	# Guaranteed kill - deal remaining HP as damage
	var execute_damage = target_enemy.current_hp
	selected_unit.face_towards(grid_pos)
	
	# Focus camera on action (like normal attacks)
	var shooter_world = selected_unit.position
	var target_world = Vector2(grid_pos.x * 32 + 16, grid_pos.y * 32 + 16)
	combat_camera.focus_on_action(shooter_world, target_world)
	await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
	
	# Cinematic execute sequence
	tactical_hud.show_combat_message("EXECUTING...", Color(1, 0.2, 0.2))
	await get_tree().create_timer(0.5).timeout
	
	# Fire projectile
	projectile.fire(shooter_world, target_world)
	await projectile.impact_reached
	
	# Apply lethal damage
	tactical_hud.show_combat_message("EXECUTED!", Color(1, 0.1, 0.1))
	target_enemy.take_damage(execute_damage)
	_spawn_damage_popup(execute_damage, true, target_enemy.position)
	
	await get_tree().create_timer(1.0).timeout
	tactical_hud.hide_combat_message()
	
	# Return camera to tactical view
	combat_camera.return_to_tactical()
	
	_select_unit(selected_unit)
	
	# Re-enable end turn button after execute animation completes
	_set_animating(false)
	
	# Check if unit is out of AP and auto-end turn
	_check_auto_end_turn()


## Try to use Precision Shot on an enemy (Sniper ability)
func _try_precision_shot(grid_pos: Vector2i) -> void:
	precision_mode = false
	tactical_map.clear_execute_range()
	tactical_hud.hide_combat_message()
	
	if not selected_unit or selected_unit.officer_type != "sniper":
		return
	
	# Disable end turn button during precision shot animation
	_set_animating(true)
	
	# Must be clicking on an enemy
	var target_enemy: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos and enemy.current_hp > 0:
			target_enemy = enemy
			break
	
	if not target_enemy:
		print("No enemy at that position")
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Only requirement: enemy must be visible (if player can see the sprite, they can use precision shot)
	if not _is_enemy_visible(target_enemy):
		print("Precision Shot requires visible enemy")
		tactical_hud.show_combat_message("ENEMY NOT VISIBLE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not selected_unit.use_precision_shot():
		print("Failed to use Precision Shot (no AP or cooldown)")
		_set_animating(false)
		return
	
	# Precision Shot deals 2x base damage (60 for sniper with 30 base damage)
	var precision_damage = selected_unit.base_damage * 2
	selected_unit.face_towards(grid_pos)
	
	# Focus camera on action
	var shooter_world = selected_unit.position
	var target_world = Vector2(grid_pos.x * 32 + 16, grid_pos.y * 32 + 16)
	combat_camera.focus_on_action(shooter_world, target_world)
	await get_tree().create_timer(0.2).timeout
	
	# Cinematic precision shot sequence
	tactical_hud.show_combat_message("TAKING AIM...", Color(0.6, 0.55, 0.8))
	await get_tree().create_timer(0.6).timeout
	
	# Play attack animation
	if selected_unit.has_method("play_attack_animation"):
		selected_unit.play_attack_animation()
	
	# Fire projectile
	projectile.fire(shooter_world, target_world)
	await projectile.impact_reached
	
	# Guaranteed hit with 2x damage
	tactical_hud.show_combat_message("PRECISION HIT!", Color(0.6, 0.55, 0.8))
	target_enemy.take_damage(precision_damage)
	_spawn_damage_popup(precision_damage, true, target_enemy.position)
	
	await get_tree().create_timer(1.0).timeout
	tactical_hud.hide_combat_message()
	
	# Return camera to tactical view
	combat_camera.return_to_tactical()
	
	_select_unit(selected_unit)
	
	# Re-enable end turn button after precision shot animation completes
	_set_animating(false)
	
	# Check if unit is out of AP and auto-end turn
	_check_auto_end_turn()


## Process all active turrets (auto-fire at nearest enemy)
func _process_turrets() -> void:
	var turrets_to_remove: Array[Node2D] = []
	
	for turret in active_turrets:
		# Tick down turn timer
		if not turret.tick_turn():
			# Turret expired
			print("Turret at %s expired!" % turret.get_grid_position())
			turrets_to_remove.append(turret)
			continue
		
		# Auto-fire at nearest visible enemy
		var turret_pos = turret.get_grid_position()
		var nearest_enemy: Node2D = null
		var nearest_dist = 999
		
		for enemy in enemies:
			if enemy.current_hp <= 0:
				continue
			if not _is_enemy_visible(enemy):
				continue
			
			var enemy_pos = enemy.get_grid_position()
			var dist = abs(enemy_pos.x - turret_pos.x) + abs(enemy_pos.y - turret_pos.y)
			
			if dist <= turret.shoot_range and dist < nearest_dist:
				if has_line_of_sight(turret_pos, enemy_pos):
					nearest_dist = dist
					nearest_enemy = enemy
		
		if nearest_enemy:
			var enemy_pos = nearest_enemy.get_grid_position()
			print("Turret at %s fires at enemy at %s!" % [turret_pos, enemy_pos])
			
			# Focus camera on turret attack
			var turret_world = turret.position
			var enemy_world = nearest_enemy.position
			combat_camera.focus_on_action(turret_world, enemy_world)
			await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
			
			tactical_hud.show_combat_message("TURRET FIRES!", Color(0, 1, 1))
			
			# Play turret attack animation
			if turret.has_method("play_attack_animation"):
				turret.play_attack_animation()
			
			# Fire projectile
			projectile.fire(turret_world, enemy_world)
			await projectile.impact_reached
			
			# Apply damage (turrets always hit)
			nearest_enemy.take_damage(turret.base_damage)
			_spawn_damage_popup(turret.base_damage, true, nearest_enemy.position)
			tactical_hud.show_combat_message("TURRET HIT! %d DMG" % turret.base_damage, Color(0, 1, 1))
			
			await get_tree().create_timer(0.7).timeout
			tactical_hud.hide_combat_message()
			
			# Return camera to tactical view
			combat_camera.return_to_tactical()
		
		# Update turret visual (remaining turns)
		turret.update_visual()
	
	# Remove expired turrets
	for turret in turrets_to_remove:
		active_turrets.erase(turret)
		tactical_hud.show_combat_message("TURRET EXPIRED", Color(0.5, 0.5, 0.5))
		turret.queue_free()
		await get_tree().create_timer(0.5).timeout
		tactical_hud.hide_combat_message()
