extends Node3D
## Minimal presentation of Rounds on a placeholder Map: places the models where the rules
## say, plays the Cats' animations and shows the result. It decides nothing.

const PLACEHOLDER_MAP: PackedStringArray = [
	"#############",
	"#S.xxxxxxx.S#",
	"#.#x#x#x#x#.#",
	"#xxxxx.xxxxx#",
	"#x#x#.#.#x#x#",
	"#xxx.....xxx#",
	"#x#x#.#.#x#x#",
	"#xxxxx.xxxxx#",
	"#.#x#x#x#x#.#",
	"#S.xxxxxxx.S#",
	"#############",
]
const CATS: Array[Dictionary] = [
	{"name": "Turing", "scene": preload("res://assets/models/turing.glb")},
	{"name": "Berni", "scene": preload("res://assets/models/berni.glb")},
]
const FLOORS: Array[PackedScene] = [preload("res://assets/models/floor_a.glb"), preload("res://assets/models/floor_b.glb")]
const WALL_BRICK: PackedScene = preload("res://assets/models/wall_brick.glb")
const WALL_PILLAR: PackedScene = preload("res://assets/models/wall_pillar.glb")
const CRATE: PackedScene = preload("res://assets/models/crate.glb")
const BOMB: PackedScene = preload("res://assets/models/bomb.glb")

## The Cat models are about 1.2 m tall; this fits them to a 1 m Tile.
const CAT_SCALE := 0.72
const BOMB_SCALE := 0.8
const CAMERA_PITCH := deg_to_rad(57.0)
const RESULT_SECONDS := 2.5

@export var config: GameConfig

var _map := MapData.from_rows(PLACEHOLDER_MAP)
var _round: Round
var _controllers: Array[PlayerController] = [LocalPlayerController.new(0), LocalPlayerController.new(1)]
var _world: Node3D
var _cat_nodes: Array[Node3D] = []
var _cat_animations: Array[AnimationPlayer] = []
var _bomb_nodes: Dictionary[Bomb, Node3D] = {}
var _crate_nodes: Dictionary[Vector2i, Node3D] = {}

@onready var _camera: Camera3D = $Camera
@onready var _timer_label: Label = $Hud/Timer
@onready var _result_label: Label = $Hud/Result


func _ready() -> void:
	_frame_map()
	_start_round()


func _physics_process(delta: float) -> void:
	if _round.finished:
		return
	for player in _controllers.size():
		_controllers[player].drive(_round, player)
	_round.step(delta)


func _process(_delta: float) -> void:
	for player in _cat_nodes.size():
		_show_cat(player)
	for bomb in _bomb_nodes:
		_bomb_nodes[bomb].scale = Vector3.ONE * BOMB_SCALE * _bomb_pulse(bomb)
	var seconds := ceili(maxf(_round.time_left, 0.0))
	_timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]


func _start_round() -> void:
	if _world != null:
		_world.queue_free()
	_world = Node3D.new()
	add_child(_world)
	_cat_nodes.clear()
	_cat_animations.clear()
	_bomb_nodes.clear()
	_crate_nodes.clear()
	_result_label.text = ""

	_round = Round.new(_map, config, _map.farthest_spawn_points(CATS.size()))
	_round.bomb_placed.connect(_on_bomb_placed)
	_round.bomb_detonated.connect(_on_bomb_detonated)
	_round.crate_destroyed.connect(_on_crate_destroyed)
	_round.cat_eliminated.connect(_on_cat_eliminated)
	_round.round_ended.connect(_on_round_ended)

	for y in _map.size.y:
		for x in _map.size.x:
			var tile := Vector2i(x, y)
			_spawn(FLOORS[(x + y) % 2], tile)
			match _map.tile_at(tile):
				MapData.Tile.WALL:
					var on_border := x == 0 or y == 0 or x == _map.size.x - 1 or y == _map.size.y - 1
					_spawn(WALL_BRICK if on_border else WALL_PILLAR, tile)
				MapData.Tile.CRATE:
					_crate_nodes[tile] = _spawn(CRATE, tile)
	for player in CATS.size():
		var scene: PackedScene = CATS[player].scene
		var node := _spawn(scene, _round.cats[player].tile())
		node.scale = Vector3.ONE * CAT_SCALE
		var animations: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false)[0]
		for looping: String in ["idle", "walk"]:
			animations.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
		animations.play("idle")
		_cat_nodes.append(node)
		_cat_animations.append(animations)


func _spawn(scene: PackedScene, tile: Vector2i) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.position = _to_world(Vector2(tile))
	_world.add_child(node)
	return node


## Tile coordinates to world: x runs east, y runs south, one Tile per metre.
func _to_world(tile_position: Vector2) -> Vector3:
	return Vector3(tile_position.x, 0.0, tile_position.y)


## Places the camera south of the Map, looking north and down, and backs it away until
## the whole Map (with a margin) is inside the view.
func _frame_map() -> void:
	var last := Vector2(_map.size - Vector2i.ONE)
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
	var target := _to_world(cat.position)
	var moved := not node.position.is_equal_approx(target)
	node.position = target
	node.rotation.y = atan2(cat.facing.x, cat.facing.y)  # the models face +Z (south)
	var busy := animations.is_playing() and animations.current_animation in ["place_bomb", "die"]
	if cat.alive and not busy:
		animations.play("walk" if moved else "idle")


## Scale factor of a Bomb: a throb whose rate depends only on the Fuse left, from 1.5 beats
## a second when placed to 7 just before it detonates.
func _bomb_pulse(bomb: Bomb) -> float:
	var elapsed := config.fuse - bomb.fuse_left
	var beats := 1.5 * elapsed + (7.0 - 1.5) * elapsed * elapsed / (2.0 * config.fuse)
	return 1.0 + 0.12 * sin(TAU * beats)


func _on_bomb_placed(bomb: Bomb) -> void:
	_bomb_nodes[bomb] = _spawn(BOMB, bomb.tile)
	_cat_animations[bomb.owner].play("place_bomb")


func _on_bomb_detonated(bomb: Bomb, tiles: Array[Vector2i]) -> void:
	_bomb_nodes[bomb].queue_free()
	_bomb_nodes.erase(bomb)
	for tile in tiles:
		var fire := MeshInstance3D.new()
		fire.mesh = preload("res://presentation/explosion_mesh.tres")
		fire.position = _to_world(Vector2(tile)) + Vector3(0.0, 0.35, 0.0)
		fire.scale = Vector3.ONE * 0.3
		_world.add_child(fire)
		var tween := fire.create_tween()
		tween.tween_property(fire, "scale", Vector3.ONE, 0.08)
		tween.tween_interval(config.explosion_lifetime - 0.16)
		tween.tween_property(fire, "scale", Vector3.ZERO, 0.08)
		tween.tween_callback(fire.queue_free)


func _on_crate_destroyed(tile: Vector2i) -> void:
	_crate_nodes[tile].queue_free()
	_crate_nodes.erase(tile)


func _on_cat_eliminated(player: int) -> void:
	_cat_animations[player].play("die")


func _on_round_ended(winner: int) -> void:
	if winner == Round.DRAW:
		_result_label.text = "Draw!"
	else:
		_result_label.text = "%s wins!" % CATS[winner].name
		_cat_animations[winner].get_animation("win").loop_mode = Animation.LOOP_LINEAR
		_cat_animations[winner].play("win")
	await get_tree().create_timer(RESULT_SECONDS).timeout
	_start_round()
