@tool
class_name MapScene
extends GridMap
## A Map as authored in Map Studio: a GridMap painted with the MapPalette, plus its Powerup
## Pool. Empty Tiles inside the painted area are Floor, which is laid automatically. This is
## the only script that knows Maps are GridMaps; the rules get plain MapData from it.

const TEST_PLAY := "res://map_studio/test_play.gd"
const FLOOR_MODELS: Array[String] = ["floor_a", "floor_b"]

## How many of each Powerup (by id) hide in the Crates every Round.
@export var powerup_pool: Dictionary[StringName, int] = {}

var _painted_hash := 0
## The painted area as of the last `to_map_data` or floor refresh; Tile (0, 0) is its corner.
var _area: Rect2i


func _init() -> void:
	mesh_library = MapPalette.library()
	cell_size = Vector3.ONE
	cell_center_y = false


func _ready() -> void:
	_lay_floor()
	set_process(Engine.is_editor_hint())
	# Run on its own (F6 in the editor), a Map is test-played. Map Studio is not exported.
	if not Engine.is_editor_hint() and get_tree().current_scene == self and ResourceLoader.exists(TEST_PLAY):
		(load(TEST_PLAY) as GDScript).call("start", self)


## Editor only. ponytail: GridMap has no "cells changed" signal, so this hashes the cells
## every frame; fine for Maps this small, throttle it if Maps ever get large.
func _process(_delta: float) -> void:
	var cells := get_used_cells()
	var painted := hash([cells, cells.map(get_cell_item), powerup_pool])
	if painted != _painted_hash:
		_painted_hash = painted
		_lay_floor()
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var problems := MapValidator.problems(to_map_data())
	if get_used_cells().any(func(cell: Vector3i) -> bool: return cell.y != 0):
		problems.append("Something is painted above or below floor 0 of the GridMap; the game only reads floor 0.")
	return problems


## The palette and the 1 m grid are set in code: not editable, not saved into every Map scene.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["mesh_library", "cell_size", "cell_center_x", "cell_center_y", "cell_center_z"]:
		property.usage = PROPERTY_USAGE_NONE


func to_map_data() -> MapData:
	var map := MapData.new()
	_area = _painted_area()
	var area := _area
	map.size = area.size
	map.powerup_pool = powerup_pool.duplicate()
	for y in area.size.y:
		for x in area.size.x:
			var item := get_cell_item(Vector3i(area.position.x + x, 0, area.position.y + y)) as MapPalette.Item
			if item in MapPalette.WALLS:
				map.tiles.append(MapData.Tile.WALL)
			elif item == MapPalette.Item.CRATE:
				map.tiles.append(MapData.Tile.CRATE)
			else:
				map.tiles.append(MapData.Tile.FLOOR)
				if item == MapPalette.Item.SPAWN_MARKER:
					map.spawn_points.append(Vector2i(x, y))
	return map


## Removes what the presentation draws itself (Crates) or never shows (Spawn Point markers).
func prepare_for_play() -> void:
	for cell in get_used_cells():
		if get_cell_item(cell) in [MapPalette.Item.CRATE, MapPalette.Item.SPAWN_MARKER]:
			set_cell_item(cell, INVALID_CELL_ITEM)


## Where a position in Tile units (as the rules use them) is, in this node's space.
func tile_to_local(tile_position: Vector2) -> Vector3:
	var origin := _area.position
	return Vector3(origin.x + tile_position.x + 0.5, 0.0, origin.y + tile_position.y + 0.5)


func _painted_area() -> Rect2i:
	var cells := get_used_cells().filter(func(cell: Vector3i) -> bool: return cell.y == 0)
	if cells.is_empty():
		return Rect2i()
	var area := Rect2i(cells[0].x, cells[0].z, 1, 1)
	for cell: Vector3i in cells:
		area = area.expand(Vector2i(cell.x, cell.z)).expand(Vector2i(cell.x + 1, cell.z + 1))
	return area


func _lay_floor() -> void:
	for node in get_children(true):
		if node is MultiMeshInstance3D:
			node.queue_free()
	_area = _painted_area()
	var area := _area
	for tone in FLOOR_MODELS.size():
		var tiles: Array[Vector2i] = []
		for y in area.size.y:
			for x in area.size.x:
				if (x + y) % FLOOR_MODELS.size() == tone:
					tiles.append(Vector2i(x, y))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = MapPalette.mesh_of(FLOOR_MODELS[tone])
		multimesh.instance_count = tiles.size()
		for index in tiles.size():
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, tile_to_local(Vector2(tiles[index]))))
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		add_child(node, false, Node.INTERNAL_MODE_BACK)
