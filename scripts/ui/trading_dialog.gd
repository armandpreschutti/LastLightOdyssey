extends Control
## Trading Dialog - Exchange scrap for fuel and repairs
## Terminal aesthetic menu for trading outpost nodes

signal trading_complete

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var resources_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResourcesLabel
@onready var fuel_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/FuelTradeButton
@onready var repair_trade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TradesContainer/RepairTradeButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

const SCRAP_PER_FUEL: int = 10
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


func _update_display() -> void:
	# Update resource display
	resources_label.text = "CURRENT RESOURCES:\nSCRAP: %d\nFUEL: %d\nHULL: %d%%" % [
		GameState.scrap,
		GameState.fuel,
		GameState.ship_integrity
	]
	
	# Update trade button availability
	var can_buy_fuel = GameState.scrap >= SCRAP_PER_FUEL
	var can_buy_repair = GameState.scrap >= SCRAP_PER_REPAIR and GameState.ship_integrity < 100
	
	fuel_trade_button.disabled = not can_buy_fuel
	repair_trade_button.disabled = not can_buy_repair
	
	# Update button text
	fuel_trade_button.text = "[ BUY FUEL: %d SCRAP ]" % SCRAP_PER_FUEL
	repair_trade_button.text = "[ REPAIR HULL: %d SCRAP ]" % SCRAP_PER_REPAIR


func _on_fuel_trade_pressed() -> void:
	if GameState.scrap >= SCRAP_PER_FUEL:
		GameState.scrap -= SCRAP_PER_FUEL
		GameState.fuel += 1
		status_label.text = "FUEL PURCHASED: +1"
		_update_display()


func _on_repair_trade_pressed() -> void:
	if GameState.scrap >= SCRAP_PER_REPAIR and GameState.ship_integrity < 100:
		GameState.scrap -= SCRAP_PER_REPAIR
		GameState.repair_ship(REPAIR_AMOUNT)
		status_label.text = "HULL REPAIRED: +%d%%" % REPAIR_AMOUNT
		_update_display()


func _on_close_pressed() -> void:
	visible = false
	trading_complete.emit()
