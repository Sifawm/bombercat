class_name Ui
## Shorthands for the screens, which build their controls in code.

const TITLE_SIZE := 96
const SMALL_SIZE := 28
## The size of the design's screens, which place their parts in it.
const FRAME := Vector2(1920, 1080)
const INK := Color("2a1b3d")
const CREAM := Color("fff6e5")
const YELLOW := Color("ffc93c")
const RED := Color("ff4f64")
const GREEN := Color("7ed957")
const BLUE := Color("3fa9f5")
const LILITA: FontFile = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const FREDOKA_MEDIUM: FontVariation = preload("res://assets/fonts/fredoka_medium.tres")
const FREDOKA_SEMIBOLD: FontVariation = preload("res://assets/fonts/fredoka_semibold.tres")

## What a Notice tells: something under way, something wrong, something done, or a word to know.
enum Tone { PROGRESS, ERROR, SUCCESS, INFO }
## How long a Notice that is done or informs stays before it fades away by itself.
const NOTICE_SECONDS := 3.0


static func label(text: String, font_size: int = 0, color: Color = Color.WHITE, font: Font = null) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_color_override("font_color", color)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)
	if font != null:
		node.add_theme_font_override("font", font)
	return node


## The design's Button: yellow and large for a screen's main action, cream otherwise.
static func button(text: String, on_pressed: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	var fill := YELLOW if primary else CREAM
	var body := surface(fill)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		node.add_theme_stylebox_override(state, body)
	node.add_theme_stylebox_override("focus", surface(fill, true))
	# Half see-through, as on the cream it stands on, without its shadow showing through.
	var faded := INK.lerp(CREAM, 0.5)
	node.add_theme_stylebox_override("disabled", surface(fill.lerp(CREAM, 0.5), false, 28, faded, 6, faded))
	node.add_theme_font_override("font", LILITA)
	node.add_theme_font_size_override("font_size", 64 if primary else 40)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(color, INK)
	node.add_theme_color_override("font_disabled_color", faded)
	node.mouse_entered.connect(node.grab_focus)  # one button lit at a time, whatever points
	node.pressed.connect(on_pressed)
	node.pressed.connect(Audio.play.bind(&"ui_confirm"))
	node.focus_entered.connect(_bounce.bind(node))
	return node


static func _bounce(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * 1.15
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The design's surface, of buttons, fields and panels: an inked body with a band of shade at its
## foot, on a hard shadow; with the focus, inside a cream ring inside an inked one. The focus box
## covers the plain one, which is drawn under it.
static func surface(fill: Color, focused: bool = false, radius: int = 28, stroke: Color = INK,
		stroke_width: int = 6, shadow: Color = INK) -> Layers:
	var box := Layers.new()
	box.set_content_margin(SIDE_LEFT, 40)
	box.set_content_margin(SIDE_RIGHT, 40)
	box.set_content_margin(SIDE_TOP, 16)
	box.set_content_margin(SIDE_BOTTOM, 16)
	if focused:
		box.add(_rounded(INK, radius, 14))
		box.add(_rounded(CREAM, radius, 8))
	box.add(_rounded(shadow, radius, 0), Vector2(0, 14 if focused else 10))
	var body := _rounded(fill, radius, 0)
	body.set_border_width_all(stroke_width)
	body.border_color = stroke
	box.add(body)
	var shade := _rounded(Color(INK, 0.18), radius, 0)
	shade.draw_center = false
	shade.border_width_bottom = stroke_width + 10  # under the stroke, 10 px of the body
	box.add(shade)
	return box


## A rounded shape, grown by `spread` on every side.
static func _rounded(color: Color, radius: int, spread: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color
	box.set_corner_radius_all(radius + spread)
	box.set_expand_margin_all(spread)
	return box


## The design's TextField: a name written on a cream surface, ringed when focused and red when
## what it holds was refused.
static func text_field(size: Vector2) -> LineEdit:
	var node := LineEdit.new()
	node.custom_minimum_size = size
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", FREDOKA_SEMIBOLD)
	node.add_theme_font_size_override("font_size", 40)
	for color: String in ["font_color", "caret_color", "font_selected_color"]:
		node.add_theme_color_override(color, INK)
	node.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	node.add_theme_color_override("selection_color", Color(YELLOW, 0.6))
	node.add_theme_constant_override("caret_width", 2)  # scaled by the theme to the design's 4 or so
	mark_field(node, false)
	return node


## Draws the field red, or as it was.
static func mark_field(field: LineEdit, refused: bool) -> void:
	var stroke := RED if refused else INK
	var width := 12 if refused else 6
	for state: String in ["normal", "read_only"]:
		field.add_theme_stylebox_override(state, surface(CREAM, false, 28, stroke, width))
	field.add_theme_stylebox_override("focus", surface(CREAM, true, 28, stroke, width))


## The design's Notice: a message on ink after a round icon of its Tone. One that is done or
## informs fades away by itself after a moment.
static func notice(tone: Tone, message: String) -> PanelContainer:
	var node := PanelContainer.new()
	var box := Layers.new()
	box.add(_rounded(Color(INK, 0.35), 28, 0), Vector2(0, 12))
	box.add(_rounded(INK, 28, 0))
	box.set_content_margin_all(12)
	box.set_content_margin(SIDE_RIGHT, 32)
	node.add_theme_stylebox_override("panel", box)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	node.add_child(row)
	row.add_child(_notice_icon(tone))
	row.add_child(label(message, 32, CREAM, FREDOKA_SEMIBOLD))
	if tone == Tone.SUCCESS or tone == Tone.INFO:
		node.ready.connect(func() -> void:
			var fade := node.create_tween()
			fade.tween_interval(NOTICE_SECONDS)
			fade.tween_property(node, "modulate:a", 0.0, 0.3)
			fade.tween_callback(node.queue_free))
	return node


static func _notice_icon(tone: Tone) -> Control:
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(56, 56)
	var fill := StyleBoxFlat.new()
	fill.bg_color = [YELLOW, RED, GREEN, BLUE][tone]
	fill.set_border_width_all(6)
	fill.border_color = INK
	fill.set_corner_radius_all(28)
	icon.add_theme_stylebox_override("panel", fill)
	if tone == Tone.SUCCESS:
		icon.add_child(Tick.new())
	else:
		var glyph := label(["…", "!", "", "i"][tone], 28, INK, LILITA)
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(glyph)
	return icon


## The design's panel: a cream surface with rounder corners, holding a screen's content.
static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	var box := surface(CREAM, false, 40)
	box.set_content_margin(SIDE_LEFT, 96)
	box.set_content_margin(SIDE_RIGHT, 96)
	box.set_content_margin(SIDE_TOP, 64)
	box.set_content_margin(SIDE_BOTTOM, 64)
	node.add_theme_stylebox_override("panel", box)
	return node


## A vertical stack centred in `screen`, which is made to cover the whole picture.
static func centred_column(screen: Control, separation: int = 24) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	centre.add_child(column)
	return column


## The design's frame, centred in `screen`; what it holds goes at the design's coordinates.
static func frame(screen: Control) -> Control:
	var node := Control.new()
	node.set_anchors_preset(Control.PRESET_CENTER)
	node.offset_left = -FRAME.x / 2.0
	node.offset_top = -FRAME.y / 2.0
	node.offset_right = FRAME.x / 2.0
	node.offset_bottom = FRAME.y / 2.0
	screen.add_child(node)
	return node


## A picture stretched over `rect` of `parent`, turning and scaling on its centre.
static func picture(path: String, rect: Rect2, parent: Control) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.pivot_offset = rect.size / 2.0
	parent.add_child(node)
	return node


## The check mark of a Notice that tells something is done.
class Tick:
	extends Control

	func _draw() -> void:
		var centre := size / 2.0
		var points := PackedVector2Array([Vector2(-9, 0), Vector2(-3, 7), Vector2(10, -7)])
		for i in points.size():
			points[i] += centre
		draw_polyline(points, INK, 5.0, true)


## StyleBoxes drawn one over another, each moved by its offset.
class Layers:
	extends StyleBox

	var _boxes: Array[StyleBox] = []
	var _offsets: Array[Vector2] = []

	func add(box: StyleBox, offset: Vector2 = Vector2.ZERO) -> void:
		_boxes.append(box)
		_offsets.append(offset)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		for i in _boxes.size():
			_boxes[i].draw(to_canvas_item, Rect2(rect.position + _offsets[i], rect.size))
