extends RulesTestCase

const LONG_CORRIDOR: PackedStringArray = [
	"#########",
	"#S.....S#",
	"#########",
]
## Player 0 can hide at the bottom of the left column; Player 1 waits on the right.
const SHELTER: PackedStringArray = [
	"########",
	"#S....S#",
	"#.######",
	"#.######",
	"#.######",
	"########",
]


func test_bomb_is_placed_on_the_cats_tile() -> void:
	var game_round := make_round(LONG_CORRIDOR)
	game_round.place_bomb(0)
	advance(game_round, STEP)
	check_eq(events_named("bomb_placed"), [["bomb_placed", Vector2i(1, 1)]], "placed")
	check_eq(game_round.bombs.size(), 1, "Bombs on the Board")


func test_bomb_capacity_limits_bombs_on_the_map() -> void:
	var game_round := make_round(LONG_CORRIDOR)
	game_round.place_bomb(0)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	game_round.place_bomb(0)
	advance(game_round, STEP)
	check_eq(events_named("bomb_placed").size(), 1, "Bomb Capacity 1 allows a single Bomb")


func test_bomb_explodes_when_its_fuse_ends() -> void:
	var game_round := make_round(LONG_CORRIDOR)
	game_round.place_bomb(0)
	game_round.set_move(0, RIGHT)
	advance(game_round, 2.9)
	check_eq(events_named("bomb_detonated").size(), 0, "still fused at 2.9 s")
	advance(game_round, 0.2)
	var detonations := events_named("bomb_detonated")
	check_eq(detonations.size(), 1, "detonated by 3.1 s")
	var tiles: Array[Vector2i] = detonations[0][2]
	tiles.sort()
	check_eq(tiles, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i],
		"Range 2 along the corridor, stopped by the Walls around it")
	check(game_round.cats[0].alive, "the owner escaped beyond Range")


func test_capacity_is_restored_after_the_explosion() -> void:
	var game_round := make_round(LONG_CORRIDOR)
	game_round.place_bomb(0)
	game_round.set_move(0, RIGHT)
	advance(game_round, 3.1)
	game_round.place_bomb(0)
	advance(game_round, STEP)
	check_eq(events_named("bomb_placed").size(), 2, "second Bomb after the first exploded")


func test_explosion_destroys_the_first_crate_and_stops() -> void:
	var config := GameConfig.new()
	config.bomb_range = 3
	var game_round := make_round(["########", "#S.x..S#", "########"], config)
	game_round.place_bomb(0)
	advance(game_round, 3.1)
	check_eq(events_named("crate_destroyed"), [["crate_destroyed", Vector2i(3, 1)]], "Crate destroyed")
	check_eq(game_round.board.tile_at(Vector2i(3, 1)), MapData.Tile.FLOOR, "the Crate's Tile is now Floor")
	var tiles: Array[Vector2i] = events_named("bomb_detonated")[0][2]
	check(tiles.has(Vector2i(3, 1)), "the Crate's Tile is in the Explosion")
	check(not tiles.has(Vector2i(4, 1)), "the Tile behind the Crate is not")


func test_explosion_detonates_other_bombs_immediately() -> void:
	var config := GameConfig.new()
	config.bomb_capacity = 2
	var game_round := make_round(LONG_CORRIDOR, config)
	game_round.place_bomb(0)
	game_round.set_move(0, RIGHT)
	advance(game_round, 0.25)
	game_round.place_bomb(0)  # on (2, 1), a quarter of a second behind the first
	advance(game_round, 2.8)  # 3.05 s: only the first Fuse has ended
	check_eq(events_named("bomb_detonated").size(), 2, "Chain Reaction")
	check_eq(game_round.bombs.size(), 0, "no Bombs left")


func test_own_explosion_kills_the_owner() -> void:
	var game_round := make_round(LONG_CORRIDOR)
	game_round.place_bomb(0)
	advance(game_round, 3.1)
	check_eq(events_named("cat_eliminated"), [["cat_eliminated", 0]], "killed by its own Bomb")
	check(not game_round.cats[0].alive, "not alive")


func test_explosion_stays_lethal_for_its_lifetime() -> void:
	var game_round := make_round(SHELTER)
	game_round.place_bomb(0)
	game_round.set_move(0, DOWN)
	game_round.set_move(1, LEFT)
	advance(game_round, 0.5)  # Player 1 waits at (4, 1), just outside Range
	game_round.set_move(1, Vector2i.ZERO)
	advance(game_round, 2.6)
	check_eq(events_named("cat_eliminated").size(), 0, "nobody was in the Explosion")
	game_round.set_move(1, LEFT)
	advance(game_round, 0.2)
	check_eq(events_named("cat_eliminated"), [["cat_eliminated", 1]], "walked into fresh fire")


func test_explosion_is_safe_after_its_lifetime() -> void:
	var game_round := make_round(SHELTER)
	game_round.place_bomb(0)
	game_round.set_move(0, DOWN)
	advance(game_round, 3.7)  # detonation at 3.0 s plus the 0.5 s lifetime
	game_round.set_move(1, LEFT)
	advance(game_round, 1.0)
	check_eq(events_named("cat_eliminated").size(), 0, "the Explosion is over")
