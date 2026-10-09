extends RulesTestCase

const POOL: Dictionary[StringName, int] = {&"yarn_ball": 3, &"tuna_can": 2, &"cucumber": 1}


func crates(count: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for index in count:
		tiles.append(Vector2i(index, 0))
	return tiles


func distribute(random_seed: int, crate_count: int = 20) -> Dictionary[Vector2i, StringName]:
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	return PowerupPool.distribute(POOL, crates(crate_count), random)


func test_every_powerup_of_the_pool_goes_into_its_own_crate() -> void:
	var hidden := distribute(1)
	check_eq(hidden.size(), 6, "six Crates hold a Powerup")
	for powerup: StringName in POOL:
		check_eq(hidden.values().count(powerup), POOL[powerup], "quantity of " + powerup)


func test_the_same_random_source_gives_the_same_distribution() -> void:
	check_eq(distribute(7), distribute(7), "same seed")


func test_positions_change_from_round_to_round() -> void:
	check(distribute(1) != distribute(2), "different seeds give different positions")


func test_a_pool_larger_than_the_crates_fills_them_all() -> void:
	check_eq(distribute(1, 4).size(), 4, "one Powerup per Crate at most")


func test_a_round_hides_the_maps_pool_in_its_crates() -> void:
	var game_round := make_round(["######", "#SxxS#", "######"], GameConfig.new(), {&"yarn_ball": 1, &"tuna_can": 1})
	var hidden: Array[String] = []
	for powerup: Powerup in game_round.board.hidden_powerups.values():
		hidden.append(String(powerup.id))
	hidden.sort()
	check_eq(hidden, ["tuna_can", "yarn_ball"] as Array[String], "both Crates hold one")
