extends Node
## TutorialManager - Singleton to manage the guided tutorial system
## Tracks tutorial progress and emits signals when tutorial prompts should display

signal tutorial_step_triggered(step_id: String, step_data: Dictionary)
signal tutorial_completed
signal tutorial_skipped

const CONFIG_PATH: String = "user://settings.cfg"

# Tutorial steps definition
# Each step has: id, text, target (UI element to highlight), trigger (event that advances),
# delay_after_trigger (seconds), wait_for_context (context type to wait for), blocking (always true)
var tutorial_steps: Array[Dictionary] = [
	{
		"id": "star_map_intro",
		"text": "Welcome, Commander. Your mission: guide humanity's last survivors to New Earth.\n\nClick on AMBER nodes to plot your course. Each jump costs FUEL.",
		"target": "star_map",
		"trigger": "node_clicked",
		"position": "center",
		"delay_after_trigger": 1.0,
		"wait_for_context": "voyage_intro_dismissed",
		"blocking": true
	},
	{
		"id": "resources_intro",
		"text": "Monitor your resources carefully:\n- COLONISTS: Your score and humanity's future\n- FUEL: Required for each jump\n- HULL: Ship integrity - reaches 0 and you're lost\n- SCRAP: Trade currency",
		"target": "management_hud",
		"trigger": "acknowledged",
		"position": "right",
		"delay_after_trigger": 1.0,
		"wait_for_context": "",
		"blocking": true
	},
	{
		"id": "event_intro",
		"text": "Random events will test your crew. If you have the right SPECIALIST alive, you can MITIGATE the damage.\n\nMake your choice.",
		"target": "event_dialog",
		"trigger": "event_closed",
		"position": "left",
		"delay_after_trigger": 0.8,
		"wait_for_context": "event_dialog_visible",
		"blocking": true
	},
	{
		"id": "scavenge_intro",
		"text": "SCAVENGE SITES let you send an away team to gather resources.\n\nSelect up to 3 officers for the mission. Choose wisely - death is PERMANENT.",
		"target": "team_select",
		"trigger": "team_selected",
		"position": "center",
		"delay_after_trigger": 1.0,
		"wait_for_context": "team_select_visible",
		"blocking": true
	},
	{
		"id": "tactical_movement",
		"text": "TACTICAL MODE: Each officer has 2 ACTION POINTS per turn.\n\nClick on blue-highlighted tiles to MOVE (costs 1 AP).",
		"target": "tactical_map",
		"trigger": "unit_moved",
		"position": "right",
		"delay_after_trigger": 1.0,
		"wait_for_context": "tactical_first_turn",
		"blocking": true
	},
	{
		"id": "tactical_combat",
		"text": "Click on enemies highlighted in RED to ATTACK (costs 1 AP).\n\nCover reduces hit chance. Use it wisely!",
		"target": "tactical_map",
		"trigger": "unit_attacked",
		"position": "right",
		"delay_after_trigger": 1.2,
		"wait_for_context": "",
		"blocking": true
	},
	{
		"id": "tactical_abilities",
		"text": "Each specialist has a UNIQUE ABILITY:\n- SCOUT: Overwatch (reaction shot)\n- TECH: Breach (destroy cover)\n- MEDIC: Patch (heal ally)",
		"target": "ability_container",
		"trigger": "acknowledged",
		"position": "left",
		"delay_after_trigger": 1.0,
		"wait_for_context": "",
		"blocking": true
	},
	{
		"id": "cryo_stability",
		"text": "WARNING: CRYO-STABILITY decreases each turn!\n\nAt 0%, you lose COLONISTS every turn. Extract before it's too late!",
		"target": "stability_bar",
		"trigger": "acknowledged",
		"position": "left",
		"delay_after_trigger": 1.0,
		"wait_for_context": "",
		"blocking": true
	},
	{
		"id": "extraction",
		"text": "Move ALL surviving officers to the GREEN extraction zone to complete the mission.\n\nGood luck, Commander. Humanity is counting on you.",
		"target": "extraction_zone",
		"trigger": "mission_complete",
		"position": "center",
		"delay_after_trigger": 1.0,
		"wait_for_context": "",
		"blocking": true
	}
]

# Current tutorial state
var is_tutorial_active: bool = false
var current_step_index: int = 0
var tutorial_completed_flag: bool = false
var _pending_triggers: Array[String] = []

