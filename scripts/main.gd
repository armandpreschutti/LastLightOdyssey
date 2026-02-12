extends Node
## Main game controller for Last Light Odyssey
## Manages the game loop and switches between management and tactical modes

@onready var management_hud: Control = $ManagementLayer/ManagementHUD
@onready var star_map: Control = $ManagementLayer/StarMap
@onready var event_scene_dialog: Control = $DialogLayer/EventSceneDialog
@onready var event_dialog: Control = $DialogLayer/EventDialog

@onready var mission_recap: Control = $DialogLayer/MissionRecap
@onready var new_earth_scene: Control = $DialogLayer/NewEarthSceneDialog
@onready var voyage_recap: Control = $DialogLayer/VoyageRecap
@onready var voyage_intro_scene_dialog: Control = $DialogLayer/VoyageIntroSceneDialog
@onready var game_over_scene_dialog: Control = $DialogLayer/GameOverSceneDialog
@onready var game_over_recap: Control = $DialogLayer/GameOverRecap
@onready var team_select_dialog: Control = $DialogLayer/TeamSelectDialog
@onready var trading_dialog: Control = $DialogLayer/TradingDialog
@onready var mission_scene_dialog: Control = $DialogLayer/MissionSceneDialog
@onready var colonist_loss_scene_dialog: Control = $DialogLayer/ColonistLossSceneDialog
@onready var objective_complete_scene_dialog: Control = $DialogLayer/ObjectiveCompleteSceneDialog
@onready var enemy_elimination_scene_dialog: Control = $DialogLayer/EnemyEliminationSceneDialog
@onready var tactical_mode: Node2D = $TacticalMode
@onready var management_layer: CanvasLayer = $ManagementLayer
@onready var management_background: Control = $BackgroundLayer/Background
@onready var fade_transition: Control = $FadeTransitionLayer/FadeTransition

var _pending_ending_type: String = ""  # Store ending type for the win sequence
var _pending_officer_keys: Array[String] = []  # Store selected officers for mission start
var _pending_objectives: Array[MissionObjective] = []  # Store selected objectives for mission start
var _pending_node_after_colonist_loss: int = -1
var _pending_biome_after_colonist_loss: int = -1
var _pending_mission_recap_stats: Dictionary = {}
var _pending_game_over_reason: String = ""  # Store game over reason for the sequence

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
var _wormhole_offered_at: int = -1  # Track if wormhole dialog was presented at current node


func _ready() -> void:
	# Add to group for easy discovery by TutorialManager
	add_to_group("main")
	
	# Ensure fade is black immediately (before any other initialization)
	# This prevents grey flash when transitioning from title menu
	fade_transition.set_black()
	
	_connect_signals()
	_initialize_star_map()
	_initialize_tutorial()
	tactical_mode.visible = false
	
	# Wait a frame to ensure everything is initialized, then fade in from black
	await get_tree().process_frame
	fade_transition.fade_in(0.6)
	
	# Show voyage intro scene when starting a new voyage
	_show_voyage_intro()


func _connect_signals() -> void:
	event_scene_dialog.scene_dismissed.connect(_on_event_scene_dismissed)
	event_dialog.event_choice_made.connect(_on_event_choice_made)
	team_select_dialog.team_selected.connect(_on_team_selected)
	team_select_dialog.cancelled.connect(_on_team_select_cancelled)
	trading_dialog.trading_complete.connect(_on_trading_complete)
	mission_scene_dialog.scene_dismissed.connect(_on_mission_scene_dismissed)
	tactical_mode.mission_complete.connect(_on_mission_complete)
	mission_recap.recap_dismissed.connect(_on_recap_dismissed)
	new_earth_scene.scene_dismissed.connect(_on_new_earth_scene_dismissed)
	voyage_intro_scene_dialog.scene_dismissed.connect(_on_voyage_intro_scene_dismissed)
	colonist_loss_scene_dialog.scene_dismissed.connect(_on_colonist_loss_scene_dismissed)
	objective_complete_scene_dialog.scene_dismissed.connect(_on_objective_complete_scene_dismissed)
	enemy_elimination_scene_dialog.scene_dismissed.connect(_on_enemy_elimination_scene_dismissed)
	game_over_scene_dialog.scene_dismissed.connect(_on_game_over_scene_dismissed)
	game_over_recap.main_menu_pressed.connect(_on_main_menu_pressed)
	game_over_recap.restart_pressed.connect(_on_restart_pressed)
	voyage_recap.main_menu_pressed.connect(_on_main_menu_pressed)
	voyage_recap.restart_pressed.connect(_on_restart_pressed)
	management_hud.quit_to_menu_pressed.connect(_on_quit_to_menu)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)


