class_name Match
extends RefCounted
## A Battle between the same Cats: Rounds on one Map until a Player has won enough of them.
## A Draw awards nothing, so it is simply followed by another Round.

signal match_ended(winner: int)

var config: GameConfig
## Rounds won, by Player index.
var wins: Array[int] = []
## Totals over every Round played so far, by Player index.
var bombs_placed: Array[int] = []
var crates_destroyed: Array[int] = []
var powerups_collected: Array[int] = []
var current_round: Round
var finished := false
## The Player who won the Match, once it is finished.
var winner := -1

var _map: MapData
var _spawn_points: Array[Vector2i]
var _random: RandomNumberGenerator


## `random` is handed to every Round; pass one with a known seed to get a reproducible Match.
func _init(map: MapData, game_config: GameConfig, players: int = 2,
		random: RandomNumberGenerator = RandomNumberGenerator.new()) -> void:
	config = game_config
	_map = map
	_spawn_points = map.farthest_spawn_points(players)
	_random = random
	for tally: Array[int] in [wins, bombs_placed, crates_destroyed, powerups_collected]:
		tally.resize(players)


## Starts the next Round on the restored Map; every Cat is back to its starting abilities.
func start_round() -> Round:
	current_round = Round.new(_map, config, _spawn_points, _random)
	current_round.round_ended.connect(_on_round_ended)
	return current_round


func _on_round_ended(round_winner: int) -> void:
	for player in wins.size():
		var cat := current_round.cats[player]
		bombs_placed[player] += cat.bombs_placed
		crates_destroyed[player] += cat.crates_destroyed
		powerups_collected[player] += cat.collected.size()
	if round_winner == Round.DRAW:
		return
	wins[round_winner] += 1
	if wins[round_winner] >= config.rounds_to_win:
		finished = true
		winner = round_winner
		match_ended.emit(winner)
