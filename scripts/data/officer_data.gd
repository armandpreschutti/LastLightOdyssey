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

const XP_LEVEL2_THRESHOLD: int = 100
const XP_LEVEL3_THRESHOLD: int = 300
const DATA_LOGS_LEVEL2_COST: int = 5
const DATA_LOGS_LEVEL3_COST: int = 10

var id: String = ""
var alive: bool = true
var level: int = 1
var xp: int = 0
var unlocked_abilities: Array[String] = []
var max_hp: int = 0
var current_hp: int = 0
var injury_jumps: int = 0


func initialize(officer_id: String) -> void:
	id = officer_id
	alive = true
	level = 1
	xp = 0
	unlocked_abilities.clear()
	max_hp = BASE_HP.get(officer_id, 80)
	current_hp = max_hp
	injury_jumps = 0


func is_injured() -> bool:
	return injury_jumps > 0


func is_available() -> bool:
	return alive and injury_jumps == 0


func has_ability(ab: String) -> bool:
	return ab in unlocked_abilities


func unlock_ability(ab: String) -> void:
	if not has_ability(ab):
		unlocked_abilities.append(ab)


func can_unlock_level2(data_logs: int) -> bool:
	return xp >= XP_LEVEL2_THRESHOLD and data_logs >= DATA_LOGS_LEVEL2_COST and level < 2


func can_unlock_level3(data_logs: int) -> bool:
	return xp >= XP_LEVEL3_THRESHOLD and data_logs >= DATA_LOGS_LEVEL3_COST and level < 3


func to_dict() -> Dictionary:
	return {
		"id": id,
		"alive": alive,
		"level": level,
		"xp": xp,
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
	var abilities_raw = d.get("unlocked_abilities", [])
	unlocked_abilities.clear()
	for ab in abilities_raw:
		unlocked_abilities.append(str(ab))
	max_hp = d.get("max_hp", BASE_HP.get(id, 80))
	current_hp = d.get("current_hp", max_hp)
	injury_jumps = d.get("injury_jumps", 0)
