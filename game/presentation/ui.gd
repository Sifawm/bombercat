class_name Ui
## Shorthands for the screens, which build their controls in code.

const TITLE_SIZE := 96
const SMALL_SIZE := 28
## The size of the design's screens, which place their parts in it.
const FRAME := Vector2(1920, 1080)
const INK := Color("2a1b3d")
const CREAM := Color("fff6e5")
const YELLOW := Color("ffc93c")
const LILITA: FontFile = preload("res://assets/fonts/LilitaOne-Regular.ttf")


static func label(text: String, font_size: int = 0, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_color_override("font_color", color)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)
	return node


## The design's Button: yellow and large for a screen's main action, cream otherwise.
static func button(text: String, on_pressed: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	var fill := YELLOW if primary else CREAM
	var body := _button_box(fill, false)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		node.add_theme_stylebox_override(state, body)
	node.add_theme_stylebox_override("focus", _button_box(fill, true))
	node.add_theme_font_override("font", LILITA)
	node.add_theme_font_size_override("font_size", 64 if primary else 40)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(color, INK)
	node.add_theme_color_override("font_disabled_color", Color(INK, 0.5))
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


## An inked body with a band of shade at its foot, on a hard shadow; with the focus, inside a
## cream ring inside an inked one. The focus box covers the plain one, which is drawn under it.
static func _button_box(fill: Color, focused: bool) -> Layers:
	var box := Layers.new()
	box.set_content_margin(SIDE_LEFT, 40)
	box.set_content_margin(SIDE_RIGHT, 40)
	box.set_content_margin(SIDE_TOP, 16)
	box.set_content_margin(SIDE_BOTTOM, 16)
	if focused:
		box.add(_rounded(INK, 14))
		box.add(_rounded(CREAM, 8))
	box.add(_rounded(INK, 0), Vector2(0, 14 if focused else 10))
	var body := _rounded(fill, 0)
	body.set_border_width_all(6)
	body.border_color = INK
	box.add(body)
	var shade := _rounded(Color(INK, 0.18), 0)
	shade.draw_center = false
	shade.border_width_bottom = 16  # under the stroke, 10 px of the body
	box.add(shade)
	return box


## The button's rounded shape, grown by `spread` on every side.
static func _rounded(color: Color, spread: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color
	box.set_corner_radius_all(28 + spread)
	box.set_expand_margin_all(spread)
	return box


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
