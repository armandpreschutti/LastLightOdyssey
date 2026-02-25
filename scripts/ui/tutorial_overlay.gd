extends Control
## TutorialOverlay - Lightweight contextual tutorial display.
## Builds its entire UI programmatically (no scene tree dependencies).
## Shows multi-step tooltips with an optional arrow pointing to a target area.
## Styled to match the game's retro CRT terminal aesthetic.
class_name TutorialOverlay

signal tutorial_completed
signal tutorial_skipped

# ── Visual constants ──────────────────────────────────────────────────────────
const PANEL_WIDTH     := 400.0
const VIGNETTE_ALPHA  := 0.45
const PANEL_BG        := Color(0.01, 0.03, 0.08, 0.97)
const BORDER_COLOR    := Color(0.4, 0.9, 1.0, 0.85)
const HEADER_COLOR    := Color(0.4, 0.9, 1.0, 1.0)   # cyan
const BODY_COLOR      := Color(0.88, 0.93, 1.0, 1.0)
const STEP_COLOR      := Color(0.4, 0.5, 0.55, 1.0)
const SKIP_COLOR      := Color(0.45, 0.5, 0.55, 1.0)
const ARROW_COLOR     := Color(0.4, 0.9, 1.0, 0.9)
const ARROW_WIDTH     := 2.5
const ARROWHEAD_SIZE  := 12.0

# Panel center positions expressed as fractions of the viewport (width, height).
# Adjust if the layout ever changes.
const PANEL_ANCHORS: Dictionary = {
	"center"       : Vector2(0.50, 0.50),
	"center_right" : Vector2(0.78, 0.48),
	"top_right"    : Vector2(0.78, 0.18),
	"top_left"     : Vector2(0.22, 0.18),
	"bottom_right" : Vector2(0.78, 0.82),
}

# ── State ─────────────────────────────────────────────────────────────────────
var _steps: Array        = []
var _current_step: int   = 0

# ── Built nodes ───────────────────────────────────────────────────────────────
var _vignette: ColorRect
var _arrow_layer: Control    # draws the arrow shaft + head
var _panel: PanelContainer
var _header_label: Label
var _body_label: Label
var _step_label: Label
var _next_button: Button
var _skip_button: Button

# Arrow geometry (set per-step; read in _draw of _arrow_layer)
var _arrow_from: Vector2 = Vector2.ZERO
var _arrow_to:   Vector2 = Vector2.ZERO
var _draw_arrow: bool    = false


func _ready() -> void:
	_build_ui()
	visible = false
	# Process even when paused so the tutorial can show mid-mission later
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Public API ────────────────────────────────────────────────────────────────

## Feed the steps array from TutorialManager.
func setup_steps(steps: Array) -> void:
	_steps = steps
	_current_step = 0


## Make the overlay visible and display the first step.
func show_overlay() -> void:
	visible = true
	_show_step(_current_step)

	# Subtle fade-in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


# ── Step logic ────────────────────────────────────────────────────────────────

func _show_step(index: int) -> void:
	if index >= _steps.size():
		_emit_complete()
		return

	var step: Dictionary = _steps[index]
	var header: String   = step.get("header", "")
	var body: String     = step.get("body", "")
	var anchor_key = step.get("panel_anchor", "center")  # String key or Vector2
	var arrow_frac: Vector2 = step.get("arrow_target", Vector2(-1.0, -1.0))

	# Update labels
	_header_label.text = "[ %s ]" % header.to_upper()
	_body_label.text   = body
	_step_label.text   = "%d / %d" % [index + 1, _steps.size()]

	# Toggle button text
	if index >= _steps.size() - 1:
		_next_button.text = "[ GOT IT ]"
	else:
		_next_button.text = "[ NEXT ]"

	# Wait a frame so the panel can measure its final size before positioning
	await get_tree().process_frame

	_position_panel(anchor_key)
	_update_arrow(arrow_frac)


func _position_panel(anchor_key) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var anchor: Vector2
	if typeof(anchor_key) == TYPE_VECTOR2:
		anchor = anchor_key
	else:
		anchor = PANEL_ANCHORS.get(str(anchor_key), Vector2(0.5, 0.48))
	var center: Vector2 = anchor * vp_size
	var panel_size: Vector2 = _panel.size
	var pos: Vector2 = center - panel_size * 0.5
	# Clamp so it doesn't spill off screen
	pos.x = clamp(pos.x, 20.0, vp_size.x - panel_size.x - 20.0)
	pos.y = clamp(pos.y, 20.0, vp_size.y - panel_size.y - 20.0)
	_panel.position = pos


func _update_arrow(arrow_frac: Vector2) -> void:
	if arrow_frac.x < 0.0:
		_draw_arrow = false
		_arrow_layer.queue_redraw()
		return

	var vp_size := get_viewport_rect().size
	_arrow_to   = arrow_frac * vp_size
	# Arrow starts from the closest edge midpoint of the panel
	_arrow_from = _closest_panel_edge_point(_arrow_to)
	_draw_arrow = true
	_arrow_layer.queue_redraw()


