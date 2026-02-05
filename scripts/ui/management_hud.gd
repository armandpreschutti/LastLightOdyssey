extends Control
## Management HUD - Displays ship stats and provides jump controls
## 1980s terminal aesthetic with amber text

@onready var colonists_label: Label = $VBoxContainer/StatsContainer/ColonistsLabel
@onready var fuel_label: Label = $VBoxContainer/StatsContainer/FuelLabel
@onready var integrity_label: Label = $VBoxContainer/StatsContainer/IntegrityLabel
@onready var scrap_label: Label = $VBoxContainer/StatsContainer/ScrapLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _ready() -> void:
	_connect_signals()
	_update_all_stats()


func _connect_signals() -> void:
	GameState.colonists_changed.connect(_on_colonists_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.integrity_changed.connect(_on_integrity_changed)
	GameState.scrap_changed.connect(_on_scrap_changed)


func _update_all_stats() -> void:
	_on_colonists_changed(GameState.colonist_count)
	_on_fuel_changed(GameState.fuel)
	_on_integrity_changed(GameState.ship_integrity)
	_on_scrap_changed(GameState.scrap)


func _on_colonists_changed(new_value: int) -> void:
	colonists_label.text = "COLONISTS: %d" % new_value


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
