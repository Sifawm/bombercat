class_name RoundHud
extends HBoxContainer
## The Players' side of the HUD, along the top of the picture: for each one its Cat's
## portrait and name, the Rounds it has won and the Powerups it holds.

const PORTRAIT_SIZE := Vector2(120, 120)
const POWERUP_SIZE := Vector2(52, 52)
const SEPARATION := 24
## The middle of the picture, left to the timer.
const TIMER_WIDTH := 472
## How wide the texts of a panel are with two Players, and how much smaller everything is
## with more.
const TEXTS_WIDTH := 480
const CROWDED_SCALE := 0.5

var _names: Array[String] = []
var _wins_labels: Array[Label] = []
var _held_rows: Array[HBoxContainer] = []
## What each row of held Powerups is showing, to rebuild it only when it changes.
var _held_shown: Array[Array] = []


## `cat_picks` holds the index in Roster.CATS of each Player's Cat, and `names` what to
## call each Player.
func _init(cat_picks: Array[int], names: PackedStringArray) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", SEPARATION)
	var crowded := cat_picks.size() > 2
	var on_the_left := ceili(cat_picks.size() / 2.0)
	for player in cat_picks.size():
		if player == on_the_left:
			var timer_space := Control.new()
			timer_space.custom_minimum_size.x = TIMER_WIDTH
			add_child(timer_space)
		var mirrored := player >= on_the_left  # the right-hand panels read from the right
		var panel := HBoxContainer.new()
		var portrait := ModelView.new(Roster.cat_scene(cat_picks[player]),
				PORTRAIT_SIZE * (0.75 if crowded else 1.0))
		portrait.play("idle")
		var texts := VBoxContainer.new()
		texts.custom_minimum_size.x = TEXTS_WIDTH * (CROWDED_SCALE if crowded else 1.0)
		var wins := Ui.label("", Ui.SMALL_SIZE if crowded else 0, Roster.PLAYER_COLORS[player])
		var held := HBoxContainer.new()
		held.custom_minimum_size.y = POWERUP_SIZE.y
		held.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_child(wins)
		texts.add_child(held)
		panel.add_child(portrait)
		panel.add_child(texts)
		if mirrored:
			panel.move_child(portrait, 1)
		add_child(panel)
		_names.append(names[player])
		_wins_labels.append(wins)
		_held_rows.append(held)
		_held_shown.append([])


func show_wins(wins: Array[int], rounds_to_win: int) -> void:
	for player in wins.size():
		_wins_labels[player].text = "%s   %d / %d" % [_names[player], wins[player], rounds_to_win]


## Shows the Powerups a Player's Cat holds (their ids): one model of each kind, with how
## many when there are several.
func show_held(player: int, held: Array[StringName]) -> void:
	if held == _held_shown[player]:
		return
	_held_shown[player] = held
	var row := _held_rows[player]
	for child in row.get_children():
		child.queue_free()
	var kinds: Array[StringName] = []
	for powerup_id in held:
		if not kinds.has(powerup_id):
			kinds.append(powerup_id)
	for powerup_id in kinds:
		var scene: PackedScene = load("res://assets/models/%s.glb" % powerup_id)
		row.add_child(ModelView.new(scene, POWERUP_SIZE))
		if held.count(powerup_id) > 1:
			row.add_child(Ui.label("x%d" % held.count(powerup_id), Ui.SMALL_SIZE))
