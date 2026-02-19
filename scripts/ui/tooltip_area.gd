extends Control
## Attach to any Control node that uses tooltip_text.
## Provides a styled, word-wrapped custom tooltip box.

var tooltip_delay_sec: float = 0.0
var _tooltip_timer: Timer = null
var _pending_tooltip: String = ""
var _original_tooltip: String = ""

func _ready() -> void:
	# Capture tooltip_text via deferred call so it picks up any text set
	# after set_script() (e.g. in tactical_hud._update_ability_preview)
	call_deferred("_capture_original_tooltip")
	if tooltip_delay_sec > 0:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

func _capture_original_tooltip() -> void:
	if _original_tooltip.is_empty():
		_original_tooltip = tooltip_text

func _on_mouse_entered() -> void:
	# Re-capture if tooltip_text was updated externally after initial capture
	if not tooltip_text.is_empty():
		_original_tooltip = tooltip_text
	if tooltip_delay_sec > 0 and not _original_tooltip.is_empty():
		_pending_tooltip = _original_tooltip
		tooltip_text = ""  # Clear to prevent immediate tooltip

		if _tooltip_timer == null:
			_tooltip_timer = Timer.new()
			add_child(_tooltip_timer)
			_tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)

		_tooltip_timer.start(tooltip_delay_sec)

func _on_mouse_exited() -> void:
	if _tooltip_timer:
		_tooltip_timer.stop()
	tooltip_text = ""

func _on_tooltip_timer_timeout() -> void:
	if _tooltip_timer:
		_tooltip_timer.stop()
	tooltip_text = _pending_tooltip

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.03, 0.08, 0.95)
	sb.border_width_left = 3
	sb.border_color = Color(0.4, 0.9, 1.0, 0.85)
	sb.set_content_margin_all(10)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	margin.add_child(label)

	panel.custom_minimum_size = Vector2(260, 0)
	return panel
