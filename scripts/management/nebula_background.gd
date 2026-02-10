extends Control
## Procedurally generated nebula background for star map
## Creates animated space clouds with subtle drift animation

# Nebula cloud data structure
class NebulaCloud:
	var position: Vector2
	var size: float
	var color: Color
	var velocity: Vector2  # Pixels per second
	var circles: Array[Dictionary]  # Array of {pos_offset: Vector2, radius: float} for organic shape
	
	func _init(p_pos: Vector2, p_size: float, p_color: Color, p_velocity: Vector2) -> void:
		position = p_pos
		size = p_size
		color = p_color
		velocity = p_velocity
		circles = []

var nebula_clouds: Array[NebulaCloud] = []
var rng: RandomNumberGenerator

# Color palette for nebula clouds (darker, less bright)
const COLOR_DEEP_BLUE = Color(0.12, 0.25, 0.35, 0.06)
const COLOR_PURPLE = Color(0.18, 0.12, 0.3, 0.07)
const COLOR_CYAN = Color(0.12, 0.35, 0.45, 0.08)
const COLOR_BLUE_PURPLE = Color(0.15, 0.18, 0.33, 0.06)

const CLOUD_COLORS = [COLOR_DEEP_BLUE, COLOR_PURPLE, COLOR_CYAN, COLOR_BLUE_PURPLE]

# Star data structure
class Star:
	var position: Vector2
	var size: float
	var base_brightness: float
	var twinkle_phase: float  # For animation
	var twinkle_speed: float
	
	func _init(p_pos: Vector2, p_size: float, p_brightness: float) -> void:
		position = p_pos
		size = p_size
		base_brightness = p_brightness
		twinkle_phase = randf() * TAU  # Random starting phase
		twinkle_speed = randf_range(0.5, 2.0)  # Different twinkle speeds

var stars: Array[Star] = []

# Generation parameters
const NUM_CLOUDS = 20
const MIN_CLOUD_SIZE = 200.0
const MAX_CLOUD_SIZE = 600.0
const MIN_VELOCITY = 5.0  # pixels per second
const MAX_VELOCITY_H = 12.0  # horizontal
const MAX_VELOCITY_V = 6.0  # vertical
const CIRCLES_PER_CLOUD = 4  # Number of overlapping circles per cloud

# Star parameters
const NUM_STARS = 150
const MIN_STAR_SIZE = 1.0
const MAX_STAR_SIZE = 2.5
const MIN_STAR_BRIGHTNESS = 0.3
const MAX_STAR_BRIGHTNESS = 0.8
const TWINKLE_INTENSITY = 0.4  # How much stars vary in brightness


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng = RandomNumberGenerator.new()
	rng.randomize()
	# Wait for size to be set before generating
	call_deferred("_generate_nebula_clouds")
	call_deferred("_generate_stars")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Regenerate clouds and stars when size changes significantly
		if (nebula_clouds.is_empty() and stars.is_empty()) or (size.x > 0 and size.y > 0):
			call_deferred("_generate_nebula_clouds")
			call_deferred("_generate_stars")


## Generate all nebula clouds procedurally
func _generate_nebula_clouds() -> void:
	nebula_clouds.clear()
	
	# Get the size of the control (will be set by parent)
	var map_size = size
	if map_size.x <= 0 or map_size.y <= 0:
		# Default size if not set yet
		map_size = Vector2(1280, 720)
	
	# Generate clouds distributed across the map
	for i in range(NUM_CLOUDS):
		# Random position across the map (extend beyond edges for seamless wrapping)
		var cloud_pos = Vector2(
			rng.randf_range(-200, map_size.x + 200),
			rng.randf_range(-200, map_size.y + 200)
		)
		
		# Random size
		var cloud_size = rng.randf_range(MIN_CLOUD_SIZE, MAX_CLOUD_SIZE)
		
		# Random color from palette
		var cloud_color = CLOUD_COLORS[rng.randi() % CLOUD_COLORS.size()]
		
		# Random velocity (horizontal faster than vertical)
		var cloud_velocity = Vector2(
			rng.randf_range(MIN_VELOCITY, MAX_VELOCITY_H),
			rng.randf_range(MIN_VELOCITY * 0.5, MAX_VELOCITY_V)
		)
		
		# Create cloud
		var cloud = NebulaCloud.new(cloud_pos, cloud_size, cloud_color, cloud_velocity)
		
		# Generate overlapping circles for organic nebula shape
		for j in range(CIRCLES_PER_CLOUD):
			var circle_offset = Vector2(
				rng.randf_range(-cloud_size * 0.3, cloud_size * 0.3),
				rng.randf_range(-cloud_size * 0.3, cloud_size * 0.3)
			)
			var circle_radius = cloud_size * rng.randf_range(0.4, 0.7)
			cloud.circles.append({
				"offset": circle_offset,
				"radius": circle_radius
			})
		
		nebula_clouds.append(cloud)
	
	# Request redraw
	queue_redraw()


