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
	_map.portals = map.portals


func tile_at(tile: Vector2i) -> MapData.Tile:
	return _map.tile_at(tile)


## Whether a Cat that does not already overlap this Tile may enter it.
func is_walkable(tile: Vector2i) -> bool:
	return tile_at(tile) == MapData.Tile.FLOOR and not bombs.has(tile)


## Where a Cat that reaches the centre of `tile` comes out: the other Portal of its colour,
## unless a Bomb lies on it. NO_TILE for a Tile that is no Portal.
func portal_exit(tile: Vector2i) -> Vector2i:
	var exit := _map.portal_partner(tile)
	return MapData.NO_TILE if bombs.has(exit) else exit


## The other Portal of the colour of `tile`, or NO_TILE, whatever lies on it.
func portal_partner(tile: Vector2i) -> Vector2i:
	return _map.portal_partner(tile)


func destroy_crate(tile: Vector2i) -> void:
	_map.tiles[tile.y * size.x + tile.x] = MapData.Tile.FLOOR
