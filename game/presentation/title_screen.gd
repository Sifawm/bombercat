class_name TitleScreen
extends Control
## The first screen after the Splash: the game's name, the five Cats on a stage and the way into
## a Match. Its parts stand where the design's TitleScreen puts them.

signal play_pressed
signal online_pressed

const BOMBER := Rect2(448, 25, 734, 350)
const CAT := Rect2(1108, 25, 364, 350)
const PLATFORM := Rect2(280, 602, 1360, 156)
## The first Cat's place; the others follow it one CAT_STEP apart.
const CAT_SLOT := Rect2(380, 342, 205, 320)
const CAT_STEP := 239.0
const MENU := Rect2(584, 790, 752, 232)
const MENU_GAP := 32
## How far the name floats up and down.
const LOGO_FLOAT := 6.0

var _logo := Control.new()
var _clock := 0.0
var _play: Button
var _how_to_play: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	frame.add_child(_logo)
	Ui.picture("res://assets/splash/wordmark_bomber.png", BOMBER, _logo)
	Ui.picture("res://assets/splash/wordmark_cat.png", CAT, _logo)
	Ui.picture("res://assets/title/platform.png", PLATFORM, frame)
	var laser := LaserPointer.new()
	for pick in Roster.CATS.size():
		var slot := Rect2(CAT_SLOT.position + Vector2(CAT_STEP * pick, 0.0), CAT_SLOT.size)
		frame.add_child(_ground_shadow(slot))
		var phase := float(pick) / Roster.CATS.size()  # out of step, as five cats would be
		var cat := LaserCat.new(Roster.cat_scene(pick), slot.size, laser.dot, phase)
		cat.position = slot.position
		frame.add_child(cat)
	frame.add_child(_menu())
	add_child(laser)


func _ready() -> void:
	_play.grab_focus()


func _process(delta: float) -> void:
	_clock += delta
	_logo.position.y = LOGO_FLOAT * sin(_clock * 2.0)


func _menu() -> VBoxContainer:
	var menu := VBoxContainer.new()
	menu.position = MENU.position
	menu.size = MENU.size
	menu.add_theme_constant_override("separation", MENU_GAP)
	_play = Ui.button("Play", play_pressed.emit, true)
	_play.custom_minimum_size = Vector2(520, 112)
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_child(_play)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", MENU_GAP)
	if Online.porter != null:
		row.add_child(_secondary("Play Online", online_pressed.emit))
	_how_to_play = _secondary("How to Play", _show_how_to_play)
	row.add_child(_how_to_play)
	if not OS.has_feature("web"):  # a browser tab is closed, not quit
		row.add_child(_secondary("Quit", func() -> void: get_tree().quit()))
	menu.add_child(row)
	return menu


func _secondary(text: String, on_pressed: Callable) -> Button:
	var button := Ui.button(text, on_pressed)
	button.custom_minimum_size = Vector2(360, 88)
	return button


## The shade of ink a Cat stands on.
func _ground_shadow(slot: Rect2) -> Polygon2D:
	var centre := Vector2(slot.get_center().x, slot.end.y - 6.0)
	var points := PackedVector2Array()
	for i in 48:
		points.append(centre + Vector2(87.0, 16.0) * Vector2.from_angle(TAU * i / 48.0))
	var shadow := Polygon2D.new()
	shadow.polygon = points
	shadow.color = Color(Ui.INK, 0.25)
	shadow.antialiased = true
	return shadow


func _show_how_to_play() -> void:
	HowToPlay.open_over(self, _how_to_play)
