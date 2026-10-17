class_name RemoteRound
extends Round
## A Round that is played on the server, as far as this client knows it. It decides nothing:
## the server says where everything is and what happened, and this keeps the Board, the Cats
## and the Bombs as it says, emitting the signals a Round emits. Commands are not carried
## out here; they become the Input sent to the server on each step.
##
## The one thing it does not wait for is the walk of this client's own Cat (ADR 0004). Each
## Input moves that Cat at once, with the Movement the server will move it with. When the
## server says where the Cat was after an Input, the Cat is put there and the Inputs sent
## since are walked again; on the same Board that gives where it already was.

const CURSES := "res://rules/curses/%s.gd"

## The Tile of the Powerup most recently collected: by then its Cat may be elsewhere.
var collected_tile: Vector2i

## The Player whose Cat this client moves ahead of the server, or -1.
var predicted := -1

var _bomb_wanted := false
var _inputs_sent := 0
## The Inputs of `predicted` the server has not answered yet: each its number and its move.
var _unconfirmed: Array[Dictionary] = []
## An Input is for one step, which lasts as long as a Tick of the server.
var _step_seconds := 1.0 / Engine.physics_ticks_per_second


## `snapshot` is the Round as the server's state gives it.
func _init(map: MapData, game_config: GameConfig, snapshot: Dictionary) -> void:
	var cats_at: Array[Vector2i] = []
	cats_at.resize((snapshot.cats as Array).size())
	super(map, game_config, cats_at)
	board.hidden_powerups.clear()  # only the server knows what the Crates hide
	var rows: Array = snapshot.rows
	for y in map.size.y:
		for x in map.size.x:
			if rows[y][x] != "x" and board.tile_at(Vector2i(x, y)) == MapData.Tile.CRATE:
				board.destroy_crate(Vector2i(x, y))
	for lying: Dictionary in snapshot.powerups:
		board.powerups[_tile(lying)] = Powerup.create(lying.id)
	for placed: Dictionary in snapshot.bombs:
		var bomb := _add_bomb(_tile(placed), int(placed.owner), int(placed.range))
		bomb.fuse_left = placed.fuseLeft
		bomb.slide = Vector2i(int(placed.sx), int(placed.sy))
		bomb.slide_progress = placed.progress
	for player in cats.size():
		var known: Dictionary = snapshot.cats[player]
		var cat := cats[player]
		cat.position = Vector2(known.x, known.y)
		cat.facing = Vector2i(int(known.fx), int(known.fy))
		cat.alive = known.alive
		cat.speed = known.speed
		cat.bomb_capacity = int(known.bombCapacity)
		cat.bomb_range = int(known.bombRange)
		cat.active_bombs = int(known.activeBombs)
		cat.bombs_placed = int(known.bombsPlaced)
		cat.crates_destroyed = int(known.cratesDestroyed)
		cat.collected.assign(known.collected)
		cat.paw_swipe = known.pawSwipe
		cat.nine_lives = known.nineLives
		cat.invulnerable_left = known.invulnerableLeft
		if known.curse != null:
			cat.curse = _curse(known.curse.id)
			cat.curse.time_left = known.curse.timeLeft
		cat.portal_arrival = _arrival(known)
	time_left = snapshot.timeLeft
	finished = snapshot.finished


## Emits the signals of what was already on the Board when this Round was built, for
## whoever draws it.
func announce() -> void:
	for bomb in bombs:
		bomb_placed.emit(bomb)
	for tile in board.powerups:
		powerup_revealed.emit(tile, board.powerups[tile])


func place_bomb(_player: int) -> void:
	_bomb_wanted = true


## What `player` asks of its Cat for this step, numbered, to send to the server. The
## predicted Cat walks it at once.
func take_input(player: int) -> Dictionary:
	_inputs_sent += 1
	var input := {"seq": _inputs_sent, "x": _moves[player].x, "y": _moves[player].y, "bomb": _bomb_wanted}
	_bomb_wanted = false
	if player == predicted:
		_unconfirmed.append({"seq": _inputs_sent, "move": _moves[player]})
		_walk(cats[player], _moves[player])
	return input


## Only what runs down between two words from the server, so that it shows smoothly.
func step(delta: float) -> void:
	if finished:
		return
	for bomb in bombs:
		bomb.fuse_left -= delta
	for cat in cats:
		cat.invulnerable_left = maxf(cat.invulnerable_left - delta, 0.0)


