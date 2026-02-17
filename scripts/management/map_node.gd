class_name StarMapNode
extends Control
## Individual map node visual and interaction
## Represents a single node in the star map with visual states
## Now uses sprite-based graphics for planets and stations

signal clicked(node_data: NodeData)

enum NodeState { LOCKED, AVAILABLE, CURRENT, VISITED }

# Node references
@onready var sprite: TextureRect = $Sprite
@onready var label: Label = $Label
@onready var glow_effect: TextureRect = $GlowEffect
@onready var current_indicator: Panel = $CurrentIndicator
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var node_data: NodeData
var current_state: NodeState = NodeState.LOCKED

const NODE_SIZE = Vector2(80, 80)

# Sprite textures for different node types
const NODE_TEXTURES = {
	EventManager.NodeType.EMPTY_SPACE: preload("res://assets/sprites/navigation/waypoint.png"),
	EventManager.NodeType.SCAVENGE_SITE: preload("res://assets/sprites/navigation/asteroid.png"),
	EventManager.NodeType.TRADING_OUTPOST: preload("res://assets/sprites/navigation/outpost.png"),
	EventManager.NodeType.WORMHOLE: preload("res://assets/sprites/navigation/wormhole.png"),
}

# Planet variations no longer used - EMPTY_SPACE nodes now use waypoint sprite
# Kept for reference if needed in the future
# const PLANET_VARIATIONS = [
# 	preload("res://assets/sprites/navigation/planet_earth.png"),
# 	preload("res://assets/sprites/navigation/planet_red.png"),
# 	preload("res://assets/sprites/navigation/planet_gas.png"),
# ]

# Color scheme for labels and effects
const COLOR_LOCKED = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_AVAILABLE = Color(1.0, 0.69, 0.0, 1.0)  # Amber
const COLOR_CURRENT = Color(0.2, 1.0, 0.2, 1.0)  # Green
const COLOR_VISITED = Color(0.6, 0.6, 0.6, 1.0)  # Gray
const COLOR_WAYPOINT_IN_RANGE = Color(1.0, 1.0, 1.0, 0.25) # Subtle white glow for waypoints
const COLOR_HOVER = Color(1.0, 0.85, 0.3, 1.0)  # Brighter amber

# Glow colors
const GLOW_AVAILABLE = Color(1.0, 1.0, 1.0, 0.4) # Default white glow for reached waypoints
const GLOW_CURRENT = Color(0.2, 1.0, 0.2, 0.0) # No glow for current node

# Difficulty colors
const COLOR_EASY = Color(0.2, 1.0, 0.2, 1.0)      # Green
const COLOR_MEDIUM = Color(1.0, 0.69, 0.0, 1.0)    # Amber
const COLOR_HARD = Color(1.0, 0.2, 0.2, 1.0)      # Red
const COLOR_IMPOSSIBLE = Color(0.6, 0.0, 1.0, 1.0) # Purple/Black (Using Purple for visibility)

# Question mark sprite for LOCKED nodes
const QUESTION_MARK_TEXTURE = preload("res://assets/sprites/navigation/question_mark.png")
const SKULL_TEXTURE = preload("res://assets/sprites/navigation/skull_icon.png")
const STORY_TEXTURE = preload("res://assets/sprites/navigation/node_target.png")
const COLOR_STORY = Color(0.95, 0.45, 1.0, 1.0)

var is_hovered: bool = false
var _pulse_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_circular_highlights()
	_update_visual()
	_setup_pulse_animation()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_clickable():
				clicked.emit(node_data)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_on_mouse_entered()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_on_mouse_exited()


## Initialize the node with data
func initialize(p_node_data: NodeData, is_current: bool, is_reachable: bool) -> void:
	node_data = p_node_data
	
	# Map internal NodeData state to visual state
	# We also need to consider if it's the CURRENT node or reachable
	
	if is_current:
		current_state = NodeState.VISITED # Visually it's "Current" but state is simply visited
		# But we use visual state enums locally
		# Let's map it
	
	_update_visual_state(is_current, is_reachable)
	_update_visual()

