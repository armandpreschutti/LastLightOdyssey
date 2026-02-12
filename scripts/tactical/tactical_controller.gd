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
@onready var biome_background: Control = $BackgroundLayer/Background

var deployed_officers: Array[Node2D] = []
var enemies: Array[Node2D] = []
var selected_unit: Node2D = null
var selected_target: Vector2i = Vector2i(-1, -1)  # For targeting enemies
var execute_mode: bool = false  # When true, clicking selects execute target
var charge_mode: bool = false  # When true, clicking selects charge target
var is_charging: bool = false  # Track when a CHARGE movement is in progress to prevent movement_finished callback interference
var turret_mode: bool = false  # When true, clicking selects turret placement tile
var patch_mode: bool = false  # When true, clicking selects patch target
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
var is_scavenger_mission: bool = false  # Track if this is a scavenger mission
var mission_objectives: Array[MissionObjective] = []  # Current mission objectives
var stored_player_zoom: Vector2 = Vector2(1.0, 1.0)  # Store player's zoom level between turns

var FuelCrateScene: PackedScene
var ScrapPileScene: PackedScene
var HealthPackScene: PackedScene
var MiningEquipmentScene: PackedScene
var SecurityTerminalScene: PackedScene
var DataLogScene: PackedScene
var PowerCoreScene: PackedScene
var SampleCollectorScene: PackedScene
var BeaconScene: PackedScene
var NestScene: PackedScene
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
const MIN_HIT_CHANCE: float = 20.0  # Increased from 10% to 20% for more forgiving minimum
const MAX_HIT_CHANCE: float = 95.0
const FLANK_DAMAGE_BONUS: float = 0.50  # 50% bonus damage when flanking

# Cover attack bonuses (attacker in cover gets accuracy buff)
const FULL_COVER_ATTACK_BONUS: float = 10.0   # +10% hit chance when firing from full cover
const HALF_COVER_ATTACK_BONUS: float = 5.0   # +5% hit chance when firing from half cover


func _ready() -> void:
	FuelCrateScene = load("res://scenes/tactical/fuel_crate.tscn")
	ScrapPileScene = load("res://scenes/tactical/scrap_pile.tscn")
	HealthPackScene = load("res://scenes/tactical/health_pack.tscn")
	MiningEquipmentScene = load("res://scenes/tactical/mining_equipment.tscn")
	SecurityTerminalScene = load("res://scenes/tactical/security_terminal.tscn")
	DataLogScene = load("res://scenes/tactical/data_log.tscn")
	PowerCoreScene = load("res://scenes/tactical/power_core.tscn")
	SampleCollectorScene = load("res://scenes/tactical/sample_collector.tscn")
	BeaconScene = load("res://scenes/tactical/beacon.tscn")
	NestScene = load("res://scenes/tactical/nest.tscn")
	OfficerUnitScene = load("res://scenes/tactical/officer_unit.tscn")
	EnemyUnitScene = load("res://scenes/tactical/enemy_unit.tscn")
	TurretUnitScene = load("res://scenes/tactical/turret_unit.tscn")
	PauseMenuScene = load("res://scenes/ui/pause_menu.tscn")
	ConfirmDialogScene = load("res://scenes/ui/confirm_dialog.tscn")

	tactical_map.tile_clicked.connect(_on_tile_clicked)
	tactical_map.tile_hovered.connect(_on_tile_hovered)
	tactical_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	tactical_hud.extract_pressed.connect(_on_extract_pressed)
	tactical_hud.ability_used.connect(_on_ability_used)
	tactical_hud.ability_cancelled.connect(_cancel_ability_mode)
	tactical_hud.pause_pressed.connect(_show_pause_menu)
	
	# Hide the UILayer CanvasLayer on startup - CanvasLayer children render
	# independently of parent Node2D visibility, so we must hide it explicitly
	ui_layer.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and mission_active and not is_paused:
		# Cancel any active ability mode
		if turret_mode or charge_mode or execute_mode or precision_mode or patch_mode:
			_cancel_ability_mode()
			get_viewport().set_input_as_handled()
			return
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
	
	# Play beam-up animation on all surviving units before ending mission
	if deployed_officers.size() > 0:
		# Check if there are any surviving units
		var has_survivors = false
		for officer in deployed_officers:
			if officer.current_hp > 0:
				has_survivors = true
				break
		
		if has_survivors:
			await _play_beam_up_animation()
	
	# End mission as failure (colonist cost already applied by pause menu)
	_end_mission(false)


func start_mission(officer_keys: Array[String], biome_type: int = BiomeConfig.BiomeType.STATION, provided_objectives: Array[MissionObjective] = []) -> void:
	# Don't set mission_active yet - wait until after beam down animation
	mission_active = false
	current_turn = 1
	current_unit_index = 0
	mission_fuel_collected = 0
	mission_scrap_collected = 0
	mission_enemies_killed = 0
	deployed_officers.clear()
	enemies.clear()
	selected_target = Vector2i(-1, -1)

	# Check if this is a scavenger mission
	var current_node_type = GameState.node_types.get(GameState.current_node_index, -1)
	is_scavenger_mission = (current_node_type == EventManager.NodeType.SCAVENGE_SITE)

	GameState.enter_tactical_mode()

	# Generate map with biome type
	current_biome = biome_type as BiomeConfig.BiomeType
	
	# Initialize mission objectives based on biome (only for scavenger missions)
	mission_objectives.clear()
	if is_scavenger_mission:
		# Use provided objectives if available, otherwise generate random ones
		if not provided_objectives.is_empty():
			mission_objectives = provided_objectives.duplicate()
		else:
			mission_objectives = MissionObjective.ObjectiveManager.get_objectives_for_biome(current_biome)
		# Initialize objectives panel in HUD
		tactical_hud.initialize_objectives(mission_objectives)
	
	# Update background pattern based on biome
	if biome_background:
		biome_background.set_biome(current_biome)
	
	var generator = MapGenerator.new()
	# Pass voyage progression to scale map size
	var layout = generator.generate(current_biome, GameState.current_node_index, GameState.nodes_to_new_earth)
	
	# Set tactical map dimensions and biome theme
	var map_dims = generator.get_map_dimensions()
	tactical_map.set_map_dimensions(map_dims.x, map_dims.y)
	tactical_map.initialize_map(layout, current_biome)

	extraction_positions = generator.get_extraction_positions()

	# Spawn officers - start invisible and positioned above spawn points for beam down animation
	var spawn_positions = generator.get_spawn_positions()
	for i in range(mini(officer_keys.size(), spawn_positions.size())):
		var officer = OfficerUnitScene.instantiate()
		officer.movement_finished.connect(_on_unit_movement_finished.bind(officer))
		officer.died.connect(_on_officer_died)
		
		# Get world position for spawn point
		var world_pos = tactical_map.grid_to_world(spawn_positions[i])
		
		# Add to map first (this sets position to grid position)
		tactical_map.add_unit(officer, spawn_positions[i])
		officer.set_grid_position(spawn_positions[i])
		officer.initialize(officer_keys[i])  # Must be after add_unit so @onready vars are set
		
		# NOW position officer above spawn point and make invisible for beam down animation
		# (after add_unit which sets the position)
		officer.position = Vector2(world_pos.x, world_pos.y - 150)
		officer.modulate.a = 0.0
		
		deployed_officers.append(officer)

		# Reveal around spawn (will be visible after beam down)
		tactical_map.reveal_around(spawn_positions[i], officer.sight_range)

	# Spawn objective items FIRST (before resources) to prevent resources from spawning on objective tiles
	# Track all mission tile positions to exclude them from loot spawning
	var mission_tile_positions: Array[Vector2i] = []
	
	# Spawn mining equipment for asteroid biome missions with mining-related objectives
	if current_biome == BiomeConfig.BiomeType.ASTEROID and is_scavenger_mission:
		# Check if mission has mining-related objectives
		var has_activate_mining = false
		var has_extract_minerals = false
		var extract_minerals_max = 2
		
		for obj in mission_objectives:
			if obj.id == "activate_mining":
				has_activate_mining = true
			elif obj.id == "extract_minerals":
				has_extract_minerals = true
				extract_minerals_max = obj.max_progress
		
		# Spawn mining equipment based on objectives
		if has_activate_mining or has_extract_minerals:
			map_dims = generator.get_map_dimensions()
			var num_to_spawn = 1
			
			# For extract_minerals, spawn multiple units (one per required mineral)
			if has_extract_minerals:
				num_to_spawn = extract_minerals_max
			# For activate_mining, spawn 1 unit
			elif has_activate_mining:
				num_to_spawn = 1
			
			# Track positions we've already used to avoid duplicates
			var used_positions: Array[Vector2i] = []
			
			# Spawn mining equipment units
			for i in range(num_to_spawn):
				var mining_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
				if mining_pos != Vector2i(-1, -1):
					used_positions.append(mining_pos)
					mission_tile_positions.append(mining_pos)  # Track mission tile position
					tactical_map.add_mission_highlight(mining_pos) # Add highlight
					var mining_equipment = MiningEquipmentScene.instantiate()
					mining_equipment.set_grid_position(mining_pos)
					tactical_map.add_interactable(mining_equipment, mining_pos)
	
	# Spawn objective interactables for STATION biome missions
	if current_biome == BiomeConfig.BiomeType.STATION and is_scavenger_mission:
		# Check if mission has station-related objectives
		var has_hack_security = false
		var has_retrieve_logs = false
		var retrieve_logs_max = 3
		var has_repair_core = false
		
		for obj in mission_objectives:
			if obj.id == "hack_security":
				has_hack_security = true
			elif obj.id == "retrieve_logs":
				has_retrieve_logs = true
				retrieve_logs_max = obj.max_progress
			elif obj.id == "repair_core":
				has_repair_core = true
		
		# Spawn objective interactables based on objectives
		if has_hack_security or has_retrieve_logs or has_repair_core:
			map_dims = generator.get_map_dimensions()
			var used_positions: Array[Vector2i] = []
			
			# Spawn security terminal (binary objective - 1 unit)
			if has_hack_security:
				var terminal_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
				if terminal_pos != Vector2i(-1, -1):
					used_positions.append(terminal_pos)
					mission_tile_positions.append(terminal_pos)  # Track mission tile position
					tactical_map.add_mission_highlight(terminal_pos) # Add highlight
					var security_terminal = SecurityTerminalScene.instantiate()
					security_terminal.set_grid_position(terminal_pos)
					tactical_map.add_interactable(security_terminal, terminal_pos)
			
			# Spawn data logs (progress objective - multiple units)
			if has_retrieve_logs:
				for i in range(retrieve_logs_max):
					var log_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
					if log_pos != Vector2i(-1, -1):
						used_positions.append(log_pos)
						mission_tile_positions.append(log_pos)  # Track mission tile position
						tactical_map.add_mission_highlight(log_pos) # Add highlight
						var data_log = DataLogScene.instantiate()
						data_log.set_grid_position(log_pos)
						tactical_map.add_interactable(data_log, log_pos)
			
			# Spawn power core (binary objective - 1 unit)
			if has_repair_core:
				var core_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
				if core_pos != Vector2i(-1, -1):
					used_positions.append(core_pos)
					mission_tile_positions.append(core_pos)  # Track mission tile position
					tactical_map.add_mission_highlight(core_pos) # Add highlight
					var power_core = PowerCoreScene.instantiate()
					power_core.set_grid_position(core_pos)
					tactical_map.add_interactable(power_core, core_pos)
	
	# Spawn objective interactables for PLANET biome missions
	if current_biome == BiomeConfig.BiomeType.PLANET and is_scavenger_mission:
		# Check if mission has planet-related objectives
		var has_collect_samples = false
		var collect_samples_max = 5
		var has_activate_beacons = false
		var activate_beacons_max = 3
		var has_clear_nests = false
		
		for obj in mission_objectives:
			if obj.id == "collect_samples":
				has_collect_samples = true
				collect_samples_max = obj.max_progress
			elif obj.id == "activate_beacons":
				has_activate_beacons = true
				activate_beacons_max = obj.max_progress
			elif obj.id == "clear_nests":
				has_clear_nests = true
		
		# Spawn objective interactables based on objectives
		if has_collect_samples or has_activate_beacons or has_clear_nests:
			map_dims = generator.get_map_dimensions()
			var used_positions: Array[Vector2i] = []
			
			# Spawn sample collectors (progress objective - multiple units)
			if has_collect_samples:
				for i in range(collect_samples_max):
					var sample_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
					if sample_pos != Vector2i(-1, -1):
						used_positions.append(sample_pos)
						mission_tile_positions.append(sample_pos)  # Track mission tile position
						tactical_map.add_mission_highlight(sample_pos) # Add highlight
						var sample_collector = SampleCollectorScene.instantiate()
						sample_collector.set_grid_position(sample_pos)
						tactical_map.add_interactable(sample_collector, sample_pos)
			
			# Spawn beacons (progress objective - multiple units)
			if has_activate_beacons:
				for i in range(activate_beacons_max):
					var beacon_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
					if beacon_pos != Vector2i(-1, -1):
						used_positions.append(beacon_pos)
						mission_tile_positions.append(beacon_pos)  # Track mission tile position
						tactical_map.add_mission_highlight(beacon_pos) # Add highlight
						var beacon = BeaconScene.instantiate()
						beacon.set_grid_position(beacon_pos)
						tactical_map.add_interactable(beacon, beacon_pos)
			
			# Spawn nests (binary objective - 1 unit)
			if has_clear_nests:
				var nest_pos = _find_valid_mining_equipment_position(map_dims, used_positions)
				if nest_pos != Vector2i(-1, -1):
					used_positions.append(nest_pos)
					mission_tile_positions.append(nest_pos)  # Track mission tile position
					tactical_map.add_mission_highlight(nest_pos) # Add highlight
					var nest = NestScene.instantiate()
					nest.set_grid_position(nest_pos)
					tactical_map.add_interactable(nest, nest_pos)
	
	# Spawn loot AFTER objective items (only if no mission resource exists at that position)
	var loot_positions = generator.get_loot_positions()
	for loot_data in loot_positions:
		var loot_pos = loot_data["position"]
		
		# Skip if this position is a mission tile
		if loot_pos in mission_tile_positions:
			continue
		
		# Check if there's already a mission resource at this position (double-check)
		var existing = tactical_map.get_interactable_at(loot_pos)
		if existing != null and _is_mission_resource(existing):
			# Skip spawning regular loot if mission resource exists (mission resources take priority)
			continue
		
		var loot: Node2D
		if loot_data["type"] == "fuel":
			loot = FuelCrateScene.instantiate()
		elif loot_data["type"] == "health_pack":
			loot = HealthPackScene.instantiate()
		else:
			loot = ScrapPileScene.instantiate()
		_safe_add_interactable(loot, loot_pos)
	
	# Spawn enemies with difficulty-based scaling
	var difficulty = GameState.get_mission_difficulty()
	var _enemy_config = BiomeConfig.get_enemy_config(current_biome, difficulty)
	
	# Spawn boss enemy based on spawn chance
	var boss_spawn_chance = _calculate_boss_spawn_chance(difficulty)
	var _boss_spawned = false
	if randf() < boss_spawn_chance:
		var boss_pos = _find_valid_boss_spawn_position(generator)
		if boss_pos != Vector2i(-1, -1):
			var boss = EnemyUnitScene.instantiate()
			boss.set_grid_position(boss_pos)
			boss.movement_finished.connect(_on_enemy_movement_finished.bind(boss))
			boss.died.connect(_on_enemy_died.bind(boss))
			tactical_map.add_unit(boss, boss_pos)
			boss.initialize(0, "boss", current_biome, difficulty)
			boss.visible = false  # Start invisible until revealed
			enemies.append(boss)
			_boss_spawned = true
		else:
			# Fallback: if no valid 2x2 position found, try spawning boss at a regular enemy position
			push_warning("Could not find valid 2x2 boss spawn position, attempting fallback")
			var fallback_positions = generator.get_enemy_spawn_positions(difficulty)
			if fallback_positions.size() > 0:
				# Use the first enemy spawn position as fallback
				boss_pos = fallback_positions[0]
				var boss = EnemyUnitScene.instantiate()
				boss.set_grid_position(boss_pos)
				boss.movement_finished.connect(_on_enemy_movement_finished.bind(boss))
				boss.died.connect(_on_enemy_died.bind(boss))
				tactical_map.add_unit(boss, boss_pos)
				boss.initialize(0, "boss", current_biome, difficulty)
				boss.visible = false  # Start invisible until revealed
				enemies.append(boss)
				_boss_spawned = true
	
	# Spawn regular enemies
	# Check if mission requires minimum enemies for objectives (e.g., clear_passages needs 4 kills)
	var min_enemies_required = 0
	if is_scavenger_mission and not mission_objectives.is_empty():
		var objective = mission_objectives[0]
		if objective.id == "clear_passages" and objective.type == MissionObjective.ObjectiveType.PROGRESS:
			# Ensure at least enough enemies spawn to complete the objective
			min_enemies_required = objective.max_progress
	
	var enemy_positions = generator.get_enemy_spawn_positions(difficulty, min_enemies_required)
	var enemy_id = 1
	for enemy_pos in enemy_positions:
		var enemy = EnemyUnitScene.instantiate()
		enemy.set_grid_position(enemy_pos)
		enemy.movement_finished.connect(_on_enemy_movement_finished.bind(enemy))
		enemy.died.connect(_on_enemy_died.bind(enemy))
		tactical_map.add_unit(enemy, enemy_pos)
		# Select enemy type based on voyage progression
		var enemy_type = _select_enemy_type(difficulty)
		enemy.initialize(enemy_id, enemy_type, current_biome)
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
	ui_layer.visible = true

	# Center and zoom camera on spawn positions (where units will land) immediately (before fade in and beam down animations)
	if spawn_positions.size() > 0:
		_center_camera_on_spawn_positions(spawn_positions)

	# Play beam down animation for scavenger missions
	if is_scavenger_mission and deployed_officers.size() > 0:
		await _play_beam_down_animation()
	
	# Now activate the mission and start the turn
	mission_active = true
	# Show pause button only when mission is active
	tactical_hud.show_pause_button()

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
	
	# Tutorial: Trigger tactical_movement after first turn begins
	if TutorialManager.is_active() and TutorialManager.is_at_step("tactical_movement"):
		# Wait a frame for UI to be fully set up, then queue the step
		await get_tree().process_frame
		TutorialManager.queue_step(TutorialManager.current_step_index)


