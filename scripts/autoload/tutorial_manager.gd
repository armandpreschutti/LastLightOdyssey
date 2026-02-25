extends Node
## TutorialManager - Manages contextual, per-mechanic tutorials.
## Tutorials trigger the first time a mechanic is encountered (contextual/just-in-time).
## Each mechanic is independently tracked so players only see each tutorial once.

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "tutorial"

## All mechanic tutorial definitions.
## Each entry maps a mechanic_id to a list of steps.
## Steps: { header, body, panel_anchor, arrow_target }
##   panel_anchor: "top_right" | "center" | "center_right" | "top_left" | "bottom_right"
##   arrow_target: Vector2 in 0-1 viewport fractions  (Vector2(-1,-1) = no arrow)
const TUTORIALS: Dictionary = {
	"star_map": {
		"steps": [
			{
				"header": "STAR MAP",
				"body": "This is your star map. Your ship must reach NEW EARTH.\n\nClick any AMBER node connected to your ship to jump there. Gray nodes are locked until you reach them.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
			{
				"header": "NODE TYPES",
				"body": "WAYPOINTS — trigger random events (good or bad)\nSCAVENGE SITES — tactical combat missions\nWORMHOLES — instant teleport to another sector\n\nPlan your route and conserve resources.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
		],
	},
	"resources": {
		"steps": [
			{
				"header": "CREDITS",
				"body": "CREDITS are your currency. Use them at the TRADING TERMINAL to buy fuel, hull repairs, and supplies.\n\nEarn credits by completing missions and looting containers.",
				"panel_anchor": "center",
				"arrow_target": Vector2(0.11, 0.868),
			},
			{
				"header": "INTEL",
				"body": "INTEL is gathered from Data Logs found during missions.\n\nSpend it at the BARRACKS to unlock and upgrade officer abilities between deployments.",
				"panel_anchor": "center",
				"arrow_target": Vector2(0.11, 0.897),
			},
			{
				"header": "FUEL",
				"body": "FUEL is spent on every jump. You just used some.\n\nWhen fuel hits zero, DRIFT MODE activates — each jump deals hull damage instead. Prioritize fuel on your route.",
				"panel_anchor": "center",
				"arrow_target": Vector2(0.11, 0.926),
			},
			{
				"header": "HULL INTEGRITY",
				"body": "HULL INTEGRITY is your ship's health. It drops 1% every turn during tactical missions.\n\nIf it reaches 0%, the voyage ends in failure. Repair it at the Trading Terminal.",
				"panel_anchor": "center",
				"arrow_target": Vector2(0.11, 0.955),
			},
		],
	},
	"story_signals": {
		"steps": [
			{
				"header": "STORY SIGNAL",
				"body": "A STORY SIGNAL has appeared. These beacons carry the main narrative — reach them, complete the mission, and the choice you make afterward will shape the voyage ahead.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
		],
	},
	"raiders": {
		"steps": [
			{
				"header": "RAIDER SHIP",
				"body": "A RAIDER has entered the sector. Hostile ships pursue you across the map.\n\nIf they catch you, you cannot jump away — you must DEPLOY to fight or SURRENDER. Defeat them to claim a bounty and escape.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
			{
				"header": "DETECTION ZONE",
				"body": "The red circle on the map is the raider's DETECTION ZONE. While your ship is inside it, the raider gives chase.\n\nBeware — they move TWICE per turn. Once a raider locks on, it closes fast.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
		],
	},
	"wormholes": {
		"steps": [
			{
				"header": "WORMHOLE",
				"body": "A WORMHOLE is a free shortcut — entering costs no FUEL, but the destination is unknown. You could land far across the map.\n\nRaiders cannot follow you through, making wormholes a useful escape route.",
				"panel_anchor": "center",
				"arrow_target": Vector2(-1.0, -1.0),
			},
		],
	},
}

var _overlay_scene: PackedScene = null
var _current_canvas_layer: CanvasLayer = null


func _ready() -> void:
	_overlay_scene = load("res://scenes/ui/tutorial_overlay.tscn")


## Returns true if the given mechanic tutorial has already been shown and completed.
func is_mechanic_completed(mechanic_id: String) -> bool:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	return config.get_value(CONFIG_SECTION, mechanic_id + "_completed", false)


## Marks a mechanic as completed and persists to disk.
func mark_mechanic_completed(mechanic_id: String) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, mechanic_id + "_completed", true)
	config.save(CONFIG_PATH)


## Resets ALL mechanic tutorials (called when player presses Reset Tutorial in Settings).
func reset_all_tutorials() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for mechanic_id in TUTORIALS.keys():
		config.set_value(CONFIG_SECTION, mechanic_id + "_completed", false)
	# Also clear the legacy single-key for backwards compatibility
	config.set_value(CONFIG_SECTION, "completed", false)
	config.save(CONFIG_PATH)


## Disables ALL tutorials permanently (called when player presses Skip Tutorial in any popup).
func disable_all_tutorials() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for mechanic_id in TUTORIALS.keys():
		config.set_value(CONFIG_SECTION, mechanic_id + "_completed", true)
	config.save(CONFIG_PATH)


## Request the tutorial for a mechanic. Shows the overlay if not yet completed.
## Safe to call every time the mechanic is first accessed — guards internally.
func request_tutorial(mechanic_id: String) -> void:
	if is_mechanic_completed(mechanic_id):
		return
	if not TUTORIALS.has(mechanic_id):
		push_warning("TutorialManager: Unknown mechanic_id '%s'" % mechanic_id)
		return
	# Don't stack tutorials
	if _current_canvas_layer and is_instance_valid(_current_canvas_layer):
		return

	_show_tutorial(mechanic_id)


func _show_tutorial(mechanic_id: String) -> void:
	if not _overlay_scene:
		push_error("TutorialManager: tutorial_overlay.tscn not loaded")
		return

	var tutorial_data: Dictionary = TUTORIALS[mechanic_id]
	var steps: Array = tutorial_data.get("steps", [])
	if steps.is_empty():
		mark_mechanic_completed(mechanic_id)
		return

	var overlay: Control = _overlay_scene.instantiate()

	_current_canvas_layer = CanvasLayer.new()
	_current_canvas_layer.layer = 50
	_current_canvas_layer.name = "TutorialLayer"
	get_tree().current_scene.add_child(_current_canvas_layer)
	_current_canvas_layer.add_child(overlay)

	overlay.setup_steps(steps)

	overlay.tutorial_completed.connect(_on_tutorial_completed.bind(mechanic_id))
	overlay.tutorial_skipped.connect(_on_tutorial_skipped)

	overlay.show_overlay()


func _on_tutorial_completed(mechanic_id: String) -> void:
	mark_mechanic_completed(mechanic_id)
	_cleanup_overlay()


func _on_tutorial_skipped() -> void:
	disable_all_tutorials()
	_cleanup_overlay()


func _cleanup_overlay() -> void:
	if _current_canvas_layer and is_instance_valid(_current_canvas_layer):
		_current_canvas_layer.queue_free()
	_current_canvas_layer = null
