extends CanvasLayer
## TutorialOverlay - Displays tutorial prompts with animations and user interactions

@onready var fullscreen_dim: ColorRect = $FullscreenDim
@onready var prompt_container: Control = $PromptContainer
@onready var prompt_panel: PanelContainer = $PromptContainer/PromptPanel
@onready var title_label: Label = $PromptContainer/PromptPanel/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var step_counter: Label = $PromptContainer/PromptPanel/MarginContainer/VBoxContainer/HeaderContainer/StepCounter
@onready var content_label: Label = $PromptContainer/PromptPanel/MarginContainer/VBoxContainer/ContentLabel
@onready var got_it_button: Button = $PromptContainer/PromptPanel/MarginContainer/VBoxContainer/ButtonContainer/GotItButton
@onready var skip_button: Button = $PromptContainer/PromptPanel/MarginContainer/VBoxContainer/ButtonContainer/SkipButton
@onready var arrow_indicator: Label = $PromptContainer/ArrowIndicator
@onready var pulse_timer: Timer = $PulseTimer

var _current_step_data: Dictionary = {}
var _is_showing: bool = false
var _arrow_tween: Tween = null


func _ready() -> void:
	got_it_button.pressed.connect(_on_got_it_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	pulse_timer.timeout.connect(_on_pulse_timer_timeout)
	
	# Connect to TutorialManager
	TutorialManager.tutorial_step_triggered.connect(_on_tutorial_step_triggered)
	TutorialManager.tutorial_completed.connect(_on_tutorial_completed)
	TutorialManager.tutorial_skipped.connect(_on_tutorial_skipped)
	
	# Start hidden
	_hide_immediate()


func _on_tutorial_step_triggered(step_id: String, step_data: Dictionary) -> void:
	_current_step_data = step_data
	_show_prompt(step_data)


func _on_tutorial_completed() -> void:
	_hide_prompt()


func _on_tutorial_skipped() -> void:
	_hide_prompt()


func _show_prompt(step_data: Dictionary) -> void:
	if _is_showing:
		# Quick transition between steps
		_update_content(step_data)
		return
	
	_is_showing = true
	_update_content(step_data)
	
	# Position the panel based on step data
	_position_panel(step_data.get("position", "center"))
	
	# Make visible before animating
	fullscreen_dim.visible = true
	prompt_panel.visible = true
	
	# Fade in
	fullscreen_dim.modulate.a = 0.0
	prompt_panel.modulate.a = 0.0
	prompt_panel.scale = Vector2(0.9, 0.9)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(fullscreen_dim, "modulate:a", 1.0, 0.3)
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(prompt_panel, "scale", Vector2(1.0, 1.0), 0.4)
	
	# Start arrow animation if needed
	_update_arrow(step_data)


func _hide_prompt() -> void:
	if not _is_showing:
		return
	
	_is_showing = false
	
	# Stop arrow animation
	if _arrow_tween:
		_arrow_tween.kill()
	arrow_indicator.visible = false
	
	# Fade out
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(fullscreen_dim, "modulate:a", 0.0, 0.2)
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(prompt_panel, "scale", Vector2(0.95, 0.95), 0.2)
	
	# Actually hide the panels after animation to stop blocking clicks
	tween.chain().tween_callback(func():
		fullscreen_dim.visible = false
		prompt_panel.visible = false
	)


func _hide_immediate() -> void:
	_is_showing = false
	fullscreen_dim.modulate.a = 0.0
	prompt_panel.modulate.a = 0.0
	fullscreen_dim.visible = false
	prompt_panel.visible = false
	arrow_indicator.visible = false
	if _arrow_tween:
		_arrow_tween.kill()


func _update_content(step_data: Dictionary) -> void:
	content_label.text = step_data.get("text", "")
	
	# Update step counter
	var current_index = TutorialManager.current_step_index + 1
	var total_steps = TutorialManager.tutorial_steps.size()
	step_counter.text = "[%d/%d]" % [current_index, total_steps]
	
	# Show/hide "Got It" button based on trigger type
	var trigger = step_data.get("trigger", "acknowledged")
	if trigger == "acknowledged":
		got_it_button.visible = true
		got_it_button.text = "[ GOT IT ]"
	else:
		# Hide button for event-triggered steps, or show a "Continue" hint
		got_it_button.visible = true
		got_it_button.text = "[ CONTINUE ]"
		got_it_button.disabled = true
		# Re-enable after a short delay to prevent accidental skips
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): got_it_button.disabled = false)


