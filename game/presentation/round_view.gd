class_name RoundView
extends Node3D
## Presentation of a Match on a Map: places the models where the rules say, turns the rules'
## signals into effects and sound, draws the HUD and shows each Round's result. It decides
## nothing. The countdown is told in the middle of the picture.

signal match_finished(game_match: Match)
signal quit_requested

const CRATE: PackedScene = preload("res://assets/models/crate.glb")

const POWERUP_SCALE := 1.2
const CAMERA_PITCH := deg_to_rad(57.0)
const CAMERA_FOV := 30.0
const RESULT_SECONDS := 2.5
const COUNTDOWN_SECONDS := 3.0
## How long "Go!" stays on screen.
const GO_SECONDS := 0.6
## Seconds an Explosion takes to reach each further Tile, so it grows outwards.
const EXPLOSION_SPREAD := 0.035
const SHAKE := 0.12
## Shake left after one second.
const SHAKE_DECAY := 0.002
## The final elimination: how slow time runs, for how long, and how far the camera closes in.
const SLOW_MOTION_SCALE := 0.3
const SLOW_MOTION_SECONDS := 1.2
const ZOOM_FOV := 20.0
## Seconds left when the timer starts pulsing, and when the music speeds up.
const HURRY_SECONDS := 10
## How much the timer swells at the top of each pulse.
const HURRY_PULSE := 0.25
const FASTER_MUSIC_SECONDS := 30.0
const FASTER_MUSIC := 1.18
## Points checked along each side of the Map when framing it.
const FRAMED_POINTS := 8
## How far the camera may back away to frame the Map, when the HUD leaves it no room.
const MAX_CAMERA_DISTANCE := 100.0
const CONFETTI: Array[Color] = [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.8, 1), Color(0.5, 1, 0.4), Color(1, 0.5, 0.9)]

@export var config: GameConfig
@export var map_scene: PackedScene

## The index in Roster.CATS of each Player's Cat.
var cat_picks: Array[int] = [0, 1]

var _map_node: MapScene
var _match: Match
var _round: Round
var _controllers: Array[PlayerController] = [LocalPlayerController.new(0), LocalPlayerController.new(1)]
## Seconds until the Round starts being stepped.
var _countdown_left := 0.0
var _world: Node3D
var _cat_views: Array[CatView] = []
## Whether each Cat moved in the last rules step.
var _cat_moving: Array[bool] = []
var _bomb_views: Dictionary[Bomb, BombView] = {}
## Pushed Bombs still sliding; their swipe has already sounded and they bounce when they stop.
var _sliding_bombs: Array[Bomb] = []
var _crate_nodes: Dictionary[Vector2i, Node3D] = {}
var _powerup_nodes: Dictionary[Vector2i, Node3D] = {}
var _shake := 0.0
## Bombs detonated in the current rules step; from the second on they sound stronger.
var _detonations := 0
var _slow_motion := false
var _hurry_second := 0
var _music_is_faster := false
var _hud: RoundHud
## The size of the Map the camera frames, framed again when the window changes shape.
var _framed_size := Vector2i.ZERO
var _pause_menu := PauseMenu.new()

@onready var _camera: Camera3D = $Camera
@onready var _result_label: Label = $Hud/Result


func _ready() -> void:
	_pause_menu.quit_to_title.connect(quit_requested.emit)
	get_viewport().size_changed.connect(func() -> void:
		if _framed_size != Vector2i.ZERO:
			_frame_map(_framed_size))
	$Hud.add_child(_pause_menu)
	start_match()


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # in case it leaves in the middle of the slow motion


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(PauseMenu.PAUSE_ACTION):
		get_viewport().set_input_as_handled()
		_request_pause()


func _request_pause() -> void:
	_pause_menu.open()


## What to call a Player on screen.
func _player_name(player: int) -> String:
	return Roster.cat_name(cat_picks[player])


func _create_match(map: MapData) -> Match:
	return Match.new(map, config, cat_picks.size())


