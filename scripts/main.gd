extends Node
## Main game controller for Last Light Odyssey
## Manages the game loop and switches between management and tactical modes

@onready var management_hud: Control = $ManagementLayer/ManagementHUD
@onready var star_map: Control = $ManagementLayer/StarMap
@onready var barracks_menu: Control = $DialogLayer/BarracksMenu
@onready var event_scene_dialog: Control = $DialogLayer/EventSceneDialog
@onready var event_dialog: Control = $DialogLayer/EventDialog

@onready var mission_recap: Control = $DialogLayer/MissionRecap
@onready var new_earth_scene: Control = $DialogLayer/NewEarthSceneDialog
@onready var voyage_recap: Control = $DialogLayer/VoyageRecap
@onready var voyage_intro_scene_dialog: Control = $DialogLayer/VoyageIntroSceneDialog
@onready var game_over_scene_dialog: Control = $DialogLayer/GameOverSceneDialog
@onready var game_over_recap: Control = $DialogLayer/GameOverRecap
@onready var team_select_dialog: Control = $DialogLayer/TeamSelectDialog
# @onready var trading_dialog: Control = $DialogLayer/TradingDialog - Removed in V2
@onready var mission_scene_dialog: Control = $DialogLayer/MissionSceneDialog
@onready var objective_complete_scene_dialog: Control = $DialogLayer/ObjectiveCompleteSceneDialog
@onready var enemy_elimination_scene_dialog: Control = $DialogLayer/EnemyEliminationSceneDialog
@onready var story_choice_dialog: Control = $DialogLayer/StoryChoiceDialog
@onready var tactical_mode: Node2D = $TacticalMode
@onready var management_layer: CanvasLayer = $ManagementLayer
@onready var management_background: Control = $BackgroundLayer/Background
@onready var fade_transition_layer: CanvasLayer = $FadeTransitionLayer
@onready var fade_transition: Control = $FadeTransitionLayer/FadeTransition

var _pending_ending_type: String = ""  # Store ending type for the win sequence
var _pending_officer_keys: Array[String] = []  # Store selected officers for mission start
var _pending_objectives: Array[MissionObjective] = []  # Store selected objectives for mission start
var _pending_game_over_reason: String = ""  # Store game over reason for the sequence
var _pending_story_victory: bool = false
var _suppress_mission_scene_dismiss_handler: bool = false

# Campaign branching pending state
var _pending_next_choices: Array[String] = []
var _pending_is_terminal_mission: bool = false
var _pending_completed_mission_id: String = ""

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

const CAMPAIGN_POST_SCENES: Dictionary = {
	"1A": {"title": "CHAPTER 1 COMPLETE — 1A", "text": "Mission intelligence archived. Prepare for the next signal.", "location": "DEBRIEF 1A"},
	"2A": {"title": "CHAPTER 2 COMPLETE — 2A", "text": "Route data secured. The path ahead becomes clearer.", "location": "DEBRIEF 2A"},
	"2B": {"title": "CHAPTER 2 COMPLETE — 2B", "text": "Route data secured. An alternative course is charted.", "location": "DEBRIEF 2B"},
	"3A": {"title": "CHAPTER 3 COMPLETE — 3A", "text": "Settlement records analyzed. History guides the future.", "location": "DEBRIEF 3A"},
	"3B": {"title": "CHAPTER 3 COMPLETE — 3B", "text": "Settlement records analyzed. The hub's secrets revealed.", "location": "DEBRIEF 3B"},
	"3C": {"title": "CHAPTER 3 COMPLETE — 3C", "text": "Settlement records analyzed. A new direction emerges.", "location": "DEBRIEF 3C"},
	"4A": {"title": "CHAPTER 4 COMPLETE — 4A", "text": "Corridor verified. The final approach preparations begin.", "location": "DEBRIEF 4A"},
	"4B": {"title": "CHAPTER 4 COMPLETE — 4B", "text": "Corridor verified. The critical juncture is reached.", "location": "DEBRIEF 4B"},
	"4C": {"title": "CHAPTER 4 COMPLETE — 4C", "text": "Corridor verified. Landing zones prioritized.", "location": "DEBRIEF 4C"},
	"4D": {"title": "CHAPTER 4 COMPLETE — 4D", "text": "Corridor verified. Final approach vectors locked.", "location": "DEBRIEF 4D"},
	"5A": {"title": "CHAPTER 5 COMPLETE — ENDING A", "text": "Landing successful. Humanity's new home awaits.", "location": "NEW EARTH A"},
	"5B": {"title": "CHAPTER 5 COMPLETE — ENDING B", "text": "Landing successful. A new era begins.", "location": "NEW EARTH B"},
	"5C": {"title": "CHAPTER 5 COMPLETE — ENDING C", "text": "Landing successful. The voyage concludes.", "location": "NEW EARTH C"},
	"5D": {"title": "CHAPTER 5 COMPLETE — ENDING D", "text": "Landing successful. Home is found.", "location": "NEW EARTH D"},
	"5E": {"title": "CHAPTER 5 COMPLETE — ENDING E", "text": "Landing successful. A new world awaits.", "location": "NEW EARTH E"},
}

