extends RulesTestCase

const CORRIDOR: PackedStringArray = [
	"#######",
	"#S...S#",
	"#######",
]
const CORNER: PackedStringArray = [
	"#####",
	"#S..#",
	"#.#.#",
	"#..S#",
	"#####",
]


func test_cat_walks_at_its_speed() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.5)
	check_position(game_round.cats[0], Vector2(3, 1), "speed 4 for half a second")
	check_eq(game_round.cats[0].facing, RIGHT, "facing")


func test_cat_stops_when_the_command_stops() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	game_round.set_move(0, Vector2i.ZERO)
	advance(game_round, 0.5)
	check_position(game_round.cats[0], Vector2(2, 1), "stopped after one Tile")


func test_wall_blocks_a_cat() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.set_move(0, LEFT)
	game_round.set_move(1, RIGHT)
	advance(game_round, 0.5)
	check_position(game_round.cats[0], Vector2(1, 1), "Wall on the left")
	check_position(game_round.cats[1], Vector2(5, 1), "Wall on the right")


func test_crate_blocks_a_cat() -> void:
	var game_round := make_round(["#######", "#S.x.S#", "#######"])
	game_round.set_move(0, RIGHT)
	advance(game_round, 1.0)
	check_position(game_round.cats[0], Vector2(2, 1), "stopped before the Crate")


func test_cats_do_not_block_each_other() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.set_move(0, RIGHT)
	advance(game_round, 2.0)
	check_position(game_round.cats[0], Vector2(5, 1), "walked onto the other Cat's Tile")


func test_turning_late_slides_back_into_the_corridor() -> void:
	var game_round := make_round(CORNER)
	game_round.set_move(0, DOWN)
	advance(game_round, 0.1)  # 0.4 Tiles past the corridor of row 1
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)  # one Tile of travel: 0.4 back up, 0.6 right
	check_position(game_round.cats[0], Vector2(1.6, 1), "slid back to row 1 then right")


func test_turning_early_slides_on_to_the_far_corridor() -> void:
	var game_round := make_round(CORNER)
	game_round.set_move(0, DOWN)
	advance(game_round, 0.35)  # at y 2.4: row 2 is nearest but (2, 2) is a Wall; row 3 is 0.6 away
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], Vector2(1.4, 3), "slid on to row 3 then right")


func test_no_corner_assist_beyond_its_reach() -> void:
	var config := GameConfig.new()
	config.corner_assist = 0.5
	var game_round := make_round(CORNER, config)
	game_round.set_move(0, DOWN)
	advance(game_round, 0.35)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	check_position(game_round.cats[0], Vector2(1, 2.4), "row 3 is out of reach, so the Cat stays")


func test_owner_leaves_its_bomb_tile_but_cannot_return() -> void:
	var game_round := make_round(CORRIDOR)
	game_round.place_bomb(0)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.5)
	check_position(game_round.cats[0], Vector2(3, 1), "walked off its own Bomb")
	game_round.set_move(0, LEFT)
	advance(game_round, 1.0)
	check_position(game_round.cats[0], Vector2(2, 1), "the Bomb's Tile is closed behind it")


func test_bomb_blocks_the_other_cat() -> void:
	var game_round := make_round(["#######", "#S.S..#", "#######"])
	game_round.place_bomb(0)
	game_round.set_move(1, LEFT)
	advance(game_round, 1.0)
	check_position(game_round.cats[1], Vector2(2, 1), "stopped next to the Bomb")
