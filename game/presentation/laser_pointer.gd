class_name LaserPointer
extends Control
## The Laser Pointer (docs/laser-pointer.md): on the screens that show the Cats, the mouse pointer
## is a red dot the Cats hunt. It still presses buttons; it chooses nothing.

## The dot's radius, its glow's, and how far the hand holding it trembles, in pixels.
const CORE := 7.0
const GLOW := 22.0
const TREMOR := 1.2
## How fast the hand trembles across and up, in radians a second.
const TREMOR_RATE := Vector2(23.0, 31.0)
const RED := Color("ff2a2a")
## The glow's outer and inner rings, and the hot middle of the core.
const GLOW_OUTER := Color(RED, 0.18)
const GLOW_INNER := Color(RED, 0.4)
const HOT := Color("ffd6d6")

## How many Laser Pointers are on screen: while one screen fades into another, both have one.
static var _shown := 0

var dot := LaserDot.new()
var _clock := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX  # above the screen's overlays, such as How to Play


func _enter_tree() -> void:
	_shown += 1
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	_shown -= 1
	if _shown == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	dot.take(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		dot.leave()


func _process(delta: float) -> void:
	_clock += delta
	dot.advance(delta)
	queue_redraw()


func _draw() -> void:
	if not dot.visible:
		return
	var at := get_global_transform().affine_inverse() * dot.position \
			+ TREMOR * Vector2(sin(_clock * TREMOR_RATE.x), cos(_clock * TREMOR_RATE.y))
	draw_circle(at, GLOW, GLOW_OUTER, true, -1.0, true)
	draw_circle(at, GLOW * 0.55, GLOW_INNER, true, -1.0, true)
	draw_circle(at, CORE, RED, true, -1.0, true)
	draw_circle(at, CORE * 0.45, HOT, true, -1.0, true)
