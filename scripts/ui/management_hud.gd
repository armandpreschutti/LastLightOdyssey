extends Control
## Management HUD - Displays ship stats and provides jump controls
## Retro sci-fi terminal aesthetic with cyan/amber accents

signal quit_to_menu_pressed
signal view_recap_pressed
signal market_pressed
signal barracks_pressed
signal deploy_pressed

# Updated paths for new icon-based layout
@onready var cash_label: Label = $MarginContainer/VBoxContainer/StatsContainer/CashRow/CashLabel
@onready var fuel_label: Label = $MarginContainer/VBoxContainer/StatsContainer/FuelRow/FuelLabel
@onready var integrity_label: Label = $MarginContainer/VBoxContainer/StatsContainer/IntegrityRow/IntegrityLabel
@onready var scrap_label: Label = $MarginContainer/VBoxContainer/StatsContainer/ScrapRow/ScrapLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var market_button: Button = $MarginContainer/VBoxContainer/MarketButton
@onready var barracks_button: Button = $MarginContainer/VBoxContainer/BarracksButton
@onready var deploy_button: Button = $DeployPanel/DeployButton
@onready var quit_button: Button = $TopLeftPanel/QuitButton

var _pulse_tween: Tween

var _last_cash: int = 0
var _last_fuel: int = 0
var _last_integrity: int = 0
var _last_scrap: int = 0
var _last_intel: int = 0

var intel_label: Label


func _ready() -> void:
	# Store initial values to prevent animations on first update
	_last_cash = GameState.cash
	_last_fuel = GameState.fuel
	_last_integrity = GameState.ship_integrity
	_last_scrap = GameState.scrap
	_last_intel = GameState.intel
	
	_setup_additional_stats()
	_connect_signals()
	_update_all_stats()
	_update_glass_style()
	
	# Initial state: Hidden and inactive
	set_deploy_active(false)


func _update_glass_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.1, 0.6)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.9, 1.0, 0.3)
	sb.set_corner_radius_all(4)
	
	if has_node("TopLeftPanel"):
		$TopLeftPanel.add_theme_stylebox_override("panel", sb)
		
	if has_node("DeployPanel"):
		$DeployPanel.add_theme_stylebox_override("panel", sb)


func _connect_signals() -> void:
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.integrity_changed.connect(_on_integrity_changed)
	GameState.scrap_changed.connect(_on_scrap_changed)
	GameState.intel_changed.connect(_on_intel_changed)
	market_button.pressed.connect(_on_market_pressed)
	if barracks_button:
		barracks_button.pressed.connect(_on_barracks_pressed)
	deploy_button.pressed.connect(_on_deploy_pressed)
	deploy_button.mouse_entered.connect(_on_deploy_hover)
	deploy_button.mouse_exited.connect(_on_deploy_unhover)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_quit_pressed() -> void:
	# Save game before quitting to menu
	GameState.save_game()
	quit_to_menu_pressed.emit()


func _on_market_pressed() -> void:
	market_pressed.emit()


func _on_barracks_pressed() -> void:
	barracks_pressed.emit()


func _on_deploy_pressed() -> void:
	deploy_pressed.emit()


func _on_deploy_hover() -> void:
	# Stop pulse on hover and set to max glow for highlight
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	var glow_rect = deploy_button.get_node_or_null("GlowRect")
	if glow_rect:
		glow_rect.color.a = 0.8


func _on_deploy_unhover() -> void:
	# Resume pulse if button is active
	if not deploy_button.disabled:
		_start_pulse()


func set_deploy_active(active: bool) -> void:
	deploy_button.disabled = not active
	
	if has_node("DeployPanel"):
		$DeployPanel.visible = active
		
	if active:
		_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	var glow_rect = deploy_button.get_node_or_null("GlowRect")
	if not glow_rect:
		return
		
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(glow_rect, "color:a", 0.1, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(glow_rect, "color:a", 0.4, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	
	var glow_rect = deploy_button.get_node_or_null("GlowRect")
	if glow_rect:
		glow_rect.color.a = 0.0


## Programmatically add Intel and Data Logs rows to the stat container
func _setup_additional_stats() -> void:
	var stats_container = $MarginContainer/VBoxContainer/StatsContainer
	
	# Intel Row
	var intel_row = HBoxContainer.new()
	intel_row.name = "IntelRow"
	intel_row.add_theme_constant_override("separation", 10)
	stats_container.add_child(intel_row)
	
	var intel_icon = TextureRect.new()
	intel_icon.custom_minimum_size = Vector2(24, 24)
	intel_icon.texture = load("res://assets/sprites/ui/icons/icon_intel.png")
	intel_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intel_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intel_row.add_child(intel_icon)
	
	intel_label = Label.new()
	intel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0)) # Purple-ish
	intel_label.add_theme_font_size_override("font_size", 18)
	intel_row.add_child(intel_label)