# Dynamic step tracking
var _shown_step_ids: Array[String] = []  # Track which step IDs have been shown
var _step_order_map: Dictionary = {}  # Map step IDs to their display order (1-9)
var _next_display_number: int = 3  # Next available display number (3-9, since 1-2 are fixed)

# Queue system for delayed/conditional step triggering
var _queued_steps: Array[Dictionary] = []  # Array of {step_index, delay, context_check, timer}
var _delay_timer: Timer = null
var _main_node: Node = null  # Reference to Main node for UI blocking checks


func _ready() -> void:
	_load_tutorial_state()
	# Create delay timer
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.timeout.connect(_on_delay_timer_timeout)
	add_child(_delay_timer)
	
	# Initialize fixed step display numbers
	_step_order_map["star_map_intro"] = 1
	_step_order_map["resources_intro"] = 2


func _load_tutorial_state() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		tutorial_completed_flag = config.get_value("tutorial", "completed", false)


func _save_tutorial_state() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("tutorial", "completed", tutorial_completed_flag)
	config.save(CONFIG_PATH)


## Start the tutorial (called when new game begins)
## Does NOT immediately trigger first step - use queue_step() or trigger_first_step() instead
func start_tutorial() -> void:
	if tutorial_completed_flag:
		return
	
	is_tutorial_active = true
	current_step_index = 0
	# Don't trigger immediately - wait for voyage intro to complete
	# First step will be queued from main.gd after voyage intro dismisses


## Reset tutorial (called from settings menu)
func reset_tutorial() -> void:
	tutorial_completed_flag = false
	current_step_index = 0
	is_tutorial_active = false
	_shown_step_ids.clear()
	_step_order_map.clear()
	_next_display_number = 3
	_queued_steps.clear()
	if _delay_timer:
		_delay_timer.stop()
	# Re-initialize fixed step display numbers
	_step_order_map["star_map_intro"] = 1
	_step_order_map["resources_intro"] = 2
	_save_tutorial_state()


## Skip the entire tutorial
func skip_tutorial() -> void:
	if not is_tutorial_active:
		return
	
	is_tutorial_active = false
	tutorial_completed_flag = true
	_queued_steps.clear()
	if _delay_timer:
		_delay_timer.stop()
	_save_tutorial_state()
	tutorial_skipped.emit()


## Called when the player acknowledges a tutorial prompt (clicks "Got it")
func acknowledge_step() -> void:
	if not is_tutorial_active:
		return
	
	var current_step = get_current_step()
	if current_step.is_empty():
		return
	
	if current_step.get("trigger", "") == "acknowledged":
		advance_step()
		# Check if tutorial should complete after advancing
		_check_tutorial_completion()


## Called by game systems when specific events occur
func notify_trigger(trigger_name: String) -> void:
	if not is_tutorial_active:
		return
	
	# Check if there's a step waiting for this trigger
	if should_show_step_by_trigger(trigger_name):
		# Find the step that matches this trigger
		for i in range(tutorial_steps.size()):
			var step = tutorial_steps[i]
			var step_id = step.get("id", "")
			var step_trigger = step.get("trigger", "")
			
			# Skip if already shown
			if step_id in _shown_step_ids:
				continue
			
			# Check if this trigger matches
			if step_trigger == trigger_name:
				# Check prerequisites
				if _check_step_prerequisites(step_id):
					trigger_step_by_id(step_id)
					return
	
	# Also check current step (for linear progression of steps 1-2)
	var current_step = get_current_step()
	if not current_step.is_empty():
		if current_step.get("trigger", "") == trigger_name:
			advance_step()


## Advance to the next tutorial step
func advance_step() -> void:
	if not is_tutorial_active:
		return
	
	var current_step = get_current_step()
	if current_step.is_empty():
		return
	
	var current_step_id = current_step.get("id", "")
	
	# Mark current step as shown
	mark_step_shown(current_step_id)
	
	# For steps 1-2 (fixed), use linear progression
	if current_step_id in ["star_map_intro", "resources_intro"]:
		var previous_step_index = current_step_index
		current_step_index += 1
		
		if current_step_index >= tutorial_steps.size():
			_check_tutorial_completion()
			return
		
		# Special case: transitioning from step 0 (1/9) to step 1 (2/9)
		if previous_step_index == 0 and current_step_index == 1:
			_trigger_current_step()
		else:
			var next_step = get_current_step()
			if next_step.get("trigger", "") == "acknowledged" and next_step.get("wait_for_context", "").is_empty():
				var delay = next_step.get("delay_after_trigger", 1.0)
				if delay > 0:
					queue_step(current_step_index, delay)
				else:
					_trigger_current_step()
			else:
				_check_and_show_next_step()
	else:
		# For steps 3-9, check if tutorial is complete
		_check_tutorial_completion()


