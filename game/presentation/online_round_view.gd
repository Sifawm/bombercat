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
## What this User should know about where it stands: watching, or cut off.
var _standing := Ui.label("", Ui.SMALL_SIZE, Color(1.0, 0.8, 0.3))
## The Admin's way to end the Match, in the pause menu.
var _end_match: Button
## Whether the menu is open on this screen alone, for a User that may not pause the Match.
var _menu_is_own := false


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
		porter.on("roundStarted", _build),
		porter.on("synced", _build),
		porter.on("porter:joined", _build),  # back from a dropped connection
		porter.on("happened", _on_happened),
		porter.on("moved", _on_moved),
		porter.on("meowed", _on_meowed),
	]
	porter.game_changed.connect(_show_pause)
	porter.room_changed.connect(_show_presence.unbind(1))
	porter.connection_changed.connect(_show_presence.unbind(1))
	_pause_menu.closes_itself = false
	_pause_menu.name_quit("Leave the Room")
	_pause_menu.resume_pressed.connect(_request_pause)
	_end_match = _pause_menu.add_action("End the Match", porter.send.bind("porter:endMatch"))
	_standing.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_standing.grow_horizontal = Control.GROW_DIRECTION_BOTH
	$Hud.add_child(_standing)
	super()
	_show_pause(porter.game)


func _exit_tree() -> void:
	super()
	get_tree().paused = false
	for listener in _listeners:
		Online.porter.off(listener)


## Nothing is drawn yet. What this client has of the Round may be from its start, with
## all that happened since unheard, so it asks the server for the Round as it is now.
func start_match() -> void:
	set_process(false)
	set_physics_process(false)
	Online.porter.send("sync")


## Draws the Round the server has just given whole: at its start, on request, or on coming
## back. The Match may be another one by then, with other Players.
func _build(_given: Variant = null) -> void:
	var game: Dictionary = Online.porter.game
	if game.state.round == null or _built_on == Engine.get_process_frames():
		return
	var players := PackedStringArray(game.state.players)
	if _match != null and players == _names and _own == _player_of(game):
		_start_round()
	else:
		_names = players
		_own = _player_of(game)
		config = TUNED
		cat_picks.assign(Array(_names).map(Online.cat_of))
		_controllers.clear()
		for player in _names.size():
			_controllers.append(OnlinePlayerController.new() if player == _own else PlayerController.new())
		map_scene = map_scene_of(game)
		super.start_match()
	set_process(true)
	set_physics_process(true)


## This User's Player index in the Match, or -1: it watches, or it came in under the name
## of a Player that left.
func _player_of(game: Dictionary) -> int:
	var player := PackedStringArray(game.state.players).find(Online.porter.room.you.name)
	return -1 if (game.state.gone as Array).has(float(player)) else player


func _create_match(_map: MapData) -> Match:
	var game_match := match_of(Online.porter.game, config)
	config = game_match.config
	return game_match


func _player_name(player: int) -> String:
	return _names[player]


## The pause is the Room's: any Player, or the Admin, asks for it and for its end, and the
## server decides. A User that only watches gets the menu to itself, to leave by, and the
## Match goes on without it.
func _request_pause() -> void:
	if _own != -1 or Online.porter.room.isAdmin:
		Online.porter.send("resume" if Online.porter.game["match"].status == "paused" else "pause")
	elif _menu_is_own:
		_menu_is_own = false
		_pause_menu.close()
	elif not _pause_menu.visible:
		_menu_is_own = true
		_pause_menu.open()


func _show_pause(game: Variant) -> void:
	if game == null:
		return
	var paused: bool = game["match"].status == "paused"
	if paused and not _pause_menu.visible:
		_pause_menu.open()
	elif not paused and _pause_menu.visible and not _menu_is_own:
		_pause_menu.close()
	_menu_is_own = _menu_is_own and not paused


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
	var before := _round.cats[_own].position
	_controllers[_own].drive(_round, _own)
	Online.porter.send("input", _remote().take_input(_own))
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
	_show_presence()


## Names each Cat after its Player, and says so when that Player's User is away or gone.
func _show_presence() -> void:
	var room: Variant = Online.porter.room
	if room == null or _cat_views.is_empty():
		return
	for player in _cat_views.size():
		var users: Array = (room.users as Array).filter(func(user: Dictionary) -> bool: return user.name == _names[player])
		var left: bool = users.is_empty() or (Online.porter.game.state.gone as Array).has(float(player))
		var presence := " (left)" if left else " (away)" if users[0].status == "reconnecting" else ""
		_cat_views[player].show_name(_names[player] + presence, Roster.PLAYER_COLORS[player])
	_end_match.visible = room.isAdmin  # the Admin may change in the middle of a Match
	if Online.porter.connection.status == "reconnecting":
		_standing.text = "Reconnecting..."
	else:
		_standing.text = "You are watching: you play in the next Match" if _own == -1 else ""


## The server starts the next Round, and ends the Match, when it is time.
func _after_result() -> void:
	pass


func _on_happened(events: Array) -> void:
	if _round == null:
		return  # still waiting for the Round as it is
	_detonations = 0
	_remote().apply_events(events)


func _on_moved(moved: Dictionary) -> void:
	if _round == null:
		return
	var before: Array[Vector2] = []
	for cat in _round.cats:
		before.append(cat.position)
	_remote().apply_moved(moved)
	for player in _round.cats.size():
		if player != _own:  # its own Cat moves when its Inputs are walked
			_cat_moving[player] = _round.cats[player].position != before[player]


func _on_meowed(meowed: Dictionary) -> void:
	if _round != null and int(meowed.player) != _own:
		_cat_views[int(meowed.player)].meow()


func _remote() -> RemoteRound:
	return _round as RemoteRound