## Generate twinkling stars
func _generate_stars() -> void:
	stars.clear()
	
	var map_size = size
	if map_size.x <= 0 or map_size.y <= 0:
		# Default size if not set yet
		map_size = Vector2(1280, 720)
	
	# Generate stars distributed across the map
	for i in range(NUM_STARS):
		var star_pos = Vector2(
			rng.randf_range(0, map_size.x),
			rng.randf_range(0, map_size.y)
		)
		var star_size = rng.randf_range(MIN_STAR_SIZE, MAX_STAR_SIZE)
		var star_brightness = rng.randf_range(MIN_STAR_BRIGHTNESS, MAX_STAR_BRIGHTNESS)
		
		var star = Star.new(star_pos, star_size, star_brightness)
		stars.append(star)
	
	queue_redraw()


## Update cloud positions and star twinkling for animation
func _process(delta: float) -> void:
	var map_size = size
	if map_size.x <= 0 or map_size.y <= 0:
		return
	
	# Update each cloud's position
	for cloud in nebula_clouds:
		cloud.position += cloud.velocity * delta
		
		# Wrap around edges for seamless scrolling
		if cloud.position.x < -400:
			cloud.position.x += map_size.x + 800
		elif cloud.position.x > map_size.x + 400:
			cloud.position.x -= map_size.x + 800
		
		if cloud.position.y < -400:
			cloud.position.y += map_size.y + 800
		elif cloud.position.y > map_size.y + 400:
			cloud.position.y -= map_size.y + 800
	
	# Update star twinkling
	for star in stars:
		star.twinkle_phase += star.twinkle_speed * delta
		# Keep phase in reasonable range
		if star.twinkle_phase > TAU * 10:
			star.twinkle_phase -= TAU * 10
	
	# Request redraw for animation
	queue_redraw()


## Draw the nebula clouds and twinkling stars
func _draw() -> void:
	# Draw each cloud using overlapping circles
	for cloud in nebula_clouds:
		# Draw each circle in the cloud
		for circle_data in cloud.circles:
			var circle_pos = cloud.position + circle_data.offset
			var circle_radius = circle_data.radius
			
			# Draw the circle with the cloud's color
			draw_circle(circle_pos, circle_radius, cloud.color)
			
			# Add a subtle outer glow (lighter, more transparent)
			var glow_color = cloud.color
			glow_color.a *= 0.5
			draw_circle(circle_pos, circle_radius * 1.2, glow_color)
	
	# Draw twinkling stars
	var star_color = Color(0.9, 0.95, 1.0, 1.0)  # Slightly warm white
	for star in stars:
		# Calculate twinkling brightness using sine wave
		var twinkle_factor = sin(star.twinkle_phase) * TWINKLE_INTENSITY
		var current_brightness = star.base_brightness + twinkle_factor
		current_brightness = clamp(current_brightness, 0.1, 1.0)
		
		# Apply brightness to star color
		var final_color = star_color
		final_color.a = current_brightness
		
		# Draw star as a small circle
		draw_circle(star.position, star.size, final_color)
		
		# Add a subtle glow for larger/brighter stars
		if star.size > 2.0 and current_brightness > 0.6:
			var glow_color = final_color
			glow_color.a *= 0.3
			draw_circle(star.position, star.size * 1.5, glow_color)


## Regenerate clouds and stars (useful if map size changes significantly)
func regenerate() -> void:
	_generate_nebula_clouds()
	_generate_stars()
