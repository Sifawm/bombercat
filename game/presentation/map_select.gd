class_name MapSelect
extends Control
## The design's MapSelect: after Cat Select, the local Players choose the Map of their Match.
## Either Player steps through the Maps with left and right and starts with the bomb button;
## the mouse works on the arrows, the thumbnails and the buttons. Nothing takes the focus, so
## the keys only ever mean what the Players' controls say.

signal confirmed(map: String)
signal cancelled

const PLAYERS := 2
const TITLE := Vector2(64, 48)
const PICKER := Rect2(480, 197, 960, 681)
const BACK := Rect2(64, 932, 360, 88)
const START := Rect2(1336, 920, 520, 112)

var _map: String
var _picker := MapPicker.new()


func _init(map: String) -> void:
	_map = map
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var title := Ui.title("Choose a Map")
	title.position = TITLE
	frame.add_child(title)
	_picker.position = PICKER.position
	_picker.size = PICKER.size
	_picker.chosen.connect(_show)
	frame.add_child(_picker)
	var back := Ui.button("Back", _go_back)
	back.position = BACK.position
	back.custom_minimum_size = BACK.size
	frame.add_child(back)
	var start := Ui.button("Start Match", _start, true)
	start.position = START.position
	start.custom_minimum_size = START.size
	frame.add_child(start)
	_show(map)


func _process(_delta: float) -> void:
	for player in PLAYERS:
		var step := int(Input.is_action_just_pressed(LocalPlayerController.action(player, "right"))) \
				- int(Input.is_action_just_pressed(LocalPlayerController.action(player, "left")))
		if step != 0:
			Audio.play(&"ui_move")
			_picker.step(step)
		if Input.is_action_just_pressed(LocalPlayerController.action(player, "bomb")):
			_start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _show(map: String) -> void:
	_map = map
	_picker.show_map(map, true)


func _start() -> void:
	if not is_processing():
		return  # already started
	set_process(false)
	Audio.play(&"ui_confirm")
	confirmed.emit(_map)


func _go_back() -> void:
	Audio.play(&"ui_cancel")
	cancelled.emit()
