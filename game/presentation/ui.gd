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
const SKY := Color("a8e2ff")
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
	node.focus_entered.connect(bounce.bind(node))
	return node


## Swells `control` to `from` times its size and lets it spring back.
static func bounce(control: Control, from: float = 1.15) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * from
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
		box.add(rounded(INK, radius, 14))
		box.add(rounded(CREAM, radius, 8))
	box.add(rounded(shadow, radius, 0), Vector2(0, 14 if focused else 10))
	var body := rounded(fill, radius, 0)
	body.set_border_width_all(stroke_width)
	body.border_color = stroke
	box.add(body)
	var shade := rounded(Color(INK, 0.18), radius, 0)
	shade.draw_center = false
	shade.border_width_bottom = stroke_width + 10  # under the stroke, 10 px of the body
	box.add(shade)
	return box


## A rounded shape, grown by `spread` on every side.
static func rounded(color: Color, radius: int, spread: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color
	box.set_corner_radius_all(radius + spread)
	box.set_expand_margin_all(spread)
	return box


## A surface claimed by a player: a ring of that player's colour inside an inked one, lifted
## on a deeper shadow.
static func claimed(fill: Color, color: Color, radius: int = 40) -> Layers:
	var box := Layers.new()
	box.add(rounded(INK, radius, 6), Vector2(0, 16))
	box.add(rounded(INK, radius, 6))
	var body := rounded(fill, radius, 0)
	body.set_border_width_all(12)
	body.border_color = color
	box.add(body)
	return box


## A screen's title: the design's yellow letters, inked round and on a hard shadow.
static func title(text: String, font_size: int = 88) -> Label:
	var node := label(text, font_size, YELLOW, LILITA)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", 10)  # scaled by the theme to the design's 24
	node.add_theme_color_override("font_shadow_color", INK)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 14)
	node.add_theme_constant_override("shadow_outline_size", 10)
	return node


## The design's Badge: a word on a pill, light on ink or ink on cream.
static func badge(text: String, dark: bool) -> PanelContainer:
	var node := PanelContainer.new()
	var box := rounded(INK if dark else CREAM, 28, 0)
	box.set_border_width_all(6)
	box.border_color = INK
	box.set_content_margin(SIDE_LEFT, 16)
	box.set_content_margin(SIDE_RIGHT, 16)
	box.set_content_margin(SIDE_TOP, 0)
	box.set_content_margin(SIDE_BOTTOM, 0)
	node.add_theme_stylebox_override("panel", box)
	node.add_child(label(text, 28, CREAM if dark else INK, FREDOKA_SEMIBOLD))
	return node


## A word on a pill of `fill`, inked round, as the design's PlayerTag names a Player. More parts
## can follow the word in its first child.
static func tag(text: String, fill: Color, text_color: Color = INK) -> PanelContainer:
	var node := PanelContainer.new()
	var box := rounded(fill, 28, 0)
	box.set_border_width_all(6)
	box.border_color = INK
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	node.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	node.add_child(row)
	row.add_child(label(text, 28, text_color, LILITA))
	return node


## The design's KeyCap: the name of a key on a small cream cap; "up", "down", "left" and "right"
## are arrows.
static func key_cap(key: String) -> PanelContainer:
	var node := PanelContainer.new()
	var box := Layers.new()
	box.add(rounded(INK, 28, 0), Vector2(0, 8))
	var body := rounded(CREAM, 28, 0)
	body.set_border_width_all(6)
	body.border_color = INK
	box.add(body)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 10
	node.add_theme_stylebox_override("panel", box)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Arrow.TURNS.has(key):
		node.add_child(Arrow.new(key))
	else:
		node.add_child(label(key, 28, INK, LILITA))
	return node


