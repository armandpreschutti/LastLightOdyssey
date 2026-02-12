extends Control

## Trading Terminal - Allows buying fuel and repairs in the Navigation System
## integrated into the main navigation view

# Configuration
const SCRAP_COST_FUEL: int = 10
const FUEL_AMOUNT: int = 5
const SCRAP_COST_REPAIR: int = 15
const REPAIR_AMOUNT: int = 10

# UI Components
@onready var buy_fuel_button: Button = %BuyFuelButton
@onready var repair_hull_button: Button = %RepairHullButton
@onready var fuel_cost_label: Label = %FuelCostLabel
@onready var repair_cost_label: Label = %RepairCostLabel
@onready var status_message: Label = %StatusMessage

func _ready() -> void:
	# Connect signals
	buy_fuel_button.pressed.connect(_on_buy_fuel_pressed)
	repair_hull_button.pressed.connect(_on_repair_hull_pressed)
	
	# Connect to GameState changes to update button states
	GameState.scrap_changed.connect(_on_scrap_changed)
	GameState.integrity_changed.connect(_on_integrity_changed)
	
	# Initial update
	_update_ui_state()

func _update_ui_state() -> void:
	var current_scrap = GameState.scrap
	var current_integrity = GameState.ship_integrity
	
	# Fuel Button Logic
	if current_scrap >= SCRAP_COST_FUEL:
		buy_fuel_button.disabled = false
		fuel_cost_label.modulate = Color(0.4, 0.9, 1.0) # Active Blue
	else:
		buy_fuel_button.disabled = true
		fuel_cost_label.modulate = Color(0.5, 0.2, 0.2) # Disabled Red
		
	# Repair Button Logic
	if current_scrap >= SCRAP_COST_REPAIR and current_integrity < 100:
		repair_hull_button.disabled = false
		repair_cost_label.modulate = Color(0.4, 0.9, 1.0)
	else:
		repair_hull_button.disabled = true
		if current_integrity >= 100:
			repair_cost_label.modulate = Color(0.4, 0.9, 0.4) # Green (Full check)
		else:
			repair_cost_label.modulate = Color(0.5, 0.2, 0.2)

	# Update labels text
	fuel_cost_label.text = "%d SCRAP" % SCRAP_COST_FUEL
	repair_cost_label.text = "%d SCRAP" % SCRAP_COST_REPAIR

func _on_buy_fuel_pressed() -> void:
	if GameState.scrap >= SCRAP_COST_FUEL:
		GameState.scrap -= SCRAP_COST_FUEL
		GameState.fuel += FUEL_AMOUNT
		_show_status("FUEL ADDED (+%d)" % FUEL_AMOUNT)
		_update_ui_state()

func _on_repair_hull_pressed() -> void:
	if GameState.scrap >= SCRAP_COST_REPAIR and GameState.ship_integrity < 100:
		GameState.scrap -= SCRAP_COST_REPAIR
		GameState.repair_ship(REPAIR_AMOUNT)
		_show_status("HULL REPAIRED (+%d%%)" % REPAIR_AMOUNT)
		_update_ui_state()

func _show_status(text: String) -> void:
	status_message.text = text
	status_message.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(status_message, "modulate:a", 0.0, 1.0)

func _on_scrap_changed(_new_value: int) -> void:
	_update_ui_state()

func _on_integrity_changed(_new_value: int) -> void:
	_update_ui_state()