func _position_panel(position: String) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = prompt_panel.size
	
	match position:
		"center":
			prompt_panel.position = (viewport_size - panel_size) / 2
		"left":
			prompt_panel.position = Vector2(50, (viewport_size.y - panel_size.y) / 2)
		"right":
			prompt_panel.position = Vector2(viewport_size.x - panel_size.x - 50, (viewport_size.y - panel_size.y) / 2)
		"top":
			prompt_panel.position = Vector2((viewport_size.x - panel_size.x) / 2, 50)
		"bottom":
			prompt_panel.position = Vector2((viewport_size.x - panel_size.x) / 2, viewport_size.y - panel_size.y - 50)
		_:
			prompt_panel.position = (viewport_size - panel_size) / 2


func _update_arrow(step_data: Dictionary) -> void:
	var target = step_data.get("target", "")
	var position = step_data.get("position", "center")
	
	# Only show arrow for certain targets
	if target.is_empty() or position == "center":
		arrow_indicator.visible = false
		return
	
	arrow_indicator.visible = true
	
	# Position arrow based on panel position
	var panel_pos = prompt_panel.position
	var panel_size = prompt_panel.size
	
	match position:
		"left":
			arrow_indicator.text = "►"
			arrow_indicator.position = Vector2(panel_pos.x + panel_size.x + 10, panel_pos.y + panel_size.y / 2 - 25)
		"right":
			arrow_indicator.text = "◄"
			arrow_indicator.position = Vector2(panel_pos.x - 50, panel_pos.y + panel_size.y / 2 - 25)
		"top":
			arrow_indicator.text = "▼"
			arrow_indicator.position = Vector2(panel_pos.x + panel_size.x / 2 - 25, panel_pos.y + panel_size.y + 10)
		"bottom":
			arrow_indicator.text = "▲"
			arrow_indicator.position = Vector2(panel_pos.x + panel_size.x / 2 - 25, panel_pos.y - 50)
	
	# Start pulsing animation
	_start_arrow_pulse()


func _start_arrow_pulse() -> void:
	if _arrow_tween:
		_arrow_tween.kill()
	
	_arrow_tween = create_tween()
	_arrow_tween.set_loops()
	_arrow_tween.tween_property(arrow_indicator, "modulate:a", 0.3, 0.4)
	_arrow_tween.tween_property(arrow_indicator, "modulate:a", 1.0, 0.4)


func _on_pulse_timer_timeout() -> void:
	# Additional pulsing effect on the panel border (visual feedback)
	if _is_showing:
		var tween = create_tween()
		tween.tween_property(prompt_panel, "modulate", Color(1.1, 1.1, 1.1, 1), 0.2)
		tween.tween_property(prompt_panel, "modulate", Color(1, 1, 1, 1), 0.2)


func _on_got_it_pressed() -> void:
	var trigger = _current_step_data.get("trigger", "acknowledged")
	
	if trigger == "acknowledged":
		# This step advances on button press
		TutorialManager.acknowledge_step()
	else:
		# For event-triggered steps, just hide the prompt temporarily
		# The TutorialManager will show the next step when the event fires
		_hide_prompt()


func _on_skip_pressed() -> void:
	TutorialManager.skip_tutorial()


## Called externally to temporarily hide the overlay (e.g., during combat)
func hide_temporarily() -> void:
	if _is_showing:
		var tween = create_tween()
		tween.tween_property(fullscreen_dim, "modulate:a", 0.0, 0.2)
		tween.parallel().tween_property(prompt_panel, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(func():
			fullscreen_dim.visible = false
			prompt_panel.visible = false
		)


## Called externally to restore the overlay after temporary hide
func restore_visibility() -> void:
	if _is_showing:
		# Make visible before animating
		fullscreen_dim.visible = true
		prompt_panel.visible = true
		var tween = create_tween()
		tween.tween_property(fullscreen_dim, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(prompt_panel, "modulate:a", 1.0, 0.2)
