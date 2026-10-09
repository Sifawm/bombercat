extends RulesTestCase

## Player 0 breaks the Crate on (3, 1) from (2, 1) and shelters on (1, 2). Player 1 waits
## on (6, 1), out of reach of a Bomb on the Crate's Tile.
const ONE_CRATE: PackedStringArray = [
	"########",
	"#S.x..S#",
	"#.######",
	"########",
]
const TWO_CRATES: PackedStringArray = [
	"##########",
	"#S.xx...S#",
	"#.########",
	"##########",
]
const HOME := Vector2i(1, 1)


func quick_config() -> GameConfig:
	var config := GameConfig.new()
	config.fuse = 1.0
	return config


## Walks Player 0 along `path`, one Tile per entry, at the default speed.
func walk(game_round: Round, path: Array[Vector2i]) -> void:
	for direction in path:
		game_round.set_move(0, direction)
		advance(game_round, 0.25)
	game_round.set_move(0, Vector2i.ZERO)


## Player 0 goes from HOME to `bomb_tile` along row 1, places a Bomb, shelters on (1, 2)
## until the Explosion is over, and comes back to HOME.
func bomb_from(game_round: Round, bomb_tile: Vector2i) -> void:
	var steps := bomb_tile.x - HOME.x
	var out: Array[Vector2i] = []
	var back: Array[Vector2i] = []
	out.resize(steps)
	out.fill(RIGHT)
	back.resize(steps)
	back.fill(LEFT)
	walk(game_round, out)
	game_round.place_bomb(0)
	walk(game_round, back + ([DOWN] as Array[Vector2i]))
	advance(game_round, 2.0)
	walk(game_round, [UP])


## A Round where the Crate on (3, 1) has just revealed the given Powerup and Player 0 is at HOME.
func round_with_revealed(powerup: StringName, config: GameConfig = quick_config(), random_seed: int = 0) -> Round:
	var game_round := make_round(ONE_CRATE, config, {powerup: 1}, random_seed)
	bomb_from(game_round, Vector2i(2, 1))
	return game_round


## The same, with Player 0 having walked onto (3, 1) and collected it on the way.
func round_with_collected(powerup: StringName, config: GameConfig = quick_config(), random_seed: int = 0) -> Round:
	var game_round := round_with_revealed(powerup, config, random_seed)
	walk(game_round, [RIGHT, RIGHT])
	return game_round


## The same, but Player 0 stops on the very step it collects the Powerup (as it enters the
## Tile), for Powerups that change how it walks.
func round_with_just_collected(powerup: StringName, config: GameConfig = quick_config(), random_seed: int = 0) -> Round:
	var game_round := round_with_revealed(powerup, config, random_seed)
	game_round.set_move(0, RIGHT)
	while events_named("powerup_collected").is_empty():
		game_round.step(STEP)
	game_round.set_move(0, Vector2i.ZERO)
	return game_round


func round_with_curse(curse: StringName, config: GameConfig = quick_config()) -> Round:
	for random_seed in 64:
		events.clear()
		var game_round := round_with_just_collected(&"cucumber", config, random_seed)
		if game_round.cats[0].curse.id == curse:
			return game_round
	check(false, "no seed below 64 gave the Curse " + curse)
	return null


func test_a_destroyed_crate_reveals_its_powerup() -> void:
	var game_round := round_with_revealed(&"yarn_ball")
	check_eq(events_named("powerup_revealed"), [["powerup_revealed", Vector2i(3, 1), &"yarn_ball"]], "revealed")
	check(game_round.board.powerups.has(Vector2i(3, 1)), "lying on the Floor")
	check_eq(events_named("powerup_destroyed").size(), 0, "not destroyed by the Explosion that revealed it")


func test_a_crate_without_a_powerup_reveals_nothing() -> void:
	var game_round := make_round(ONE_CRATE, quick_config())
	bomb_from(game_round, Vector2i(2, 1))
	check_eq(events_named("crate_destroyed").size(), 1, "Crate destroyed")
	check_eq(events_named("powerup_revealed").size(), 0, "nothing inside")


