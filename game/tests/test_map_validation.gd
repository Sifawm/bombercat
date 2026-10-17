extends RulesTestCase

const GOOD: PackedStringArray = [
	"#######",
	"#S.x.S#",
	"#.#x#.#",
	"#S.x.S#",
	"#######",
]


func problems(rows: PackedStringArray, pool: Dictionary[StringName, int] = {}) -> PackedStringArray:
	var map := MapData.from_rows(rows)
	map.powerup_pool = pool
	return MapValidator.problems(map)


func test_a_sound_map_has_no_problems() -> void:
	check_eq(problems(GOOD, {&"yarn_ball": 2, &"tuna_can": 1}), PackedStringArray(), "no problems")


func test_a_map_needs_two_spawn_points() -> void:
	var found := problems(["#####", "#S..#", "#.#.#", "#####"])
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("at least 2 Spawn Points"), found[0])


func test_a_spawn_point_needs_room_to_escape_its_first_bomb() -> void:
	# The Cat on (1, 1) can only walk right: any Bomb it places there reaches it.
	var found := problems(["#####", "#S.S#", "###.#", "#####"])
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("(1, 1)") and found[0].contains("escape"), found[0])


func test_a_crate_next_to_a_spawn_point_is_not_room() -> void:
	var found := problems(["######", "#S..S#", "#x##.#", "######"])
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("(1, 1)"), found[0])


func test_the_powerup_pool_must_fit_in_the_crates() -> void:
	var found := problems(GOOD, {&"yarn_ball": 2, &"tuna_can": 2})
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("4 Powerups") and found[0].contains("3 Crates"), found[0])


func test_a_map_must_be_enclosed_by_walls() -> void:
	var found := problems(["#####", "#S.S.", "#.#.#", "#####"])
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("(4, 1)") and found[0].contains("Wall"), found[0])


func test_the_powerup_pool_may_only_name_known_powerups() -> void:
	var found := problems(GOOD, {&"yarn_ball": 1, &"laser_pointer": 1})
	check_eq(found.size(), 1, "one problem")
	check(found[0].contains("laser_pointer"), found[0])


func test_each_portal_colour_comes_in_a_pair() -> void:
	check_eq(problems(["#######", "#S1.2S#", "#.#1#.#", "#S.2.S#", "#######"]), PackedStringArray(), "two pairs")
	var found := problems(["#######", "#S1.1S#", "#.#1#.#", "#S.2.S#", "#######"])
	check_eq(found.size(), 2, "three of one colour, one of the other")
	check(found[0].contains("3 Portals of colour 1"), found[0])
	check(found[1].contains("1 Portals of colour 2"), found[1])