func _initialize_star_map() -> void:
	# Generate the node graph
	star_map_generator = StarMapGenerator.new()
	var node_graph = star_map_generator.generate()
	
	# Store node types and biome types in GameState for consistency
	for node_data in node_graph:
		GameState.node_types[node_data.id] = node_data.node_type
		if node_data.biome_type >= 0:
			GameState.node_biomes[node_data.id] = node_data.biome_type
	
	# Initialize the visual star map
	star_map.initialize(star_map_generator)
	# Disconnect signal if already connected (e.g., on restart)
	if star_map.node_clicked.is_connected(_on_node_clicked):
		star_map.node_clicked.disconnect(_on_node_clicked)
	star_map.node_clicked.connect(_on_node_clicked)


func _initialize_tutorial() -> void:
	# Load and add the tutorial overlay
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	tutorial_overlay = tutorial_scene.instantiate()
	add_child(tutorial_overlay)
	
	# Start the tutorial (TutorialManager will check if already completed)
	TutorialManager.start_tutorial()


func _on_node_clicked(node_id: int) -> void:
	
	# Block interactions when tutorial is active
	if tutorial_overlay and tutorial_overlay.is_showing():
		return
	
	if current_phase != GamePhase.IDLE:
		return
	
	if _is_jump_animating:
		return
	
	var current_node = GameState.current_node_index
	
	# If clicking the current node (e.g., re-clicking an SCAVENGER or WORMHOLE), skip jump and process directly
	if node_id == current_node:
		# Block interactions when tutorial is active
		if tutorial_overlay and tutorial_overlay.is_showing():
			return
		
		var node_type = star_map.get_node_type(node_id)
		if node_type == EventManager.NodeType.SCAVENGE_SITE:
			# Only allow re-entry if mission was not already successful
			if not GameState.successful_scavenge_nodes.has(node_id):
				# Re-trigger mission flow (intro then team select)
				pending_node_type = node_type
				pending_biome_type = star_map.get_node_biome(node_id)
				current_phase = GamePhase.EVENT_DISPLAY
				mission_scene_dialog.show_scene(pending_biome_type)
			return
		elif node_type == EventManager.NodeType.WORMHOLE:
			# Re-trigger wormhole dialog ONLY if it was offered at this node
			if node_id == _wormhole_offered_at:
				_show_wormhole_dialog()
			return
	

	
	# Tutorial: Notify that a node was clicked (first time only for intro step)
	if not _first_node_clicked:
		_first_node_clicked = true
		TutorialManager.notify_trigger("node_clicked")
	
	# Get fuel cost for this jump
	var from_node = GameState.current_node_index
	var fuel_cost = star_map.get_fuel_cost(from_node, node_id)
	
	# Check if player has enough fuel - warn about drift mode if not
	if GameState.fuel < fuel_cost and not _suppress_fuel_warning:
		_show_fuel_warning(from_node, node_id, fuel_cost)
	else:
		# Start ship jump animation, then execute jump when animation completes
		_execute_jump_with_animation(from_node, node_id, fuel_cost)


## Show fuel warning dialog when player doesn't have enough fuel for the jump
func _show_fuel_warning(from_node_id: int, to_node_id: int, fuel_cost: int) -> void:
	var fuel_deficit = fuel_cost - GameState.fuel
	var colonist_loss = GameState.COLONIST_LOSS_DRIFT_MODE
	var hull_loss = GameState.SHIP_INTEGRITY_LOSS_PER_JUMP * fuel_deficit
	
	var dialog_scene = load("res://scenes/ui/fuel_warning_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	$DialogLayer.add_child(dialog)
	
	dialog.setup(colonist_loss, hull_loss)
	dialog.show_dialog()
	
	# Play warning SFX
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "menu_open")
	
	dialog.confirmed.connect(func(suppress_warning: bool):
		if suppress_warning:
			_suppress_fuel_warning = true
		_execute_jump_with_animation(from_node_id, to_node_id, fuel_cost)
	)