const CAMPAIGN_CHOICE_OPTIONS: Dictionary = {
	"2A": {"label": "CHOICE 2A", "text": "Select this path forward."},
	"2B": {"label": "CHOICE 2B", "text": "Select this alternative."},
	"3A": {"label": "CHOICE 3A", "text": "Select this route."},
	"3B": {"label": "CHOICE 3B", "text": "Select this course."},
	"3C": {"label": "CHOICE 3C", "text": "Select this direction."},
	"4A": {"label": "CHOICE 4A", "text": "Select this approach."},
	"4B": {"label": "CHOICE 4B", "text": "Select this option."},
	"4C": {"label": "CHOICE 4C", "text": "Select this vector."},
	"4D": {"label": "CHOICE 4D", "text": "Select this path."},
	"5A": {"label": "CHOICE 5A", "text": "Select Ending A."},
	"5B": {"label": "CHOICE 5B", "text": "Select Ending B."},
	"5C": {"label": "CHOICE 5C", "text": "Select Ending C."},
	"5D": {"label": "CHOICE 5D", "text": "Select Ending D."},
	"5E": {"label": "CHOICE 5E", "text": "Select Ending E."},
}
const ENABLE_STORY_PRE_SCENE: bool = true
const ENABLE_STORY_POST_SCENE: bool = true
const ENABLE_REGULAR_MISSION_SCENE: bool = false
const ENABLE_EVENT_SCENE: bool = false
const ENABLE_VOYAGE_INTRO_SCENE: bool = true
const ENABLE_NEW_EARTH_SCENE: bool = false
const ENABLE_GAME_OVER_SCENE: bool = true
const ENABLE_FADE_TRANSITIONS: bool = true

enum GamePhase { IDLE, EVENT_DISPLAY, TEAM_SELECT, TACTICAL, TRADING, GAME_OVER, GAME_WON }

var current_phase: GamePhase = GamePhase.IDLE
var current_event: Dictionary = {}
var pending_node_type: int = -1  # EventManager.NodeType
var pending_biome_type: int = -1  # BiomeConfig.BiomeType for scavenge missions
var star_map_generator: StarMapGenerator = null
var tutorial_overlay: CanvasLayer = null
var _first_node_clicked: bool = false
var _first_event_seen: bool = false
var _is_jump_animating: bool = false  # Track if jump animation is in progress
var _suppress_fuel_warning: bool = false  # Track if player dismissed fuel warning
var _wormhole_offered_at: String = ""  # Track if wormhole dialog was presented at current node


func _ready() -> void:
	# Initialize random number generator seed
	randomize()
	
	# Add to group for easy discovery by TutorialManager
	add_to_group("main")

	# Fade layer must stay visible/on-top or transitions render invisibly.
	fade_transition_layer.visible = true
	
	# Ensure fade is black immediately (before any other initialization)
	# This prevents grey flash when transitioning from title menu
	fade_transition.set_black()
	
	_connect_signals()
	_initialize_star_map()
	_initialize_tutorial()
	tactical_mode.visible = false
	
	# Wait a frame to ensure everything is initialized, then fade in from black
	await get_tree().process_frame
	_fade_in(0.6)
	
	# Show voyage intro scene when starting a new voyage
	_show_voyage_intro()


func _connect_signals() -> void:
	event_scene_dialog.scene_dismissed.connect(_on_event_scene_dismissed)
	event_dialog.event_choice_made.connect(_on_event_choice_made)
	team_select_dialog.team_selected.connect(_on_team_selected)
	team_select_dialog.cancelled.connect(_on_team_select_cancelled)
	# trading_dialog.trading_complete.connect(_on_trading_complete) - Removed in V2
	mission_scene_dialog.scene_dismissed.connect(_on_mission_scene_dismissed)
	tactical_mode.mission_complete.connect(_on_mission_complete)
	mission_recap.recap_dismissed.connect(_on_recap_dismissed)
	story_choice_dialog.choice_made.connect(_on_story_choice_made)
	new_earth_scene.scene_dismissed.connect(_on_new_earth_scene_dismissed)
	voyage_intro_scene_dialog.scene_dismissed.connect(_on_voyage_intro_scene_dismissed)
	objective_complete_scene_dialog.scene_dismissed.connect(_on_objective_complete_scene_dismissed)
	enemy_elimination_scene_dialog.scene_dismissed.connect(_on_enemy_elimination_scene_dismissed)
	game_over_scene_dialog.scene_dismissed.connect(_on_game_over_scene_dismissed)
	game_over_recap.main_menu_pressed.connect(_on_main_menu_pressed)
	game_over_recap.restart_pressed.connect(_on_restart_pressed)
	game_over_recap.view_map_requested.connect(_on_view_map_requested)
	voyage_recap.main_menu_pressed.connect(_on_main_menu_pressed)
	voyage_recap.restart_pressed.connect(_on_restart_pressed)
	voyage_recap.view_map_requested.connect(_on_view_map_requested)
	management_hud.quit_to_menu_pressed.connect(_on_quit_to_menu)
	management_hud.view_recap_pressed.connect(_on_view_recap_from_map)
	management_hud.market_pressed.connect(_on_market_pressed)
	management_hud.barracks_pressed.connect(_on_barracks_pressed)
	management_hud.deploy_pressed.connect(_on_deploy_pressed)
	management_hud.center_view_pressed.connect(_on_center_view_pressed)
	if barracks_menu.has_signal("closed"):
		barracks_menu.closed.connect(_on_barracks_menu_closed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)