## Calculate boss spawn chance based on difficulty
## Currently set to 0% spawn rate
func _calculate_boss_spawn_chance(_difficulty: float) -> float:
	var current_node = GameState.current_node_index
	
	# Boss spawn only at nodes 40-49 (progress 0.8-0.98)
	# Linear interpolation from 0% at node 40 to 10% at node 49
	if current_node < 40:
		return 0.0
	
	if current_node >= 49:
		return 0.10
	
	# Interpolate between 0% and 10% for nodes 40-48
	var progress_in_range = float(current_node - 40) / float(49 - 40)
	return lerpf(0.0, 0.10, progress_in_range)


## Find a valid 2x2 spawn position for boss
func _find_valid_boss_spawn_position(generator: MapGenerator) -> Vector2i:
	var map_dims = generator.get_map_dimensions()
	var layout = generator.get_layout()
	var map_width = map_dims.x
	var map_height = map_dims.y
	
	# Try to find a valid 2x2 position (all 4 tiles must be floor, not near edges)
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		attempts += 1
		# Pick a random position, but avoid edges (need space for 2x2)
		var x = randi_range(2, map_width - 4)
		var y = randi_range(2, map_height - 4)
		var pos = Vector2i(x, y)
		
		# Check if all 4 tiles are valid floor tiles
		var valid = true
		for dx in range(2):
			for dy in range(2):
				var check_pos = pos + Vector2i(dx, dy)
				var tile_type = layout.get(check_pos, MapGenerator.TileType.WALL)
				if tile_type != MapGenerator.TileType.FLOOR:
					valid = false
					break
			if not valid:
				break
		
		if valid:
			return pos
	
	# Failed to find valid position
	return Vector2i(-1, -1)


## Select enemy type based on voyage progression
## Uses linear interpolation between early (nodes 0-10) and end (nodes 40-49) distributions
## Early: 90% basic, 10% heavy, 0% sniper, 0% elite
## End: 25% basic, 30% heavy, 20% sniper, 15% elite
func _select_enemy_type(difficulty: float) -> String:
	var current_node = GameState.current_node_index
	var total_nodes = GameState.nodes_to_new_earth
	
	# Calculate voyage progress (0.0 at start, 1.0 at end)
	var progress = float(current_node) / float(total_nodes)
	
	# Define spawn chances at early stage (nodes 0-10, progress ~0.0-0.2)
	var early_basic = 0.90
	var early_heavy = 0.10
	var early_sniper = 0.0
	var early_elite = 0.0
	
	# Define spawn chances at end stage (nodes 40-49, progress ~0.8-0.98)
	var end_basic = 0.25
	var end_heavy = 0.30
	var end_sniper = 0.20
	var end_elite = 0.15
	
	# Linear interpolation between early and end values
	var basic_chance = lerpf(early_basic, end_basic, progress)
	var heavy_chance_calc = lerpf(early_heavy, end_heavy, progress)
	var sniper_chance = lerpf(early_sniper, end_sniper, progress)
	var elite_chance = lerpf(early_elite, end_elite, progress)
	
	# Apply unlock thresholds: Sniper at difficulty 1.5+ (~node 17), Elite at difficulty 2.0+ (~node 33)
	if difficulty < 1.5:
		# Sniper not unlocked yet - redistribute its chance to basic and heavy proportionally
		var total_available = basic_chance + heavy_chance_calc
		if total_available > 0:
			basic_chance += sniper_chance * (basic_chance / total_available)
			heavy_chance_calc += sniper_chance * (heavy_chance_calc / total_available)
		else:
			basic_chance += sniper_chance
		sniper_chance = 0.0
	
	if difficulty < 2.0:
		# Elite not unlocked yet - redistribute its chance to other types proportionally
		var total_available = basic_chance + heavy_chance_calc + sniper_chance
		if total_available > 0:
			basic_chance += elite_chance * (basic_chance / total_available)
			heavy_chance_calc += elite_chance * (heavy_chance_calc / total_available)
			sniper_chance += elite_chance * (sniper_chance / total_available)
		else:
			basic_chance += elite_chance
		elite_chance = 0.0
	
	# Normalize probabilities to ensure they sum to 1.0
	var total = basic_chance + heavy_chance_calc + sniper_chance + elite_chance
	if total > 0:
		basic_chance /= total
		heavy_chance_calc /= total
		sniper_chance /= total
		elite_chance /= total
	
	# Weighted random selection
	var roll = randf()
	
	if roll < elite_chance:
		return "elite"
	roll -= elite_chance
	
	if roll < sniper_chance:
		return "sniper"
	roll -= sniper_chance
	
	if roll < heavy_chance_calc:
		return "heavy"
	
	# Default to basic
	return "basic"


func _on_tile_hovered(grid_pos: Vector2i) -> void:
	# Handle tooltip (only during scavenger missions)
	if mission_active and is_scavenger_mission:
		# Check if there's a unit at the hovered position
		if grid_pos == Vector2i(-1, -1):
			tactical_hud.hide_unit_tooltip()
		else:
			var unit = tactical_map.get_unit_at(grid_pos)
			if unit:
				tactical_hud.show_unit_tooltip(unit)
			else:
				tactical_hud.hide_unit_tooltip()
	else:
		tactical_hud.hide_unit_tooltip()
	
	# Update pathfinding path (works for all missions)
	if not mission_active:
		tactical_map.clear_pathfinding_path()
		return
	
	if grid_pos == Vector2i(-1, -1):
		tactical_map.clear_pathfinding_path()
		return
	
	# Update pathfinding path if there's a selected unit and it's their turn
	if selected_unit and selected_unit == deployed_officers[current_unit_index]:
		# Check if hovered tile is within movement range
		if tactical_map.movement_range_tiles.get(grid_pos, false):
			tactical_map.update_pathfinding_path(selected_unit.get_grid_position(), grid_pos)
		else:
			tactical_map.clear_pathfinding_path()
	else:
		tactical_map.clear_pathfinding_path()


func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if not mission_active:
		return
	
	# Prevent input during animations (including enemy overwatch)
	if is_animating:
		return
	
	# Check if it's the current unit's turn
	if not _is_current_unit_turn():
		return
	
	# Handle ability targeting modes
	if patch_mode and selected_unit and selected_unit.officer_type == "medic":
		_try_patch_target(grid_pos)
		return
	
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
			return
		
		if not _is_enemy_visible(enemy_at_pos):
			return
		
		if not selected_unit.can_shoot_at(grid_pos):
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
	# Cancel precision mode when selecting a unit
	if precision_mode:
		precision_mode = false
		tactical_hud.hide_combat_message()
		_update_precision_mode_highlights()
	# Cancel turret mode when selecting a unit
	if turret_mode:
		turret_mode = false
		tactical_hud.hide_combat_message()
	# Cancel patch mode when selecting a unit
	if patch_mode:
		patch_mode = false
		tactical_map.clear_heal_range()
		tactical_hud.hide_combat_message()
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
	
	# Check if target position has a turret
	if tactical_map.has_turret_at(target_pos):
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
	
	# Tutorial: Notify that a unit moved (only if scavenge_intro has been shown)
	if TutorialManager.is_active() and "scavenge_intro" in TutorialManager._shown_step_ids:
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
		# Preserve pathfinding path during movement animation
		tactical_map.clear_movement_range(true)


