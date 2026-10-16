extends RulesTestCase
## The shipped Maps, read through the GridMap loader.


func test_backyard_is_a_valid_13_by_11_map() -> void:
	var scene: PackedScene = load("res://maps/backyard.tscn")
	var node: MapScene = scene.instantiate()
	var map := node.to_map_data()
	node.free()
	check_eq(map.size, Vector2i(13, 11), "size")
	check_eq(map.spawn_points, [Vector2i(1, 1), Vector2i(11, 1), Vector2i(1, 9), Vector2i(11, 9)] as Array[Vector2i],
		"corner Spawn Points")
	check_eq(map.tile_at(Vector2i(2, 2)), MapData.Tile.WALL, "pillars on the checkerboard")
	check_eq(map.tiles.count(MapData.Tile.CRATE), 60, "Crates")
	for y in map.size.y:
		for x in map.size.x:
			var opposite := map.size - Vector2i.ONE - Vector2i(x, y)
			check_eq(map.tile_at(Vector2i(x, y)), map.tile_at(opposite), "point symmetry at (%d, %d)" % [x, y])
	check_eq(map.powerup_pool, {&"yarn_ball": 6, &"tuna_can": 6, &"catnip": 4, &"paw_swipe": 2, &"nine_lives": 1, &"cucumber": 2}
		as Dictionary[StringName, int], "Powerup Pool")
	check_eq(MapValidator.problems(map), PackedStringArray(), "no validation problems")


func test_living_room_is_a_valid_17_by_13_map_for_six() -> void:
	var scene: PackedScene = load("res://maps/living_room.tscn")
	var node: MapScene = scene.instantiate()
	var map := node.to_map_data()
	node.free()
	check_eq(map.size, Vector2i(17, 13), "size")
	check_eq(map.spawn_points.size(), 6, "Spawn Points")
	check_eq(map.tiles.count(MapData.Tile.CRATE), 82, "Crates")
	for y in map.size.y:
		for x in map.size.x:
			check_eq(map.tile_at(Vector2i(x, y)), map.tile_at(Vector2i(map.size.x - 1 - x, y)), "mirrored at (%d, %d)" % [x, y])
			check_eq(map.tile_at(Vector2i(x, y)), map.tile_at(Vector2i(x, map.size.y - 1 - y)), "mirrored at (%d, %d)" % [x, y])
	check_eq(map.powerup_pool, {&"yarn_ball": 8, &"tuna_can": 9, &"catnip": 5, &"paw_swipe": 4, &"nine_lives": 2, &"cucumber": 2}
		as Dictionary[StringName, int], "Powerup Pool")
	check_eq(MapValidator.problems(map), PackedStringArray(), "no validation problems")