func _initialize_star_map() -> void:
	# Voyage 2.0: Map logic is now handled by VoyageManager
	# StarMap.gd listens to VoyageManager signals to update itself
	
	# Initial refresh to ensure UI is in sync
	star_map.refresh()
	
	# Disconnect signal if already connected (e.g., on restart)
	if star_map.node_clicked.is_connected(_on_node_clicked):
		star_map.node_clicked.disconnect(_on_node_clicked)
	star_map.node_clicked.connect(_on_node_clicked)


	# Ensure voyage manager is ready
	if not VoyageManager:
		push_error("VoyageManager autoload not found!")


func _initialize_tutorial() -> void:
	# Load and add the tutorial overlay
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	tutorial_overlay = tutorial_scene.instantiate()
	add_child(tutorial_overlay)
	
	# Start the tutorial (TutorialManager will check if already completed)
	TutorialManager.start_tutorial()


func _on_node_clicked(node_data: NodeData) -> void:
	
	# Block interactions when tutorial is active
	if tutorial_overlay and tutorial_overlay.is_showing():
		return
	
	if current_phase != GamePhase.IDLE:
		return
	
	if _is_jump_animating:
		return
	
	var current_node_id = VoyageManager.current_node_id
	
	# If clicking the current node (e.g., re-clicking an SCAVENGER or WORMHOLE), skip jump and process directly
	if node_data.id == current_node_id:
		# Allow re-entry logic
		var node_type = node_data.node_type
		if node_type == EventManager.NodeType.WORMHOLE:
			# Re-trigger wormhole dialog ONLY if it was offered at this node
			# In infinite map, maybe just always offer?
			_show_wormhole_dialog()
			return
	

	
	# Tutorial: Notify that a node was clicked (first time only for intro step)
	if not _first_node_clicked:
		_first_node_clicked = true
		TutorialManager.notify_trigger("node_clicked")
	
	# Get fuel cost for this jump
	var fuel_cost = VoyageManager.get_fuel_cost(node_data)
	
	# Determine if this is a neighbor or requires a path
	var current_node = VoyageManager.get_current_node()
	var is_neighbor = current_node and node_data.id in current_node.connections

	if is_neighbor:
		# Check if player has enough fuel - warn about drift mode if not
		if GameState.fuel < fuel_cost and not _suppress_fuel_warning:
			_show_fuel_warning(node_data, fuel_cost)
		else:
			# Start ship jump animation, then execute jump when animation completes
			_execute_jump_with_animation(node_data, fuel_cost)
	else:
		# Attempt direct travel to visited nodes
		# We check if a path exists first (VoyageManager.attempt_direct_travel does this too, but we can checks here for UX)
		# Just call it directly, let VoyageManager handle validation
		
		# For direct travel, we want speed boost (1.25x faster than normal hopping? Or just faster?)
		# User requested 25% faster.
		# Note: attempt_direct_travel default speed_mult is 1.25.
		
		# Check if target is visited
		if node_data.state == NodeData.NodeState.UNVISITED:
			# Can't jump directly to unvisited non-neighbors
			# (This case shouldn't be reachable via click usually unless we allow clicking deep into fog, but logic handles it)
			return

		_execute_direct_travel(node_data)


## Show fuel warning dialog when player doesn't have enough fuel for the jump
func _show_fuel_warning(node_data: NodeData, fuel_cost: int) -> void:
	var fuel_deficit = fuel_cost - GameState.fuel
	var hull_loss = GameState.SHIP_INTEGRITY_LOSS_PER_JUMP * fuel_deficit
	
	var dialog_scene = load("res://scenes/ui/fuel_warning_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	$DialogLayer.add_child(dialog)
	
	dialog.setup(hull_loss)
	dialog.show_dialog()
	
	# Play warning SFX
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "menu_open")
	
	dialog.confirmed.connect(func(suppress_warning: bool):
		if suppress_warning:
			_suppress_fuel_warning = true
		_execute_jump_with_animation(node_data, fuel_cost)
	)


## Execute jump with ship animation
func _execute_jump_with_animation(node_data: NodeData, _fuel_cost: int) -> void:
	# Capture visited state BEFORE jump attempt changes it.
	# STORY nodes must still run arrival scene flow, so they are treated as not-visited here.
	var was_visited = node_data.state == NodeData.NodeState.VISITED or node_data.state == NodeData.NodeState.CLEARED
	
	# Set flag to prevent multiple clicks during animation
	_is_jump_animating = true
	management_hud.set_deploy_active(false)
	
	# Start ship jump animation (StarMap handles visual)
	# We might need to tell StarMap to animate first?
	# Or just let VoyageManager handle the logic and StarMap react.
	# But we want the animation delay.
	
	# For now, simplistic: Call jump on VoyageManager, which emits signals.
	# StarMap should listen and animate.
	# But Main needs to wait for animation before processing the event.
	
	# Let's manually invoke animation on StarMap if needed, OR:
	# VoyageManager.attempt_jump() could be async?
	
	# Let's rely on StarMaps signal 'jump_animation_complete' if call attempt_jump
	# But we are in _on_node_clicked.
	
	# Let's trigger the jump in VoyageManager now.
	var success = VoyageManager.attempt_jump(node_data)
	
	if success:
		# Wait for animation to complete (StarMap should emit this when it sees ship_moved)
		await star_map.jump_animation_complete
		
		# Clear flag after animation completes
		_is_jump_animating = false
		
		# Check if we won
		if current_phase == GamePhase.GAME_WON or current_phase == GamePhase.GAME_OVER:
			return
		
		_process_node_after_jump(node_data, was_visited)
	else:
		_is_jump_animating = false
		_update_deploy_button_visibility()


