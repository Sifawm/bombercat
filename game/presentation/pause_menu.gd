class_name PauseMenu
extends ColorRect
## Freezes the game while it is open. Esc or Start opens it (see `open`) and closes it.

signal quit_to_title
## Emitted in place of closing when `closes_itself` is off.
signal resume_pressed

const PAUSE_ACTION := &"pause"
const RESUME_DELAY := 0.8

## Off where the pause is not this screen's own to end: online it belongs to the Room.
var closes_itself := true

var _resume: Button
var _quit: Button


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
	color = Color(Ui.INK, 0.7)
	var column := Ui.centred_column(self, 40)
	column.add_child(Ui.title("Paused"))
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 20)
	column.add_child(menu)
	_resume = Ui.button("Resume", _resume_or_ask, true)
	_resume.custom_minimum_size = Vector2(520, 112)
	menu.add_child(_resume)
	menu.add_child(_item(Ui.button("How to Play", _show_how_to_play)))
	for bus: String in ["Music", "Effects"]:
		var index := AudioServer.get_bus_index(bus)
		menu.add_child(_item(Ui.toggle(bus, not AudioServer.is_bus_mute(index),
				func(on: bool) -> void: AudioServer.set_bus_mute(index, not on))))
	_quit = _item(Ui.button("Quit to Title", func() -> void:
		get_tree().paused = false
		quit_to_title.emit()))
	menu.add_child(_quit)


## Adds a button above the one that quits.
func add_action(text: String, action: Callable) -> Button:
	var button := _item(Ui.button(text, action))
	_quit.add_sibling(button)
	_quit.get_parent().move_child(button, _quit.get_index())
	return button


## Says where quitting leads, where that is not the title.
func name_quit(text: String) -> void:
	_quit.text = text


## A row of the menu, as wide as Resume.
static func _item(control: Button) -> Button:
	control.custom_minimum_size = Vector2(520, 88)
	return control


func open() -> void:
	get_tree().paused = true
	visible = true
	_resume.grab_focus()
	if not closes_itself:
		# It opened without this Player asking: a bomb press on its way must not resume the Match.
		_resume.disabled = true
		create_tween().tween_callback(func() -> void: _resume.disabled = false).set_delay(RESUME_DELAY)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(PAUSE_ACTION) or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_resume_or_ask()


func _resume_or_ask() -> void:
	if closes_itself:
		close()
	else:
		resume_pressed.emit()


func close() -> void:
	for child in get_children():
		if child is HowToPlay:  # closed with Start while the card was open
			child.queue_free()
	visible = false
	get_tree().paused = false


func _show_how_to_play() -> void:
	HowToPlay.open_over(self, _resume)