func _update_visual_state(is_current: bool, is_reachable: bool) -> void:
	if is_current:
		set_state(StarMapNode.NodeState.CURRENT)
	elif is_reachable:
		# Missions stay AVAILABLE (highlighted) until CLEARED.
		# Random events go to VISITED once visited.
		var is_cleared = node_data.state == NodeData.NodeState.CLEARED
		var is_visited = node_data.state == NodeData.NodeState.VISITED or node_data.is_story_node
		var is_random_event = (node_data.node_type == EventManager.NodeType.EMPTY_SPACE)
		
		if is_random_event and is_visited:
			set_state(StarMapNode.NodeState.VISITED)
		elif is_cleared:
			set_state(StarMapNode.NodeState.VISITED)
		else:
			set_state(StarMapNode.NodeState.AVAILABLE)
	elif node_data.state != NodeData.NodeState.UNVISITED:
		# Visited, Story, or Cleared nodes that are not reachable from current.
		set_state(StarMapNode.NodeState.VISITED)
	else:
		set_state(StarMapNode.NodeState.LOCKED)


## Set the node's state
func set_state(new_state: NodeState) -> void:
	current_state = new_state
	_update_visual()
	
	# Start/stop pulse animation based on state
	if new_state == NodeState.AVAILABLE:
		_start_pulse()
	else:
		_stop_pulse()


## Update visual appearance based on state and type
func _update_visual() -> void:
	if not sprite or not label or node_data == null:
		return
	
	# Set texture based on node type
	_update_sprite_texture()
	
	# Update label text
	_update_label_text()
	
	# Update colors and effects based on state
	match current_state:
		NodeState.LOCKED:
			label.add_theme_color_override("font_color", COLOR_LOCKED)
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if glow_effect:
				glow_effect.visible = false
			if current_indicator:
				current_indicator.visible = false
				
		NodeState.AVAILABLE:
			if node_data.is_story_node:
				label.add_theme_color_override("font_color", COLOR_STORY)
			else:
				label.add_theme_color_override("font_color", COLOR_AVAILABLE)
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			# Waypoints get white glow if unvisited
			if node_data.is_story_node:
				if glow_effect:
					glow_effect.visible = true
					_apply_panel_color(glow_effect, COLOR_STORY, 0.55)
			elif node_data.node_type == EventManager.NodeType.EMPTY_SPACE:
				if glow_effect:
					# Always show glow for available waypoints, even if visited
					glow_effect.visible = true
					_apply_panel_color(glow_effect, COLOR_WAYPOINT_IN_RANGE)
			else:
				# Temporarily hide, difficulty visuals will show it if needed
				if glow_effect:
					glow_effect.visible = false
			
			if current_indicator:
				current_indicator.visible = false
				
		NodeState.CURRENT:
			if node_data.is_story_node:
				label.add_theme_color_override("font_color", COLOR_STORY)
				if glow_effect:
					glow_effect.visible = true
					_apply_panel_color(glow_effect, COLOR_STORY, 0.55)
			else:
				label.add_theme_color_override("font_color", COLOR_CURRENT)
				if glow_effect:
					glow_effect.visible = false
			
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if current_indicator:
				current_indicator.visible = false
				
		NodeState.VISITED:
			var is_scavenge = node_data.node_type == EventManager.NodeType.SCAVENGE_SITE
			if node_data.is_story_node:
				label.add_theme_color_override("font_color", COLOR_STORY)
				if glow_effect and node_data.state != NodeData.NodeState.CLEARED:
					glow_effect.visible = true
					_apply_panel_color(glow_effect, COLOR_STORY, 0.55)
			elif is_scavenge and node_data.state != NodeData.NodeState.CLEARED:
				# Show difficulty color and glow for visited but not cleared scavenger missions
				_update_visited_mission_color()
				if glow_effect:
					glow_effect.visible = true
					# Use same alpha/logic as _update_difficulty_visuals
					var grade_color = _get_grade_color()
					_apply_panel_color(glow_effect, grade_color, 0.35)
			else:
				label.add_theme_color_override("font_color", COLOR_VISITED)
				if glow_effect:
					glow_effect.visible = false
			
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if current_indicator:
				current_indicator.visible = false
	
	# Update difficulty highlights and skulls if it's a scavenge site and revealed
	_update_difficulty_visuals()
	
	# Update cleared marker if it's a scavenge site
	_update_cleared_marker()
	
	# Update event results (penalty/mitigation)
	_update_event_result_visuals()