func test_walking_over_a_powerup_collects_it() -> void:
	var game_round := round_with_collected(&"yarn_ball")
	check_eq(events_named("powerup_collected"), [["powerup_collected", 0, &"yarn_ball"]], "collected")
	check(game_round.board.powerups.is_empty(), "gone from the Floor")
	check_eq(game_round.cats[0].collected, [&"yarn_ball"] as Array[StringName], "held by the Cat")


func test_an_explosion_destroys_a_powerup_on_the_floor() -> void:
	var game_round := round_with_revealed(&"yarn_ball")
	bomb_from(game_round, Vector2i(2, 1))
	check_eq(events_named("powerup_destroyed"), [["powerup_destroyed", Vector2i(3, 1), &"yarn_ball"]], "destroyed")
	check(game_round.board.powerups.is_empty(), "gone from the Floor")


func test_yarn_ball_raises_bomb_capacity() -> void:
	var game_round := round_with_collected(&"yarn_ball")
	check_eq(game_round.cats[0].bomb_capacity, 2, "Bomb Capacity")


func test_bomb_capacity_has_a_maximum() -> void:
	var config := quick_config()
	config.max_bomb_capacity = 1
	var game_round := round_with_collected(&"yarn_ball", config)
	check_eq(game_round.cats[0].bomb_capacity, 1, "capped")
	check_eq(events_named("powerup_collected").size(), 1, "still collected")


func test_tuna_can_raises_range() -> void:
	var game_round := round_with_collected(&"tuna_can")
	check_eq(game_round.cats[0].bomb_range, 3, "Range")


func test_range_has_a_maximum() -> void:
	var config := quick_config()
	config.max_bomb_range = 2
	var game_round := round_with_collected(&"tuna_can", config)
	check_eq(game_round.cats[0].bomb_range, 2, "capped")


func test_catnip_makes_a_cat_faster() -> void:
	var config := quick_config()
	config.catnip_speed_gain = 2.0
	var game_round := round_with_just_collected(&"catnip", config)
	var start := game_round.cats[0].position
	game_round.set_move(0, LEFT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], start + Vector2(-1.5, 0), "speed 6 covers 1.5 Tiles in a quarter of a second")


func test_cat_speed_has_a_maximum() -> void:
	var config := quick_config()
	config.catnip_speed_gain = 5.0
	config.max_cat_speed = 4.5
	var game_round := round_with_collected(&"catnip", config)
	check_eq(game_round.cats[0].speed, 4.5, "capped")


func test_nine_lives_absorbs_one_explosion() -> void:
	var game_round := round_with_collected(&"nine_lives")
	check(game_round.cats[0].nine_lives, "holding Nine Lives")
	game_round.place_bomb(0)
	advance(game_round, 1.6)  # the Explosion has come and gone around the Cat
	check_eq(events_named("nine_lives_consumed"), [["nine_lives_consumed", 0]], "absorbed")
	check(game_round.cats[0].alive, "survived the whole Explosion")
	check(not game_round.cats[0].nine_lives, "Nine Lives is spent")
	advance(game_round, 1.0)  # the invulnerability is over too
	game_round.place_bomb(0)
	advance(game_round, 1.1)
	check(not game_round.cats[0].alive, "the next Explosion kills")


func test_nine_lives_does_not_stack() -> void:
	var game_round := make_round(TWO_CRATES, quick_config(), {&"nine_lives": 2})
	bomb_from(game_round, Vector2i(2, 1))
	bomb_from(game_round, Vector2i(3, 1))  # collects the first on the way, reveals the second
	walk(game_round, [RIGHT, RIGHT, RIGHT])
	check_eq(events_named("powerup_collected").size(), 2, "collected both")
	game_round.place_bomb(0)
	advance(game_round, 2.6)  # first Explosion absorbed, invulnerability over
	check(game_round.cats[0].alive, "one Explosion absorbed")
	game_round.place_bomb(0)
	advance(game_round, 1.1)
	check(not game_round.cats[0].alive, "there was no second Nine Lives")


