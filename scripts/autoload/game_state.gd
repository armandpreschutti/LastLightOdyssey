extends Node
## Global game state for Last Light Odyssey
## Manages resources, officers, and game progression

signal fuel_changed(new_value: int)
signal cash_changed(new_value: int)
signal intel_changed(new_value: int)
signal integrity_changed(new_value: int)
signal officer_died(officer_type: String)
signal officer_injured(officer_key: String)
signal game_over(reason: String)
signal game_won(ending_type: String)
signal developer_flags_changed
signal officer_progression_changed # Emitted when any officer gains XP/DL or unlocks an ability

const SETTINGS_CONFIG_PATH: String = "user://settings.cfg"
const SETTINGS_DEVELOPER_SECTION: String = "developer"

## Developer feature keys — used for persistence in settings.cfg [developer] section.
const DEV_KEYS: Array[String] = [
	"protect_fuel", "protect_integrity", "protect_cash", "protect_intel",
	"officers_maxed", "story_intel", "raider_fast", "raider_1_jump_per_turn", "wormhole_4x", "story_tactical_ease", "raider_tactical_ease",
	"skip_raider_spawn_camera", "skip_story_spawn_camera", "skip_mission_recap_animations"
]

# --- Ability & Officer Definitions ---
const OFFICER_COLOR = {
	"captain": Color(1.0, 0.69, 0.0),
	"scout":   Color(0.2, 1.0, 0.5),
	"tech":    Color(0.4, 0.9, 1.0),
	"medic":   Color(1.0, 0.5, 0.8),
	"heavy":   Color(1.0, 0.4, 0.3),
	"sniper":  Color(0.6, 0.55, 0.7),
}

