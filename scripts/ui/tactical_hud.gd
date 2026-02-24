extends Control
## Tactical HUD - Displays mission info, unit stats, and controls
## Designed for clarity with descriptive labels and tooltips

signal end_turn_pressed
signal extract_pressed
signal ability_used(ability_type: String)
signal pause_pressed
signal ability_cancelled

const ABILITY_ICON_PATH = "res://assets/sprites/ui/icons/abilities/"

# Pause button panel (top left)
@onready var pause_panel: PanelContainer = $TopLeftPanel
@onready var pause_button: Button = $TopLeftPanel/PauseButton

# Top bar elements - updated paths for icon-based layout
@onready var turn_label: Label = $TopBar/HBox/TurnContainer/TurnRow/TurnLabel
@onready var integrity_container: VBoxContainer = $TopBar/HBox/IntegrityContainer
@onready var integrity_label: Label = $TopBar/HBox/IntegrityContainer/IntegrityRow/IntegrityLabel
@onready var integrity_bar: ProgressBar = $TopBar/HBox/IntegrityContainer/IntegrityBar
@onready var haul_container: VBoxContainer = $TopBar/HBox/HaulContainer
@onready var fuel_label: Label = $TopBar/HBox/HaulContainer/FuelRow/FuelLabel

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

# Abilities panel (bottom-right, shown only when a unit is selected)
@onready var abilities_panel: PanelContainer = $AbilitiesPanel
@onready var system_panel: PanelContainer = $SystemPanel

@onready var ability_previews: Array[CenterContainer] = [
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow1/AbilityPreview1,
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow2/AbilityPreview2,
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow3/AbilityPreview3
]

# Ability section (inside AbilitiesPanel)
@onready var ability_container: VBoxContainer = $AbilitiesPanel/VBox/AbilityContainer
@onready var ability_btn_1: Button = $AbilitiesPanel/VBox/AbilityContainer/AbilityRow1/AbilityButton1
@onready var ability_btn_2: Button = $AbilitiesPanel/VBox/AbilityContainer/AbilityRow2/AbilityButton2
@onready var ability_btn_3: Button = $AbilitiesPanel/VBox/AbilityContainer/AbilityRow3/AbilityButton3
@onready var ability_buttons: Array[Button] = [ability_btn_1, ability_btn_2, ability_btn_3]

@onready var ability_rows: Array[HBoxContainer] = [
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow1,
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow2,
	$AbilitiesPanel/VBox/AbilityContainer/AbilityRow3
]
@onready var cancel_button: Button = $AbilitiesPanel/VBox/AbilityContainer/CancelButton

# System buttons (inside SystemPanel)
@onready var end_turn_button: Button = $SystemPanel/VBox/SystemHeader/ButtonContainer/EndTurnButton
@onready var extract_button: Button = $SystemPanel/VBox/SystemHeader/ButtonContainer/ExtractButton
# Objectives panel
@onready var objectives_panel: PanelContainer = $ObjectivesPanel

# Unit stats tooltip
@onready var unit_stats_tooltip: Control = $UnitStatsTooltip

# Ability panel (new upgraded abilities panel)
var ability_panel: Control = null

# Current ability info
var _is_animating: bool = false  # Track animation state to disable ability button
var _current_officer_key: String = ""  # Track current officer for ability panel
var _extract_tween: Tween = null  # Track extract pulse animation


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	abilities_panel.visible = false
	system_panel.visible = false

	# Load and setup ability panel
	var ability_panel_scene = preload("res://scenes/ui/ability_panel.tscn")
	if ability_panel_scene:
		ability_panel = ability_panel_scene.instantiate()
		add_child(ability_panel)
		ability_panel.ability_selected.connect(_on_ability_panel_ability_selected)
		ability_panel.panel_closed.connect(_on_ability_panel_closed)
	
	# Hide pause panel by default - only show during active tactical missions
	pause_panel.visible = false
	
	# Set up tooltips
	_setup_tooltips()


