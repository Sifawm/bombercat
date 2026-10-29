class_name LaserChase
extends RefCounted
## What one Cat does with the Laser Pointer's dot, decided from where the Cat stands on screen
## and what it was doing (docs/laser-pointer.md). Distances are in the screen's design space.

enum Act { IDLE, WATCH, HOP, STALK, POUNCE, PIN, BITE, MISS }

## Nearer than this the Cat bites at the dot.
const BITE_DISTANCE := 110.0
## Nearer than this the Cat hunts the dot; further, it only watches it.
const HUNT_DISTANCE := 420.0
## How long the dot must rest in the hunt band before the Cat crouches to stalk it.
const STALK_AFTER := 0.6
## How long a Cat that landed on an empty spot stands looking at where the dot went.
const MISS_PAUSE := 0.4
## How far to the other side of the Cat the dot must go before it reaches out with the other paw.
const PAW_SWAP := 40.0
## How far, in degrees, the body turns towards the dot, the head on top of it, and the head up or down.
const BODY_YAW := 35.0
const HEAD_YAW := 30.0
const HEAD_PITCH := 25.0
## Seen from above, the big head reads far more turned down than it is: further than this hides
## the Cat's face.
const HEAD_DOWN := 4.0
## How far in front of the screen the Cat pretends to be, in pixels: a dot this far to its side is
## 45° round.
const LOOK_DEPTH := 300.0

var act := Act.IDLE
## Degrees towards the screen's right (yaw) and up (pitch).
var body_yaw := 0.0
var head_yaw := 0.0
var head_pitch := 0.0
## The paw nearer the dot, "L" or "R", the one the Cat reaches out with while it hops.
var paw := &"L"
## Where the dot was when the Cat leapt at it.
var _aim := Vector2.ZERO
## How much longer a Cat that missed stands still.
var _pause := 0.0


## One frame of the hunt, `delta` seconds after the last. `cat` is the Cat's place on screen.
func follow(cat: Rect2, dot: LaserDot, delta: float) -> void:
	if act == Act.POUNCE:
		return  # committed: in the air the Cat no longer follows the dot
	if act == Act.MISS:
		_pause -= delta
		if _pause <= 0.0:
			act = Act.WATCH  # back to the hunt
	_look(cat.get_center(), dot)
	if act == Act.PIN or act == Act.BITE or act == Act.MISS:
		return  # a clip plays to its end, a miss to the end of its pause
	act = _next(cat, dot)
	if act == Act.POUNCE:
		_aim = dot.position  # where it leaps


## The clip the Cat plays for `act` has ended, the dot where it is now.
func finish(dot: LaserDot) -> void:
	match act:
		Act.POUNCE:
			if dot.visible and dot.position.distance_to(_aim) < BITE_DISTANCE:
				act = Act.PIN
			else:
				act = Act.MISS
				_pause = MISS_PAUSE
		Act.PIN:
			act = Act.BITE
		Act.BITE:
			act = Act.WATCH  # decided afresh on the next frame


## Turns the body and head towards the dot. A Cat that missed keeps its body facing where it
## aimed and snaps only its head round.
func _look(cat: Vector2, dot: LaserDot) -> void:
	if not dot.visible:
		body_yaw = 0.0
		head_yaw = 0.0
		head_pitch = 0.0
		return
	var offset := dot.position - cat
	var turn := rad_to_deg(atan2(offset.x, LOOK_DEPTH))  # shared by body and head, each up to its limit
	if act != Act.MISS:
		body_yaw = clampf(turn * BODY_YAW / (BODY_YAW + HEAD_YAW), -BODY_YAW, BODY_YAW)
	head_yaw = clampf(turn - body_yaw, -HEAD_YAW, HEAD_YAW)
	head_pitch = clampf(rad_to_deg(atan2(-offset.y, LOOK_DEPTH)), -HEAD_DOWN, HEAD_PITCH)
	if absf(offset.x) > PAW_SWAP:
		paw = &"L" if offset.x > 0.0 else &"R"  # facing the screen, its left is on the right


func _next(cat: Rect2, dot: LaserDot) -> Act:
	if not dot.visible:
		return Act.IDLE
	var distance := dot.position.distance_to(cat.get_center())
	if distance < BITE_DISTANCE:
		return Act.BITE
	if distance > HUNT_DISTANCE:
		return Act.WATCH
	if dot.still >= STALK_AFTER or dot.position.y > cat.end.y:  # a dot below its feet is not leapt at
		return Act.STALK
	if act == Act.STALK:
		return Act.POUNCE
	return Act.HOP