## Where everything that moves is after a Tick of the server.
func apply_moved(moved: Dictionary) -> void:
	time_left = moved.timeLeft
	for player in cats.size():
		var known: Dictionary = moved.cats[player]
		cats[player].position = Vector2(known.x, known.y)
		cats[player].facing = Vector2i(int(known.fx), int(known.fy))
		cats[player].portal_arrival = _arrival(known)
	if predicted != -1:
		var answered := int(moved.cats[predicted].seq)
		if answered > _inputs_sent:
			answered = 0  # a number from before this Round was built here: none of these Inputs yet
		_unconfirmed = _unconfirmed.filter(func(input: Dictionary) -> bool: return input.seq > answered)
		for input in _unconfirmed:
			_walk(cats[predicted], input.move)
	for bomb in bombs:
		bomb.slide = Vector2i.ZERO
		bomb.slide_progress = 0.0
	for sliding: Dictionary in moved.sliding:
		var bomb: Bomb = board.bombs.get(_tile(sliding))
		if bomb != null:
			bomb.slide = Vector2i(int(sliding.sx), int(sliding.sy))
			bomb.slide_progress = sliding.progress


## What happened in a Tick of the server, in the order it happened.
func apply_events(events: Array) -> void:
	for event: Dictionary in events:
		match event.type:
			"bombPlaced":
				var owner := int(event.owner)
				cats[owner].active_bombs += 1
				cats[owner].bombs_placed += 1
				bomb_placed.emit(_add_bomb(_tile(event.tile), owner, int(event.range)))
			"bombMoved":
				var bomb := board.bombs[_tile(event.from)]
				board.bombs.erase(bomb.tile)
				bomb.tile = _tile(event.to)
				board.bombs[bomb.tile] = bomb
				bomb_moved.emit(bomb, _tile(event.from))
			"bombDetonated":
				var bomb := board.bombs[_tile(event.tile)]
				board.bombs.erase(bomb.tile)
				bombs.erase(bomb)
				cats[bomb.owner].active_bombs -= 1
				var tiles: Array[Vector2i] = []
				tiles.assign((event.tiles as Array).map(_tile))
				bomb_detonated.emit(bomb, tiles)
			"crateDestroyed":
				board.destroy_crate(_tile(event.tile))
				cats[int(event.owner)].crates_destroyed += 1
				crate_destroyed.emit(_tile(event.tile))
			"powerupRevealed":
				var powerup := Powerup.create(event.powerup)
				board.powerups[_tile(event.tile)] = powerup
				powerup_revealed.emit(_tile(event.tile), powerup)
			"powerupCollected":
				var cat := cats[int(event.player)]
				collected_tile = _tile(event.tile)
				var powerup := board.powerups[collected_tile]
				board.powerups.erase(collected_tile)
				cat.collected.append(powerup.id)
				# Its Curse is the server's to choose; it comes as an event of its own.
				if powerup.id != &"cucumber":
					powerup.apply(cat, config, _random)
				powerup_collected.emit(int(event.player), powerup)
			"powerupDestroyed":
				var powerup := board.powerups[_tile(event.tile)]
				board.powerups.erase(_tile(event.tile))
				powerup_destroyed.emit(_tile(event.tile), powerup)
			"curseStarted":
				var cat := cats[int(event.player)]
				cat.curse = _curse(event.curse)
				cat.curse.time_left = config.curse_duration
				curse_started.emit(int(event.player), cat.curse)
			"curseEnded":
				var cat := cats[int(event.player)]
				var ended := cat.curse
				cat.curse = null
				curse_ended.emit(int(event.player), ended)
			"nineLivesConsumed":
				var cat := cats[int(event.player)]
				cat.nine_lives = false
				cat.invulnerable_left = config.nine_lives_invulnerability
				nine_lives_consumed.emit(int(event.player))
			"catEliminated":
				cats[int(event.player)].alive = false
				cat_eliminated.emit(int(event.player))
			"roundEnded":
				finished = true
				round_ended.emit(int(event.winner))


## One step of a Cat's walk, as `Round.step` walks it.
func _walk(cat: CatState, move: Vector2i) -> void:
	if not cat.alive:
		return
	var speed := cat.speed
	if cat.curse != null:
		move = cat.curse.redirect(move)
		speed *= cat.curse.speed_factor(config)
	Movement.move(cat, board, move, speed * _step_seconds, config.corner_assist)


func _add_bomb(tile: Vector2i, owner: int, bomb_range: int) -> Bomb:
	var bomb := Bomb.new()
	bomb.tile = tile
	bomb.owner = owner
	bomb.bomb_range = bomb_range
	bomb.fuse_left = config.fuse
	bombs.append(bomb)
	board.bombs[tile] = bomb
	return bomb


func _curse(curse_id: String) -> Curse:
	return (load(CURSES % curse_id) as GDScript).new()


## The Portal a Cat the server writes came out of and has not left, or MapData.NO_TILE.
static func _arrival(known: Dictionary) -> Vector2i:
	return MapData.NO_TILE if known.get("arrival") == null else _tile(known.arrival)


## The server writes a Tile as `{ x, y }`, in numbers that arrive as floats.
static func _tile(written: Dictionary) -> Vector2i:
	return Vector2i(int(written.x), int(written.y))
