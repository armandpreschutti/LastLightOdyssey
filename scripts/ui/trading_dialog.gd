extends Control
## Trading Dialog - Exchange cash for fuel and repairs
## Terminal aesthetic menu for trading outpost nodes

signal trading_complete

# Updated paths for new icon-based layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesContainer/FuelDisplay/FuelLabel
@onready var hull_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesContainer/HullDisplay/HullLabel
@onready var fuel_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/FuelTradeButton
@onready var repair_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/RepairTradeButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

const CASH_PER_FUEL: int = 10  # Reduced cost vs Market (15)
const FUEL_PER_TRADE: int = 5
const CASH_PER_REPAIR: int = 35 # Reduced cost vs Market (50)
const REPAIR_AMOUNT: int = 15   # Better repair value (25% in market costs 50)


func _ready() -> void:
	fuel_trade_button.pressed.connect(_on_fuel_trade_pressed)
	repair_trade_button.pressed.connect(_on_repair_trade_pressed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_trading() -> void:
	_update_display()
	status_label.text = ""
	visible = true


func _update_display() -> void:
	# Update individual resource displays with icons
	fuel_label.text = "FUEL: %d" % GameState.fuel
	hull_label.text = "HULL: %d%%" % GameState.ship_integrity
	
	# Update trade button availability
	var can_buy_fuel = GameState.cash >= CASH_PER_FUEL
	var can_buy_repair = GameState.cash >= CASH_PER_REPAIR and GameState.ship_integrity < 100
	
	fuel_trade_button.disabled = not can_buy_fuel
	repair_trade_button.disabled = not can_buy_repair
	
	# Update button text
	fuel_trade_button.text = "[ BUY %d FUEL CELLS: %d CR ]" % [FUEL_PER_TRADE, CASH_PER_FUEL]
	repair_trade_button.text = "[ REPAIR HULL +%d%%: %d CR ]" % [REPAIR_AMOUNT, CASH_PER_REPAIR]


func _on_fuel_trade_pressed() -> void:
	if GameState.cash >= CASH_PER_FUEL:
		GameState.cash -= CASH_PER_FUEL
		GameState.fuel += FUEL_PER_TRADE
		status_label.text = "FUEL PURCHASED: +%d" % FUEL_PER_TRADE
		_update_display()


func _on_repair_trade_pressed() -> void:
	if GameState.cash >= CASH_PER_REPAIR and GameState.ship_integrity < 100:
		GameState.cash -= CASH_PER_REPAIR
		GameState.repair_ship(REPAIR_AMOUNT)
		status_label.text = "HULL REPAIRED: +%d%%" % REPAIR_AMOUNT
		_update_display()


func _on_close_pressed() -> void:
	visible = false
	if SFXManager:
		SFXManager.stop_scene_sfx()
	trading_complete.emit()
