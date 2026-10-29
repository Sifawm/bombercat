class_name LaserChase
extends RefCounted
## What one Cat does with the Laser Pointer's dot, decided from where the Cat stands on screen
## (docs/laser-pointer.md). Distances are in the screen's design space.

enum Band { IDLE, WATCH, HUNT, BITE }

## Nearer than this the Cat bites at the dot.
const BITE_DISTANCE := 110.0
## Nearer than this the Cat hunts the dot; further, it only watches it.
const HUNT_DISTANCE := 420.0
## The hop at the hunt band's near edge, against 1 at its far edge.
const LOWEST_HOP := 0.25
## How far, in degrees, the body turns towards the dot, the head on top of it, and the head up or down.
const BODY_YAW := 35.0
const HEAD_YAW := 30.0
const HEAD_PITCH := 25.0
## How far in front of the screen the Cat pretends to be, in pixels: a dot this far to its side is
## 45° round.
const LOOK_DEPTH := 300.0

var band := Band.IDLE
## Degrees towards the screen's right (yaw) and up (pitch).
var body_yaw := 0.0
var head_yaw := 0.0
var head_pitch := 0.0
## How high the Cat hops at the dot, from 0 (no hop) to 1 (`pounce`'s full height).
var hop := 0.0
## The paw the Cat swats with, "L" or "R", or "" for none.
var paw := &""


func _init(cat: Vector2, dot: LaserDot) -> void:
	if not dot.visible:
		return
	var offset := dot.position - cat
	var turn := rad_to_deg(atan2(offset.x, LOOK_DEPTH))  # shared by body and head, each up to its limit
	body_yaw = clampf(turn * BODY_YAW / (BODY_YAW + HEAD_YAW), -BODY_YAW, BODY_YAW)
	head_yaw = clampf(turn * HEAD_YAW / (BODY_YAW + HEAD_YAW), -HEAD_YAW, HEAD_YAW)
	head_pitch = clampf(rad_to_deg(atan2(-offset.y, LOOK_DEPTH)), -HEAD_PITCH, HEAD_PITCH)
	var distance := offset.length()
	if distance < BITE_DISTANCE:
		band = Band.BITE
	elif distance <= HUNT_DISTANCE:
		band = Band.HUNT
		if dot.moving():
			hop = lerpf(LOWEST_HOP, 1.0, inverse_lerp(BITE_DISTANCE, HUNT_DISTANCE, distance))
			paw = &"L" if offset.x > 0.0 else &"R"  # facing the screen, its left is on the right
	else:
		band = Band.WATCH
