extends Control
## Off-Screen Indicator - Arrow on screen edge pointing toward a target (raider, story node, etc.)
## Supports configurable color via arrow_color property.
## All marker types: pulse glow. MISSION OBJECTIVE and EXTRACTION ZONE: Y-axis bob when above element.

## Inset from screen edges (pixels).
const MARGIN_LEFT: float = 300.0
const MARGIN_TOP: float = 40.0
const MARGIN_RIGHT: float = 300.0
const MARGIN_BOTTOM: float = 40.0

## Arrow size (half-width/height of triangle)
const ARROW_SIZE: float = 16.0

## Vertical offset when on-screen: raise arrow above the target (negative Y)
const ON_SCREEN_Y_OFFSET: float = -38.0

## When true, marker snaps above target when both are on-screen. When false, marker hides when on-screen.
const ENABLE_ON_SCREEN_SNAP: bool = false

## Pulse glow animation
const PULSE_SPEED: float = 2.5
const PULSE_GLOW_MIN_ALPHA: float = 0.25
const PULSE_GLOW_MAX_ALPHA: float = 0.6
const GLOW_SCALE: float = 1.6  # Scale factor for glow behind arrow

## Y-axis bob when marker is above element (MISSION OBJECTIVE, EXTRACTION ZONE)
const BOB_AMPLITUDE: float = 4.0
const BOB_SPEED: float = 0.005  # Radians per ms

## Default red tint matching raider ship
const ARROW_COLOR: Color = Color(1.0, 0.3, 0.3, 0.95)

## Current arrow color (overridable for story signal, etc.)
var arrow_color: Color = ARROW_COLOR

var _pulse_phase: float = 0.0
var _is_above_target: bool = false  # True when marker is snapped above on-screen element (enables Y bob)


func set_indicator_color(color: Color) -> void:
	arrow_color = color
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pivot at center so rotation works correctly
	pivot_offset = Vector2(ARROW_SIZE, ARROW_SIZE)
	custom_minimum_size = Vector2(ARROW_SIZE * 2, ARROW_SIZE * 2)
	size = custom_minimum_size


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_phase += delta * PULSE_SPEED
	queue_redraw()


## Update position and rotation based on target screen position and viewport size.
## target_screen_pos: target position in screen coordinates
## viewport_size: size of the viewport (visible area)
## snap_when_on_screen: when true and target is on-screen, snap marker above it; when false, hide marker
func update_indicator(target_screen_pos: Vector2, viewport_size: Vector2, snap_when_on_screen: bool = false) -> void:
	# On-screen: target visible within full viewport
	var is_on_screen: bool = (
		target_screen_pos.x >= 0.0 and target_screen_pos.x <= viewport_size.x
		and target_screen_pos.y >= 0.0 and target_screen_pos.y <= viewport_size.y
	)
	if is_on_screen:
		if ENABLE_ON_SCREEN_SNAP or snap_when_on_screen:
			var base_pos := target_screen_pos + Vector2(0.0, ON_SCREEN_Y_OFFSET) - pivot_offset
			# Y-axis bob when marker is above element (MISSION OBJECTIVE, EXTRACTION ZONE)
			_is_above_target = true
			var bob_y := sin(Time.get_ticks_msec() * BOB_SPEED) * BOB_AMPLITUDE
			position = base_pos + Vector2(0.0, bob_y)
			rotation = PI / 2.0  # Point down toward target node
			visible = true
		else:
			_is_above_target = false
			visible = false
		return

	_is_above_target = false

	# Off-screen: clamp to edge, arrow pointing toward target
	var rect_min := Vector2(MARGIN_LEFT, MARGIN_TOP)
	var rect_max := viewport_size - Vector2(MARGIN_RIGHT, MARGIN_BOTTOM)
	var center := viewport_size / 2.0
	var to_raider := target_screen_pos - center

	if to_raider.length_squared() < 1.0:
		position = Vector2(viewport_size.x / 2.0, viewport_size.y - MARGIN_BOTTOM - ARROW_SIZE) - pivot_offset
		rotation = PI / 2.0
		visible = true
		return

	var dir := to_raider.normalized()
	var edge_pos := _intersect_ray_with_rect(center, dir, rect_min, rect_max)

	position = edge_pos - pivot_offset
	rotation = dir.angle()
	visible = true


## Intersect ray from origin in direction dir with axis-aligned rect.
## Returns the intersection point on the rect boundary.
func _intersect_ray_with_rect(origin: Vector2, dir: Vector2, rect_min: Vector2, rect_max: Vector2) -> Vector2:
	var t_min = -INF
	var t_max = INF

	# X slab
	if abs(dir.x) > 0.0001:
		var t1 = (rect_min.x - origin.x) / dir.x
		var t2 = (rect_max.x - origin.x) / dir.x
		var tx_min = min(t1, t2)
		var tx_max = max(t1, t2)
		t_min = max(t_min, tx_min)
		t_max = min(t_max, tx_max)
	else:
		if origin.x < rect_min.x or origin.x > rect_max.x:
			# No intersection
			return origin + dir * 1000.0

	# Y slab
	if abs(dir.y) > 0.0001:
		var t1 = (rect_min.y - origin.y) / dir.y
		var t2 = (rect_max.y - origin.y) / dir.y
		var ty_min = min(t1, t2)
		var ty_max = max(t1, t2)
		t_min = max(t_min, ty_min)
		t_max = min(t_max, ty_max)
	else:
		if origin.y < rect_min.y or origin.y > rect_max.y:
			return origin + dir * 1000.0

	if t_min > t_max:
		return origin + dir * 1000.0

	# Use positive t (direction from center toward raider)
	var t = t_min if t_min > 0 else (t_max if t_max > 0 else 0.0)
	return origin + dir * t


func _draw() -> void:
	# Pulse glow: alpha oscillates between min and max
	var pulse_t: float = 0.5 + 0.5 * sin(_pulse_phase)
	var glow_alpha: float = lerpf(PULSE_GLOW_MIN_ALPHA, PULSE_GLOW_MAX_ALPHA, pulse_t)

	var s = ARROW_SIZE
	var pivot = Vector2(ARROW_SIZE, ARROW_SIZE)
	var triangle = PackedVector2Array([
		pivot + Vector2(s, 0),           # Tip
		pivot + Vector2(-s * 0.7, s * 0.8),   # Base left
		pivot + Vector2(-s * 0.7, -s * 0.8)   # Base right
	])

	# Pulse glow: draw scaled-up triangle behind main arrow
	var glow_color := Color(arrow_color.r, arrow_color.g, arrow_color.b, glow_alpha)
	var glow_triangle := PackedVector2Array()
	for i in range(triangle.size()):
		var v: Vector2 = triangle[i] - pivot
		glow_triangle.append(pivot + v * GLOW_SCALE)
	draw_colored_polygon(glow_triangle, glow_color)

	# Main arrow
	draw_colored_polygon(triangle, arrow_color)
	# Subtle outline for visibility (lighter shade of arrow color)
	var outline_color := Color(arrow_color.r + 0.2, arrow_color.g + 0.2, arrow_color.b + 0.2, 0.6)
	outline_color = outline_color.clamp(Color(0, 0, 0, 0), Color(1, 1, 1, 1))
	draw_polyline(triangle, outline_color)
	draw_line(triangle[2], triangle[0], outline_color)
