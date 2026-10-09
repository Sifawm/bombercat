class_name RoundHud
extends HBoxContainer
## The Players' side of the HUD, along the top of the picture: for each one its Cat's
## portrait and name, the Rounds it has won and the Powerups it holds.

const PORTRAIT_SIZE := Vector2(120, 120)
const POWERUP_SIZE := Vector2(52, 52)

var _names: Array[String] = []
var _wins_labels: Array[Label] = []
var _held_rows: Array[HBoxContainer] = []
## What each row of held Powerups is showing, to rebuild it only when it changes.
var _held_shown: Array[Array] = []


## `cat_picks` holds the index in Roster.CATS of each Player's Cat.
func _init(cat_picks: Array[int]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 520)  # leaves the middle to the timer
	for player in cat_picks.size():
		var mirrored := player % 2 == 1  # the right-hand panel reads from the right
		var panel := HBoxContainer.new()
		var portrait := ModelView.new(Roster.cat_scene(cat_picks[player]), PORTRAIT_SIZE)
		portrait.play("idle")
		var texts := VBoxContainer.new()
		texts.custom_minimum_size.x = 480
		var wins := Ui.label("", 0, Roster.PLAYER_COLORS[player])
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
		_names.append(Roster.cat_name(cat_picks[player]))
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
