extends RulesTestCase

const CORRIDOR: PackedStringArray = ["#########", "#S.....S#", "#########"]

var match_events: Array[int] = []


func make_match(rows: PackedStringArray = CORRIDOR, config: GameConfig = GameConfig.new()) -> Match:
	var game_match := Match.new(MapData.from_rows(rows), config)
	game_match.match_ended.connect(func(winner: int) -> void: match_events.append(winner))
	return game_match


## Plays a Round in which `loser` stands on its own Bomb.
func play_round_lost_by(game_match: Match, loser: int) -> void:
	var game_round := game_match.start_round()
	game_round.place_bomb(loser)
	advance(game_round, 3.6)


func test_winning_a_round_counts_for_the_winner() -> void:
	var game_match := make_match()
	play_round_lost_by(game_match, 0)
	check_eq(game_match.wins, [0, 1] as Array[int], "Player 1 has one win")
	check(not game_match.finished, "one Round does not decide the Match")
	check_eq(match_events, [] as Array[int], "no Match winner yet")


func test_the_first_cat_to_win_two_rounds_wins_the_match() -> void:
	var game_match := make_match()
	play_round_lost_by(game_match, 0)
	play_round_lost_by(game_match, 1)
	check_eq(match_events, [] as Array[int], "1-1 is not decided")
	play_round_lost_by(game_match, 0)
	check_eq(game_match.wins, [1, 2] as Array[int], "wins")
	check_eq(match_events, [1] as Array[int], "Player 1 wins the Match")
	check_eq(game_match.winner, 1, "the Match remembers its winner")
	check(game_match.finished, "finished")


func test_a_draw_awards_no_win_and_is_replayed() -> void:
	var config := GameConfig.new()
	config.round_time = 1.0
	var game_match := make_match(CORRIDOR, config)
	advance(game_match.start_round(), 1.1)
	check_eq(game_match.wins, [0, 0] as Array[int], "nobody won the Draw")
	advance(game_match.start_round(), 1.1)
	advance(game_match.start_round(), 1.1)
	check(not game_match.finished, "Draws never end a Match")
	check_eq(game_match.round_number, 3, "a replayed Draw is another Round")


func test_the_number_of_rounds_to_win_is_tunable() -> void:
	var config := GameConfig.new()
	config.rounds_to_win = 1
	var game_match := make_match(CORRIDOR, config)
	play_round_lost_by(game_match, 1)
	check_eq(match_events, [0] as Array[int], "one win is enough")


func test_cats_start_every_round_on_the_spawn_points_farthest_apart() -> void:
	var game_match := make_match(["#########", "#S.S...S#", "#########"])
	for attempt in 2:
		var game_round := game_match.start_round()
		check_eq(game_round.cats[0].tile(), Vector2i(1, 1), "Player 0")
		check_eq(game_round.cats[1].tile(), Vector2i(7, 1), "Player 1")


func test_every_round_starts_on_the_restored_map() -> void:
	var game_match := make_match(["#########", "#Sx....S#", "#########"])
	play_round_lost_by(game_match, 0)
	var game_round := game_match.start_round()
	check_eq(game_round.board.tile_at(Vector2i(2, 1)), MapData.Tile.CRATE, "the Crate is back")
	check_eq(game_round.bombs.size(), 0, "no Bombs left over")


func test_the_match_adds_up_what_each_player_did_in_every_round() -> void:
	var game_match := make_match(["#########", "#Sx....S#", "#########"])
	play_round_lost_by(game_match, 0)
	play_round_lost_by(game_match, 0)
	check_eq(game_match.bombs_placed, [2, 0] as Array[int], "Bombs placed")
	check_eq(game_match.crates_destroyed, [2, 0] as Array[int], "Crates destroyed")
	check_eq(game_match.powerups_collected, [0, 0] as Array[int], "Powerups collected")
