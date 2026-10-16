extends SceneTree
## Writes what the online server needs from this project as JSON into shared/src: the balance
## values and every Map (ADR 0003). The server cannot read scenes or resources, so this
## project stays their source and the files are versioned. Run it through ./run_tests.sh,
## which fails when they are stale. A Map also carries its `look` for art/render_map.py,
## which the server ignores.

const TARGET := "res://../shared/src/"
const SYMBOLS: Dictionary[MapData.Tile, String] = {
	MapData.Tile.FLOOR: ".", MapData.Tile.WALL: "#", MapData.Tile.CRATE: "x",
}


func _init() -> void:
	var config: GameConfig = load("res://config/game_config.tres")
	var balance := {}
	for property in (config.get_script() as GDScript).get_script_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:  # not the groups of the inspector
			var property_name: String = property.name
			balance[property_name.to_camel_case()] = config.get(property_name)
	_write("config.json", balance)

	# A Map that is no longer in the project leaves no file behind.
	var exported := ProjectSettings.globalize_path(TARGET + "maps")
	for file in DirAccess.get_files_at(exported):
		DirAccess.remove_absolute(exported.path_join(file))
	for file in DirAccess.get_files_at("res://maps"):
		if file.ends_with(".tscn"):
			var node: MapScene = (load("res://maps/" + file) as PackedScene).instantiate()
			var described := _described(node.to_map_data())
			described.look = _look(node)
			_write("maps/" + file.get_basename() + ".json", described)
			node.free()
	quit()


## A Map as the rows `MapData.from_rows` reads, plus its Powerup Pool.
func _described(map: MapData) -> Dictionary:
	var rows: Array[String] = []
	for y in map.size.y:
		var row := ""
		for x in map.size.x:
			row += "S" if map.spawn_points.has(Vector2i(x, y)) else SYMBOLS[map.tile_at(Vector2i(x, y))]
		rows.append(row)
	return {"rows": rows, "powerupPool": map.powerup_pool}


## What is painted on each Tile and how it is turned, the Floor, and the decoration that is
## not a Tile: the models by name, at Tile coordinates, turned in degrees about the vertical.
func _look(node: MapScene) -> Dictionary:
	var origin := node.tile_to_local(Vector2.ZERO)
	var cells := []
	for cell in node.get_used_cells():
		var turn := node.get_basis_with_orthogonal_index(node.get_cell_item_orientation(cell)).get_euler().y
		var tile := Vector2i(Vector2(node.map_to_local(cell).x - origin.x, node.map_to_local(cell).z - origin.z).round())
		cells.append({"x": tile.x, "y": tile.y, "model": MapPalette.MODELS[node.get_cell_item(cell)], "turn": roundi(rad_to_deg(turn))})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a.y, a.x] < [b.y, b.x])
	var decor := []
	for child in node.get_children():
		if child is Node3D and child.scene_file_path.ends_with(".glb"):
			var at: Vector3 = (child as Node3D).position - origin
			decor.append({"x": at.x, "y": at.z, "model": child.scene_file_path.get_file().get_basename(),
				"turn": roundi(rad_to_deg((child as Node3D).rotation.y))})
	return {"floor": node.floor_models, "cells": cells, "decor": decor}


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(TARGET + path), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "  ", false) + "\n")
