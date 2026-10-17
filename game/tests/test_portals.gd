extends RulesTestCase
## Portals: a Cat or a pushed Bomb that reaches one goes on from the other of its colour.

## Two corridors that only the Portals of colour 1 join.
const TWO_CORRIDORS: PackedStringArray = [
	"########",
	"#S.1...#",
	"########",
	"#...1.S#",
	"########",
]


func walker(position: Vector2) -> Array:
	var cat := CatState.new()
	cat.position = position
	return [cat, Board.new(MapData.from_rows(TWO_CORRIDORS))]


func test_a_cat_reaching_the_centre_of_a_portal_comes_out_of_the_other() -> void:
	var walk := walker(Vector2(2, 1))
	var cat: CatState = walk[0]
	Movement.move(cat, walk[1], RIGHT, 0.8, 0.7)
	check_position(cat, Vector2(2.8, 1), "short of the centre, it has not gone through")
	Movement.move(cat, walk[1], RIGHT, 0.7, 0.7)
	check_position(cat, Vector2(4.5, 3), "on from the other Portal, the same way, by what was left of its step")


func test_a_cat_is_not_sent_back_until_it_has_left_the_portal_it_came_out_of() -> void:
	var walk := walker(Vector2(2, 1))
	var cat: CatState = walk[0]
	var board: Board = walk[1]
	Movement.move(cat, board, RIGHT, 1.0, 0.7)
	check_position(cat, Vector2(4, 3), "came out")
	Movement.move(cat, board, RIGHT, 0.3, 0.7)
	Movement.move(cat, board, LEFT, 0.3, 0.7)
	check_position(cat, Vector2(4, 3), "back on the centre without leaving the Tile: it stays")
	Movement.move(cat, board, RIGHT, 0.6, 0.7)
	Movement.move(cat, board, LEFT, 0.6, 0.7)
	check_position(cat, Vector2(3, 1), "having left the Tile, it goes back through")


func test_a_bomb_on_the_other_portal_lets_a_cat_walk_over_this_one() -> void:
	var walk := walker(Vector2(2, 1))
	var cat: CatState = walk[0]
	var board: Board = walk[1]
	board.bombs[Vector2i(4, 3)] = Bomb.new()
	Movement.move(cat, board, RIGHT, 1.5, 0.7)
	check_position(cat, Vector2(3.5, 1), "over the Portal as over Floor")


func test_a_pushed_bomb_goes_through_a_portal_and_slides_on() -> void:
	var game_round := make_round(TWO_CORRIDORS)
	game_round.place_bomb(0)
	advance(game_round, STEP)
	game_round.bombs[0].slide = RIGHT
	advance(game_round, 1.0)
	check_eq(events_named("bomb_moved"), [["bomb_moved", Vector2i(1, 1), Vector2i(2, 1)],
		["bomb_moved", Vector2i(2, 1), Vector2i(3, 1)], ["bomb_moved", Vector2i(3, 1), Vector2i(4, 3)],
		["bomb_moved", Vector2i(4, 3), Vector2i(5, 3)]], "through the Portal, then on until the other Cat")
	check_eq(game_round.bombs[0].tile, Vector2i(5, 3), "stopped beside the other Cat")


func test_a_pushed_bomb_stops_on_a_portal_whose_other_one_is_taken() -> void:
	var game_round := make_round(TWO_CORRIDORS)
	game_round.board.bombs[Vector2i(4, 3)] = Bomb.new()
	game_round.place_bomb(0)
	advance(game_round, STEP)
	game_round.bombs[0].slide = RIGHT
	advance(game_round, 1.0)
	check_eq(game_round.bombs[0].tile, Vector2i(3, 1), "stopped on the Portal it reached")
	check_eq(game_round.bombs[0].slide, Vector2i.ZERO, "at rest")
