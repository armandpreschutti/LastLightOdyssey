extends VBoxContainer
## Attach via set_script() to any VBoxContainer that needs a styled, word-wrapped tooltip.

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