func _execute_direct_travel(target_node: NodeData) -> void:
	_is_jump_animating = true
	management_hud.set_deploy_active(false)
	
	var success = VoyageManager.attempt_direct_travel(target_node, 3.0)
	
	if success:
		await star_map.jump_animation_complete
		_is_jump_animating = false
		
		if current_phase == GamePhase.GAME_WON or current_phase == GamePhase.GAME_OVER:
			return
			
		_process_node_after_jump(target_node, true) # true = was_visited
	else:
		_is_jump_animating = false
		_update_deploy_button_visibility()


func _process_node_after_jump(node_data: NodeData, was_visited: bool = false) -> void:
	# Determine node type from data
	pending_node_type = node_data.node_type
	pending_biome_type = node_data.biome_type
	
	match pending_node_type:
		EventManager.NodeType.SCAVENGE_SITE:
			if was_visited and node_data.state != NodeData.NodeState.STORY:
				if node_data.state == NodeData.NodeState.STORY or node_data.state != NodeData.NodeState.CLEARED:
					management_hud.set_deploy_active(true)
				else:
					management_hud.set_deploy_active(false)
				return
			
			# Tutorial: Trigger scavenge_intro if not shown yet
			if TutorialManager.is_active() and not "scavenge_intro" in TutorialManager._shown_step_ids:
				# Wait a moment for jump animation, then trigger
				await get_tree().create_timer(0.5).timeout
				TutorialManager.trigger_step_by_id("scavenge_intro")
			
			# Show mission scene first, then team selection
			current_phase = GamePhase.EVENT_DISPLAY
			if node_data.state == NodeData.NodeState.STORY:
				if ENABLE_STORY_PRE_SCENE:
					_show_story_beat_scene()
				else:
					_on_mission_scene_dismissed()
			else:
				if ENABLE_REGULAR_MISSION_SCENE:
					mission_scene_dialog.show_scene(pending_biome_type)
				else:
					_on_mission_scene_dismissed()

		EventManager.NodeType.WORMHOLE:
			# Show wormhole interaction dialog
			_show_wormhole_dialog()

		# Outpost logic removed (deprecated)

		_:
			if was_visited:
				return
			
			# Empty space - roll random event
			_trigger_random_event()


func _trigger_random_event() -> void:
	var current_node = VoyageManager.get_current_node()
	if current_node and current_node.pending_event_id >= 0:
		current_event = EventManager.random_events[current_node.pending_event_id]
	elif current_node and current_node.pending_event_id == -1:
		# No event assigned to this node
		current_event = {}
		current_node.event_penalty_text = ""
		star_map.refresh()
		current_phase = GamePhase.IDLE
		return
	else:
		current_event = EventManager.roll_random_event()
	
	# Determine if we can mitigate
	var use_specialist = EventManager.can_mitigate_event(current_event)
	
	# Resolve event instantly
	var result = EventManager.resolve_event(current_event, use_specialist)
	
	# Store results in node data for display (List all non-zero changes)
	if current_node:
		var display_text = ""
		var effects = []
		
		var integrity_change = result.get("integrity_change", 0)
		if integrity_change != 0:
			var prefix = "+" if integrity_change > 0 else ""
			effects.append(prefix + str(integrity_change) + "% HULL")
			
		var cash_change = result.get("cash_change", 0)
		if cash_change == 0:
			cash_change = result.get("cash_change", 0)
			
		if cash_change != 0:
			var prefix = "+" if cash_change > 0 else ""
			effects.append(prefix + str(cash_change) + " CR")
			
		var fuel_change = result.get("fuel_change", 0)
		if fuel_change != 0:
			var prefix = "+" if fuel_change > 0 else ""
			effects.append(prefix + str(fuel_change) + " FUEL")
		
		# Combine effects into a single string
		if effects.is_empty():
			current_node.event_penalty_text = "NO INCIDENT"
		else:
			current_node.event_penalty_text = ", ".join(effects)
		
		# Log to message log
		var log_msg = "Event: " + current_event.get("name", "Unknown")
		VoyageManager.message_log_added.emit(log_msg)
		
		# Refresh map to show results
		star_map.refresh()

	# Tutorial: Show event intro if this is the first event
	if not _first_event_seen and TutorialManager.is_active():
		_first_event_seen = true
		if TutorialManager.is_at_step("resources_intro"):
			TutorialManager.acknowledge_step()
	
	# Phase is back to IDLE since no dialog is shown
	current_phase = GamePhase.IDLE
	current_event = {}
	
	# Tutorial: Notify that an event was closed (since it's automatic now)
	TutorialManager.notify_trigger("event_closed")


