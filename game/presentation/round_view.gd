class_name RoundView
extends Node3D
## Presentation of a Match on a Map: places the models where the rules say, plays the Cats'
## animations, draws the HUD and shows each Round's result. It decides nothing.

signal match_finished(game_match: Match)
signal quit_requested

const CRATE: PackedScene = preload("res://assets/models/crate.glb")
const BOMB: PackedScene = preload("res://assets/models/bomb.glb")

## The Cat models are about 1.2 m tall; this fits them to a 1 m Tile.
const CAT_SCALE := 0.72
const BOMB_SCALE := 0.8
const POWERUP_SCALE := 1.2
const CAMERA_PITCH := deg_to_rad(57.0)
const RESULT_SECONDS := 2.5
const COUNTDOWN_SECONDS := 3.0
## How long "Go!" stays on screen.
const GO_SECONDS := 0.6
const PORTRAIT_SIZE := Vector2(120, 120)

@export var config: GameConfig
@export var map_scene: PackedScene

## The index in Roster.CATS of each Player's Cat.
var cat_picks: Array[int] = [0, 1]

var _map_node: MapScene
var _match: Match
var _round: Round
## Seconds until the Round starts being stepped.
var _countdown_left := 0.0
var _hud_players: Control
var _wins_labels: Array[Label] = []
var _held_labels: Array[Label] = []
var _pause_menu := PauseMenu.new()
var _controllers: Array[PlayerController] = [LocalPlayerController.new(0), LocalPlayerController.new(1)]
var _world: Node3D
var _cat_nodes: Array[Node3D] = []
var _cat_animations: Array[AnimationPlayer] = []
## Whether each Cat moved in the last rules step.
var _cat_moving: Array[bool] = []
var _bomb_nodes: Dictionary[Bomb, Node3D] = {}
var _crate_nodes: Dictionary[Vector2i, Node3D] = {}
var _powerup_nodes: Dictionary[Vector2i, Node3D] = {}

@onready var _camera: Camera3D = $Camera
@onready var _timer_label: Label = $Hud/Timer
@onready var _result_label: Label = $Hud/Result


func _ready() -> void:
	_pause_menu.quit_to_title.connect(quit_requested.emit)
	$Hud.add_child(_pause_menu)
	start_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(PauseMenu.PAUSE_ACTION):
		get_viewport().set_input_as_handled()
		_pause_menu.open()


func _physics_process(delta: float) -> void:
	if _round.finished:
		return
	if _countdown_left > 0.0:
		_countdown_left -= delta
		_result_label.text = str(ceili(_countdown_left)) if _countdown_left > 0.0 else "Go!"
		return
	if _result_label.text == "Go!" and _round.time_left < config.round_time - GO_SECONDS:
		_result_label.text = ""
	for player in _controllers.size():
		_controllers[player].drive(_round, player)
	var before: Array[Vector2] = []
	for cat in _round.cats:
		before.append(cat.position)
	_round.step(delta)
	for player in _round.cats.size():
		_cat_moving[player] = _round.cats[player].position != before[player]


func _process(_delta: float) -> void:
	for player in _cat_nodes.size():
		_show_cat(player)
	for bomb in _bomb_nodes:
		var node := _bomb_nodes[bomb]
		node.scale = Vector3.ONE * BOMB_SCALE * _bomb_pulse(bomb)
		node.position = _to_world(Vector2(bomb.tile) + Vector2(bomb.slide) * bomb.slide_progress)
	var seconds_played := Time.get_ticks_msec() / 1000.0
	for tile in _powerup_nodes:
		var node := _powerup_nodes[tile]
		node.position = _to_world(Vector2(tile)) + Vector3.UP * (0.25 + 0.08 * sin(seconds_played * 3.0))
		node.rotation.y = seconds_played * 1.5
	var seconds := ceili(maxf(_round.time_left, 0.0))
	_timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	for player in _held_labels.size():
		_held_labels[player].text = _held_text(_round.cats[player])


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
	_match = Match.new(map, config, cat_picks.size())
	_build_hud()
	_start_round()


