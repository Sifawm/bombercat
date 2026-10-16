class_name HowToPlay
extends Control
## The design's HowToPlay: the goal, the controls and what each Powerup does, on the sky. Shown
## over the Title screen or the Pause menu, whose place it keeps; closes itself.

signal closed

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const TITLE := Rect2(64, 48, 1792, 106)
const BODY := Rect2(64, 178, 1792, 718)
const BACK := Rect2(64, 932, 360, 88)
## The width of each column of the controls: who, Move, Bomb and Meow.
const COLUMNS: Array[int] = [176, 264, 128, 168]
## Who plays with what, and the keys of each column.
const CONTROLS: Array[Array] = [
	["Player 1", ["W", "A", "S", "D"], ["Space"], ["Q"]],
	["Player 2", ["up", "left", "down", "right"], ["Enter"], ["Right Shift"]],
	["Gamepad", ["Stick", "D-pad"], ["A"], ["X"]],
]
## In catalogue order: id, name, effect.
const POWERUPS: Array[Array] = [
	["yarn_ball", "Yarn Ball", "+1 Bomb Capacity"],
	["tuna_can", "Tuna Can", "+1 Range"],
	["catnip", "Catnip", "Your Cat runs faster"],
	["paw_swipe", "Paw Swipe", "Walk into a Bomb to push it"],
	["nine_lives", "Nine Lives", "Survive one Explosion"],
	["cucumber", "Cucumber", "A Curse for a while: inverted controls or slowness"],
]

var _back: Button


## Shows the card on top of `screen`; the focus goes back to `return_focus` when it closes.
static func open_over(screen: Control, return_focus: Control) -> void:
	var card := HowToPlay.new()
	card.closed.connect(return_focus.grab_focus)
	screen.add_child(card)


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var title := Ui.title("How to Play")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = TITLE.position
	title.size = TITLE.size
	frame.add_child(title)
	var body := HBoxContainer.new()
	body.position = BODY.position
	body.size = BODY.size
	body.add_theme_constant_override("separation", 48)
	body.add_child(_panel(_rules(), 40))
	body.add_child(_panel(_powerups(), 20))
	frame.add_child(body)
	_back = Ui.button("Back", _close)
	_back.position = BACK.position
	_back.size = BACK.size
	# Keeps the focus on the card instead of letting it wander to the buttons underneath.
	for side: String in ["left", "top", "right", "bottom"]:
		_back.set("focus_neighbor_" + side, NodePath("."))
	_back.focus_next = NodePath(".")
	_back.focus_previous = NodePath(".")
	frame.add_child(_back)


func _ready() -> void:
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Audio.play(&"ui_cancel")
	closed.emit()
	queue_free()


## One of the two cream panels, half the body wide, holding `parts` one under another.
static func _panel(parts: Array[Control], separation: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := Ui.surface(Ui.CREAM, false, 40)
	box.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	panel.add_child(column)
	for part in parts:
		column.add_child(part)
	return panel


static func _rules() -> Array[Control]:
	var goal := VBoxContainer.new()
	goal.add_theme_constant_override("separation", 8)
	goal.add_child(_text("Goal", 40, Ui.LILITA))
	var text := _text("Trap the other Cat in your Explosions. First to win %d Rounds wins the Match." % CONFIG.rounds_to_win, 32)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("line_spacing", -5)  # the design's lines, 1.2 apart
	goal.add_child(text)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 24)
	controls.add_child(_text("Controls", 40, Ui.LILITA))
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 24)
	var captions: Array[Control] = [Control.new()]
	for caption: String in ["Move", "Bomb", "Meow"]:
		captions.append(_text(caption, 28))
	# Fredoka's line is taller than the design's 34 px; the row keeps the design's place.
	var caption_row := MarginContainer.new()
	caption_row.add_theme_constant_override("margin_top", -4)
	caption_row.add_theme_constant_override("margin_bottom", -4)
	caption_row.add_child(_row(captions))
	table.add_child(caption_row)
	for at in CONTROLS.size():
		var who: Array = CONTROLS[at]
		var fill := Roster.PLAYER_COLORS[at] if at < 2 else Ui.INK
		var cells: Array[Control] = [Ui.tag(who[0], fill, Ui.CREAM if at == 2 else Ui.INK)]
		for keys: Array in who.slice(1):
			cells.append(Ui.keys(keys))
		table.add_child(_row(cells))
	controls.add_child(table)
	var system := HBoxContainer.new()
	system.add_theme_constant_override("separation", 32)
	system.add_child(Ui.keys(["Esc", "Start"], "Pause"))
	system.add_child(Ui.keys(["F11"], "Fullscreen"))
	var below := MarginContainer.new()
	below.add_theme_constant_override("margin_top", 16)
	below.add_child(system)
	controls.add_child(below)
	return [goal, controls]


static func _powerups() -> Array[Control]:
	var parts: Array[Control] = [_text("Powerups", 40, Ui.LILITA)]
	for powerup in POWERUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % powerup[0])
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.add_child(_text(powerup[1], 32, Ui.LILITA))
		words.add_child(_text(powerup[2], 28))
		row.add_child(words)
		parts.append(row)
	return parts


## A row of the controls, each cell in its column.
static func _row(cells: Array[Control]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	for at in cells.size():
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(COLUMNS[at], 54 if at > 0 or cells[0] is PanelContainer else 34)
		cell.add_child(cells[at])
		cells[at].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cell)
	return row


static func _text(text: String, font_size: int, font: Font = null) -> Label:
	var node := Ui.label(text, font_size, Ui.INK, font)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return node
