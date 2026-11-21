extends Node
## Detects, filters and assigns Bluetooth and other gamepads to local Players. Unknown devices
## that look like real gamepads get a standard fallback mapping; keyboards, mice and system
## controls are ignored. Each Player keeps its assigned device until it disconnects.

signal assignments_changed(disconnected_player: int)

const NO_DEVICE := -1
const SLOTS := 2

## Device-name substrings that identify peripherals to ignore, case-insensitively.
const NON_GAMEPAD_PATTERNS: Array[String] = [
	"keyboard",
	"mouse",
	"touchpad",
	"trackpad",
	"consumer control",
	"system control",
	"hotkey",
	"wmi",
	"led controller",
]

var _assignments: Array[int] = [NO_DEVICE, NO_DEVICE]
var _valid_gamepads: Array[int] = []
var _fallback_candidates: Array[int] = []


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_connection_changed)
	_refresh()


func _on_connection_changed(_device: int, _connected: bool) -> void:
	_refresh()


func _refresh() -> void:
	var descriptors: Array[Dictionary] = []
	for device in Input.get_connected_joypads():
		descriptors.append({
			"id": device,
			"name": Input.get_joy_name(device),
			"guid": Input.get_joy_guid(device),
			"known": Input.is_joy_known(device),
		})
	update_roster(descriptors)


## Recomputes valid gamepads and sticky slot assignments from `descriptors`, each a Dictionary
## with `id: int`, `name: String`, `guid: String` and `known: bool`. Returns the Player whose
## controller just disconnected, or `NO_DEVICE` if none did.
func update_roster(descriptors: Array[Dictionary]) -> int:
	var before := _assignments.duplicate()
	var accepted: Array[int] = []
	_fallback_candidates.clear()

	for descriptor in descriptors:
		if _is_non_gamepad(descriptor.name):
			continue
		accepted.append(descriptor.id)
		if not descriptor.known and not descriptor.guid.is_empty():
			_fallback_candidates.append(descriptor.id)
			_register_fallback(descriptor.id, descriptor.guid)

	var disconnected_player := NO_DEVICE
	for player in SLOTS:
		if _assignments[player] != NO_DEVICE and not accepted.has(_assignments[player]):
			_assignments[player] = NO_DEVICE
			disconnected_player = player

	for player in SLOTS:
		if _assignments[player] == NO_DEVICE:
			var other := 1 if player == 0 else 0
			for device in accepted:
				if device != _assignments[other]:
					_assignments[player] = device
					break

	_valid_gamepads = accepted
	if _assignments != before:
		assignments_changed.emit(disconnected_player)
	return disconnected_player


func _is_non_gamepad(name: String) -> bool:
	var lower := name.to_lower()
	for pattern in NON_GAMEPAD_PATTERNS:
		if lower.contains(pattern):
			return true
	return false


func _register_fallback(device: int, guid: String) -> void:
	# Tests feed descriptors for devices that are not really connected; skip registration there.
	if not Input.get_connected_joypads().has(device):
		return
	var platform := _platform_name()
	var mapping := "%s,BomberCat Gamepad,platform:%s,a0:leftx,a1:lefty,b0:a,b1:b,b2:x,b3:y,b6:start,b7:start,b9:start,h0.1:dpup,h0.2:dpright,h0.4:dpdown,h0.8:dpleft" % [guid, platform]
	Input.add_joy_mapping(mapping, true)


func _platform_name() -> String:
	match OS.get_name():
		"Windows":
			return "Windows"
		"macOS":
			return "Mac OS X"
		"Linux":
			return "Linux"
		_:
			return "Linux"


func assigned_device(player: int) -> int:
	return _assignments[player] if player >= 0 and player < SLOTS else NO_DEVICE


func has_gamepad(player: int) -> bool:
	return assigned_device(player) != NO_DEVICE


func has_any_gamepad() -> bool:
	return _assignments.any(func(device: int) -> bool: return device != NO_DEVICE)


func valid_gamepads() -> Array[int]:
	return _valid_gamepads.duplicate()


func fallback_candidates() -> Array[int]:
	return _fallback_candidates.duplicate()