func _physics_process(delta: float) -> void:
	if _round.finished:
		return
	if _countdown_left > 0.0:
		_count_down(_countdown_left - delta)
		return
	_clear_go()
	for player in _controllers.size():
		_controllers[player].drive(_round, player)
	var before: Array[Vector2] = []
	for cat in _round.cats:
		before.append(cat.position)
	_detonations = 0
	_round.step(delta)
	for player in _round.cats.size():
		_cat_moving[player] = _round.cats[player].position != before[player]


## Takes the countdown to `left` seconds, showing and sounding each second it crosses.
func _count_down(left: float) -> void:
	var second := ceili(_countdown_left)
	_countdown_left = left
	if _countdown_left > COUNTDOWN_SECONDS:
		pass  # the Cats are still dropping in
	elif _countdown_left <= 0.0:
		_result_label.text = "Go!"
		Audio.play(&"go")
	elif ceili(_countdown_left) != second or _result_label.text == "":
		_result_label.text = str(ceili(_countdown_left))
		Audio.play(&"countdown")


func _clear_go() -> void:
	if _result_label.text == "Go!" and _round.time_left < config.round_time - GO_SECONDS:
		_result_label.text = ""


func _process(delta: float) -> void:
	for player in _cat_views.size():
		var cat := _round.cats[player]
		_cat_views[player].position = _to_world(cat.position)
		_cat_views[player].show_state(cat, _cat_moving[player], cat.speed > config.cat_speed, _round.finished)
		if cat.alive and _countdown_left <= 0.0 and _controllers[player].meows():
			_cat_views[player].meow()
	for bomb in _bomb_views:
		_bomb_views[bomb].position = _to_world(Vector2(bomb.tile) + Vector2(bomb.slide) * bomb.slide_progress)
		_bomb_views[bomb].show_state(bomb, config.fuse)
		if bomb.slide == Vector2i.ZERO and _sliding_bombs.has(bomb):
			_sliding_bombs.erase(bomb)
			_bomb_views[bomb].bounce()
	var seconds_played := Time.get_ticks_msec() / 1000.0
	for tile in _powerup_nodes:
		var node := _powerup_nodes[tile]
		node.position = _to_world(Vector2(tile)) + Vector3.UP * (0.25 + 0.08 * sin(seconds_played * 3.0))
		node.rotation.y = seconds_played * 1.5
	_shake *= pow(SHAKE_DECAY, delta)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake
	_show_time()
	for player in _round.cats.size():
		_hud.show_cat(player, _round.cats[player], config)


## Starts a new Match between the Cats in `cat_picks`.
func start_match() -> void:
	var map_node: MapScene = map_scene.instantiate()
	var map := map_node.to_map_data()
	map_node.free()
	if map.spawn_points.size() < cat_picks.size():
		_result_label.text = "This Map needs %d Spawn Points" % cat_picks.size()
		set_physics_process(false)
		set_process(false)
		return
	_match = _create_match(map)
	if _hud != null:
		_hud.queue_free()
	_hud = RoundHud.new(cat_picks, PackedStringArray(range(cat_picks.size()).map(_player_name)))
	$Hud.add_child(_hud)
	$Hud.move_child(_hud, 0)
	_show_wins()
	_start_round()


func _show_wins() -> void:
	_hud.show_wins(_match.wins, config.rounds_to_win)


## The timer; in the last seconds it turns red, pulses and beeps, and the music speeds up.
func _show_time() -> void:
	var seconds := ceili(maxf(_round.time_left, 0.0))
	var hurry := seconds <= HURRY_SECONDS and not _round.finished
	_hud.show_time(seconds, hurry, HURRY_PULSE * absf(sin(_round.time_left * PI)) if hurry else 0.0)
	if hurry and seconds != _hurry_second:
		_hurry_second = seconds
		Audio.play(&"warning")
	if _round.time_left <= FASTER_MUSIC_SECONDS and not _music_is_faster:
		_music_is_faster = true
		Audio.play_music(&"music_round", FASTER_MUSIC)


