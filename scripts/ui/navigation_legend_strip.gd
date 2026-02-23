extends MarginContainer
## Compact navigation legend strip. Updates dynamically based on node types
## present in the current voyage. Shows icon + count; hides entries with zero count.
## Styling matches Ship Status (cyan accents).

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
@onready var wormhole_entry: HBoxContainer = $PanelContainer/HBoxContainer/WormholeEntry
@onready var wormhole_count_label: Label = $PanelContainer/HBoxContainer/WormholeEntry/WormholeCountLabel


func _ready() -> void:
	_set_tooltip_delay(story_entry.get_node("StoryIcon"))
	_set_tooltip_delay(raider_entry.get_node("RaiderIcon"))
	_set_tooltip_delay(asteroid_entry.get_node("AsteroidIcon"))
	_set_tooltip_delay(planet_entry.get_node("PlanetIcon"))
	_set_tooltip_delay(wormhole_entry.get_node("WormholeIcon"))

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
	var raider_count := 1 if VoyageManager.is_raider_active else 0
	raider_entry.visible = raider_count > 0
	if raider_count > 0:
		raider_count_label.text = str(raider_count)

	# Asteroid (SCAVENGE_SITE with ASTEROID biome; exclude story - they use story_signal)
	var asteroid_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if n.node_type == EventManager.NodeType.SCAVENGE_SITE and not n.is_story_node:
			if n.biome_type == BiomeConfig.BiomeType.ASTEROID:
				asteroid_count += 1

	asteroid_entry.visible = asteroid_count > 0
	if asteroid_count > 0:
		asteroid_count_label.text = str(asteroid_count)

	# Planet (SCAVENGE_SITE with PLANET biome + TRADING_OUTPOST; exclude story)
	var planet_count := 0
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if n.node_type == EventManager.NodeType.TRADING_OUTPOST:
			planet_count += 1
		elif n.node_type == EventManager.NodeType.SCAVENGE_SITE and not n.is_story_node:
			if n.biome_type == BiomeConfig.BiomeType.PLANET:
				planet_count += 1

	planet_entry.visible = planet_count > 0
	if planet_count > 0:
		planet_count_label.text = str(planet_count)

	# Wormhole (WORMHOLE node type)
	var wormhole_count := 0
	for id in VoyageManager.nodes:
		if VoyageManager.nodes[id].node_type == EventManager.NodeType.WORMHOLE:
			wormhole_count += 1

	wormhole_entry.visible = wormhole_count > 0
	if wormhole_count > 0:
		wormhole_count_label.text = str(wormhole_count)


func _set_tooltip_delay(control: Control) -> void:
	if control and "tooltip_delay_sec" in control:
		control.tooltip_delay_sec = TOOLTIP_DELAY
