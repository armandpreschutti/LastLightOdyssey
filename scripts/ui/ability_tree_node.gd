extends Control
## Individual node in the ability tree

signal unlock_requested(ab_id: String, cost: int)
signal hovered(desc: String)
signal unhovered

@onready var icon_rect = $Margin/Icon
@onready var bg_panel = $BG
@onready var name_label = $NameLabel
@onready var cost_label = $CostLabel
@onready var tooltip_area = $TooltipArea

var ability_id: String = ""
var officer_key: String = ""
var unlock_cost: int = 0
var is_unlocked: bool = false
var is_available: bool = false
var ability_desc: String = ""

func _ready():
	# Initialize StyleBox
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	bg_panel.add_theme_stylebox_override("panel", sb)
	
	# Connect mouse signals for hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Also connect from tooltip area since it covers the node
	tooltip_area.mouse_entered.connect(_on_mouse_entered)
	tooltip_area.mouse_exited.connect(_on_mouse_exited)
	# Pass clicks through so _gui_input on the root Control fires
	tooltip_area.mouse_filter = Control.MOUSE_FILTER_PASS


func setup(ab_id: String, off_key: String):
	ability_id = ab_id
	officer_key = off_key
	
	var def = GameState.ABILITY_DEFS.get(ab_id, {})
	name_label.text = def.get("name", "???")
	
	# Load generated icon
	var icon_name = "%s_%s" % [officer_key, ab_id]
	var path = "res://assets/sprites/ui/icons/abilities/%s.png" % icon_name
	if FileAccess.file_exists(path):
		icon_rect.texture = load(path)
	else:
		# Fallback to a generic icon or color
		icon_rect.texture = preload("res://icon_256.png") # Using project icon as fallback
		icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	ability_desc = def.get("desc", "")
	# tooltip_area.tooltip_text = ability_desc # No longer using tooltips


func update_state(locked_out: bool, available: bool, cost: int):
	is_unlocked = locked_out
	is_available = available
	unlock_cost = cost
	
	var accent = GameState.OFFICER_COLOR.get(officer_key, Color.WHITE)
	
	if is_unlocked:
		bg_panel.modulate = Color(1, 1, 1, 1)
		icon_rect.modulate = Color(1, 1, 1, 1)
		cost_label.text = "UNLOCKED"
		cost_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif is_available:
		bg_panel.modulate = Color(0.6, 0.6, 0.6, 0.8)
		icon_rect.modulate = Color(0.7, 0.7, 0.7, 1)
		cost_label.text = "%d DL" % cost
		cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	else:
		bg_panel.modulate = Color(0.2, 0.2, 0.2, 0.5)
		icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		cost_label.text = "%d DL" % cost if cost > 0 else "LOCKED"
		cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))

	# Apply border color based on officer color
	var sb = bg_panel.get_theme_stylebox("panel").duplicate()
	sb.border_color = accent if is_available or is_unlocked else Color(0.3, 0.3, 0.3, 0.5)
	bg_panel.add_theme_stylebox_override("panel", sb)


func _on_mouse_entered():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pivot_offset = size / 2
	hovered.emit(ability_desc)

func _on_mouse_exited():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	unhovered.emit()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_available and not is_unlocked:
			unlock_requested.emit(ability_id, unlock_cost)