const _TOOLTIP_BTN  = preload("res://scripts/ui/tooltip_button.gd")
const _TOOLTIP_LBL  = preload("res://scripts/ui/tooltip_label.gd")
const _TOOLTIP_BAR  = preload("res://scripts/ui/tooltip_progress_bar.gd")
const _TOOLTIP_VBOX = preload("res://scripts/ui/tooltip_vbox.gd")
const _TOOLTIP_HBOX = preload("res://scripts/ui/tooltip_hbox.gd")

func _setup_tooltips() -> void:
	# Apply tooltip scripts so _make_custom_tooltip fires on each node
	pause_button.set_script(_TOOLTIP_BTN)
	pause_button.tooltip_text = "Pause the mission.\nYou can abandon the mission at the cost of 25% hull damage and forfeiting all collected resources."

	turn_label.set_script(_TOOLTIP_LBL)
	turn_label.tooltip_text = "Current turn number. Each turn, the ship takes structural damage (−1% Integrity)."

	integrity_container.set_script(_TOOLTIP_VBOX)
	integrity_container.tooltip_text = "Ship Integrity: Structural health of the ship.\nDecreases 1% per tactical turn. At 0%, the voyage fails."

	integrity_label.set_script(_TOOLTIP_LBL)
	integrity_label.tooltip_text = "Ship Integrity: Structural health of the ship.\nDecreases 1% per tactical turn. At 0%, the voyage fails."

	integrity_bar.set_script(_TOOLTIP_BAR)
	integrity_bar.tooltip_text = "Ship Integrity: Structural health of the ship.\nDecreases 1% per tactical turn. At 0%, the voyage fails."

	haul_container.set_script(_TOOLTIP_VBOX)
	haul_container.tooltip_text = "Resources collected during this mission.\nWalk over fuel crates to collect them."

	hp_container.set_script(_TOOLTIP_HBOX)
	hp_container.tooltip_text = "Health Points: Unit's remaining health.\nIf HP reaches 0, the unit dies permanently."

	ap_container.set_script(_TOOLTIP_HBOX)
	ap_container.tooltip_text = "Action Points: Used for moving and attacking.\nMovement costs 1 AP. Shooting costs 1 AP. Resets each round."

	end_turn_button.set_script(_TOOLTIP_BTN)
	end_turn_button.tooltip_text = "End this unit's turn and move to the next unit.\nAfter all units act, enemies take their turn."

	extract_button.set_script(_TOOLTIP_BTN)
	extract_button.tooltip_text = "Extract units from the mission.\nAt least 1 unit must be on extraction tiles (green areas).\nUnits not in the extraction zone will be left behind (KIA)."

	# Apply to static labels that get tooltip_text set later
	status_label.set_script(_TOOLTIP_LBL)
	move_label.set_script(_TOOLTIP_LBL)
	attack_label.set_script(_TOOLTIP_LBL)
	cover_bonus_label.set_script(_TOOLTIP_LBL)
	fuel_label.set_script(_TOOLTIP_LBL)

func update_turn(turn_number: int) -> void:
	turn_label.text = "TURN: %d" % turn_number


func update_integrity(integrity: int) -> void:
	integrity_bar.value = integrity
	integrity_label.text = "HULL: %d%%" % integrity

	if integrity <= 25:
		integrity_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		integrity_bar.modulate = Color(1, 0.3, 0.3)
	elif integrity <= 50:
		integrity_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
		integrity_bar.modulate = Color(1, 1, 0.3)
	else:
		integrity_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
		integrity_bar.modulate = Color(1, 1, 1)


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


func update_haul(fuel: int, cash: int) -> void:
	fuel_label.text = "FUEL: +%d" % fuel
	fuel_label.tooltip_text = "Fuel cells collected this mission.\nFuel is used to jump between star systems."




