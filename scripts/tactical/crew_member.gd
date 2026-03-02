extends TacticalInteractable
## Crew Member - Abandoned Station objective interactable
## Survivor waiting to be rescued. Pulses yellow.
## Removed on interaction (rescued).

var _pulse_tween: Tween = null


func _ready() -> void:
	super._ready()
	_start_yellow_pulse()


func _start_yellow_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	if not sprite:
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(sprite, "modulate", Color(1.4, 1.2, 0.3, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func interact() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	super.interact()


func get_interaction_text() -> String:
	return "RESCUE CREW MEMBER (+1)"


func get_objective_id() -> String:
	return "rescue_crew"


func get_item_type() -> String:
	return ""
