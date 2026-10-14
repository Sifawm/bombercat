class_name LocalPlayerController
extends PlayerController
## A human on this machine, on the keyboard or on the gamepad of its slot (both work at once).
## Bindings are fixed, one set per slot.

const KEYS: Array[Dictionary] = [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "bomb": KEY_SPACE, "meow": KEY_Q},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "bomb": KEY_ENTER,
		"meow": KEY_SHIFT},  # only the right-hand one, see register_actions,
]
const PAD_BUTTONS: Dictionary[String, JoyButton] = {
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT,
	"right": JOY_BUTTON_DPAD_RIGHT, "bomb": JOY_BUTTON_A, "meow": JOY_BUTTON_X,
}
## Left stick: the axis and which side of it.
## A device number no joypad has: what a slot without a gamepad listens to.
const NO_DEVICE := 99
## How far the stick must be pushed; high enough that a sideways drift does not turn the Cat.
const STICK_DEADZONE := 0.5
const PAD_STICK: Dictionary[String, Array] = {
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
}

var _slot: int
## Whether the horizontal keys were pressed more recently than the vertical ones.
var _horizontal_is_newer := false


## The input action of a slot's "up", "down", "left", "right", "bomb" or "meow".
static func action(slot: int, control: String) -> StringName:
	return "p%d_%s" % [slot + 1, control]


## Creates every slot's actions. The direction keys also join Godot's ui_* actions, so each
## Player moves through the menus with the keys it plays with (gamepads already do).
static func register_actions() -> void:
	if InputMap.has_action(action(0, "up")):
		return
	Input.joy_connection_changed.connect(_assign_gamepads.unbind(2))
	for slot in KEYS.size():
		for control: String in KEYS[slot]:
			var action_name := action(slot, control)
			InputMap.add_action(action_name, STICK_DEADZONE)
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[slot][control]
			if key.physical_keycode == KEY_SHIFT:
				key.location = KEY_LOCATION_RIGHT
			InputMap.action_add_event(action_name, key)
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_BUTTONS[control]
			InputMap.action_add_event(action_name, button)
			if PAD_STICK.has(control):
				var stick := InputEventJoypadMotion.new()
				stick.axis = PAD_STICK[control][0]
				stick.axis_value = PAD_STICK[control][1]
				InputMap.action_add_event(action_name, stick)
				InputMap.action_add_event("ui_" + control, key)
	_assign_gamepads()


## Gives each slot its gamepad: the first real one to the first slot, and so on. Device
## numbers alone will not do, because some keyboards register as a joypad and take one.
static func _assign_gamepads() -> void:
	var gamepads := Input.get_connected_joypads().filter(Input.is_joy_known)
	for slot in KEYS.size():
		var device: int = gamepads[slot] if slot < gamepads.size() else NO_DEVICE
		for control: String in KEYS[slot]:
			for event in InputMap.action_get_events(action(slot, control)):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					event.device = device


func _init(slot: int) -> void:
	_slot = slot
	register_actions()


func drive(game_round: Round, player: int) -> void:
	game_round.set_move(player, direction())
	if bombs():
		game_round.place_bomb(player)


## Whether this Player wants a Bomb placed right now.
func bombs() -> bool:
	return Input.is_action_just_pressed(action(_slot, "bomb"))


func meows() -> bool:
	return Input.is_action_just_pressed(action(_slot, "meow"))


## Four directions only. With keys of both axes held, the one pressed last wins, so a Player
## can hold a direction and tap the next one to turn.
func direction() -> Vector2i:
	var x := int(_held("right")) - int(_held("left"))
	var y := int(_held("down")) - int(_held("up"))
	if Input.is_action_just_pressed(action(_slot, "left")) or Input.is_action_just_pressed(action(_slot, "right")):
		_horizontal_is_newer = true
	elif Input.is_action_just_pressed(action(_slot, "up")) or Input.is_action_just_pressed(action(_slot, "down")):
		_horizontal_is_newer = false
	if x != 0 and (y == 0 or _horizontal_is_newer):
		return Vector2i(x, 0)
	return Vector2i(0, y)


func _held(control: String) -> bool:
	return Input.is_action_pressed(action(_slot, control))
