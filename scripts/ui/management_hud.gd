extends Control
## Management HUD - Displays ship stats and provides jump controls
## Retro sci-fi terminal aesthetic with cyan/amber accents

signal quit_to_menu_pressed
signal view_recap_pressed
signal market_pressed

# Updated paths for new icon-based layout
@onready var cash_label: Label = $MarginContainer/VBoxContainer/StatsContainer/CashRow/CashLabel
@onready var intel_label: Label = $MarginContainer/VBoxContainer/StatsContainer/IntelRow/IntelLabel
@onready var data_logs_label: Label = $MarginContainer/VBoxContainer/StatsContainer/DataRow/DataLabel
@onready var fuel_label: Label = $MarginContainer/VBoxContainer/StatsContainer/FuelRow/FuelLabel
@onready var integrity_label: Label = $MarginContainer/VBoxContainer/StatsContainer/IntegrityRow/IntegrityLabel
@onready var scrap_label: Label = $MarginContainer/VBoxContainer/StatsContainer/ScrapRow/ScrapLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var market_button: Button = $MarginContainer/VBoxContainer/MarketButton
@onready var quit_button: Button = $TopLeftPanel/QuitButton


func _ready() -> void:
	_connect_signals()
	_update_all_stats()
	_update_glass_style()

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


func _connect_signals() -> void:
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.intel_changed.connect(_on_intel_changed)
	GameState.data_logs_changed.connect(_on_data_logs_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.integrity_changed.connect(_on_integrity_changed)
	GameState.scrap_changed.connect(_on_scrap_changed)
	market_button.pressed.connect(_on_market_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_quit_pressed() -> void:
	# Save game before quitting to menu
	GameState.save_game()
	quit_to_menu_pressed.emit()


func _on_market_pressed() -> void:
	market_pressed.emit()


func _update_all_stats() -> void:
	_on_cash_changed(GameState.cash)
	_on_intel_changed(GameState.intel)
	_on_data_logs_changed(GameState.data_logs)
	_on_fuel_changed(GameState.fuel)
	_on_integrity_changed(GameState.ship_integrity)
	_on_scrap_changed(GameState.scrap)


func _on_cash_changed(new_value: int) -> void:
	cash_label.text = "CASH: %d" % new_value


func _on_intel_changed(new_value: int) -> void:
	intel_label.text = "INTEL: %d" % new_value


func _on_data_logs_changed(new_value: int) -> void:
	data_logs_label.text = "DATA LOGS: %d" % new_value


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
		quit_button.text = "[ VIEW RECAP ]"
		quit_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
		quit_button.pressed.connect(_on_view_recap_pressed)
	else:
		market_button.visible = true
		quit_button.text = "[ QUIT TO MENU ]"
		quit_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Reddish
		quit_button.pressed.connect(_on_quit_pressed)


func _on_view_recap_pressed() -> void:
	view_recap_pressed.emit()
