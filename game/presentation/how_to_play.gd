class_name HowToPlay
extends ColorRect
## The How to Play card: the controls and what each Powerup does. Shown over the Title
## screen or the Pause menu; closes itself.

signal closed

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const CONTROLS: Array[Array] = [
	["", "Move", "Bomb", "Meow"],
	["Player 1", "W A S D", "Space", "Q"],
	["Player 2", "Arrow keys", "Enter", "Right Shift"],
	["Gamepad", "Stick or d-pad", "A", "X"],
]
## In catalogue order: id, name, effect.
const POWERUPS: Array[Array] = [
	[&"yarn_ball", "Yarn Ball", "+1 Bomb Capacity"],
	[&"tuna_can", "Tuna Can", "+1 Range"],
	[&"catnip", "Catnip", "Your Cat runs faster"],
	[&"paw_swipe", "Paw Swipe", "Walk into a Bomb to push it"],
	[&"nine_lives", "Nine Lives", "Survive one Explosion"],
	[&"cucumber", "Cucumber", "A Curse for a while: inverted controls or slowness"],
]

var _back: Button


## Shows the card on top of `screen`; the focus goes back to `return_focus` when it closes.
static func open_over(screen: Control, return_focus: Control) -> void:
	var card := HowToPlay.new()
	card.closed.connect(return_focus.grab_focus)
	screen.add_child(card)


func _init() -> void:
	color = Color(0.08, 0.1, 0.16, 0.96)
	var column := Ui.centred_column(self)
	column.add_child(Ui.label("How to Play", 72))
	column.add_child(Ui.label("Trap the other Cat in your Explosions. First to win %d Rounds wins the Match." % CONFIG.rounds_to_win,
		Ui.SMALL_SIZE))
	var controls := GridContainer.new()
	controls.columns = CONTROLS[0].size()
	controls.add_theme_constant_override("h_separation", 64)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in CONTROLS:
		for cell: String in row:
			controls.add_child(Ui.label(cell, Ui.SMALL_SIZE))
	column.add_child(controls)
	column.add_child(Ui.label("Esc or Start pauses. F11 toggles fullscreen.", Ui.SMALL_SIZE))
	var powerups := GridContainer.new()
	powerups.columns = 3
	powerups.add_theme_constant_override("h_separation", 32)
	powerups.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for powerup in POWERUPS:
		var scene: PackedScene = load("res://assets/models/%s.glb" % powerup[0])
		powerups.add_child(ModelView.new(scene, Vector2(72, 72), true))
		for text: String in [powerup[1], powerup[2]]:
			var cell := Ui.label(text, Ui.SMALL_SIZE)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			powerups.add_child(cell)
	column.add_child(powerups)
	_back = Ui.button("Back", _close)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Keeps the focus on the card instead of letting it wander to the buttons underneath.
	for side: String in ["left", "top", "right", "bottom"]:
		_back.set("focus_neighbor_" + side, NodePath("."))
	_back.focus_next = NodePath(".")
	_back.focus_previous = NodePath(".")
	column.add_child(_back)


func _ready() -> void:
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
