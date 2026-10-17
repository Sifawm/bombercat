class_name Movement
extends RefCounted
## Moves a Cat along the grid. A Cat always has at least one coordinate on a whole number
## (it walks along rows and columns), may move freely within Tiles it already overlaps, and
## may only start overlapping a new Tile if that Tile is walkable. That alone gives the Bomb
## rule: its owner overlaps the Bomb's Tile until fully off it, and then cannot re-enter.
## A Cat whose centre reaches the centre of a Portal goes on from the other one.

const EPSILON := 0.0001
const NOT_BLOCKED := Vector2i(-1, -1)


## Returns the Tile that stopped the Cat walking straight ahead, or NOT_BLOCKED.
static func move(cat: CatState, board: Board, direction: Vector2i, distance: float, corner_assist: float) -> Vector2i:
	if cat.tile() != cat.portal_arrival:
		cat.portal_arrival = MapData.NO_TILE
	if direction == Vector2i.ZERO:
		return NOT_BLOCKED
	cat.facing = direction
	var along := 0 if direction.x != 0 else 1
	var across := 1 - along
	var step: int = direction[along]
	var position := cat.position

	# Corner assist: off the row or column it wants to walk along, the Cat first slides to
	# the nearest one (within reach) from which the way ahead is open.
	if absf(position[across] - roundf(position[across])) > EPSILON:
		var ahead := roundi(position[along]) + step
		var lanes: Array[float] = [floorf(position[across]), ceilf(position[across])]
		if position[across] - lanes[0] > lanes[1] - position[across]:
			lanes.reverse()
		var target := NAN
		for lane in lanes:
			var tile := Vector2i.ZERO
			tile[along] = ahead
			tile[across] = int(lane)
			if absf(lane - position[across]) <= corner_assist and board.is_walkable(tile):
				target = lane
				break
		if is_nan(target):
			# Stopped by whatever is ahead on the nearest row or column.
			var obstacle := Vector2i.ZERO
			obstacle[along] = ahead
			obstacle[across] = int(lanes[0])
			return obstacle
		var slide := minf(distance, absf(target - position[across]))
		position[across] = move_toward(position[across], target, slide)
		distance -= slide
		if absf(position[across] - target) > EPSILON:
			cat.position = position
			return NOT_BLOCKED
		position[across] = target
		position = _arrive(cat, board, position)

	while distance > EPSILON:
		var on_centre := absf(position[along] - roundf(position[along])) < EPSILON
		if on_centre:
			position[along] = roundf(position[along])
		# The next Tile centre ahead. Between centres the Cat already overlaps that Tile.
		var next := position[along] + step if on_centre else (ceilf(position[along]) if step > 0 else floorf(position[along]))
		var tile := Vector2i(position.round())
		tile[along] = int(next)
		if on_centre and not board.is_walkable(tile):
			cat.position = position
			return tile
		var travelled := minf(distance, absf(next - position[along]))
		position[along] = move_toward(position[along], next, travelled)
		distance -= travelled
		# Steps of a 32-bit length can end a hair short of the centre: that is reaching it.
		if absf(position[along] - next) < EPSILON:
			position[along] = next
			position = _arrive(cat, board, position)
	cat.position = position
	return NOT_BLOCKED


## Where a Cat whose centre has just reached a Tile centre, `position`, goes on from: the
## other Portal if that Tile is one that may send it there, else where it is.
static func _arrive(cat: CatState, board: Board, position: Vector2) -> Vector2:
	var tile := Vector2i(position.round())
	var exit := board.portal_exit(tile)
	if exit == MapData.NO_TILE or tile == cat.portal_arrival:
		return position
	cat.portal_arrival = exit
	return Vector2(exit)