func _on_unit_movement_finished(unit: Node2D) -> void:
	# CRITICAL: Skip all processing for CHARGE movements to prevent turn sequencing issues
	# CHARGE handles all movement completion logic internally and this callback would interfere
	if is_charging:
		return
	
	var pos = unit.get_grid_position()

	# Mark new position as solid
	tactical_map.set_unit_position_solid(pos, true)

	# Reveal fog around new position
	tactical_map.reveal_around(pos, unit.sight_range)
	
	# Update cover indicator for this unit
	_update_unit_cover_indicator(unit)
	
	# Update enemy visibility (also updates attackable highlights)
	_update_enemy_visibility()
	
	# Check for nest objective completion (PLANET biome - must move to nest square)
	if current_biome == BiomeConfig.BiomeType.PLANET and is_scavenger_mission and unit in deployed_officers:
		var nest_interactable = tactical_map.get_interactable_at(pos)
		if nest_interactable and nest_interactable.has_method("get_objective_id"):
			var objective_id = nest_interactable.get_objective_id()
			if objective_id == "clear_nests":
				# Complete objective when player moves to nest square
				_complete_objective("clear_nests")
				# Remove the highlight
				tactical_map.remove_mission_highlight(pos)
				# Remove the nest after objective is completed
				nest_interactable.queue_free()
	
	# Auto-pickup: Check if there's an interactable at this position
	var interactable = tactical_map.get_interactable_at(pos)
	if interactable:
		# Skip auto-pickup for nests (handled above)
		if not (interactable.has_method("get_objective_id") and interactable.get_objective_id() == "clear_nests"):
			_auto_pickup(interactable, unit)
	
	# Check extraction availability
	_check_extraction_available()
	
	# Check for sniper overwatch (if officer moved within sniper overwatch range)
	if unit in deployed_officers:
		await _check_sniper_overwatch(unit, pos)
	
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
		# Update ability buttons with new AP after movement (if this is the selected unit)
		if selected_unit == unit:
			tactical_hud.update_ability_buttons(unit.officer_type, unit.current_ap, unit.get_ability_cooldown())
	
	# Check if unit is out of AP and auto-end turn
	if unit == deployed_officers[current_unit_index]:
		_check_auto_end_turn()


func _interact_with(interactable: Node2D) -> void:
	if selected_unit.use_ap(interactable.interaction_ap_cost):
		_pickup_item(interactable, selected_unit)
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
		
		# Update ability buttons with new AP after interaction
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		
		# Check if unit is out of AP and auto-end turn
		if selected_unit == deployed_officers[current_unit_index]:
			_check_auto_end_turn()


func _auto_pickup(interactable: Node2D, unit: Node2D) -> void:
	# Auto-pickup when landing on an item (no AP cost)
	_pickup_item(interactable, unit)


func _pickup_item(interactable: Node2D, unit: Node2D) -> void:
	# Check if this is an objective interactable (like mining equipment)
	if interactable.has_method("get_objective_id"):
		var objective_id = interactable.get_objective_id()
		
		# Remove mission highlight when interacting with any objective item
		tactical_map.remove_mission_highlight(interactable.get_grid_position())
		
		# ASTEROID objectives
		if objective_id == "activate_mining":
			# Handle both activate_mining (binary) and extract_minerals (progress) objectives
			# Complete activate_mining if that's the current objective
			_complete_objective("activate_mining")
			# Progress extract_minerals if that's the current objective
			_update_objective_progress("extract_minerals", 1)
			# Interact with the item (will mark it as activated but not remove it)
			interactable.interact()
			return
		
		# STATION objectives
		if objective_id == "hack_security":
			# Binary objective - complete it
			_complete_objective("hack_security")
			# Interact with the item (will mark it as activated but not remove it)
			interactable.interact()
			return
		
		if objective_id == "retrieve_logs":
			# Progress objective - update progress
			_update_objective_progress("retrieve_logs", 1)
			# Interact with the item (will remove it)
			interactable.interact()
			return
		
		if objective_id == "repair_core":
			# Binary objective - complete it
			_complete_objective("repair_core")
			# Interact with the item (will mark it as activated but not remove it)
			interactable.interact()
			return
		
		# PLANET objectives
		if objective_id == "collect_samples":
			# Progress objective - update progress
			_update_objective_progress("collect_samples", 1)
			# Interact with the item (will remove it)
			interactable.interact()
			return
		
		if objective_id == "activate_beacons":
			# Progress objective - update progress
			_update_objective_progress("activate_beacons", 1)
			# Interact with the item (will mark it as activated but not remove it)
			interactable.interact()
			return
		
		if objective_id == "clear_nests":
			# For PLANET biome, nest objective is completed by moving to the nest square, not by interaction
			# This code path should not be reached for nests (they're handled in movement_finished)
			# But keep it as a fallback in case interaction happens
			_complete_objective("clear_nests")
			# Interact with the item (will remove it)
			interactable.interact()
			return
	
	# Track what was collected by type (normal loot)
	# NOTE: Fuel and scrap do NOT count toward objectives - only objective-specific interactables do
	if interactable.has_method("get_item_type"):
		var item_type = interactable.get_item_type()
		var amount: int = 0
		if item_type == "fuel":
			# Play fuel pickup SFX
			if SFXManager:
				SFXManager.play_sfx_by_name("interactions", "fuel_pickup")
			mission_fuel_collected += 1
			amount = 1
		elif item_type == "scrap":
			# Play scrap pickup SFX
			if SFXManager:
				SFXManager.play_sfx_by_name("interactions", "scrap_pickup")
			if interactable.has_method("get_scrap_amount"):
				amount = interactable.get_scrap_amount()
				mission_scrap_collected += amount
			else:
				amount = 5
				mission_scrap_collected += 5
		elif item_type == "health_pack":
			# Check if unit is at full health - don't consume health pack if so
			if unit.current_hp >= unit.max_hp:
				# Unit is at full health, don't consume the health pack
				return
			
			# Play health pickup SFX
			if SFXManager:
				SFXManager.play_sfx_by_name("interactions", "health_pickup")
			
			# Health pack heals the unit for 62.5% max HP (same as Medic patch)
			var heal_amount = int(unit.max_hp * 0.625)
			unit.heal(heal_amount)
			amount = heal_amount
		else:
			# Generic pickup SFX for other items
			if SFXManager:
				SFXManager.play_sfx_by_name("interactions", "pickup")
		
		# Spawn pickup popup at unit position (slightly above unit, offset way to the left)
		if amount > 0 and unit:
			var popup_pos = unit.position + Vector2(-30, -20)  # Way to the left, up by 20px
			_spawn_pickup_popup(item_type, amount, popup_pos)
	else:
		# Generic pickup SFX for objective items
		if SFXManager:
			SFXManager.play_sfx_by_name("interactions", "pickup")
	
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
	
	# CRITICAL: Verify that selected_unit matches the current unit to prevent turn skipping
	# This ensures we're checking the correct unit, especially after async operations like CHARGE
	if selected_unit and selected_unit != current_unit:
		# If selected_unit doesn't match current_unit, we should still check current_unit
		# but log a warning for debugging
		pass
	
	# If unit has no AP remaining, automatically end their turn
	if not current_unit.has_ap():
		_on_end_turn_pressed()


func _on_end_turn_pressed() -> void:
	# Cancel precision mode when ending turn
	if precision_mode:
		precision_mode = false
		tactical_hud.hide_combat_message()
		_update_precision_mode_highlights()
	if not mission_active:
		return
	
	# Prevent ending turn while animations are playing
	if is_animating:
		return
	
	# Clear attackable highlights before changing turns
	_clear_attackable_highlights()
	
	# Track the unit whose turn just ended (for consecutive turn pause)
	var previous_unit: Node2D = null
	if current_unit_index < deployed_officers.size():
		previous_unit = deployed_officers[current_unit_index]
	
	# Advance to next unit's turn
	current_unit_index += 1
	var came_from_enemy_phase: bool = false
	
	# If all units have had their turn, advance to next round
	if current_unit_index >= deployed_officers.size():
		came_from_enemy_phase = true
		current_unit_index = 0
		
		# Store current zoom level before enemy turn (so we can restore it later)
		stored_player_zoom = combat_camera.zoom
		
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
		var next_unit = deployed_officers[current_unit_index]
		
		# Add a small pause when the same unit gets consecutive turns
		# (e.g., a lone officer with no enemies around)
		if previous_unit != null and next_unit == previous_unit and mission_active:
			_set_animating(true)
			await get_tree().create_timer(0.6).timeout
			# Re-check mission is still active after the pause
			if not mission_active:
				return
			_set_animating(false)
		
		_select_unit(next_unit)
		
		if came_from_enemy_phase:
			# Center camera on the active unit and restore player's previous zoom level
			# (Important when coming from enemy phase where camera might be zoomed in)
			var unit_pos = next_unit.get_grid_position()
			var world_pos = tactical_map.grid_to_world(unit_pos)
			combat_camera.center_on_position_with_zoom(world_pos, stored_player_zoom)
		else:
			# Just center camera (preserve zoom level) for player unit switching
			_center_camera_on_unit(next_unit)


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


## Center and zoom camera on spawn positions (where units will land)
func _center_camera_on_spawn_positions(spawn_positions: Array[Vector2i]) -> void:
	if spawn_positions.size() == 0:
		return
	
	# Calculate average position of all spawn positions in world space
	var avg_pos = Vector2.ZERO
	for spawn_pos in spawn_positions:
		var world_pos = tactical_map.grid_to_world(spawn_pos)
		avg_pos += world_pos
	
	avg_pos /= spawn_positions.size()
	
	# Account for MapContainer offset (300, 200) to center properly
	var map_offset = Vector2(300, 200)
	var camera_pos = avg_pos + map_offset
	
	# Snap camera to position with zoom (no animation) - use combat zoom zoomed out by 15%
	# zoom_max is Vector2(3.0, 3.0), so 15% zoomed out = 3.0 * 0.85 = 2.55
	var combat_zoom = Vector2(3.0, 3.0)  # zoom_max from combat_camera
	var zoomed_out = combat_zoom * 0.85  # Zoom out by 15%
	combat_camera.snap_to_position(camera_pos, false, zoomed_out)


## Center and zoom camera on all player units (called at mission start, before animations)
func _center_camera_on_all_units() -> void:
	if deployed_officers.size() == 0:
		return
	
	# Calculate average position of all player units in world space
	var avg_pos = Vector2.ZERO
	for officer in deployed_officers:
		var unit_pos = officer.get_grid_position()
		var world_pos = tactical_map.grid_to_world(unit_pos)
		avg_pos += world_pos
	
	avg_pos /= deployed_officers.size()
	
	# Account for MapContainer offset (300, 200) to center properly
	var map_offset = Vector2(300, 200)
	var camera_pos = avg_pos + map_offset
	
	# Snap camera to position with zoom (no animation) - use a zoomed in view
	combat_camera.snap_to_position(camera_pos, true)  # true = use combat zoom


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

	# Show extract button if:
	# 1. Normal extraction: at least one unit is in extraction zone and at least one unit is alive
	# 2. Scavenger mission with all enemies killed: all enemies are dead and at least one unit is alive
	var all_enemies_dead = enemies.is_empty()
	var can_extract_after_kill = is_scavenger_mission and all_enemies_dead and any_alive
	
	tactical_hud.set_extract_visible((any_on_extraction and any_alive) or can_extract_after_kill)


## End all unit turns by setting AP to 0 (used during extraction to freeze all actions)
func _end_all_unit_turns() -> void:
	# End all player unit turns
	for officer in deployed_officers:
		if officer.has_method("set_ap"):
			officer.set_ap(0)
	
	# End all enemy unit turns
	for enemy in enemies:
		if enemy.has_method("set_ap"):
			enemy.set_ap(0)