# Ability definitions: id → {name, desc, level, slot, modifiers}
const ABILITY_DEFS: Dictionary = {
	# BASE ABILITIES (Level 1)
	"execute":            {"name": "Execute",            "desc": "Guaranteed kill on any enemy within 4 tiles that is below 50% HP. 2-turn cooldown.",                                                            "level": 1, "slot": "base", "type": "active", "cost": 1},
	"overwatch":          {"name": "Overwatch",          "desc": "Take a reaction shot at the first enemy that moves in Line of Sight. Guaranteed hit. 2-turn cooldown.",                                          "level": 1, "slot": "base", "type": "active", "cost": 1},
	"turret":             {"name": "Turret",             "desc": "Deploy an auto-firing sentry on an adjacent tile. Lasts 3 turns. 2-turn cooldown.",                                                              "level": 1, "slot": "base", "type": "active", "cost": 1},
	"patch":              {"name": "Patch",              "desc": "Heal yourself or an ally within 3 tiles for 62.5% Max HP. 2-turn cooldown.",                                                                    "level": 1, "slot": "base", "type": "active", "cost": 1},
	"charge":             {"name": "Charge",             "desc": "Rush an enemy within 4 tiles. Instant-kills basic enemies; deals 2x Base Damage to heavy enemies. 2-turn cooldown.",                             "level": 1, "slot": "base", "type": "active", "cost": 1},
	"precision_shot":     {"name": "Precision Shot",     "desc": "Guaranteed hit on any visible enemy. Deals 1.5x Base Damage. 2-turn cooldown.",                                                                   "level": 1, "slot": "base", "type": "active", "cost": 1},

	# CAPTAIN - Level 2
	"lead_by_example":    {"name": "Lead by Example",    "desc": "When the Captain kills an enemy, all other squad members gain +1 AP on their next turn.",                                                       "level": 2, "slot": "a", "type": "passive"},
	"coordinate_fire":    {"name": "Coordinate Fire",    "desc": "Mark a target. All allies gain +20% Accuracy and +25% Critical Chance against that target for 1 turn. (1 AP, active)",                        "level": 2, "slot": "b", "type": "active", "cost": 1},

	# CAPTAIN - Level 3
	"warlord":            {"name": "Warlord",            "desc": "Execute no longer has a cooldown. Chain multiple executions in a single turn if you have enough AP.",                                            "level": 3, "slot": "a", "type": "passive", "cooldown_override": 0, "modifies": "execute"},
	"no_one_left_behind": {"name": "No One Left Behind", "desc": "If an ally within 5 tiles takes lethal damage, they survive with 1 HP and become immune to all damage for 1 turn. (Once per ally per mission)", "level": 3, "slot": "b", "type": "passive"},
	"inspire":            {"name": "Inspire",            "desc": "Grant one ally within 5 tiles +1 AP immediately. (1 AP, 3-turn cooldown)",                                                                       "level": 3, "slot": "c", "type": "active", "cost": 1, "cooldown": 3},

	# SCOUT - Level 2
	"hit_and_run":        {"name": "Hit & Run",          "desc": "Dash up to 3 tiles to reposition. Free action. (0 AP, 1-turn cooldown)",                                                                     "level": 2, "slot": "a", "type": "passive", "cost": 0, "cooldown": 1},
	"deep_scanner":       {"name": "Deep Scanner",       "desc": "Reveals all enemies in a large radius (15 tiles) for 1 turn, even through walls. (0 AP, 3-turn cooldown)",                                      "level": 2, "slot": "b", "type": "active", "cost": 0, "cooldown": 3},

	# SCOUT - Level 3
	"ambush":             {"name": "Explosive Ambush",   "desc": "Plant a hidden explosive trap on your current tile. The first enemy to walk over it takes 100 damage and is pinned. (0 AP, no cooldown)", "level": 3, "slot": "a", "type": "active", "cost": 0, "cooldown": 0},
	"phantom":            {"name": "Phantom",            "desc": "Become Invisible for 2 turns. First attack from invisibility deals +100% Damage but reveals you. (1 AP, active)",                               "level": 3, "slot": "b", "type": "active", "cost": 1, "duration": 2},
	"untouchable":        {"name": "Untouchable",        "desc": "If you kill an enemy during your turn, the next attack against you during the enemy turn is guaranteed to Miss.",                                 "level": 3, "slot": "c", "type": "passive"},

	# TECH - Level 2
	"combat_engineer":    {"name": "Combat Engineer",    "desc": "Turrets gain a 20 HP shield barrier and their duration is extended to 5 turns.",                                                                 "level": 2, "slot": "a", "type": "passive", "modifies": "turret", "turret_hp_bonus": 20, "turret_duration": 5},
	"field_repair":       {"name": "Field Repair",       "desc": "Instantly restore 25 HP and +1 turn duration to your nearest active turret. (0 AP, 3-turn cooldown)",                                           "level": 2, "slot": "b", "type": "active", "cost": 0, "cooldown": 3},

	# TECH - Level 3
	"twin_link":          {"name": "Overcharge",         "desc": "All active turrets deal 2× damage for 2 turns. Also allows 2 turrets simultaneously. (1 AP, 3-turn cooldown)",                              "level": 3, "slot": "a", "type": "active", "cost": 1, "cooldown": 3, "modifies": "turret", "max_turrets": 2},
	"remote_detonation":  {"name": "Remote Detonation",  "desc": "Destroy your nearest active turret. It explodes, dealing 30 damage to all enemies within 2 tiles. (0 AP)",                                      "level": 3, "slot": "b", "type": "active", "cost": 0, "cooldown": 0},
	"emergency_protocol": {"name": "System Reboot",      "desc": "Reset all officer ability cooldowns and grant every deployed ally +1 AP. (1 AP, once per mission)",                                           "level": 3, "slot": "c", "type": "active", "cost": 1, "uses_per_mission": 1},

	# MEDIC - Level 2
	"adrenaline_patch":   {"name": "Adrenaline Patch",   "desc": "Patch also grants the target +2 Movement and +15% Accuracy for 2 turns.",                                                                       "level": 2, "slot": "a", "type": "passive", "modifies": "patch"},
	"field_surgeon":      {"name": "Field Surgeon",      "desc": "Automatically stabilize any ally who drops to 0 HP within 4 tiles, preventing death (unless Medic is also killed).",                            "level": 2, "slot": "b", "type": "passive", "range": 4},

	# MEDIC - Level 3
	"miracle_worker":     {"name": "Miracle Worker",     "desc": "Global Heal: instantly restore 50% HP to all squad members regardless of distance. (2 AP, once per mission)",                                    "level": 3, "slot": "a", "type": "active", "cost": 2, "uses_per_mission": 1},
	"toxicologist":       {"name": "Toxicologist",       "desc": "Attacks apply Poison (5 DMG/turn, -20% Aim). Patch removes all status effects from allies.",                                                     "level": 3, "slot": "b", "type": "passive"},
	"stim_injector":      {"name": "Stim Injector",      "desc": "Inject an ally: they gain +2 AP and take -50% damage for 1 turn. (1 AP, 3-turn cooldown)",                                                      "level": 3, "slot": "c", "type": "active", "cost": 1, "cooldown": 3},

	# HEAVY - Level 2
	"bulldozer":          {"name": "Bulldozer",          "desc": "Charge destroys all cover in its path. Gain +20 Armor after charging.",                                                                          "level": 2, "slot": "a", "type": "passive", "modifies": "charge", "armor_bonus": 20},
	"suppression_fire":   {"name": "Suppression Fire",   "desc": "Target a visible enemy within range: deal 12 light damage and Pin Down (no movement for 3 turns). (1 AP, 3-turn cooldown)",                               "level": 2, "slot": "b", "type": "active", "cost": 1, "cooldown": 3},

	# HEAVY - Level 3
	"juggernaut":         {"name": "Juggernaut",         "desc": "Immune to Critical Hits. If you end your turn without attacking, regenerate 15% Max HP.",                                                        "level": 3, "slot": "a", "type": "passive"},
	"rocket_salvo":       {"name": "Rocket Salvo",       "desc": "Launch a micro-missile swarm. Deals 40 damage to all enemies in a 3×3 area. (2 AP, 3-turn cooldown)",                                          "level": 3, "slot": "b", "type": "active", "cost": 2, "cooldown": 3},
	"war_machine":        {"name": "War Machine",        "desc": "Each enemy killed this mission permanently grants +5 Base Damage. The Heavy grows more dangerous as the fight goes on.",                         "level": 3, "slot": "c", "type": "passive"},

	# SNIPER - Level 2
	"damn_good_ground":   {"name": "Last Stand",         "desc": "Your next shot is a guaranteed hit, ignores all cover penalties. (1 AP, 2-turn cooldown)",                                                     "level": 2, "slot": "a", "type": "active", "cost": 1, "cooldown": 2},
	"snap_shot":          {"name": "Snap Shot",          "desc": "Precision Shot has no cooldown — move and shoot or fire multiple precision shots in the same turn.",                                              "level": 2, "slot": "b", "type": "passive", "modifies": "precision_shot", "cooldown_override": 0},

	# SNIPER - Level 3
	"serial":             {"name": "Serial",             "desc": "Killing an enemy with your main weapon fully refunds your Action Points. Chain kills until you miss or run out of targets.",                     "level": 3, "slot": "a", "type": "passive"},
	"apex_predator":      {"name": "Apex Predator",      "desc": "Deal +100% damage against enemies at full health. Designed for one-shotting high-value targets.",                                                 "level": 3, "slot": "b", "type": "passive", "damage_multiplier": 2.0},
	"double_tap":         {"name": "Double Tap",         "desc": "Fire two shots at the same target: second shot has -15% accuracy penalty. (1 AP, 2-turn cooldown)",                                              "level": 3, "slot": "c", "type": "active", "cost": 1, "cooldown": 2},
}