## Get the current tutorial step data
func get_current_step() -> Dictionary:
	if current_step_index < 0 or current_step_index >= tutorial_steps.size():
		return {}
	return tutorial_steps[current_step_index]


## Get a specific step by ID
func get_step_by_id(step_id: String) -> Dictionary:
	for step in tutorial_steps:
		if step.get("id", "") == step_id:
			return step
	return {}


## Check if a specific step should be shown (based on current progress)
func should_show_step(step_id: String) -> bool:
	if not is_tutorial_active:
		return false
	
	var current_step = get_current_step()
	return current_step.get("id", "") == step_id


## Check if tutorial is currently active
func is_active() -> bool:
	return is_tutorial_active


## Check if tutorial has been completed
func is_completed() -> bool:
	return tutorial_completed_flag


func _trigger_current_step() -> void:
	var step = get_current_step()
	if step.is_empty():
		return
	
	var step_id = step.get("id", "")
	
	# Mark step as shown if not already
	mark_step_shown(step_id)
	
	# Clear any queued steps for this index to avoid conflicts
	for i in range(_queued_steps.size() - 1, -1, -1):
		if _queued_steps[i].get("step_index", -1) == current_step_index:
			_queued_steps.remove_at(i)
	
	# Stop delay timer if running
	if _delay_timer and _delay_timer.time_left > 0:
		_delay_timer.stop()
	
	tutorial_step_triggered.emit(step_id, step)


func _complete_tutorial() -> void:
	is_tutorial_active = false
	tutorial_completed_flag = true
	_save_tutorial_state()
	tutorial_completed.emit()


## Check if all tutorial steps have been shown and complete tutorial if so
func _check_tutorial_completion() -> void:
	# Check if all 9 steps have been shown
	if _shown_step_ids.size() >= 9:
		_complete_tutorial()


## Utility: Check if we're at a specific step
func is_at_step(step_id: String) -> bool:
	var current = get_current_step()
	return current.get("id", "") == step_id


## Mark a step as shown and assign it a display number
func mark_step_shown(step_id: String) -> void:
	if step_id in _shown_step_ids:
		return  # Already shown
	
	_shown_step_ids.append(step_id)
	
	# Assign display number if not already assigned
	if not step_id in _step_order_map:
		# Steps 1-2 are fixed, 3-4 are dynamic, 5-9 are fixed after scavenger
		if step_id == "star_map_intro":
			_step_order_map[step_id] = 1
		elif step_id == "resources_intro":
			_step_order_map[step_id] = 2
		elif step_id in ["event_intro", "scavenge_intro"]:
			# Dynamic steps 3-4: assign next available number
			_step_order_map[step_id] = _next_display_number
			_next_display_number += 1
		else:
			# Steps 5-9: assign in order
			_step_order_map[step_id] = _next_display_number
			_next_display_number += 1


## Get the display number for a step (1-9)
func get_step_display_number(step_id: String) -> int:
	if step_id in _step_order_map:
		return _step_order_map[step_id]
	return 0  # Not assigned yet


## Check if a step should be shown based on trigger
func should_show_step_by_trigger(trigger_name: String) -> bool:
	if not is_tutorial_active:
		return false
	
	# Check if there's a step waiting for this trigger that hasn't been shown
	for step in tutorial_steps:
		var step_id = step.get("id", "")
		var step_trigger = step.get("trigger", "")
		
		# Skip if already shown
		if step_id in _shown_step_ids:
			continue
		
		# Check if this trigger matches and step should be shown
		if step_trigger == trigger_name:
			# Special handling for steps 3-4 (event_intro, scavenge_intro)
			if step_id in ["event_intro", "scavenge_intro"]:
				# These can show at any time after resources_intro
				if "resources_intro" in _shown_step_ids:
					return true
			else:
				# Other steps need their prerequisites
				return _check_step_prerequisites(step_id)
	
	return false


## Check if step prerequisites are met
func _check_step_prerequisites(step_id: String) -> bool:
	match step_id:
		"tactical_movement", "tactical_combat", "tactical_abilities", "cryo_stability", "extraction":
			# Tactical steps require scavenge_intro to be shown
			return "scavenge_intro" in _shown_step_ids
		_:
			return true


