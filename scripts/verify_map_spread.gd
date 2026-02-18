extends Node

func _ready():
	print("Starting Map Spread Verification...")
	
	# Instantiate the generator
	var generator = ProgressiveMapGenerator.new()
	
	# Create a dummy start node
	# NodeData constructor: _init(p_id, p_pos, p_type)
	# EventManager.NodeType.EMPTY_SPACE is 0
	var start_node = NodeData.new("start_node", Vector2.ZERO, 0)
	
	# Define incoming direction (Right = 0 degrees)
	var direction = Vector2.RIGHT 
	
	print("Generating 100 iterations of options...")
	var min_angle = 180.0
	var max_angle = -180.0
	var fail_count = 0
	var nodes_generated = 0
	
	for i in range(100):
		# generate_options(source_node, incoming_vector, override_count, ignore_direction, existing_nodes)
		var nodes = generator.generate_options(start_node, direction, 1, false, {})
		
		if nodes.size() == 0:
			print("Iteration %d produced 0 nodes." % i)
			continue
			
		nodes_generated += 1
		var new_node = nodes[0]
		var offset = new_node.position - start_node.position
		var angle = direction.angle_to(offset)
		var angle_deg = rad_to_deg(angle)
		
		min_angle = min(min_angle, angle_deg)
		max_angle = max(max_angle, angle_deg)
		
		# Check if within expected range (+/- 70 degrees for 140 spread)
		# Allow small margin for floating point errors (e.g. 71)
		if abs(angle_deg) > 71.0:
			print("FAILURE: Angle %f is outside expected spread!" % angle_deg)
			fail_count += 1
			
	print("Verification Complete. Generated %d nodes." % nodes_generated)
	print("Min Angle: %f" % min_angle)
	print("Max Angle: %f" % max_angle)
	
	if fail_count == 0 and abs(min_angle) > 30 and abs(max_angle) > 30:
		print("SUCCESS: Spread looks correct (within +/- 70 degrees).")
	elif fail_count > 0:
		print("FAILURE: %d nodes outside range." % fail_count)
	else:
		print("WARNING: Spread might be too narrow? Min/Max: %f / %f" % [min_angle, max_angle])
		
	get_tree().quit()
