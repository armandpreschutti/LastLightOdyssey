extends Label
## Pickup popup - Shows scrap/fuel collection text that floats upward and fades
## Smaller and subtler than damage popups

var _velocity: Vector2 = Vector2(0, -50)  # Float upward
var _lifetime: float = 1.2
var _elapsed: float = 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 2)
	add_theme_font_size_override("font_size", 9)


func _process(delta: float) -> void:
	_elapsed += delta
	
	# Move upward
	position += _velocity * delta
	
	# Fade out
	var alpha = 1.0 - (_elapsed / _lifetime)
	modulate.a = alpha
	
	# Destroy when done
	if _elapsed >= _lifetime:
		queue_free()


## Initialize with item type and amount
func initialize(item_type: String, amount: int, world_pos: Vector2) -> void:
	position = world_pos
	
	if item_type == "scrap":
		text = "+%d SCRAP" % amount
		add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))  # Gray/silver for scrap
	elif item_type == "fuel":
		text = "+%d FUEL" % amount
		add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Yellow/orange for fuel
	elif item_type == "health_pack":
		text = "+%d HP" % amount
		add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green for health
