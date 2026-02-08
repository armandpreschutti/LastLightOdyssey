extends Control
## Tactical HUD - Displays mission info, unit stats, and controls
## Designed for clarity with descriptive labels and tooltips

signal end_turn_pressed
signal extract_pressed
signal ability_used(ability_type: String)
signal pause_pressed

# Pause button (top left)
@onready var pause_button: Button = $TopLeftPanel/PauseButton

# Top bar elements - updated paths for icon-based layout
@onready var turn_label: Label = $TopBar/HBox/TurnContainer/TurnRow/TurnLabel
@onready var stability_container: VBoxContainer = $TopBar/HBox/StabilityContainer
@onready var stability_label: Label = $TopBar/HBox/StabilityContainer/StabilityRow/StabilityLabel
@onready var stability_bar: ProgressBar = $TopBar/HBox/StabilityContainer/StabilityBar
@onready var haul_container: VBoxContainer = $TopBar/HBox/HaulContainer
@onready var fuel_label: Label = $TopBar/HBox/HaulContainer/FuelRow/FuelLabel
@onready var scrap_label: Label = $TopBar/HBox/HaulContainer/ScrapRow/ScrapLabel

# Warning overlay
@onready var cryo_warning: Label = $CryoWarning

# Side panel elements - updated paths for icon-based layout
@onready var side_panel: PanelContainer = $SidePanel
@onready var selected_header: Label = $SidePanel/VBox/SelectedHeader
@onready var selected_name: Label = $SidePanel/VBox/SelectedName
@onready var hp_container: HBoxContainer = $SidePanel/VBox/HPContainer
@onready var hp_label: Label = $SidePanel/VBox/HPContainer/HPLabel
@onready var hp_bar: ProgressBar = $SidePanel/VBox/HPContainer/HPBar
@onready var ap_container: HBoxContainer = $SidePanel/VBox/APContainer
@onready var ap_label: Label = $SidePanel/VBox/APContainer/APLabel
@onready var ap_bar: ProgressBar = $SidePanel/VBox/APContainer/APBar
@onready var move_label: Label = $SidePanel/VBox/MoveRow/MoveLabel
@onready var attack_label: Label = $SidePanel/VBox/AttackLabel
@onready var cover_bonus_label: Label = $SidePanel/VBox/CoverBonusLabel
@onready var status_label: Label = $SidePanel/VBox/StatusLabel

# Ability section
@onready var ability_container: VBoxContainer = $SidePanel/VBox/AbilityContainer
@onready var ability_header: Label = $SidePanel/VBox/AbilityContainer/AbilityHeader
@onready var ability_button: Button = $SidePanel/VBox/AbilityContainer/AbilityButton
@onready var ability_desc: Label = $SidePanel/VBox/AbilityContainer/AbilityDesc

# Action buttons
@onready var end_turn_button: Button = $SidePanel/VBox/ButtonContainer/EndTurnButton
@onready var extract_button: Button = $SidePanel/VBox/ButtonContainer/ExtractButton

# Objectives panel
@onready var objectives_panel: PanelContainer = $ObjectivesPanel

# Unit stats tooltip
@onready var unit_stats_tooltip: Control = $UnitStatsTooltip

# Current ability info
var _current_ability_type: String = ""


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	ability_button.pressed.connect(_on_ability_pressed)
	cryo_warning.visible = false
	extract_button.visible = false
	ability_container.visible = false
	
	# Set up tooltips
	_setup_tooltips()


func _setup_tooltips() -> void:
	# Pause button tooltip
	pause_button.tooltip_text = "Pause the mission.\nYou can abandon the mission for a 20 colonist penalty."
	
	# Top bar tooltips
	turn_label.tooltip_text = "Current turn number. Each turn, cryo-stability decreases by 5%."
	stability_container.tooltip_text = "Cryo-Stability: Colonist life support status.\nDecreases 5% per turn. At 0%, lose 10 colonists per turn."
	stability_label.tooltip_text = "Cryo-Stability: Colonist life support status.\nDecreases 5% per turn. At 0%, lose 10 colonists per turn."
	stability_bar.tooltip_text = "Cryo-Stability: Colonist life support status.\nDecreases 5% per turn. At 0%, lose 10 colonists per turn."
	haul_container.tooltip_text = "Resources collected during this mission.\nWalk over fuel crates and scrap piles to collect them."
	
	# Side panel tooltips
	hp_container.tooltip_text = "Health Points: Unit's remaining health.\nIf HP reaches 0, the unit dies permanently."
	ap_container.tooltip_text = "Action Points: Used for moving and attacking.\nMovement costs 1 AP. Shooting costs 1 AP. Resets each round."
	end_turn_button.tooltip_text = "End this unit's turn and move to the next unit.\nAfter all units act, enemies take their turn."
	extract_button.tooltip_text = "Extract units from the mission.\nAt least 1 unit must be on extraction tiles (green areas).\nUnits not in the extraction zone will be left behind (KIA)."