func _on_extract_pressed() -> void:
	if not mission_active:
		return

	# Check if all enemies are dead in a scavenger mission - if so, extract all units from anywhere
	var all_enemies_dead = enemies.is_empty()
	if is_scavenger_mission and all_enemies_dead:
		# Center camera on all units for beam-up animation
		var any_alive = false
		var avg_pos = Vector2.ZERO
		var alive_count = 0
		
		for officer in deployed_officers:
			if officer.current_hp > 0:
				any_alive = true
				var world_pos = tactical_map.grid_to_world(officer.get_grid_position())
				avg_pos += world_pos
				alive_count += 1
		
		if any_alive:
			# Center camera on average position of all units
			if alive_count > 0:
				avg_pos /= alive_count
				combat_camera.center_on_position_with_zoom(avg_pos, Vector2(1.5, 1.5))
			
			# End all unit turns to prevent actions during extraction
			_end_all_unit_turns()
			
			# Extract all surviving units directly (beam-up animation will play in _end_mission)
			_end_mission(true)
		return

	# Normal extraction logic (requires units to be in extraction zone)
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
	
	
	# If some units are outside the zone, show warning
	if units_outside_zone.size() > 0:
		_show_extraction_warning(units_in_zone, units_outside_zone)
	else:
		# All units are in zone, extract normally
		# End all unit turns to prevent actions during extraction
		_end_all_unit_turns()
		_end_mission(true)




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
	
	# End all unit turns to prevent actions during extraction
	_end_all_unit_turns()
	
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
		
		# Adjust current_unit_index if the removed unit was at or before current position
		# When an element is removed, all elements after it shift left by one position
		if officer_index <= current_unit_index:
			current_unit_index -= 1
			# Clamp to valid range (after removal, size decreased by 1)
			if deployed_officers.size() > 0:
				current_unit_index = max(0, min(current_unit_index, deployed_officers.size() - 1))
			else:
				current_unit_index = 0
	
	# Select another unit if the selected one died
	if selected_unit and selected_unit.officer_key == officer_key:
		selected_unit = null
		if deployed_officers.size() > 0:
			# Use the adjusted current_unit_index instead of always selecting index 0
			if current_unit_index < deployed_officers.size():
				_select_unit(deployed_officers[current_unit_index])
			else:
				# Fallback: select first unit if index is somehow invalid
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
	tactical_hud.hide_pause_button()  # Hide pause button when mission ends
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
	
	# Check objective completion and apply bonus rewards
	var bonus_fuel = 0
	var bonus_scrap = 0
	var bonus_colonists = 0
	var bonus_hull_repair = 0
	var objectives_data: Array = []
	if is_scavenger_mission and not mission_objectives.is_empty():
		# Check all objectives for completion (not just the first one)
		for objective in mission_objectives:
			# Double-check completion status for progress objectives (in case progress wasn't properly updated)
			if objective.type == MissionObjective.ObjectiveType.PROGRESS:
				if objective.progress >= objective.max_progress and not objective.completed:
					objective.completed = true
			
			if objective.completed:
				var bonuses = MissionObjective.ObjectiveManager.get_bonus_rewards(objective)
				bonus_fuel += bonuses.get("fuel", 0)
				bonus_scrap += bonuses.get("scrap", 0)
				bonus_colonists += bonuses.get("colonists", 0)
				bonus_hull_repair += bonuses.get("hull_repair", 0)
		
		# Note: Bonuses are tracked separately and applied to GameState separately
		# This keeps mission stats (add_mission_stats) showing only collected resources, not bonuses
		# Bonus rewards will be applied to GameState only on successful extraction
		
		# Build objectives data array for recap (include reward info)
		for obj in mission_objectives:
			var obj_type_str = "BINARY" if obj.type == MissionObjective.ObjectiveType.BINARY else "PROGRESS"
			var potential_rewards = MissionObjective.ObjectiveManager.get_potential_rewards(obj)
			objectives_data.append({
				"id": obj.id,
				"description": obj.description,
				"completed": obj.completed,
				"progress": obj.progress,
				"max_progress": obj.max_progress,
				"type": obj_type_str,
				"potential_rewards": potential_rewards
			})
	
	# Build stats dictionary
	var mission_stats: Dictionary = {
		"success": success,
		"fuel_collected": mission_fuel_collected,
		"scrap_collected": mission_scrap_collected,
		"enemies_killed": mission_enemies_killed,
		"turns_taken": current_turn,
		"officers_status": officers_status,
		"objective_completed": is_scavenger_mission and not mission_objectives.is_empty() and mission_objectives[0].completed,
		"bonus_fuel": bonus_fuel,
		"bonus_scrap": bonus_scrap,
		"bonus_colonists": bonus_colonists,
		"bonus_hull_repair": bonus_hull_repair,
		"objectives": objectives_data,
		"biome_type": current_biome,
	}
	
	# Apply all resources and rewards to GameState only on successful extraction
	if success:
		# Apply collected resources (fuel and scrap picked up during mission)
		GameState.fuel += mission_fuel_collected
		GameState.scrap += mission_scrap_collected
		
		# Apply bonus rewards from completed objectives (separate from collected resources)
		GameState.fuel += bonus_fuel
		GameState.scrap += bonus_scrap
		GameState.colonist_count += bonus_colonists
		if bonus_hull_repair > 0:
			GameState.repair_ship(bonus_hull_repair)
		
		# Accumulate stats to GameState for voyage recap
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
	_cleanup_tactical_ui()  # Ensure all UI elements are properly hidden
	tactical_map.clear_movement_range()

	mission_complete.emit(success, mission_stats)


## Clean up all tactical UI elements
func _cleanup_tactical_ui() -> void:
	tactical_hud.visible = false
	tactical_hud.hide_combat_message()
	tactical_hud.hide_pause_button()  # Hide pause button when leaving tactical mode
	# Clear any pending pause menu
	if current_pause_menu != null:
		current_pause_menu.queue_free()
		current_pause_menu = null
		is_paused = false
		get_tree().paused = false


## Play beam-up extraction animation - units float up with a light beam effect
func _play_beam_up_animation() -> void:
	# Hide HUD during animation
	tactical_hud.show_combat_message("EXTRACTION IN PROGRESS...", Color(0.4, 0.9, 1.0))
	
	# Play beam SFX
	SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/common_scene/beam.mp3")
	
	# Center camera on the group (animate from current position)
	if deployed_officers.size() > 0:
		var avg_pos = Vector2.ZERO
		var alive_count = 0
		for officer in deployed_officers:
			if officer.current_hp > 0:
				# Convert grid position to world coordinates (same as extraction logic)
				var world_pos = tactical_map.grid_to_world(officer.get_grid_position())
				avg_pos += world_pos
				alive_count += 1
		if alive_count > 0:
			avg_pos /= alive_count
			# Use center_on_position_with_zoom to animate smoothly from current position
			# Zoom in more for extraction animation (2.0x for closer view)
			var extraction_zoom = Vector2(2.0, 2.0)
			combat_camera.center_on_position_with_zoom(avg_pos, extraction_zoom)
	
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


## Play beam-down insertion animation - units descend from above with a light beam effect
func _play_beam_down_animation() -> void:
	# Show message during animation
	tactical_hud.show_combat_message("BEAMING DOWN...", Color(0.4, 0.9, 1.0))
	
	# Play beam SFX
	SFXManager.play_scene_sfx("res://assets/audio/sfx/scenes/common_scene/beam.mp3")
	
	# Camera should already be centered on spawn positions from start_mission
	# No need to reposition here - it's already in the right place
	
	await get_tree().create_timer(0.5).timeout
	
	# Create beam effects and animate each officer descending
	var beam_tweens: Array[Tween] = []
	
	for i in range(deployed_officers.size()):
		var officer = deployed_officers[i]
		
		# Get the target landing position (current position is already above, so get grid position and convert)
		var grid_pos = officer.get_grid_position()
		var target_world_pos = tactical_map.grid_to_world(grid_pos)
		var start_y = officer.position.y  # Current position (above)
		
		# Make sure officer is invisible
		officer.modulate.a = 0.0
		officer.modulate = Color(1.0, 1.0, 1.0, 0.0)  # Reset color
		
		# Create a vertical beam of light from above
		var beam = Line2D.new()
		beam.width = 2.0  # Start narrow
		beam.default_color = Color(0.3, 0.9, 1.0, 0.0)
		beam.add_point(Vector2(target_world_pos.x, start_y - 50))  # Beam starts from above officer
		beam.add_point(Vector2(target_world_pos.x, start_y + 40))   # Beam extends down to officer
		tactical_map.add_child(beam)
		
		# Stagger the beam appearance
		var delay = i * 0.3
		
		var beam_tween = create_tween()
		beam_tween.tween_interval(delay)
		
		# Widen and fade in the beam
		beam_tween.parallel().tween_property(beam, "width", 20.0, 0.3)
		beam_tween.parallel().tween_property(beam, "default_color:a", 0.5, 0.3)
		
		# Descend the officer while fading in
		beam_tween.parallel().tween_property(officer, "position:y", target_world_pos.y, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(0.2)
		beam_tween.parallel().tween_property(officer, "modulate:a", 1.0, 1.0).set_delay(0.2)
		
		# Update beam end point as officer descends
		beam_tween.parallel().tween_method(
			func(y: float):
			beam.set_point_position(1, Vector2(target_world_pos.x, y + 40))
			,
			start_y,
			target_world_pos.y,
			1.2
		).set_delay(0.2)
		
		# Add a subtle white flash as they materialize
		beam_tween.parallel().tween_property(officer, "modulate", Color(2.0, 2.5, 3.0, 1.0), 0.3).set_delay(0.5)
		beam_tween.parallel().tween_property(officer, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3).set_delay(0.8)
		
		# Narrow and fade the beam after officer lands
		beam_tween.tween_property(beam, "width", 2.0, 0.4)
		beam_tween.parallel().tween_property(beam, "default_color:a", 0.0, 0.4)
		beam_tween.tween_callback(beam.queue_free)
		
		beam_tweens.append(beam_tween)
	
	# Wait for all animations to complete
	if beam_tweens.size() > 0:
		await beam_tweens[-1].finished
	
	await get_tree().create_timer(0.3).timeout
	tactical_hud.hide_combat_message()


## Apply forgiveness curve for high hit chances (above 65%)
## Makes attacks more forgiving for player units when hit chance is high
func _apply_forgiveness_curve(hit_chance: float) -> float:
	if hit_chance <= 65.0:
		return hit_chance
	
	# Apply curve: effective_chance = hit_chance + (hit_chance - 65.0) * 0.4
	# This increases forgiveness proportionally as hit chance increases above 65%
	var effective_chance = hit_chance + (hit_chance - 65.0) * 0.4
	
	# Cap at maximum hit chance
	return minf(effective_chance, MAX_HIT_CHANCE)


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
	hit_chance = clampf(hit_chance, MIN_HIT_CHANCE, MAX_HIT_CHANCE)
	
	# Apply forgiveness curve for player units if hit chance is above 65%
	if shooter != null and shooter in deployed_officers:
		hit_chance = _apply_forgiveness_curve(hit_chance)
		# Re-clamp after applying curve (shouldn't exceed MAX_HIT_CHANCE, but safety check)
		hit_chance = minf(hit_chance, MAX_HIT_CHANCE)
	
	return hit_chance


## Get base hit chance based on shooter type and distance
func _get_base_hit_chance_for_shooter(shooter: Node2D, distance: int) -> float:
	# Adjacent shots are highly accurate for all classes
	if distance == 1:
		return 95.0  # Increased from 90% to 95% for point-blank shots
	elif distance == 2:
		return 90.0  # Increased from 85% to 90%
	
	# Determine shooter type
	var shooter_type = ""
	if shooter and "officer_type" in shooter:
		shooter_type = shooter.officer_type
	
	# Class-specific distance falloff
	match shooter_type:
		"scout":
			# Scout excels at long range
			if distance <= 4:
				return 85.0  # Increased from 80%
			elif distance <= 6:
				return 75.0  # Increased from 70%
			elif distance <= 8:
				return 65.0  # Increased from 60%
			else:
				return 50.0  # Increased from 45%
		"sniper":
			# Sniper has the best long-range accuracy, slightly weaker at close range
			if distance <= 2:
				return 85.0  # Increased from 80%
			elif distance <= 4:
				return 85.0  # Increased from 80%
			elif distance <= 6:
				return 80.0  # Increased from 75%
			elif distance <= 8:
				return 75.0  # Increased from 70%
			elif distance <= 10:
				return 70.0  # Increased from 65%
			else:
				return 65.0  # Increased from 60%
		"captain":
			# Captain is balanced
			if distance <= 4:
				return 80.0  # Increased from 75%
			elif distance <= 6:
				return 65.0  # Increased from 60%
			elif distance <= 8:
				return 50.0  # Increased from 45%
			else:
				return 35.0  # Increased from 30%
		"heavy":
			# Heavy is decent at close-mid range, weaker at distance
			if distance <= 4:
				return 80.0  # Increased from 75%
			elif distance <= 6:
				return 65.0  # Increased from 60%
			elif distance <= 8:
				return 45.0  # Increased from 40%
			else:
				return 30.0  # Increased from 25%
		"tech", "medic":
			# Support classes are weaker at range
			if distance <= 4:
				return 75.0  # Increased from 70%
			elif distance <= 6:
				return 55.0  # Increased from 50%
			elif distance <= 8:
				return 40.0  # Increased from 35%
			else:
				return 25.0  # Increased from 20%
		_:
			# Default (enemies and unknown)
			if distance <= 4:
				return 75.0  # Increased from 70%
			elif distance <= 6:
				return 60.0  # Increased from 55%
			elif distance <= 8:
				return 45.0  # Increased from 40%
			else:
				return 30.0  # Increased from 25%


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
	# 1. Check direct center-to-center line
	if _check_line_clear(shooter_pos, target_pos):
		return true
	
	# 2. If direct line is blocked, check "step-out" tiles (leaning around corners)
	# Check adjacent tiles (up, down, left, right)
	var neighbors = [
		Vector2i(0, -1), Vector2i(0, 1), 
		Vector2i(-1, 0), Vector2i(1, 0)
	]
	
	for offset in neighbors:
		var lean_pos = shooter_pos + offset
		
		# Can only lean into a tile if it doesn't block LOS itself (e.g. not a wall)
		# We don't care if a unit is there, just if it's logically "open" for vision
		if tactical_map.blocks_line_of_sight(lean_pos):
			continue
			
		# Check LOS from the lean position to the target
		if _check_line_clear(lean_pos, target_pos):
			return true
	
	return false


## Helper to check if a single line of sight path is clear
func _check_line_clear(from: Vector2i, to: Vector2i) -> bool:
	var tiles = _get_line_tiles(from, to)
	
	for tile_pos in tiles:
		# Skip start and end positions
		if tile_pos == from or tile_pos == to:
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
		tactical_hud.show_combat_message("NO LINE OF SIGHT", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		
		# If shooter is an enemy, consume AP to prevent infinite loops
		# This happens when AI thinks there's LOS but the actual LOS check fails
		if shooter in enemies and is_instance_valid(shooter) and shooter.has_method("use_ap"):
			shooter.use_ap(1)
		
		return
	
	# Calculate hit chance (pass shooter for class-specific calculations)
	var hit_chance = calculate_hit_chance(shooter_pos, target_pos, shooter)
	var base_damage = shooter.base_damage if "base_damage" in shooter else 25
	
	# Check for flanking and calculate bonus damage
	var is_flanking = is_flanking_attack(shooter_pos, target_pos)
	var damage = base_damage
	if is_flanking:
		damage = int(base_damage * (1.0 + FLANK_DAMAGE_BONUS))
	
		# Tutorial: Notify that a unit attacked (only if scavenge_intro has been shown)
		if TutorialManager.is_active() and "scavenge_intro" in TutorialManager._shown_step_ids:
			TutorialManager.notify_trigger("unit_attacked")
	
	# PHASE 1: AIMING (1.0s - balanced timing)
	await _phase_aiming(shooter, shooter_pos, target_pos, hit_chance, is_flanking, damage)
	
	# Safety: abort if shooter or target was freed during aiming phase
	if not is_instance_valid(shooter):
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 2: FIRING (slower projectile travel)
	var hit = await _phase_firing(shooter, shooter_pos, target_pos, hit_chance, damage)
	
	# Check for critical hit AFTER hit confirmation (only for player units and only if hit)
	var is_critical = false
	if hit and shooter in deployed_officers and "critical_hit_chance" in shooter:
		var crit_roll = randf() * 100.0
		if crit_roll <= shooter.critical_hit_chance:
			is_critical = true
			# Apply 2.5x damage multiplier (stacks with flanking)
			damage = int(damage * 2.5)
	
	# Safety: abort if shooter was freed during firing phase
	if not is_instance_valid(shooter):
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 3: IMPACT (0.9s - balanced impact reaction)
	# Target may have been freed - _phase_impact already has a null check
	var valid_target = target if is_instance_valid(target) else null
	await _phase_impact(shooter, target_pos, valid_target, hit, damage, is_flanking, is_critical)
	
	# Safety: abort if shooter was freed during impact phase
	if not is_instance_valid(shooter):
		tactical_hud.hide_combat_message()
		combat_camera.return_to_tactical()
		_set_animating(false)
		return
	
	# PHASE 4: RESOLUTION (0.7s - balanced transition back)
	await _phase_resolution(shooter)


## Phase 1: Aiming
func _phase_aiming(shooter: Node2D, shooter_pos: Vector2i, target_pos: Vector2i, hit_chance: float, is_flanking: bool = false, _damage: int = 0) -> void:
	# Focus camera on action
	var shooter_world = shooter.position
	var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
	combat_camera.focus_on_action(shooter_world, target_world)
	
	# Shooter faces target
	shooter.face_towards(target_pos)
	
	# Check for cover bonus to display
	var _attacker_cover_bonus = _get_attacker_cover_bonus(shooter_pos)
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
	
	# Play shooting SFX
	if SFXManager:
		SFXManager.play_sfx_by_name("combat", "shoot")
	
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
func _phase_impact(_shooter: Node2D, target_pos: Vector2i, target: Node2D, hit: bool, damage: int, is_flanking: bool = false, is_critical: bool = false) -> void:
	# Display hit/miss message with flanking and critical indicators
	if hit:
		# Play hit SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "hit")
		
		if is_critical and is_flanking:
			tactical_hud.show_combat_message("CRITICAL FLANKING HIT!", Color(1, 0.8, 0.0))  # Gold for critical + flanking
		elif is_critical:
			tactical_hud.show_combat_message("CRITICAL HIT!", Color(1, 0.9, 0.2))  # Gold-yellow for critical
		elif is_flanking:
			tactical_hud.show_combat_message("FLANKING HIT!", Color(1, 0.5, 0.1))
		else:
			tactical_hud.show_combat_message("HIT!", Color(1, 0.2, 0.2))
		
		# Apply damage (check validity in case target was freed during earlier phases)
		if is_instance_valid(target):
			if is_critical:
				# Screen shake effect for critical hits (more intense than regular hits)
				var camera_offset = combat_camera.offset
				var shake_tween = create_tween()
				shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(6, 3), 0.04)
				shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(-6, -3), 0.04)
				shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(4, -2), 0.04)
				shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(-3, 2), 0.04)
				shake_tween.tween_property(combat_camera, "offset", camera_offset, 0.06)
			target.take_damage(damage)

			# Show damage popup (pass critical flag)
			_spawn_damage_popup(damage, true, target.position, false, is_flanking, is_critical)
		else:
			# Target was freed - show popup at grid position instead
			var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
			_spawn_damage_popup(damage, true, target_world, false, is_flanking, is_critical)
	else:
		# Play miss SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "miss")
		
		tactical_hud.show_combat_message("MISS!", Color(0.6, 0.6, 0.6))
		
		# Show miss popup
		var target_world = Vector2(target_pos.x * 32 + 16, target_pos.y * 32 + 16)
		_spawn_damage_popup(0, false, target_world)
	
	# Balanced impact phase timing
	await get_tree().create_timer(0.9).timeout