## Trigger a specific step by ID
func trigger_step_by_id(step_id: String) -> void:
	if not is_tutorial_active:
		return
	
	# Check if step already shown
	if step_id in _shown_step_ids:
		return
	
	# Find the step
	for i in range(tutorial_steps.size()):
		if tutorial_steps[i].get("id", "") == step_id:
			# Mark as shown and assign display number
			mark_step_shown(step_id)
			
			# Set current step index
			current_step_index = i
			
			# Trigger the step
			_trigger_current_step()
			return


## Force show a specific step (for debugging or special cases)
func force_show_step(step_id: String) -> void:
	for i in range(tutorial_steps.size()):
		if tutorial_steps[i].get("id", "") == step_id:
			current_step_index = i
			is_tutorial_active = true
			_trigger_current_step()
			return


## Queue a step to be shown after delay and context check
## step_index: Index of step to show
## delay: Delay in seconds before checking context (default from step config)
## context_check: Optional callable that returns true when context is ready
func queue_step(step_index: int, delay: float = -1.0, context_check: Callable = Callable()) -> void:
	if step_index < 0 or step_index >= tutorial_steps.size():
		return
	
	var step = tutorial_steps[step_index]
	
	# Use step's delay if not specified
	if delay < 0:
		delay = step.get("delay_after_trigger", 1.0)
	
	# Use step's context check if not specified
	if not context_check.is_valid():
		var context_type = step.get("wait_for_context", "")
		if not context_type.is_empty():
			context_check = _get_context_check_callable(context_type)
	
	# Cancel any existing delay timer
	if _delay_timer.time_left > 0:
		_delay_timer.stop()
	
	# Queue the step
	var queued_step = {
		"step_index": step_index,
		"delay": delay,
		"context_check": context_check,
		"queued_at": Time.get_ticks_msec()
	}
	_queued_steps.append(queued_step)
	
	# Start delay timer
	_delay_timer.wait_time = delay
	_delay_timer.start()


## Check if context is ready for a queued step
func _check_context_ready(queued_step: Dictionary) -> bool:
	# Check if UI is blocking
	if _check_ui_blocking():
		return false
	
	# Check custom context check if provided
	var context_check = queued_step.get("context_check", Callable())
	if context_check.is_valid():
		return context_check.call()
	
	return true


## Get a callable for checking specific context types
func _get_context_check_callable(context_type: String) -> Callable:
	match context_type:
		"voyage_intro_dismissed":
			return func() -> bool:
				return _is_voyage_intro_dismissed()
		"event_dialog_visible":
			return func() -> bool:
				return _is_event_dialog_visible()
		"team_select_visible":
			return func() -> bool:
				return _is_team_select_visible()
		"tactical_first_turn":
			return func() -> bool:
				return _is_tactical_first_turn()
		"jump_animation_complete":
			return func() -> bool:
				return _is_jump_animation_complete()
		_:
			return Callable()  # No context check needed


## Check if other UI elements are blocking tutorial display
## Public so tutorial_overlay can check
func _check_ui_blocking() -> bool:
	_find_main_node()
	
	if not _main_node:
		return false  # Can't check, assume not blocking
	
	# Check if any blocking dialogs/scenes are visible
	# These are the dialogs that should block tutorial
	var blocking_ui_paths = [
		"DialogLayer/VoyageIntroSceneDialog",
		"DialogLayer/EventSceneDialog",
		"DialogLayer/MissionSceneDialog",
		"DialogLayer/ColonistLossSceneDialog",
		"DialogLayer/GameOverSceneDialog",
		"DialogLayer/NewEarthSceneDialog"
	]
	
	for path in blocking_ui_paths:
		var node = _main_node.get_node_or_null(path)
		if node and node.visible:
			return true
	
	# Check GamePhase - if in EVENT_DISPLAY, TACTICAL, or TRADING, might be blocking
	if "current_phase" in _main_node:
		var phase = _main_node.current_phase
		# EVENT_DISPLAY phase means a scene dialog is showing
		# Check if GamePhase enum exists on the node
		if "GamePhase" in _main_node:
			if phase == _main_node.GamePhase.EVENT_DISPLAY:
				return true
	
	return false


## Helper to find Main node
func _find_main_node() -> void:
	if _main_node:
		return
	
	# Try to find Main node
	var main_scene = get_tree().get_first_node_in_group("main")
	if main_scene:
		_main_node = main_scene
		return
	
	# Try to get Main from root
	var root = get_tree().root
	for child in root.get_children():
		if child.name == "Main" or (child.get_script() and child.get_script().resource_path.ends_with("main.gd")):
			_main_node = child
			return