func update_turn(turn_number: int) -> void:
	turn_label.text = "TURN: %d" % turn_number


func update_stability(stability: int) -> void:
	stability_bar.value = stability
	stability_label.text = "CRYO: %d%%" % stability

	if stability <= 0:
		stability_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		stability_bar.modulate = Color(1, 0.3, 0.3)
	elif stability <= 25:
		stability_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
		stability_bar.modulate = Color(1, 1, 0.3)
	else:
		stability_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
		stability_bar.modulate = Color(1, 1, 1)


func update_selected_unit(officer_name: String, current_ap: int, max_ap: int) -> void:
	# Legacy method for backwards compatibility
	update_selected_unit_full(officer_name, current_ap, max_ap, 100, 100, 5)


func update_selected_unit_full(officer_name: String, current_ap: int, max_ap: int, current_hp: int, max_hp: int, move_range: int, is_their_turn: bool = true, attack_range: int = 10, cover_level: int = 0, _officer_type: String = "") -> void:
	selected_name.text = officer_name.to_upper()
	
	# Health display - shorter format for icon layout
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	
	# Color HP bar based on health percentage
	var hp_percent = float(current_hp) / float(max_hp) if max_hp > 0 else 0
	if hp_percent <= 0.25:
		hp_bar.modulate = Color(1, 0.3, 0.3)
	elif hp_percent <= 0.5:
		hp_bar.modulate = Color(1, 1, 0.3)
	else:
		hp_bar.modulate = Color(0.3, 1, 0.3)
	
	# Action points display - shorter format for icon layout
	ap_label.text = "AP: %d / %d" % [current_ap, max_ap]
	ap_bar.max_value = max_ap
	ap_bar.value = current_ap
	
	# Color AP bar based on AP remaining
	if current_ap == 0:
		ap_bar.modulate = Color(0.5, 0.5, 0.5)
	else:
		ap_bar.modulate = Color(1.0, 0.69, 0.0)
	
	# Movement and attack range
	move_label.text = "MOVE: %d tiles" % move_range
	attack_label.text = "ATTACK RANGE: %d tiles" % attack_range
	
	# Update tooltips with current values
	move_label.tooltip_text = "Maximum distance this unit can move in one action.\nMoving costs 1 Action Point."
	attack_label.tooltip_text = "Maximum distance this unit can shoot.\nShooting costs 1 Action Point."
	
	# Update cover attack bonus display
	_update_cover_bonus_display(cover_level)
	
	# Dynamic status based on unit state
	_update_status(is_their_turn, current_ap, current_hp, max_hp)


func _update_status(is_their_turn: bool, current_ap: int, current_hp: int, max_hp: int) -> void:
	if not is_their_turn:
		status_label.text = "STATUS: ◌ WAITING"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		status_label.tooltip_text = "This unit is waiting. Other units must finish their turns first."
	elif current_ap == 0:
		status_label.text = "STATUS: ✗ NO ACTIONS"
		status_label.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
		status_label.tooltip_text = "No Action Points remaining. Click END TURN to proceed."
	elif current_hp <= max_hp * 0.25:
		status_label.text = "STATUS: ⚠ CRITICAL"
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		status_label.tooltip_text = "Unit is badly wounded! Consider retreating or healing."
	else:
		status_label.text = "STATUS: ▶ READY"
		status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.5))
		status_label.tooltip_text = "This unit can act. Click tiles to move or enemies to attack."


func _update_cover_bonus_display(cover_level: int) -> void:
	if not cover_bonus_label:
		return
	
	match cover_level:
		2:  # Full cover
			cover_bonus_label.visible = true
			cover_bonus_label.text = "COVER: +10% ACC"
			cover_bonus_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
			cover_bonus_label.tooltip_text = "Firing from full cover provides a stable shooting position.\n+10% accuracy bonus to all attacks."
		1:  # Half cover
			cover_bonus_label.visible = true
			cover_bonus_label.text = "COVER: +5% ACC"
			cover_bonus_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.8))
			cover_bonus_label.tooltip_text = "Firing from half cover provides some stability.\n+5% accuracy bonus to all attacks."
		_:  # No cover
			cover_bonus_label.visible = false


func update_haul(fuel: int, scrap: int) -> void:
	fuel_label.text = "FUEL: +%d" % fuel
	scrap_label.text = "SCRAP: +%d" % scrap
	fuel_label.tooltip_text = "Fuel cells collected this mission.\nFuel is used to jump between star systems."
	scrap_label.tooltip_text = "Scrap collected this mission.\nScrap can be traded for repairs and supplies."


