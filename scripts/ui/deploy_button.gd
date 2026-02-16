class_name DeployButton
extends Control

## Deploy Button - Appears above Scavenger/Event nodes to trigger interaction
## Features a pulsing animation to draw attention

signal pressed

@onready var button: Button = $Button
@onready var pulse_rect: ColorRect = $PulseRect
@onready var label: Label = $Button/Label

var _pulse_tween: Tween

func _ready() -> void:
    # Setup styles
    _setup_visuals()
    
    # Connect signals
    button.pressed.connect(_on_button_pressed)
    
    # Start animation
    _start_pulse()

func _setup_visuals() -> void:
    # Ensure button is styled
    button.flat = false
    
    # Set text
    label.text = "DEPLOY"
    label.add_theme_color_override("font_color", Color(0, 0, 0, 1)) # Black text
    
    # Button background (Amber/Orange)
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = Color(1.0, 0.7, 0.0, 1.0) # Amber
    style_box.corner_radius_top_left = 4
    style_box.corner_radius_top_right = 4
    style_box.corner_radius_bottom_right = 4
    style_box.corner_radius_bottom_left = 4
    button.add_theme_stylebox_override("normal", style_box)
    button.add_theme_stylebox_override("hover", style_box)
    button.add_theme_stylebox_override("pressed", style_box)
    
    # Pulse rect behind it
    pulse_rect.color = Color(1.0, 0.7, 0.0, 0.5)
    pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _start_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
        
    _pulse_tween = create_tween()
    _pulse_tween.set_loops()
    
    # Pulse scale and alpha
    _pulse_tween.tween_property(pulse_rect, "scale", Vector2(1.2, 1.4), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _pulse_tween.parallel().tween_property(pulse_rect, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    
    # Reset
    _pulse_tween.tween_property(pulse_rect, "scale", Vector2(1.0, 1.0), 0.1)
    _pulse_tween.parallel().tween_property(pulse_rect, "modulate:a", 0.8, 0.1)

func _on_button_pressed() -> void:
    pressed.emit()
