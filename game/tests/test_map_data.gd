extends RulesTestCase

const FOUR_CORNERS: PackedStringArray = [
	"#######",
	"#S.x.S#",
	"#.....#",
	"#S...S#",
	"#######",
]


func test_rows_describe_floor_walls_crates_and_spawn_points() -> void:
	var map := MapData.from_rows(FOUR_CORNERS)
	check_eq(map.size, Vector2i(7, 5), "size")
	check_eq(map.tile_at(Vector2i(0, 0)), MapData.Tile.WALL, "Wall")
	check_eq(map.tile_at(Vector2i(3, 1)), MapData.Tile.CRATE, "Crate")
	check_eq(map.tile_at(Vector2i(1, 1)), MapData.Tile.FLOOR, "a Spawn Point is Floor")
	check_eq(map.tile_at(Vector2i(-1, 9)), MapData.Tile.WALL, "outside the Map counts as Wall")
	check_eq(map.spawn_points.size(), 4, "Spawn Points")


func test_two_players_get_the_spawn_points_farthest_apart() -> void:
	var map := MapData.from_rows(FOUR_CORNERS)
	check_eq(map.farthest_spawn_points(2), [Vector2i(1, 1), Vector2i(5, 3)] as Array[Vector2i], "opposite corners")
