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


## The Tile under the Cat's centre.
func tile() -> Vector2i:
	return Vector2i(position.round())