@warning_ignore("shadowed_variable_base_class")
func set_extract_visible(is_visible: bool) -> void:
	extract_button.visible = is_visible
	
	if _extract_tween:
		_extract_tween.kill()
		_extract_tween = null
		
	if is_visible:
		extract_button.modulate = Color(1, 1, 1, 1)
		_extract_tween = create_tween().set_loops()
		_extract_tween.tween_property(extract_button, "modulate", Color(1, 1, 1, 0.15), 0.4).set_trans(Tween.TRANS_SINE)
		_extract_tween.tween_property(extract_button, "modulate", Color(1, 1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
	else:
		extract_button.modulate = Color(1, 1, 1, 1)


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled
	# Immediately disable ability buttons if animating (update_ability_buttons() will handle proper state when called)
	if ability_container.visible and _is_animating:
		for btn in ability_buttons:
			if btn.visible:
				btn.disabled = true


func _on_pause_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	pause_pressed.emit()


func _on_end_turn_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	end_turn_pressed.emit()


func _on_extract_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	if _extract_tween:
		_extract_tween.kill()
		_extract_tween = null
	extract_button.modulate = Color(1, 1, 1, 1)
	extract_pressed.emit()


func update_ability_buttons(officer_type: String, current_ap: int, unit_ref: Object = null) -> void:
	abilities_panel.visible = true
	system_panel.visible = true
	_current_officer_key = officer_type

	ability_container.visible = false
	for btn in ability_buttons:
		btn.visible = false
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
			
	var active_ab_count := 0
	
	# Determine base ability info
	var ability_name := ""
	var ability_text := ""
	var ability_tooltip := ""
	var ap_cost := 1
	
	match officer_type:
		"scout":
			ability_name = "overwatch"
			ability_text = "[ OVERWATCH ] - 1 AP"
			ability_tooltip = "Overwatch: Costs 1 AP. Guaranteed hit on enemies that move in your sight."
		"tech":
			ability_name = "turret"
			ability_text = "[ TURRET ] - 1 AP"
			ability_tooltip = "Turret: Costs 1 AP. Place auto-firing sentry (3 turns, 15 DMG/turn)."
		"medic":
			ability_name = "patch"
			ability_text = "[ PATCH ] - 1 AP"
			ability_tooltip = "Patch: Costs 1 AP. Heals yourself or ally within 3 tiles for 62.5% max HP."
		"heavy":
			ability_name = "charge"
			ability_text = "[ CHARGE ] - 1 AP"
			ability_tooltip = "Charge: Costs 1 AP. Rush and devastate an enemy within 4 tiles."
		"captain":
			ability_name = "execute"
			ability_text = "[ EXECUTE ] - 1 AP"
			ability_tooltip = "Execute: Costs 1 AP. Instant kill on enemy within 4 tiles below 50% HP."
		"sniper":
			ability_name = "precision_shot"
			ability_text = "[ PRECISION SHOT ] - 1 AP"
			ability_tooltip = "Precision Shot: Costs 1 AP. Guaranteed hit on any visible enemy for 60 damage."

	# Configure base ability if exists
	if ability_name != "" and active_ab_count < ability_buttons.size():
		var base_cd: int = unit_ref.get_ability_cooldown(ability_name) if unit_ref else 0
		var is_on_cooldown := base_cd > 0
		var has_enough_ap := current_ap >= ap_cost
		
		var btn = ability_buttons[active_ab_count]
		btn.set_script(_TOOLTIP_BTN)
		if is_on_cooldown:
			btn.text = "%s (CD: %d)" % [ability_text, base_cd]
			btn.disabled = true
			btn.tooltip_text = ability_tooltip + "\nCooldown: %d turn(s) remaining." % base_cd
		else:
			btn.text = ability_text
			btn.disabled = not has_enough_ap or _is_animating
			btn.tooltip_text = ability_tooltip
			
		var captured_id = ability_name
		btn.pressed.connect(func(): ability_used.emit(captured_id))
		btn.visible = true
		ability_container.visible = true
		active_ab_count += 1

	# Add tier 2/3 abilities (unlocked or locked, active or passive)
	var od = GameState.get_officer(officer_type)
	if od:
		var all_abs = GameState.OFFICER_ABILITIES.get(officer_type, [])
		if all_abs.size() >= 6:
			# Tier 2 (Indices 1, 2)
			var tier2_id = ""
			for i in range(1, 3):
				if od.has_ability(all_abs[i]):
					tier2_id = all_abs[i]
					break
			
			# Tier 3 (Indices 3, 4, 5)
			var tier3_id = ""
			for i in range(3, 6):
				if od.has_ability(all_abs[i]):
					tier3_id = all_abs[i]
					break
			
			# Map to buttons synchronously
			var active_tiers = [tier2_id, tier3_id]
			for tier_ab_id in active_tiers:
				if active_ab_count >= ability_buttons.size():
					continue
					
				var btn = ability_buttons[active_ab_count]
				btn.set_script(_TOOLTIP_BTN)
				btn.remove_theme_color_override("font_disabled_color")
				
				if tier_ab_id == "":
					btn.text = "[ LOCKED ]"
					btn.disabled = true
					btn.tooltip_text = "Unlock this ability between missions."
				else:
					var def = GameState.get_ability_def(tier_ab_id)
					if def.get("type", "") == "passive":
						btn.text = "[ %s - PASSIVE ]" % def.get("name", tier_ab_id).to_upper()
						btn.disabled = true
						btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.7, 0.45, 1))
						btn.tooltip_text = def.get("desc", "")
					else:
						var ab_cost: int = def.get("cost", 1)
						var cd_remaining: int = unit_ref.get_ability_cooldown(tier_ab_id) if unit_ref else 0
						var on_cd := cd_remaining > 0
						
						if on_cd:
							btn.text = "[ %s ] - %d AP (CD: %d)" % [def.get("name", tier_ab_id).to_upper(), ab_cost, cd_remaining]
						else:
							btn.text = "[ %s ] - %d AP" % [def.get("name", tier_ab_id).to_upper(), ab_cost]
							
						btn.disabled = on_cd or current_ap < ab_cost or _is_animating
						btn.tooltip_text = def.get("desc", "")
						
						var captured_lambda := func(cid: String): ability_used.emit(cid)
						btn.pressed.connect(captured_lambda.bind(tier_ab_id))
						
				btn.visible = true
				ability_container.visible = true
				active_ab_count += 1

	# Ensure all 3 tier buttons are shown (fill empty with [LOCKED])
	while active_ab_count < ability_buttons.size():
		var btn = ability_buttons[active_ab_count]
		btn.text = "[ LOCKED ]"
		btn.disabled = true
		btn.tooltip_text = "Unlock more abilities between missions."
		btn.remove_theme_color_override("font_disabled_color")
		btn.visible = true
		ability_container.visible = true
		active_ab_count += 1

	_update_ability_preview(officer_type)


