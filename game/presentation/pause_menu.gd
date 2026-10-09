class_name PauseMenu
extends ColorRect
## Freezes the game while it is open. Esc or Start opens it (see `open`) and closes it.

signal quit_to_title

const PAUSE_ACTION := &"pause"

var _resume: Button


func _init() -> void:
	if not InputMap.has_action(PAUSE_ACTION):
		InputMap.add_action(PAUSE_ACTION)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event(PAUSE_ACTION, key)
		var start := InputEventJoypadButton.new()
		start.device = -1  # any gamepad
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event(PAUSE_ACTION, start)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	color = Color(0.0, 0.0, 0.0, 0.7)
	var column := Ui.centred_column(self)
	column.add_child(Ui.label("Paused", Ui.TITLE_SIZE))
	_resume = Ui.button("Resume", _close)
	column.add_child(_resume)
	column.add_child(Ui.button("How to Play", _show_how_to_play))
	for bus: String in ["Music", "Effects"]:
		var index := AudioServer.get_bus_index(bus)
		var toggle := CheckButton.new()
		toggle.text = bus
		toggle.button_pressed = not AudioServer.is_bus_mute(index)
		toggle.toggled.connect(func(on: bool) -> void: AudioServer.set_bus_mute(index, not on))
		column.add_child(toggle)
	column.add_child(Ui.button("Quit to Title", func() -> void:
		get_tree().paused = false
		quit_to_title.emit()))


func open() -> void:
	get_tree().paused = true
	visible = true
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(PAUSE_ACTION) or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	for child in get_children():
		if child is HowToPlay:  # closed with Start while the card was open
			child.queue_free()
	visible = false
	get_tree().paused = false


func _show_how_to_play() -> void:
	HowToPlay.open_over(self, _resume)
