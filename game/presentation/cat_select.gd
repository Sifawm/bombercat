class_name CatSelect
extends Control
## Both Players choose their Cat at the same time, each with its own cursor, using the keys
## or gamepad they play with: left and right to move, the bomb button to confirm.

## Emitted after the countdown with the index in Roster.CATS of each Player's Cat.
signal confirmed(picks: Array[int])
signal cancelled

const PLAYERS := 2
const COUNTDOWN_SECONDS := 3

## The slot each Player's cursor is on; the one after the last Cat is the Random option.
## A cursor never rests on a Cat the other Player has confirmed: that Cat is locked.
var _cursors: Array[int] = [0, 1]
## Each Player's confirmed Cat, or -1.
var _picks: Array[int] = [-1, -1]
var _slots: Array[Control] = []
var _cat_views: Array[ModelView] = []
## Per slot, the marker of each Player.
var _markers: Array[Array] = []
var _status: Label


func _init() -> void:
	LocalPlayerController.register_actions()
	var column := Ui.centred_column(self, 48)
	column.add_child(Ui.label("Choose your Cat", Ui.TITLE_SIZE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	for index in Roster.CATS.size() + 1:
		var slot := VBoxContainer.new()
		var markers := HBoxContainer.new()
		markers.alignment = BoxContainer.ALIGNMENT_CENTER
		markers.custom_minimum_size.y = 60
		_markers.append([])
		for player in PLAYERS:
			var marker := Ui.label("", 0, Roster.PLAYER_COLORS[player])
			markers.add_child(marker)
			_markers[index].append(marker)
		slot.add_child(markers)
		if index < Roster.CATS.size():
			var view := ModelView.new(Roster.cat_scene(index), Vector2(260, 320))
			view.play("idle")
			_cat_views.append(view)
			slot.add_child(view)
			slot.add_child(Ui.label(Roster.cat_name(index)))
		else:
			var question := Ui.label("?", 200)
			question.custom_minimum_size = Vector2(260, 320)
			question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(question)
			slot.add_child(Ui.label("Random"))
		_slots.append(slot)
		row.add_child(slot)
	column.add_child(row)
	_status = Ui.label("")
	column.add_child(_status)
	_refresh()


func _process(_delta: float) -> void:
	for player in PLAYERS:
		if _picks[player] != -1:
			continue
		var step := int(Input.is_action_just_pressed(LocalPlayerController.action(player, "right"))) \
				- int(Input.is_action_just_pressed(LocalPlayerController.action(player, "left")))
		if step != 0:
			_move(player, step)
			_refresh()
		if Input.is_action_just_pressed(LocalPlayerController.action(player, "bomb")):
			_confirm(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()


## Moves a cursor one slot, skipping locked Cats.
func _move(player: int, step: int) -> void:
	_cursors[player] = posmod(_cursors[player] + step, _slots.size())
	while _picks.has(_cursors[player]):
		_cursors[player] = posmod(_cursors[player] + step, _slots.size())


func _confirm(player: int) -> void:
	var pick := _cursors[player]
	if pick == Roster.CATS.size():
		var unlocked: Array = range(Roster.CATS.size()).filter(func(cat: int) -> bool: return not _picks.has(cat))
		pick = unlocked.pick_random()
		_cursors[player] = pick
	_picks[player] = pick
	_cat_views[pick].play("win")
	for other in PLAYERS:
		if _picks[other] == -1 and _cursors[other] == pick:
			_move(other, 1)
	_refresh()
	if not _picks.has(-1):
		set_process(false)
		var countdown := create_tween()
		for second in range(COUNTDOWN_SECONDS, 0, -1):
			countdown.tween_callback(func() -> void: _status.text = "Starting in %d..." % second)
			countdown.tween_interval(0.7)
		countdown.tween_callback(func() -> void: confirmed.emit(_picks))


func _refresh() -> void:
	for index in _slots.size():
		for player in PLAYERS:
			var marker: Label = _markers[index][player]
			marker.visible = _cursors[player] == index
			marker.text = "P%d%s" % [player + 1, " READY" if _picks[player] != -1 else ""]
	_status.text = "Move left or right, confirm with your bomb button"
