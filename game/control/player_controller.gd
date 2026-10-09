class_name PlayerController
extends RefCounted
## Turns some source of decisions into commands for one Player's Cat. The local human is
## the only implementation today; an AI or a remote Player would be others.


## Issues this Player's commands for the coming step.
func drive(_game_round: Round, _player: int) -> void:
	pass


## Whether this Player wants its Cat to meow right now. A meow is for show only, so it is
## not a command to the Round.
func meows() -> bool:
	return false
