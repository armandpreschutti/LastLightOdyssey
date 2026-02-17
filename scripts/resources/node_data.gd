class_name NodeData
extends Resource

## Data container for a single node in the progressive graph system
## Stores unique ID, world position, connections, and game state

# Node States
enum NodeState {
	UNVISITED = 0, # Default state, interactable
	CLEARED = 1,   # Extracted successfully, safe to revisit but no rewards (maybe fuel cost)
	VISITED = 2,   # Visited but not necessarily cleared (e.g. just passed through)
	LOCKED = 3,    # Not reachable (visual only, logic handled by manager)
	STORY = 4,      # Special story node
	TRADING = 5,    # Trading outpost
}

# Difficulty Grades
enum DifficultyGrade {
	EASY = 0,
	MEDIUM = 1,
	HARD = 2,
	IMPOSSIBLE = 3
}

# Core Properties
@export var id: String
@export var position: Vector2 # World space position for UI
@export var connections: Array[String] = [] # IDs of connected nodes
@export var parent_id: String = "" # ID of the node that generated this one (for directionality)

@export var node_type: int = EventManager.NodeType.EMPTY_SPACE # See EventManager.NodeType
@export var biome_type: int = -1 # See BiomeConfig.BiomeType
@export var state: NodeState = NodeState.UNVISITED
@export var is_new_earth: bool = false

# Difficulty Properties
@export var difficulty_grade: DifficultyGrade = DifficultyGrade.EASY
@export var difficulty_multiplier: float = 1.0
@export var difficulty_revealed: bool = true # Per user request "yes it should be revealed"

# UI Helper Properties
@export var fuel_cost_to_enter: int = 1
@export var event_penalty_text: String = "" # e.g. "-15 HULL"
@export var event_mitigation_text: String = "" # e.g. "+10 WITH TECH"
@export var pending_event_id: int = -1 # Pre-rolled random event ID

func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_type: int = EventManager.NodeType.EMPTY_SPACE) -> void:
	id = p_id
	position = p_pos
	node_type = p_type
	# Default state is UNVISITED
	state = NodeState.UNVISITED

## Helper to check if node is interactable
func is_interactable() -> bool:
	return state == NodeState.UNVISITED or state == NodeState.STORY

## Helper to check if node is safe/cleared
func is_cleared() -> bool:
	return state == NodeState.CLEARED or state == NodeState.VISITED
