extends Control
## Ability Panel - Shows available abilities for selected officer during tactical missions

const _TOOLTIP_BTN = preload("res://scripts/ui/tooltip_button.gd")

signal ability_selected(ability_id: String)
signal panel_closed

@onready var title_label: Label = $"Background/VBox/Title"
@onready var abilities_container: VBoxContainer = $"Background/VBox/ScrollContainer/VBoxContainer"
@onready var close_button: Button = $"Background/VBox/CloseButton"
@onready var scroll_container: ScrollContainer = $"Background/VBox/ScrollContainer"

var ability_button_scene: PackedScene = null  # Will load dynamically

var current_officer_key: String = ""
var current_unit: Node2D = null  # Reference to the selected Unit
var available_abilities: Array[String] = []


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


## Show ability panel for a specific officer
func show_abilities(officer_key: String, unit: Node2D) -> void:
	current_officer_key = officer_key
	current_unit = unit

	if title_label:
		title_label.text = "ABILITIES - %s" % officer_key.to_upper()

	_populate_abilities()
	visible = true

	# Auto-scroll to top
	if scroll_container:
		await get_tree().process_frame  # Wait one frame for layout
		scroll_container.get_v_scroll_bar().value = 0


## Populate ability list for current officer
func _populate_abilities() -> void:
	# Clear existing buttons
	for child in abilities_container.get_children():
		child.queue_free()

	available_abilities.clear()

	var od: OfficerData = GameState.get_officer(current_officer_key)
	if not od:
		return

	# Get all unlocked abilities for this officer
	var officer_abilities = GameState.OFFICER_ABILITIES.get(current_officer_key, [])
	for ab_id in officer_abilities:
		if od.has_ability(ab_id):
			var ability_def = GameState.get_ability_def(ab_id)
			if ability_def.is_empty():
				continue

			# Skip passive abilities (they're always active)
			var ability_type = ability_def.get("type", "passive")
			if ability_type == "passive":
				continue

			# Check if ability can be used (has AP, not on cooldown)
			if _can_use_ability(ab_id):
				available_abilities.append(ab_id)
				var button = _create_ability_button(ab_id, ability_def)
				abilities_container.add_child(button)


## Create a button for an ability
func _create_ability_button(ability_id: String, ability_def: Dictionary) -> Button:
	var button = Button.new()
	button.set_script(_TOOLTIP_BTN)
	var name_text = ability_def.get("name", ability_id)
	var cost = ability_def.get("cost", 1)
	var level = ability_def.get("level", 1)

	# Show level indicator for upgraded abilities
	var level_text = "L%d" % level if level > 1 else ""
	var final_text = "%s %s (AP: %d)" % [name_text, level_text, cost]

	button.text = final_text.strip_edges()
	button.custom_minimum_size = Vector2(300, 40)
	button.pressed.connect(_on_ability_button_pressed.bind(ability_id))

	# Add tooltip with description
	var desc = ability_def.get("desc", "")
	if desc:
		button.tooltip_text = desc

	return button


## Check if ability can be used
func _can_use_ability(ability_id: String) -> bool:
	if not current_unit:
		return false

	var ability_def = GameState.get_ability_def(ability_id)
	if ability_def.is_empty():
		return false

	var cost = ability_def.get("cost", 1)

	# Check AP
	if not current_unit.has_ap(cost):
		return false

	# Check cooldown
	if current_unit.is_ability_on_cooldown(ability_id):
		return false

	return true


func _on_ability_button_pressed(ability_id: String) -> void:
	ability_selected.emit(ability_id)
	visible = false


func _on_close_pressed() -> void:
	visible = false
	panel_closed.emit()


## Hide the panel
func hide_panel() -> void:
	visible = false