# Per-officer ability lists: [L1, L2-A, L2-B, L3-A, L3-B, L3-C]
const OFFICER_ABILITIES: Dictionary = {
	"captain": ["execute", "lead_by_example",  "coordinate_fire",  "warlord",          "no_one_left_behind", "inspire"],
	"scout":   ["overwatch", "hit_and_run",   "deep_scanner",     "ambush",           "phantom",            "untouchable"],
	"tech":    ["turret",  "combat_engineer", "field_repair",     "twin_link",        "remote_detonation",  "emergency_protocol"],
	"medic":   ["patch",   "adrenaline_patch","field_surgeon",    "miracle_worker",   "toxicologist",       "stim_injector"],
	"heavy":   ["charge",  "bulldozer",       "suppression_fire", "juggernaut",       "rocket_salvo",       "war_machine"],
	"sniper":  ["precision_shot", "damn_good_ground", "snap_shot", "serial",          "apex_predator",      "double_tap"],
}

# --- Developer Flags (granular per-feature toggles) ---
var dev_protect_fuel: bool = false
var dev_protect_integrity: bool = false
var dev_protect_cash: bool = false
var dev_protect_intel: bool = false
var dev_officers_maxed: bool = false
var dev_story_intel: bool = false
var dev_raider_fast: bool = false
var dev_raider_1_jump_per_turn: bool = false
var dev_wormhole_4x: bool = false
var dev_story_tactical_ease: bool = false
var dev_raider_tactical_ease: bool = false
var dev_skip_raider_spawn_camera: bool = false
var dev_skip_story_spawn_camera: bool = false
var dev_skip_mission_recap_animations: bool = false
var dev_abandoned_station_4x: bool = false

