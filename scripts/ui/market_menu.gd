extends Control
## Market Menu - Allows player to buy resources and repair ship
## Accessed via the Management HUD

signal closed

@onready var cash_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/CashLabel
@onready var fuel_price_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GridContainer/FuelPrice
@onready var repair_price_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GridContainer/RepairPrice

@onready var buy_fuel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/GridContainer/BuyFuelButton
@onready var repair_hull_button: Button = $PanelContainer/MarginContainer/VBoxContainer/GridContainer/RepairHullButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

# Base prices
const FUEL_PRICE: int = 5
const REPAIR_PRICE: int = 50
const REPAIR_AMOUNT: int = 25

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	if buy_fuel_button:
		buy_fuel_button.pressed.connect(_on_buy_fuel_pressed)
	
	if repair_hull_button:
		repair_hull_button.pressed.connect(_on_repair_hull_pressed)
	
	setup_prices()
	update_ui()
	
	# Listen for cash changes to update button states
	GameState.cash_changed.connect(func(_new_val): update_ui())


func setup_prices() -> void:
	if fuel_price_label:
		fuel_price_label.text = "%d CR" % FUEL_PRICE
	if repair_price_label:
		repair_price_label.text = "%d CR" % REPAIR_PRICE


func update_ui() -> void:
	if cash_label:
		cash_label.text = "CREDITS: %d CR" % GameState.cash
	
	# Update button states based on affordability
	if buy_fuel_button:
		buy_fuel_button.disabled = GameState.cash < FUEL_PRICE or GameState.fuel >= GameState.MAX_FUEL
	
	if repair_hull_button:
		# Can't repair if full health or not enough cash
		repair_hull_button.disabled = GameState.cash < REPAIR_PRICE or GameState.ship_integrity >= 100


func _on_buy_fuel_pressed() -> void:
	if GameState.cash >= FUEL_PRICE and GameState.fuel < GameState.MAX_FUEL:
		GameState.cash -= FUEL_PRICE
		GameState.fuel += 1
		if SFXManager:
			SFXManager.play_sfx_by_name("ui", "buy")




func _on_repair_hull_pressed() -> void:
	if GameState.cash >= REPAIR_PRICE and GameState.ship_integrity < 100:
		GameState.cash -= REPAIR_PRICE
		GameState.repair_ship(REPAIR_AMOUNT)
		if SFXManager:
			SFXManager.play_sfx_by_name("ui", "repair")


func _on_close_pressed() -> void:
	if SFXManager:
		SFXManager.play_sfx_by_name("ui", "click")
	closed.emit()
	queue_free()