## The design's portrait: a picture on a rounded square of `color`, inked round, standing on its
## bottom edge or `centred`. `inset` is the room the picture leaves on each side.
static func portrait(path: String, side: int, inset: int, color: Color, radius: int = 40,
		centred: bool = false) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(side, side)
	var back := Panel.new()
	back.size = node.custom_minimum_size
	back.add_theme_stylebox_override("panel", rounded(color, radius, 0))
	back.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	node.add_child(back)
	var size := side - 2 * inset
	picture(path, Rect2(inset, inset if centred else side - size, size, size), back)
	var ring := Panel.new()
	ring.size = node.custom_minimum_size
	var stroke := rounded(Color.TRANSPARENT, radius, 0)
	stroke.draw_center = false
	stroke.set_border_width_all(6)
	stroke.border_color = INK
	ring.add_theme_stylebox_override("panel", stroke)
	node.add_child(ring)
	return node


## The design's WinPip: a Round won, in yellow, or still to win.
static func pip(won: bool) -> Panel:
	var node := Panel.new()
	node.custom_minimum_size = Vector2(36, 36)
	var box := rounded(YELLOW if won else CREAM, 18, 0)
	box.set_border_width_all(6)
	box.border_color = INK
	node.add_theme_stylebox_override("panel", box)
	return node


## A row of `count` WinPips, the first `won` of them yellow.
static func pips(won: int, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for at in count:
		row.add_child(pip(at < won))
	return row


## The design's Toggle: a cream row named on its left, pressed anywhere to flip the switch on its
## right, green with the knob right when on, inked with the knob left when off.
static func toggle(text: String, on: bool, on_toggled: Callable) -> Button:
	var node := button(text, func() -> void: pass)
	node.toggle_mode = true
	node.button_pressed = on
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state: String in ["normal", "focus"]:
		node.get_theme_stylebox(state).content_margin_left = 32
	var switch := Panel.new()
	switch.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	switch.offset_left = -132
	switch.offset_right = -32
	switch.offset_top = -28
	switch.offset_bottom = 28
	switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(switch)
	var knob := Panel.new()
	knob.size = Vector2(40, 40)
	var knob_box := rounded(CREAM, 20, 0)
	knob_box.set_border_width_all(6)
	knob_box.border_color = INK
	knob.add_theme_stylebox_override("panel", knob_box)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch.add_child(knob)
	var show := func(now_on: bool) -> void:
		var box := rounded(GREEN if now_on else INK, 28, 0)
		box.set_border_width_all(6)
		box.border_color = INK
		switch.add_theme_stylebox_override("panel", box)
		knob.position = Vector2(54 if now_on else 6, 8)
	show.call(on)
	node.toggled.connect(show)
	node.toggled.connect(on_toggled)
	return node


## A small round cream button with a glyph, ringed when focused.
static func round_button(glyph: String, diameter: int, on_pressed: Callable) -> Button:
	var node := Button.new()
	node.text = glyph
	node.custom_minimum_size = Vector2(diameter, diameter)
	var body := rounded(CREAM, diameter / 2, 0)
	body.set_border_width_all(6)
	body.border_color = INK
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		node.add_theme_stylebox_override(state, body)
	var focus := Layers.new()
	focus.add(rounded(INK, diameter / 2, 10))
	focus.add(rounded(CREAM, diameter / 2, 5))
	focus.add(body)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_font_override("font", LILITA)
	node.add_theme_font_size_override("font_size", 28)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(color, INK)
	node.mouse_entered.connect(node.grab_focus)
	node.pressed.connect(on_pressed)
	node.pressed.connect(Audio.play.bind(&"ui_confirm"))
	return node


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
	box.add(rounded(Color(INK, 0.35), 28, 0), Vector2(0, 12))
	box.add(rounded(INK, 28, 0))
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


## The arrow of a KeyCap, which the design's letters have none of.
class Arrow:
	extends Control

	const TURNS := {"right": 0.0, "down": 0.25, "left": 0.5, "up": 0.75}
	var _angle: float

	func _init(direction: String) -> void:
		_angle = TAU * TURNS[direction]
		custom_minimum_size = Vector2(22, 34) if direction == "left" or direction == "right" else Vector2(28, 34)

	func _draw() -> void:
		var points := PackedVector2Array([Vector2(9, 0), Vector2(-7, -10), Vector2(-7, 10)])
		for i in points.size():
			points[i] = size / 2.0 + points[i].rotated(_angle)
		draw_colored_polygon(points, INK)


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
