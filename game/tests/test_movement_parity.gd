extends RulesTestCase
## Movement against the cases it shares with the server's `movement.ts` (ADR 0004): a client
## predicts its Cat's walk with one and the server walks it with the other, so both must end
## every walk on the same spot.

const CASES := "res://../shared/src/movement-cases.json"


func test_movement_walks_every_shared_case_to_where_the_file_says() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(CASES)))
	check(cases.size() > 100, "the cases were read")
	for walk: Dictionary in cases:
		var board := Board.new(MapData.from_rows(PackedStringArray(walk.rows)))
		for tile: Array in walk.bombs:
			board.bombs[Vector2i(tile[0], tile[1])] = Bomb.new()
		var cat := CatState.new()
		cat.position = Vector2(walk.start[0], walk.start[1])
		var blocked := Movement.NOT_BLOCKED
		for move: Array in walk.moves:
			for step in int(move[2]):
				blocked = Movement.move(cat, board, Vector2i(move[0], move[1]), walk.speed / 60.0, walk.cornerAssist)
		var expected: Dictionary = walk.expected
		var what := "speed %s, assist %s, %s" % [walk.speed, walk.cornerAssist, walk.moves]
		# As a Vector2: the file's numbers are 32-bit ones written out in full, and reading them
		# back as 64-bit is off by less than a 32-bit number can tell.
		check_eq(cat.position, Vector2(expected.position[0], expected.position[1]), what + ": position")
		var expected_blocked := Movement.NOT_BLOCKED if expected.blocked == null \
				else Vector2i(expected.blocked[0], expected.blocked[1])
		check_eq(blocked, expected_blocked, what + ": blocked")
		var expected_arrival := MapData.NO_TILE if expected.arrival == null \
				else Vector2i(expected.arrival[0], expected.arrival[1])
		check_eq(cat.portal_arrival, expected_arrival, what + ": the Portal it came out of")
