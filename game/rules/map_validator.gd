@tool
class_name MapValidator
extends RefCounted
## Finds what would make a Map unplayable. Map Studio shows these as warnings.


static func problems(map: MapData) -> PackedStringArray:
	var found: PackedStringArray = []
	if map.spawn_points.size() < 2:
		found.append("A Map needs at least 2 Spawn Points; this one has %d." % map.spawn_points.size())

	# A Cat escapes its first Bomb around a corner, so it needs an L of free Tiles.
	var is_free := func(tile: Vector2i) -> bool: return map.tile_at(tile) == MapData.Tile.FLOOR
	for point in map.spawn_points:
		var sideways: bool = is_free.call(point + Vector2i.LEFT) or is_free.call(point + Vector2i.RIGHT)
		var upright: bool = is_free.call(point + Vector2i.UP) or is_free.call(point + Vector2i.DOWN)
		if not (sideways and upright):
			found.append(("The Spawn Point at %s has no room to escape its first Bomb: "
				+ "it needs a free Tile beside it and another above or below it.") % point)

	var powerups := 0
	for amount: int in map.powerup_pool.values():
		powerups += amount
	var crates := map.tiles.count(MapData.Tile.CRATE)
	if powerups > crates:
		found.append("The Powerup Pool holds %d Powerups but the Map has only %d Crates." % [powerups, crates])

	var open_border: Array[Vector2i] = []
	for y in map.size.y:
		for x in map.size.x:
			var on_border := x == 0 or y == 0 or x == map.size.x - 1 or y == map.size.y - 1
			if on_border and map.tile_at(Vector2i(x, y)) != MapData.Tile.WALL:
				open_border.append(Vector2i(x, y))
	if not open_border.is_empty():
		found.append("The Map is not enclosed: %d border Tiles are not a Wall, the first at %s."
			% [open_border.size(), open_border[0]])
	return found
