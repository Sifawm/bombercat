class_name Splash
extends Control
## The first screen: the game's name over a sky while the rest of the game loads. On the web it
## takes over from the page's copy of it (web/index.html), which covered the download.

const MAIN := "res://presentation/main.tscn"
const FOLDER := "res://assets/splash/"
const MIN_SECONDS := 2.0
## The share of the bar the page filled while the game downloaded.
const WEB_SHARE := 0.8
const FADE_SECONDS := 0.15  # as Main's
const INK := Color("2a1b3d")
const FRAME := Vector2(1920, 1080)
## The clouds of the design, in the frame; each drifts right at a twelfth of its width a second.
const CLOUDS: Array[Rect2] = [
	Rect2(120, 120, 352, 132), Rect2(1500, 80, 288, 108), Rect2(1640, 560, 224, 84),
	Rect2(40, 640, 192, 72), Rect2(760, 40, 160, 60),
]
const BAR_WIDTH := 640.0
const BAR_INSET := 8.0

var _frame := Control.new()
var _clouds: Array[TextureRect] = []
var _burst: TextureRect
var _bomb: TextureRect
var _spark := TextureRect.new()
var _bomber: TextureRect
var _cat: TextureRect
var _fill: Panel
var _shine := Polygon2D.new()
var _label := Label.new()
## Seconds since the game started opening, which on the web is when the page did.
var _clock := 0.0
## When the intro ended and the loops took over; negative while it plays.
var _loop_start := -1.0
var _bar_start := 0.0
var _bar := 0.0
var _leaving := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := _image("sky", Rect2(Vector2.ZERO, FRAME), self)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	for cloud: Rect2 in CLOUDS:
		var node := _image("cloud", cloud, self)
		node.modulate.a = 0.9
		_clouds.append(node)
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.offset_left = -FRAME.x / 2.0
	_frame.offset_top = -FRAME.y / 2.0
	_frame.offset_right = FRAME.x / 2.0
	_frame.offset_bottom = FRAME.y / 2.0
	add_child(_frame)
	_burst = _image("burst", Rect2(640, 46, 640, 640), _frame)
	_bomb = _image("bomb", Rect2(807, 156, 253, 400), _frame)
	_bomb.pivot_offset = Vector2(_bomb.size.x / 2.0, _bomb.size.y)  # sways on its bottom
	_bomber = _image("wordmark_bomber", Rect2(448, 515, 734, 350), _frame)
	_cat = _image("wordmark_cat", Rect2(1108, 515, 364, 350), _frame)
	_add_spark()
	_add_bar()
	_add_text(_label, "Loading...", 32, Rect2(640, 856, 640, 39))
	_label.add_theme_font_override("font", load("res://assets/fonts/fredoka_semibold.tres"))
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # dots don't shift it
	_add_text(Label.new(), "Made with Godot", 24, Rect2(640, 987, 640, 29))


func _ready() -> void:
	ResourceLoader.load_threaded_request(MAIN)
	# A JavaScript boolean comes back as an int.
	var relayed := OS.has_feature("web") and bool(JavaScriptBridge.eval("typeof hideSplash == 'function'"))
	if OS.has_feature("web"):
		_clock = float(JavaScriptBridge.eval("performance.now()")) / 1000.0
	var top := (size.y - FRAME.y) / 2.0
	for i in _clouds.size():  # from where they stand in the design, whatever the window
		_clouds[i].position = CLOUDS[i].position + Vector2((size.x - FRAME.x) / 2.0, top)
	if not relayed:
		return _intro()
	_bar_start = WEB_SHARE
	_bar = WEB_SHARE
	_loop_start = _clock
	await RenderingServer.frame_post_draw  # the page's copy goes once this one is on screen
	JavaScriptBridge.eval("hideSplash()")


func _process(delta: float) -> void:
	_clock += delta
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += cloud.size.x / 12.0 * delta
		if cloud.position.x > size.x:
			cloud.position.x = -cloud.size.x
		cloud.position.y = (size.y - FRAME.y) / 2.0 + CLOUDS[i].position.y
	_burst.rotation += 0.2 * delta
	_spark.scale = Vector2.ONE * (0.85 + 0.3 * sin(_clock * 23.0) * sin(_clock * 7.1))
	_spark.modulate.a = 0.7 + 0.3 * sin(_clock * 31.0)
	if _loop_start >= 0.0:
		var t := _clock - _loop_start
		_burst.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 2.5))
		_bomb.position.y = 156.0 - 12.0 * sin(t * 2.0)
		_bomb.rotation = deg_to_rad(3.0) * sin(t * 1.3)
	_label.visible_characters = 8 + int(_clock * 3.0) % 3
	_advance_bar(delta)


## The bar follows the loading, but never fills before MIN_SECONDS nor jumps.
func _advance_bar(delta: float) -> void:
	var progress := [0.0]
	var loaded := ResourceLoader.load_threaded_get_status(MAIN, progress) \
			== ResourceLoader.THREAD_LOAD_LOADED
	var done := minf(1.0 if loaded else float(progress[0]), _clock / MIN_SECONDS)
	_bar = move_toward(_bar, lerpf(_bar_start, 1.0, done), 0.5 * delta)
	_fill.size.x = lerpf(32.0, BAR_WIDTH - 2.0 * BAR_INSET, _bar)
	_shine.position.x = fmod(_clock * 400.0, _fill.size.x + 120.0) - 60.0
	if loaded and _bar >= 1.0 and not _leaving:
		_leave()


func _leave() -> void:
	_leaving = true
	var main: PackedScene = ResourceLoader.load_threaded_get(MAIN)
	var curtain := ColorRect.new()
	curtain.color = Color(0.0, 0.0, 0.0, 0.0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)
	var fade := create_tween()
	fade.tween_property(curtain, "color:a", 1.0, FADE_SECONDS)
	fade.tween_callback(get_tree().change_scene_to_packed.bind(main))


func _intro() -> void:
	for node: Control in [_burst, _bomber, _cat]:
		node.scale = Vector2.ZERO
	_bomb.position.y = -_bomb.size.y
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_burst, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_bomb, "position:y", 156.0, 0.6).set_delay(0.1) \
			.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_bomber, "scale", Vector2.ONE, 0.35).set_delay(0.3)
	tween.tween_property(_cat, "scale", Vector2.ONE, 0.35).set_delay(0.45)
	tween.chain().tween_callback(func() -> void: _loop_start = _clock)


func _image(file: String, rect: Rect2, parent: Control) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(FOLDER + file + ".png")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.pivot_offset = rect.size / 2.0
	parent.add_child(node)
	return node


## A flickering glow on the fuse's spark, which is drawn in the bomb's picture.
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
	_panel(INK, 24, Rect2(640, 800, BAR_WIDTH, 48), _frame)  # the hard shadow under the track
	var track := _panel(Color("fff6e5"), 24, Rect2(640, 792, BAR_WIDTH, 48), _frame)
	(track.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(6)
	(track.get_theme_stylebox("panel") as StyleBoxFlat).border_color = INK
	_fill = _panel(Color("ffc93c"), 16, Rect2(BAR_INSET, BAR_INSET, 32, 32), track)
	_fill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # the shine keeps to the fill
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
	node.add_theme_color_override("font_color", INK)
	node.position = rect.position
	node.size = rect.size
	_frame.add_child(node)
