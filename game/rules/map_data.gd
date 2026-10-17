@tool
class_name MapData
extends RefCounted
## Plain description of a Map: the data a Board is built from. Knows nothing about scenes.

enum Tile { FLOOR, WALL, CRATE }

## A Tile no Map has: what Tile-valued queries return for "none".
const NO_TILE := Vector2i(-1, -1)

var size: Vector2i
## Row by row, `size.x` Tiles per row.
var tiles: Array[Tile] = []
var spawn_points: Array[Vector2i] = []
## How many of each Powerup (by id) the Map hides in its Crates every Round.
var powerup_pool: Dictionary[StringName, int] = {}
## The colour (1, 2...) of each Portal. A Portal is a Floor Tile linked to the other Portal of its colour.
var portals: Dictionary[Vector2i, int] = {}


## Builds a Map from text rows: "#" Wall, "x" Crate, "S" Spawn Point, "1" to "9" a Portal of
## that colour, anything else Floor.
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
					if rows[y][x] >= "1" and rows[y][x] <= "9":
						map.portals[Vector2i(x, y)] = rows[y][x].to_int()
	return map


## Anything outside the Map counts as Wall.
func tile_at(tile: Vector2i) -> Tile:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return Tile.WALL
	return tiles[tile.y * size.x + tile.x]


## The other Portal of the colour of `tile`, or NO_TILE when `tile` is no Portal or its colour is
## not a pair.
func portal_partner(tile: Vector2i) -> Vector2i:
	if not portals.has(tile):
		return NO_TILE
	var linked := portals.keys().filter(func(other: Vector2i) -> bool: return other != tile and portals[other] == portals[tile])
	return linked[0] if linked.size() == 1 else NO_TILE


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
