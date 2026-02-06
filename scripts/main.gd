extends Node
## Main game controller for Last Light Odyssey
## Manages the game loop and switches between management and tactical modes

@onready var management_hud: Control = $ManagementLayer/ManagementHUD
@onready var star_map: Control = $ManagementLayer/StarMap
@onready var event_dialog: Control = $DialogLayer/EventDialog
@onready var trading_dialog: Control = $DialogLayer/TradingDialog
@onready var game_over_panel: Control = $DialogLayer/GameOverPanel
@onready var game_over_label: Label = $DialogLayer/GameOverPanel/PanelContainer/MarginContainer/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $DialogLayer/GameOverPanel/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var team_select_dialog: Control = $DialogLayer/TeamSelectDialog
@onready var tactical_mode: Node2D = $TacticalMode
@onready var management_layer: CanvasLayer = $ManagementLayer
@onready var management_background: ColorRect = $ManagementBackground

enum GamePhase { IDLE, EVENT_DISPLAY, TEAM_SELECT, TACTICAL, TRADING, GAME_OVER, GAME_WON }

var current_phase: GamePhase = GamePhase.IDLE
var current_event: Dictionary = {}
var pending_node_type: int = -1  # EventManager.NodeType
var pending_biome_type: int = -1  # BiomeConfig.BiomeType for scavenge missions
var star_map_generator: StarMapGenerator = null
var tutorial_overlay: CanvasLayer = null
var _first_node_clicked: bool = false
var _first_event_seen: bool = false


func _ready() -> void:
	_connect_signals()
	_initialize_star_map()
	_initialize_tutorial()
	game_over_panel.visible = false
	tactical_mode.visible = false


func _connect_signals() -> void:
	event_dialog.event_choice_made.connect(_on_event_choice_made)
	trading_dialog.trading_complete.connect(_on_trading_complete)
	team_select_dialog.team_selected.connect(_on_team_selected)
	team_select_dialog.cancelled.connect(_on_team_select_cancelled)
	tactical_mode.mission_complete.connect(_on_mission_complete)
	management_hud.quit_to_menu_pressed.connect(_on_quit_to_menu)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	restart_button.pressed.connect(_on_restart_pressed)


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
	star_map.node_clicked.connect(_on_node_clicked)


func _initialize_tutorial() -> void:
	# Load and add the tutorial overlay
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	tutorial_overlay = tutorial_scene.instantiate()
	add_child(tutorial_overlay)
	
	# Start the tutorial (TutorialManager will check if already completed)
	TutorialManager.start_tutorial()


func _on_node_clicked(node_id: int) -> void:
	print("Main: Node clicked signal received for node %d" % node_id)
	print("Main: Current phase: %d" % current_phase)
	
	if current_phase != GamePhase.IDLE:
		print("Main: Not in IDLE phase, ignoring click")
		return
	
	print("Main: Executing jump to node %d" % node_id)
	
	# Tutorial: Notify that a node was clicked (first time only for intro step)
	if not _first_node_clicked:
		_first_node_clicked = true
		TutorialManager.notify_trigger("node_clicked")
	
	# Get fuel cost for this jump
	var from_node = GameState.current_node_index
	var fuel_cost = star_map.get_fuel_cost(from_node, node_id)
	print("Main: Jump costs %d fuel" % fuel_cost)
	
	# Execute jump to the selected node with variable fuel cost
	GameState.jump_to_node(node_id, fuel_cost)
	star_map.refresh()
	
	# Check if we won
	if current_phase == GamePhase.GAME_WON or current_phase == GamePhase.GAME_OVER:
		return
	
	# Determine node type from the pre-rolled types
	pending_node_type = star_map.get_node_type(node_id)
	pending_biome_type = star_map.get_node_biome(node_id)
	print("Main: Node type is %d, biome is %d" % [pending_node_type, pending_biome_type])
	
	match pending_node_type:
		EventManager.NodeType.SCAVENGE_SITE:
			# Show team selection for tactical mission
			print("Main: Showing team selection dialog")
			current_phase = GamePhase.TEAM_SELECT
			
			# Tutorial: Trigger scavenge intro before showing dialog
			if TutorialManager.is_at_step("scavenge_intro"):
				# The tutorial overlay will show, then player dismisses it
				pass
			
			# Pass biome type to team select dialog for display
			team_select_dialog.show_dialog(pending_biome_type)
		EventManager.NodeType.TRADING_OUTPOST:
			# Show trading interface
			print("Main: Showing trading outpost")
			current_phase = GamePhase.TRADING
			trading_dialog.show_trading()
		_:
			# Empty space - roll random event
			print("Main: Triggering random event")
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
	
	event_dialog.show_event(current_event)


func _on_event_choice_made(use_specialist: bool) -> void:
	if current_phase != GamePhase.EVENT_DISPLAY:
		return

	EventManager.resolve_event(current_event, use_specialist)
	
	# Tutorial: Notify that an event was closed
	TutorialManager.notify_trigger("event_closed")

	current_phase = GamePhase.IDLE
	current_event = {}


func _on_team_selected(officer_keys: Array[String]) -> void:
	current_phase = GamePhase.TACTICAL

	# Hide management UI, show tactical
	management_layer.visible = false
	management_background.visible = false
	tactical_mode.visible = true
	
	# Tutorial: Notify that team was selected
	TutorialManager.notify_trigger("team_selected")

	# Start the mission with biome type
	tactical_mode.start_mission(officer_keys, pending_biome_type)


func _on_team_select_cancelled() -> void:
	# Player cancelled - still consume the jump but skip the mission
	current_phase = GamePhase.IDLE
	pending_biome_type = -1


func _on_mission_complete(_success: bool) -> void:
	# Return to management mode
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true

	current_phase = GamePhase.IDLE
	pending_biome_type = -1
	
	# Tutorial: Notify mission complete
	TutorialManager.notify_trigger("mission_complete")
	
	# Refresh the star map
	star_map.refresh()


func _on_game_over(reason: String) -> void:
	current_phase = GamePhase.GAME_OVER
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true

	game_over_label.text = GameState.get_game_over_text(reason)
	game_over_panel.visible = true


func _on_game_won(ending_type: String) -> void:
	current_phase = GamePhase.GAME_WON
	event_dialog.hide_dialog()
	tactical_mode.visible = false
	management_layer.visible = true
	management_background.visible = true

	game_over_label.text = GameState.get_ending_text(ending_type)
	game_over_panel.visible = true


func _on_trading_complete() -> void:
	current_phase = GamePhase.IDLE


func _on_quit_to_menu() -> void:
	# Return to title menu
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")


func _on_restart_pressed() -> void:
	GameState.reset_game()
	current_phase = GamePhase.IDLE
	current_event = {}
	pending_biome_type = -1
	game_over_panel.visible = false
	_first_node_clicked = false
	_first_event_seen = false
	
	# Regenerate the star map
	_initialize_star_map()
	
	# Restart tutorial if not completed
	TutorialManager.start_tutorial()
