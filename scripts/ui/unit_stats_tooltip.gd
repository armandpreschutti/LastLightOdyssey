extends Control
## Unit Stats Tooltip - Displays unit statistics when hovering over units
## Shows HP, AP, movement range, sight range, shoot range, damage, and unit type

@onready var panel: PanelContainer = $PanelContainer
@onready var unit_name_label: Label = $PanelContainer/MarginContainer/VBox/UnitNameLabel
@onready var hp_label: Label = $PanelContainer/MarginContainer/VBox/HPLabel
@onready var ap_label: Label = $PanelContainer/MarginContainer/VBox/APLabel
@onready var move_range_label: Label = $PanelContainer/MarginContainer/VBox/MoveRangeLabel
@onready var sight_range_label: Label = $PanelContainer/MarginContainer/VBox/SightRangeLabel
@onready var shoot_range_label: Label = $PanelContainer/MarginContainer/VBox/ShootRangeLabel
@onready var damage_label: Label = $PanelContainer/MarginContainer/VBox/DamageLabel


func _ready() -> void:
	visible = false


## Update tooltip with unit statistics
func update_unit_stats(unit: Node2D) -> void:
	if not unit:
		hide_tooltip()
		return
	
	var unit_type: String = ""
	var current_hp: int = 0
	var max_hp: int = 0
	var current_ap: int = 0
	var max_ap: int = 0
	var move_range: int = 0
	var sight_range: int = 0
	var shoot_range: int = 0
	var damage: int = 0
	
	# Check if it's an officer unit
	if unit.get("officer_type") != null:
		unit_type = unit.officer_type.to_upper()
		current_hp = unit.current_hp
		max_hp = unit.max_hp
		current_ap = unit.current_ap
		max_ap = unit.max_ap
		move_range = unit.move_range
		sight_range = unit.sight_range
		shoot_range = unit.shoot_range
		damage = unit.base_damage
	# Check if it's an enemy unit
	elif unit.get("enemy_type") != null:
		unit_type = unit.enemy_type.to_upper()
		current_hp = unit.current_hp
		max_hp = unit.max_hp
		current_ap = unit.current_ap
		max_ap = unit.max_ap
		move_range = unit.move_range
		sight_range = unit.sight_range
		shoot_range = unit.shoot_range
		damage = unit.base_damage
	else:
		hide_tooltip()
		return
	
	# Update labels
	unit_name_label.text = unit_type
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	ap_label.text = "AP: %d / %d" % [current_ap, max_ap]
	move_range_label.text = "MOVE: %d tiles" % move_range
	sight_range_label.text = "SIGHT: %d tiles" % sight_range
	shoot_range_label.text = "SHOOT: %d tiles" % shoot_range
	damage_label.text = "DAMAGE: %d" % damage
	
	# Color HP based on percentage
	var hp_percent = float(current_hp) / float(max_hp) if max_hp > 0 else 0
	if hp_percent <= 0.25:
		hp_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif hp_percent <= 0.5:
		hp_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
	# Color AP based on remaining
	if current_ap == 0:
		ap_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		ap_label.add_theme_color_override("font_color", Color(1.0, 0.69, 0.0))
	
	show_tooltip()


## Show the tooltip
func show_tooltip() -> void:
	visible = true


## Hide the tooltip
func hide_tooltip() -> void:
	visible = false
