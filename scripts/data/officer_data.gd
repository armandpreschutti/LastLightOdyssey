class_name OfficerData
extends Resource
## Persistent officer progression data — level, XP, HP, injuries, abilities

const BASE_HP: Dictionary = {
	"captain": 100,
	"scout": 80,
	"tech": 70,
	"medic": 75,
	"heavy": 120,
	"sniper": 70,
}

const XP_THRESHOLD_INITIAL: int = 100
const XP_THRESHOLD_STEP: int = 100
const DATA_LOGS_LEVEL2_COST: int = 1
const DATA_LOGS_LEVEL3_COST: int = 1

var id: String = ""
var alive: bool = true
var level: int = 1
var xp: int = 0
var data_logs: int = 0
var unlocked_abilities: Array[String] = []
var max_hp: int = 0
var current_hp: int = 0
var injury_jumps: int = 0


func initialize(officer_key: String) -> void:
	id = officer_key
	alive = true
	level = 1
	xp = 0
	data_logs = 0
	unlocked_abilities.clear()
	max_hp = BASE_HP.get(officer_key, 80)
	current_hp = max_hp
	injury_jumps = 0
	# Check for initial level up if starting with XP (though usually 0)
	_check_level_up()


func is_injured() -> bool:
	return injury_jumps > 0


func is_available() -> bool:
	return alive and injury_jumps == 0


func has_ability(ab: String) -> bool:
	return ab in unlocked_abilities


func unlock_ability(ab: String) -> void:
	if not has_ability(ab):
		unlocked_abilities.append(ab)


func add_xp(amount: int) -> void:
	xp += amount
	_check_level_up()


func _check_level_up() -> void:
	while xp >= get_next_xp_threshold():
		level += 1
		data_logs += 1
		print("DEBUG: %s leveled up to %d! Earned 1 DL (Total: %d)" % [id, level, data_logs])


func get_next_xp_threshold() -> int:
	# Level 1 -> 2: 100
	# Level 2 -> 3: 300 (per original code)
	# Level 3 -> 4: 600? Let's make it quadratic or linear-step.
	# Original thresholds were 100, 300.
	# L1: 0
	# L2: 100
	# L3: 300
	# L4: 600
	# L5: 1000
	# Formula: threshold = 50 * level * (level + 1) -> 1=100, 2=300, 3=600, 4=1000
	return threshold_for_level(level)


static func threshold_for_level(lvl: int) -> int:
	return 50 * lvl * (lvl + 1)


static func level_for_xp(xp_val: int) -> int:
	var lvl: int = 1
	while xp_val >= threshold_for_level(lvl):
		lvl += 1
	return lvl


func can_unlock_level2(_logs_count: int) -> bool:
	# Ignored logs_count parameter, using internal data_logs
	return level >= 2 and data_logs >= DATA_LOGS_LEVEL2_COST


func can_unlock_level3(_logs_count: int) -> bool:
	# Ignored logs_count parameter, using internal data_logs
	return level >= 3 and data_logs >= DATA_LOGS_LEVEL3_COST


func to_dict() -> Dictionary:
	return {
		"id": id,
		"alive": alive,
		"level": level,
		"xp": xp,
		"data_logs": data_logs,
		"unlocked_abilities": unlocked_abilities.duplicate(),
		"max_hp": max_hp,
		"current_hp": current_hp,
		"injury_jumps": injury_jumps,
	}


func from_dict(d: Dictionary) -> void:
	id = d.get("id", id)
	alive = d.get("alive", true)
	level = d.get("level", 1)
	xp = d.get("xp", 0)
	data_logs = d.get("data_logs", 0)
	var abilities_raw = d.get("unlocked_abilities", [])
	unlocked_abilities.clear()
	for ab in abilities_raw:
		unlocked_abilities.append(str(ab))
	max_hp = d.get("max_hp", BASE_HP.get(id, 80))
	current_hp = d.get("current_hp", max_hp)
	injury_jumps = d.get("injury_jumps", 0)
	# Retroactively apply levels if XP is high (e.g. Sniper with 270 XP)
	_check_level_up()

