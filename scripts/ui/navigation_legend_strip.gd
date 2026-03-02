extends MarginContainer
## Compact navigation legend strip. Updates dynamically based on node types
## present in the current voyage. Shows icon + count; hides entries with zero count.
## Clicking an entry snaps the star map camera to that node type. Successive clicks
## cycle through all visible nodes of that category.

const TOOLTIP_DELAY := 0.3

# Entry containers and count labels
@onready var story_entry: HBoxContainer = $PanelContainer/HBoxContainer/StoryEntry
@onready var story_count_label: Label = $PanelContainer/HBoxContainer/StoryEntry/StoryCountLabel
@onready var raider_entry: HBoxContainer = $PanelContainer/HBoxContainer/RaiderEntry
@onready var raider_count_label: Label = $PanelContainer/HBoxContainer/RaiderEntry/RaiderCountLabel
@onready var asteroid_entry: HBoxContainer = $PanelContainer/HBoxContainer/AsteroidEntry
@onready var asteroid_count_label: Label = $PanelContainer/HBoxContainer/AsteroidEntry/AsteroidCountLabel
@onready var planet_entry: HBoxContainer = $PanelContainer/HBoxContainer/PlanetEntry
@onready var planet_count_label: Label = $PanelContainer/HBoxContainer/PlanetEntry/PlanetCountLabel
@onready var outpost_entry: HBoxContainer = $PanelContainer/HBoxContainer/OutpostEntry
@onready var outpost_count_label: Label = $PanelContainer/HBoxContainer/OutpostEntry/OutpostCountLabel
@onready var wormhole_entry: HBoxContainer = $PanelContainer/HBoxContainer/WormholeEntry
@onready var wormhole_count_label: Label = $PanelContainer/HBoxContainer/WormholeEntry/WormholeCountLabel

# Cached node lists per legend category. Rebuilt each time the legend refreshes.
var _story_nodes: Array[NodeData] = []
var _raider_nodes: Array[NodeData] = []
var _asteroid_nodes: Array[NodeData] = []
var _planet_nodes: Array[NodeData] = []
var _outpost_nodes: Array[NodeData] = []
var _wormhole_nodes: Array[NodeData] = []

# Cycle indices — start at -1 so the first click lands on index 0.
# Reset to -1 whenever the node lists are rebuilt.
var _story_idx: int = -1
var _raider_idx: int = -1
var _asteroid_idx: int = -1
var _planet_idx: int = -1
var _outpost_idx: int = -1
var _wormhole_idx: int = -1


func _ready() -> void:
	_set_tooltip_delay(story_entry.get_node("StoryIcon"))
	_set_tooltip_delay(raider_entry.get_node("RaiderIcon"))
	_set_tooltip_delay(asteroid_entry.get_node("AsteroidIcon"))
	_set_tooltip_delay(planet_entry.get_node("PlanetIcon"))
	_set_tooltip_delay(outpost_entry.get_node("OutpostIcon"))
	_set_tooltip_delay(wormhole_entry.get_node("WormholeIcon"))

	story_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "story"))
	raider_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "raider"))
	asteroid_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "asteroid"))
	planet_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "planet"))
	outpost_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "outpost"))
	wormhole_entry.gui_input.connect(func(e): _on_entry_gui_input(e, "wormhole"))

	if VoyageManager:
		VoyageManager.map_updated.connect(_refresh_legend)
		VoyageManager.raider_destroyed.connect(_refresh_legend)

	_refresh_legend()


func _refresh_legend() -> void:
	if not VoyageManager:
		return

	# Story Signals
	var story_count := 1 if not VoyageManager.active_story_node_id.is_empty() else 0
	story_entry.visible = story_count > 0
	if story_count > 0:
		story_count_label.text = str(story_count)

	# Raider Ambush
	var raider_count := VoyageManager.raider_node_ids.size()
	raider_entry.visible = raider_count > 0
	if raider_count > 0:
		raider_count_label.text = str(raider_count)

	# Asteroid (SCAVENGE_SITE with ASTEROID biome; exclude story - they use story_signal)
	var asteroid_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if not _is_legend_visible(n):
			continue
		if n.node_type == EventManager.NodeType.SCAVENGE_SITE and not n.is_story_node:
			if n.biome_type == BiomeConfig.BiomeType.ASTEROID:
				asteroid_count += 1

	asteroid_entry.visible = asteroid_count > 0
	if asteroid_count > 0:
		asteroid_count_label.text = str(asteroid_count)

	# Planet (SCAVENGE_SITE with PLANET biome; exclude story)
	var planet_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if not _is_legend_visible(n):
			continue
		if n.node_type == EventManager.NodeType.SCAVENGE_SITE and not n.is_story_node:
			if n.biome_type == BiomeConfig.BiomeType.PLANET:
				planet_count += 1

	planet_entry.visible = planet_count > 0
	if planet_count > 0:
		planet_count_label.text = str(planet_count)

	# Outpost (TRADING_OUTPOST node type)
	var outpost_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if not _is_legend_visible(n):
			continue
		if n.node_type == EventManager.NodeType.TRADING_OUTPOST:
			outpost_count += 1

	outpost_entry.visible = outpost_count > 0
	if outpost_count > 0:
		outpost_count_label.text = str(outpost_count)

	# Wormhole (WORMHOLE node type)
	var wormhole_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if not _is_legend_visible(n):
			continue
		if n.node_type == EventManager.NodeType.WORMHOLE:
			wormhole_count += 1

	wormhole_entry.visible = wormhole_count > 0
	if wormhole_count > 0:
		wormhole_count_label.text = str(wormhole_count)

	_build_node_lists()


