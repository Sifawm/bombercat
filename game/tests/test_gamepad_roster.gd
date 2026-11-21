extends RulesTestCase
## Headless tests for the control layer's gamepad filtering, fallback mapping and sticky
## slot assignment.

const Roster := preload("res://control/gamepad_roster.gd")


func _device(id: int, name: String, guid: String = "", known: bool = false) -> Dictionary:
	return {"id": id, "name": name, "guid": guid, "known": known}


func test_ignores_keyboard_and_mouse() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [
		_device(0, "USB Keyboard"),
		_device(1, "Wireless Mouse"),
		_device(2, "Generic Gamepad", "05000000", false),
	]
	roster.update_roster(descriptors)
	check_eq(roster.assigned_device(0), 2, "player 0 should get the only gamepad")
	check_eq(roster.assigned_device(1), GamepadRoster.NO_DEVICE, "player 1 should be unassigned")
	check_eq(roster.valid_gamepads(), [2], "only the gamepad is valid")
	roster.free()


func test_ignores_consumer_and_system_controls() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [
		_device(0, "Logitech USB Consumer Control"),
		_device(1, "System Control"),
		_device(2, "Sony Interactive Entertainment Wireless Controller", "000054756f686f", false),
	]
	roster.update_roster(descriptors)
	check_eq(roster.assigned_device(0), 2, "the real controller should be assigned")
	check_eq(roster.valid_gamepads().size(), 1, "only one valid gamepad")
	roster.free()


func test_flags_unknown_device_for_fallback_mapping() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [_device(0, "8BitDo Zero 2", "05000000c82", false)]
	roster.update_roster(descriptors)
	check_eq(roster.fallback_candidates(), [0], "unknown device should need fallback mapping")
	roster.free()


func test_known_device_is_not_a_fallback_candidate() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [_device(0, "XInput Gamepad", "__xinput__", true)]
	roster.update_roster(descriptors)
	check_eq(roster.fallback_candidates(), [], "known device should not need fallback mapping")
	check_eq(roster.assigned_device(0), 0, "known device should be assigned")
	roster.free()


func test_assigns_two_controllers_to_two_players() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [
		_device(0, "Controller One", "a", false),
		_device(1, "Controller Two", "b", false),
	]
	roster.update_roster(descriptors)
	check_eq(roster.assigned_device(0), 0, "player 0 should get the first controller")
	check_eq(roster.assigned_device(1), 1, "player 1 should get the second controller")
	roster.free()


func test_third_controller_held_in_reserve() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [
		_device(0, "Controller One", "a", false),
		_device(1, "Controller Two", "b", false),
		_device(2, "Controller Three", "c", false),
	]
	roster.update_roster(descriptors)
	check_eq(roster.assigned_device(0), 0, "player 0 keeps the first controller")
	check_eq(roster.assigned_device(1), 1, "player 1 keeps the second controller")
	check_eq(roster.valid_gamepads().size(), 3, "all three are valid")
	roster.free()


func test_sticky_slot_retention_on_disconnect() -> void:
	var roster: Variant = Roster.new()
	var before: Array[Dictionary] = [
		_device(0, "Controller One", "a", false),
		_device(1, "Controller Two", "b", false),
	]
	roster.update_roster(before)
	var descriptors: Array[Dictionary] = [_device(1, "Controller Two", "b", false)]
	var disconnected: int = roster.update_roster(descriptors)
	check_eq(disconnected, 0, "player 0 should be reported as disconnected")
	check_eq(roster.assigned_device(0), GamepadRoster.NO_DEVICE, "player 0 should be unassigned")
	check_eq(roster.assigned_device(1), 1, "player 1 should keep its controller")
	roster.free()


func test_reconnection_fills_empty_slot_without_disturbing_other_player() -> void:
	var roster: Variant = Roster.new()
	var before: Array[Dictionary] = [
		_device(0, "Controller One", "a", false),
		_device(1, "Controller Two", "b", false),
	]
	roster.update_roster(before)
	var disconnected: Array[Dictionary] = [_device(1, "Controller Two", "b", false)]
	roster.update_roster(disconnected)
	check_eq(roster.assigned_device(0), GamepadRoster.NO_DEVICE, "player 0 is unassigned after disconnect")
	check_eq(roster.assigned_device(1), 1, "player 1 keeps its controller")
	var descriptors: Array[Dictionary] = [
		_device(1, "Controller Two", "b", false),
		_device(2, "Controller One", "a", false),
	]
	roster.update_roster(descriptors)
	check_eq(roster.assigned_device(0), 2, "player 0 gets the new controller")
	check_eq(roster.assigned_device(1), 1, "player 1 keeps its controller")
	roster.free()


func test_empty_guid_does_not_get_fallback_mapping() -> void:
	var roster: Variant = Roster.new()
	var descriptors: Array[Dictionary] = [_device(0, "Mystery Device", "", false)]
	roster.update_roster(descriptors)
	check_eq(roster.fallback_candidates(), [], "device with empty GUID should not be a fallback candidate")
	check_eq(roster.assigned_device(0), 0, "device with empty GUID is still assigned")
	roster.free()


func test_assignment_signal_carries_disconnected_player() -> void:
	var roster: Variant = Roster.new()
	var before: Array[Dictionary] = [
		_device(0, "Controller One", "a", false),
		_device(1, "Controller Two", "b", false),
	]
	roster.update_roster(before)
	var signaled: Array[int] = [-2]
	roster.assignments_changed.connect(func(player: int) -> void: signaled[0] = player)
	var descriptors: Array[Dictionary] = [_device(1, "Controller Two", "b", false)]
	roster.update_roster(descriptors)
	check_eq(signaled[0], 0, "signal should carry the disconnected player")
	roster.free()
