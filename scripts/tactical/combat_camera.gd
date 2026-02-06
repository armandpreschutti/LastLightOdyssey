extends Camera2D
## Combat Camera - Handles cinematic camera movements during combat
## Focuses on units during attack sequences, then returns to tactical overview
## Supports mouse scroll wheel zoom in tactical mode

signal camera_transition_complete

@export var zoom_tactical: Vector2 = Vector2(1.0, 1.0)  # Default tactical view
@export var transition_speed: float = 3.0  # Camera movement speed

## Scroll wheel zoom settings
@export var zoom_min: Vector2 = Vector2(0.4, 0.4)  # Maximum zoom out (wider view)
@export var zoom_max: Vector2 = Vector2(3.0, 3.0)  # Maximum zoom in (closer)
@export var zoom_step: float = 0.2  # Zoom increment per scroll (doubled for more responsive zooming)
@export var zoom_smooth_speed: float = 12.0  # How fast zoom transitions

## Pan settings (middle mouse button)
@export var pan_speed: float = 1.0  # Pan sensitivity multiplier

var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = Vector2(1.0, 1.0)
var _transitioning: bool = false
var _combat_transition: bool = false  # True during combat zoom (blocks user zoom input)
var _default_position: Vector2 = Vector2.ZERO
var _manual_zoom: bool = false  # True when user is manually zooming
var _panning: bool = false  # True when middle mouse button is held

# Pre-combat state (to restore after combat animations)
var _pre_combat_position: Vector2 = Vector2.ZERO
var _pre_combat_zoom: Vector2 = Vector2(1.0, 1.0)


func _ready() -> void:
	enabled = true
	zoom = zoom_tactical
	_default_position = position
	_target_position = position
	_target_zoom = zoom
	_pre_combat_position = position
	_pre_combat_zoom = zoom


func _process(delta: float) -> void:
	if _transitioning:
		# Smoothly move to target position
		position = position.lerp(_target_position, transition_speed * delta)
		zoom = zoom.lerp(_target_zoom, transition_speed * delta)
		
		# Check if we've reached the target
		if position.distance_to(_target_position) < 1.0 and zoom.distance_to(_target_zoom) < 0.01:
			position = _target_position
			zoom = _target_zoom
			_transitioning = false
			_combat_transition = false
			camera_transition_complete.emit()
	elif _manual_zoom:
		# Smooth zoom transition for manual scroll wheel zoom
		zoom = zoom.lerp(_target_zoom, zoom_smooth_speed * delta)
		
		if zoom.distance_to(_target_zoom) < 0.01:
			zoom = _target_zoom
			_manual_zoom = false


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse scroll wheel for zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_out()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			# Start/stop panning with middle mouse button
			_panning = event.pressed
			if _panning:
				get_viewport().set_input_as_handled()
	
	# Handle mouse motion for panning
	if event is InputEventMouseMotion and _panning:
		if not _transitioning:  # Don't pan during combat transitions
			# Move camera opposite to mouse movement (drag to pan)
			# Divide by zoom to keep pan speed consistent at different zoom levels
			var pan_delta = -event.relative * pan_speed / zoom.x
			position += pan_delta
			_target_position = position
			get_viewport().set_input_as_handled()


## Zoom in (scroll wheel up)
func _zoom_in() -> void:
	# Don't override combat transitions (but allow during position-only pans)
	if _combat_transition:
		return
	
	_target_zoom = (_target_zoom + Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)
	_manual_zoom = true


## Zoom out (scroll wheel down)
func _zoom_out() -> void:
	# Don't override combat transitions (but allow during position-only pans)
	if _combat_transition:
		return
	
	_target_zoom = (_target_zoom - Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)
	_manual_zoom = true


## Focus camera on a specific world position with combat zoom
func focus_on_position(world_pos: Vector2) -> void:
	# Save current state to restore after combat
	_pre_combat_position = position
	_pre_combat_zoom = zoom
	
	_target_position = world_pos
	_target_zoom = zoom_max  # Zoom to maximum for cinematic combat
	_transitioning = true
	_combat_transition = true  # Lock user zoom during combat
	_manual_zoom = false
	_panning = false


## Focus on midpoint between two positions (for showing both shooter and target)
func focus_on_action(shooter_pos: Vector2, target_pos: Vector2) -> void:
	# Save current state to restore after combat
	_pre_combat_position = position
	_pre_combat_zoom = zoom
	
	# Calculate midpoint in world space
	var midpoint = (shooter_pos + target_pos) / 2.0
	
	# Account for MapContainer offset (300, 200) to center properly
	# The camera needs to be positioned relative to the scene root
	var map_offset = Vector2(300, 200)
	_target_position = midpoint + map_offset
	_target_zoom = zoom_max  # Zoom to maximum for cinematic combat
	_transitioning = true
	_combat_transition = true  # Lock user zoom during combat
	_manual_zoom = false
	_panning = false


## Return camera to tactical overview (restores pre-combat zoom/position)
func return_to_tactical() -> void:
	_target_position = _pre_combat_position
	_target_zoom = _pre_combat_zoom
	_transitioning = true
	_combat_transition = true  # Lock user zoom during combat return
	_manual_zoom = false
	_panning = false


## Set the default tactical position (call this when map is initialized)
func set_tactical_position(pos: Vector2) -> void:
	_default_position = pos
	if not _transitioning:
		position = pos
		_pre_combat_position = pos
		_pre_combat_zoom = zoom


## Immediately snap to a position without transition
func snap_to_position(world_pos: Vector2, use_combat_zoom: bool = false) -> void:
	position = world_pos
	_target_position = world_pos
	zoom = zoom_max if use_combat_zoom else zoom_tactical
	_target_zoom = zoom
	_transitioning = false
	_combat_transition = false
	_manual_zoom = false
	_panning = false
	_pre_combat_position = world_pos
	_pre_combat_zoom = zoom


## Center camera on a world position without affecting zoom (for turn transitions)
func center_on_unit(world_pos: Vector2, map_offset: Vector2 = Vector2(300, 200)) -> void:
	# Account for MapContainer offset to center properly
	_target_position = world_pos + map_offset
	_pre_combat_position = _target_position
	_transitioning = true
	_manual_zoom = false
	_panning = false
	# Keep current zoom - don't modify _target_zoom