class_name Curse
extends RefCounted
## A temporary handicap on a Cat. A Curse changes nothing on the Cat itself: the Round asks
## it how to bend the Cat's commands while it lasts, so there is nothing to undo when it ends.

var id: StringName
var time_left: float


## The direction the Cat actually walks when its Player commands `direction`.
func redirect(direction: Vector2i) -> Vector2i:
	return direction


## Multiplier on the Cat's speed.
func speed_factor(_config: GameConfig) -> float:
	return 1.0
