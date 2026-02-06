class_name StarMapNode
extends Control
## Individual map node visual and interaction
## Represents a single node in the star map with visual states
## Now uses sprite-based graphics for planets and stations

signal clicked(node_id: int)

enum NodeState { LOCKED, AVAILABLE, CURRENT, VISITED }

# Node references
@onready var sprite: TextureRect = $Sprite
@onready var label: Label = $Label
@onready var glow_effect: ColorRect = $GlowEffect
@onready var current_indicator: ColorRect = $CurrentIndicator
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var node_id: int = -1
var node_type: int = -1  # EventManager.NodeType
var biome_type: int = -1  # BiomeConfig.BiomeType (-1 if not scavenge)
var current_state: NodeState = NodeState.LOCKED

const NODE_SIZE = Vector2(80, 80)

# Sprite textures for different node types
const NODE_TEXTURES = {
	EventManager.NodeType.EMPTY_SPACE: preload("res://assets/sprites/navigation/planet_earth.png"),
	EventManager.NodeType.SCAVENGE_SITE: preload("res://assets/sprites/navigation/asteroid.png"),
	EventManager.NodeType.TRADING_OUTPOST: preload("res://assets/sprites/navigation/station_trading.png"),
}

# Additional planet variations for visual variety
const PLANET_VARIATIONS = [
	preload("res://assets/sprites/navigation/planet_earth.png"),
	preload("res://assets/sprites/navigation/planet_red.png"),
	preload("res://assets/sprites/navigation/planet_gas.png"),
]

# Color scheme for labels and effects
const COLOR_LOCKED = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_AVAILABLE = Color(1.0, 0.69, 0.0, 1.0)  # Amber
const COLOR_CURRENT = Color(0.2, 1.0, 0.2, 1.0)  # Green
const COLOR_VISITED = Color(0.6, 0.6, 0.6, 1.0)  # Gray
const COLOR_HOVER = Color(1.0, 0.85, 0.3, 1.0)  # Brighter amber

# Glow colors
const GLOW_AVAILABLE = Color(1.0, 0.69, 0.0, 0.3)
const GLOW_CURRENT = Color(0.2, 1.0, 0.2, 0.4)

var is_hovered: bool = false
var _pulse_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_visual()
	_setup_pulse_animation()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_state == NodeState.AVAILABLE or current_state == NodeState.CURRENT:
				print("MapNode: Clicked on node %d" % node_id)
				clicked.emit(node_id)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_on_mouse_entered()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_on_mouse_exited()


## Initialize the node with data
func initialize(p_node_id: int, p_node_type: int, p_state: NodeState = NodeState.LOCKED, p_biome_type: int = -1) -> void:
	node_id = p_node_id
	node_type = p_node_type
	biome_type = p_biome_type
	current_state = p_state
	_update_visual()


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
	if not sprite or not label:
		return
	
	# Set texture based on node type
	_update_sprite_texture()
	
	# Update label text
	_update_label_text()
	
	# Update colors and effects based on state
	match current_state:
		NodeState.LOCKED:
			label.add_theme_color_override("font_color", COLOR_LOCKED)
			sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
			if glow_effect:
				glow_effect.visible = false
			if current_indicator:
				current_indicator.visible = false
				
		NodeState.AVAILABLE:
			label.add_theme_color_override("font_color", COLOR_AVAILABLE)
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if glow_effect:
				glow_effect.visible = true
				glow_effect.color = GLOW_AVAILABLE
			if current_indicator:
				current_indicator.visible = false
				
		NodeState.CURRENT:
			label.add_theme_color_override("font_color", COLOR_CURRENT)
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if glow_effect:
				glow_effect.visible = true
				glow_effect.color = GLOW_CURRENT
			if current_indicator:
				current_indicator.visible = true
				
		NodeState.VISITED:
			label.add_theme_color_override("font_color", COLOR_VISITED)
			sprite.modulate = Color(0.6, 0.6, 0.6, 0.8)
			if glow_effect:
				glow_effect.visible = false
			if current_indicator:
				current_indicator.visible = false


## Update the sprite texture based on node type
func _update_sprite_texture() -> void:
	if not sprite:
		return
	
	# Special cases for start and end nodes
	if node_id == 0:
		# Start node - use Earth
		sprite.texture = preload("res://assets/sprites/navigation/planet_earth.png")
	elif node_id == 19:
		# End node (New Earth) - use a distinct planet
		sprite.texture = preload("res://assets/sprites/navigation/planet_gas.png")
	else:
		# Regular nodes - use type-based texture with some variation
		match node_type:
			EventManager.NodeType.EMPTY_SPACE:
				# Use planet variation based on node_id for variety
				var variation_index = node_id % PLANET_VARIATIONS.size()
				sprite.texture = PLANET_VARIATIONS[variation_index]
			EventManager.NodeType.SCAVENGE_SITE:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.SCAVENGE_SITE]
			EventManager.NodeType.TRADING_OUTPOST:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.TRADING_OUTPOST]
			_:
				sprite.texture = NODE_TEXTURES[EventManager.NodeType.EMPTY_SPACE]


## Update label text based on node type and id
func _update_label_text() -> void:
	if not label:
		return
	
	if node_id == 0:
		label.text = "EARTH"
	elif node_id == 19:
		label.text = "NEW EARTH"
	else:
		match node_type:
			EventManager.NodeType.EMPTY_SPACE:
				label.text = "WAYPOINT"
			EventManager.NodeType.SCAVENGE_SITE:
				# Show biome type for scavenge sites
				label.text = _get_biome_label()
			EventManager.NodeType.TRADING_OUTPOST:
				label.text = "OUTPOST"
			_:
				label.text = "???"


## Get the label text for scavenge sites based on biome
func _get_biome_label() -> String:
	match biome_type:
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
	return current_state == NodeState.AVAILABLE


func _on_mouse_entered() -> void:
	is_hovered = true
	if current_state == NodeState.AVAILABLE or current_state == NodeState.CURRENT:
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
