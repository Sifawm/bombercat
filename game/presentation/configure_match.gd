class_name ConfigureMatch
extends Control
## The settings of the next Match, which the Admin changes and the others watch: the Map, the
## Rounds that win it, how long a Round lasts, and who plays. Its parts stand where the design's
## ConfigureMatch puts them.

## The limits of the settings, which the server enforces: see `isSettings` in shared/.
const MIN_ROUNDS := 1
const MAX_ROUNDS := 5
const MIN_TIME := 30
const MAX_TIME := 300
const TIME_STEP := 30
const REJECTIONS: Dictionary[String, String] = {
	"belowMinPlayers": "A Match needs at least 2 Users",
	"tooManyUsers": "This Map has no room for so many Users",
	"tooFewUsers": "A Match needs at least 2 Users connected",
	"invalidSettings": "The server does not take that setting",
}
const TITLE := Vector2(64, 48)
const PICKER := Rect2(64, 197, 960, 681)
const SETTINGS := Rect2(1072, 195, 784, 685)
const BACK := Rect2(64, 932, 360, 88)
## Between the back button and the main action, where an error is told.
const ERROR := Rect2(448, 920, 784, 112)
## The foot's right half, where the main action or what the others wait for stands.
const MAIN := Rect2(1072, 920, 784, 112)

## By Map name, its size and how many Spawn Points it has.
static var _map_facts: Dictionary[String, Array] = {}

var _maps: Array[String] = []
var _previous := _arrow("‹", _step_map.bind(-1))
var _next := _arrow("›", _step_map.bind(1))
var _map_image := TextureRect.new()
var _map_name := Ui.label("", 64, Ui.INK, Ui.LILITA)
var _map_meta := Ui.label("", 32, Ui.INK, Ui.FREDOKA_MEDIUM)
var _thumbs := HBoxContainer.new()
var _rounds := Stepper.new(_step_rounds)
var _rounds_help := _help()
var _time := Stepper.new(_step_time)
var _time_help := _help()
var _players := HBoxContainer.new()
var _back := Ui.button("", _go_back)
var _footer_notice := CenterContainer.new()
var _start := Ui.button("Start Match", _send.bind("porter:startMatch"), true)
var _waiting := Ui.label("", 32, Ui.INK, Ui.FREDOKA_SEMIBOLD)
## Whether a change is waiting to be drawn: several may come in one frame.
var _stale := false
var _rejection_listener := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for file in ResourceLoader.list_directory("res://maps"):
		if file.ends_with(".tscn"):
			_maps.append(file.get_basename())
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var title := Ui.title("Configure Match")
	title.position = TITLE
	frame.add_child(title)
	frame.add_child(_picker())
	frame.add_child(_settings())
	_back.position = BACK.position
	_back.custom_minimum_size = BACK.size
	frame.add_child(_back)
	_footer_notice.position = ERROR.position
	_footer_notice.size = ERROR.size
	_footer_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_footer_notice)
	var main := HBoxContainer.new()
	main.position = MAIN.position
	main.size = MAIN.size
	main.alignment = BoxContainer.ALIGNMENT_END
	_start.custom_minimum_size = Vector2(520, 112)
	main.add_child(_start)
	_waiting.size_flags_horizontal = Control.SIZE_SHRINK_END
	main.add_child(_waiting)
	frame.add_child(main)


## The Map card between its arrows, and under it a thumbnail of every Map.
func _picker() -> VBoxContainer:
	var picker := VBoxContainer.new()
	picker.position = PICKER.position
	picker.size = PICKER.size
	picker.add_theme_constant_override("separation", 24)
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
	picker.add_child(carousel)
	var thumbs := CenterContainer.new()
	thumbs.custom_minimum_size.x = 768
	_thumbs.add_theme_constant_override("separation", 24)
	for map in _maps:
		_thumbs.add_child(_thumb(map))
	thumbs.add_child(_thumbs)
	picker.add_child(thumbs)
	return picker


func _thumb(map: String) -> Button:
	var thumb := Button.new()
	thumb.custom_minimum_size = Vector2(216, 136)
	thumb.focus_entered.connect(Ui.bounce.bind(thumb))
	thumb.mouse_entered.connect(func() -> void:
		if thumb.focus_mode != Control.FOCUS_NONE:
			thumb.grab_focus())
	thumb.pressed.connect(_choose_map.bind(map))
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


