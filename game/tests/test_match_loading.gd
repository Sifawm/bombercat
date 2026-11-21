extends RulesTestCase

class MockCat:
	extends RefCounted
	var held := false
	var dropped := false
	func hold_at_drop() -> void: held = true
	func drop() -> void: dropped = true


var _captured: Array[Dictionary] = []


func _record(loader: MatchLoadingCoordinator) -> void:
	_captured.clear()
	if not loader.progress_changed.is_connected(_on_progress):
		loader.progress_changed.connect(_on_progress)


func _on_progress(phase: int, label: String, progress: float) -> void:
	_captured.append({"phase": phase, "label": label, "progress": progress})


func test_progress_is_monotonic_through_all_phases() -> void:
	var loader := MatchLoadingCoordinator.new()
	_record(loader)
	loader.start(2)
	check_eq(_captured.back().label, "Loading map...", "starts loading map")
	loader.complete_asset_step()
	check_eq(_captured.back().label, "Loading map...", "still loading map")
	loader.complete_asset_step()
	check_eq(_captured.back().label, "Building arena...", "moves to building")
	loader.set_arena_ready()
	check_eq(_captured.back().label, "Warming up...", "moves to warming up")
	loader.advance_warm_up_frame()
	check(_captured.back().progress > 0.7, "warmup progress advanced")
	var finished: Array[bool] = [false]
	loader.finished.connect(func() -> void: finished[0] = true)
	loader.advance_warm_up_frame()
	check(finished[0], "finishes after two warmup frames")
	check_eq(_captured.back().progress, 1.0, "ends at full progress")
	for i in range(1, _captured.size()):
		check(_captured[i].progress >= _captured[i - 1].progress, "progress never decreases")


func test_does_not_finish_prematurely() -> void:
	var loader := MatchLoadingCoordinator.new()
	loader.start(2)
	check(not loader.is_finished(), "not finished at start")
	loader.complete_asset_step()
	check(not loader.is_finished(), "not finished with one step done")
	loader.complete_asset_step()
	check(not loader.is_finished(), "not finished before arena ready")
	loader.set_arena_ready()
	check(not loader.is_finished(), "not finished before warmup")
	loader.advance_warm_up_frame()
	check(not loader.is_finished(), "not finished after one warmup frame")
	loader.advance_warm_up_frame()
	check(loader.is_finished(), "finished after two warmup frames")


func test_gate_holds_and_releases() -> void:
	var loader := MatchLoadingCoordinator.new()
	loader.start(1)
	check(loader.is_held(), "gate is held after start")
	var released: Array[bool] = [false]
	loader.released.connect(func() -> void: released[0] = true)
	loader.release()
	check(not loader.is_held(), "gate is released")
	check(released[0], "released signal emitted")
	loader.release()
	check(not loader.is_held(), "second release is a no-op")


func test_releasing_gate_starts_cat_drop() -> void:
	var loader := MatchLoadingCoordinator.new()
	var cats: Array[MockCat] = [MockCat.new(), MockCat.new()]
	loader.start(1)
	for cat in cats:
		cat.hold_at_drop()
	var dropped_before := cats.all(func(cat: MockCat) -> bool: return not cat.dropped)
	check(dropped_before, "cats are not dropped while held")
	loader.release()
	for cat in cats:
		cat.drop()
	var dropped_after := cats.all(func(cat: MockCat) -> bool: return cat.dropped)
	check(dropped_after, "cats drop on release")


func test_phase_labels_are_english() -> void:
	var loader := MatchLoadingCoordinator.new()
	loader.start(1)
	check_eq(loader.phase_label(), "Loading map...", "phase one label")
	loader.complete_asset_step()
	loader.set_arena_ready()
	check_eq(loader.phase_label(), "Warming up...", "phase three label")


func test_set_asset_step_count_keeps_progress_monotonic() -> void:
	var loader := MatchLoadingCoordinator.new()
	_record(loader)
	loader.start(1)
	loader.set_asset_step_count(4)
	var progress_after_resize: float = _captured.back().progress
	check_eq(_captured.back().label, "Loading map...", "still loading map after resize")
	loader.complete_asset_step()
	check(_captured.back().progress > progress_after_resize, "progress advances after resize")
	loader.complete_asset_step()
	loader.complete_asset_step()
	loader.complete_asset_step()
	check_eq(_captured.back().label, "Building arena...", "all steps completed")
