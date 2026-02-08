class_name MissionObjective
extends RefCounted
## Mission Objective - Represents a single mission objective with tracking

enum ObjectiveType { PROGRESS, BINARY }

var id: String
var description: String
var type: ObjectiveType
var progress: int = 0
var max_progress: int = 1
var completed: bool = false

func _init(p_id: String, p_description: String, p_type: ObjectiveType, p_max_progress: int = 1) -> void:
	id = p_id
	description = p_description
	type = p_type
	max_progress = p_max_progress
	progress = 0
	completed = false


func add_progress(amount: int = 1) -> void:
	if completed:
		return
	
	progress += amount
	if type == ObjectiveType.PROGRESS:
		completed = (progress >= max_progress)
	else:
		completed = (progress >= max_progress)


func set_completed() -> void:
	completed = true
	if type == ObjectiveType.PROGRESS:
		progress = max_progress
	else:
		progress = max_progress


func get_display_text() -> String:
	if type == ObjectiveType.PROGRESS:
		return "%s (%d/%d)" % [description, progress, max_progress]
	else:
		if completed:
			return "%s - COMPLETE" % description
		else:
			return description


func get_progress_percent() -> float:
	if max_progress <= 0:
		return 0.0
	return float(progress) / float(max_progress)


#region Objective Manager

class ObjectiveManager:
	## Static manager for biome-specific objectives
	
	# Biome-specific objective definitions
	const BIOME_OBJECTIVES: Dictionary = {
		BiomeConfig.BiomeType.STATION: [
			{"id": "hack_security", "description": "Hack security systems", "type": MissionObjective.ObjectiveType.BINARY},
			{"id": "retrieve_logs", "description": "Retrieve data logs", "type": MissionObjective.ObjectiveType.PROGRESS, "max": 3},
			{"id": "repair_core", "description": "Repair power core", "type": MissionObjective.ObjectiveType.BINARY},
		],
		BiomeConfig.BiomeType.ASTEROID: [
			{"id": "clear_passages", "description": "Clear cave passages", "type": MissionObjective.ObjectiveType.PROGRESS, "max": 4},
			{"id": "activate_mining", "description": "Activate mining equipment", "type": MissionObjective.ObjectiveType.BINARY},
			{"id": "extract_minerals", "description": "Extract rare minerals", "type": MissionObjective.ObjectiveType.PROGRESS, "max": 2},
		],
		BiomeConfig.BiomeType.PLANET: [
			{"id": "collect_samples", "description": "Collect alien samples", "type": MissionObjective.ObjectiveType.PROGRESS, "max": 5},
			{"id": "activate_beacons", "description": "Activate beacons", "type": MissionObjective.ObjectiveType.PROGRESS, "max": 3},
			{"id": "clear_nests", "description": "Clear hostile nests", "type": MissionObjective.ObjectiveType.BINARY},
		],
	}
	
	
	static func get_objectives_for_biome(biome_type: BiomeConfig.BiomeType) -> Array[MissionObjective]:
		## Get a single randomly selected objective for a specific biome type
		var objective_defs = BIOME_OBJECTIVES.get(biome_type, [])
		
		if objective_defs.is_empty():
			return []
		
		# Randomly select one objective from the biome's options
		var selected_def = objective_defs[randi() % objective_defs.size()]
		
		var obj_type = selected_def.get("type", MissionObjective.ObjectiveType.BINARY)
		var max_prog = selected_def.get("max", 1)
		var objective = MissionObjective.new(
			selected_def.get("id", ""),
			selected_def.get("description", "Unknown objective"),
			obj_type,
			max_prog
		)
		
		# Return as array with single element for compatibility
		return [objective]
	
	
	static func get_objective_by_id(objectives: Array[MissionObjective], id: String) -> MissionObjective:
		## Find an objective by its ID
		for obj in objectives:
			if obj.id == id:
				return obj
		return null
	
	
	static func get_bonus_rewards(objective: MissionObjective) -> Dictionary:
		## Get bonus rewards for a completed objective
		## Returns Dictionary with "fuel" and "scrap" keys
		if not objective or not objective.completed:
			return {"fuel": 0, "scrap": 0}
		
		# Define bonus rewards based on objective type and ID
		match objective.id:
			# Collection objectives (fuel/scrap)
			"retrieve_logs", "extract_minerals", "collect_samples":
				return {"fuel": 0, "scrap": 10}
			
			# Kill-based objectives
			"clear_passages", "clear_nests":
				return {"fuel": 0, "scrap": 5}
			
			# Binary objectives (hack, repair, activate, etc.)
			"hack_security", "repair_core", "activate_mining", "activate_beacons":
				return {"fuel": 3, "scrap": 0}
			
			_:
				# Default bonus for unknown objectives
				return {"fuel": 2, "scrap": 5}

#endregion
