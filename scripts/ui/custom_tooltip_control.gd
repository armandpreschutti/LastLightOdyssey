extends Control
## Attach this script (or extend it) on any Control that uses tooltip_text.
## Overrides _make_custom_tooltip to produce a styled, word-wrapped tooltip box
## instead of Godot's default single-line tooltip.

const MAX_TOOLTIP_WIDTH := 260.0

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style
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
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	margin.add_child(label)

	# Clamp width so it wraps into a square-ish shape
	panel.custom_minimum_size = Vector2(MAX_TOOLTIP_WIDTH, 0)

	return panel