func _on_event_scene_dismissed() -> void:
	# Event scene disabled per user preference.
	if not ENABLE_EVENT_SCENE:
		return
	event_scene_dialog.show_scene(current_event)


func _on_event_choice_made(use_specialist: bool) -> void:
	if current_phase != GamePhase.EVENT_DISPLAY:
		return

	EventManager.resolve_event(current_event, use_specialist)
	
	# Tutorial: Notify that an event was closed
	TutorialManager.notify_trigger("event_closed")

	current_phase = GamePhase.IDLE
	current_event = {}


func _on_team_selected(officer_keys: Array[String], objectives: Array[MissionObjective]) -> void:
	# Store officer keys and objectives for mission start
	_pending_officer_keys = officer_keys
	_pending_objectives = objectives
	
	# Fade to black, then transition to tactical mode
	await _fade_out(0.6)
	
	# Hide the team select dialog explicitly now that we are faded out
	team_select_dialog.visible = false
	
	# Go directly to tactical mission (scene was already shown before team select)
	current_phase = GamePhase.TACTICAL
	
	# Hide management UI, show tactical
	management_layer.visible = false
	management_background.visible = false
	tactical_mode.visible = true
	
	# Tutorial: Notify that team was selected
	TutorialManager.notify_trigger("team_selected")
	
	# Start the mission with biome type, stored officer keys, and stored objectives
	tactical_mode.start_mission(_pending_officer_keys, pending_biome_type, _pending_objectives)
	_pending_officer_keys.clear()
	_pending_objectives.clear()
	
	# Start tactical music if this is a scavenger mission
	if pending_node_type == EventManager.NodeType.SCAVENGE_SITE:
		MusicManager.play_tactical_music()
	
	# Wait a frame to ensure map generation and rendering catch up before fading in
	await get_tree().process_frame
	
	# Fade in from black
	_fade_in(0.6)


func _on_team_select_cancelled() -> void:
	# Player cancelled - still consume the jump but skip the mission
	current_phase = GamePhase.IDLE
	pending_biome_type = -1
	_pending_officer_keys.clear()
	_pending_objectives.clear()
	
	# Re-enable deploy button if appropriate
	_update_deploy_button_visibility()


func _on_mission_scene_dismissed() -> void:
	if _suppress_mission_scene_dismiss_handler:
		_suppress_mission_scene_dismiss_handler = false
		return

	# After mission scene is dismissed, check if we need to show team select
	# If we have pending officers, we're in the old flow (shouldn't happen now)
	# Otherwise, show team select dialog
	if _pending_officer_keys.size() > 0:
		# Old flow - start tactical mission directly (shouldn't happen with new flow)
		current_phase = GamePhase.TACTICAL
		
		# Hide management UI, show tactical
		management_layer.visible = false
		management_background.visible = false
		tactical_mode.visible = true
		
		# Tutorial: Notify that team was selected
		TutorialManager.notify_trigger("team_selected")
		
		# Start the mission with biome type and stored officer keys
		# Old flow - no objectives stored, pass empty array (will generate random in tactical controller)
		tactical_mode.start_mission(_pending_officer_keys, pending_biome_type, [])
		_pending_officer_keys.clear()
		_pending_objectives.clear()
		
		# Start tactical music if this is a scavenger mission
		if pending_node_type == EventManager.NodeType.SCAVENGE_SITE:
			MusicManager.play_tactical_music()
	else:
		# New flow - show deploy button after scene
		current_phase = GamePhase.IDLE # Allow clicking other nodes
		_update_deploy_button_visibility()


## Handle [DEPLOY] button press
func _on_deploy_pressed() -> void:
	if current_phase != GamePhase.IDLE and current_phase != GamePhase.EVENT_DISPLAY:
		return
		
	# Disable button immediately to prevent double-click or stale state
	management_hud.set_deploy_active(false)
	
	# Re-read biome from current node to prevent stale pending_biome_type after abandon
	var current_node = VoyageManager.get_current_node()
	if current_node:
		pending_biome_type = current_node.biome_type
	
	# Transition to team select
	_transition_to_team_select()


func _on_center_view_pressed() -> void:
	if current_phase == GamePhase.IDLE:
		star_map.center_view_on_ship(true)


## Transition to team select screen (skipping scene)
func _transition_to_team_select() -> void:
	current_phase = GamePhase.TEAM_SELECT
	team_select_dialog.show_dialog(pending_biome_type)
	
	# Reset wormhole offered state when entering a mission (edge case cleanup)
	_wormhole_offered_at = ""
	
	# Tutorial: Trigger scavenge_intro after team select dialog is visible
	if TutorialManager.is_active() and TutorialManager.is_at_step("scavenge_intro"):
		# Wait a frame for dialog to become visible, then queue the step
		await get_tree().process_frame
		TutorialManager.queue_step(TutorialManager.current_step_index)