## Execute jump with ship animation
func _execute_jump_with_animation(from_node_id: int, to_node_id: int, fuel_cost: int) -> void:
	# Set flag to prevent multiple clicks during animation
	_is_jump_animating = true
	
	# Start ship jump animation
	star_map.animate_jump(from_node_id, to_node_id)
	
	# Wait for animation to complete
	await star_map.jump_animation_complete
	
	# Clear flag after animation completes
	_is_jump_animating = false
	
	# Execute jump to the selected node with variable fuel cost
	GameState.jump_to_node(to_node_id, fuel_cost)
	star_map.refresh()  # This will also center camera on new node
	
	# Check if we won
	if current_phase == GamePhase.GAME_WON or current_phase == GamePhase.GAME_OVER:
		return
	
	# Check for colonist loss milestones BEFORE showing other scenes
	var threshold = _check_colonist_loss_milestones()
	if threshold >= 0:
		# Store pending node info to process after colonist loss scene
		_pending_node_after_colonist_loss = star_map.get_node_type(to_node_id)
		_pending_biome_after_colonist_loss = star_map.get_node_biome(to_node_id)
		
		# Show colonist loss scene first
		current_phase = GamePhase.EVENT_DISPLAY
		colonist_loss_scene_dialog.show_scene(threshold)
		return
	
	# No colonist loss milestone, proceed with normal node logic
	_process_node_after_jump(to_node_id)


func _process_node_after_jump(node_id: int) -> void:
	# Determine node type from the pre-rolled types
	pending_node_type = star_map.get_node_type(node_id)
	pending_biome_type = star_map.get_node_biome(node_id)
	
	match pending_node_type:
		EventManager.NodeType.SCAVENGE_SITE:
			# Tutorial: Trigger scavenge_intro if not shown yet
			if TutorialManager.is_active() and not "scavenge_intro" in TutorialManager._shown_step_ids:
				# Wait a moment for jump animation, then trigger
				await get_tree().create_timer(0.5).timeout
				TutorialManager.trigger_step_by_id("scavenge_intro")
			
			# Show mission scene first, then team selection
			current_phase = GamePhase.EVENT_DISPLAY
			mission_scene_dialog.show_scene(pending_biome_type)

		EventManager.NodeType.WORMHOLE:
			# Show wormhole interaction dialog
			_wormhole_offered_at = node_id
			_show_wormhole_dialog()

		# Outpost logic removed (deprecated)

		_:
			# Empty space - roll random event
			_trigger_random_event()


func _trigger_random_event() -> void:
	current_event = EventManager.roll_random_event()
	current_phase = GamePhase.EVENT_DISPLAY
	
	# Tutorial: Show event intro if this is the first event
	if not _first_event_seen and TutorialManager.is_active():
		_first_event_seen = true
		# Advance past resources_intro if we're still there
		if TutorialManager.is_at_step("resources_intro"):
			TutorialManager.acknowledge_step()
	
	# Show Oregon Trail-style event scene first, then the choice dialog
	event_scene_dialog.show_scene(current_event)


func _on_event_scene_dismissed() -> void:
	# After the scene is dismissed, show the event choice dialog
	event_dialog.show_event(current_event)
	
	# Tutorial: Trigger event_intro after event dialog is visible
	if TutorialManager.is_active() and TutorialManager.is_at_step("event_intro"):
		# Wait a frame for dialog to become visible, then queue the step
		await get_tree().process_frame
		TutorialManager.queue_step(TutorialManager.current_step_index)


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
	fade_transition.fade_out(0.6)
	await fade_transition.fade_complete
	
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
	fade_transition.fade_in(0.6)


func _on_team_select_cancelled() -> void:
	# Player cancelled - still consume the jump but skip the mission
	current_phase = GamePhase.IDLE
	pending_biome_type = -1
	_pending_officer_keys.clear()
	_pending_objectives.clear()


