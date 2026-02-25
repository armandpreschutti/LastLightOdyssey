extends Control
## Fuel Warning Dialog - Warns the player about drift mode
## Includes a "Don't show again" option

signal confirmed(suppress_warning: bool)
signal cancelled

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var jump_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/JumpButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton
@onready var dont_show_toggle: Button = $PanelContainer/MarginContainer/VBoxContainer/DontShowCheckbox

var _icon_unchecked: Texture2D
var _icon_checked: Texture2D


func _ready() -> void:
	_create_checkbox_icons()
	jump_button.pressed.connect(_on_jump_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	dont_show_toggle.toggled.connect(_update_toggle_visual)
	cancel_button.grab_focus()
	_update_toggle_visual(dont_show_toggle.button_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func setup(hull_loss: int) -> void:
	title_label.text = "[ INSUFFICIENT FUEL ]"
	message_label.text = "DRIFT MODE will engage.\n\nPenalties:\n• -%d%% HULL\n\nProceed with jump?" % [hull_loss]
	jump_button.text = "[ DRIFT ]"
	cancel_button.text = "[ CANCEL ]"


func show_dialog() -> void:
	visible = true
	cancel_button.grab_focus()
	
	# Animate appearance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_jump_pressed() -> void:
	confirmed.emit(dont_show_toggle.button_pressed)
	_close()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	_close()


	var dark := Color(0.08, 0.08, 0.12)
func _create_checkbox_icons() -> void:
	const SIZE := 20
	var accent := Color(0.4, 0.9, 1.0)

	# Unchecked: outlined box
	var img_unchecked := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _draw_checkbox(false, SIZE, accent))
	_icon_unchecked = ImageTexture.create_from_image(img_unchecked)

	# Checked: filled box with checkmark
	var img_checked := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _draw_checkbox(true, SIZE, accent))
	_icon_checked = ImageTexture.create_from_image(img_checked)


func _draw_checkbox(checked: bool, size: int, accent: Color) -> PackedByteArray:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var border := 2
	for y in size:
		for x in size:
			var on_border := x < border or x >= size - border or y < border or y >= size - border
			var inner := x >= border and x < size - border and y >= border and y < size - border

			if on_border:
				img.set_pixel(x, y, Color(accent.r, accent.g, accent.b, 0.85))
			elif checked and inner:
				img.set_pixel(x, y, Color(accent.r, accent.g, accent.b, 0.3))
			# Unchecked inner stays transparent

	if checked:
		# Checkmark: left leg, then right leg
		var pts: Array[Vector2] = [Vector2(5, 10), Vector2(9, 14), Vector2(15, 6)]
		for i in range(pts.size() - 1):
			var from: Vector2 = pts[i]
			var to: Vector2 = pts[i + 1]
			var steps := int(max(absf(to.x - from.x), absf(to.y - from.y))) + 1
			for j in range(steps + 1):
				var t := (float(j) / steps) if steps > 0 else 1.0
				var px := int(lerpf(from.x, to.x, t))
				var py := int(lerpf(from.y, to.y, t))
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, accent)

	return img.get_data()


func _update_toggle_visual(pressed: bool) -> void:
	dont_show_toggle.icon = _icon_checked if pressed else _icon_unchecked


func _close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
