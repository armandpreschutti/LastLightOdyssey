extends Control
## Confirmation Dialog - Simple yes/no prompt
## Used for confirming destructive actions like erasing save data

signal confirmed
signal cancelled

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var yes_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/YesButton
@onready var no_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/NoButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	no_button.grab_focus()  # Default to "No" for safety


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_no_pressed()
		get_viewport().set_input_as_handled()


func setup(title: String, message: String, yes_text: String = "YES", no_text: String = "NO") -> void:
	title_label.text = title
	message_label.text = message
	yes_button.text = "[ %s ]" % yes_text
	no_button.text = "[ %s ]" % no_text


func show_dialog() -> void:
	visible = true
	no_button.grab_focus()
	
	# Animate appearance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_yes_pressed() -> void:
	confirmed.emit()
	_close()


func _on_no_pressed() -> void:
	cancelled.emit()
	_close()


func _close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