func _on_mission_scene_dismissed() -> void:
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
		# New flow - show team select dialog after scene
		current_phase = GamePhase.TEAM_SELECT
		team_select_dialog.show_dialog(pending_biome_type)
		
		# Reset wormhole offered state when entering a mission (edge case cleanup)
		_wormhole_offered_at = -1
		
		# Tutorial: Trigger scavenge_intro after team select dialog is visible
		if TutorialManager.is_active() and TutorialManager.is_at_step("scavenge_intro"):
			# Wait a frame for dialog to become visible, then queue the step
			await get_tree().process_frame
			TutorialManager.queue_step(TutorialManager.current_step_index)


func _on_mission_complete(_success: bool, stats: Dictionary) -> void:
	# Stop tactical music when leaving tactical mode
	MusicManager.stop_music()
	
	# Fade to black, then transition back to management mode
	fade_transition.fade_out(0.6)
	await fade_transition.fade_complete
	
	# Hide tactical mode
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true
	
	# Fade in from black
	fade_transition.fade_in(0.6)
	
	# Check for colonist loss milestones BEFORE showing mission recap
	var threshold = _check_colonist_loss_milestones()
	if threshold >= 0:
		# Store mission recap stats to show after colonist loss scene
		_pending_mission_recap_stats = stats
		
		# Show colonist loss scene first
		current_phase = GamePhase.EVENT_DISPLAY
		colonist_loss_scene_dialog.show_scene(threshold)
	else:
		# No colonist loss milestone, show mission recap directly
		mission_recap.show_recap(stats)
	
	# If mission was successful, mark node as completed (only for scavenge sites)
	if stats.get("success", false) and pending_node_type == EventManager.NodeType.SCAVENGE_SITE:
		if not GameState.successful_scavenge_nodes.has(GameState.current_node_index):
			GameState.successful_scavenge_nodes.append(GameState.current_node_index)


func _on_recap_dismissed() -> void:
	current_phase = GamePhase.IDLE
	pending_biome_type = -1
	
	# Resume navigation music after returning from tactical mission
	MusicManager.play_navigation_music()
	
	# Tutorial: Notify mission complete
	TutorialManager.notify_trigger("mission_complete")
	
	# Refresh the star map
	star_map.refresh()


func _on_trading_complete() -> void:
	current_phase = GamePhase.IDLE
	# Refresh the star map to update any changed states
	star_map.refresh()


func _on_game_over(reason: String) -> void:
	current_phase = GamePhase.GAME_OVER
	_pending_game_over_reason = reason
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true

	# Show game over scene dialog first
	game_over_scene_dialog.show_scene(reason)


func _on_game_won(ending_type: String) -> void:
	current_phase = GamePhase.GAME_WON
	_pending_ending_type = ending_type
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = false
	management_background.visible = true

	# Show New Earth arrival scene first
	new_earth_scene.show_scene(ending_type)


func _on_new_earth_scene_dismissed() -> void:
	# After New Earth scene, show voyage recap
	voyage_recap.show_recap(_pending_ending_type)


func _on_game_over_scene_dismissed() -> void:
	# After game over scene, show the recap
	game_over_recap.show_recap(_pending_game_over_reason)


func _show_voyage_intro() -> void:
	# Show voyage intro scene when starting a new voyage
	current_phase = GamePhase.EVENT_DISPLAY  # Use EVENT_DISPLAY phase to block interaction
	voyage_intro_scene_dialog.show_scene()
	
	# Start navigation music immediately
	MusicManager.play_navigation_music()


func _on_voyage_intro_scene_dismissed() -> void:
	# After voyage intro is dismissed, allow normal gameplay
	current_phase = GamePhase.IDLE
	
	# Trigger first tutorial step after voyage intro completes
	if TutorialManager.is_active() and TutorialManager.is_at_step("star_map_intro"):
		TutorialManager.trigger_first_step()