func _on_mission_complete(success: bool, stats: Dictionary) -> void:
	# Stop tactical music when leaving tactical mode
	MusicManager.stop_music()

	# Fade to black, then transition back to management mode
	await _fade_out(0.6)

	# Hide tactical mode
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true
	
	# Ensure deploy button is inactive when returning from mission
	management_hud.set_deploy_active(false)

	# Fade in from black
	_fade_in(0.6)

	# Clear pending campaign state
	_pending_next_choices.clear()
	_pending_is_terminal_mission = false
	_pending_completed_mission_id = ""

	# If mission was successful, mark node as completed (only for scavenge sites)
	if success and pending_node_type == EventManager.NodeType.SCAVENGE_SITE:
		var current_node = VoyageManager.get_current_node()
		if current_node:
			print("DEBUG: current_node.id=%s, state=%d, is_story=%s" % [current_node.id, current_node.state, current_node.state == NodeData.NodeState.STORY])
			if current_node.state == NodeData.NodeState.STORY:
				var story_result = VoyageManager.complete_story_node(current_node.id, true)
				print("DEBUG: story_result = %s" % str(story_result))
				if story_result.get("completed", false):
					var chapter_num = int(story_result.get("chapters_completed", 0))
					var chapter_total = VoyageManager.get_story_chain_length()
					VoyageManager.message_log_added.emit("Story chapter %d/%d completed." % [chapter_num, VoyageManager.get_story_chain_length()])

					# Store campaign branching info for post-recap flow
					var choices = story_result.get("next_choices", [])
					_pending_next_choices.assign(choices)
					_pending_is_terminal_mission = story_result.get("is_terminal", false)
					_pending_completed_mission_id = VoyageManager.current_story_mission_id
					print("DEBUG: After assignment | mission_id=%s choices=%s terminal=%s" % [_pending_completed_mission_id, str(_pending_next_choices), _pending_is_terminal_mission])

				if story_result.get("story_chain_complete", false):
					_pending_story_victory = true
			current_node.state = NodeData.NodeState.CLEARED
			VoyageManager.map_updated.emit()

	# Show mission recap directly (post-scene will be shown after recap is dismissed)
	mission_recap.show_recap(stats)


func _on_recap_dismissed() -> void:
	# Resume navigation music after returning from tactical mission
	MusicManager.play_navigation_music()

	# Tutorial: Notify mission complete
	TutorialManager.notify_trigger("mission_complete")

	# Check if we need to show post-story scene
	if _pending_completed_mission_id != "" and ENABLE_STORY_POST_SCENE:
		await _show_post_story_scene()

	# Always continue to post-story flow (choice dialog or win)
	_on_post_story_flow_complete()


func _show_post_story_scene() -> void:
	current_phase = GamePhase.EVENT_DISPLAY
	_suppress_mission_scene_dismiss_handler = true

	var post_scene = CAMPAIGN_POST_SCENES.get(_pending_completed_mission_id, {})
	var title = post_scene.get("title", "CHAPTER COMPLETE")
	var desc = post_scene.get("text", "Story intelligence archived and uplinked.")
	var location = post_scene.get("location", "STORY DEBRIEF")

	mission_scene_dialog.show_scene(pending_biome_type, "generic", title, desc, location)
	await mission_scene_dialog.scene_dismissed
	# Control returns to _on_recap_dismissed which calls _on_post_story_flow_complete()


func _on_post_story_flow_complete() -> void:
	current_phase = GamePhase.IDLE
	pending_biome_type = -1

	print("DEBUG: _on_post_story_flow_complete | victory=%s terminal=%s mission_id=%s choices=%s" % [
		_pending_story_victory, _pending_is_terminal_mission,
		_pending_completed_mission_id, str(_pending_next_choices)
	])

	if _pending_story_victory:
		_pending_story_victory = false
		GameState.trigger_story_victory(_pending_completed_mission_id)
		return

	if _pending_is_terminal_mission:
		var ending_id = _pending_completed_mission_id
		_pending_next_choices.clear()
		_pending_completed_mission_id = ""
		GameState.trigger_story_victory(ending_id)
		return

	if _pending_next_choices.size() > 0:
		print("DEBUG: Showing choice dialog | choices=%s" % str(_pending_next_choices))
		_show_story_choice_dialog(_pending_next_choices)
		return

	# Refresh the star map
	star_map.refresh()
	star_map.center_view_on_ship(false)

	# Re-show deploy button if we are still at a scavenger site and it's not cleared
	_update_deploy_button_visibility()



# func _on_trading_complete() -> void: - Removed in V2
# 	current_phase = GamePhase.IDLE
# 	# Refresh the star map to update any changed states
# 	star_map.refresh()



func _on_game_over(reason: String) -> void:
	current_phase = GamePhase.GAME_OVER
	_pending_game_over_reason = reason
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true

	# Show game over scene dialog first
	if ENABLE_GAME_OVER_SCENE:
		game_over_scene_dialog.show_scene(reason)
	else:
		_on_game_over_scene_dismissed()


func _on_game_won(ending_type: String) -> void:
	current_phase = GamePhase.GAME_WON
	_pending_ending_type = ending_type
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = false
	management_background.visible = true

	# Show New Earth arrival scene first
	if ENABLE_NEW_EARTH_SCENE:
		new_earth_scene.show_scene(ending_type)
	else:
		_on_new_earth_scene_dismissed()


func _on_new_earth_scene_dismissed() -> void:
	# After New Earth scene, show voyage recap
	voyage_recap.show_recap(_pending_ending_type)


func _on_game_over_scene_dismissed() -> void:
	# After game over scene, show the recap
	game_over_recap.show_recap(_pending_game_over_reason)


