@tool
class_name MapPalette
extends RefCounted
## The meshes a Map is painted with in Map Studio, built from the models each time the
## editor or the game starts (restart the editor after re-exporting a model). An Item's number is what a Map scene stores in each Tile: only ever append.

enum Item {
	WALL_BRICK, WALL_BRICK_LOW, WALL_PILLAR, CRATE, SPAWN_MARKER,
	WALL_ROOM, WALL_ROOM_LOW, SOFA_LEFT, SOFA_MIDDLE, SOFA_RIGHT, BOOKSHELF, CAT_TREE, TABLE_CORNER,
}

const MODELS: Dictionary[Item, String] = {
	Item.WALL_BRICK: "wall_brick",
	Item.WALL_BRICK_LOW: "wall_brick_low",
	Item.WALL_PILLAR: "wall_pillar",
	Item.CRATE: "crate",
	Item.SPAWN_MARKER: "spawn_marker",
	Item.WALL_ROOM: "wall_room",
	Item.WALL_ROOM_LOW: "wall_room_low",
	Item.SOFA_LEFT: "sofa_left",
	Item.SOFA_MIDDLE: "sofa_middle",
	Item.SOFA_RIGHT: "sofa_right",
	Item.BOOKSHELF: "bookshelf",
	Item.CAT_TREE: "cat_tree",
	Item.TABLE_CORNER: "table_corner",
}
const WALLS: Array[Item] = [
	Item.WALL_BRICK, Item.WALL_BRICK_LOW, Item.WALL_PILLAR,
	Item.WALL_ROOM, Item.WALL_ROOM_LOW, Item.SOFA_LEFT, Item.SOFA_MIDDLE, Item.SOFA_RIGHT, Item.BOOKSHELF,
	Item.CAT_TREE, Item.TABLE_CORNER,
]

static var _library: MeshLibrary


static func library() -> MeshLibrary:
	if _library != null:
		return _library
	_library = MeshLibrary.new()
	var meshes: Array[Mesh] = []
	for item: Item in MODELS:
		meshes.append(mesh_of(MODELS[item]))
		_library.create_item(item)
		_library.set_item_name(item, MODELS[item])
		_library.set_item_mesh(item, meshes[-1])
	# No previews without a window: a headless editor (an export, an import) cannot draw them.
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface") and DisplayServer.get_name() != "headless":
		# Looked up by name: the EditorInterface class does not exist in exported games.
		var previews: Array = Engine.get_singleton("EditorInterface").call("make_mesh_previews", meshes, 64)
		for item in previews.size():
			_library.set_item_preview(item, previews[item])
	return _library


static func mesh_of(model: String) -> Mesh:
	var scene: PackedScene = load("res://assets/models/%s.glb" % model)
	var root := scene.instantiate()
	var instance: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := instance.mesh
	root.free()
	return mesh
