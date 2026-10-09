class_name Ui
## Shorthands for the screens, which build their controls in code.

const TITLE_SIZE := 96
const SMALL_SIZE := 28


static func label(text: String, font_size: int = 0, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_color_override("font_color", color)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)
	return node


static func button(text: String, on_pressed: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(on_pressed)
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
