class_name OnlineRoundView
extends RoundView
## The Round view of a Match played in a Room. The server plays the Match: this draws what
## it says, sends it what this browser's Player asks of its Cat, and waits for it to start
## each Round and to end the Match.

const TUNED: GameConfig = preload("res://config/game_config.tres")

## This User's Player index, or -1 when it only watches.
var _own := -1
var _names: PackedStringArray
var _listeners: Array[int] = []
## The frame the Round on screen was built in: the server's word for it may come twice.
var _built_on := -1


## The Match of the Room as it is, and the Map it is played on.
static func match_of(game: Dictionary, tuned: GameConfig) -> RemoteMatch:
	var settings: Dictionary = game.settings
	var game_config: GameConfig = tuned.duplicate()
	game_config.round_time = settings.roundTime
	game_config.rounds_to_win = int(settings.roundsToWin)
	var map_node: MapScene = map_scene_of(game).instantiate()
	var map := map_node.to_map_data()
	map_node.free()
	return RemoteMatch.new(map, game_config, game.state)


static func map_scene_of(game: Dictionary) -> PackedScene:
	return load("res://maps/%s.tscn" % game.settings.map)


func _ready() -> void:
	var porter := Online.porter
	_listeners = [
		porter.on("roundStarted", _on_round_started),
		porter.on("porter:joined", _on_round_started),  # back from a dropped connection
		porter.on("happened", _on_happened),
		porter.on("moved", _on_moved),
		porter.on("meowed", _on_meowed),
	]
	porter.game_changed.connect(_show_pause)
	_pause_menu.closes_itself = false
	_pause_menu.name_quit("Leave the Room")
	_pause_menu.resume_pressed.connect(_request_pause)
	super()
	_show_pause(porter.game)


func _exit_tree() -> void:
	super()
	get_tree().paused = false
	for listener in _listeners:
		Online.porter.off(listener)


func start_match() -> void:
	var game: Dictionary = Online.porter.game
	_names = PackedStringArray(game.state.players)
	config = TUNED
	_own = _names.find(Online.porter.room.you.name)
	cat_picks.assign(Array(_names).map(Online.cat_of))
	_controllers.clear()
	for player in _names.size():
		_controllers.append(OnlinePlayerController.new() if player == _own else PlayerController.new())
	map_scene = map_scene_of(game)
	super()


func _create_match(_map: MapData) -> Match:
	var game_match := match_of(Online.porter.game, config)
	config = game_match.config
	return game_match


func _player_name(player: int) -> String:
	return _names[player]


## The pause is the Room's: any Player asks for it, and for its end, and the server decides.
func _request_pause() -> void:
	Online.porter.send("togglePause")


func _show_pause(game: Variant) -> void:
	if game == null:
		return
	var paused: bool = game["match"].status == "paused"
	if paused and not _pause_menu.visible:
		_pause_menu.open()
	elif not paused and _pause_menu.visible:
		_pause_menu.close()


func _collected_tile(_player: int) -> Vector2i:
	return _remote().collected_tile


func _physics_process(delta: float) -> void:
	if _round.finished:
		return
	var left := maxf(Online.porter.timer_remaining("countdown") / 1000.0, 0.0)
	if left > 0.0 or _countdown_left > 0.0:
		_count_down(left)
		return
	_clear_go()
	if _own == -1 or not _round.cats[_own].alive:
		_round.step(delta)
		return
	_controllers[_own].drive(_round, _own)
	Online.porter.send("input", _remote().take_input(_own))
	var before := _round.cats[_own].position
	_round.step(delta)
	_cat_moving[_own] = _round.cats[_own].position != before


func _process(delta: float) -> void:
	super(delta)
	if _own != -1 and _round.cats[_own].alive and _countdown_left <= 0.0 and _controllers[_own].meows():
		Online.porter.send("meow")


func _start_round() -> void:
	_built_on = Engine.get_process_frames()
	(_match as RemoteMatch).state = Online.porter.game.state
	super()
	_show_wins()
	if Online.porter.timer_remaining("countdown") < 0.0:
		_countdown_left = 0.0  # joined with the Round already going
	for player in _cat_views.size():
		_cat_views[player].visible = _round.cats[player].alive
	_remote().predicted = _own
	_remote().announce()


## The server starts the next Round, and ends the Match, when it is time.
func _after_result() -> void:
	pass


func _on_round_started(_state: Variant) -> void:
	if _built_on != Engine.get_process_frames() and Online.porter.game.state.round != null:
		_start_round()


func _on_happened(events: Array) -> void:
	_detonations = 0
	_remote().apply_events(events)


func _on_moved(moved: Dictionary) -> void:
	var before: Array[Vector2] = []
	for cat in _round.cats:
		before.append(cat.position)
	_remote().apply_moved(moved)
	for player in _round.cats.size():
		if player != _own:  # its own Cat moves when its Inputs are walked
			_cat_moving[player] = _round.cats[player].position != before[player]


func _on_meowed(meowed: Dictionary) -> void:
	if int(meowed.player) != _own:
		_cat_views[int(meowed.player)].meow()


func _remote() -> RemoteRound:
	return _round as RemoteRound
