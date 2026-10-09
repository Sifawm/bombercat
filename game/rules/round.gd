class_name Round
extends RefCounted
## One fight on a fresh Board. The whole simulation: Players issue commands, `step` advances
## everything by a fixed delta, signals report what happened, and `board`, `cats` and `bombs`
## are there to be read. The same commands on the same steps always give the same Round.

signal bomb_placed(bomb: Bomb)
## A pushed Bomb slid from the Tile `from` onto `bomb.tile`.
signal bomb_moved(bomb: Bomb, from: Vector2i)
signal bomb_detonated(bomb: Bomb, tiles: Array[Vector2i])
signal crate_destroyed(tile: Vector2i)
signal powerup_revealed(tile: Vector2i, powerup: Powerup)
signal powerup_collected(player: int, powerup: Powerup)
signal powerup_destroyed(tile: Vector2i, powerup: Powerup)
signal curse_started(player: int, curse: Curse)
signal curse_ended(player: int, curse: Curse)
signal nine_lives_consumed(player: int)
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

var _random: RandomNumberGenerator
var _moves: Array[Vector2i] = []
var _bomb_requests: Array[bool] = []
## Crates reached by this step's Explosions. They stay on the Board until every Bomb of the
## step has detonated, so a Chain Reaction still clears a single layer of Crates.
var _doomed_crates: Array[Vector2i] = []


## `spawn_points` holds one Spawn Point per Player. `random` decides everything left to
## chance; pass one with a known seed to get a reproducible Round.
func _init(map: MapData, game_config: GameConfig, spawn_points: Array[Vector2i],
		random: RandomNumberGenerator = RandomNumberGenerator.new()) -> void:
	config = game_config
	board = Board.new(map)
	_random = random
	var crates: Array[Vector2i] = []
	for y in map.size.y:
		for x in map.size.x:
			if map.tile_at(Vector2i(x, y)) == MapData.Tile.CRATE:
				crates.append(Vector2i(x, y))
	var hidden := PowerupPool.distribute(map.powerup_pool, crates, _random)
	for tile in hidden:
		board.hidden_powerups[tile] = Powerup.create(hidden[tile])
	time_left = config.round_time
	for tile in spawn_points:
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
	# Reduced to one unit axis step, whatever a controller sends.
	_moves[player] = Vector2i(signi(direction.x), 0) if direction.x != 0 else Vector2i(0, signi(direction.y))


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
		var direction := _moves[player]
		var speed := cat.speed
		if cat.curse != null:
			direction = cat.curse.redirect(direction)
			speed *= cat.curse.speed_factor(config)
		var blocked := Movement.move(cat, board, direction, speed * delta, config.corner_assist)
		if cat.paw_swipe and board.bombs.has(blocked):
			board.bombs[blocked].slide = direction
		_collect(player)
		_tick_effects(player, delta)
	_bomb_requests.fill(false)

	for bomb: Bomb in bombs.duplicate():
		if not bombs.has(bomb):
			continue  # went off in a Chain Reaction earlier in this step
		_slide(bomb, delta)
		bomb.fuse_left -= delta
		if bomb.fuse_left <= 0.0 or board.explosions.has(bomb.tile):
			_detonate(bomb)
	# Powerups come out only now, so the Explosion that broke a Crate cannot destroy what was in it.
	for tile in _doomed_crates:
		board.destroy_crate(tile)
		crate_destroyed.emit(tile)
		if board.hidden_powerups.has(tile):
			board.powerups[tile] = board.hidden_powerups[tile]
			board.hidden_powerups.erase(tile)
			powerup_revealed.emit(tile, board.powerups[tile])
	_doomed_crates.clear()

	for player in cats.size():
		var cat := cats[player]
		if not cat.alive or cat.invulnerable_left > 0.0 or not board.explosions.has(cat.tile()):
			continue
		if cat.nine_lives:
			cat.nine_lives = false
			cat.invulnerable_left = config.nine_lives_invulnerability
			nine_lives_consumed.emit(player)
		else:
			cat.alive = false
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
	# With one Cat left the Round waits for the Explosions to burn out: if they kill that Cat
	# too, both died in the same Explosion and it is a Draw.
	if alive.is_empty():
		_finish(DRAW)
	elif alive.size() == 1 and board.explosions.is_empty():
		_finish(alive[0])
	elif time_left <= 0.0:
		_finish(DRAW)


func _collect(player: int) -> void:
	var cat := cats[player]
	var tile := cat.tile()
	if not board.powerups.has(tile):
		return
	var powerup := board.powerups[tile]
	var curse_before := cat.curse
	board.powerups.erase(tile)
	cat.collected.append(powerup.id)
	powerup.apply(cat, config, _random)
	powerup_collected.emit(player, powerup)
	if cat.curse != curse_before:
		if curse_before != null:
			curse_ended.emit(player, curse_before)
		curse_started.emit(player, cat.curse)


## Runs down the Cat's timed effects.
func _tick_effects(player: int, delta: float) -> void:
	var cat := cats[player]
	cat.invulnerable_left = maxf(cat.invulnerable_left - delta, 0.0)
	if cat.curse != null:
		cat.curse.time_left -= delta
		if cat.curse.time_left <= 0.0:
			var ended := cat.curse
			cat.curse = null
			curse_ended.emit(player, ended)


## Advances a pushed Bomb Tile by Tile until something is in its way.
func _slide(bomb: Bomb, delta: float) -> void:
	if bomb.slide == Vector2i.ZERO:
		return
	bomb.slide_progress += config.bomb_slide_speed * delta
	while bomb.slide != Vector2i.ZERO:
		var next := bomb.tile + bomb.slide
		var cat_in_the_way := cats.any(func(cat: CatState) -> bool: return cat.alive and cat.tile() == next)
		if not board.is_walkable(next) or cat_in_the_way:
			bomb.slide = Vector2i.ZERO
			bomb.slide_progress = 0.0
		elif bomb.slide_progress >= 1.0:
			var from := bomb.tile
			board.bombs.erase(from)
			board.bombs[next] = bomb
			bomb.tile = next
			bomb.slide_progress -= 1.0
			bomb_moved.emit(bomb, from)
		else:
			break


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
				if board.powerups.has(tile):
					powerup_destroyed.emit(tile, board.powerups[tile])
					board.powerups.erase(tile)
				if kind == MapData.Tile.CRATE:
					if not _doomed_crates.has(tile):
						_doomed_crates.append(tile)
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