func test_cucumber_puts_a_curse_on_the_cat() -> void:
	var game_round := round_with_collected(&"cucumber")
	check_eq(events_named("curse_started").size(), 1, "cursed")
	check(game_round.cats[0].curse != null, "the Cat carries the Curse")


func test_inverted_controls_reverse_the_cats_direction() -> void:
	var game_round := round_with_curse(&"inverted_controls")
	var start := game_round.cats[0].position
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], start + Vector2(-1, 0), "commanded right, walked a Tile left")


func test_slowness_slows_the_cat() -> void:
	var config := quick_config()
	config.slowness_factor = 0.5
	var game_round := round_with_curse(&"slowness", config)
	var start := game_round.cats[0].position
	game_round.set_move(0, LEFT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], start + Vector2(-0.5, 0), "half a Tile at half speed")


func test_a_curse_ends_after_its_duration() -> void:
	var config := quick_config()
	config.curse_duration = 1.0
	var game_round := round_with_curse(&"inverted_controls", config)
	advance(game_round, 1.1)
	check_eq(events_named("curse_ended"), [["curse_ended", 0, &"inverted_controls"]], "ended")
	check(game_round.cats[0].curse == null, "the Cat is free of it")
	var start := game_round.cats[0].position
	game_round.set_move(0, LEFT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], start + Vector2(-1, 0), "controls are back to normal")


func test_paw_swipe_pushes_a_bomb_until_it_hits_a_wall() -> void:
	var game_round := round_with_collected(&"paw_swipe")
	game_round.place_bomb(0)  # on (3, 1)
	walk(game_round, [RIGHT, LEFT])  # off the Bomb, then into it
	advance(game_round, 0.4)
	check_eq(game_round.bombs[0].tile, Vector2i(1, 1), "slid to the last Tile before the Wall")
	check_eq(events_named("bomb_moved"),
		[["bomb_moved", Vector2i(3, 1), Vector2i(2, 1)], ["bomb_moved", Vector2i(2, 1), Vector2i(1, 1)]], "Tile by Tile")


func test_a_pushed_bomb_stops_at_a_cat() -> void:
	var game_round := round_with_collected(&"paw_swipe")
	game_round.place_bomb(0)  # on (3, 1)
	walk(game_round, [LEFT, RIGHT])
	advance(game_round, 0.4)
	check_eq(game_round.bombs[0].tile, Vector2i(5, 1), "stopped next to Player 1 on (6, 1)")


func test_without_paw_swipe_a_bomb_does_not_move() -> void:
	var game_round := round_with_collected(&"yarn_ball")
	game_round.place_bomb(0)
	walk(game_round, [RIGHT, LEFT])
	advance(game_round, 0.4)
	check_eq(game_round.bombs[0].tile, Vector2i(3, 1), "still where it was placed")
	check_eq(events_named("bomb_moved").size(), 0, "never moved")


func test_paw_swipe_works_when_the_cat_is_slightly_off_the_bombs_row() -> void:
	var game_round := round_with_collected(&"paw_swipe")
	walk(game_round, [LEFT])
	game_round.place_bomb(0)  # on (2, 1)
	walk(game_round, [LEFT])
	game_round.set_move(0, DOWN)
	advance(game_round, 0.075)  # 0.3 Tiles below row 1
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.5)
	check_eq(game_round.bombs[0].tile, Vector2i(5, 1), "pushed all the way to Player 1")


