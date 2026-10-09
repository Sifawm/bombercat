extends RefCounted
## Map Studio's test-play: running a Map scene on its own (F6) starts a Round on that Map.


static func start(map: MapScene) -> void:
	RoundView.test_map = load(map.scene_file_path)
	map.get_tree().change_scene_to_file.call_deferred("res://presentation/round_view.tscn")
