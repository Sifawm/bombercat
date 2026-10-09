extends Node
## The game's flow: Title -> Cat Select -> Match -> Match Result. One screen at a time.

const ROUND_VIEW: PackedScene = preload("res://presentation/round_view.tscn")

const FADE_SECONDS := 0.15

var _screen: Node
var _curtain := ColorRect.new()
## The index in Roster.CATS of each Player's Cat, kept for a Rematch.
var _picks: Array[int]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 also works while paused
	LocalPlayerController.register_actions()
	_curtain.color = Color(0.0, 0.0, 0.0, 0.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := CanvasLayer.new()
	top.layer = 10
	top.add_child(_curtain)
	add_child(top)
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11:
		var fullscreen := get_window().mode == Window.MODE_FULLSCREEN
		get_window().mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN


## Fades to black, swaps the screens and fades back in. Menus share one music loop.
func _show(screen: Node, menu_music: bool = true) -> void:
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	var fade := create_tween()
	if _screen != null:
		fade.tween_property(_curtain, "color:a", 1.0, FADE_SECONDS)
	fade.tween_callback(func() -> void:
		if _screen != null:
			_screen.queue_free()
		_screen = screen
		add_child(screen)
		move_child(screen, 0)
		if menu_music:
			Audio.play_music(&"music_menu"))
	fade.tween_property(_curtain, "color:a", 0.0, FADE_SECONDS)


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
	_show(view, false)  # it plays the Round music itself


func _show_match_result(game_match: Match) -> void:
	var result := MatchResult.new(game_match, _picks)
	result.rematch_pressed.connect(_start_match)
	result.cat_select_pressed.connect(_show_cat_select)
	_show(result)