func _start_round() -> void:
	if _world != null:
		_world.queue_free()
	_world = Node3D.new()
	add_child(_world)
	_cat_views.clear()
	_cat_moving.clear()
	_bomb_views.clear()
	_sliding_bombs.clear()
	_crate_nodes.clear()
	_powerup_nodes.clear()
	_result_label.text = ""
	_slow_motion = false
	_hurry_second = 0
	_music_is_faster = false
	Audio.play_music(&"music_round")

	_map_node = map_scene.instantiate()
	_world.add_child(_map_node)
	var map := _map_node.to_map_data()
	_map_node.prepare_for_play()
	_frame_map(map.size)
	_countdown_left = CatView.DROP_SECONDS + COUNTDOWN_SECONDS

	_round = _match.start_round()
	_hud.show_round(_match.round_number)
	_round.bomb_placed.connect(_on_bomb_placed)
	_round.bomb_moved.connect(_on_bomb_moved)
	_round.bomb_detonated.connect(_on_bomb_detonated)
	_round.crate_destroyed.connect(_on_crate_destroyed)
	_round.powerup_revealed.connect(_on_powerup_revealed)
	_round.powerup_collected.connect(_on_powerup_collected)
	_round.powerup_destroyed.connect(_on_powerup_destroyed)
	_round.nine_lives_consumed.connect(_on_nine_lives_consumed)
	_round.cat_eliminated.connect(_on_cat_eliminated)
	_round.round_ended.connect(_on_round_ended)

	for y in map.size.y:
		for x in map.size.x:
			if _round.board.tile_at(Vector2i(x, y)) == MapData.Tile.CRATE:
				_crate_nodes[Vector2i(x, y)] = _place(CRATE.instantiate(), Vector2(x, y))
	for player in cat_picks.size():
		var view := CatView.new(Roster.cat_scene(cat_picks[player]))
		_place(view, _round.cats[player].position)
		view.drop()
		_cat_views.append(view)
		_cat_moving.append(false)


## Adds `node` to the Round's world at a position in Tile units, `height` above the Floor.
func _place(node: Node3D, tile_position: Vector2, height: float = 0.0) -> Node3D:
	node.position = _to_world(tile_position) + Vector3.UP * height
	_world.add_child(node)
	return node


func _to_world(tile_position: Vector2) -> Vector3:
	return _map_node.tile_to_local(tile_position)


## Places the camera south of the Map, looking north and down, and backs it away until the
## whole Map is in the picture and clear of the HUD: the outline of its outer Tiles, at the
## foot and at the top of a Wall, is checked point by point.
func _frame_map(map_size: Vector2i) -> void:
	_framed_size = map_size
	var last := Vector2(map_size - Vector2i.ONE)
	var corners: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(last.x + 0.5, -0.5),
			last + Vector2.ONE * 0.5, Vector2(-0.5, last.y + 0.5)]
	var outline: Array[Vector3] = []
	for side in corners.size():
		for step in FRAMED_POINTS:
			var point := _to_world(corners[side].lerp(corners[(side + 1) % corners.size()], float(step) / FRAMED_POINTS))
			outline.append(point)
			outline.append(point + Vector3.UP)
	var picture := get_viewport().get_visible_rect()
	var covered := _hud.covered()
	_camera.fov = CAMERA_FOV
	_camera.rotation = Vector3(-CAMERA_PITCH, 0.0, 0.0)
	var distance := 5.0
	while distance < MAX_CAMERA_DISTANCE:
		_camera.position = _to_world(last / 2.0) + _camera.basis.z * distance
		if outline.all(_is_clear.bind(picture, covered)):
			break
		distance += 0.25


## Whether `point` is seen in the picture, outside every part of it the HUD covers.
func _is_clear(point: Vector3, picture: Rect2, covered: Array[Rect2]) -> bool:
	if _camera.is_position_behind(point):
		return false
	var seen := _camera.unproject_position(point)
	return picture.has_point(seen) and covered.all(func(rect: Rect2) -> bool: return not rect.has_point(seen))