## Spawns a floating text indicator next to a label to show resource changes
func _spawn_stat_change_indicator(target_node: Control, delta: int, is_percentage: bool = false) -> void:
	if delta == 0:
		return
		
	var indicator = Label.new()
	var prefix = "+" if delta > 0 else ""
	var suffix = "%" if is_percentage else ""
	indicator.text = prefix + str(delta) + suffix
	
	# User Request: Bigger and White
	indicator.modulate = Color.WHITE
	indicator.add_theme_font_size_override("font_size", 22)
	
	# Add to main HUD so it's on top and doesn't affect row layout
	add_child(indicator)
	
	# Position next to the actual text content rather than the container edge
	indicator.top_level = true
	
	var label_node = target_node as Label
	var text_width = 0.0
	if label_node:
		var font = label_node.get_theme_font("font")
		var font_size = label_node.get_theme_font_size("font_size")
		text_width = font.get_string_size(label_node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	else:
		text_width = target_node.size.x
		
	var start_pos = target_node.global_position + Vector2(text_width + 15, -5)
	start_pos.x += randf_range(-2, 2) # Minimal jitter
	indicator.global_position = start_pos
	
	# Add shadow for better readability
	indicator.add_theme_constant_override("shadow_offset_x", 1)
	indicator.add_theme_constant_override("shadow_offset_y", 1)
	indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	# Animate: Fade out in place
	var tween = create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.finished.connect(indicator.queue_free)



func _update_all_stats() -> void:
	_on_cash_changed(GameState.cash)
	_on_fuel_changed(GameState.fuel)
	_on_integrity_changed(GameState.ship_integrity)
	_on_scrap_changed(GameState.scrap)
	_on_intel_changed(GameState.intel)


func _on_cash_changed(new_value: int) -> void:
	var delta = new_value - _last_cash
	_spawn_stat_change_indicator(cash_label, delta)
	_last_cash = new_value
	cash_label.text = "CASH: %d" % new_value





func _on_fuel_changed(new_value: int) -> void:
	var delta = new_value - _last_fuel
	_spawn_stat_change_indicator(fuel_label, delta)
	_last_fuel = new_value
	fuel_label.text = "FUEL: %d" % new_value
	if new_value == 0:
		status_label.text = "[ DRIFT MODE - NO FUEL ]"
		status_label.visible = true
	else:
		status_label.visible = false


func _on_integrity_changed(new_value: int) -> void:
	var delta = new_value - _last_integrity
	_spawn_stat_change_indicator(integrity_label, delta, true)
	_last_integrity = new_value
	integrity_label.text = "HULL: %d%%" % new_value


func _on_scrap_changed(new_value: int) -> void:
	var delta = new_value - _last_scrap
	_spawn_stat_change_indicator(scrap_label, delta)
	_last_scrap = new_value
	scrap_label.text = "SCRAP: %d" % new_value


func _on_intel_changed(new_value: int) -> void:
	if not intel_label: return
	var delta = new_value - _last_intel
	_spawn_stat_change_indicator(intel_label, delta)
	_last_intel = new_value
	intel_label.text = "INTEL: %d" % new_value




func set_view_recap_mode(enabled: bool) -> void:
	# Disconnect existing connections to avoid duplicates/confusion
	if quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.disconnect(_on_quit_pressed)
	if quit_button.pressed.is_connected(_on_view_recap_pressed):
		quit_button.pressed.disconnect(_on_view_recap_pressed)
		
	if enabled:
		market_button.visible = false # Hide market in recap mode
		if barracks_button:
			barracks_button.visible = false
		if has_node("DeployPanel"):
			$DeployPanel.visible = false # Hide deploy panel in recap mode
		quit_button.text = "[ VIEW RECAP ]"
		quit_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
		quit_button.pressed.connect(_on_view_recap_pressed)
	else:
		market_button.visible = true
		if barracks_button:
			barracks_button.visible = true
		if has_node("DeployPanel"):
			$DeployPanel.visible = true
		quit_button.text = "[ QUIT TO MENU ]"
		quit_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Reddish
		quit_button.pressed.connect(_on_quit_pressed)


func _on_view_recap_pressed() -> void:
	view_recap_pressed.emit()
