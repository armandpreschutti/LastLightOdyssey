extends Control
## Dialog for selecting the next story mission branch

const _TOOLTIP_BTN = preload("res://scripts/ui/tooltip_button.gd")

signal choice_made(mission_id: String)

@onready var choice_a_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ChoicesContainer/ChoiceAButton
@onready var choice_b_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ChoicesContainer/ChoiceBButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var subtitle_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel

var _choice_a_id: String = ""
var _choice_b_id: String = ""


func _ready() -> void:
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)


func setup(choices: Array[String], options_data: Dictionary) -> void:
	if choices.size() < 2:
		push_error("StoryChoiceDialog requires at least 2 choices")
		return

	_choice_a_id = choices[0]
	_choice_b_id = choices[1]

	# Set button labels and text
	var option_a = options_data.get(_choice_a_id, {})
	var option_b = options_data.get(_choice_b_id, {})

	choice_a_button.text = option_a.get("label", "CHOICE A")
	choice_b_button.text = option_b.get("label", "CHOICE B")

	# Set subtitle
	subtitle_label.text = "SELECT YOUR NEXT OPERATION"

	# Optionally set tooltip or additional info
	var desc_a = option_a.get("text", "")
	var desc_b = option_b.get("text", "")
	choice_a_button.set_script(_TOOLTIP_BTN)
	choice_a_button.tooltip_text = desc_a
	choice_b_button.set_script(_TOOLTIP_BTN)
	choice_b_button.tooltip_text = desc_b


func show_dialog() -> void:
	visible = true
	choice_a_button.grab_focus()


func hide_dialog() -> void:
	visible = false


func _on_choice_a_pressed() -> void:
	choice_made.emit(_choice_a_id)
	hide_dialog()


func _on_choice_b_pressed() -> void:
	choice_made.emit(_choice_b_id)
	hide_dialog()