# Primary Statistics (Voyage 2.0 Economy)
const MAX_FUEL: int = 20

var fuel: int = 10:
	set(value):
		if dev_protect_fuel and value < fuel:
			value = fuel
		fuel = clampi(value, 0, MAX_FUEL)
		fuel_changed.emit(fuel)

var ship_integrity: int = 100:
	set(value):
		if dev_protect_integrity and value < ship_integrity:
			value = ship_integrity
		ship_integrity = clampi(value, 0, 100)
		integrity_changed.emit(ship_integrity)
		if ship_integrity <= 0:
			_trigger_game_over("ship_destroyed")


var cash: int = 50:
	set(value):
		if dev_protect_cash and value < cash:
			value = cash
		cash = maxi(0, value)
		cash_changed.emit(cash)

var intel: int = 0:
	set(value):
		if dev_protect_intel and value < intel:
			value = intel
		intel = maxi(0, value)
		intel_changed.emit(intel)

# Story progression (Phase 5 loop closer)

var story_chapters_completed: int = 0
var story_victory_emitted: bool = false

const SHIP_INTEGRITY_LOSS_PER_JUMP: int = 1  # Ship takes minor damage from each jump
const HULL_DAMAGE_DRIFT_MODE: int = 5 # Extra damage when drafting without fuel
const HULL_DAMAGE_PER_TURN: int = 1 # Ship takes damage each tactical turn

# Officer Roster
enum OfficerType { SCOUT, TECH, MEDIC }
# ... (rest of officer logic skipped)

# ...

func process_tactical_turn() -> void:
	tactical_turn_count += 1
	# Ship takes structural damage over time during tactical missions
	damage_ship(HULL_DAMAGE_PER_TURN)

## Officer roster — values are OfficerData instances, populated in _init_officers()
var officers: Dictionary = {}

# Game progression
# REFACTORED: Map state is now handled by VoyageManager (infinite graph system).
# The following properties have been removed to prevent usage:
# - current_node_index
# - nodes_to_new_earth
# - visited_nodes, travel_history
# - node_types, node_biomes
# Use VoyageManager.get_current_node() and related methods instead.

var is_in_tactical_mode: bool = false
var tactical_turn_count: int = 0

# Cumulative mission statistics (tracked across entire voyage)
var total_fuel_collected: int = 0
var total_enemies_killed: int = 0
var total_missions_completed: int = 0
var total_tactical_turns: int = 0


func _ready() -> void:
	load_persistent_settings()
	_init_officers()
	# Intercept window close so we can save before quitting (prevents map reset when closing during tactical)
	get_tree().set_auto_accept_quit(false)

## Load persistent non-run state from settings.cfg
func load_persistent_settings() -> void:
	_load_developer_flags()


