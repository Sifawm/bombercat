extends RefCounted
## Map Studio's test-play: running a Map scene on its own (F6) starts a Round on that Map.


static func start(map: MapScene) -> void:
	var scene: PackedScene = load("res://presentation/round_view.tscn")
	var view: RoundView = scene.instantiate()
	view.map_scene = load(map.scene_file_path)
	_replace.call_deferred(map, view)  # the tree is still busy adding the Map


static func _replace(map: MapScene, view: RoundView) -> void:
	var tree := map.get_tree()
	tree.root.add_child(view)
	tree.current_scene = view
	map.queue_free()
