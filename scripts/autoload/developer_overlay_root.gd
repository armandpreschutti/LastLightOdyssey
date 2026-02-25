extends CanvasLayer
## Autoload root for the Developer Overlay.
## Ensures the overlay is always available (title screen and in-game).
## Toggle via DeveloperOverlay.toggle() or from Settings menu button.

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