func _closest_panel_edge_point(target: Vector2) -> Vector2:
	var r := Rect2(_panel.position, _panel.size)
	var center := r.get_center()
	var diff := target - center

	# Parametric intersection with rect edges
	var t_candidates: Array[float] = []
	if abs(diff.x) > 0.001:
		t_candidates.append((r.position.x - center.x) / diff.x)
		t_candidates.append((r.end.x      - center.x) / diff.x)
	if abs(diff.y) > 0.001:
		t_candidates.append((r.position.y - center.y) / diff.y)
		t_candidates.append((r.end.y      - center.y) / diff.y)

	var best_t := 1.0
	for t in t_candidates:
		if t > 0.001 and t < best_t:
			# Verify the point is actually on the rect's perimeter
			var pt := center + diff * t
			if pt.x >= r.position.x - 1.0 and pt.x <= r.end.x + 1.0 \
					and pt.y >= r.position.y - 1.0 and pt.y <= r.end.y + 1.0:
				best_t = t

	return center + diff * best_t


# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_next_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")

	_current_step += 1
	if _current_step >= _steps.size():
		_emit_complete()
	else:
		_show_step(_current_step)


func _on_skip_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	_draw_arrow = false
	tutorial_skipped.emit()
	queue_free()


func _emit_complete() -> void:
	_draw_arrow = false
	tutorial_completed.emit()
	queue_free()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fill the whole viewport
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE   # pass clicks to game beneath

	# ── Vignette ──────────────────────────────────────────────────────────────
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vignette.color = Color(0.0, 0.0, 0.0, VIGNETTE_ALPHA)
	_vignette.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# ── Arrow layer (drawn on top of vignette, under panel) ───────────────────
	_arrow_layer = Control.new()
	_arrow_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_arrow_layer.draw.connect(_draw_arrow_line)
	add_child(_arrow_layer)

	# ── Panel ─────────────────────────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	_panel.mouse_filter = MOUSE_FILTER_STOP   # panel itself captures clicks so they don't hit the map

	var sb := StyleBoxFlat.new()
	sb.bg_color       = PANEL_BG
	sb.border_width_left   = 3
	sb.border_width_right  = 3
	sb.border_width_top    = 3
	sb.border_width_bottom = 3
	sb.border_color   = BORDER_COLOR
	sb.set_content_margin_all(18.0)
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.shadow_color   = Color(0.0, 0.0, 0.0, 0.7)
	sb.shadow_size    = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# Inner VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header_label)

	# Thin separator line
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0.0, 2.0)
	sep.color = Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.35)
	sep.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_child(sep)

	# Body
	_body_label = Label.new()
	_body_label.add_theme_color_override("font_color", BODY_COLOR)
	_body_label.add_theme_font_size_override("font_size", 14)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 0.0)
	vbox.add_child(_body_label)

	# Step counter
	_step_label = Label.new()
	_step_label.add_theme_color_override("font_color", STEP_COLOR)
	_step_label.add_theme_font_size_override("font_size", 11)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_step_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	_skip_button = _make_button("[ SKIP TUTORIAL ]", SKIP_COLOR)
	_skip_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_next_button = _make_button("[ NEXT ]", HEADER_COLOR)
	_next_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_button)


func _make_button(label_text: String, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.flat = true
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", Color(font_color.r, font_color.g, font_color.b, 1.0).lightened(0.25))
	btn.add_theme_color_override("font_pressed_color", font_color.darkened(0.15))
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE

	# Transparent background
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("pressed", sb_normal)
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(font_color.r, font_color.g, font_color.b, 0.08)
	btn.add_theme_stylebox_override("hover", sb_hover)
	return btn


# ── Arrow drawing ─────────────────────────────────────────────────────────────

func _draw_arrow_line() -> void:
	if not _draw_arrow:
		return

	var dir := (_arrow_to - _arrow_from).normalized()
	# Leave a small gap at the tip so the head sits cleanly
	var shaft_end := _arrow_to - dir * ARROWHEAD_SIZE

	# Shaft
	_arrow_layer.draw_line(_arrow_from, shaft_end, ARROW_COLOR, ARROW_WIDTH, true)

	# Arrowhead (filled triangle)
	var perp := Vector2(-dir.y, dir.x) * ARROWHEAD_SIZE * 0.5
	var head_pts := PackedVector2Array([
		_arrow_to,
		shaft_end + perp,
		shaft_end - perp,
	])
	_arrow_layer.draw_colored_polygon(head_pts, ARROW_COLOR)

	# Small pulsing dot at the tip target (drawn as a filled circle)
	_arrow_layer.draw_circle(_arrow_to, 5.0, ARROW_COLOR)
