extends RulesTestCase

const FACE_TO_FACE: PackedStringArray = ["####", "#SS#", "####"]
const CORRIDOR: PackedStringArray = ["#########", "#S.....S#", "#########"]


func test_last_cat_alive_wins_the_round() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.place_bomb(0)
	advance(game_round, 3.1)
	check_eq(events_named("round_ended").size(), 0, "not decided while the Explosion is still lethal")
	advance(game_round, 0.5)
	check_eq(events_named("round_ended"), [["round_ended", 1]], "Player 1 wins")
	check(game_round.finished, "finished")


func test_both_cats_dying_in_the_same_explosion_is_a_draw() -> void:
	var game_round := make_round(FACE_TO_FACE)
	game_round.place_bomb(0)
	advance(game_round, 3.1)
	check_eq(events_named("cat_eliminated").size(), 2, "both Cats died")
	check_eq(events_named("round_ended"), [["round_ended", Round.DRAW]], "Draw")


func test_walking_into_the_explosion_that_killed_the_other_cat_is_a_draw() -> void:
	var game_round := make_round(["#######", "#S..S.#", "#######"])
	game_round.place_bomb(0)
	advance(game_round, 3.1)  # Player 0 died; Player 1 at (4, 1) is one Tile outside Range
	game_round.set_move(1, LEFT)
	advance(game_round, 0.5)
	check_eq(events_named("cat_eliminated").size(), 2, "both Cats died in that Explosion")
	check_eq(events_named("round_ended"), [["round_ended", Round.DRAW]], "Draw")


func test_running_out_of_time_is_a_draw() -> void:
	var config := GameConfig.new()
	config.round_time = 1.0
	var game_round := make_round(CORRIDOR, config)
	advance(game_round, 0.9)
	check_eq(events_named("round_ended").size(), 0, "still running")
	advance(game_round, 0.2)
	check_eq(events_named("round_ended"), [["round_ended", Round.DRAW]], "Draw on time-out")


func test_a_finished_round_ignores_further_steps() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.place_bomb(0)
	advance(game_round, 3.6)
	game_round.set_move(1, LEFT)
	advance(game_round, 1.0)
	check_position(game_round.cats[1], Vector2(7, 1), "the winner no longer moves")
	check_eq(events_named("round_ended").size(), 1, "ended once")


func test_same_commands_produce_the_same_round() -> void:
	var snapshots: Array[String] = []
	for attempt in 2:
		events.clear()
		var game_round := make_round(CORRIDOR)
		game_round.set_move(0, RIGHT)
		advance(game_round, 0.3)
		game_round.place_bomb(0)
		game_round.set_move(1, LEFT)
		advance(game_round, 0.7)
		game_round.set_move(0, LEFT)
		advance(game_round, 3.0)
		snapshots.append(str(events, game_round.cats[0].position, game_round.cats[1].position, game_round.time_left))
	check_eq(snapshots[0], snapshots[1], "identical outcome")