## Load all granular developer flags from settings.cfg.
## Migrates old single developer_mode=true by enabling all flags.
func _load_developer_flags() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_CONFIG_PATH)
	if err != OK:
		return

	# Migrate legacy single developer_mode key → enable all flags
	var legacy_raw = config.get_value(SETTINGS_DEVELOPER_SECTION, "developer_mode", null)
	if legacy_raw != null and _coerce_bool(legacy_raw, false):
		dev_protect_fuel = true
		dev_protect_integrity = true
		dev_protect_cash = true
		dev_protect_intel = true
		dev_officers_maxed = true
		dev_story_intel = true
		dev_raider_fast = true
		dev_raider_1_jump_per_turn = true
		dev_wormhole_4x = true
		dev_story_tactical_ease = true
		dev_raider_tactical_ease = true
		dev_skip_raider_spawn_camera = true
		dev_skip_story_spawn_camera = true
		dev_skip_mission_recap_animations = true
		dev_abandoned_station_4x = true
		return

	dev_protect_fuel       = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "protect_fuel", false), false)
	dev_protect_integrity  = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "protect_integrity", false), false)
	dev_protect_cash       = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "protect_cash", false), false)
	dev_protect_intel      = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "protect_intel", false), false)
	dev_officers_maxed     = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "officers_maxed", false), false)
	dev_story_intel        = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "story_intel", false), false)
	dev_raider_fast        = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "raider_fast", false), false)
	dev_raider_1_jump_per_turn = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "raider_1_jump_per_turn", false), false)
	dev_wormhole_4x        = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "wormhole_4x", false), false)
	dev_story_tactical_ease = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "story_tactical_ease", false), false)
	dev_raider_tactical_ease = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "raider_tactical_ease", false), false)
	dev_skip_raider_spawn_camera = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "skip_raider_spawn_camera", false), false)
	dev_skip_story_spawn_camera = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "skip_story_spawn_camera", false), false)
	dev_skip_mission_recap_animations = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "skip_mission_recap_animations", false), false)
	dev_abandoned_station_4x = _coerce_bool(config.get_value(SETTINGS_DEVELOPER_SECTION, "abandoned_station_4x", false), false)


## Save all granular developer flags to settings.cfg.
func save_developer_flags() -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_CONFIG_PATH)  # Load existing to preserve other settings
	config.set_value(SETTINGS_DEVELOPER_SECTION, "protect_fuel",       dev_protect_fuel)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "protect_integrity",  dev_protect_integrity)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "protect_cash",       dev_protect_cash)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "protect_intel",      dev_protect_intel)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "officers_maxed",     dev_officers_maxed)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "story_intel",        dev_story_intel)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "raider_fast",        dev_raider_fast)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "raider_1_jump_per_turn", dev_raider_1_jump_per_turn)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "wormhole_4x",        dev_wormhole_4x)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "story_tactical_ease", dev_story_tactical_ease)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "raider_tactical_ease", dev_raider_tactical_ease)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "skip_raider_spawn_camera", dev_skip_raider_spawn_camera)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "skip_story_spawn_camera", dev_skip_story_spawn_camera)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "skip_mission_recap_animations", dev_skip_mission_recap_animations)
	config.set_value(SETTINGS_DEVELOPER_SECTION, "abandoned_station_4x", dev_abandoned_station_4x)
	# Remove legacy key if present
	if config.has_section_key(SETTINGS_DEVELOPER_SECTION, "developer_mode"):
		config.erase_section_key(SETTINGS_DEVELOPER_SECTION, "developer_mode")
	config.save(SETTINGS_CONFIG_PATH)
	developer_flags_changed.emit()


## Returns true if any developer flag is currently active.
func is_any_dev_flag_active() -> bool:
	return (dev_protect_fuel or dev_protect_integrity or dev_protect_cash or dev_protect_intel
		or dev_officers_maxed or dev_story_intel or dev_raider_fast or dev_raider_1_jump_per_turn or dev_wormhole_4x
		or dev_story_tactical_ease or dev_raider_tactical_ease
		or dev_skip_raider_spawn_camera or dev_skip_story_spawn_camera
		or dev_skip_mission_recap_animations or dev_abandoned_station_4x)


