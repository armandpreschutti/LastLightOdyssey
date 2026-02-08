extends Label
## Damage number popup
## Shows damage/miss text that floats upward and fades

var _velocity: Vector2 = Vector2(0, -50)  # Float upward
var _lifetime: float = 1.0
var _elapsed: float = 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 2)
	add_theme_font_size_override("font_size", 24)


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


## Initialize with damage amount, miss text, or heal amount
func initialize(damage: int, is_hit: bool, world_pos: Vector2, is_heal: bool = false, is_flank: bool = false, is_critical: bool = false) -> void:
	position = world_pos
	
	if is_heal:
		text = "+%d" % damage
		add_theme_color_override("font_color", Color(0.2, 1, 0.2))  # Green for healing
	elif is_hit:
		if is_critical:
			text = "-%d CRIT!" % damage  # CRIT! text for critical hits
			add_theme_color_override("font_color", Color(1, 0.8, 0.0))  # Gold color for critical hits
			add_theme_font_size_override("font_size", 32)  # Larger font for critical hits
			_velocity = Vector2(0, -70)  # Faster upward velocity for emphasis
		elif is_flank:
			text = "-%d!" % damage  # Exclamation mark for flanking hits
			add_theme_color_override("font_color", Color(1, 0.5, 0.1))  # Orange for flanking damage
			add_theme_font_size_override("font_size", 28)  # Larger text for flanking
			_velocity = Vector2(0, -60)  # Float up faster for emphasis
		else:
			text = "-%d" % damage
			add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # Red for damage
	else:
		text = "MISS"
		add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Gray for miss
