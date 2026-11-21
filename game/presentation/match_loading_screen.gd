class_name MatchLoadingScreen
extends CanvasLayer
## The in-game Match loading overlay. It reuses the Splash screen's sky, clouds, rotating
## burst, swaying Bomb with fuse spark, wordmark and yellow progress bar, but omits the
## "Made with Godot" footer and the startup intro. It loads the Map, builds the arena,
## waits for shader warm-up frames, then fades out and releases the Round start gate.

const FOLDER := "res://assets/splash/"
const FADE_SECONDS := 0.25
const BAR_WIDTH := 640.0
const BAR_INSET := 8.0

var coordinator: MatchLoadingCoordinator

var _round_view: RoundView
var _frame: Control
var _burst: TextureRect
var _bomb: TextureRect
var _spark := TextureRect.new()
var _bomber: TextureRect
var _cat: TextureRect
var _fill: Panel
var _shine := Polygon2D.new()
var _label := Label.new()
var _clock := 0.0
var _finished := false


func _init(round_view: RoundView) -> void:
	_round_view = round_view
	coordinator = MatchLoadingCoordinator.new()
	coordinator.progress_changed.connect(_on_progress)
	coordinator.finished.connect(_on_finished)
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(SkyBackdrop.new())
	_frame = Ui.frame(root)
	_burst = _image("burst", Rect2(640, 46, 640, 640), _frame)
	_bomb = _image("bomb", Rect2(807, 156, 253, 400), _frame)
	_bomb.pivot_offset = Vector2(_bomb.size.x / 2.0, _bomb.size.y)
	_bomber = _image("wordmark_bomber", Rect2(448, 515, 734, 350), _frame)
	_cat = _image("wordmark_cat", Rect2(1108, 515, 364, 350), _frame)
	_add_spark()
	_add_bar()
	_add_text(_label, coordinator.phase_label(), 32, Rect2(640, 856, 640, 39))
	_label.add_theme_font_override("font", load("res://assets/fonts/fredoka_semibold.tres"))
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


func _ready() -> void:
	_start_loading()


func _process(delta: float) -> void:
	_clock += delta
	_burst.rotation += 0.2 * delta
	_spark.scale = Vector2.ONE * (0.85 + 0.3 * sin(_clock * 23.0) * sin(_clock * 7.1))
	_spark.modulate.a = 0.7 + 0.3 * sin(_clock * 31.0)
	var t := _clock
	_burst.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 2.5))
	_bomb.position.y = 156.0 - 12.0 * sin(t * 2.0)
	_bomb.rotation = deg_to_rad(3.0) * sin(t * 1.3)
	_label.visible_characters = _label.text.length() - 2 + int(_clock * 3.0) % 3
	_shine.position.x = fmod(_clock * 400.0, _fill.size.x + 120.0) - 60.0


func _start_loading() -> void:
	coordinator.start(1)
	await _scene_tree().process_frame
	var map_data := _map_data()
	coordinator.set_asset_step_count(_asset_step_count(map_data))
	await _load_map_assets(map_data)
	await _wait_for_arena()
	await _warm_up()


func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _map_data() -> MapData:
	var map_node: MapScene = _round_view.map_scene.instantiate()
	var map := map_node.to_map_data()
	map_node.free()
	return map


func _asset_step_count(map: MapData) -> int:
	return 1 + map.floor_models.size() + map.powerup_pool.size() + _round_view.cat_picks.size() + 1


func _load_map_assets(map: MapData) -> void:
	MapPalette.library()
	coordinator.complete_asset_step()
	await _scene_tree().process_frame
	for floor_model in map.floor_models:
		MapPalette.mesh_of(floor_model)
		coordinator.complete_asset_step()
		await _scene_tree().process_frame
	for powerup in map.powerup_pool:
		load("res://assets/models/%s.glb" % powerup)
		coordinator.complete_asset_step()
		await _scene_tree().process_frame
	for pick in _round_view.cat_picks:
		Roster.cat_scene(pick)
		coordinator.complete_asset_step()
		await _scene_tree().process_frame
	load("res://assets/audio/music_round.ogg")
	coordinator.complete_asset_step()
	await _scene_tree().process_frame


func _wait_for_arena() -> void:
	while not _round_view.is_arena_built():
		await _scene_tree().process_frame
	coordinator.set_arena_ready()


func _warm_up() -> void:
	for i in MatchLoadingCoordinator.WARM_UP_FRAMES:
		await RenderingServer.frame_post_draw
		coordinator.advance_warm_up_frame()


func _on_progress(_phase: int, label: String, progress: float) -> void:
	_label.text = label
	_fill.size.x = lerpf(32.0, BAR_WIDTH - 2.0 * BAR_INSET, progress)


func _on_finished() -> void:
	if _finished:
		return
	_finished = true
	coordinator.release()
	_round_view.release_start()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(queue_free)


func _image(file: String, rect: Rect2, parent: Control) -> TextureRect:
	return Ui.picture(FOLDER + file + ".png", rect, parent)


func _add_spark() -> void:
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.gradient = Gradient.new()
	glow.gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	glow.gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.4, 0.6), Color(1.0, 0.8, 0.2, 0.0)])
	_spark.texture = glow
	_spark.size = Vector2(72, 72)
	_spark.position = Vector2(178, 38) - _spark.size / 2.0
	_spark.pivot_offset = _spark.size / 2.0
	_spark.material = CanvasItemMaterial.new()
	(_spark.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bomb.add_child(_spark)


func _add_bar() -> void:
	_panel(Ui.INK, 24, Rect2(640, 800, BAR_WIDTH, 48), _frame)
	var track := _panel(Ui.CREAM, 24, Rect2(640, 792, BAR_WIDTH, 48), _frame)
	(track.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(6)
	(track.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Ui.INK
	_fill = _panel(Ui.YELLOW, 16, Rect2(BAR_INSET, BAR_INSET, 32, 32), track)
	_fill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_shine.polygon = PackedVector2Array([Vector2(16, 0), Vector2(56, 0), Vector2(40, 32), Vector2(0, 32)])
	_shine.color = Color(1.0, 1.0, 1.0, 0.45)
	_fill.add_child(_shine)


func _panel(color: Color, radius: int, rect: Rect2, parent: Control) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	var node := Panel.new()
	node.add_theme_stylebox_override("panel", style)
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node


func _add_text(node: Label, text: String, font_size: int, rect: Rect2) -> void:
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Ui.INK)
	node.position = rect.position
	node.size = rect.size
	_frame.add_child(node)