func _settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = SETTINGS.position
	panel.custom_minimum_size = SETTINGS.size
	var box := Ui.surface(Ui.CREAM, false, 40)
	box.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	column.add_child(_section("Rounds to win", [_rounds, _rounds_help]))
	column.add_child(_section("Round time", [_time, _time_help]))
	_players.add_theme_constant_override("separation", 12)
	column.add_child(_section("Players", [_players]))
	return panel


func _section(heading: String, parts: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	var label := Ui.label(heading, 32, Ui.INK, Ui.LILITA)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(label)
	for part: Control in parts:
		part.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		section.add_child(part)
	return section


func _ready() -> void:
	var porter := Online.porter
	for changed: Signal in [porter.connection_changed, porter.room_changed, porter.game_changed]:
		changed.connect(func(_part: Variant) -> void: _stale = true)
	_rejection_listener = porter.on("porter:messageRejected", _rejected)
	_render()
	(_rounds if Online.porter.room.isAdmin else _back as Control).grab_focus()


func _exit_tree() -> void:
	Online.porter.off(_rejection_listener)


func _process(_delta: float) -> void:
	if _stale:
		_render()


func _render() -> void:
	_stale = false
	var room: Variant = Online.porter.room
	if room == null:
		return  # on the way out
	var admin: bool = room.isAdmin
	var settings: Dictionary = Online.porter.game.settings
	var map: String = settings.map
	var facts := _facts(map)
	_map_image.texture = _map_texture(map)
	_map_name.text = map.capitalize()
	# No two Players bring the same Cat, so a Map with more Spawn Points than Cats seats them all.
	_map_meta.text = "%d × %d · up to %d players" % [facts[0].x, facts[0].y, mini(facts[1], Roster.CATS.size())]
	for arrow: Button in [_previous, _next]:
		arrow.visible = admin
		arrow.disabled = _maps.size() < 2
	for at in _maps.size():
		var thumb := _thumbs.get_child(at) as Button
		var chosen := _maps[at] == map
		var box: StyleBox = Ui.claimed(Ui.CREAM, Ui.YELLOW, 28) if chosen else Ui.surface(Ui.CREAM, false, 28)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			thumb.add_theme_stylebox_override(state, box)
		thumb.add_theme_stylebox_override("focus", Ui.surface(Ui.CREAM, true, 28))
		thumb.disabled = not admin or chosen
		thumb.focus_mode = Control.FOCUS_ALL if admin and not chosen else Control.FOCUS_NONE
	var rounds := int(settings.roundsToWin)
	var seconds := int(settings.roundTime)
	_rounds.show_value(str(rounds), admin)
	_rounds_help.text = "First to %d wins the Match" % rounds
	_time.show_value("%d:%02d" % [seconds / 60, seconds % 60], admin)
	_time_help.text = "Per Round, from %d:%02d to %d:%02d" % [MIN_TIME / 60, MIN_TIME % 60, MAX_TIME / 60, MAX_TIME % 60]
	for chip in _players.get_children():
		_players.remove_child(chip)
		chip.queue_free()
	for at: int in room.users.size():
		_players.add_child(_chip(room.users[at], at))
	_back.text = "Back to Room" if admin else "Leave"
	_start.visible = admin
	_waiting.visible = not admin
	_waiting.text = "Waiting for %s to start..." % room.admin
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree() or focused.focus_mode == Control.FOCUS_NONE:
		(_rounds if admin else _back as Control).grab_focus()


## The design's PlayerChip: a User's Cat in a ring of its colour, and its name.
func _chip(user: Dictionary, at: int) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := Ui.rounded(Ui.CREAM, 28, 0)
	box.set_border_width_all(6)
	box.border_color = Ui.INK
	box.content_margin_left = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.content_margin_right = 28
	chip.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	chip.add_child(row)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(64, 64)
	var sky := Panel.new()
	sky.size = avatar.custom_minimum_size
	sky.add_theme_stylebox_override("panel", Ui.rounded(Ui.SKY, 32, 0))
	sky.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	avatar.add_child(sky)
	var cat := Ui.picture(Roster.portrait(int(user.profile.cat)), Rect2(1, 4, 63, 96), sky)
	cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var ring := Panel.new()
	ring.size = avatar.custom_minimum_size
	var stroke := Ui.rounded(Color.TRANSPARENT, 32, 0)
	stroke.draw_center = false
	stroke.set_border_width_all(6)
	stroke.border_color = Roster.PLAYER_COLORS[at]
	ring.add_theme_stylebox_override("panel", stroke)
	avatar.add_child(ring)
	row.add_child(avatar)
	var name_label := Ui.label(user.name, 28, Ui.INK, Ui.LILITA)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	chip.modulate.a = 0.5 if user.status == "reconnecting" else 1.0
	return chip


func _step_map(step: int) -> void:
	var at := _maps.find(Online.porter.game.settings.map)
	_choose_map(_maps[posmod(at + step, _maps.size())])


func _choose_map(map: String) -> void:
	_change_settings({"map": map})


func _step_rounds(step: int) -> void:
	var rounds := int(Online.porter.game.settings.roundsToWin) + step
	_change_settings({"roundsToWin": clampi(rounds, MIN_ROUNDS, MAX_ROUNDS)})


func _step_time(step: int) -> void:
	var seconds := int(Online.porter.game.settings.roundTime) + step * TIME_STEP
	_change_settings({"roundTime": clampi(seconds, MIN_TIME, MAX_TIME)})


## The Admin sends the settings whole, with one of them changed.
func _change_settings(change: Dictionary) -> void:
	var settings: Dictionary = Online.porter.game.settings
	var next := {"map": settings.map, "roundsToWin": settings.roundsToWin, "roundTime": settings.roundTime}
	next.merge(change, true)
	_send("porter:updateSettings", next)


func _go_back() -> void:
	if Online.porter.room.isAdmin:
		_send("backToRoom")
	else:
		Online.porter.leave()


## Every action of the User puts away the error it had been told.
func _send(event: String, data: Variant = null) -> void:
	_clear_error()
	Online.porter.send(event, data)


func _rejected(rejection: Dictionary) -> void:
	var reason: Variant = rejection.reason
	var code: String = reason if reason is String else reason.reason
	_clear_error()
	_footer_notice.add_child(Ui.notice(Ui.Tone.ERROR, REJECTIONS.get(code, code)))


func _clear_error() -> void:
	for child in _footer_notice.get_children():
		child.queue_free()


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


static func _help() -> Label:
	var label := Ui.label("", 28, Ui.INK, Ui.FREDOKA_MEDIUM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


## The design's ArrowButton: a glyph on a small cream surface.
static func _arrow(glyph: String, on_pressed: Callable) -> Button:
	var arrow := Ui.button(glyph, on_pressed)
	arrow.custom_minimum_size = Vector2(72, 72)
	arrow.add_theme_font_size_override("font_size", 64)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		arrow.get_theme_stylebox(state).set_content_margin_all(0)
	return arrow


## The design's Stepper: a value between two arrows that step it, by mouse or by left and right
## while it has the focus; only the value for whoever may not change it.
class Stepper:
	extends PanelContainer

	var _value := Ui.label("", 64, Ui.INK, Ui.LILITA)
	var _arrows: Array[Button] = []
	var _on_step: Callable
	var _plain: StyleBox
	var _focused: StyleBox

	func _init(on_step: Callable) -> void:
		_on_step = on_step
		_plain = Ui.surface(Ui.CREAM, false, 28, Ui.INK, 6, Color.TRANSPARENT)
		_focused = Ui.surface(Ui.CREAM, true, 28)
		for box: StyleBox in [_plain, _focused]:
			box.set_content_margin_all(12)
		add_theme_stylebox_override("panel", _plain)
		focus_entered.connect(func() -> void: add_theme_stylebox_override("panel", _focused))
		focus_exited.connect(func() -> void: add_theme_stylebox_override("panel", _plain))
		mouse_entered.connect(func() -> void:
			if focus_mode != Control.FOCUS_NONE:
				grab_focus())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		row.add_child(_arrow_button("‹", -1))
		_value.custom_minimum_size = Vector2(200, 100)
		_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(_value)
		row.add_child(_arrow_button("›", 1))

	func _arrow_button(glyph: String, step: int) -> Button:
		var arrow := Button.new()
		arrow.text = glyph
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(64, 64)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var body := Ui.rounded(Ui.INK, 32, 0)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			arrow.add_theme_stylebox_override(state, body)
		arrow.add_theme_font_override("font", Ui.LILITA)
		arrow.add_theme_font_size_override("font_size", 64)
		for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			arrow.add_theme_color_override(color, Ui.CREAM)
		arrow.pressed.connect(_step.bind(step))
		_arrows.append(arrow)
		return arrow

	func show_value(text: String, editable: bool) -> void:
		_value.text = text
		for arrow in _arrows:
			arrow.visible = editable
		focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE

	func _gui_input(event: InputEvent) -> void:
		for step: int in [-1, 1]:
			if event.is_action_pressed("ui_left" if step == -1 else "ui_right"):
				_step(step)
				accept_event()

	func _step(step: int) -> void:
		Audio.play(&"ui_confirm")
		_on_step.call(step)
