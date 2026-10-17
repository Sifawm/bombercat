class_name MapPicker
extends VBoxContainer
## The design's map picker: the Map shown on its card between two arrows, and under it a
## thumbnail of every Map. It only tells which Map is wanted; its owner decides and shows it.

signal chosen(map: String)

## By Map name, its size and how many Spawn Points it has.
static var _map_facts: Dictionary[String, Array] = {}

## Every Map in the project, by name.
var maps: Array[String] = []
var _map := ""
var _previous := _arrow("‹", step.bind(-1))
var _next := _arrow("›", step.bind(1))
var _map_image := TextureRect.new()
var _map_name := Ui.label("", 64, Ui.INK, Ui.LILITA)
var _map_meta := Ui.label("", 32, Ui.INK, Ui.FREDOKA_MEDIUM)
var _thumbs := HBoxContainer.new()
## The row of thumbnails, as wide as the card and kept under it.
var _under_card := CenterContainer.new()


func _init() -> void:
	for file in ResourceLoader.list_directory("res://maps"):
		if file.ends_with(".tscn"):
			maps.append(file.get_basename())
	add_theme_constant_override("separation", 24)
	var carousel := HBoxContainer.new()
	carousel.add_theme_constant_override("separation", 24)
	_previous.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carousel.add_child(_previous)
	var card := PanelContainer.new()
	var box := Ui.surface(Ui.CREAM, false, 40)
	box.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var preview := _sky(Vector2(720, 380))
	_map_image.custom_minimum_size = Vector2(620, 378)
	_map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(_map_image)
	column.add_child(preview)
	var info := HBoxContainer.new()
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 8)
	name_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_margin.add_child(_map_name)
	info.add_child(name_margin)
	var meta_margin := MarginContainer.new()
	meta_margin.add_theme_constant_override("margin_right", 8)
	meta_margin.add_child(_map_meta)
	info.add_child(meta_margin)
	column.add_child(info)
	carousel.add_child(card)
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carousel.add_child(_next)
	add_child(carousel)
	_under_card.custom_minimum_size.x = 768
	_thumbs.add_theme_constant_override("separation", 24)
	for map in maps:
		_thumbs.add_child(_thumb(map))
	_under_card.add_child(_thumbs)
	add_child(_under_card)


## Shows `map` as the chosen one; only with `can_change` may the arrows and thumbnails ask for another.
func show_map(map: String, can_change: bool) -> void:
	_map = map
	var facts := _facts(map)
	_map_image.texture = _map_texture(map)
	_map_name.text = map.capitalize()
	# No two Players bring the same Cat, so a Map with more Spawn Points than Cats seats them all.
	_map_meta.text = "%d × %d · up to %d players" % [facts[0].x, facts[0].y, mini(facts[1], Roster.CATS.size())]
	for arrow: Button in [_previous, _next]:
		arrow.visible = can_change
		arrow.disabled = maps.size() < 2
	# Without the arrows the card stands at the left edge, and so do the thumbnails under it.
	_under_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if can_change else Control.SIZE_SHRINK_BEGIN
	for at in maps.size():
		var thumb := _thumbs.get_child(at) as Button
		var is_chosen := maps[at] == map
		var box: StyleBox = Ui.claimed(Ui.CREAM, Ui.YELLOW, 28) if is_chosen else Ui.surface(Ui.CREAM, false, 28)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			thumb.add_theme_stylebox_override(state, box)
		thumb.add_theme_stylebox_override("focus", Ui.surface(Ui.CREAM, true, 28))
		thumb.disabled = not can_change or is_chosen
		thumb.focus_mode = Control.FOCUS_ALL if can_change and not is_chosen else Control.FOCUS_NONE


## Asks for the Map `by` places after the one shown, round the list.
func step(by: int) -> void:
	chosen.emit(maps[posmod(maps.find(_map) + by, maps.size())])


func _thumb(map: String) -> Button:
	var thumb := Button.new()
	thumb.custom_minimum_size = Vector2(216, 136)
	thumb.focus_entered.connect(Ui.bounce.bind(thumb))
	thumb.mouse_entered.connect(func() -> void:
		if thumb.focus_mode != Control.FOCUS_NONE:
			thumb.grab_focus())
	thumb.pressed.connect(func() -> void: chosen.emit(map))
	thumb.pressed.connect(Audio.play.bind(&"ui_confirm"))
	var inside := MarginContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inside.add_theme_constant_override(side, 8)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(inside)
	var preview := _sky(Vector2(200, 120))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = _map_texture(map)
	image.custom_minimum_size = Vector2(184, 112)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(image)
	inside.add_child(preview)
	return thumb


static func _facts(map: String) -> Array:
	if not _map_facts.has(map):
		var scene := (load("res://maps/%s.tscn" % map) as PackedScene).instantiate() as MapScene
		var data := scene.to_map_data()
		scene.free()
		_map_facts[map] = [data.size, data.spawn_points.size()]
	return _map_facts[map]


static func _map_texture(map: String) -> Texture2D:
	return load("res://assets/maps/%s.png" % map)


static func _sky(size: Vector2) -> PanelContainer:
	var sky := PanelContainer.new()
	sky.custom_minimum_size = size
	sky.add_theme_stylebox_override("panel", Ui.rounded(Ui.SKY, 28, 0))
	return sky


## The design's ArrowButton: a glyph on a small cream surface.
static func _arrow(glyph: String, on_pressed: Callable) -> Button:
	var arrow := Ui.button(glyph, on_pressed)
	arrow.custom_minimum_size = Vector2(72, 72)
	arrow.add_theme_font_size_override("font_size", 64)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		arrow.get_theme_stylebox(state).set_content_margin_all(0)
	return arrow
