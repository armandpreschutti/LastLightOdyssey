class_name NodeInfoPanel
extends Control
## Node Info Panel – displays a contextual description for the current star map node.
## Hidden on WAYPOINT (EMPTY_SPACE) nodes; visible for all other node types.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var separator: ColorRect = $MarginContainer/VBoxContainer/Separator
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var location_label: Label = $MarginContainer/VBoxContainer/LocationLabel

const CAMPAIGN_PRE_SCENES: Dictionary = {
	"1A": {"title": "CHAPTER 1 — MISSION 1A", "text": "Long-range telemetry locks onto a fragmented pre-colony beacon. You are not the first to cross this void.", "location": "SIGNAL 1A"},
	"2A": {"title": "CHAPTER 2 — MISSION 2A", "text": "A broken relay repeats distress metadata from decades ago. The signal carries coordinates and a warning.", "location": "SIGNAL 2A"},
	"2B": {"title": "CHAPTER 2 — MISSION 2B", "text": "A broken relay repeats distress metadata from decades ago. Alternative route detected ahead.", "location": "SIGNAL 2B"},
	"3A": {"title": "CHAPTER 3 — MISSION 3A", "text": "Cryo archival fragments suggest a failed settlement attempt. Survivors marked a fallback route deeper into the sector.", "location": "SIGNAL 3A"},
	"3B": {"title": "CHAPTER 3 — MISSION 3B", "text": "Cryo archival fragments suggest a failed settlement attempt. A central hub shows signs of recent activity.", "location": "SIGNAL 3B"},
	"3C": {"title": "CHAPTER 3 — MISSION 3C", "text": "Cryo archival fragments suggest a failed settlement attempt. A divergent path emerges from the data.", "location": "SIGNAL 3C"},
	"4A": {"title": "CHAPTER 4 — MISSION 4A", "text": "Your scans isolate a stable corridor hidden behind false readings. The way forward requires direct ground verification.", "location": "SIGNAL 4A"},
	"4B": {"title": "CHAPTER 4 — MISSION 4B", "text": "Your scans isolate a stable corridor hidden behind false readings. A critical juncture approaches.", "location": "SIGNAL 4B"},
	"4C": {"title": "CHAPTER 4 — MISSION 4C", "text": "Your scans isolate a stable corridor hidden behind false readings. Multiple landing zones identified.", "location": "SIGNAL 4C"},
	"4D": {"title": "CHAPTER 4 — MISSION 4D", "text": "Your scans isolate a stable corridor hidden behind false readings. The final approach vector is set.", "location": "SIGNAL 4D"},
	"5A": {"title": "CHAPTER 5 — ENDING A", "text": "Final beacon packet recovered. The navigation solution is complete. Path A selected.", "location": "ENDING A"},
	"5B": {"title": "CHAPTER 5 — ENDING B", "text": "Final beacon packet recovered. The navigation solution is complete. Path B selected.", "location": "ENDING B"},
	"5C": {"title": "CHAPTER 5 — ENDING C", "text": "Final beacon packet recovered. The navigation solution is complete. Path C selected.", "location": "ENDING C"},
	"5D": {"title": "CHAPTER 5 — ENDING D", "text": "Final beacon packet recovered. The navigation solution is complete. Path D selected.", "location": "ENDING D"},
	"5E": {"title": "CHAPTER 5 — ENDING E", "text": "Final beacon packet recovered. The navigation solution is complete. Path E selected.", "location": "ENDING E"},
}

const BIOME_DESCRIPTIONS: Dictionary = {
	BiomeConfig.BiomeType.STATION:  "A derelict orbital station. Deploy your team to scavenge resources and neutralize hostile forces.",
	BiomeConfig.BiomeType.ASTEROID: "A remote asteroid field. Tactical extraction required — clear the site and recover salvage.",
	BiomeConfig.BiomeType.PLANET:   "Hostile planetary surface. Dense terrain and alien encounters make extraction dangerous.",
}

const DIFFICULTY_LABELS: Dictionary = {
	NodeData.DifficultyGrade.EASY:       "EASY",
	NodeData.DifficultyGrade.MEDIUM:     "MEDIUM",
	NodeData.DifficultyGrade.HARD:       "HARD",
	NodeData.DifficultyGrade.IMPOSSIBLE: "IMPOSSIBLE",
}

