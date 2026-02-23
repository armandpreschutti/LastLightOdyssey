extends RefCounted
class_name EffectIconConfig
## Shared config for status-effect icons drawn as Polygon2D shapes
## (same technique as the cover shield indicators).

## Filled circle (8-sided approximation)
static var _CIRCLE := PackedVector2Array([
	Vector2(4, 0), Vector2(2.8, 2.8), Vector2(0, 4), Vector2(-2.8, 2.8),
	Vector2(-4, 0), Vector2(-2.8, -2.8), Vector2(0, -4), Vector2(2.8, -2.8),
])

## Downward-pointing filled triangle
static var _DOWN_TRI := PackedVector2Array([
	Vector2(-4, -3), Vector2(4, -3), Vector2(0, 4),
])

## Diamond / rhombus
static var _DIAMOND := PackedVector2Array([
	Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0),
])

## Upward-pointing filled triangle
static var _UP_TRI := PackedVector2Array([
	Vector2(-4, 3), Vector2(4, 3), Vector2(0, -4),
])

## Filled square (for armor/block effects)
static var _SQUARE := PackedVector2Array([
	Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3),
])

static var EFFECT_DATA: Dictionary = {
	"poison": {
		"polygon": _CIRCLE,
		"color": Color(0.75, 0.2, 1.0, 0.95),
		"outline": Color(0.45, 0.1, 0.65, 0.7),
		"label": "Poisoned",
	},
	"pin_down": {
		"polygon": _DOWN_TRI,
		"color": Color(1.0, 0.5, 0.1, 0.95),
		"outline": Color(0.65, 0.3, 0.05, 0.7),
		"label": "Suppressed",
	},
	"marked": {
		"polygon": _DIAMOND,
		"color": Color(1.0, 0.85, 0.15, 0.95),
		"outline": Color(0.7, 0.55, 0.05, 0.7),
		"label": "Marked",
	},
	"adrenaline": {
		"polygon": _UP_TRI,
		"color": Color(0.2, 1.0, 0.4, 0.95),
		"outline": Color(0.1, 0.6, 0.2, 0.7),
		"label": "Adrenaline Patch",
	},
	"immune": {
		"polygon": _DIAMOND,
		"color": Color(1.0, 0.9, 0.2, 0.95),
		"outline": Color(0.7, 0.6, 0.0, 0.7),
		"label": "Immune",
	},
	"stim": {
		"polygon": _CIRCLE,
		"color": Color(0.2, 0.8, 1.0, 0.95),
		"outline": Color(0.0, 0.5, 0.7, 0.7),
		"label": "Stim",
	},
	"phantom": {
		"polygon": _CIRCLE,
		"color": Color(0.6, 0.3, 1.0, 0.95),
		"outline": Color(0.35, 0.15, 0.6, 0.7),
		"label": "Phantom",
	},
	"untouchable": {
		"polygon": _UP_TRI,
		"color": Color(0.5, 0.9, 1.0, 0.95),
		"outline": Color(0.2, 0.6, 0.8, 0.7),
		"label": "Untouchable",
	},
	"bulldozer_armor": {
		"polygon": _SQUARE,
		"color": Color(0.7, 0.7, 0.75, 0.95),
		"outline": Color(0.4, 0.4, 0.45, 0.7),
		"label": "Bulldozer Armor",
	},
	"deep_scanned": {
		"polygon": _DIAMOND,
		"color": Color(0.3, 0.7, 1.0, 0.95),
		"outline": Color(0.0, 0.45, 0.75, 0.7),
		"label": "Deep Scanned",
	},
	"last_stand": {
		"polygon": _UP_TRI,
		"color": Color(1.0, 0.4, 0.2, 0.95),
		"outline": Color(0.7, 0.25, 0.05, 0.7),
		"label": "Last Stand",
	},
	"inspired": {
		"polygon": _UP_TRI,
		"color": Color(1.0, 0.85, 0.3, 0.95),
		"outline": Color(0.8, 0.6, 0.0, 0.7),
		"label": "Inspired",
	},
}

static var EFFECT_PRIORITY: Array[String] = [
	"poison", "pin_down", "marked", "deep_scanned",
	"adrenaline", "immune", "stim", "phantom", "untouchable",
	"bulldozer_armor", "last_stand", "inspired",
]
## Icons start from top-left of unit. X increases rightward, Y is fixed.
static var ICON_SPACING := 10
static var ICON_START_X := -10  ## Left edge of icon row
static var ICON_Y := -13  ## Vertical position above sprite
static var ICON_SCALE := 0.844  ## 12.5% bigger than 0.75


static func get_data(effect_name: String) -> Dictionary:
	return EFFECT_DATA.get(effect_name, {})


## Get position for icon at given slot index. Used for status effects and cover alike.
## slot 0 = leftmost, increasing rightward.
static func get_icon_position(slot: int) -> Vector2:
	return Vector2(ICON_START_X + slot * ICON_SPACING, ICON_Y)


## Create an effect icon Node2D. Consolidates logic for officer and enemy units.
static func create_effect_icon(effect_key: String, data: Dictionary, slot: int) -> Node2D:
	var icon := Node2D.new()
	icon.name = "Icon_" + effect_key
	icon.position = get_icon_position(slot)
	var s := ICON_SCALE
	var outline := Polygon2D.new()
	outline.polygon = data["polygon"]
	outline.color = data["outline"]
	outline.scale = Vector2(1.3 * s, 1.3 * s)
	icon.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = data["polygon"]
	fill.color = data["color"]
	fill.scale = Vector2(s, s)
	icon.add_child(fill)
	return icon
