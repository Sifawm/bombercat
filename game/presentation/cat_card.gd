class_name CatCard
extends VBoxContainer
## The design's CatCard: one Cat on its sky, or the Random choice, free or claimed in a colour,
## with the tags of who claims it above it.

const TAG_HEIGHT := 62

## What takes the focus and is pressed to choose this Cat.
var button := Button.new()
var _tags := HBoxContainer.new()


## `pick` is the index in Roster.CATS, or -1 for Random. The sky is `portrait_height` tall.
func _init(pick: int, card_size: Vector2, portrait_height: int) -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 0)
	_tags.custom_minimum_size.y = TAG_HEIGHT
	_tags.alignment = BoxContainer.ALIGNMENT_CENTER
	_tags.add_theme_constant_override("separation", 8)
	add_child(_tags)
	button.custom_minimum_size = card_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # however wide its tags
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", Ui.surface(Ui.CREAM, true, 40))
	button.mouse_entered.connect(func() -> void:
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus())
	button.focus_entered.connect(Ui.bounce.bind(button))
	button.pressed.connect(Audio.play.bind(&"ui_confirm"))
	add_child(button)
	var inside := MarginContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inside.add_theme_constant_override(side, 16)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inside)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(column)
	var portrait := PanelContainer.new()
	var sky := Ui.rounded(Ui.SKY, 28, 0)
	sky.content_margin_bottom = 12
	portrait.add_theme_stylebox_override("panel", sky)
	portrait.custom_minimum_size = Vector2(card_size.x - 32, portrait_height)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	if pick == -1:
		var mark := Ui.title("?", 200)
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait.add_child(mark)
	else:
		var cat := ModelView.new(Roster.cat_scene(pick), Vector2(193, 300), true)
		cat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cat.size_flags_vertical = Control.SIZE_SHRINK_END
		cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat.play("idle", float(pick) / Roster.CATS.size())
		portrait.add_child(cat)
	column.add_child(Ui.label("Random" if pick == -1 else Roster.cat_name(pick), 32, Ui.INK, Ui.LILITA))


## Free when `color` is null; otherwise claimed in that colour, under `tags`.
func show_claim(color: Variant, tags: Array[Control]) -> void:
	for child in _tags.get_children():
		_tags.remove_child(child)
		child.queue_free()
	var box: StyleBox = Ui.surface(Ui.CREAM, false, 40) if color == null else Ui.claimed(Ui.CREAM, color)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	for tag in tags:
		tag.size_flags_vertical = Control.SIZE_SHRINK_END
		_tags.add_child(tag)
