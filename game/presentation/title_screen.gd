class_name TitleScreen
extends Control

signal play_pressed

var _play: Button
var _how_to_play: Button


func _init() -> void:
	var column := Ui.centred_column(self, 40)
	column.add_child(Ui.label("BomberCat", 160, Color(1.0, 0.8, 0.3)))
	var cats := HBoxContainer.new()
	cats.alignment = BoxContainer.ALIGNMENT_CENTER
	for pick in Roster.CATS.size():
		var cat := ModelView.new(Roster.cat_scene(pick), Vector2(220, 260))
		cat.play("idle")
		cats.add_child(cat)
	column.add_child(cats)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play = Ui.button("Play", play_pressed.emit)
	_how_to_play = Ui.button("How to Play", _show_how_to_play)
	menu.add_child(_play)
	menu.add_child(_how_to_play)
	if not OS.has_feature("web"):  # a browser tab is closed, not quit
		menu.add_child(Ui.button("Quit", func() -> void: get_tree().quit()))
	column.add_child(menu)


func _ready() -> void:
	_play.grab_focus()


func _show_how_to_play() -> void:
	var card := HowToPlay.new()
	card.closed.connect(_how_to_play.grab_focus)
	add_child(card)