func show_cryo_warning() -> void:
	cryo_warning.visible = true
	cryo_warning.text = "⚠ CRYO-FAILURE: LOSING 10 COLONISTS ⚠"

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


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func _on_pause_pressed() -> void:
	pause_pressed.emit()


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()


func _on_extract_pressed() -> void:
	extract_pressed.emit()


func update_ability_buttons(officer_type: String, current_ap: int, cooldown: int = 0) -> void:
	# Hide by default
	ability_container.visible = false
	_current_ability_type = ""
	
	# Determine ability info based on officer type
	var ability_name := ""
	var ability_text := ""
	var ability_description := ""
	var ability_tooltip := ""
	var ap_cost := 1
	
	match officer_type:
		"scout":
			ability_name = "overwatch"
			ability_text = "[ OVERWATCH ] - 1 AP"
			ability_description = "Enter overwatch stance. Guaranteed hit on the first enemy that moves within line of sight."
			ability_tooltip = "Overwatch: Costs 1 AP. Guaranteed hit on enemies that move in your sight."
			ap_cost = 1
		"tech":
			ability_name = "turret"
			ability_text = "[ TURRET ] - 1 AP"
			ability_description = "Deploy a sentry turret on an adjacent tile. Auto-shoots the nearest enemy each turn for 3 turns."
			ability_tooltip = "Turret: Costs 1 AP. Place auto-firing sentry (3 turns, 15 DMG/turn)."
			ap_cost = 1
		"medic":
			ability_name = "patch"
			ability_text = "[ PATCH ] - 2 AP"
			ability_description = "Heal an adjacent friendly unit for 50% of their maximum health."
			ability_tooltip = "Patch: Costs 2 AP. Heals adjacent ally for 50% max HP."
			ap_cost = 2
		"heavy":
			ability_name = "charge"
			ability_text = "[ CHARGE ] - 1 AP"
			ability_description = "Rush an enemy within 4 tiles. Instant-kills basic enemies; deals heavy damage to elites."
			ability_tooltip = "Charge: Costs 1 AP. Rush and devastate an enemy within 4 tiles."
			ap_cost = 1
		"captain":
			ability_name = "execute"
			ability_text = "[ EXECUTE ] - 1 AP"
			ability_description = "Guaranteed kill on an enemy within 4 tiles below 50% HP. Never misses."
			ability_tooltip = "Execute: Costs 1 AP. Instant kill on enemy within 4 tiles below 50% HP."
			ap_cost = 1
		"sniper":
			ability_name = "precision"
			ability_text = "[ PRECISION SHOT ] - 1 AP"
			ability_description = "Guaranteed hit on any visible enemy. Deals 2x damage (60)."
			ability_tooltip = "Precision Shot: Costs 1 AP. Guaranteed hit on any visible enemy for 60 damage."
			ap_cost = 1
	
	# Show ability if officer has one
	if ability_name != "":
		ability_container.visible = true
		_current_ability_type = ability_name
		
		# Check cooldown
		if cooldown > 0:
			ability_header.text = "ABILITY: [CD %d]" % cooldown
			ability_button.text = "%s (CD: %d)" % [ability_text, cooldown]
			ability_button.disabled = true
			ability_desc.text = ability_description + "\n>> On cooldown for %d more turn(s)." % cooldown
			ability_button.tooltip_text = ability_tooltip + "\nCooldown: %d turn(s) remaining." % cooldown
		else:
			ability_header.text = "SPECIALIST ABILITY:"
			ability_button.text = ability_text
			ability_button.disabled = current_ap < ap_cost
			ability_desc.text = ability_description
			ability_button.tooltip_text = ability_tooltip


func _on_ability_pressed() -> void:
	if _current_ability_type != "":
		ability_used.emit(_current_ability_type)


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
		combat_msg.text = ""  # Clear the message text


## Show unit stats tooltip with unit data
func show_unit_tooltip(unit: Node2D) -> void:
	if unit_stats_tooltip:
		unit_stats_tooltip.update_unit_stats(unit)


## Hide unit stats tooltip
func hide_unit_tooltip() -> void:
	if unit_stats_tooltip:
		unit_stats_tooltip.hide_tooltip()


## Initialize objectives panel with mission objectives
func initialize_objectives(objectives: Array[MissionObjective]) -> void:
	if objectives_panel:
		objectives_panel.initialize(objectives)


## Update a specific objective's display
func update_objective(objective_id: String) -> void:
	if objectives_panel:
		objectives_panel.update_objective(objective_id)