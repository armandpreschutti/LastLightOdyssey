extends Control
## Tactical HUD - Displays mission info, stability bar, and controls

signal end_turn_pressed
signal extract_pressed
signal ability_used(ability_type: String)

@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var stability_bar: ProgressBar = $VBoxContainer/StabilityContainer/StabilityBar
@onready var stability_label: Label = $VBoxContainer/StabilityContainer/StabilityLabel
@onready var cryo_warning: Label = $VBoxContainer/CryoWarning
@onready var selected_label: Label = $VBoxContainer/SelectedContainer/SelectedLabel
@onready var ap_label: Label = $VBoxContainer/SelectedContainer/APLabel
@onready var hp_label: Label = $VBoxContainer/SelectedContainer/HPLabel
@onready var move_range_label: Label = $VBoxContainer/SelectedContainer/MoveRangeLabel
@onready var attack_range_label: Label = $VBoxContainer/SelectedContainer/AttackRangeLabel
@onready var turn_status_label: Label = $VBoxContainer/SelectedContainer/TurnStatusLabel
@onready var haul_label: Label = $VBoxContainer/HaulContainer/HaulLabel
@onready var end_turn_button: Button = $VBoxContainer/ButtonContainer/EndTurnButton
@onready var extract_button: Button = $VBoxContainer/ButtonContainer/ExtractButton
@onready var ability_container: VBoxContainer = $VBoxContainer/AbilityContainer
@onready var overwatch_button: Button = $VBoxContainer/AbilityContainer/OverwatchButton
@onready var overwatch_desc: Label = $VBoxContainer/AbilityContainer/OverwatchDesc
@onready var breach_button: Button = $VBoxContainer/AbilityContainer/BreachButton
@onready var breach_desc: Label = $VBoxContainer/AbilityContainer/BreachDesc
@onready var patch_button: Button = $VBoxContainer/AbilityContainer/PatchButton
@onready var patch_desc: Label = $VBoxContainer/AbilityContainer/PatchDesc


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	overwatch_button.pressed.connect(_on_overwatch_pressed)
	breach_button.pressed.connect(_on_breach_pressed)
	patch_button.pressed.connect(_on_patch_pressed)
	cryo_warning.visible = false
	extract_button.visible = false
	ability_container.visible = false


func update_turn(turn_number: int) -> void:
	turn_label.text = "TURN: %d" % turn_number


func update_stability(stability: int) -> void:
	stability_bar.value = stability
	stability_label.text = "CRYO-STABILITY: %d%%" % stability

	if stability <= 0:
		stability_label.add_theme_color_override("font_color", Color.RED)
	elif stability <= 25:
		stability_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		stability_label.add_theme_color_override("font_color", Color(1, 0.69, 0))


func update_selected_unit(officer_name: String, current_ap: int, max_ap: int) -> void:
	# Legacy method for backwards compatibility
	update_selected_unit_full(officer_name, current_ap, max_ap, 100, 100, 5)


func update_selected_unit_full(officer_name: String, current_ap: int, max_ap: int, current_hp: int, max_hp: int, move_range: int, is_their_turn: bool = true, attack_range: int = 10) -> void:
	selected_label.text = "SELECTED: %s" % officer_name.to_upper()
	ap_label.text = "ACTION POINTS: %d / %d" % [current_ap, max_ap]
	hp_label.text = "HEALTH: %d / %d" % [current_hp, max_hp]
	move_range_label.text = "MOVE RANGE: %d tiles" % move_range
	attack_range_label.text = "ATTACK RANGE: %d tiles" % attack_range
	
	if is_their_turn:
		turn_status_label.text = "[ ACTIVE TURN ]"
		turn_status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	else:
		turn_status_label.text = "[ WAITING ]"
		turn_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func update_haul(fuel: int, scrap: int) -> void:
	haul_label.text = "MISSION HAUL:\nFUEL: +%d\nSCRAP: +%d" % [fuel, scrap]


func show_cryo_warning() -> void:
	cryo_warning.visible = true
	cryo_warning.text = "[ CRYO-FAILURE: -10 COLONISTS ]"

	# Flash effect
	var tween = create_tween()
	tween.tween_property(cryo_warning, "modulate:a", 0.3, 0.3)
	tween.tween_property(cryo_warning, "modulate:a", 1.0, 0.3)
	tween.set_loops(3)


func hide_cryo_warning() -> void:
	cryo_warning.visible = false


@warning_ignore("shadowed_variable_base_class")
func set_extract_visible(is_visible: bool) -> void:
	extract_button.visible = is_visible


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()


func _on_extract_pressed() -> void:
	extract_pressed.emit()


func update_ability_buttons(officer_type: String, current_ap: int) -> void:
	# Hide all by default
	ability_container.visible = false
	overwatch_button.visible = false
	overwatch_desc.visible = false
	breach_button.visible = false
	breach_desc.visible = false
	patch_button.visible = false
	patch_desc.visible = false
	
	# Show relevant abilities based on officer type
	match officer_type:
		"scout":
			ability_container.visible = true
			overwatch_button.visible = true
			overwatch_desc.visible = true
			overwatch_button.disabled = current_ap < 1
		"tech":
			ability_container.visible = true
			breach_button.visible = true
			breach_desc.visible = true
			breach_button.disabled = current_ap < 1
		"medic":
			ability_container.visible = true
			patch_button.visible = true
			patch_desc.visible = true
			patch_button.disabled = current_ap < 2


func _on_overwatch_pressed() -> void:
	ability_used.emit("overwatch")


func _on_breach_pressed() -> void:
	ability_used.emit("breach")


func _on_patch_pressed() -> void:
	ability_used.emit("patch")


## Show a combat message (for attack phases)
func show_combat_message(message: String, color: Color = Color(1, 1, 0.2)) -> void:
	# Get the combat message label from the parent tactical scene
	var combat_msg = get_node_or_null("../../UILayer/CombatMessageContainer/CombatMessage")
	if combat_msg:
		combat_msg.text = message
		combat_msg.add_theme_color_override("font_color", color)
		combat_msg.visible = true


## Hide the combat message
func hide_combat_message() -> void:
	var combat_msg = get_node_or_null("../../UILayer/CombatMessageContainer/CombatMessage")
	if combat_msg:
		combat_msg.visible = false