## Rebuild the per-category node arrays and reset all cycle indices.
## Called at the end of every _refresh_legend() so the cache stays in sync.
func _build_node_lists() -> void:
	if not VoyageManager:
		return

	_story_nodes.clear()
	_raider_nodes.clear()
	_asteroid_nodes.clear()
	_planet_nodes.clear()
	_outpost_nodes.clear()
	_wormhole_nodes.clear()

	_story_idx = -1
	_raider_idx = -1
	_asteroid_idx = -1
	_planet_idx = -1
	_outpost_idx = -1
	_wormhole_idx = -1

	if not VoyageManager.active_story_node_id.is_empty() \
			and VoyageManager.nodes.has(VoyageManager.active_story_node_id):
		_story_nodes.append(VoyageManager.nodes[VoyageManager.active_story_node_id])

	for rid in VoyageManager.raider_node_ids:
		if VoyageManager.nodes.has(rid):
			_raider_nodes.append(VoyageManager.nodes[rid])

	for id in VoyageManager.nodes:
		var n: NodeData = VoyageManager.nodes[id]
		if not _is_legend_visible(n):
			continue
		match n.node_type:
			EventManager.NodeType.SCAVENGE_SITE:
				if n.is_story_node:
					pass
				elif n.biome_type == BiomeConfig.BiomeType.ASTEROID:
					_asteroid_nodes.append(n)
				elif n.biome_type == BiomeConfig.BiomeType.PLANET:
					_planet_nodes.append(n)
			EventManager.NodeType.TRADING_OUTPOST:
				_outpost_nodes.append(n)
			EventManager.NodeType.WORMHOLE:
				_wormhole_nodes.append(n)


## Handle gui_input on each legend entry HBoxContainer.
func _on_entry_gui_input(event: InputEvent, entry_type: String) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	match entry_type:
		"story":
			_story_idx = (_story_idx + 1) % max(1, _story_nodes.size())
			_snap_to(_story_nodes, _story_idx)
		"raider":
			_raider_idx = (_raider_idx + 1) % max(1, _raider_nodes.size())
			_snap_to(_raider_nodes, _raider_idx)
		"asteroid":
			_asteroid_idx = (_asteroid_idx + 1) % max(1, _asteroid_nodes.size())
			_snap_to(_asteroid_nodes, _asteroid_idx)
		"planet":
			_planet_idx = (_planet_idx + 1) % max(1, _planet_nodes.size())
			_snap_to(_planet_nodes, _planet_idx)
		"outpost":
			_outpost_idx = (_outpost_idx + 1) % max(1, _outpost_nodes.size())
			_snap_to(_outpost_nodes, _outpost_idx)
		"wormhole":
			_wormhole_idx = (_wormhole_idx + 1) % max(1, _wormhole_nodes.size())
			_snap_to(_wormhole_nodes, _wormhole_idx)


## Ask the parent StarMap to instantly center the camera on the given node.
func _snap_to(nodes: Array[NodeData], idx: int) -> void:
	if nodes.is_empty():
		return
	var star_map = get_parent()
	if star_map and star_map.has_method("center_view_on_node"):
		star_map.center_view_on_node(nodes[idx])


## Returns true when a node should appear in the legend — i.e. it is not showing
## a question mark on the map. A node is visible when it has been seen before
## (state != UNVISITED) OR when it is directly reachable from the current position
## (adjacent in the graph, so the player can see its type).
func _is_legend_visible(n: NodeData) -> bool:
	if n.state != NodeData.NodeState.UNVISITED:
		return true
	var current = VoyageManager.get_current_node()
	return current != null and n.id in current.connections


func _set_tooltip_delay(control: Control) -> void:
	if control and "tooltip_delay_sec" in control:
		control.tooltip_delay_sec = TOOLTIP_DELAY
