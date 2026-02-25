extends CanvasLayer
## Autoload root for the Developer Overlay.
## Ensures the overlay is always available (title screen and in-game).
## Toggle via DeveloperOverlay.toggle(), from Settings menu button, or Alt+D anywhere.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_dev_settings"):
		toggle()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	layer = 99  # Above dialogs (10), below fade transition (100)
	var OverlayScript = load("res://scripts/ui/developer_overlay.gd") as GDScript
	var overlay = OverlayScript.new()
	overlay.name = "DeveloperOverlay"
	add_child(overlay)


## Toggle overlay visibility. Call from anywhere (e.g. Settings menu).
func toggle() -> void:
	var overlay = get_node_or_null("DeveloperOverlay")
	if overlay:
		overlay.toggle()