## Phase 4: Resolution
func _phase_resolution(shooter: Node2D) -> void:
	# Hide combat message
	tactical_hud.hide_combat_message()
	
	# Return camera to tactical view (only for player units, enemies stay focused on action)
	if shooter in deployed_officers:
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
		
		# Update ability buttons with new AP after attack (if this is the selected unit)
		if shooter == selected_unit:
			tactical_hud.update_ability_buttons(shooter.officer_type, shooter.current_ap, shooter.get_ability_cooldown())
		
		# Check if unit is out of AP and auto-end turn
		if shooter == deployed_officers[current_unit_index]:
			_check_auto_end_turn()
	else:
		# For non-player shooters (enemies), just re-enable the button
		_set_animating(false)
	
	# Balanced resolution transition
	await get_tree().create_timer(0.7).timeout


## Spawn a damage popup number
func _spawn_damage_popup(damage: int, is_hit: bool, world_pos: Vector2, is_heal: bool = false, is_flank: bool = false, is_critical: bool = false) -> void:
	var popup = Label.new()
	popup.script = load("res://scripts/tactical/damage_popup.gd")
	damage_popup_container.add_child(popup)
	popup.initialize(damage, is_hit, world_pos, is_heal, is_flank, is_critical)


## Spawn a pickup popup for scrap or fuel
func _spawn_pickup_popup(item_type: String, amount: int, world_pos: Vector2) -> void:
	var popup = Label.new()
	popup.script = load("res://scripts/tactical/pickup_popup.gd")
	damage_popup_container.add_child(popup)
	popup.initialize(item_type, amount, world_pos)


## Execute AI turn for all enemies
func _execute_enemy_turn() -> void:
	
	for enemy in enemies:
		# Check if enemy is valid before processing
		if not is_instance_valid(enemy):
			continue
		
		if enemy.current_hp <= 0:
			continue
		
		# Enemies always act (they can see and move even if players can't see them)
		# The AI itself will handle whether they can detect players
		
		# Safety counter to prevent infinite loops
		var max_actions = 10
		var action_count = 0
		
		# Continue taking actions until enemy runs out of AP
		while is_instance_valid(enemy) and enemy.has_ap() and action_count < max_actions:
			action_count += 1
			
			# Check enemy validity again before taking action
			if not is_instance_valid(enemy):
				break
			
			# Enemy takes their action
			var decision = EnemyAI.decide_action(enemy, deployed_officers, tactical_map, self)
			
			match decision["action"]:
				"shoot":
					await execute_shot(enemy, decision["target_pos"], decision["target"])
					
					# Check if enemy was freed during shot (e.g., killed by overwatch)
					if not is_instance_valid(enemy):
						break
					
					await get_tree().create_timer(0.3).timeout  # Small delay for visual feedback
				
				"move":
					# Check enemy validity before movement
					if not is_instance_valid(enemy):
						break
					
					var old_pos = enemy.get_grid_position()
					var new_pos = decision["target_pos"]
					
					# Clear old position
					tactical_map.set_unit_position_solid(old_pos, false)

					# Move enemy
					enemy.use_ap(1)
					enemy.move_along_path(decision["path"])

					# Wait for movement to finish
					await enemy.movement_finished

					# Check if enemy was freed during movement
					if not is_instance_valid(enemy):
						break

					# Update grid position after animation completes
					enemy.set_grid_position(new_pos)

					# Mark new position as solid
					tactical_map.set_unit_position_solid(new_pos, true)
					
					# Update enemy visibility after movement
					_update_enemy_visibility()
					
					# Check for overwatch shots
					await _check_overwatch_shots(enemy, new_pos)
					
					# Check if enemy was freed during overwatch
					if not is_instance_valid(enemy):
						break
					
					await get_tree().create_timer(0.2).timeout  # Small delay
				
				"idle":
					# If AI decides to idle and enemy still has AP, break to prevent infinite loop
					# This should only happen if enemy truly can't do anything useful
					break
	


func _on_enemy_movement_finished(_enemy: Node2D) -> void:
	# Enemy movement completed
	pass


## Calculate resource drop amount based on enemy type
func _calculate_enemy_resource_drop(enemy_type: String) -> int:
	var base_amount: int
	match enemy_type:
		"basic":
			base_amount = randi_range(3, 5)
		"heavy":
			base_amount = randi_range(8, 12)
		"sniper":
			base_amount = randi_range(6, 9)  # Medium-high value
		"elite":
			base_amount = randi_range(12, 18)  # Highest value
		"boss":
			base_amount = randi_range(20, 30)  # Boss base value (will be multiplied by 2-3x)
		_:
			# Default fallback for unknown enemy types
			base_amount = 3
	
	# Reduce by 60% (multiply by 0.4, ensure minimum of 1)
	return max(1, roundi(base_amount * 0.4))


## Check if an interactable is a mission resource (has objective_id)
func _is_mission_resource(interactable: Node2D) -> bool:
	if interactable == null:
		return false
	return interactable.has_method("get_objective_id")


## Safely add an interactable, ensuring only one resource per tile
## Mission resources take priority - if a mission resource exists, don't add the new one
## If a regular resource exists, remove it and add the new one
func _safe_add_interactable(interactable: Node2D, grid_pos: Vector2i) -> bool:
	# Check if there's already an interactable at this position
	var existing = tactical_map.get_interactable_at(grid_pos)
	
	if existing != null:
		# If existing is a mission resource, don't add the new one (mission resources take priority)
		if _is_mission_resource(existing):
			interactable.queue_free()  # Clean up the new interactable we won't use
			return false
		
		# If existing is a regular resource, remove it and add the new one
		existing.queue_free()
	
	# Add the new interactable
	interactable.set_grid_position(grid_pos)
	tactical_map.add_interactable(interactable, grid_pos)
	return true


func _on_enemy_died(enemy: Node2D) -> void:
	mission_enemies_killed += 1
	
	# Update objectives based on enemy kills (only if objective matches)
	_update_objective_progress("clear_passages", 1)  # Enemies killed count as clearing passages for asteroid
	# Note: clear_nests objective is completed by interacting with nest structures, not by killing enemies
	
	# Get enemy position before removal
	var pos = enemy.get_grid_position()
	var enemy_type = enemy.enemy_type
	
	# Clear enemy target tile highlight if it was highlighted
	var enemy_size = Vector2i(1, 1)
	if enemy.get("unit_size") != null:
		enemy_size = enemy.unit_size
	tactical_map.clear_enemy_target_tile(pos, enemy_size)
	
	# Remove from enemies list
	var idx = enemies.find(enemy)
	if idx >= 0:
		enemies.remove_at(idx)
	
	# Clear from map (handle multi-tile units like bosses)
	if enemy.get("unit_size") != null and enemy.unit_size == Vector2i(2, 2):
		# Clear all 4 tiles for 2x2 boss
		for dx in range(2):
			for dy in range(2):
				var occupied_pos = pos + Vector2i(dx, dy)
				tactical_map.set_unit_position_solid(occupied_pos, false)
	else:
		tactical_map.set_unit_position_solid(pos, false)
	
	# Play death animation before removing
	if enemy.has_method("play_death_animation"):
		await enemy.play_death_animation()
	
	# Check if enemy should drop resources (10-15% chance)
	var drop_chance = randi_range(10, 15)  # Random chance between 10% and 15%
	var should_drop = randf() * 100.0 < drop_chance
	
	# Only spawn resource drop if chance succeeds
	if should_drop:
		# Spawn resource drop at enemy's death position
		var resource_amount = _calculate_enemy_resource_drop(enemy_type)
		
		# Bosses drop bonus loot (2-3x normal)
		if enemy_type == "boss":
			resource_amount = resource_amount * randi_range(2, 3)
			# Bosses drop both fuel and scrap, but at different positions within 2x2 area
			# Try to drop fuel at center first, then scrap at a different corner
			var fuel_amount = randi_range(2, 4)
			var boss_center_pos = pos + Vector2i(1, 1)  # Center of 2x2 area
			
			# Try to drop fuel at center
			var fuel_crate = FuelCrateScene.instantiate()
			fuel_crate.fuel_amount = fuel_amount
			var fuel_dropped = _safe_add_interactable(fuel_crate, boss_center_pos)
			
			# Try to drop scrap at a different position within the 2x2 area
			# Try corners of the 2x2 area: (0,0), (1,0), (0,1)
			var scrap_positions = [
				pos + Vector2i(0, 0),  # Top-left
				pos + Vector2i(1, 0),   # Top-right
				pos + Vector2i(0, 1)    # Bottom-left
			]
			
			var scrap_dropped = false
			for scrap_pos in scrap_positions:
				var scrap_pile = ScrapPileScene.instantiate()
				scrap_pile.scrap_amount = resource_amount
				if _safe_add_interactable(scrap_pile, scrap_pos):
					scrap_dropped = true
					break
			
			# If scrap couldn't be dropped at any corner and fuel wasn't dropped at center,
			# try dropping scrap at center (only if center is free)
			if not scrap_dropped and not fuel_dropped:
				var scrap_pile = ScrapPileScene.instantiate()
				scrap_pile.scrap_amount = resource_amount
				_safe_add_interactable(scrap_pile, boss_center_pos)
		else:
			# Regular enemies drop at their position
			var scrap_pile = ScrapPileScene.instantiate()
			scrap_pile.scrap_amount = resource_amount
			_safe_add_interactable(scrap_pile, pos)
	
	# Remove node
	enemy.queue_free()
	
	# Check if all enemies defeated
	if enemies.is_empty():
		# Check if extraction should become available (for scavenger missions)
		_check_extraction_available()
		# Show enemy elimination scene
		_show_enemy_elimination_scene()


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
	# Update precision mode highlights if active (enemies may have become visible)
	if precision_mode:
		_update_precision_mode_highlights()
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		enemy.visible = _is_enemy_visible(enemy)
	
	# Also update attackable highlights (visibility affects targeting)
	_update_attackable_highlights()