func _update_difficulty_visuals() -> void:
	if node_data and node_data.is_story_node:
		if has_node("SkullContainer"):
			$SkullContainer.visible = false
		return

	if not node_data or node_data.node_type != EventManager.NodeType.SCAVENGE_SITE:
		if has_node("SkullContainer"):
			$SkullContainer.visible = false
		return
		
	# Revealed logic: user said "yes it should be revealed"
	# We also check if the node is not LOCKED
	var revealed = node_data.difficulty_revealed and current_state != NodeState.LOCKED
	
	if not revealed:
		if has_node("SkullContainer"):
			$SkullContainer.visible = false
		return
		
	# Set highlights
	var grade = node_data.difficulty_grade
	var grade_color = COLOR_EASY
	match grade:
		NodeData.DifficultyGrade.EASY:
			grade_color = COLOR_EASY
		NodeData.DifficultyGrade.MEDIUM:
			grade_color = COLOR_MEDIUM
		NodeData.DifficultyGrade.HARD:
			grade_color = COLOR_HARD
		NodeData.DifficultyGrade.IMPOSSIBLE:
			grade_color = COLOR_IMPOSSIBLE
			
	# Apply highlight to label or glow if available and unvisited
	if current_state != NodeState.VISITED:
		label.add_theme_color_override("font_color", grade_color)
	
	# Always show glow for active (Available, Current, or jumpable Visited) missions, as long as not cleared
	var is_active = (current_state == NodeState.AVAILABLE or current_state == NodeState.CURRENT or current_state == NodeState.VISITED)
	if glow_effect and is_active and node_data.state != NodeData.NodeState.CLEARED:
		glow_effect.visible = true 
		_apply_panel_color(glow_effect, grade_color, 0.35)
	
	# Update skulls
	_update_skulls(grade)

func _update_skulls(grade: int) -> void:
	# Grade is 0-3 (EASY-IMPOSSIBLE), so count is grade + 1
	var skull_count = grade + 1
	
	# Dynamic check/creation of SkullContainer if it doesn't exist in the scene tree yet
	# (Since I can't easily edit the .tscn file, I'll handle it programmatically)
	var sc = get_node_or_null("SkullContainer")
	if not sc:
		sc = HBoxContainer.new()
		sc.name = "SkullContainer"
		add_child(sc)
		sc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		sc.position.y += 20 # Offset below label
		sc.alignment = BoxContainer.ALIGNMENT_CENTER
	
	sc.visible = true
	
	# Clear existing
	for child in sc.get_children():
		child.queue_free()
		
	# Add new skulls
	for i in range(skull_count):
		var tr = TextureRect.new()
		tr.texture = SKULL_TEXTURE
		tr.custom_minimum_size = Vector2(16, 16)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sc.add_child(tr)


func _update_cleared_marker() -> void:
	# Only relevant for Scavenge Sites
	if not node_data or node_data.node_type != EventManager.NodeType.SCAVENGE_SITE:
		if has_node("ClearedLabel"):
			$ClearedLabel.visible = false
		return
		
	# Check if cleared
	var is_cleared = node_data.state == NodeData.NodeState.CLEARED
	
	if not is_cleared:
		if has_node("ClearedLabel"):
			$ClearedLabel.visible = false
		return
		
	# Create label if needed
	var cl = get_node_or_null("ClearedLabel")
	if not cl:
		cl = Label.new()
		cl.name = "ClearedLabel"
		add_child(cl)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0)) # Grey
		
	# Reset position relative to top
	cl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	
	# Move up above the node
	cl.position.y -= 25 # Move up by 25 pixels
	
	cl.text = "[ CLEARED ]"
	cl.visible = true