func test_a_pushed_bomb_stops_before_a_tile_a_cat_overlaps() -> void:
	var game_round := round_with_collected(&"paw_swipe")
	game_round.set_move(1, LEFT)
	advance(game_round, 0.1)  # Player 1 at x 5.6, overlapping Tiles 5 and 6
	game_round.set_move(1, Vector2i.ZERO)
	game_round.place_bomb(0)
	walk(game_round, [LEFT, RIGHT])
	advance(game_round, 0.4)
	check_eq(game_round.bombs[0].tile, Vector2i(4, 1), "stopped short of the Cat's body")


func test_an_explosion_destroys_the_powerup_under_its_own_bomb() -> void:
	# Player 1 is walled in on the right, so a Bomb pushed right stops on (4, 1).
	var rows: PackedStringArray = ["########", "#S.xx#S#", "#.######", "########"]
	var game_round: Round
	for random_seed in 64:
		events.clear()
		game_round = make_round(rows, quick_config(), {&"paw_swipe": 1, &"yarn_ball": 1}, random_seed)
		if game_round.board.hidden_powerups[Vector2i(3, 1)].id == &"paw_swipe":
			break
	bomb_from(game_round, Vector2i(2, 1))
	bomb_from(game_round, Vector2i(3, 1))  # collects Paw Swipe on the way, reveals the Yarn Ball on (4, 1)
	walk(game_round, [RIGHT])
	game_round.place_bomb(0)
	walk(game_round, [LEFT, RIGHT, LEFT, DOWN])  # step back, push the Bomb onto the Yarn Ball, shelter
	advance(game_round, 0.5)
	check_eq(events_named("powerup_destroyed"), [["powerup_destroyed", Vector2i(4, 1), &"yarn_ball"]], "destroyed")


func test_a_curse_ends_when_its_cat_dies() -> void:
	var game_round := round_with_curse(&"slowness")
	game_round.place_bomb(0)
	advance(game_round, 1.1)
	check_eq(events_named("cat_eliminated").size(), 1, "died")
	check_eq(events_named("curse_ended").size(), 1, "the Curse ended with it")


func test_an_unknown_powerup_in_the_pool_is_left_out() -> void:
	var game_round := make_round(ONE_CRATE, quick_config(), {&"laser_pointer": 1})
	check(game_round.board.hidden_powerups.is_empty(), "nothing hidden")


func test_a_cat_keeps_count_of_its_bombs_crates_and_powerups() -> void:
	var game_round := round_with_collected(&"yarn_ball")
	check_eq(game_round.cats[0].bombs_placed, 1, "Bombs placed")
	check_eq(game_round.cats[0].crates_destroyed, 1, "Crates destroyed")
	check_eq(game_round.cats[0].collected, [&"yarn_ball"] as Array[StringName], "Powerups collected")
	check_eq(game_round.cats[1].crates_destroyed, 0, "the other Cat destroyed nothing")


func test_a_cat_holds_the_powerups_it_collected() -> void:
	var game_round := round_with_collected(&"yarn_ball")
	check_eq(Powerup.held_by(game_round.cats[0]), [&"yarn_ball"] as Array[StringName], "holding the Yarn Ball")
	check_eq(Powerup.held_by(game_round.cats[1]), [] as Array[StringName], "the other Cat holds nothing")


func test_nine_lives_is_no_longer_held_once_spent() -> void:
	var game_round := round_with_collected(&"nine_lives")
	check_eq(Powerup.held_by(game_round.cats[0]), [&"nine_lives"] as Array[StringName], "held")
	game_round.place_bomb(0)
	advance(game_round, 1.6)
	check_eq(Powerup.held_by(game_round.cats[0]), [] as Array[StringName], "spent")


func test_cucumber_is_held_only_while_its_curse_lasts() -> void:
	var config := quick_config()
	config.curse_duration = 1.0
	var game_round := round_with_collected(&"cucumber", config)
	check_eq(Powerup.held_by(game_round.cats[0]), [&"cucumber"] as Array[StringName], "cursed")
	advance(game_round, 1.1)
	check_eq(Powerup.held_by(game_round.cats[0]), [] as Array[StringName], "the Curse is over")
