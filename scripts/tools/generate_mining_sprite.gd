@tool
extends EditorScript
## Tool script to generate mining equipment sprite
## Run this from Script > Run in the Godot editor

func _run() -> void:
	# Create a 32x32 image (matching tile size)
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Fill with transparent background
	image.fill(Color(0, 0, 0, 0))
	
	# Draw mining equipment - industrial drill/equipment design
	# Base structure (dark gray/steel)
	var base_color = Color(0.3, 0.3, 0.35, 1.0)
	var accent_color = Color(0.5, 0.5, 0.6, 1.0)
	var highlight_color = Color(0.7, 0.7, 0.8, 1.0)
	var drill_color = Color(0.4, 0.35, 0.3, 1.0)  # Brownish drill bit
	
	# Draw base platform (bottom)
	for x in range(8, 24):
		for y in range(20, 28):
			image.set_pixel(x, y, base_color)
	
	# Draw main body (center column)
	for x in range(12, 20):
		for y in range(8, 20):
			image.set_pixel(x, y, accent_color)
	
	# Draw drill bit (top, pointing down)
	for x in range(14, 18):
		for y in range(4, 10):
			image.set_pixel(x, y, drill_color)
	# Drill tip
	for x in range(15, 17):
		for y in range(2, 4):
			image.set_pixel(x, y, drill_color)
	
	# Draw side supports
	for x in range(10, 12):
		for y in range(12, 18):
			image.set_pixel(x, y, base_color)
	for x in range(20, 22):
		for y in range(12, 18):
			image.set_pixel(x, y, base_color)
	
	# Add highlights for depth
	for x in range(12, 20):
		image.set_pixel(x, 8, highlight_color)
	for x in range(8, 24):
		image.set_pixel(x, 20, highlight_color)
	
	# Add control panel/details (small squares)
	image.set_pixel(10, 14, highlight_color)
	image.set_pixel(21, 14, highlight_color)
	
	# Add some blue/cyan accent for tech look (matching the highlight color in scene)
	for x in range(13, 19):
		image.set_pixel(x, 6, Color(0.2, 0.8, 1.0, 1.0))
	
	# Save the image
	var save_path = "res://assets/sprites/objects/mining_equipment.png"
	image.save_png(save_path)
	print("Mining equipment sprite generated at: ", save_path)
	
	# Force resource reload
	EditorInterface.get_resource_filesystem().update_file(save_path)