## Update which enemies are highlighted as attackable by the current unit
func _update_attackable_highlights() -> void:
	# First clear all highlights (both enemy highlights and tile highlights)
	tactical_map.clear_all_enemy_target_tiles()
	for enemy in enemies:
		if enemy.current_hp > 0:
			enemy.set_targetable(false)
	
	# If precision mode is active, don't set targetable here (precision mode handles it)
	if precision_mode:
		return
	
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
		
		# Also highlight the tile(s) the enemy is standing on
		var enemy_size = Vector2i(1, 1)
		if enemy.get("unit_size") != null:
			enemy_size = enemy.unit_size
		tactical_map.set_enemy_target_tile(enemy_pos, enemy_size)


## Clear all attackable enemy highlights
func _clear_attackable_highlights() -> void:
	tactical_map.clear_all_enemy_target_tiles()
	for enemy in enemies:
		if enemy.current_hp > 0:
			enemy.set_targetable(false)
			enemy.set_precision_mode(false)


## Update enemy highlights for precision mode (show all visible enemies)
func _update_precision_mode_highlights() -> void:
	# Clear all enemy target tiles first
	tactical_map.clear_all_enemy_target_tiles()
	
	for enemy in enemies:
		if enemy.current_hp > 0:
			enemy.set_precision_mode(precision_mode)
			
			# If precision mode is active and enemy is visible, highlight their tile(s)
			if precision_mode and enemy.visible:
				var enemy_pos = enemy.get_grid_position()
				var enemy_size = Vector2i(1, 1)
				if enemy.get("unit_size") != null:
					enemy_size = enemy.unit_size
				tactical_map.set_enemy_target_tile(enemy_pos, enemy_size)