func _coerce_bool(value: Variant, default_value: bool = false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			var normalized := String(value).strip_edges().to_lower()
			if normalized in ["1", "true", "yes", "on"]:
				return true
			if normalized in ["0", "false", "no", "off", ""]:
				return false
			return default_value
		_:
			return default_value


## Create fresh OfficerData for all 6 officers
func _init_officers() -> void:
	for key in ["captain", "scout", "tech", "medic", "heavy", "sniper"]:
		var od = OfficerData.new()
		od.initialize(key)
		if key in ["tech", "heavy", "sniper"]:
			od.unlocked = false
		if dev_officers_maxed:
			od.level = 3
			od.xp = 300  # XP threshold to reach level 3
			od.data_logs = 100
		# Unlock Level 1 ability by default
		var abilities = OFFICER_ABILITIES.get(key, [])
		if not abilities.is_empty():
			od.unlock_ability(abilities[0])
		officers[key] = od


## Get OfficerData for a given officer key
func get_officer(key: String) -> OfficerData:
	return officers.get(key, null)


## Returns true if officer is alive AND not injured (available for deployment)
func is_officer_available(key: String) -> bool:
	var od: OfficerData = get_officer(key)
	return od != null and od.is_available()


## Check if any officer (or a specific one) has available ability upgrades
## This means: has enough DL AND has an unlockable ability in the current or next tier
func has_available_upgrades(officer_key: String = "") -> bool:
	var keys_to_check = []
	if officer_key != "":
		keys_to_check.append(officer_key)
	else:
		keys_to_check = officers.keys()
		
	for key in keys_to_check:
		var od: OfficerData = get_officer(key)
		if not od or not od.alive:
			continue
			
		# Must have at least 1 Data Log to buy anything
		if od.data_logs <= 0:
			continue

		var all_abs = OFFICER_ABILITIES.get(key, [])
		if all_abs.size() < 6: continue
			
		# Check unlockable abilities based on tier rules
		# Tier costs: L2 = 1 DL, L3 = 1 DL
		
		# If level >= 2, can we unlock tier 2?
		if od.level >= 2 and od.data_logs >= OfficerData.DATA_LOGS_LEVEL2_COST:
			# Tier 2 slots: indices 1 and 2 (Mutually Exclusive)
			# Do we already have a Tier 2 ability?
			var has_tier2_selection = od.has_ability(all_abs[1]) or od.has_ability(all_abs[2])
			
			if not has_tier2_selection:
				# Tier 2 requires Tier 1 ability (index 0)
				if od.has_ability(all_abs[0]):
					return true # Available to buy!
		
		# If level >= 3, can we unlock tier 3?
		if od.level >= 3 and od.data_logs >= OfficerData.DATA_LOGS_LEVEL3_COST:
			# Tier 3 slots: indices 3, 4, 5 (Mutually Exclusive)
			# Do we already have a Tier 3 ability?
			var has_tier3_selection = od.has_ability(all_abs[3]) or od.has_ability(all_abs[4]) or od.has_ability(all_abs[5])
			
			if not has_tier3_selection:
				# Tier 3 specific prerequisites
				# idx 3 requires idx 1
				# idx 4 requires idx 1 OR idx 2
				# idx 5 requires idx 2
				
				var has_ab1 = od.has_ability(all_abs[1])
				var has_ab2 = od.has_ability(all_abs[2])
				
				if has_ab1 or has_ab2:
					return true # Available to buy!
					
	return false


func reset_game() -> void:
	was_loaded_from_save = false
	fuel = 10
	ship_integrity = 100
	cash = 50
	intel = 0
	story_chapters_completed = 0
	story_victory_emitted = false
	
	# Reset cumulative stats
	total_fuel_collected = 0
	total_enemies_killed = 0
	total_missions_completed = 0
	total_tactical_turns = 0

	# Reset Voyage Manager
	if VoyageManager:
		VoyageManager._initialize_voyage()

	_init_officers()


## Add mission stats to cumulative totals (called after successful missions)
func add_mission_stats(fuel_collected: int, enemies_killed: int, turns_taken: int) -> void:
	total_fuel_collected += fuel_collected
	total_enemies_killed += enemies_killed
	total_tactical_turns += turns_taken
	total_missions_completed += 1


func jump_to_node(_target_node_index: int, _fuel_cost: int = 1) -> void:
	# DEPRECATED - Use VoyageManager.attempt_jump()
	pass


func enter_tactical_mode() -> void:
	is_in_tactical_mode = true
	tactical_turn_count = 0


func exit_tactical_mode() -> void:
	is_in_tactical_mode = false


func down_officer(officer_key: String) -> void:
	var od: OfficerData = get_officer(officer_key)
	if od:
		od.downed = true
		od.injury_jumps = 4
		od.current_hp = 0
		officer_died.emit(officer_key)


func kill_officer(officer_key: String) -> void:
	down_officer(officer_key)


func is_officer_alive(officer_key: String) -> bool:
	var od: OfficerData = get_officer(officer_key)
	return od != null and od.alive


func damage_ship(amount: int) -> void:
	ship_integrity -= amount


func repair_ship(amount: int) -> void:
	ship_integrity += amount


func _check_win_condition() -> void:
	trigger_story_victory()


func get_ending_type_by_hull() -> String:
	if ship_integrity >= 100:
		return "perfect"
	if ship_integrity >= 50:
		return "good"
	return "bad"


func trigger_story_victory(ending_type: String = "") -> void:
	if story_victory_emitted:
		return
	story_victory_emitted = true
	if ending_type == "":
		ending_type = get_ending_type_by_hull()
	game_won.emit(ending_type)


func _trigger_game_over(reason: String) -> void:
	game_over.emit(reason)


func get_ending_text(ending_type: String) -> String:
	match ending_type:
		"perfect":
			return "THE GOLDEN AGE\nHumanity will flourish."
		"good":
			return "THE HARD FOUNDATION\nEnough survived to rebuild."
		"bad":
			return "THE ENDANGERED SPECIES\nHumanity clings to existence."
		_:
			return ""


func get_game_over_text(reason: String) -> String:
	match reason:
		"ship_destroyed":
			return "CATASTROPHIC FAILURE\nThe ship has been destroyed. All souls aboard are lost to the void."
		"crew_wipe":
			return "MISSION FAILED\nThe entire crew has been lost. The ship drifts silently in the dark."
		"captain_died":
			return "LEADERSHIP LOST\nThe Captain has fallen. Without leadership, the mission cannot continue."
		_:
			return "GAME OVER"


#region Save/Load System
const SAVE_PATH = "user://savegame.dat"

## True when game was loaded via Continue (used to skip voyage intro)
var was_loaded_from_save: bool = false

## True when we're in an active game session (main scene); used to know when to save on window close
var game_session_active: bool = false

## Star map data (saved to preserve the exact node layout)
var saved_star_map_data: Dictionary = {}


## Save the current game state to disk
func save_game() -> bool:
	# Serialize officer progression
	var officers_data: Dictionary = {}
	for key in officers:
		officers_data[key] = (officers[key] as OfficerData).to_dict()

	var save_data = {
		"version": 7, # Voyage 2.0 + story progression (Phase 5)
		"fuel": fuel,
		"ship_integrity": ship_integrity,
		"cash": cash,
		"intel": intel,
		"story_chapters_completed": story_chapters_completed,
		"story_victory_emitted": story_victory_emitted,
		"officers": officers_data,
		# VoyageManager Data
		"voyage_data": VoyageManager.get_save_data(),
		# Cumulative mission stats (v3)
		"total_fuel_collected": total_fuel_collected,
		"total_enemies_killed": total_enemies_killed,
		"total_missions_completed": total_missions_completed,
		"total_tactical_turns": total_tactical_turns,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()
	
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_session_active:
			save_game()
		get_tree().quit()


## Load a saved game from disk
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("No save file found!")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return false
	
	var save_data = json.data
	if not save_data is Dictionary:
		push_error("Invalid save file format!")
		return false
	

	
	# Version Check
	var version = int(save_data.get("version", 0))
	if version < 5:
		# Wipe save for new version compatibility
		print("Save version %d is too old (requires 5). Deleting save..." % version)
		delete_save()
		return false

	# Restore game state
	fuel = int(save_data.get("fuel", 3))
	ship_integrity = int(save_data.get("ship_integrity", 100))
	cash = int(save_data.get("cash", 20))
	intel = int(save_data.get("intel", 0))
	story_chapters_completed = int(save_data.get("story_chapters_completed", 0))
	story_victory_emitted = bool(save_data.get("story_victory_emitted", false))

	# Restore VoyageManager Data
	if save_data.has("voyage_data"):
		VoyageManager.load_save_data(save_data["voyage_data"])

	# Restore officers (must be initialised first so keys exist)
	_init_officers()
	var loaded_officers = save_data.get("officers", {})
	for officer_key in officers.keys():
		var od: OfficerData = get_officer(officer_key)
		if loaded_officers.has(officer_key):
			if version >= 6:
				# Full v6+ restore (from_dict handles migration of old alive=false)
				od.from_dict(loaded_officers[officer_key])
			else:
				# v5 migration: restore alive flag, reset HP to full
				var old_alive = loaded_officers[officer_key].get("alive", true)
				od.alive = old_alive
				od.current_hp = od.max_hp
				# Migrate dead officers to downed state
				if not old_alive:
					od.alive = true
					od.downed = true
					od.injury_jumps = 4
		if dev_officers_maxed:
			od.data_logs = 100
	
	# Restore cumulative mission stats
	total_fuel_collected = int(save_data.get("total_fuel_collected", 0))
	total_enemies_killed = int(save_data.get("total_enemies_killed", 0))
	total_missions_completed = int(save_data.get("total_missions_completed", 0))
	total_tactical_turns = int(save_data.get("total_tactical_turns", 0))
	
	# Reset tactical state
	tactical_turn_count = 0
	is_in_tactical_mode = false
	
	was_loaded_from_save = true
	return true


## Check if a save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Store star map data for saving
func store_star_map_data(generator: StarMapGenerator) -> void:
	saved_star_map_data.clear()
	var nodes_data = []
	
	for node in generator.nodes:
		var node_data = {
			"id": node.id,
			"column": node.column,
			"row": node.row,
			"connections": node.connections,
			"node_type": node.node_type,
			"biome_type": node.biome_type,
			"connection_fuel_costs": node.connection_fuel_costs,
		}
		nodes_data.append(node_data)
	
	saved_star_map_data["nodes"] = nodes_data


## Check if we have saved star map data
func has_saved_star_map_data() -> bool:
	return saved_star_map_data.has("nodes") and saved_star_map_data["nodes"].size() > 0


## Get mission difficulty multiplier based on current node index
## Returns a multiplier (1.0 = base difficulty, increases as player progresses)
## Formula: 1.0 + (current_node_index / nodes_to_new_earth) * difficulty_scale_factor
## This gives: 1.0x at start (node 0), ~2.5x at end (node 49)
## Reduced scaling in final stages (nodes 35+) to decrease difficulty
func get_mission_difficulty() -> float:
	var current_node = VoyageManager.get_current_node()
	if current_node and current_node.difficulty_multiplier > 0:
		return current_node.difficulty_multiplier
		
	# Fallback to old distance-based logic if node data is missing multiplier
	var distance = current_node.position.length() if current_node else 0.0
	var steps = distance / 400.0
	return 1.0 + (steps * 0.05)


## Recreate a StarMapGenerator from saved data
func restore_star_map_generator() -> StarMapGenerator:
	if not has_saved_star_map_data():
		return null

	var generator = StarMapGenerator.new()
	generator.nodes.clear()

	var nodes_data = saved_star_map_data["nodes"]
	for node_dict in nodes_data:
		var node = StarMapGenerator.MapNode.new(
			int(node_dict["id"]),
			int(node_dict["column"]),
			int(node_dict["row"])
		)

		# Restore connections
		for conn_id in node_dict["connections"]:
			node.connections.append(int(conn_id))

		node.node_type = int(node_dict["node_type"])
		node.biome_type = int(node_dict.get("biome_type", -1))

		# Restore fuel costs
		var fuel_costs = node_dict.get("connection_fuel_costs", {})
		for key in fuel_costs.keys():
			node.connection_fuel_costs[int(key)] = int(fuel_costs[key])

		generator.nodes.append(node)

	return generator
#endregion


#region Ability System Helpers

## Get ability definition by ID
func get_ability_def(ability_id: String) -> Dictionary:
	return ABILITY_DEFS.get(ability_id, {})


## Get ability cost (AP required to use)
func get_ability_cost(ability_id: String) -> int:
	var def = get_ability_def(ability_id)
	return def.get("cost", 1)


## Get ability type (passive or active)
func get_ability_type(ability_id: String) -> String:
	var def = get_ability_def(ability_id)
	return def.get("type", "passive")


## Get cooldown override for an ability (if any)
func get_ability_cooldown_override(ability_id: String) -> int:
	var def = get_ability_def(ability_id)
	if def.has("cooldown_override"):
		return def.get("cooldown_override", -1)
	return -1  # -1 means no override


## Get custom cooldown (if different from base)
func get_ability_cooldown(ability_id: String) -> int:
	var def = get_ability_def(ability_id)
	return def.get("cooldown", 2)  # Default 2-turn cooldown for base abilities


## Get damage multiplier for an ability (for passive bonuses like Apex Predator)
func get_ability_damage_multiplier(ability_id: String) -> float:
	var def = get_ability_def(ability_id)
	return def.get("damage_multiplier", 1.0)

#endregion
