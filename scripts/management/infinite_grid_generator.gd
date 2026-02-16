class_name InfiniteGridGenerator
extends RefCounted

## Procedurally generates map nodes based on grid coordinates
## Uses deterministic RNG based on position hash

const NOISE_SEED = 12345 # Base seed for generation

## Generate a node at the specific grid position
func generate_node(grid_pos: Vector2) -> NodeData:
	var rng = _get_rng_for_position(grid_pos)
	
	var node = NodeData.new(grid_pos)
	
	# Roll Node Type
	node.node_type = _roll_node_type(rng)
	
	# Roll Biome if Scavenge Site
	if node.node_type == EventManager.NodeType.SCAVENGE_SITE:
		node.biome_type = _roll_biome_type(rng)
	
	return node

## Create a deterministic RNG state for a given coordinate
func _get_rng_for_position(pos: Vector2) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	# Create a unique seed based on position and base seed
	# Use a hash function to mix x/y widely
	var x_hash = int(pos.x) * 73856093
	var y_hash = int(pos.y) * 19349663
	var combined = (x_hash ^ y_hash) * 83492791
	rng.seed = combined + NOISE_SEED
	return rng

## Roll node type based on weightings
## 40% Scavenge, 40% Empty, 20% Reserved (currently Empty or Event)
func _roll_node_type(rng: RandomNumberGenerator) -> int:
	var roll = rng.randf()
	
	if roll < 0.40:
		return EventManager.NodeType.SCAVENGE_SITE
	elif roll < 0.80:
		return EventManager.NodeType.EMPTY_SPACE
	else:
		# Reserved/Event/Special
		# For now, treat as Empty or potentially Wormhole
		if rng.randf() < 0.1: # Small chance for Wormhole in the "reserved" bucket
			return EventManager.NodeType.WORMHOLE
		return EventManager.NodeType.EMPTY_SPACE

## Roll biome type for scavenge sites
func _roll_biome_type(rng: RandomNumberGenerator) -> int:
	# Uniform distribution for now
	var biomes = [
		BiomeConfig.BiomeType.STATION,
		BiomeConfig.BiomeType.ASTEROID,
		BiomeConfig.BiomeType.PLANET
	]
	return biomes[rng.randi() % biomes.size()]