func _on_ability_used(ability_type: String) -> void:
	if not selected_unit or selected_unit not in deployed_officers:
		return
	
	if selected_unit != deployed_officers[current_unit_index]:
		tactical_hud.show_combat_message("NOT YOUR TURN", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	# Check cooldown first
	if selected_unit.is_ability_on_cooldown():
		tactical_hud.show_combat_message("COOLDOWN: %d TURNS" % selected_unit.get_ability_cooldown(), Color(1, 0.5, 0))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		return
	
	match ability_type:
		"overwatch":
			if selected_unit.officer_type != "scout":
				return
			
			if selected_unit.toggle_overwatch():
				var status = "ACTIVATED" if selected_unit.overwatch_active else "DEACTIVATED"
				tactical_hud.show_combat_message("OVERWATCH %s" % status, Color(0.2, 1, 0.2) if selected_unit.overwatch_active else Color(1, 0.5, 0))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				# Update HUD to reflect AP change
				_select_unit(selected_unit)
				
				# Check if unit is out of AP and auto-end turn
				_check_auto_end_turn()
			else:
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
		
		"turret":
			if selected_unit.officer_type != "tech":
				return
			
			if not selected_unit.has_ap(1):
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter turret placement mode - show red range tiles (filtered to walkable and empty tiles only)
			turret_mode = true
			tactical_map.clear_movement_range()
			tactical_map.set_turret_placement_range(selected_unit.get_grid_position(), 2)  # Filtered execute range (red tiles)
			tactical_hud.show_combat_message("SELECT TILE FOR TURRET (2 TILES)", Color(0, 1, 1))
			tactical_hud.show_cancel_button()
		
		"patch":
			if selected_unit.officer_type != "medic":
				return
			
			if not selected_unit.has_ap(1):
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter patch targeting mode - show light green range tiles (all tiles within 3-tile range)
			patch_mode = true
			tactical_map.clear_movement_range()
			tactical_map.clear_execute_range()  # Clear any existing execute range highlights
			tactical_map.set_heal_range(selected_unit.get_grid_position(), 3, selected_unit, deployed_officers)
			tactical_hud.show_combat_message("SELECT TARGET TO HEAL (3 TILES)", Color(0.2, 1, 0.2))
			tactical_hud.show_cancel_button()
		
		"charge":
			if selected_unit.officer_type != "heavy":
				return
			
			if not selected_unit.has_ap(1):
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter charge targeting mode - show red range tiles
			charge_mode = true
			tactical_map.clear_movement_range()
			tactical_map.set_execute_range(selected_unit.get_grid_position(), 4)  # Reuse execute range (red tiles)
			tactical_hud.show_combat_message("SELECT ENEMY TO CHARGE (4 TILES)", Color(1, 0.5, 0.1))
			tactical_hud.show_cancel_button()
		
		"execute":
			if selected_unit.officer_type != "captain":
				return
			
			if not selected_unit.has_ap(1):
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter execute targeting mode - show red range tiles
			execute_mode = true
			tactical_map.clear_movement_range()
			tactical_map.set_execute_range(selected_unit.get_grid_position(), 4)
			tactical_hud.show_combat_message("SELECT ENEMY WITHIN 4 TILES (<50%% HP)", Color(1, 0.2, 0.2))
			tactical_hud.show_cancel_button()
		
		"precision":
			if selected_unit.officer_type != "sniper":
				return
			
			if not selected_unit.has_ap(1):
				tactical_hud.show_combat_message("NOT ENOUGH AP", Color(1, 0.3, 0.3))
				await get_tree().create_timer(1.0).timeout
				tactical_hud.hide_combat_message()
				return
			
			# Enter precision targeting mode - can target any visible enemy
			precision_mode = true
			tactical_map.clear_movement_range()
			# No range display needed - can target any visible enemy
			tactical_hud.show_combat_message("SELECT ANY VISIBLE ENEMY", Color(0.6, 0.55, 0.8))
			# Update enemy highlights for precision mode
			_update_precision_mode_highlights()
			tactical_hud.show_cancel_button()


## Cancel any active ability targeting mode
func _cancel_ability_mode() -> void:
	# Check which ability mode is active and clear it
	if turret_mode:
		turret_mode = false
		tactical_map.clear_execute_range()
		tactical_hud.hide_combat_message()
		tactical_hud.hide_cancel_button()
		# Restore movement range if unit still has AP
		if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	if charge_mode:
		charge_mode = false
		tactical_map.clear_execute_range()
		tactical_hud.hide_combat_message()
		tactical_hud.hide_cancel_button()
		# Restore movement range if unit still has AP
		if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	if execute_mode:
		execute_mode = false
		tactical_map.clear_execute_range()
		tactical_hud.hide_combat_message()
		tactical_hud.hide_cancel_button()
		# Restore movement range if unit still has AP
		if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	if precision_mode:
		precision_mode = false
		tactical_map.clear_execute_range()
		tactical_hud.hide_combat_message()
		_update_precision_mode_highlights()
		_update_attackable_highlights()
		tactical_hud.hide_cancel_button()
		# Restore movement range if unit still has AP
		if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	if patch_mode:
		patch_mode = false
		tactical_map.clear_heal_range()
		tactical_hud.hide_combat_message()
		tactical_hud.hide_cancel_button()
		# Restore movement range if unit still has AP
		if selected_unit and selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return


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
		tactical_hud.show_combat_message("OVERWATCH TRIGGERED!", Color(1, 1, 0.2))
		await get_tree().create_timer(0.8).timeout
		
		# Check for flanking and calculate damage
		var is_flanking = is_flanking_attack(officer_pos, enemy_pos)
		var damage = officer.base_damage
		if is_flanking:
			damage = int(officer.base_damage * (1.0 + FLANK_DAMAGE_BONUS))
		
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


## Check if any sniper enemies can trigger overwatch on officer movement
func _check_sniper_overwatch(officer: Node2D, officer_pos: Vector2i) -> void:
	# Check each sniper enemy for overwatch
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		# Only sniper enemies have automatic overwatch
		if enemy.enemy_type != "sniper":
			continue
		
		if enemy.overwatch_range <= 0:
			continue
		
		var enemy_pos = enemy.get_grid_position()
		var distance = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
		
		# Check if officer is within overwatch range (5 tiles for sniper)
		if distance > enemy.overwatch_range:
			continue
		
		# Check if officer is visible to sniper
		if not _is_officer_visible_to_enemy(officer, enemy):
			continue
		
		# Check line of sight
		if not has_line_of_sight(enemy_pos, officer_pos):
			continue
		
		# Sniper overwatch triggered!
		tactical_hud.show_combat_message("SNIPER OVERWATCH!", Color(1, 0.3, 0.3))
		await get_tree().create_timer(0.8).timeout
		
		# Calculate damage and hit chance
		var _hit_chance = calculate_hit_chance(enemy_pos, officer_pos, enemy)
		var _damage = enemy.base_damage
		
		# Check for flanking
		var is_flanking = is_flanking_attack(enemy_pos, officer_pos)
		if is_flanking:
			_damage = int(enemy.base_damage * (1.0 + FLANK_DAMAGE_BONUS))
		
		# Take the shot (execute_shot handles all the animation and damage)
		await execute_shot(enemy, officer_pos, officer)
		
		await get_tree().create_timer(0.5).timeout
		tactical_hud.hide_combat_message()
		
		# Only one sniper overwatch per movement
		break


## Check if an officer is visible to an enemy
func _is_officer_visible_to_enemy(officer: Node2D, enemy: Node2D) -> bool:
	var officer_pos = officer.get_grid_position()
	var enemy_pos = enemy.get_grid_position()
	
	# Check if officer tile is revealed (enemies can see revealed tiles)
	if not tactical_map.is_tile_revealed(officer_pos):
		return false
	
	# Check if officer is within enemy sight range
	var distance = abs(officer_pos.x - enemy_pos.x) + abs(officer_pos.y - enemy_pos.y)
	return distance <= enemy.sight_range


## Try to patch target at clicked position (Medic ability)
func _try_patch_target(grid_pos: Vector2i) -> void:
	patch_mode = false
	tactical_map.clear_heal_range()  # Clear light green heal range tiles
	tactical_hud.hide_combat_message()
	tactical_hud.hide_cancel_button()
	
	if not selected_unit or selected_unit.officer_type != "medic":
		return
	
	# Disable end turn button during patch animation
	_set_animating(true)
	
	var medic_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - medic_pos.x) + abs(grid_pos.y - medic_pos.y)
	
	# Must be within 3 tiles
	if distance > 3:
		tactical_hud.show_combat_message("OUT OF RANGE (MAX 3 TILES)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check if there's a unit at the clicked position
	var target_unit = tactical_map.get_unit_at(grid_pos)
	if not target_unit:
		tactical_hud.show_combat_message("NO TARGET AT TILE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check if target is a friendly officer (can heal self or allies)
	if target_unit not in deployed_officers:
		tactical_hud.show_combat_message("CANNOT HEAL TARGET", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check if target is injured
	if target_unit.current_hp >= target_unit.max_hp:
		tactical_hud.show_combat_message("TARGET AT FULL HEALTH", Color(1, 0.5, 0))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if selected_unit.use_patch(target_unit):
		# Play patch SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "patch")
		
		# Focus camera on healing action
		var medic_world = selected_unit.position
		var target_world = target_unit.position
		combat_camera.focus_on_action(medic_world, target_world)
		await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
		
		var heal_amount = int(target_unit.max_hp * 0.5 * selected_unit.get_healing_bonus())
		tactical_hud.show_combat_message("HEALED %s (+%d HP)" % [target_unit.officer_key.to_upper(), heal_amount], Color(0.2, 1, 0.2))
		
		# Show heal popup
		_spawn_damage_popup(heal_amount, true, target_unit.position, true)
		
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		
		# Return camera to tactical view
		combat_camera.return_to_tactical()
		
		_select_unit(selected_unit)
		
		# Re-enable end turn button after patch animation completes
		_set_animating(false)
		
		# Update ability buttons with new AP after patch (ability is now on cooldown)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		
		# Check if unit is out of AP and auto-end turn
		_check_auto_end_turn()
	else:
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)


## Try to place a turret within 2 tiles (Tech ability)
func _try_place_turret(grid_pos: Vector2i) -> void:
	turret_mode = false
	tactical_map.clear_execute_range()  # Clear red turret range tiles
	tactical_hud.hide_combat_message()
	tactical_hud.hide_cancel_button()
	
	if not selected_unit or selected_unit.officer_type != "tech":
		return
	
	# Disable end turn button during turret placement animation
	_set_animating(true)
	
	var tech_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - tech_pos.x) + abs(grid_pos.y - tech_pos.y)
	
	# Must be within 2 tiles
	if distance > 2:
		tactical_hud.show_combat_message("OUT OF RANGE (MAX 2 TILES)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Must be a walkable, empty tile
	if not tactical_map.is_tile_walkable(grid_pos):
		tactical_hud.show_combat_message("INVALID TILE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check no unit is already there
	var unit_at = tactical_map.get_unit_at(grid_pos)
	if unit_at:
		tactical_hud.show_combat_message("TILE OCCUPIED", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check no interactable is already there (resources, mission units, etc.)
	var interactable_at = tactical_map.get_interactable_at(grid_pos)
	if interactable_at:
		tactical_hud.show_combat_message("TILE OCCUPIED", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check no turret is already there
	if tactical_map.has_turret_at(grid_pos):
		tactical_hud.show_combat_message("TURRET ALREADY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if selected_unit.use_turret():
		# Play turret SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "turret")
		
		var turret = TurretUnitScene.instantiate()
		turret.set_grid_position(grid_pos)
		turret.position = Vector2(grid_pos.x * 32 + 16, grid_pos.y * 32 + 16)
		tactical_map.add_child(turret)
		turret.initialize()
		active_turrets.append(turret)
		
		# Mark turret tile as solid so units cannot move through it
		tactical_map.set_unit_position_solid(grid_pos, true)
		
		# Focus camera on turret placement
		var tech_world = selected_unit.position
		var turret_world = turret.position
		combat_camera.focus_on_action(tech_world, turret_world)
		await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
		
		tactical_hud.show_combat_message("TURRET DEPLOYED!", Color(0, 1, 1))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		
		# Return camera to tactical view
		combat_camera.return_to_tactical()
		
		_select_unit(selected_unit)
		
		# Re-enable end turn button after turret placement animation completes
		_set_animating(false)
		
		# Update ability buttons with new AP after turret (ability is now on cooldown)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		
		# Check if unit is out of AP and auto-end turn
		_check_auto_end_turn()
	else:
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())


## Try to charge an enemy (Heavy ability)
func _try_charge_enemy(grid_pos: Vector2i) -> void:
	charge_mode = false
	tactical_map.clear_execute_range()  # Clear red charge range tiles
	tactical_hud.hide_combat_message()
	tactical_hud.hide_cancel_button()
	
	if not selected_unit or selected_unit.officer_type != "heavy":
		return
	
	# Store reference to heavy unit to prevent issues if selected_unit changes during async operations
	var heavy_unit = selected_unit
	
	# Disable end turn button during charge animation
	_set_animating(true)
	
	var heavy_pos = heavy_unit.get_grid_position()
	var distance = abs(grid_pos.x - heavy_pos.x) + abs(grid_pos.y - heavy_pos.y)
	
	# Must be within 4 tiles
	if distance > 4 or distance < 1:
		tactical_hud.show_combat_message("TARGET OUT OF RANGE (MAX 4)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		if heavy_unit == selected_unit:
			tactical_hud.update_ability_buttons(heavy_unit.officer_type, heavy_unit.current_ap, heavy_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if heavy_unit == deployed_officers[current_unit_index] and heavy_unit.has_ap():
			var unit_pos = heavy_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, heavy_unit.move_range)
		return
	
	# Must be clicking on an enemy
	var target_enemy: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos and enemy.current_hp > 0:
			target_enemy = enemy
			break
	
	if not target_enemy:
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		if heavy_unit == selected_unit:
			tactical_hud.update_ability_buttons(heavy_unit.officer_type, heavy_unit.current_ap, heavy_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if heavy_unit == deployed_officers[current_unit_index] and heavy_unit.has_ap():
			var unit_pos = heavy_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, heavy_unit.move_range)
		return
	
	# Must be visible
	if not _is_enemy_visible(target_enemy):
		tactical_hud.show_combat_message("ENEMY NOT VISIBLE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		if heavy_unit == selected_unit:
			tactical_hud.update_ability_buttons(heavy_unit.officer_type, heavy_unit.current_ap, heavy_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if heavy_unit == deployed_officers[current_unit_index] and heavy_unit.has_ap():
			var unit_pos = heavy_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, heavy_unit.move_range)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not heavy_unit.use_charge():
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		if heavy_unit == selected_unit:
			tactical_hud.update_ability_buttons(heavy_unit.officer_type, heavy_unit.current_ap, heavy_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if heavy_unit == deployed_officers[current_unit_index] and heavy_unit.has_ap():
			var unit_pos = heavy_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, heavy_unit.move_range)
		return
	
	# Find adjacent position to the enemy to move to
	var charge_destination = _find_charge_destination(heavy_pos, grid_pos)
	
	if charge_destination == heavy_pos:
		# Can't find path, but still deal damage at range
		pass
	else:
		# Move heavy to adjacent tile of enemy
		tactical_map.set_unit_position_solid(heavy_pos, false)
		heavy_unit.set_grid_position(charge_destination)
		
		# Animate rush movement (fast)
		# CRITICAL: Set is_charging flag to prevent movement_finished callback from interfering with turn sequencing
		is_charging = true
		var path = tactical_map.find_path(heavy_pos, charge_destination)
		if path and path.size() > 1:
			tactical_hud.show_combat_message("CHARGING!", Color(1, 0.5, 0.1))
			heavy_unit.move_along_path(path)
			await heavy_unit.movement_finished
		else:
			# Direct teleport if no path
			heavy_unit.position = Vector2(charge_destination.x * 32 + 16, charge_destination.y * 32 + 16)
		
		tactical_map.set_unit_position_solid(charge_destination, true)
		# Clear the charging flag after movement completes
		is_charging = false
	
	# Calculate damage - instant kill basic enemies, heavy damage to heavy enemies
	var charge_damage: int
	var is_instant_kill: bool = false
	if target_enemy.enemy_type == "basic":
		# Instant kill basic enemies
		charge_damage = target_enemy.current_hp
		is_instant_kill = true
	else:
		# Heavy damage to heavy enemies (2x base damage)
		charge_damage = heavy_unit.base_damage * 2
	
	# Face the enemy
	heavy_unit.face_towards(grid_pos)
	
	# Perform melee attack animation - use stored heavy_unit reference
	await _perform_charge_melee_attack(heavy_unit, target_enemy, charge_damage, is_instant_kill)
	
	await get_tree().create_timer(0.5).timeout
	tactical_hud.hide_combat_message()
	
	# Update fog/visibility/cover
	tactical_map.reveal_around(heavy_unit.get_grid_position(), heavy_unit.sight_range)
	_update_enemy_visibility()
	_update_unit_cover_indicator(heavy_unit)
	_select_unit(heavy_unit)
	
	# Re-enable end turn button after charge animation completes
	_set_animating(false)
	
	# Update ability buttons with new AP after charge (ability is now on cooldown)
	if heavy_unit == selected_unit:
		tactical_hud.update_ability_buttons(heavy_unit.officer_type, heavy_unit.current_ap, heavy_unit.get_ability_cooldown())
	
	# Check if unit is out of AP and auto-end turn
	# CRITICAL: Only check auto-end turn if heavy_unit is still the current unit
	# This prevents turn skipping if the unit reference or index changed during async operations
	if current_unit_index < deployed_officers.size() and heavy_unit == deployed_officers[current_unit_index]:
		if not heavy_unit.has_ap():
			_on_end_turn_pressed()


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
	# CRITICAL: Only allow heavy units to perform charge animation
	# Check if attacker has officer_type property and verify it's a heavy unit
	if not "officer_type" in attacker or attacker.officer_type != "heavy":
		# If attacker is not a heavy unit, just deal damage without animation
		target.take_damage(damage)
		_spawn_damage_popup(damage, true, target.position)
		return
	
	# Validate attacker is still valid
	if not is_instance_valid(attacker):
		return
	
	var attacker_sprite = attacker.get_node_or_null("Sprite")
	if not attacker_sprite or not is_instance_valid(attacker_sprite):
		# Fallback: just deal damage without animation
		target.take_damage(damage)
		_spawn_damage_popup(damage, true, target.position)
		return
	
	# CRITICAL: Stop idle animation and kill any existing attack tweens to prevent conflicts
	if attacker.has_method("_stop_idle_animation"):
		attacker._stop_idle_animation()
	if attacker.has_method("_kill_attack_tween"):
		attacker._kill_attack_tween()
	
	# Store original position and state for cleanup
	var original_pos = attacker_sprite.position
	var original_modulate = attacker_sprite.modulate
	
	# Store tween references for cleanup
	var charge_tweens: Array[Tween] = []
	
	# Helper function to safely create and track tweens
	var create_charge_tween = func() -> Tween:
		var tween = create_tween()
		charge_tweens.append(tween)
		return tween
	
	# Cleanup function to ensure sprite is reset even if animation is interrupted
	var cleanup_charge_animation = func():
		if is_instance_valid(attacker_sprite):
			attacker_sprite.position = original_pos
			attacker_sprite.modulate = original_modulate
		# Kill all charge tweens
		for tween in charge_tweens:
			if tween and tween.is_valid():
				tween.kill()
		charge_tweens.clear()
		# Restart idle animation
		if is_instance_valid(attacker) and attacker.has_method("_start_idle_animation"):
			attacker._start_idle_animation()
	
	# Focus camera on action (like normal attacks)
	var attacker_world = attacker.position
	var target_world = target.position
	combat_camera.focus_on_action(attacker_world, target_world)
	await get_tree().create_timer(0.2).timeout  # Wait for camera to zoom in
	
	# Validate sprite is still valid after await
	if not is_instance_valid(attacker_sprite):
		cleanup_charge_animation.call()
		return
	
	var target_direction = (target.position - attacker.position).normalized()
	var lunge_distance = 12.0  # How far to lunge toward enemy
	
	# Phase 1: Wind-up (pull back slightly)
	tactical_hud.show_combat_message("CHARGE!", Color(1, 0.5, 0.1))
	var windup_tween = create_charge_tween.call()
	windup_tween.tween_property(attacker_sprite, "position", original_pos - Vector2(target_direction.x * 4, 0), 0.1)
	windup_tween.parallel().tween_property(attacker_sprite, "modulate", Color(1.5, 0.8, 0.3, 1.0), 0.1)  # Orange glow
	await windup_tween.finished
	
	# Validate sprite is still valid after await
	if not is_instance_valid(attacker_sprite):
		cleanup_charge_animation.call()
		return
	
	# Phase 2: Lunge forward (fast strike)
	var strike_tween = create_charge_tween.call()
	strike_tween.tween_property(attacker_sprite, "position", original_pos + Vector2(target_direction.x * lunge_distance, target_direction.y * lunge_distance * 0.5), 0.08).set_ease(Tween.EASE_OUT)
	await strike_tween.finished
	
	# Validate sprite is still valid after await
	if not is_instance_valid(attacker_sprite):
		cleanup_charge_animation.call()
		return
	
	# Phase 3: Impact - deal damage and show effects
	if is_instant_kill:
		tactical_hud.show_combat_message("DEVASTATING BLOW!", Color(1, 0.2, 0.1))
	else:
		tactical_hud.show_combat_message("HEAVY STRIKE! %d DMG" % damage, Color(1, 0.5, 0.1))
	
	# Impact flash on attacker
	var impact_tween = create_charge_tween.call()
	impact_tween.tween_property(attacker_sprite, "modulate", Color(2.0, 1.5, 0.5, 1.0), 0.03)  # Bright flash
	await impact_tween.finished
	
	# Validate sprite and target are still valid
	if not is_instance_valid(attacker_sprite):
		cleanup_charge_animation.call()
		return
	
	# Deal damage and spawn popup
	var enemy_hp_before = target.current_hp if is_instance_valid(target) else 0
	if is_instance_valid(target):
		# Play charge SFX right as the hit connects
		if SFXManager:
			SFXManager.play_sfx_by_name("combat", "charge")
		
		target.take_damage(damage)
		var enemy_died = target.current_hp <= 0 and enemy_hp_before > 0
		_spawn_damage_popup(damage, true, target.position, false, true)  # Use flank style for charge hits
		
		# Screen shake effect (subtle)
		var camera_offset = combat_camera.offset
		var shake_tween = create_charge_tween.call()
		shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(4, 2), 0.03)
		shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(-4, -2), 0.03)
		shake_tween.tween_property(combat_camera, "offset", camera_offset + Vector2(2, -1), 0.03)
		shake_tween.tween_property(combat_camera, "offset", camera_offset, 0.05)
		await shake_tween.finished
		
		# Wait for enemy damage flash animation to complete (takes ~0.38 seconds total)
		await get_tree().create_timer(0.4).timeout
		
		# If enemy died, wait for death animation to complete
		# Note: _on_enemy_died will handle playing the animation, but we need to wait for it
		# Since signal handlers run asynchronously, we wait for the animation directly
		if enemy_died and is_instance_valid(target) and target.has_method("play_death_animation"):
			await target.play_death_animation()
	
	# Validate sprite is still valid after all awaits
	if not is_instance_valid(attacker_sprite):
		cleanup_charge_animation.call()
		return
	
	# Phase 4: Return to original position
	var return_tween = create_charge_tween.call()
	return_tween.tween_property(attacker_sprite, "position", original_pos, 0.15).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(attacker_sprite, "modulate", original_modulate, 0.15)
	await return_tween.finished
	
	# Explicitly ensure sprite position is reset (fixes stuck animation bug)
	# This ensures the sprite is always in the correct position even if tween had precision issues
	if is_instance_valid(attacker_sprite):
		attacker_sprite.position = original_pos
		attacker_sprite.modulate = original_modulate
	
	# Cleanup all tweens
	for tween in charge_tweens:
		if tween and tween.is_valid():
			tween.kill()
	charge_tweens.clear()
	
	# Restart idle animation to prevent sprite from being stuck
	if is_instance_valid(attacker) and attacker.has_method("_start_idle_animation"):
		attacker._start_idle_animation()
	
	# Return camera to tactical view and wait for it to complete
	combat_camera.return_to_tactical()
	await combat_camera.camera_transition_complete


## Try to execute an enemy (Captain ability)
func _try_execute_enemy(grid_pos: Vector2i) -> void:
	execute_mode = false
	tactical_map.clear_execute_range()
	tactical_hud.hide_combat_message()
	tactical_hud.hide_cancel_button()
	
	if not selected_unit or selected_unit.officer_type != "captain":
		return
	
	# Disable end turn button during execute animation
	_set_animating(true)
	
	var captain_pos = selected_unit.get_grid_position()
	var distance = abs(grid_pos.x - captain_pos.x) + abs(grid_pos.y - captain_pos.y)
	
	# Must be within 4 tiles
	if distance < 1 or distance > 4:
		tactical_hud.show_combat_message("OUT OF RANGE (MAX 4 TILES)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Check line of sight - Removed per design change (can execute any enemy in range)
	# if not has_line_of_sight(captain_pos, grid_pos):
	# 	tactical_hud.show_combat_message("NO LINE OF SIGHT", Color(1, 0.3, 0.3))
	# 	await get_tree().create_timer(1.0).timeout
	# 	tactical_hud.hide_combat_message()
	# 	_select_unit(selected_unit)
	# 	_set_animating(false)
	# 	# Update ability buttons (ability not used, button should be re-enabled)
	# 	tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
	# 	# Restore movement range if unit still has AP
	# 	if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
	# 		var unit_pos = selected_unit.get_grid_position()
	# 		tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
	# 	return
	
	# Must be clicking on an enemy
	var target_enemy: Node2D = null
	for enemy in enemies:
		if enemy.get_grid_position() == grid_pos and enemy.current_hp > 0:
			target_enemy = enemy
			break
	
	if not target_enemy:
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Enemy must be below 50% HP
	var hp_percent = float(target_enemy.current_hp) / float(target_enemy.max_hp)
	if hp_percent > 0.5:
		tactical_hud.show_combat_message("ENEMY HP TOO HIGH (NEED <50%%)", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		# Restore movement range if unit still has AP
		if selected_unit == deployed_officers[current_unit_index] and selected_unit.has_ap():
			var unit_pos = selected_unit.get_grid_position()
			tactical_map.set_movement_range(unit_pos, selected_unit.move_range)
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not selected_unit.use_execute():
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
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
	
	# Play execute SFX just before impact to build anticipation
	await get_tree().create_timer(0.05).timeout  # Small delay for anticipation
	if SFXManager:
		SFXManager.play_sfx_by_name("combat", "execute")
	
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
	
	# Update ability buttons with new AP after execute (ability is now on cooldown)
	tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
	
	# Check if unit is out of AP and auto-end turn
	_check_auto_end_turn()


## Try to use Precision Shot on an enemy (Sniper ability)
func _try_precision_shot(grid_pos: Vector2i) -> void:
	precision_mode = false
	tactical_map.clear_execute_range()
	tactical_hud.hide_combat_message()
	# Update enemy highlights when exiting precision mode
	_update_precision_mode_highlights()
	tactical_hud.hide_cancel_button()
	
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
		tactical_hud.show_combat_message("NO ENEMY THERE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		return
	
	# Only requirement: enemy must be visible (if player can see the sprite, they can use precision shot)
	if not _is_enemy_visible(target_enemy):
		tactical_hud.show_combat_message("ENEMY NOT VISIBLE", Color(1, 0.3, 0.3))
		await get_tree().create_timer(1.0).timeout
		tactical_hud.hide_combat_message()
		_select_unit(selected_unit)
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
		return
	
	# Use the ability (spends AP and starts cooldown)
	if not selected_unit.use_precision_shot():
		_set_animating(false)
		# Update ability buttons (ability not used, button should be re-enabled)
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
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
	
	# Play precision shot SFX just before impact to build anticipation
	await get_tree().create_timer(0.05).timeout  # Small delay for anticipation
	if SFXManager:
		SFXManager.play_sfx_by_name("combat", "precision_shot")
	
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
	
	# Update ability buttons with new AP after precision shot (ability is now on cooldown)
	if selected_unit == selected_unit:  # Always true, but keeping pattern consistent
		tactical_hud.update_ability_buttons(selected_unit.officer_type, selected_unit.current_ap, selected_unit.get_ability_cooldown())
	
	# Check if unit is out of AP and auto-end turn
	_check_auto_end_turn()


## Update objective progress by ID (only if it matches current mission objective)
func _update_objective_progress(objective_id: String, progress_amount: int = 1) -> void:
	if not is_scavenger_mission or mission_objectives.is_empty():
		return
	
	# Find the objective that matches the ID (check all objectives, not just first)
	var objective: MissionObjective = null
	for obj in mission_objectives:
		if obj.id == objective_id:
			objective = obj
			break
	
	# If no matching objective found, return early
	if objective == null:
		return
	
	# Only update if not already completed
	if not objective.completed:
		var was_completed = objective.completed
		objective.add_progress(progress_amount)
		tactical_hud.update_objective(objective_id)
		
		# Show scene and notification if objective just completed
		if not was_completed and objective.completed:
			_show_objective_complete_scene(objective)
			_show_objective_complete_notification(objective)


## Complete a binary objective (only if it matches current mission objective)
func _complete_objective(objective_id: String) -> void:
	if not is_scavenger_mission or mission_objectives.is_empty():
		return
	
	# Find the objective that matches the ID (check all objectives, not just first)
	var objective: MissionObjective = null
	for obj in mission_objectives:
		if obj.id == objective_id:
			objective = obj
			break
	
	# If no matching objective found, return early
	if objective == null:
		return
	
	# Only complete if not already completed
	if not objective.completed:
		objective.set_completed()
		tactical_hud.update_objective(objective_id)
		
		# Show scene and notification with bonus reward
		_show_objective_complete_scene(objective)
		_show_objective_complete_notification(objective)


## Find a valid position for mining equipment (middle area of map, avoiding edges and occupied tiles)
func _find_valid_mining_equipment_position(map_dims: Vector2i, used_positions: Array[Vector2i] = []) -> Vector2i:
	# Try to find a position in the middle area of the map
	# Avoid edges (3 tiles from each edge) and extraction zone (bottom-left)
	var min_x = 3
	var max_x = map_dims.x - 4
	var min_y = 3
	var max_y = map_dims.y - 4
	
	# Try random positions first
	for _attempt in range(100):
		var pos = Vector2i(randi_range(min_x, max_x), randi_range(min_y, max_y))
		
		# Skip if already used
		if pos in used_positions:
			continue
		
		# Check if tile is walkable (floor tile)
		if not tactical_map.is_tile_walkable(pos):
			continue
		
		# Check if there's already an interactable at this position
		var existing_interactable = tactical_map.get_interactable_at(pos)
		if existing_interactable != null:
			continue
		
		# Check if there's a unit at this position
		var unit_at_pos = tactical_map.get_unit_at(pos)
		if unit_at_pos != null:
			continue
		
		# Valid position found
		return pos
	
	# Fallback: search exhaustively
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			
			# Skip if already used
			if pos in used_positions:
				continue
			
			# Check if tile is walkable
			if not tactical_map.is_tile_walkable(pos):
				continue
			
			# Check for existing interactable
			var existing_interactable = tactical_map.get_interactable_at(pos)
			if existing_interactable != null:
				continue
			
			# Check for unit
			var unit_at_pos = tactical_map.get_unit_at(pos)
			if unit_at_pos != null:
				continue
			
			# Valid position found
			return pos
	
	return Vector2i(-1, -1)  # No valid position found


## Show objective completion scene (pauses gameplay)
func _show_objective_complete_scene(objective: MissionObjective) -> void:
	# Get alive officers
	var alive_officers: Array[String] = []
	for officer in deployed_officers:
		if officer.current_hp > 0:
			alive_officers.append(officer.officer_key)
	
	# Get rewards
	var rewards = MissionObjective.ObjectiveManager.get_bonus_rewards(objective)
	
	# Pause tactical gameplay
	is_paused = true
	get_tree().paused = true
	
	# Get reference to the scene dialog (via main node's DialogLayer)
	var main_node = get_tree().get_first_node_in_group("main")
	var scene_dialog = main_node.get_node_or_null("DialogLayer/ObjectiveCompleteSceneDialog") if main_node else null
	if scene_dialog:
		scene_dialog.show_scene(objective, current_biome, alive_officers, rewards)
		# Wait for scene to be dismissed
		await scene_dialog.scene_dismissed
		# Resume gameplay
		is_paused = false
		get_tree().paused = false
	else:
		# Fallback: if scene dialog not found, just unpause
		is_paused = false
		get_tree().paused = false


## Show enemy elimination scene (pauses gameplay)
func _show_enemy_elimination_scene() -> void:
	# Get alive officers
	var alive_officers: Array[String] = []
	for officer in deployed_officers:
		if officer.current_hp > 0:
			alive_officers.append(officer.officer_key)
	
	# Pause tactical gameplay
	is_paused = true
	get_tree().paused = true
	
	# Get reference to the scene dialog (via main node's DialogLayer)
	var main_node = get_tree().get_first_node_in_group("main")
	var scene_dialog = main_node.get_node_or_null("DialogLayer/EnemyEliminationSceneDialog") if main_node else null
	if scene_dialog:
		scene_dialog.show_scene(current_biome, alive_officers)
		# Wait for scene to be dismissed
		await scene_dialog.scene_dismissed
		# Resume gameplay
		is_paused = false
		get_tree().paused = false
	else:
		# Fallback: if scene dialog not found, just unpause
		is_paused = false
		get_tree().paused = false


## Show objective completion notification with bonus reward info
func _show_objective_complete_notification(objective: MissionObjective) -> void:
	var bonuses = MissionObjective.ObjectiveManager.get_bonus_rewards(objective)
	var reward_parts: Array[String] = []
	
	if bonuses.get("fuel", 0) > 0:
		reward_parts.append("+%d FUEL" % bonuses.get("fuel", 0))
	if bonuses.get("scrap", 0) > 0:
		reward_parts.append("+%d SCRAP" % bonuses.get("scrap", 0))
	if bonuses.get("colonists", 0) > 0:
		reward_parts.append("+%d COLONISTS" % bonuses.get("colonists", 0))
	if bonuses.get("hull_repair", 0) > 0:
		reward_parts.append("+%d%% HULL" % bonuses.get("hull_repair", 0))
	
	if reward_parts.size() > 0:
		var bonus_text = " ".join(reward_parts)
		tactical_hud.show_combat_message("OBJECTIVE COMPLETE! %s" % bonus_text, Color(0.2, 1.0, 0.3))
		# Auto-hide after delay (non-blocking)
		var timer = get_tree().create_timer(3.0)  # Slightly longer for multiple rewards
		timer.timeout.connect(func(): tactical_hud.hide_combat_message())


## Process all active turrets (auto-fire at nearest enemy)
func _process_turrets() -> void:
	# Don't process turrets if mission is not active
	if not mission_active:
		return
	
	var turrets_to_remove: Array[Node2D] = []
	
	for turret in active_turrets:
		# Tick down turn timer
		if not turret.tick_turn():
			# Turret expired
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
			var _enemy_pos = nearest_enemy.get_grid_position()
			
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
		var turret_pos = turret.get_grid_position()
		active_turrets.erase(turret)
		# Unmark turret tile as solid so units can move through it again
		tactical_map.set_unit_position_solid(turret_pos, false)
		# Only show expiration message if mission is still active
		if mission_active:
			tactical_hud.show_combat_message("TURRET EXPIRED", Color(0.5, 0.5, 0.5))
			turret.queue_free()
			await get_tree().create_timer(0.5).timeout
			tactical_hud.hide_combat_message()
		else:
			# Mission ended, just remove the turret silently
			turret.queue_free()
