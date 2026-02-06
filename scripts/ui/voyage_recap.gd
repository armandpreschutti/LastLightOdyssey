extends Control
## Voyage Recap Screen - Shows comprehensive summary of the entire voyage
## Displayed after reaching New Earth, showing final state and cumulative stats

signal recap_dismissed

@onready var background: ColorRect = $Background
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var ending_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EndingLabel
@onready var ending_desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EndingDescLabel

# Final state labels
@onready var colonists_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/ColonistsLabel
@onready var fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/FuelLabel
@onready var integrity_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/IntegrityLabel
@onready var scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FinalStateContainer/ScrapLabel
@onready var officers_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OfficersContainer

# Cumulative stats labels
@onready var total_fuel_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalFuelLabel
@onready var total_scrap_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalScrapLabel
@onready var total_enemies_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalEnemiesLabel
@onready var total_missions_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalMissionsLabel
@onready var total_turns_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/TotalTurnsLabel
@onready var nodes_visited_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CumulativeContainer/NodesVisitedLabel

@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

var _stat_tween: Tween = null
var _ending_type: String = ""


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)


func show_recap(ending_type: String) -> void:
	_ending_type = ending_type
	
	# Set title and ending
	title_label.text = "[ VOYAGE COMPLETE ]"
	
	match ending_type:
		"perfect":
			ending_label.text = "THE GOLDEN AGE"
			ending_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			ending_desc_label.text = "All 1,000 colonists reached New Earth. Humanity will flourish."
		"good":
			ending_label.text = "THE HARD FOUNDATION"
			ending_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
			ending_desc_label.text = "Enough survived to rebuild. The road ahead is difficult, but hope remains."
		"bad":
			ending_label.text = "THE ENDANGERED SPECIES"
			ending_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			ending_desc_label.text = "A mere handful reached New Earth. Humanity clings to existence by a thread."
		_:
			ending_label.text = "JOURNEY'S END"
			ending_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
			ending_desc_label.text = "The voyage is complete."
	
	# Set final state stats
	colonists_label.text = "COLONISTS REMAINING: %d / %d" % [GameState.colonist_count, GameState.MAX_COLONISTS]
	fuel_label.text = "FUEL RESERVES: %d" % GameState.fuel
	integrity_label.text = "SHIP INTEGRITY: %d%%" % GameState.ship_integrity
	scrap_label.text = "SCRAP STOCKPILE: %d" % GameState.scrap
	
	# Color colonists based on count
	if GameState.colonist_count >= 1000:
		colonists_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif GameState.colonist_count >= 500:
		colonists_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	else:
		colonists_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	
	# Clear old officer status labels
	for child in officers_container.get_children():
		child.queue_free()
	
	# Add officer status rows
	for officer_key in GameState.officers.keys():
		var officer_label = Label.new()
		officer_label.add_theme_font_size_override("font_size", 16)
		
		var officer_name = officer_key.to_upper()
		var is_alive = GameState.officers[officer_key]["alive"]
		
		if is_alive:
			officer_label.text = "  %s - SURVIVED" % officer_name
			officer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			officer_label.text = "  %s - K.I.A." % officer_name
			officer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		
		officers_container.add_child(officer_label)
	
	# Set cumulative mission stats
	total_fuel_label.text = "TOTAL FUEL COLLECTED: %d" % GameState.total_fuel_collected
	total_scrap_label.text = "TOTAL SCRAP COLLECTED: %d" % GameState.total_scrap_collected
	total_enemies_label.text = "TOTAL HOSTILES ELIMINATED: %d" % GameState.total_enemies_killed
	total_missions_label.text = "MISSIONS COMPLETED: %d" % GameState.total_missions_completed
	total_turns_label.text = "TACTICAL TURNS SURVIVED: %d" % GameState.total_tactical_turns
	nodes_visited_label.text = "SECTORS TRAVERSED: %d" % (GameState.visited_nodes.size() + 1)
	
	# Animate in
	_animate_recap_in()


func _animate_recap_in() -> void:
	# Start with everything hidden
	modulate.a = 0.0
	visible = true
	continue_button.modulate.a = 0.0
	continue_button.disabled = true
	
	# Hide all stat labels initially
	ending_label.modulate.a = 0.0
	ending_desc_label.modulate.a = 0.0
	colonists_label.modulate.a = 0.0
	fuel_label.modulate.a = 0.0
	integrity_label.modulate.a = 0.0
	scrap_label.modulate.a = 0.0
	total_fuel_label.modulate.a = 0.0
	total_scrap_label.modulate.a = 0.0
	total_enemies_label.modulate.a = 0.0
	total_missions_label.modulate.a = 0.0
	total_turns_label.modulate.a = 0.0
	nodes_visited_label.modulate.a = 0.0
	
	for child in officers_container.get_children():
		child.modulate.a = 0.0
	
	_stat_tween = create_tween()
	_stat_tween.set_ease(Tween.EASE_OUT)
	_stat_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in background and title
	_stat_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	_stat_tween.tween_interval(0.3)
	
	# Reveal ending type
	_stat_tween.tween_property(ending_label, "modulate:a", 1.0, 0.4)
	_stat_tween.tween_interval(0.2)
	_stat_tween.tween_property(ending_desc_label, "modulate:a", 1.0, 0.3)
	_stat_tween.tween_interval(0.4)
	
	# Reveal final state stats
	_stat_tween.tween_property(colonists_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(integrity_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(scrap_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.2)
	
	# Reveal officer statuses
	for child in officers_container.get_children():
		_stat_tween.tween_property(child, "modulate:a", 1.0, 0.2)
		_stat_tween.tween_interval(0.08)
	
	_stat_tween.tween_interval(0.3)
	
	# Reveal cumulative stats
	_stat_tween.tween_property(total_fuel_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_scrap_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_enemies_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_missions_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(total_turns_label, "modulate:a", 1.0, 0.25)
	_stat_tween.tween_interval(0.1)
	_stat_tween.tween_property(nodes_visited_label, "modulate:a", 1.0, 0.25)
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
			_skip_animation()
		else:
			_on_continue_pressed()


func _skip_animation() -> void:
	if _stat_tween and _stat_tween.is_running():
		_stat_tween.kill()
	
	modulate.a = 1.0
	ending_label.modulate.a = 1.0
	ending_desc_label.modulate.a = 1.0
	colonists_label.modulate.a = 1.0
	fuel_label.modulate.a = 1.0
	integrity_label.modulate.a = 1.0
	scrap_label.modulate.a = 1.0
	total_fuel_label.modulate.a = 1.0
	total_scrap_label.modulate.a = 1.0
	total_enemies_label.modulate.a = 1.0
	total_missions_label.modulate.a = 1.0
	total_turns_label.modulate.a = 1.0
	nodes_visited_label.modulate.a = 1.0
	
	for child in officers_container.get_children():
		child.modulate.a = 1.0
	
	continue_button.modulate.a = 1.0
	continue_button.disabled = false
