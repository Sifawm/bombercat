class_name MatchResult
extends Control
## The design's MatchResult: who won the Match, its Cat celebrating on the Champion plate, and a
## ScoreRow of what each Player did, the winner's raised. A Match that was left has no winner.

signal rematch_pressed
signal cat_select_pressed

## The buttons wake up late, so a bomb press meant for the Round does not skip the screen.
const BUTTONS_DELAY := 1.0
const TITLE := Rect2(0, 48, 1920, 106)
const MAIN := Rect2(64, 178, 1792, 718)
const FOOTER := Rect2(64, 920, 1792, 112)
## The width of each column of the scoreboard: the Player, its Rounds won and three tallies.
const COLUMNS: Array[int] = [380, 200, 180, 180, 180]

var _first: Button
var _buttons: Array[Button] = []


## `picks` holds the index in Roster.CATS of each Player's Cat, and `names` what to call each
## Player. `back` names the way out of the screen beside Rematch; a User that is `waiting_for`
## another to choose for it has neither.
func _init(game_match: Match, picks: Array[int], names: PackedStringArray,
		back: String = "Back to Cat Select", waiting_for: String = "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var winner := game_match.winner
	var title := Ui.title("The Match ended without a winner" if winner == -1 else "%s wins the Match!" % names[winner])
	title.position = TITLE.position
	title.size = TITLE.size
	frame.add_child(title)

	var main := HBoxContainer.new()
	main.position = MAIN.position
	main.size = MAIN.size
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 64)
	if winner != -1:
		main.add_child(_champion(picks[winner], Roster.PLAYER_COLORS[winner]))
	var scoreboard := VBoxContainer.new()
	scoreboard.add_theme_constant_override("separation", 24)
	scoreboard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scoreboard.add_child(_columns())
	var tallies: Array[Array] = [game_match.bombs_placed, game_match.crates_destroyed, game_match.powerups_collected]
	for player in picks.size():
		var row := _score_row(picks[player], names[player], Roster.PLAYER_COLORS[player], player == winner)
		row.get_child(0).add_child(_cell(Ui.pips(game_match.wins[player], game_match.config.rounds_to_win), COLUMNS[1]))
		for at in tallies.size():
			row.get_child(0).add_child(_cell(Ui.label(str(tallies[at][player]), 32, Ui.INK, Ui.LILITA), COLUMNS[2 + at]))
		scoreboard.add_child(row)
	main.add_child(scoreboard)
	frame.add_child(main)

	var footer := HBoxContainer.new()
	footer.position = FOOTER.position
	footer.size = FOOTER.size
	frame.add_child(footer)
	if waiting_for != "":
		var waiting := Ui.label("Waiting for %s to continue..." % waiting_for, 32, Ui.INK, Ui.FREDOKA_SEMIBOLD)
		waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		footer.add_child(waiting)
		return
	var back_button := Ui.button(back, cat_select_pressed.emit)
	back_button.custom_minimum_size = Vector2(360, 88)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN
	footer.add_child(back_button)
	var rematch := Ui.button("Rematch", rematch_pressed.emit, true)
	rematch.custom_minimum_size = Vector2(520, 112)
	footer.add_child(rematch)
	_buttons = [back_button, rematch]
	_first = rematch


func _ready() -> void:
	Audio.play(&"victory")
	if _first == null:
		return
	_first.grab_focus()
	for button in _buttons:
		button.disabled = true
	create_tween().tween_callback(func() -> void:
		for button in _buttons:
			button.disabled = false).set_delay(BUTTONS_DELAY)


## The winning Cat celebrating, standing on the Champion plate in its Player's colour.
static func _champion(pick: int, color: Color) -> VBoxContainer:
	var champion := VBoxContainer.new()
	champion.add_theme_constant_override("separation", 0)
	champion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cat := ModelView.new(Roster.cat_scene(pick), Vector2(312, 481), true)
	cat.play("win")
	champion.add_child(cat)
	var plate := PanelContainer.new()
	var box := Ui.Layers.new()
	box.add(Ui.rounded(Color(Ui.INK, 0.35), 28, 0), Vector2(0, 12))
	var body := Ui.rounded(color, 28, 0)
	body.set_border_width_all(6)
	body.border_color = Ui.INK
	box.add(body)
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	plate.add_theme_stylebox_override("panel", box)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_child(Ui.label("Champion", 40, Ui.INK, Ui.LILITA))
	champion.add_child(plate)
	return champion


## The scoreboard's heading: what each column counts, under its icon.
static func _columns() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	margin.add_child(row)
	var captions: Array[String] = ["", "Rounds won", "Bombs", "Crates", "Powerups"]
	var icons: Array[String] = ["", "", "bomb", "crate", "yarn_ball"]
	for at in COLUMNS.size():
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(COLUMNS[at], 96)
		column.alignment = BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation", 4)
		if icons[at] != "":
			var icon := TextureRect.new()
			icon.texture = load("res://assets/icons/%s.png" % icons[at])
			icon.custom_minimum_size = Vector2(56, 56)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			column.add_child(icon)
		column.add_child(Ui.label(captions[at], 28, Ui.INK, Ui.FREDOKA_MEDIUM))
		row.add_child(column)
	return margin


## The design's ScoreRow, which the winner's raises; its cells go in its first child.
static func _score_row(pick: int, player_name: String, color: Color, won: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var box: StyleBox
	if won:
		box = Ui.claimed(Ui.CREAM, color, 28)
	else:
		var plain := Ui.rounded(Ui.CREAM, 28, 0)
		plain.set_border_width_all(6)
		plain.border_color = color
		box = plain
	box.content_margin_left = 24
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", box)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 0)
	row.add_child(cells)
	var player := HBoxContainer.new()
	player.custom_minimum_size = Vector2(COLUMNS[0], 72)
	player.add_theme_constant_override("separation", 16)
	var portrait := Ui.portrait(Roster.face(pick), 64, 4, color, 28)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player.add_child(portrait)
	var name_label := Ui.label(player_name, 32, Ui.INK, Ui.LILITA)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player.add_child(name_label)
	if won:
		var badge := Ui.badge("Winner", true)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		player.add_child(badge)
	cells.add_child(player)
	return row


## `part` centred in a column `width` wide.
static func _cell(part: Control, width: int) -> CenterContainer:
	var cell := CenterContainer.new()
	cell.custom_minimum_size.x = width
	cell.add_child(part)
	return cell