## One panel per Player along the top: portrait, Cat name, Rounds won and Powerups held.
func _build_hud() -> void:
	if _hud_players != null:
		_hud_players.queue_free()
	_wins_labels.clear()
	_held_labels.clear()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 520)  # leaves the middle to the timer
	_hud_players = row
	$Hud.add_child(row)
	$Hud.move_child(row, 0)
	for player in cat_picks.size():
		var panel := HBoxContainer.new()
		var portrait := ModelView.new(Roster.cat_scene(cat_picks[player]), PORTRAIT_SIZE)
		portrait.play("idle")
		var texts := VBoxContainer.new()
		texts.custom_minimum_size.x = 480
		var wins := Ui.label("", 0, Roster.PLAYER_COLORS[player])
		var held := Ui.label("", Ui.SMALL_SIZE)
		texts.add_child(wins)
		texts.add_child(held)
		_wins_labels.append(wins)
		_held_labels.append(held)
		panel.add_child(portrait)
		panel.add_child(texts)
		if player % 2 == 1:
			panel.move_child(portrait, 1)  # mirrored on the right-hand side
		row.add_child(panel)
	_show_wins()


func _show_wins() -> void:
	for player in _wins_labels.size():
		_wins_labels[player].text = "%s   %d / %d" % [
			Roster.cat_name(cat_picks[player]), _match.wins[player], config.rounds_to_win]


func _held_text(cat: CatState) -> String:
	var held: PackedStringArray = ["Bombs %d" % cat.bomb_capacity, "Range %d" % cat.bomb_range]
	if cat.collected.has(&"catnip"):
		held.append("Catnip x%d" % cat.collected.count(&"catnip"))
	if cat.paw_swipe:
		held.append("Paw Swipe")
	if cat.nine_lives:
		held.append("Nine Lives")
	if cat.curse != null:
		held.append("Cursed!")
	return "  ".join(held)


func _start_round() -> void:
	if _world != null:
		_world.queue_free()
	_world = Node3D.new()
	add_child(_world)
	_cat_nodes.clear()
	_cat_animations.clear()
	_cat_moving.clear()
	_bomb_nodes.clear()
	_crate_nodes.clear()
	_powerup_nodes.clear()
	_result_label.text = ""

	_map_node = map_scene.instantiate()
	_world.add_child(_map_node)
	var map := _map_node.to_map_data()
	_map_node.prepare_for_play()
	_frame_map(map.size)
	_countdown_left = COUNTDOWN_SECONDS

	_round = _match.start_round()
	_round.bomb_placed.connect(_on_bomb_placed)
	_round.bomb_detonated.connect(_on_bomb_detonated)
	_round.crate_destroyed.connect(_on_crate_destroyed)
	_round.powerup_revealed.connect(_on_powerup_revealed)
	_round.powerup_collected.connect(_on_powerup_collected)
	_round.powerup_destroyed.connect(_on_powerup_destroyed)
	_round.cat_eliminated.connect(_on_cat_eliminated)
	_round.round_ended.connect(_on_round_ended)

	for y in map.size.y:
		for x in map.size.x:
			if map.tile_at(Vector2i(x, y)) == MapData.Tile.CRATE:
				_crate_nodes[Vector2i(x, y)] = _place(CRATE, Vector2i(x, y))
	for player in cat_picks.size():
		var node := _place(Roster.cat_scene(cat_picks[player]), _round.cats[player].tile())
		node.scale = Vector3.ONE * CAT_SCALE
		var animations: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false)[0]
		for looping: String in ["idle", "walk"]:
			animations.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
		animations.play("idle")
		_cat_nodes.append(node)
		_cat_animations.append(animations)
		_cat_moving.append(false)


func _place(scene: PackedScene, tile: Vector2i) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.position = _to_world(Vector2(tile))
	_world.add_child(node)
	return node


func _to_world(tile_position: Vector2) -> Vector3:
	return _map_node.tile_to_local(tile_position)