func _on_bomb_placed(bomb: Bomb) -> void:
	var view := BombView.new()
	_place(view, Vector2(bomb.tile))
	_bomb_views[bomb] = view
	_cat_views[bomb.owner].play("place_bomb")
	Audio.play(&"place_bomb")


## The rules report every Tile a pushed Bomb crosses; the swipe sounds on the first.
func _on_bomb_moved(bomb: Bomb, _from: Vector2i) -> void:
	if not _sliding_bombs.has(bomb):
		_sliding_bombs.append(bomb)
		Audio.play(&"paw_swipe")


func _on_bomb_detonated(bomb: Bomb, tiles: Array[Vector2i]) -> void:
	_bomb_views[bomb].queue_free()
	_bomb_views.erase(bomb)
	_sliding_bombs.erase(bomb)
	_detonations += 1
	_shake += SHAKE
	Audio.play(&"explosion" if _detonations == 1 else &"explosion_chain")

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 6.0
	flash.omni_range = bomb.bomb_range + 2.0
	_place(flash, Vector2(bomb.tile), 1.0)
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.3)
	fade.tween_callback(flash.queue_free)

	for tile in tiles:
		var reach := (tile - bomb.tile).length() * EXPLOSION_SPREAD
		var explosion := MeshInstance3D.new()
		explosion.mesh = preload("res://presentation/explosion_mesh.tres")
		explosion.scale = Vector3.ZERO
		_place(explosion, Vector2(tile), 0.35)
		var tween := explosion.create_tween()
		tween.tween_interval(reach)
		tween.tween_callback(func() -> void:
			_place(Effects.burst(Color(1.0, 0.6, 0.15), 6, 4.0, 0.35, 0.12), Vector2(tile), 0.4)
			_place(Effects.burst(Color(0.3, 0.3, 0.3, 0.45), 4, 0.8, 0.9, 0.2, Vector3.UP * 2.0), Vector2(tile), 0.5))
		tween.tween_property(explosion, "scale", Vector3.ONE, 0.08)
		tween.tween_interval(maxf(config.explosion_lifetime - 0.16 - reach, 0.0))
		tween.tween_property(explosion, "scale", Vector3.ZERO, 0.08)
		tween.tween_callback(explosion.queue_free)


func _on_crate_destroyed(tile: Vector2i) -> void:
	_crate_nodes[tile].queue_free()
	_crate_nodes.erase(tile)
	_place(Effects.burst(Color(0.75, 0.5, 0.25), 12, 4.5, 0.6, 0.22), Vector2(tile), 0.5)
	Audio.play(&"crate_break")


