class_name MatchResult
extends Control
## The end of a Match: the winning Cat celebrating and what each Player did.

signal rematch_pressed
signal cat_select_pressed

var _rematch: Button


## `picks` holds the index in Roster.CATS of each Player's Cat.
func _init(game_match: Match, picks: Array[int]) -> void:
	var winner := game_match.wins.find(game_match.wins.max())
	var column := Ui.centred_column(self)
	column.add_child(Ui.label("%s wins the Match!" % Roster.cat_name(picks[winner]), Ui.TITLE_SIZE,
		Roster.PLAYER_COLORS[winner]))
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
		summary.add_child(Ui.label(Roster.cat_name(picks[player]), 0, Roster.PLAYER_COLORS[player]))
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
	_rematch = Ui.button("Rematch", rematch_pressed.emit)
	buttons.add_child(_rematch)
	buttons.add_child(Ui.button("Back to Cat Select", cat_select_pressed.emit))
	column.add_child(buttons)


func _ready() -> void:
	_rematch.grab_focus()
