class_name Bomb
extends RefCounted

var tile: Vector2i
## Index of the Player whose Cat placed it.
var owner: int
var bomb_range: int
## Seconds until it detonates.
var fuse_left: float
## Direction it is sliding in after a push, or ZERO at rest.
var slide := Vector2i.ZERO
## How far (0 to 1) it has slid towards the next Tile.
var slide_progress := 0.0