func _on_cancel_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	ability_cancelled.emit()


func show_cancel_button() -> void:
	cancel_button.visible = true
	end_turn_button.disabled = true


func hide_cancel_button() -> void:
	cancel_button.visible = false
	# Re-enable end turn button as long as we're not currently animating
	if not _is_animating:
		end_turn_button.disabled = false


## Show a combat message (for attack phases)
func show_combat_message(message: String, color: Color = Color(1, 1, 0.2)) -> void:
	# Get the combat message label from the parent tactical scene
	var combat_msg = get_node_or_null("../../UILayer/CombatMessageContainer/CombatMessage")
	if combat_msg:
		combat_msg.text = message
		combat_msg.add_theme_color_override("font_color", color)
		combat_msg.visible = true
		# Show the background panel when message is shown
		var background_panel = get_node_or_null("../../UILayer/CombatMessageContainer/BackgroundPanel")
		if background_panel:
			background_panel.visible = true


## Hide the combat message
func hide_combat_message() -> void:
	var combat_msg = get_node_or_null("../../UILayer/CombatMessageContainer/CombatMessage")
	if combat_msg:
		combat_msg.visible = false
		# Hide the background panel when message is hidden
		var background_panel = get_node_or_null("../../UILayer/CombatMessageContainer/BackgroundPanel")
		if background_panel:
			background_panel.visible = false
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


