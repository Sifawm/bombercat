class_name CatState
extends RefCounted

## Continuous position in Tile units; Tile centres are at whole numbers.
var position: Vector2
var facing := Vector2i.DOWN
var alive := true
var speed: float
var bomb_capacity: int
var bomb_range: int
## How many of this Cat's Bombs are on the Map right now.
var active_bombs := 0
## Tallies of this Round, for the Match summary.
var bombs_placed := 0
var crates_destroyed := 0
## Ids of the Powerups collected this Round, in order.
var collected: Array[StringName] = []
var paw_swipe := false
var nine_lives := false
## Seconds left during which Explosions cannot hurt this Cat.
var invulnerable_left := 0.0
## The active Curse, if any.
var curse: Curse


## The Tile under the Cat's centre.
func tile() -> Vector2i:
	return Vector2i(position.round())