## Context check helpers
func _is_voyage_intro_dismissed() -> bool:
	_find_main_node()
	if not _main_node:
		return true  # Assume dismissed if can't check
	var voyage_intro = _main_node.get_node_or_null("DialogLayer/VoyageIntroSceneDialog")
	if voyage_intro:
		return not voyage_intro.visible
	return true  # Assume dismissed if node doesn't exist


func _is_event_dialog_visible() -> bool:
	_find_main_node()
	if not _main_node:
		return false
	var event_dialog = _main_node.get_node_or_null("DialogLayer/EventDialog")
	if event_dialog:
		return event_dialog.visible
	return false


func _is_team_select_visible() -> bool:
	_find_main_node()
	if not _main_node:
		return false
	var team_select = _main_node.get_node_or_null("DialogLayer/TeamSelectDialog")
	if team_select:
		return team_select.visible
	return false


func _is_tactical_first_turn() -> bool:
	# Check if tactical mode is active and first turn has begun
	if not GameState.is_in_tactical_mode:
		return false
	
	# Try to get tactical controller
	if not _main_node:
		# Try to find Main node
		var main_scene = get_tree().get_first_node_in_group("main")
		if main_scene:
			_main_node = main_scene
		else:
			# Try to get Main from root
			var root = get_tree().root
			for child in root.get_children():
				if child.name == "Main" or (child.get_script() and child.get_script().resource_path.ends_with("main.gd")):
					_main_node = child
					break
	
	if not _main_node:
		return false
	
	var tactical = _main_node.get_node_or_null("TacticalMode")
	if tactical and "current_turn" in tactical:
		return tactical.current_turn == 1
	
	return false


func _is_jump_animation_complete() -> bool:
	_find_main_node()
	if not _main_node:
		return true  # Assume complete if can't check
	# Check if jump animation is in progress
	if "_is_jump_animating" in _main_node:
		return not _main_node._is_jump_animating
	return true


## Check and show next step (with context checking)
func _check_and_show_next_step() -> void:
	var step = get_current_step()
	if step.is_empty():
		return
	
	# Check if UI is blocking
	if _check_ui_blocking():
		# Queue the step to show later
		var delay = step.get("delay_after_trigger", 1.0)
		queue_step(current_step_index, delay)
		return
	
	# Check context
	var context_type = step.get("wait_for_context", "")
	if not context_type.is_empty():
		var context_check = _get_context_check_callable(context_type)
		if context_check.is_valid() and not context_check.call():
			# Context not ready, queue the step
			var delay = step.get("delay_after_trigger", 1.0)
			queue_step(current_step_index, delay, context_check)
			return
	
	# Context is ready, show immediately (or with small delay)
	var delay = step.get("delay_after_trigger", 0.0)
	if delay > 0:
		queue_step(current_step_index, delay)
	else:
		_trigger_current_step()


## Called when delay timer completes
func _on_delay_timer_timeout() -> void:
	_check_queued_steps()


## Check queued steps and show them if context is ready
## Public so main.gd can trigger checks when context becomes ready
func _check_queued_steps() -> void:
	if _queued_steps.is_empty():
		return
	
	# Check each queued step
	var steps_to_remove: Array[int] = []
	for i in range(_queued_steps.size()):
		var queued_step = _queued_steps[i]
		
		if _check_context_ready(queued_step):
			# Context is ready, show the step
			var step_index = queued_step.get("step_index", -1)
			if step_index >= 0 and step_index < tutorial_steps.size():
				# Update current step index before triggering
				current_step_index = step_index
				# Clear the queue first to prevent conflicts
				_queued_steps.clear()
				if _delay_timer:
					_delay_timer.stop()
				# Now trigger the step
				_trigger_current_step()
				return  # Exit after showing one step
		else:
			# Context not ready yet, check again after a short delay
			_delay_timer.wait_time = 0.2
			_delay_timer.start()
			return
	
	# Remove shown steps (in reverse order to maintain indices)
	steps_to_remove.reverse()
	for i in steps_to_remove:
		_queued_steps.remove_at(i)


## Trigger first step after voyage intro (called from main.gd)
func trigger_first_step() -> void:
	if not is_tutorial_active:
		return
	
	current_step_index = 0
	var delay = tutorial_steps[0].get("delay_after_trigger", 1.0)
	queue_step(0, delay)