## Explicitly show/hide objectives panel (story missions only)
func set_objectives_panel_visible(show: bool) -> void:
	if objectives_panel:
		objectives_panel.visible = show


## Update a specific objective's display
func update_objective(objective_id: String) -> void:
	if objectives_panel:
		objectives_panel.update_objective(objective_id)


## Show the pause button panel (only during active tactical missions)
func show_pause_button() -> void:
	pause_panel.visible = true


## Hide the pause button panel (when not in tactical missions)
func hide_pause_button() -> void:
	pause_panel.visible = false


## Deactivate and reset ABILITIES and COMMANDS panels (e.g. during extraction)
func hide_abilities_and_commands_panels() -> void:
	abilities_panel.visible = false
	system_panel.visible = false
	cancel_button.visible = false
	if ability_panel:
		ability_panel.hide_panel()


func _update_ability_preview(officer_type: String) -> void:
	for preview in ability_previews:
		for child in preview.get_children():
			child.free()
	if officer_type == "":
		return
	var od = GameState.get_officer(officer_type)
	if not od: return
	var abilities = GameState.OFFICER_ABILITIES.get(officer_type, [])
	if abilities.size() < 6: return
	var accent = GameState.OFFICER_COLOR.get(officer_type, Color(0.4, 0.9, 1.0))
	var tiers = [[abilities[0]], [abilities[1], abilities[2]], [abilities[3], abilities[4], abilities[5]]]
	for i in range(3):
		var unlocked_ab_id = ""
		for ab_id in tiers[i]:
			if od.has_ability(ab_id):
				unlocked_ab_id = ab_id
				break
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(32, 32)
		var sb = StyleBoxFlat.new()
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		if unlocked_ab_id != "":
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
			sb.border_color = Color(accent.r, accent.g, accent.b, 0.7)
		else:
			sb.bg_color = Color(0.04, 0.06, 0.1, 0.6)
			sb.border_color = Color(0.25, 0.25, 0.3, 0.4)
		slot.add_theme_stylebox_override("panel", sb)
		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if unlocked_ab_id != "":
			var def = GameState.ABILITY_DEFS.get(unlocked_ab_id, {})
			var ab_name = def.get("name", "Unknown")
			var ab_desc = def.get("desc", "")
			var tooltip_text = "%s: %s" % [ab_name, ab_desc]

			# Use tooltip_area for proper tooltip support
			slot.set_script(preload("res://scripts/ui/tooltip_area.gd"))
			slot.tooltip_delay_sec = 0.25
			slot.tooltip_text = tooltip_text

			var tex = load(ABILITY_ICON_PATH + "%s_%s.png" % [officer_type, unlocked_ab_id])
			if tex:
				icon_rect.texture = tex
				icon_rect.modulate = Color(1, 1, 1, 1)
			else:
				icon_rect.modulate = Color(accent.r, accent.g, accent.b, 0.7)
		else:
			icon_rect.modulate = Color(0.25, 0.25, 0.3, 0.5)
		slot.add_child(icon_rect)
		ability_previews[i].add_child(slot)


## Show upgraded abilities panel for current officer
func show_ability_panel(officer_key: String, unit: Node2D) -> void:
	if ability_panel:
		_current_officer_key = officer_key
		ability_panel.show_abilities(officer_key, unit)


## Called when an ability is selected from the panel
func _on_ability_panel_ability_selected(ability_id: String) -> void:
	ability_used.emit(ability_id)


## Called when ability panel is closed
func _on_ability_panel_closed() -> void:
	pass
