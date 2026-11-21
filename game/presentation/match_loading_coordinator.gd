class_name MatchLoadingCoordinator
extends RefCounted
## Testable state machine for the Match loading screen. It tracks three phases, a monotonic
## progress value from 0.0 to 1.0, and a Round start gate that is held while loading and
## released when the arena is warmed up.

signal progress_changed(phase: int, label: String, progress: float)
signal finished
signal released

enum Phase { LOADING_MAP, BUILDING_ARENA, WARMING_UP }

const LABELS: Array[String] = ["Loading map...", "Building arena...", "Warming up..."]
const WARM_UP_FRAMES := 2

var _phase := Phase.LOADING_MAP
var _progress := 0.0
var _asset_step_count := 1
var _asset_steps_done := 0
var _arena_ready := false
var _warm_up_frames_left := WARM_UP_FRAMES
var _held := false


func start(asset_step_count: int) -> void:
	_phase = Phase.LOADING_MAP
	_progress = 0.0
	_asset_step_count = maxi(asset_step_count, 1)
	_asset_steps_done = 0
	_arena_ready = false
	_warm_up_frames_left = WARM_UP_FRAMES
	_held = true
	_emit()


## Updates the total number of asset steps while still in the LOADING_MAP phase. Call before
## completing any steps to keep progress monotonic.
func set_asset_step_count(count: int) -> void:
	if _phase != Phase.LOADING_MAP:
		return
	_asset_step_count = maxi(count, 1)
	_recalculate()


func complete_asset_step() -> void:
	if _phase != Phase.LOADING_MAP:
		return
	_asset_steps_done = mini(_asset_steps_done + 1, _asset_step_count)
	_recalculate()


func set_arena_ready() -> void:
	if _phase != Phase.BUILDING_ARENA:
		return
	_arena_ready = true
	_recalculate()


func advance_warm_up_frame() -> void:
	if _phase != Phase.WARMING_UP:
		return
	_warm_up_frames_left -= 1
	_recalculate()
	if _warm_up_frames_left <= 0:
		finished.emit()


func phase_label() -> String:
	return LABELS[_phase]


func progress() -> float:
	return _progress


func is_finished() -> bool:
	return _phase == Phase.WARMING_UP and _warm_up_frames_left <= 0


func is_held() -> bool:
	return _held


func release() -> void:
	if not _held:
		return
	_held = false
	released.emit()


func _recalculate() -> void:
	match _phase:
		Phase.LOADING_MAP:
			_progress = lerpf(0.0, 0.4, float(_asset_steps_done) / float(_asset_step_count))
			if _asset_steps_done >= _asset_step_count:
				_phase = Phase.BUILDING_ARENA
				_recalculate()
				return
		Phase.BUILDING_ARENA:
			_progress = 0.4 if not _arena_ready else 0.7
			if _arena_ready:
				_phase = Phase.WARMING_UP
				_recalculate()
				return
		Phase.WARMING_UP:
			var done := WARM_UP_FRAMES - _warm_up_frames_left
			_progress = lerpf(0.7, 1.0, float(done) / float(WARM_UP_FRAMES))
	_emit()


func _emit() -> void:
	progress_changed.emit(_phase, LABELS[_phase], _progress)
