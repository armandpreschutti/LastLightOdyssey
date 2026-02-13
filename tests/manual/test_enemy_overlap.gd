extends SceneTree

func _init():
	print("Starting enemy overlap test...")
	
	# Load scripts
	var tactical_map_script = load("res://scripts/tactical/tactical_map.gd")
	var enemy_ai_script = load("res://scripts/tactical/enemy_ai.gd")
	
	# Create TacticalMap instance
	var tactical_map = tactical_map_script.new()
	
	# Mock child containers
	var units_container = Node2D.new()
	units_container.name = "Units"
	tactical_map.add_child(units_container)
	
	var interactables_container = Node2D.new()
	interactables_container.name = "Interactables"
	tactical_map.add_child(interactables_container)
	
	# Add to scene tree to initialize
	root.add_child(tactical_map)
	
	# Configure map
	tactical_map.map_width = 10
	tactical_map.map_height = 10
	tactical_map._setup_astar()
	
	# Set up tile data (all floor)
	var layout = {}
	for x in range(10):
		for y in range(10):
			layout[Vector2i(x, y)] = 0 # TileType.FLOOR
	tactical_map.tile_data = layout
	tactical_map._update_astar_solids()
	
	# Create Unit 1 (The Mover)
	var unit1 = Node2D.new()
	unit1.set_script(GDScript.new())
	unit1.script.source_code = "extends Node2D\nvar grid_pos: Vector2i\nfunc get_grid_position(): return grid_pos\nfunc set_grid_position(pos): grid_pos = pos\nfunc get(prop): return null"
	unit1.script.reload()
	unit1.set_grid_position(Vector2i(5, 5))
	tactical_map.add_unit(unit1, Vector2i(5, 5))
	
	# Create Unit 2 (The Blocker)
	var unit2 = Node2D.new()
	unit2.set_script(unit1.script) # Reuse script
	unit2.set_grid_position(Vector2i(5, 6)) # Adjacent to (5,5)
	tactical_map.add_unit(unit2, Vector2i(5, 6))
	
	print("Unit 1 at (5, 5)")
	print("Unit 2 at (5, 6)")
	
	# Test reachable positions
	# Range 1 from (5,5) should include (5,4), (4,5), (6,5) but NOT (5,6)
	var reachable = enemy_ai_script._get_reachable_positions(Vector2i(5, 5), 1, tactical_map)
	
	print("Reachable positions: ", reachable)
	
	var passed = true
	var found_blocker = false
	var found_empty = false
	
	for pos in reachable:
		if pos == Vector2i(5, 6):
			found_blocker = true
		if pos == Vector2i(5, 4):
			found_empty = true
	
	if found_blocker:
		print("FAIL: Occupied tile (5, 6) was found in reachable positions!")
		passed = false
	else:
		print("PASS: Occupied tile (5, 6) correctly excluded.")
		
	if found_empty:
		print("PASS: Empty tile (5, 4) found in reachable positions.")
	else:
		print("FAIL: Empty tile (5, 4) NOT found in reachable positions!")
		passed = false
		
	if passed:
		print("TEST PASSED")
	else:
		print("TEST FAILED")
	
	quit()
