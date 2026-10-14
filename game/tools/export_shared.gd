extends SceneTree
## Writes what the online server needs from this project as JSON into shared/src: the balance
## values and every Map (ADR 0003). The server cannot read scenes or resources, so this
## project stays their source and the files are versioned. Run it through ./run_tests.sh,
## which fails when they are stale.

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
			_write("maps/" + file.get_basename() + ".json", _described(node.to_map_data()))
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


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(TARGET + path), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "  ", false) + "\n")
