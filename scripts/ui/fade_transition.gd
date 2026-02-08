extends Control
## Fade Transition - Handles fade to black transitions between game phases
## Provides smooth visual transitions with configurable duration

signal fade_complete

@onready var fade_overlay: ColorRect = $FadeOverlay

var _is_fading: bool = false
var _current_tween: Tween = null


func _ready() -> void:
	# Start with overlay black and visible (will be faded in by calling code)
	fade_overlay.color = Color(0, 0, 0, 1.0)
	fade_overlay.visible = true


## Fade to black (fade out)
## duration: How long the fade should take (default 0.6 seconds)
func fade_out(duration: float = 0.6) -> void:
	if _is_fading:
		# Cancel any existing fade
		if _current_tween:
			_current_tween.kill()
	
	_is_fading = true
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	_current_tween.tween_callback(_on_fade_out_complete)


## Fade from black (fade in)
## duration: How long the fade should take (default 0.6 seconds)
func fade_in(duration: float = 0.6) -> void:
	if _is_fading:
		# Cancel any existing fade
		if _current_tween:
			_current_tween.kill()
	
	_is_fading = true
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 1.0)
	
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(fade_overlay, "color:a", 0.0, duration)
	_current_tween.tween_callback(_on_fade_in_complete)




## Set fade overlay to fully black (instant, no animation)
func set_black() -> void:
	if _current_tween:
		_current_tween.kill()
		_current_tween = null
	
	_is_fading = false
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 1.0)


## Set fade overlay to fully transparent (instant, no animation)
func set_transparent() -> void:
	if _current_tween:
		_current_tween.kill()
		_current_tween = null
	
	_is_fading = false
	fade_overlay.visible = false
	fade_overlay.color = Color(0, 0, 0, 0)


func _on_fade_out_complete() -> void:
	_is_fading = false
	fade_complete.emit()


func _on_fade_in_complete() -> void:
	_is_fading = false
	fade_overlay.visible = false
	fade_complete.emit()
