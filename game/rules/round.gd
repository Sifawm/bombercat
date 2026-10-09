class_name Round
extends RefCounted
## One fight on a fresh Board. The whole simulation: Players issue commands, `step` advances
## everything by a fixed delta, signals report what happened, and `board`, `cats` and `bombs`
## are there to be read. The same commands on the same steps always give the same Round.

signal bomb_placed(bomb: Bomb)
signal bomb_detonated(bomb: Bomb, tiles: Array[Vector2i])
signal crate_destroyed(tile: Vector2i)
signal cat_eliminated(player: int)
## `winner` is a Player index or DRAW.
signal round_ended(winner: int)

const DRAW := -1
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var config: GameConfig
var board: Board
## One per Player, by Player index.
var cats: Array[CatState] = []
## In the order they were placed.
var bombs: Array[Bomb] = []
var time_left: float
var finished := false

var _moves: Array[Vector2i] = []
var _bomb_requests: Array[bool] = []


## `spawn_tiles` holds one Spawn Point per Player.
func _init(map: MapData, game_config: GameConfig, spawn_tiles: Array[Vector2i]) -> void:
	config = game_config
	board = Board.new(map)
	time_left = config.round_time
	for tile in spawn_tiles:
		var cat := CatState.new()
		cat.position = Vector2(tile)
		cat.speed = config.cat_speed
		cat.bomb_capacity = config.bomb_capacity
		cat.bomb_range = config.bomb_range
		cats.append(cat)
		_moves.append(Vector2i.ZERO)
		_bomb_requests.append(false)


## Command: the Player's Cat walks in `direction` (a unit axis vector) until told otherwise;
## Vector2i.ZERO stops it.
func set_move(player: int, direction: Vector2i) -> void:
	_moves[player] = direction


## Command: the Player's Cat places a Bomb on its Tile at the next step, if it can.
func place_bomb(player: int) -> void:
	_bomb_requests[player] = true


func step(delta: float) -> void:
	if finished:
		return
	for player in cats.size():
		var cat := cats[player]
		if not cat.alive:
			continue
		if _bomb_requests[player]:
			_place_bomb(player)
		Movement.move(cat, board, _moves[player], cat.speed * delta, config.corner_assist)
	_bomb_requests.fill(false)

	for bomb: Bomb in bombs.duplicate():
		if not bombs.has(bomb):
			continue  # went off in a Chain Reaction earlier in this step
		bomb.fuse_left -= delta
		if bomb.fuse_left <= 0.0:
			_detonate(bomb)

	for player in cats.size():
		if cats[player].alive and board.explosions.has(cats[player].tile()):
			cats[player].alive = false
			cat_eliminated.emit(player)
	for tile: Vector2i in board.explosions.keys():
		board.explosions[tile] -= delta
		if board.explosions[tile] <= 0.0:
			board.explosions.erase(tile)

	time_left -= delta
	var alive: Array[int] = []
	for player in cats.size():
		if cats[player].alive:
			alive.append(player)
	# ponytail: the Round ends on the step that leaves at most one Cat alive, so only Cats
	# killed on the same step share a Draw. Add a short grace period if near-misses feel unfair.
	if alive.size() <= 1:
		_finish(alive[0] if alive.size() == 1 else DRAW)
	elif time_left <= 0.0:
		_finish(DRAW)


func _place_bomb(player: int) -> void:
	var cat := cats[player]
	var tile := cat.tile()
	if cat.active_bombs >= cat.bomb_capacity or board.bombs.has(tile):
		return
	var bomb := Bomb.new()
	bomb.tile = tile
	bomb.owner = player
	bomb.bomb_range = cat.bomb_range
	bomb.fuse_left = config.fuse
	cat.active_bombs += 1
	bombs.append(bomb)
	board.bombs[tile] = bomb
	bomb_placed.emit(bomb)


## Detonates `first` and, as Chain Reactions, every Bomb its Explosion reaches.
func _detonate(first: Bomb) -> void:
	board.bombs.erase(first.tile)
	var pending: Array[Bomb] = [first]
	while not pending.is_empty():
		var bomb: Bomb = pending.pop_front()
		bombs.erase(bomb)
		cats[bomb.owner].active_bombs -= 1
		var tiles: Array[Vector2i] = [bomb.tile]
		for direction in DIRECTIONS:
			for distance in range(1, bomb.bomb_range + 1):
				var tile := bomb.tile + direction * distance
				var kind := board.tile_at(tile)
				if kind == MapData.Tile.WALL:
					break
				tiles.append(tile)
				if kind == MapData.Tile.CRATE:
					board.destroy_crate(tile)
					crate_destroyed.emit(tile)
					break
				if board.bombs.has(tile):
					pending.append(board.bombs[tile])
					board.bombs.erase(tile)
		for tile in tiles:
			board.explosions[tile] = config.explosion_lifetime
		bomb_detonated.emit(bomb, tiles)


func _finish(winner: int) -> void:
	finished = true
	round_ended.emit(winner)
