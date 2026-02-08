extends Node
## Standalone script to generate mining equipment sprite
## Attach to a node and run, or use as EditorScript

func _ready() -> void:
	generate_mining_sprite()

func generate_mining_sprite() -> void:
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
	var tech_accent = Color(0.2, 0.8, 1.0, 1.0)  # Cyan tech accent
	
	# Draw base platform (bottom, wider)
	for x in range(6, 26):
		for y in range(22, 28):
			image.set_pixel(x, y, base_color)
	
	# Draw main body (center column, taller)
	for x in range(12, 20):
		for y in range(10, 22):
			image.set_pixel(x, y, accent_color)
	
	# Draw drill bit assembly (top, pointing down)
	# Drill housing
	for x in range(13, 19):
		for y in range(6, 10):
			image.set_pixel(x, y, accent_color)
	# Drill bit itself
	for x in range(14, 18):
		for y in range(4, 8):
			image.set_pixel(x, y, drill_color)
	# Drill tip
	for x in range(15, 17):
		for y in range(2, 4):
			image.set_pixel(x, y, drill_color)
	
	# Draw side supports/legs
	for x in range(8, 12):
		for y in range(14, 22):
			image.set_pixel(x, y, base_color)
	for x in range(20, 24):
		for y in range(14, 22):
			image.set_pixel(x, y, base_color)
	
	# Add highlights for depth and 3D effect
	for x in range(12, 20):
		image.set_pixel(x, 10, highlight_color)  # Top of main body
	for x in range(6, 26):
		image.set_pixel(x, 22, highlight_color)  # Top of base
	
	# Add control panel/details (small tech indicators)
	image.set_pixel(9, 16, tech_accent)
	image.set_pixel(22, 16, tech_accent)
	image.set_pixel(10, 17, tech_accent)
	image.set_pixel(21, 17, tech_accent)
	
	# Add some blue/cyan accent lines for tech look
	for x in range(13, 19):
		if x % 2 == 0:  # Every other pixel for pattern
			image.set_pixel(x, 7, tech_accent)
	
	# Add shadow/depth to base
	for x in range(7, 25):
		image.set_pixel(x, 27, Color(0.1, 0.1, 0.15, 1.0))
	
	# Save the image
	var save_path = "res://assets/sprites/objects/mining_equipment.png"
	var error = image.save_png(save_path)
	if error == OK:
		print("Mining equipment sprite generated successfully at: ", save_path)
	else:
		print("Error saving sprite: ", error)
