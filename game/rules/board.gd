class_name Board
extends RefCounted
## The grid of Tiles during a Round and what occupies each one.

var size: Vector2i
var bombs: Dictionary[Vector2i, Bomb] = {}
## Tiles under an active Explosion and the seconds each stays lethal.
var explosions: Dictionary[Vector2i, float] = {}
## Powerups lying on the Floor.
var powerups: Dictionary[Vector2i, Powerup] = {}
## Powerups still inside their Crates.
var hidden_powerups: Dictionary[Vector2i, Powerup] = {}

var _map: MapData


func _init(map: MapData) -> void:
	size = map.size
	_map = MapData.new()
	_map.size = map.size
	_map.tiles = map.tiles.duplicate()


func tile_at(tile: Vector2i) -> MapData.Tile:
	return _map.tile_at(tile)


## Whether a Cat that does not already overlap this Tile may enter it.
func is_walkable(tile: Vector2i) -> bool:
	return tile_at(tile) == MapData.Tile.FLOOR and not bombs.has(tile)


func destroy_crate(tile: Vector2i) -> void:
	_map.tiles[tile.y * size.x + tile.x] = MapData.Tile.FLOOR
