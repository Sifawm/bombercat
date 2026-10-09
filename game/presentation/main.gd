extends Node
## The game's flow: Title -> Cat Select -> Match -> Match Result. One screen at a time.

const ROUND_VIEW: PackedScene = preload("res://presentation/round_view.tscn")

var _screen: Node
## The index in Roster.CATS of each Player's Cat, kept for a Rematch.
var _picks: Array[int]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 also works while paused
	LocalPlayerController.register_actions()
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11:
		var fullscreen := get_window().mode == Window.MODE_FULLSCREEN
		get_window().mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN


## The new screen arrives at the end of the frame, so the press that left the previous
## screen is not read again by the new one.
func _show(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child.call_deferred(screen)


func _show_title() -> void:
	var title := TitleScreen.new()
	title.play_pressed.connect(_show_cat_select)
	_show(title)


func _show_cat_select() -> void:
	var cat_select := CatSelect.new()
	cat_select.confirmed.connect(_start_match)
	cat_select.cancelled.connect(_show_title)
	_show(cat_select)


func _start_match(picks: Array[int] = _picks) -> void:
	_picks = picks
	var view: RoundView = ROUND_VIEW.instantiate()
	view.cat_picks = picks
	view.match_finished.connect(_show_match_result)
	view.quit_requested.connect(_show_title)
	_show(view)


func _show_match_result(game_match: Match) -> void:
	var result := MatchResult.new(game_match, _picks)
	result.rematch_pressed.connect(_start_match)
	result.cat_select_pressed.connect(_show_cat_select)
	_show(result)
