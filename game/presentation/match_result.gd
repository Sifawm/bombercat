class_name MatchResult
extends Control
## The end of a Match: the winning Cat celebrating and what each Player did.

signal rematch_pressed
signal cat_select_pressed

## The buttons wake up late, so a bomb press meant for the Round does not skip the screen.
const BUTTONS_DELAY := 1.0

var _first: Button


## `picks` holds the index in Roster.CATS of each Player's Cat, and `names` what to call
## each Player. A Match that was left has no winner. `back` names the way out of the screen,
## and without `can_rematch` there is no other.
func _init(game_match: Match, picks: Array[int], names: PackedStringArray,
		back: String = "Back to Cat Select", can_rematch: bool = true) -> void:
	var winner := game_match.winner
	var column := Ui.centred_column(self)
	if winner == -1:
		column.add_child(Ui.label("The Match ended without a winner", Ui.TITLE_SIZE))
	else:
		column.add_child(Ui.label("%s wins the Match!" % names[winner], Ui.TITLE_SIZE, Roster.PLAYER_COLORS[winner]))
		var cat := ModelView.new(Roster.cat_scene(picks[winner]), Vector2(360, 420))
		cat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cat.play("win")
		column.add_child(cat)

	var summary := GridContainer.new()
	summary.columns = 1 + picks.size()
	summary.add_theme_constant_override("h_separation", 64)
	summary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	summary.add_child(Control.new())
	for player in picks.size():
		summary.add_child(Ui.label(names[player], 0, Roster.PLAYER_COLORS[player]))
	var rows: Dictionary[String, Array] = {
		"Rounds won": game_match.wins,
		"Bombs placed": game_match.bombs_placed,
		"Crates destroyed": game_match.crates_destroyed,
		"Powerups collected": game_match.powerups_collected,
	}
	for title in rows:
		summary.add_child(Ui.label(title))
		for value: int in rows[title]:
			summary.add_child(Ui.label(str(value)))
	column.add_child(summary)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 32)
	if can_rematch:
		buttons.add_child(Ui.button("Rematch", rematch_pressed.emit))
	buttons.add_child(Ui.button(back, cat_select_pressed.emit))
	_first = buttons.get_child(0)
	column.add_child(buttons)


func _ready() -> void:
	_first.grab_focus()
	Audio.play(&"victory")
	var buttons := _first.get_parent().get_children()
	for button: Button in buttons:
		button.disabled = true
	create_tween().tween_callback(func() -> void:
		for button: Button in buttons:
			button.disabled = false).set_delay(BUTTONS_DELAY)
