extends Control
## Trading Dialog - Exchange scrap for fuel and repairs
## Terminal aesthetic menu for trading outpost nodes

signal trading_complete

# Updated paths for new icon-based layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesContainer/ScrapDisplay/ScrapLabel
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesContainer/FuelDisplay/FuelLabel
@onready var hull_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesContainer/HullDisplay/HullLabel
@onready var fuel_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/FuelTradeButton
@onready var repair_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/RepairTradeButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

const SCRAP_PER_FUEL: int = 10  # Scrap cost for fuel trade
const FUEL_PER_TRADE: int = 5  # Amount of fuel received per trade
const SCRAP_PER_REPAIR: int = 15
const REPAIR_AMOUNT: int = 10


func _ready() -> void:
	fuel_trade_button.pressed.connect(_on_fuel_trade_pressed)
	repair_trade_button.pressed.connect(_on_repair_trade_pressed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_trading() -> void:
	_update_display()
	status_label.text = ""
	visible = true
	AudioManager.play_sfx("ui_dialog_open")


func _update_display() -> void:
	# Update individual resource displays with icons
	scrap_label.text = "SCRAP: %d" % GameState.scrap
	fuel_label.text = "FUEL: %d" % GameState.fuel
	hull_label.text = "HULL: %d%%" % GameState.ship_integrity
	
	# Update trade button availability
	var can_buy_fuel = GameState.scrap >= SCRAP_PER_FUEL
	var can_buy_repair = GameState.scrap >= SCRAP_PER_REPAIR and GameState.ship_integrity < 100
	
	fuel_trade_button.disabled = not can_buy_fuel
	repair_trade_button.disabled = not can_buy_repair
	
	# Update button text
	fuel_trade_button.text = "[ BUY %d FUEL CELLS: %d SCRAP ]" % [FUEL_PER_TRADE, SCRAP_PER_FUEL]
	repair_trade_button.text = "[ REPAIR HULL +%d%%: %d SCRAP ]" % [REPAIR_AMOUNT, SCRAP_PER_REPAIR]


func _on_fuel_trade_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if GameState.scrap >= SCRAP_PER_FUEL:
		GameState.scrap -= SCRAP_PER_FUEL
		GameState.fuel += FUEL_PER_TRADE
		status_label.text = "FUEL PURCHASED: +%d" % FUEL_PER_TRADE
		_update_display()


func _on_repair_trade_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if GameState.scrap >= SCRAP_PER_REPAIR and GameState.ship_integrity < 100:
		GameState.scrap -= SCRAP_PER_REPAIR
		GameState.repair_ship(REPAIR_AMOUNT)
		status_label.text = "HULL REPAIRED: +%d%%" % REPAIR_AMOUNT
		_update_display()


func _on_close_pressed() -> void:
	AudioManager.play_sfx("ui_dialog_close")
	visible = false
	trading_complete.emit()