## Places the camera south of the Map, looking north and down, and backs it away until
## the whole Map (with a margin) is inside the view.
func _frame_map(map_size: Vector2i) -> void:
	var last := Vector2(map_size - Vector2i.ONE)
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(last.x + 1, -1), Vector2(-1, last.y + 1), last + Vector2.ONE]:
		corners.append(_to_world(corner))
		corners.append(_to_world(corner) + Vector3.UP)
	_camera.rotation = Vector3(-CAMERA_PITCH, 0.0, 0.0)
	var distance := 5.0
	while true:
		_camera.position = _to_world(last / 2.0) + _camera.basis.z * distance
		if corners.all(_camera.is_position_in_frustum):
			break
		distance += 0.25


func _show_cat(player: int) -> void:
	var cat := _round.cats[player]
	var node := _cat_nodes[player]
	var animations := _cat_animations[player]
	node.position = _to_world(cat.position)
	node.rotation.y = atan2(cat.facing.x, cat.facing.y)  # the models face +Z (south)
	var busy := animations.is_playing() and animations.current_animation in ["place_bomb", "die"]
	if cat.alive and not busy and not _round.finished:
		animations.play("walk" if _cat_moving[player] else "idle")


## Scale factor of a Bomb: a throb whose rate depends only on the Fuse left, from 1.5 beats
## a second when placed to 7 just before it detonates.
func _bomb_pulse(bomb: Bomb) -> float:
	var elapsed := config.fuse - bomb.fuse_left
	var beats := 1.5 * elapsed + (7.0 - 1.5) * elapsed * elapsed / (2.0 * config.fuse)
	return 1.0 + 0.12 * sin(TAU * beats)


func _on_bomb_placed(bomb: Bomb) -> void:
	_bomb_nodes[bomb] = _place(BOMB, bomb.tile)
	_cat_animations[bomb.owner].play("place_bomb")


func _on_bomb_detonated(bomb: Bomb, tiles: Array[Vector2i]) -> void:
	_bomb_nodes[bomb].queue_free()
	_bomb_nodes.erase(bomb)
	for tile in tiles:
		var explosion := MeshInstance3D.new()
		explosion.mesh = preload("res://presentation/explosion_mesh.tres")
		explosion.position = _to_world(Vector2(tile)) + Vector3(0.0, 0.35, 0.0)
		explosion.scale = Vector3.ONE * 0.3
		_world.add_child(explosion)
		var tween := explosion.create_tween()
		tween.tween_property(explosion, "scale", Vector3.ONE, 0.08)
		tween.tween_interval(config.explosion_lifetime - 0.16)
		tween.tween_property(explosion, "scale", Vector3.ZERO, 0.08)
		tween.tween_callback(explosion.queue_free)


func _on_crate_destroyed(tile: Vector2i) -> void:
	_crate_nodes[tile].queue_free()
	_crate_nodes.erase(tile)


## A Powerup's model is the GLB named after its id.
func _on_powerup_revealed(tile: Vector2i, powerup: Powerup) -> void:
	var scene: PackedScene = load("res://assets/models/%s.glb" % powerup.id)
	var node := _place(scene, tile)
	node.scale = Vector3.ONE * POWERUP_SCALE
	_powerup_nodes[tile] = node


func _on_powerup_collected(player: int, _powerup: Powerup) -> void:
	_remove_powerup(_round.cats[player].tile())


func _on_powerup_destroyed(tile: Vector2i, _powerup: Powerup) -> void:
	_remove_powerup(tile)


func _remove_powerup(tile: Vector2i) -> void:
	_powerup_nodes[tile].queue_free()
	_powerup_nodes.erase(tile)


func _on_cat_eliminated(player: int) -> void:
	_cat_animations[player].play("die")


func _on_round_ended(winner: int) -> void:
	if winner == Round.DRAW:
		_result_label.text = "Draw!"
		for player in _round.cats.size():
			if _round.cats[player].alive:
				_cat_animations[player].play("idle")
	else:
		_result_label.text = "%s wins the Round!" % Roster.cat_name(cat_picks[winner])
		_cat_animations[winner].get_animation("win").loop_mode = Animation.LOOP_LINEAR
		_cat_animations[winner].play("win")
	_show_wins()
	# A tween, not a SceneTree timer: it stops with the Pause menu and dies with this node.
	create_tween().tween_callback(_after_result).set_delay(RESULT_SECONDS)


func _after_result() -> void:
	if _match.finished:
		match_finished.emit(_match)
	else:
		_start_round()
