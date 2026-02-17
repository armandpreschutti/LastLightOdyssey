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

func _ready() -> void:
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



func _update_all_stats() -> void:
	_on_cash_changed(GameState.cash)
	_on_fuel_changed(GameState.fuel)
	_on_integrity_changed(GameState.ship_integrity)
	_on_scrap_changed(GameState.scrap)


func _on_cash_changed(new_value: int) -> void:
	cash_label.text = "CASH: %d" % new_value





func _on_fuel_changed(new_value: int) -> void:
	fuel_label.text = "FUEL CELLS: %d" % new_value
	if new_value == 0:
		status_label.text = "[ DRIFT MODE - NO FUEL ]"
		status_label.visible = true
	else:
		status_label.visible = false


func _on_integrity_changed(new_value: int) -> void:
	integrity_label.text = "HULL INTEGRITY: %d%%" % new_value


func _on_scrap_changed(new_value: int) -> void:
	scrap_label.text = "SCRAP: %d" % new_value


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
