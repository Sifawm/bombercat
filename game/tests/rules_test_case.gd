class_name RulesTestCase
extends RefCounted
## Base for tests of the rules layer. Tests build a Round from plain rows, issue commands,
## step it, and check the signals it emitted (recorded in `events`) and its state.

const STEP := 1.0 / 60.0
const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT

var failures: PackedStringArray = []
var events: Array[Array] = []


func check(condition: bool, what: String) -> void:
	if not condition:
		failures.append(what)


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


func check_position(cat: CatState, expected: Vector2, what: String) -> void:
	check(cat.position.distance_to(expected) < 0.001, "%s: expected %s, got %s" % [what, expected, cat.position])


## Cats start on the "S" Tiles in reading order: Player 0 on the first, Player 1 on the second.
func make_round(rows: PackedStringArray, config: GameConfig = GameConfig.new()) -> Round:
	var map := MapData.from_rows(rows)
	var game_round := Round.new(map, config, map.spawn_points)
	game_round.bomb_placed.connect(func(bomb: Bomb) -> void: events.append(["bomb_placed", bomb.tile]))
	game_round.bomb_detonated.connect(
		func(bomb: Bomb, tiles: Array[Vector2i]) -> void: events.append(["bomb_detonated", bomb.tile, tiles]))
	game_round.crate_destroyed.connect(func(tile: Vector2i) -> void: events.append(["crate_destroyed", tile]))
	game_round.cat_eliminated.connect(func(player: int) -> void: events.append(["cat_eliminated", player]))
	game_round.round_ended.connect(func(winner: int) -> void: events.append(["round_ended", winner]))
	return game_round


func advance(game_round: Round, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		game_round.step(STEP)


func events_named(event_name: String) -> Array[Array]:
	return events.filter(func(event: Array) -> bool: return event[0] == event_name)
