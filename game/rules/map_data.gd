class_name MapData
extends RefCounted
## Plain description of a Map: the data a Board is built from. Knows nothing about scenes.

enum Tile { FLOOR, WALL, CRATE }

var size: Vector2i
## Row by row, `size.x` Tiles per row.
var tiles: Array[Tile] = []
var spawn_points: Array[Vector2i] = []


## Builds a Map from text rows: "#" Wall, "x" Crate, "S" Spawn Point, anything else Floor.
static func from_rows(rows: PackedStringArray) -> MapData:
	var map := MapData.new()
	map.size = Vector2i(rows[0].length(), rows.size())
	for y in map.size.y:
		for x in map.size.x:
			match rows[y][x]:
				"#":
					map.tiles.append(Tile.WALL)
				"x":
					map.tiles.append(Tile.CRATE)
				"S":
					map.tiles.append(Tile.FLOOR)
					map.spawn_points.append(Vector2i(x, y))
				_:
					map.tiles.append(Tile.FLOOR)
	return map


## Anything outside the Map counts as Wall.
func tile_at(tile: Vector2i) -> Tile:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return Tile.WALL
	return tiles[tile.y * size.x + tile.x]


## The `count` Spawn Points farthest apart: the farthest pair first, then whichever
## remaining one is farthest from those already chosen.
func farthest_spawn_points(count: int) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	var best := -1
	for a in spawn_points:
		for b in spawn_points:
			if a.distance_squared_to(b) > best:
				best = a.distance_squared_to(b)
				chosen = [a, b]
	while chosen.size() < mini(count, spawn_points.size()):
		var remaining := spawn_points.filter(func(point: Vector2i) -> bool: return not chosen.has(point))
		var nearest_chosen := func(point: Vector2i) -> int:
			return chosen.map(func(other: Vector2i) -> int: return point.distance_squared_to(other)).min()
		remaining.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return nearest_chosen.call(a) > nearest_chosen.call(b))
		chosen.append(remaining[0])
	return chosen.slice(0, count)
