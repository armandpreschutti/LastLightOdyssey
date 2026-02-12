extends SceneTree

func _init():
	var generator = load("res://scripts/management/star_map_generator.gd").new()
	var nodes = generator.generate()
	
	print("Generated node count: ", nodes.size())
	
	# Check what was considered New Earth before fix (index 49 if TOTAL_NODES was 50)
	var index_49_is_new_earth = generator.is_new_earth_node(49)
	print("Is index 49 New Earth? ", index_49_is_new_earth)
	
	# Check actual last node
	var last_index = nodes.size() - 1
	var last_is_new_earth = generator.is_new_earth_node(last_index)
	print("Is last index (", last_index, ") New Earth? ", last_is_new_earth)
	
	if nodes.size() != 50:
		print("MISMATCH: Generated ", nodes.size(), " but TOTAL_NODES was likely 50.")
	
	quit()
