extends Node

func _ready() -> void:
	print("Starting Story Spawn Verification...")
	# Wait for autoloads to initialize
	await get_tree().create_timer(0.5).timeout
	
	# 1. Setup State
	print("Setting up game state...")
	GameState.intel = 3
	GameState.story_chapters_completed = 0
	VoyageManager.pending_branch_choice = "1A"
	
	# Clean up any existing story nodes from previous runs or initialization
	if VoyageManager.active_story_node_id != "" and VoyageManager.nodes.has(VoyageManager.active_story_node_id):
		var old_node = VoyageManager.nodes[VoyageManager.active_story_node_id]
		old_node.state = NodeData.NodeState.CLEARED
		print("Cleared existing story node: ", VoyageManager.active_story_node_id)
		
	VoyageManager.active_story_node_id = ""

	# 2. Trigger Spawn
	print("Triggering story node spawn...")
	VoyageManager._try_spawn_story_node()
	
	# 3. Verify
	var story_node: NodeData = null
	for id in VoyageManager.nodes:
		var n = VoyageManager.nodes[id]
		if n.state == NodeData.NodeState.STORY:
			story_node = n
			break
			
	if story_node:
		print("✅ PASS: Story node spawned with ID: ", story_node.id)
		
		var current = VoyageManager.get_current_node()
		var dist = current.position.distance_to(story_node.position)
		print("Distance from current node: ", dist)
		
		if dist >= 1200.0 and dist <= 1500.0:
			print("✅ PASS: Distance is within range (1200-1500): ", dist)
		else:
			print("❌ FAIL: Distance is ", dist, " (Expected 1200-1500)")
			
		# Check connections
		print("Connections: ", story_node.connections)
		if story_node.connections.is_empty():
			print("ℹ️ Info: No immediate connections (Expected if > 450 units from any node)")
		else:
			print("ℹ️ Info: Node connected to ", story_node.connections.size(), " neighbors (Proximity connection working)")
			
	else:
		print("❌ FAIL: No story node spawned.")
		print("GameState Intel: ", GameState.intel)
		print("Chapters Completed: ", GameState.story_chapters_completed)
		print("Pending Branch: ", VoyageManager.pending_branch_choice)
		
	print("Verification Complete.")
	get_tree().quit()