func _show_voyage_intro() -> void:
	# Show voyage intro scene when starting a new voyage
	current_phase = GamePhase.EVENT_DISPLAY  # Use EVENT_DISPLAY phase to block interaction
	if ENABLE_VOYAGE_INTRO_SCENE:
		voyage_intro_scene_dialog.show_scene()
	else:
		_on_voyage_intro_scene_dismissed()
	
	# Start navigation music immediately
	MusicManager.play_navigation_music()


func _on_voyage_intro_scene_dismissed() -> void:
	# After voyage intro is dismissed, allow normal gameplay
	current_phase = GamePhase.IDLE
	
	# Trigger first tutorial step after voyage intro completes
	if TutorialManager.is_active() and TutorialManager.is_at_step("star_map_intro"):
		TutorialManager.trigger_first_step()
	
	# Restore deploy button state if we loaded into a mission node
	_restore_deploy_button_state()


func _restore_deploy_button_state() -> void:
	var current_node = VoyageManager.get_current_node()
	if not current_node:
		return
		
	# Check if we are at a valid mission node
	if current_node.node_type == EventManager.NodeType.SCAVENGE_SITE:
		# If it's a story node, it's deployable unless cleared (or some other story logic blocks it)
		if current_node.state == NodeData.NodeState.STORY:
			pending_node_type = current_node.node_type
			pending_biome_type = current_node.biome_type
			management_hud.set_deploy_active(true)
			return
			
		# If it's a regular scavenge site and NOT cleared, it's deployable
		if current_node.state != NodeData.NodeState.CLEARED:
			pending_node_type = current_node.node_type
			pending_biome_type = current_node.biome_type
			management_hud.set_deploy_active(true)
			return
	
	# Default to hidden if not at a deployable node
	management_hud.set_deploy_active(false)









func _on_objective_complete_scene_dismissed() -> void:
	# Resume tactical gameplay (unpause)
	get_tree().paused = false
	# The tactical controller will handle setting is_paused = false when it receives control back


func _on_enemy_elimination_scene_dismissed() -> void:
	# Resume tactical gameplay (unpause)
	get_tree().paused = false
	# The tactical controller will handle setting is_paused = false when it receives control back


func _on_quit_to_menu() -> void:
	# Stop all music when quitting to menu
	MusicManager.stop_music()
	# Return to title menu
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")


func _on_main_menu_pressed() -> void:
	# Stop all music when returning to menu
	MusicManager.stop_music()
	# Return to title menu
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")


func _on_restart_pressed() -> void:
	# Stop all music when restarting
	MusicManager.stop_music()
	
	GameState.reset_game()
	current_phase = GamePhase.IDLE
	current_event = {}
	pending_biome_type = -1
	_pending_game_over_reason = ""
	_first_node_clicked = false
	_first_event_seen = false
	_is_jump_animating = false
	_suppress_fuel_warning = false
	_wormhole_offered_at = ""
	
	# Ensure management UI is visible
	management_layer.visible = true
	management_background.visible = true
	
	# Clean up tactical UI to prevent artifacts from persisting
	tactical_mode.visible = false
	if tactical_mode.has_method("_cleanup_tactical_ui"):
		tactical_mode._cleanup_tactical_ui()
	
	# Hide voyage recap if still visible
	voyage_recap.visible = false
	
	# Regenerate the star map
	_initialize_star_map()
	star_map.center_view_on_ship(false)
	
	# Restart tutorial if not completed
	TutorialManager.start_tutorial()
	
	# Show voyage intro scene again
	_show_voyage_intro()


## Show wormhole detection dialog
func _show_wormhole_dialog() -> void:
	current_phase = GamePhase.EVENT_DISPLAY
	
	var dialog_scene = load("res://scenes/ui/wormhole_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	$DialogLayer.add_child(dialog)
	
	dialog.setup()
	
	# Play alert SFX
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "menu_open")
	
	dialog.confirmed.connect(_on_wormhole_enter_pressed)
	dialog.cancelled.connect(_on_wormhole_cancel_pressed)
	
	dialog.show_dialog()


## Handle entering wormhole
func _on_wormhole_enter_pressed() -> void:
	# Find all other wormhole nodes
	var current_node_id = VoyageManager.current_node_id
	var other_wormholes = []
	
	for node_id in VoyageManager.nodes:
		if node_id != current_node_id and VoyageManager.nodes[node_id].node_type == EventManager.NodeType.WORMHOLE:
			other_wormholes.append(node_id)
	
	if other_wormholes.size() > 0:
		# Pick a random destination
		var target_node_id = other_wormholes.pick_random()
		var target_node = VoyageManager.nodes[target_node_id]
		
		# Teleport (no fuel cost for the jump itself)
		# Update current node directly in VoyageManager
		VoyageManager.current_node_id = target_node_id
		
		# Mark as visited
		if target_node.state == NodeData.NodeState.UNVISITED:
			target_node.state = NodeData.NodeState.VISITED
			# Generate new nodes from here if needed, but wormhole arrival might be special.
			# Let's assume we treat it as arrival for generation:
			# But we need a "previous node" to define direction. Wormhole transport has no previous node direction.
			# Maybe generate in all directions? Or just random?
			# For now, let's NOT generate from wormhole arrival until player moves again?
			# Or just generate default "Right"?
			VoyageManager._handle_arrival_generation(target_node, target_node) # Pass self as previous to indicate no direction?
		
		VoyageManager.ship_moved.emit(target_node.position, target_node)
		VoyageManager.map_updated.emit()
		
		# Play teleport SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("ui", "outpost_arrival")
		
		# Refresh map and center on new node via signal handling (StarMap listens to ship_moved)
		
		# Resume normal flow at new node (as if we just arrived there)
		# But since we're arriving at a wormhole, we don't want to re-trigger the dialog immediately
		# So we just go to IDLE
		current_phase = GamePhase.IDLE
		
		# Ensure we don't offer re-entry for the new wormhole immediately (must jump to it normally)
		_wormhole_offered_at = ""
		
		# Maybe trigger a small notification or log?
		VoyageManager.message_log_added.emit("Wormhole transport successful.")
	else:
		# Should not happen given generation logic, but fallback just in case
		current_phase = GamePhase.IDLE


