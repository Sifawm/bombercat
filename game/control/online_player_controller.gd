class_name OnlinePlayerController
extends PlayerController
## The one human of a browser playing online: it has the whole keyboard and the first
## gamepad to itself, so the keys of either local Player drive its Cat.

var _slots: Array[LocalPlayerController] = [LocalPlayerController.new(0), LocalPlayerController.new(1)]


func drive(game_round: Round, player: int) -> void:
	var direction := _slots[0].direction()
	if direction == Vector2i.ZERO:
		direction = _slots[1].direction()
	game_round.set_move(player, direction)
	if _slots.any(func(slot: LocalPlayerController) -> bool: return slot.bombs()):
		game_round.place_bomb(player)


func meows() -> bool:
	return _slots.any(func(slot: LocalPlayerController) -> bool: return slot.meows())
