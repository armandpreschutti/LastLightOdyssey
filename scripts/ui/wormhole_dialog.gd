extends Control
## Wormhole Dialog - Handles interaction with wormholes

signal confirmed
signal cancelled

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var enter_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/EnterButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton


func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func setup() -> void:
	title_label.text = "WORMHOLE DETECTED"
	message_label.text = "ANOMALY DETECTED\n\nA stable wormhole has been detected in this sector. Logic engines calculate a 94.3% probability of safe transport to another wormhole node within the cluster.\n\nDestination unknown."
	enter_button.text = "[ ENTER WORMHOLE ]"
	cancel_button.text = "[ STAY ]"


func show_dialog() -> void:
	visible = true
	cancel_button.grab_focus()
	
	# Animate appearance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_enter_pressed() -> void:
	confirmed.emit()
	_close()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	_close()


func _close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