const WORMHOLE_DESCRIPTION: String = "A stable spacetime anomaly detected in this sector. Logic engines calculate a 94.3% probability of safe transport to an unknown sector within the cluster. Destination unknown."
const OUTPOST_DESCRIPTION: String  = "A functioning trade outpost. Exchange resources, credits, and fuel. Rest and resupply before continuing the voyage."
const EARTH_DESCRIPTION: String    = "Earth — point of departure. The last remnant of human origin."
const NEW_EARTH_DESCRIPTION: String = "New Earth — your destination. The final beacon coordinates converge here."

const COLOR_CYAN  := Color(0.4, 0.9, 1.0, 1.0)
const COLOR_STORY := Color(0.95, 0.45, 1.0, 1.0)
const COLOR_WHITE := Color(0.9, 0.9, 0.9, 1.0)
const COLOR_GRAY  := Color(0.6, 0.6, 0.6, 1.0)
const COLOR_EASY       := Color(0.2, 1.0, 0.2, 1.0)
const COLOR_MEDIUM     := Color(1.0, 0.69, 0.0, 1.0)
const COLOR_HARD       := Color(1.0, 0.2, 0.2, 1.0)
const COLOR_IMPOSSIBLE := Color(0.6, 0.0, 1.0, 1.0)


func show_node(node_data: NodeData) -> void:
	if not node_data:
		hide_panel()
		return

	visible = true

	if node_data.position == Vector2.ZERO:
		_set_content("TRADING OUTPOST", OUTPOST_DESCRIPTION, "", COLOR_CYAN)
		return

	if node_data.is_new_earth:
		_set_content("NEW EARTH", NEW_EARTH_DESCRIPTION, "", COLOR_CYAN)
		return

	if node_data.is_story_node:
		_show_story(node_data)
		return

	match node_data.node_type:
		EventManager.NodeType.SCAVENGE_SITE:
			_show_scavenger(node_data)
		EventManager.NodeType.WORMHOLE:
			_show_wormhole(node_data)
		EventManager.NodeType.TRADING_OUTPOST:
			_set_content("OUTPOST", OUTPOST_DESCRIPTION, "", COLOR_CYAN)
		_:
			hide_panel()


func hide_panel() -> void:
	visible = false


func _show_story(node_data: NodeData) -> void:
	var mission_id := node_data.campaign_mission_id
	var scene_data = CAMPAIGN_PRE_SCENES.get(mission_id, {})

	var title_text := scene_data.get("title", "STORY SIGNAL") as String
	var desc_text  := scene_data.get("text", "An unknown signal pulses from this sector.") as String
	var loc_text   := scene_data.get("location", "") as String

	_set_content(title_text, desc_text, loc_text, COLOR_STORY)


func _show_scavenger(node_data: NodeData) -> void:
	var biome_name := BiomeConfig.get_biome_name(node_data.biome_type).to_upper()
	var desc_text  := BIOME_DESCRIPTIONS.get(node_data.biome_type, "Scavenge site. Deploy team to extract resources.") as String

	var title_color := COLOR_CYAN
	var location_text := ""

	if node_data.difficulty_revealed:
		var grade_label := DIFFICULTY_LABELS.get(node_data.difficulty_grade, "UNKNOWN") as String
		var grade_color := _get_grade_color(node_data.difficulty_grade)
		location_text = "DIFFICULTY: " + grade_label
		title_color = grade_color

	_set_content(biome_name, desc_text, location_text, title_color)


func _show_wormhole(_node_data: NodeData) -> void:
	_set_content("WORMHOLE", WORMHOLE_DESCRIPTION, "", COLOR_CYAN)


func _set_content(title: String, desc: String, location: String, title_color: Color) -> void:
	title_label.text = title
	title_label.add_theme_color_override("font_color", title_color)
	separator.color = title_color
	separator.color.a = 0.4

	description_label.text = desc

	if location.is_empty():
		location_label.visible = false
	else:
		location_label.visible = true
		location_label.text = location


func _get_grade_color(grade: NodeData.DifficultyGrade) -> Color:
	match grade:
		NodeData.DifficultyGrade.EASY:       return COLOR_EASY
		NodeData.DifficultyGrade.MEDIUM:     return COLOR_MEDIUM
		NodeData.DifficultyGrade.HARD:       return COLOR_HARD
		NodeData.DifficultyGrade.IMPOSSIBLE: return COLOR_IMPOSSIBLE
	return COLOR_CYAN