## A Powerup's model is the GLB named after its id. It pops out of its Crate and glows.
func _on_powerup_revealed(tile: Vector2i, powerup: Powerup) -> void:
	var scene: PackedScene = load("res://assets/models/%s.glb" % powerup.id)
	var node := _place(scene.instantiate(), Vector2(tile))
	node.add_child(Effects.glow(Color(1.0, 1.0, 0.7, 0.18), 0.32))
	node.scale = Vector3.ZERO
	node.create_tween().tween_property(node, "scale", Vector3.ONE * POWERUP_SCALE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_powerup_nodes[tile] = node


## The collected Powerup rises over the Cat and shrinks away. A Powerup sounds like the
## others unless there is a "collect_<id>" sound of its own.
func _on_powerup_collected(player: int, powerup: Powerup) -> void:
	var node := _take_powerup_node(_collected_tile(player))
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position:y", node.position.y + 1.6, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(node.queue_free)
	var own_sound := StringName("collect_" + powerup.id)
	Audio.play(own_sound if Audio.has(own_sound) else &"powerup")


## The Tile of the Powerup a Player's Cat has just collected.
func _collected_tile(player: int) -> Vector2i:
	return _round.cats[player].tile()


func _on_powerup_destroyed(tile: Vector2i, _powerup: Powerup) -> void:
	_take_powerup_node(tile).queue_free()
	_place(Effects.burst(Color(1.0, 1.0, 0.6), 10, 3.0, 0.4, 0.1), Vector2(tile), 0.4)


## Hands over the node of the Powerup on `tile`, which stops floating.
func _take_powerup_node(tile: Vector2i) -> Node3D:
	var node := _powerup_nodes[tile]
	_powerup_nodes.erase(tile)
	return node


func _on_nine_lives_consumed(player: int) -> void:
	_place(Effects.burst(Color(1.0, 0.85, 0.3), 16, 4.0, 0.5, 0.12), _round.cats[player].position, 0.5)
	Audio.play(&"nine_lives")


func _on_cat_eliminated(player: int) -> void:
	_cat_views[player].play("die")
	Audio.play(&"death")
	var alive := _round.cats.filter(func(cat: CatState) -> bool: return cat.alive).size()
	if alive <= 1 and not _slow_motion:
		_show_final_elimination(_to_world(_round.cats[player].position))


## A moment of slow motion while the camera closes in on where the Cat fell. Only the
## pace of the rules' steps changes, never their time step.
func _show_final_elimination(where: Vector3) -> void:
	_slow_motion = true
	Engine.time_scale = SLOW_MOTION_SCALE
	var framed := _camera.position
	var closer := framed + (where - _to_world(Vector2(_round.board.size - Vector2i.ONE) / 2.0)) * 0.5
	var tween := create_tween().set_ignore_time_scale().set_parallel()
	tween.tween_property(_camera, "fov", ZOOM_FOV, 0.3)
	tween.tween_property(_camera, "position", closer, 0.3)
	tween.chain().tween_interval(SLOW_MOTION_SECONDS - 0.3)
	tween.tween_callback(func() -> void: Engine.time_scale = 1.0)
	# Back to the whole Map, so the winner is in the picture for its celebration.
	tween.tween_property(_camera, "fov", CAMERA_FOV, 0.3)
	tween.parallel().tween_property(_camera, "position", framed, 0.3)


func _on_round_ended(winner: int) -> void:
	if winner == Round.DRAW:
		_hud.show_result(winner, -1, "", _match.round_number)
		for player in _round.cats.size():
			if _round.cats[player].alive:
				_cat_views[player].play("idle")
	else:
		_hud.show_result(winner, cat_picks[winner], _player_name(winner), _match.round_number)
		_cat_views[winner].play("win")
		_throw_confetti()
		Audio.play(&"victory")
	_show_wins()
	# A tween, not a SceneTree timer: it stops with the Pause menu and dies with this node.
	create_tween().tween_callback(_after_result).set_delay(RESULT_SECONDS)


## Coloured paper falling over the whole picture until the next Round's world replaces it.
func _throw_confetti() -> void:
	var confetti := CPUParticles2D.new()
	var picture := get_viewport().get_visible_rect().size
	confetti.position = Vector2(picture.x / 2.0, -20.0)
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(picture.x / 2.0, 1.0)
	confetti.amount = 160
	confetti.lifetime = 3.0
	confetti.direction = Vector2.DOWN
	confetti.spread = 30.0
	confetti.initial_velocity_min = 200.0
	confetti.initial_velocity_max = 500.0
	confetti.gravity = Vector2(0.0, 300.0)
	confetti.angular_velocity_max = 360.0
	confetti.scale_amount_min = 10.0
	confetti.scale_amount_max = 18.0
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array(range(CONFETTI.size()).map(func(index: int) -> float: return float(index) / CONFETTI.size()))
	colors.colors = PackedColorArray(CONFETTI)
	confetti.color_initial_ramp = colors
	var layer := CanvasLayer.new()
	layer.layer = -1  # behind the HUD
	layer.add_child(confetti)
	_world.add_child(layer)


func _after_result() -> void:
	if _match.finished:
		match_finished.emit(_match)
	else:
		_start_round()
