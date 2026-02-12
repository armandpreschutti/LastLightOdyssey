extends Control
## Fuel Warning Dialog - Warns the player about drift mode
## Includes a "Don't show again" option

signal confirmed(suppress_warning: bool)
signal cancelled

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var jump_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/JumpButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton
@onready var dont_show_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/DontShowCheckbox


func _ready() -> void:
	jump_button.pressed.connect(_on_jump_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func setup(colonist_loss: int, hull_loss: int) -> void:
	title_label.text = "⚠ INSUFFICIENT FUEL"
	message_label.text = "DRIFT MODE will engage.\n\nPenalties:\n• -%d COLONISTS\n• -%d HULL INTEGRITY\n\nProceed with jump?" % [colonist_loss, hull_loss]
	jump_button.text = "[ JUMP ]"
	cancel_button.text = "[ CANCEL ]"


func show_dialog() -> void:
	visible = true
	cancel_button.grab_focus()
	
	# Animate appearance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_jump_pressed() -> void:
	confirmed.emit(dont_show_checkbox.button_pressed)
	_close()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	_close()


func _close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
