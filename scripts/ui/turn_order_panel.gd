class_name TurnOrderPanel
extends PanelContainer
## Turn Order Panel — displays 5 unit slots: 1 past + current + 3 upcoming.
## Refreshed by TacticalController via the turn_display_updated signal.

const PORTRAIT_PATHS := {
	"captain":  "res://assets/sprites/portraits/captain_officer_portait.png",
	"scout":    "res://assets/sprites/portraits/scout_officer_portrait.png",
	"tech":     "res://assets/sprites/portraits/tech_officer_potrait.png",
	"medic":    "res://assets/sprites/portraits/medic_officer_portrait.png",
	"heavy":    "res://assets/sprites/portraits/heavy_officer_portait.png",
	"sniper":   "res://assets/sprites/portraits/sniper_officer_portrait.png",
}

@onready var slot_past:    Control = $VBoxContainer/SlotPast
@onready var slot_current: Control = $VBoxContainer/SlotCurrent
@onready var slot_next1:   Control = $VBoxContainer/SlotNext1
@onready var slot_next2:   Control = $VBoxContainer/SlotNext2
@onready var slot_next3:   Control = $VBoxContainer/SlotNext3

var _slots: Array[Control] = []

func _ready() -> void:
	_slots = [slot_past, slot_current, slot_next1, slot_next2, slot_next3]
	_clear_all_slots()


## Called by TacticalController whenever the display should update.
func refresh(history: Array, turn_order: Array, pos: int, biome: String) -> void:
	# Slot 0: last unit in history (past)
	var past_unit: Node2D = history.back() if history.size() > 0 else null
	_populate_slot(slot_past, past_unit, "past", biome)

	# Slot 1: current actor
	var current_unit: Node2D = turn_order[pos] if pos < turn_order.size() else null
	_populate_slot(slot_current, current_unit, "current", biome)

	# Slots 2-4: next 3 upcoming
	var upcoming_slots := [slot_next1, slot_next2, slot_next3]
	for i in 3:
		var idx := pos + 1 + i
		var unit: Node2D = turn_order[idx] if idx < turn_order.size() else null
		_populate_slot(upcoming_slots[i], unit, "future", biome)


func _clear_all_slots() -> void:
	for slot in _slots:
		_populate_slot(slot, null, "empty", "")


func _populate_slot(slot: Control, unit: Node2D, state: String, biome: String) -> void:
	if not is_instance_valid(slot):
		return

	var border:    ColorRect  = slot.get_node_or_null("BorderRect")
	var portrait:  TextureRect = slot.get_node_or_null("Portrait")
	var team_bar:  ColorRect  = slot.get_node_or_null("TeamIndicator")
	var name_lbl:  Label      = slot.get_node_or_null("NameLabel")

	# Border — gold only for current
	if border:
		border.visible = (state == "current")

	# Portrait texture
	if portrait:
		if unit != null and is_instance_valid(unit):
			var tex := _get_portrait_texture(unit, biome)
			portrait.texture = tex
			portrait.modulate = Color(0.45, 0.45, 0.5, 1.0) if state == "past" else Color.WHITE
		else:
			portrait.texture = null
			portrait.modulate = Color.WHITE

	# Team colour strip
	if team_bar:
		if unit != null and is_instance_valid(unit):
			var is_officer := unit.has_method("get") and unit.get("officer_type") != null
			team_bar.color = Color(0.2, 0.5, 1.0) if is_officer else Color(0.9, 0.2, 0.2)
		else:
			team_bar.color = Color(0.3, 0.3, 0.3)

	# Name label
	if name_lbl:
		if unit != null and is_instance_valid(unit):
			name_lbl.text = _get_unit_display_name(unit)
		else:
			name_lbl.text = ""


func _get_unit_display_name(unit: Node2D) -> String:
	# Officers expose officer_type; enemies expose enemy_type
	var otype = unit.get("officer_type") if unit.get("officer_type") != null else ""
	if otype != "":
		return otype.capitalize()
	var etype = unit.get("enemy_type") if unit.get("enemy_type") != null else ""
	if etype != "":
		return etype.capitalize()
	return unit.name


func _get_portrait_texture(unit: Node2D, biome: String) -> Texture2D:
	var otype: String = unit.get("officer_type") if unit.get("officer_type") != null else ""
	if otype != "":
		var path: String = PORTRAIT_PATHS.get(otype, "")
		if path != "" and ResourceLoader.exists(path):
			return load(path)
		return null

	# Enemy: build path from enemy_type + biome
	var etype: String = unit.get("enemy_type") if unit.get("enemy_type") != null else "basic"
	var safe_biome := biome.to_lower() if biome != "" else "station"
	var enemy_path := "res://assets/sprites/portraits/enemies/enemy_%s_%s.png" % [etype, safe_biome]
	if ResourceLoader.exists(enemy_path):
		return load(enemy_path)
	return null