## Handle cancelling wormhole entry
func _on_wormhole_cancel_pressed() -> void:
	current_phase = GamePhase.IDLE


func _on_view_map_requested(show_map: bool) -> void:
	if show_map:
		# Ensure management layer is visible so map can be seen
		management_layer.visible = true
		management_background.visible = true
		
		# Switch HUD to view recap mode (replace Quit with View Recap)
		management_hud.set_view_recap_mode(true)
	else:
		# Revert HUD to normal mode
		management_hud.set_view_recap_mode(false)
		
		# If we came from game won, we might want to hide it, but standard is to leave it visible
		# behind the recap. However, to match original game won state:
		if current_phase == GamePhase.GAME_WON:
			# Keep map hidden if we want to focus purely on the recap, 
			# but technically the recap covers everything so it doesn't matter much.
			# But for cleanliness/performance:
			# management_layer.visible = false # Optional, but maybe safer to keep it consistent
			pass


func _on_view_recap_from_map() -> void:
	# Determine which recap we came from based on which one is active
	# We check visibility of the recap nodes as they persist while viewing map
	if voyage_recap.visible:
		voyage_recap._on_return_pressed()
	elif game_over_recap.visible:
		game_over_recap._on_return_pressed()
	
	# Note: management_hud.set_view_recap_mode(false) is called automatically
	# via the voyage_recap/game_over_recap signal connected to _on_view_map_requested(false)


func _on_market_pressed() -> void:
	if current_phase != GamePhase.IDLE:
		return
	
	current_phase = GamePhase.TRADING
	
	var market_scene = load("res://scenes/ui/market_menu.tscn")
	var market = market_scene.instantiate()
	$DialogLayer.add_child(market)
	
	market.closed.connect(_on_market_menu_closed)


func _on_market_menu_closed() -> void:
	current_phase = GamePhase.IDLE
	star_map.refresh()
	_update_deploy_button_visibility()


func _on_barracks_pressed() -> void:
	if barracks_menu:
		current_phase = GamePhase.TRADING # Treat as menu phase
		barracks_menu.show_barracks()


func _on_barracks_menu_closed() -> void:
	current_phase = GamePhase.IDLE
	star_map.refresh()
	_update_deploy_button_visibility()


func _show_story_beat_scene() -> void:
	var pending_node = VoyageManager.nodes.get(VoyageManager.active_story_node_id)
	if not pending_node:
		return

	var mission_id = pending_node.campaign_mission_id
	if mission_id == "":
		return

	var pre_scene = CAMPAIGN_PRE_SCENES.get(mission_id, {})
	var title = pre_scene.get("title", "STORY SIGNAL")
	var beat_text = pre_scene.get("text", "")
	var location = pre_scene.get("location", "UNKNOWN SIGNAL")

	mission_scene_dialog.show_scene(pending_biome_type, "generic", title, beat_text, location)


func _show_story_choice_dialog(choices: Array[String]) -> void:
	print("DEBUG: _show_story_choice_dialog | choices=%s" % str(choices))
	story_choice_dialog.setup(choices, CAMPAIGN_CHOICE_OPTIONS)
	story_choice_dialog.show_dialog()
	print("DEBUG: Choice dialog now visible")


func _on_story_choice_made(choice_id: String) -> void:
	_pending_next_choices.clear()
	_pending_completed_mission_id = ""
	VoyageManager.set_branch_choice(choice_id)
	current_phase = GamePhase.IDLE
	star_map.refresh()
	star_map.center_view_on_ship(false)


func _fade_in(duration: float = 0.6) -> void:
	if ENABLE_FADE_TRANSITIONS:
		fade_transition.fade_in(duration)
	else:
		fade_transition.set_transparent()


func _fade_out(duration: float = 0.6) -> void:
	if ENABLE_FADE_TRANSITIONS:
		fade_transition.fade_out(duration)
		await fade_transition.fade_complete
	else:
		fade_transition.set_black()


## Helper to refresh DEPLOY button state based on current node
func _update_deploy_button_visibility() -> void:
	var current_node = VoyageManager.get_current_node()
	if current_node and current_node.node_type == EventManager.NodeType.SCAVENGE_SITE and current_node.state != NodeData.NodeState.CLEARED:
		management_hud.set_deploy_active(true)
	else:
		management_hud.set_deploy_active(false)
