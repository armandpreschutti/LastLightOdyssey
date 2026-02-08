extends PanelContainer
## Objectives Panel - Displays mission objectives in the tactical HUD

@onready var header_label: Label = $VBoxContainer/HeaderLabel
@onready var objectives_list: VBoxContainer = $VBoxContainer/ObjectivesList

var objectives: Array[MissionObjective] = []
var objective_labels: Dictionary = {}  # Maps objective ID to Label node

func _init() -> void:
	# Ensure the panel is ready
	pass


func _ready() -> void:
	visible = false


func initialize(new_objectives: Array[MissionObjective]) -> void:
	## Initialize the panel with a list of objectives
	objectives = new_objectives
	_update_display()


func update_objective(objective_id: String) -> void:
	## Update a specific objective's display
	var objective = MissionObjective.ObjectiveManager.get_objective_by_id(objectives, objective_id)
	if objective and objective_id in objective_labels:
		_update_objective_label(objective_labels[objective_id], objective)


func update_all() -> void:
	## Update all objectives display
	_update_display()


func _update_display() -> void:
	## Clear and rebuild the objectives display
	# Clear existing labels
	for child in objectives_list.get_children():
		child.queue_free()
	objective_labels.clear()
	
	# Update header to singular/plural based on count
	if objectives.size() == 1:
		header_label.text = "MISSION OBJECTIVE"
	else:
		header_label.text = "MISSION OBJECTIVES"
	
	# Create labels for each objective (should be just one now)
	for objective in objectives:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 14)
		objectives_list.add_child(label)
		objective_labels[objective.id] = label
		_update_objective_label(label, objective)
	
	# Show panel if there are objectives
	visible = objectives.size() > 0


func _update_objective_label(label: Label, objective: MissionObjective) -> void:
	## Update a single objective label with current state
	var display_text = objective.get_display_text()
	
	# Get potential rewards for display
	var potential_rewards = MissionObjective.ObjectiveManager.get_potential_rewards(objective)
	var reward_parts: Array[String] = []
	
	if potential_rewards.get("fuel", 0) > 0:
		reward_parts.append("%d FUEL" % potential_rewards.get("fuel", 0))
	if potential_rewards.get("scrap", 0) > 0:
		reward_parts.append("%d SCRAP" % potential_rewards.get("scrap", 0))
	if potential_rewards.get("colonists", 0) > 0:
		reward_parts.append("%d COLONISTS" % potential_rewards.get("colonists", 0))
	if potential_rewards.get("hull_repair", 0) > 0:
		reward_parts.append("%d%% HULL" % potential_rewards.get("hull_repair", 0))
	
	# Add reward info to display text
	if reward_parts.size() > 0:
		display_text += " [REWARD: " + " / ".join(reward_parts) + "]"
	
	label.text = display_text
	
	# Color coding based on state
	if objective.completed:
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))  # Green for complete
		label.text = "✓ " + label.text
	elif objective.progress > 0:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))  # Yellow for in progress
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # White for incomplete
