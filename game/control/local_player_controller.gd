class_name LocalPlayerController
extends PlayerController
## A human on this machine. Bindings are fixed, one set per slot.

const KEYS: Array[Dictionary] = [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "bomb": KEY_SPACE},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "bomb": KEY_ENTER},
]

var _prefix: String
## Whether the horizontal keys were pressed more recently than the vertical ones.
var _horizontal_is_newer := false


func _init(slot: int) -> void:
	_prefix = "p%d_" % (slot + 1)
	for action: String in KEYS[slot]:
		if InputMap.has_action(_prefix + action):
			continue
		var event := InputEventKey.new()
		event.physical_keycode = KEYS[slot][action]
		InputMap.add_action(_prefix + action)
		InputMap.action_add_event(_prefix + action, event)


func drive(game_round: Round, player: int) -> void:
	game_round.set_move(player, _direction())
	if Input.is_action_just_pressed(_prefix + "bomb"):
		game_round.place_bomb(player)


## Four directions only. With keys of both axes held, the one pressed last wins, so a Player
## can hold a direction and tap the next one to turn.
func _direction() -> Vector2i:
	var x := int(Input.get_axis(_prefix + "left", _prefix + "right"))
	var y := int(Input.get_axis(_prefix + "up", _prefix + "down"))
	if Input.is_action_just_pressed(_prefix + "left") or Input.is_action_just_pressed(_prefix + "right"):
		_horizontal_is_newer = true
	elif Input.is_action_just_pressed(_prefix + "up") or Input.is_action_just_pressed(_prefix + "down"):
		_horizontal_is_newer = false
	if x != 0 and (y == 0 or _horizontal_is_newer):
		return Vector2i(x, 0)
	return Vector2i(0, y)
