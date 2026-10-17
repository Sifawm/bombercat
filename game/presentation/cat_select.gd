class_name CatSelect
extends Control
## The design's CatSelect: both Players choose their Cat at the same time, each with its own
## cursor, using the keys or gamepad they play with: left and right to move, the bomb button to
## confirm. Once both are ready they go on to choose the Map; Map Select's Back brings them here again.

## Emitted once both are ready, with the index in Roster.CATS of each Player's Cat.
signal confirmed(picks: Array[int])
signal cancelled

const PLAYERS := 2
## How long both Cats are seen ready before the Map is chosen.
const READY_SECONDS := 0.6
const TITLE := Rect2(64, 48, 1792, 106)
const ROW := Rect2(64, 178, 1792, 718)
const FOOTER := Rect2(64, 920, 1792, 112)
const CARD := Vector2(272, 448)
const PORTRAIT_HEIGHT := 336
## The keys each Player chooses with, as the footer shows them.
const KEYS: Array[Array] = [[["A", "D"], ["Space"]], [["left", "right"], ["Enter"]]]

## The slot each Player's cursor is on; the one after the last Cat is the Random option.
## A cursor never rests on a Cat the other Player has confirmed: that Cat is locked.
var _cursors: Array[int] = [0, 1]
## Each Player's confirmed Cat, or -1.
var _picks: Array[int] = [-1, -1]
## When each cursor last came to its slot: of two on one card, the later one colours it.
var _arrivals: Array[int] = [0, 1]
var _moves := 1
var _cards: Array[CatCard] = []
var _controls: Array[Control] = []
var _back := Ui.keys(["Esc"], "Back")
var _middle := CenterContainer.new()


func _init() -> void:
	LocalPlayerController.register_actions()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var title := Ui.title("Choose your Cat")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = TITLE.position
	title.size = TITLE.size
	frame.add_child(title)
	var row := HBoxContainer.new()
	row.position = ROW.position
	row.size = ROW.size
	row.add_theme_constant_override("separation", 32)
	for index in Roster.CATS.size() + 1:
		var card := CatCard.new(index if index < Roster.CATS.size() else -1, CARD, PORTRAIT_HEIGHT)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.button.focus_mode = Control.FOCUS_NONE  # the cursors choose, not the focus
		card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.append(card)
		row.add_child(card)
	frame.add_child(row)
	var footer := HBoxContainer.new()
	footer.position = FOOTER.position
	footer.size = FOOTER.size
	for player in PLAYERS:
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 24)
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.alignment = BoxContainer.ALIGNMENT_BEGIN if player == 0 else BoxContainer.ALIGNMENT_END
		var tag := Ui.tag("P%d" % (player + 1), Roster.PLAYER_COLORS[player])
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		controls.add_child(tag)
		controls.add_child(Ui.keys(KEYS[player][0], "Move"))
		controls.add_child(Ui.keys(KEYS[player][1], "Choose"))
		_controls.append(controls)
	footer.add_child(_controls[0])
	_middle.add_child(_back)
	footer.add_child(_middle)
	footer.add_child(_controls[1])
	frame.add_child(footer)
	_refresh()


func _process(_delta: float) -> void:
	var aimed_at := _cursors.duplicate()
	for player in PLAYERS:
		# The second check: the other Player confirmed this Cat first in this very frame.
		if _picks[player] != -1 or _cursors[player] != aimed_at[player]:
			continue
		var step := int(Input.is_action_just_pressed(LocalPlayerController.action(player, "right"))) \
				- int(Input.is_action_just_pressed(LocalPlayerController.action(player, "left")))
		if step != 0:
			_move(player, step)
			Audio.play(&"ui_move")
			_refresh()
		if Input.is_action_just_pressed(LocalPlayerController.action(player, "bomb")):
			_confirm(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _picks.has(-1):  # both ready: already on the way to Map Select
		Audio.play(&"ui_cancel")
		cancelled.emit()


## Moves a cursor one slot, skipping locked Cats.
func _move(player: int, step: int) -> void:
	_cursors[player] = posmod(_cursors[player] + step, _cards.size())
	while _picks.has(_cursors[player]):
		_cursors[player] = posmod(_cursors[player] + step, _cards.size())
	_moves += 1
	_arrivals[player] = _moves


func _confirm(player: int) -> void:
	var pick := _cursors[player]
	if pick == Roster.CATS.size():
		var unlocked: Array = range(Roster.CATS.size()).filter(func(cat: int) -> bool: return not _picks.has(cat))
		pick = unlocked.pick_random()
		_cursors[player] = pick
	_picks[player] = pick
	Audio.play(&"ui_confirm")
	for other in PLAYERS:
		if _picks[other] == -1 and _cursors[other] == pick:
			_move(other, 1)
	_refresh()
	Ui.bounce(_cards[pick].button)  # its dance would jump out of the card
	if not _picks.has(-1):
		set_process(false)
		_go_on()


## A moment to see both Cats ready, then on to choosing the Map.
func _go_on() -> void:
	create_tween().tween_callback(func() -> void: confirmed.emit(_picks)).set_delay(READY_SECONDS)


## Draws each card free, or in the colour of the cursor on it, under the tag of each Player there.
func _refresh() -> void:
	for index in _cards.size():
		var tags: Array[Control] = []
		var colour: Variant = null
		var latest := -1
		for player in PLAYERS:
			if _cursors[player] != index:
				continue
			var tag := Ui.tag("P%d" % (player + 1), Roster.PLAYER_COLORS[player])
			if _picks[player] != -1:
				tag.get_child(0).add_child(Ui.badge("Ready", true))
			tags.append(tag)
			if _arrivals[player] > latest:
				latest = _arrivals[player]
				colour = Roster.PLAYER_COLORS[player]
		_cards[index].show_claim(colour, tags)