func _update_event_result_visuals() -> void:
	if not node_data:
		return
		
	# Penalty Label - show for UNVISITED (forecast) or CURRENT (result)
	var pl = get_node_or_null("PenaltyLabel")
	var penalty_text = node_data.event_penalty_text
	
	# Forecast for penalty if not yet resolved
	if penalty_text == "" and current_state == NodeState.AVAILABLE and node_data.pending_event_id >= 0:
		var event = EventManager.random_events[node_data.pending_event_id]
		var effects = []
		
		var integrity_change = event.get("integrity_change_pct", 0)
		if integrity_change != 0:
			var prefix = "+" if integrity_change > 0 else ""
			effects.append(prefix + str(integrity_change) + "% HULL")
			
		var cash_change = event.get("cash_change", 0)
		if cash_change != 0:
			var prefix = "+" if cash_change > 0 else ""
			effects.append(prefix + str(cash_change) + " CASH")
			
		var fuel_change = event.get("fuel_change", 0)
		if fuel_change != 0:
			var prefix = "+" if fuel_change > 0 else ""
			effects.append(prefix + str(fuel_change) + " FUEL")
			
		var scrap_change = event.get("scrap_change", 0)
		if scrap_change != 0:
			var prefix = "+" if scrap_change > 0 else ""
			effects.append(prefix + str(scrap_change) + " SCRAP")
		
		if not effects.is_empty():
			penalty_text = ", ".join(effects)

	# Determine if we should show the label
	# We show it if it's UNVISITED (forecast) OR if it's the CURRENT node (result)
	var is_current = (current_state == NodeState.CURRENT)
	var should_show = (node_data.state == NodeData.NodeState.UNVISITED) or is_current
	
	if penalty_text != "" and should_show:
		if not pl:
			pl = Label.new()
			pl.name = "PenaltyLabel"
			add_child(pl)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.add_theme_font_size_override("font_size", 16) # Much bigger
		
		# Color coding: Green for prizes, Red for penalties, Amber for mixed
		var has_plus = "+" in penalty_text
		var has_minus = "-" in penalty_text
		
		if has_plus and not has_minus:
			pl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0)) # Green
		elif has_minus and not has_plus:
			pl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0)) # Red
		else:
			pl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0)) # Amber/Yellow for mixed
		
		pl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		pl.position.y = -38 # Absolute offset from top
		pl.text = penalty_text
		pl.visible = true
	elif pl:
		pl.visible = false


## Update the sprite texture based on node type
func _update_sprite_texture() -> void:
	if not sprite or node_data == null:
		return
	
	# Check if node has been visited, is current, or has an amber line
	# Check if node has been visited/revealed
	# In Voyage 2.0, non-visited nodes might be hidden or shown as ?
	# But if we can see them (in view radius), we generally know what they are?
	# Let's say: If adjacent (reachable) or visited, we see type. Otherwise ?
	
	# For now, simplistic approach: If we are visualizing it, we see it.
	# Or follow the logic:
	var show_details = current_state != NodeState.LOCKED or node_data.is_story_node
	
	if not show_details:
		sprite.texture = QUESTION_MARK_TEXTURE
		return
	
	# Special cases for start and end nodes (always show actual type)
	# Special cases for start and end nodes
	if node_data.position == Vector2.ZERO:
		# Start node - use Earth
		sprite.texture = preload("res://assets/sprites/navigation/planet_red.png")
	elif node_data.is_new_earth:
		# End node (New Earth)
		sprite.texture = preload("res://assets/sprites/navigation/planet_earth.png")
	elif node_data.is_story_node:
		sprite.texture = STORY_TEXTURE
	else:
		# Regular nodes - use type-based texture
		match node_data.node_type:
			EventManager.NodeType.EMPTY_SPACE:
				# Use waypoint sprite
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.EMPTY_SPACE]
			EventManager.NodeType.SCAVENGE_SITE:
				# Use biome-based sprite
				match node_data.biome_type:
					BiomeConfig.BiomeType.ASTEROID:
						sprite.texture = preload("res://assets/sprites/navigation/asteroid.png")
					BiomeConfig.BiomeType.STATION:
						sprite.texture = preload("res://assets/sprites/navigation/station_trading.png")
					BiomeConfig.BiomeType.PLANET:
						sprite.texture = preload("res://assets/sprites/navigation/planet_gas.png")
					_:
						# Default to asteroid if biome type is unknown
						sprite.texture = preload("res://assets/sprites/navigation/asteroid.png")
			EventManager.NodeType.TRADING_OUTPOST:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.TRADING_OUTPOST]
			EventManager.NodeType.WORMHOLE:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.WORMHOLE]
			_:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.EMPTY_SPACE]


