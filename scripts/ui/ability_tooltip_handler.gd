extends Node
## Robust handles two-stage tooltips for ability slots.
## Uses proactive rect detection to bypass signal blockage.

var _target: Control
var _ab_id: String
var _is_hovering: bool = false
var _hover_start_time: float = 0.0
var _desc_box: PanelContainer = null

func setup(target: Control, ab_id: String) -> void:
	_target = target
	_ab_id = ab_id
	
	var def = GameState.ABILITY_DEFS.get(ab_id, {})
	_target.tooltip_text = def.get("name", "Unknown")


func _process(_delta: float) -> void:
	if not _target or not _target.is_inside_tree() or not _target.is_visible_in_tree():
		_cleanup()
		_is_hovering = false
		return
		
	var mouse_pos = _target.get_global_mouse_position()
	var rect = _target.get_global_rect()
	var is_inside = rect.has_point(mouse_pos)
	
	if is_inside:
		if not _is_hovering:
			_is_hovering = true
			_hover_start_time = Time.get_ticks_msec() / 1000.0
		else:
			var elapsed = (Time.get_ticks_msec() / 1000.0) - _hover_start_time
			if elapsed >= 1.25 and not _desc_box:
				_show_desc()
	else:
		if _is_hovering:
			_cleanup()
			_is_hovering = false

	if _desc_box:
		_update_desc_pos(mouse_pos)


func _show_desc() -> void:
	var def = GameState.ABILITY_DEFS.get(_ab_id, {})
	var ab_desc = def.get("desc", "")
	if ab_desc == "": return
	
	_desc_box = PanelContainer.new()
	_desc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_box.z_index = 100 # Put it on top
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.03, 0.08, 0.95)
	sb.border_width_left = 4
	sb.border_color = Color(0.4, 0.9, 1.0, 0.9) # Cyan accent
	sb.set_content_margin_all(10)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	_desc_box.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_desc_box.add_child(vbox)
	
	var title = Label.new()
	title.text = def.get("name", "Unknown").to_upper()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = ab_desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 240
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(desc)
	
	# Add to main viewport so it's always on top of menus
	_target.get_tree().root.add_child(_desc_box)


func _update_desc_pos(mouse_pos: Vector2) -> void:
	# Position slightly below and to the right of cursor
	var offset = Vector2(20, 25)
	var target_pos = mouse_pos + offset
	var screen_size = _target.get_viewport_rect().size
	
	# Keep box on screen
	var box_size = _desc_box.get_combined_minimum_size()
	if target_pos.x + box_size.x > screen_size.x:
		target_pos.x = mouse_pos.x - box_size.x - 10
	if target_pos.y + box_size.y > screen_size.y:
		target_pos.y = mouse_pos.y - box_size.y - 10
		
	_desc_box.global_position = target_pos


func _cleanup() -> void:
	if _desc_box and is_instance_valid(_desc_box):
		_desc_box.queue_free()
	_desc_box = null


func _exit_tree() -> void:
	_cleanup()
