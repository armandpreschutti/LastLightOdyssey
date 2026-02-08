extends Node
## TutorialManager - Singleton to manage the guided tutorial system
## Tracks tutorial progress and emits signals when tutorial prompts should display

signal tutorial_step_triggered(step_id: String, step_data: Dictionary)
signal tutorial_completed
signal tutorial_skipped

const CONFIG_PATH: String = "user://settings.cfg"

# Tutorial steps definition
# Each step has: id, text, target (UI element to highlight), trigger (event that advances)
var tutorial_steps: Array[Dictionary] = [
	{
		"id": "star_map_intro",
		"text": "Welcome, Commander. Your mission: guide humanity's last survivors to New Earth.\n\nClick on AMBER nodes to plot your course. Each jump costs FUEL.",
		"target": "star_map",
		"trigger": "node_clicked",
		"position": "center"
	},
	{
		"id": "resources_intro",
		"text": "Monitor your resources carefully:\n- COLONISTS: Your score and humanity's future\n- FUEL: Required for each jump\n- HULL: Ship integrity - reaches 0 and you're lost\n- SCRAP: Trade currency",
		"target": "management_hud",
		"trigger": "acknowledged",
		"position": "right"
	},
	{
		"id": "event_intro",
		"text": "Random events will test your crew. If you have the right SPECIALIST alive, you can MITIGATE the damage.\n\nMake your choice.",
		"target": "event_dialog",
		"trigger": "event_closed",
		"position": "left"
	},
	{
		"id": "scavenge_intro",
		"text": "SCAVENGE SITES let you send an away team to gather resources.\n\nSelect up to 3 officers for the mission. Choose wisely - death is PERMANENT.",
		"target": "team_select",
		"trigger": "team_selected",
		"position": "center"
	},
	{
		"id": "tactical_movement",
		"text": "TACTICAL MODE: Each officer has 2 ACTION POINTS per turn.\n\nClick on blue-highlighted tiles to MOVE (costs 1 AP).",
		"target": "tactical_map",
		"trigger": "unit_moved",
		"position": "right"
	},
	{
		"id": "tactical_combat",
		"text": "Click on enemies highlighted in RED to ATTACK (costs 1 AP).\n\nCover reduces hit chance. Use it wisely!",
		"target": "tactical_map",
		"trigger": "unit_attacked",
		"position": "right"
	},
	{
		"id": "tactical_abilities",
		"text": "Each specialist has a UNIQUE ABILITY:\n- SCOUT: Overwatch (reaction shot)\n- TECH: Breach (destroy cover)\n- MEDIC: Patch (heal ally)",
		"target": "ability_container",
		"trigger": "acknowledged",
		"position": "left"
	},
	{
		"id": "cryo_stability",
		"text": "WARNING: CRYO-STABILITY decreases each turn!\n\nAt 0%, you lose COLONISTS every turn. Extract before it's too late!",
		"target": "stability_bar",
		"trigger": "acknowledged",
		"position": "left"
	},
	{
		"id": "extraction",
		"text": "Move ALL surviving officers to the GREEN extraction zone to complete the mission.\n\nGood luck, Commander. Humanity is counting on you.",
		"target": "extraction_zone",
		"trigger": "mission_complete",
		"position": "center"
	}
]

# Current tutorial state
var is_tutorial_active: bool = false
var current_step_index: int = 0
var tutorial_completed_flag: bool = false
var _pending_triggers: Array[String] = []


func _ready() -> void:
	_load_tutorial_state()


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
func start_tutorial() -> void:
	if tutorial_completed_flag:
		return
	
	is_tutorial_active = true
	current_step_index = 0
	_trigger_current_step()


## Reset tutorial (called from settings menu)
func reset_tutorial() -> void:
	tutorial_completed_flag = false
	current_step_index = 0
	is_tutorial_active = false
	_save_tutorial_state()


## Skip the entire tutorial
func skip_tutorial() -> void:
	if not is_tutorial_active:
		return
	
	is_tutorial_active = false
	tutorial_completed_flag = true
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


## Called by game systems when specific events occur
func notify_trigger(trigger_name: String) -> void:
	if not is_tutorial_active:
		return
	
	var current_step = get_current_step()
	if current_step.is_empty():
		return
	
	
	if current_step.get("trigger", "") == trigger_name:
		advance_step()


## Advance to the next tutorial step
func advance_step() -> void:
	if not is_tutorial_active:
		return
	
	current_step_index += 1
	
	if current_step_index >= tutorial_steps.size():
		_complete_tutorial()
	else:
		_trigger_current_step()


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
	
	tutorial_step_triggered.emit(step.get("id", ""), step)


func _complete_tutorial() -> void:
	is_tutorial_active = false
	tutorial_completed_flag = true
	_save_tutorial_state()
	tutorial_completed.emit()


## Utility: Check if we're at a specific step
func is_at_step(step_id: String) -> bool:
	var current = get_current_step()
	return current.get("id", "") == step_id


## Force show a specific step (for debugging or special cases)
func force_show_step(step_id: String) -> void:
	for i in range(tutorial_steps.size()):
		if tutorial_steps[i].get("id", "") == step_id:
			current_step_index = i
			is_tutorial_active = true
			_trigger_current_step()
			return