## Update label text based on node type and id
func _update_label_text() -> void:
	if not label or node_data == null:
		return
	
	# Check if node has been visited, is current, or has an amber line
	# Check if node has been visited, is current, or has an amber line
	var show_details = current_state != NodeState.LOCKED or node_data.is_story_node
	
	# Show no text for unvisited nodes without amber lines
	# Reveal if visited OR is current OR has amber line to it
	if not show_details:
		label.text = ""
		return
	
	# Special cases for start and end nodes (always show actual type)
	if node_data.position == Vector2.ZERO:
		label.text = "EARTH"
	elif node_data.is_new_earth:
		label.text = "NEW EARTH"
	elif node_data.is_story_node:
		label.text = "STORY SIGNAL"
	else:
		match node_data.node_type:
			EventManager.NodeType.EMPTY_SPACE:
				label.text = "WAYPOINT"
			EventManager.NodeType.SCAVENGE_SITE:
				# Show biome type for scavenge sites
				label.text = _get_biome_label()
			EventManager.NodeType.TRADING_OUTPOST:
				label.text = "OUTPOST"
			EventManager.NodeType.WORMHOLE:
				label.text = "WORMHOLE"
			_:
				label.text = "???"


## Get the label text for scavenge sites based on biome
func _get_biome_label() -> String:
	match node_data.biome_type:
		BiomeConfig.BiomeType.STATION:
			return "STATION"
		BiomeConfig.BiomeType.ASTEROID:
			return "ASTEROID"
		BiomeConfig.BiomeType.PLANET:
			return "PLANET"
		_:
			return "SALVAGE"


## Setup pulse animation for available nodes
func _setup_pulse_animation() -> void:
	pass  # Animation handled by tween


## Start the pulse effect for available nodes
func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	
	# Pulse the glow effect
	if glow_effect:
		_pulse_tween.tween_property(glow_effect, "modulate:a", 0.5, 0.8).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(glow_effect, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)


## Stop the pulse effect
func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	
	if glow_effect:
		glow_effect.modulate.a = 1.0


## Check if node is clickable
func is_clickable() -> bool:
	return current_state == NodeState.AVAILABLE or current_state == NodeState.VISITED


## Check if this is the New Earth node
func _is_new_earth_node() -> bool:
	return node_data.is_new_earth


## Check if this node has an amber line connecting to it (is reachable from current node)






func _setup_circular_highlights() -> void:
	# Glow effect (TextureRect) no longer needs procedural stylebox
	
	# Current indicator style
	var indicator_style = StyleBoxFlat.new()
	indicator_style.set_corner_radius_all(100) # Circle
	indicator_style.bg_color = COLOR_CURRENT
	current_indicator.add_theme_stylebox_override("panel", indicator_style)

func _apply_panel_color(control: Control, color: Color, alpha: float = -1.0) -> void:
	if control is TextureRect:
		control.modulate = color
		if alpha >= 0.0:
			control.modulate.a = alpha
	elif control is Panel:
		var style = control.get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = color
			if alpha >= 0.0:
				style.bg_color.a = alpha
			control.add_theme_stylebox_override("panel", style)

func _on_mouse_entered() -> void:
	is_hovered = true
	if current_state == NodeState.AVAILABLE or current_state == NodeState.VISITED:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		# Scale up slightly on hover
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT)
		
		# Brighten the sprite
		if sprite:
			sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)


func _on_mouse_exited() -> void:
	is_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	# Scale back to normal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	
	# Restore visual state
	_update_visual()


func _update_visited_mission_color() -> void:
	if not node_data: return
	var grade_color = COLOR_EASY
	match node_data.difficulty_grade:
		NodeData.DifficultyGrade.EASY: grade_color = COLOR_EASY
		NodeData.DifficultyGrade.MEDIUM: grade_color = COLOR_MEDIUM
		NodeData.DifficultyGrade.HARD: grade_color = COLOR_HARD
		NodeData.DifficultyGrade.IMPOSSIBLE: grade_color = COLOR_IMPOSSIBLE
	label.add_theme_color_override("font_color", grade_color)


func _get_grade_color() -> Color:
	match node_data.difficulty_grade:
		NodeData.DifficultyGrade.EASY: return COLOR_EASY
		NodeData.DifficultyGrade.MEDIUM: return COLOR_MEDIUM
		NodeData.DifficultyGrade.HARD: return COLOR_HARD
		NodeData.DifficultyGrade.IMPOSSIBLE: return COLOR_IMPOSSIBLE
	return COLOR_EASY