## Get the colonist loss threshold that the current colonist count has crossed
## Returns threshold (750, 500, 250, 100, 0) or -1 if none crossed
func _get_colonist_loss_threshold() -> int:
	var thresholds = [0, 100, 250, 500, 750]  # Check in descending order
	var current_count = GameState.colonist_count
	
	for threshold in thresholds:
		# Check if we've crossed this threshold (current count <= threshold)
		if current_count <= threshold:
			# Check if we haven't shown this milestone yet
			if not GameState.has_shown_milestone(threshold):
				return threshold
	
	return -1


## Check if colonist loss milestone should be shown
## Returns threshold that was crossed (or -1 if none)
func _check_colonist_loss_milestones() -> int:
	return _get_colonist_loss_threshold()


## Handle colonist loss scene dismissal
func _on_colonist_loss_scene_dismissed() -> void:
	# Mark the milestone as shown
	var threshold = _get_colonist_loss_threshold()
	if threshold >= 0:
		GameState.mark_milestone_shown(threshold)
	
	# Check if we have pending node logic to process
	if _pending_node_after_colonist_loss >= 0:
		var node_type = _pending_node_after_colonist_loss
		var biome_type = _pending_biome_after_colonist_loss
		
		# Clear pending state
		_pending_node_after_colonist_loss = -1
		_pending_biome_after_colonist_loss = -1
		
		# Process the pending node
		pending_node_type = node_type
		pending_biome_type = biome_type
		
		match pending_node_type:
			EventManager.NodeType.SCAVENGE_SITE:
				# Show mission scene first, then team selection
				current_phase = GamePhase.EVENT_DISPLAY
				mission_scene_dialog.show_scene(pending_biome_type)

			EventManager.NodeType.WORMHOLE:
				# Show wormhole interaction dialog
				_wormhole_offered_at = GameState.current_node_index
				_show_wormhole_dialog()

			# Outpost logic removed (deprecated)

			_:
				_trigger_random_event()
	# Check if we have pending mission recap to show
	elif _pending_mission_recap_stats.size() > 0:
		var stats = _pending_mission_recap_stats
		_pending_mission_recap_stats = {}
		mission_recap.show_recap(stats)
	else:
		# No pending logic, return to idle
		current_phase = GamePhase.IDLE
		# Resume navigation music after returning from tactical mission
		MusicManager.play_navigation_music()


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
	_wormhole_offered_at = -1
	
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
		SFXManager.play_sfx_by_name("ui", "alert_popup")
	
	dialog.confirmed.connect(_on_wormhole_enter_pressed)
	dialog.cancelled.connect(_on_wormhole_cancel_pressed)
	
	dialog.show_dialog()


## Handle entering wormhole
func _on_wormhole_enter_pressed() -> void:
	# Find all other wormhole nodes
	var current_node_id = GameState.current_node_index
	var other_wormholes = []
	
	for node_id in GameState.node_types.keys():
		if node_id != current_node_id and GameState.node_types[node_id] == EventManager.NodeType.WORMHOLE:
			other_wormholes.append(node_id)
	
	if other_wormholes.size() > 0:
		# Pick a random destination
		var target_node_id = other_wormholes.pick_random()
		
		# Teleport (no fuel cost for the jump itself)
		# Mark source as visited to ensure sprite persists
		if not GameState.visited_nodes.has(current_node_id):
			GameState.visited_nodes.append(current_node_id)
			
		# Update current node directly
		GameState.current_node_index = target_node_id
		GameState.visited_nodes.append(target_node_id)
		GameState.travel_history.append(target_node_id)
		
		# Play teleport SFX
		if SFXManager:
			SFXManager.play_sfx_by_name("ui", "warp_drive")
		
		# Refresh map and center on new node
		star_map.refresh()
		star_map.center_on_node(target_node_id, true)
		
		# Resume normal flow at new node (as if we just arrived there)
		# But since we're arriving at a wormhole, we don't want to re-trigger the dialog immediately
		# So we just go to IDLE
		current_phase = GamePhase.IDLE
		
		# Ensure we don't offer re-entry for the new wormhole immediately (must jump to it normally)
		_wormhole_offered_at = -1
		
		# Maybe trigger a small notification or log?
	else:
		# Should not happen given generation logic, but fallback just in case
		current_phase = GamePhase.IDLE


## Handle cancelling wormhole entry
func _on_wormhole_cancel_pressed() -> void:
	current_phase = GamePhase.IDLE
