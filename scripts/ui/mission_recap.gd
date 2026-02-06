extends Control
## Mission Recap Screen - Shows post-mission summary with stats and "beaming up" animation
## Displayed after extraction before returning to management mode

signal recap_dismissed

@onready var background: ColorRect = $Background
# Updated paths for new icon-based layout
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var outcome_label: Label = $PanelContainer/MarginContainer/VBoxContainer/OutcomeLabel
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/FuelRow/FuelLabel
@onready var scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/ScrapRow/ScrapLabel
@onready var enemies_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/EnemiesRow/EnemiesLabel
@onready var turns_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/TurnsRow/TurnsLabel
@onready var officers_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficersContainer
@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

# Icon rows for animation
@onready var fuel_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/FuelRow
@onready var scrap_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/ScrapRow
@onready var enemies_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/EnemiesRow
@onready var turns_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/TurnsRow

var _stat_tween: Tween = null


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)


func show_recap(stats: Dictionary) -> void:
	var success: bool = stats.get("success", false)
	var fuel_collected: int = stats.get("fuel_collected", 0)
	var scrap_collected: int = stats.get("scrap_collected", 0)
	var enemies_killed: int = stats.get("enemies_killed", 0)
	var turns_taken: int = stats.get("turns_taken", 0)
	var officers_status: Array = stats.get("officers_status", [])
	
	# Set outcome
	if success:
		title_label.text = "[ EXTRACTION COMPLETE ]"
		outcome_label.text = "TEAM SUCCESSFULLY EXTRACTED"
		outcome_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	else:
		title_label.text = "[ MISSION FAILED ]"
		outcome_label.text = "EXTRACTION FAILED - TEAM LOST"
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	
	# Clear old officer status labels
	for child in officers_container.get_children():
		child.queue_free()
	
	# Set stats (initially hidden for animation)
	fuel_label.text = "FUEL COLLECTED: +%d" % fuel_collected
	scrap_label.text = "SCRAP COLLECTED: +%d" % scrap_collected
	enemies_label.text = "HOSTILES ELIMINATED: %d" % enemies_killed
	turns_label.text = "TURNS SURVIVED: %d" % turns_taken
	
	# Add officer status rows
	for officer_data in officers_status:
		var officer_label = Label.new()
		officer_label.add_theme_font_size_override("font_size", 16)
		
		var officer_name = officer_data.get("name", "UNKNOWN").to_upper()
		var is_alive = officer_data.get("alive", false)
		var hp = officer_data.get("hp", 0)
		var max_hp = officer_data.get("max_hp", 100)
		
		if is_alive:
			officer_label.text = "  %s - HP: %d/%d" % [officer_name, hp, max_hp]
			officer_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		else:
			officer_label.text = "  %s - K.I.A." % officer_name
			officer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		
		officers_container.add_child(officer_label)
	
	# Animate in
	_animate_recap_in()


func _animate_recap_in() -> void:
	# Start with everything hidden
	modulate.a = 0.0
	visible = true
	continue_button.modulate.a = 0.0
	continue_button.disabled = true
	
	# Fade rows (with icons)
	fuel_row.modulate.a = 0.0
	scrap_row.modulate.a = 0.0
	enemies_row.modulate.a = 0.0
	turns_row.modulate.a = 0.0
	
	for child in officers_container.get_children():
		child.modulate.a = 0.0
	
	_stat_tween = create_tween()
	_stat_tween.set_ease(Tween.EASE_OUT)
	_stat_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in background and title
	_stat_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	_stat_tween.tween_interval(0.3)
	
	# Reveal stats one by one with typewriter feel (animate rows with icons)
	_stat_tween.tween_property(fuel_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(scrap_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(enemies_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.15)
	_stat_tween.tween_property(turns_row, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.3)
	
	# Reveal officer statuses
	for child in officers_container.get_children():
		_stat_tween.tween_property(child, "modulate:a", 1.0, 0.25)
		_stat_tween.tween_interval(0.1)
	
	_stat_tween.tween_interval(0.3)
	
	# Show continue button
	_stat_tween.tween_property(continue_button, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_callback(func(): continue_button.disabled = false)


func _on_continue_pressed() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_dismiss)


func _dismiss() -> void:
	visible = false
	recap_dismissed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if continue_button.disabled:
			# Skip animation
			if _stat_tween and _stat_tween.is_running():
				_stat_tween.kill()
			modulate.a = 1.0
			fuel_row.modulate.a = 1.0
			scrap_row.modulate.a = 1.0
			enemies_row.modulate.a = 1.0
			turns_row.modulate.a = 1.0
			for child in officers_container.get_children():
				child.modulate.a = 1.0
			continue_button.modulate.a = 1.0
			continue_button.disabled = false
		else:
			_on_continue_pressed()
