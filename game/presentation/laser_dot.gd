class_name LaserDot
extends RefCounted
## Where the Laser Pointer's dot is, as the Cats read it: in the screen's design space, and seen
## only while the mouse is in use (docs/laser-pointer.md).

## How long the mouse may rest before the dot goes out.
const TIMEOUT := 3.0
## How long after its last move the dot still counts as moving.
const MOVING := 0.2

var position := Vector2.ZERO
var visible := false
## How long since the mouse last moved.
var still := 0.0


## Seen and moved a moment ago.
func moving() -> bool:
	return visible and still <= MOVING


func take(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:  # not a finger
		position = event.position
		visible = true
		still = 0.0


func advance(delta: float) -> void:
	still += delta
	if still > TIMEOUT:
		visible = false


## The mouse left the window.
func leave() -> void:
	visible = false
