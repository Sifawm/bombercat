class_name WaitingRoom
extends Control
## The Room between Matches: who is in it, the link that invites to it, and what the Admin
## may do to it. Built again after every change of the Room.

const PROBE := "bridgeProbe"

var _column: VBoxContainer
var _notice := Ui.label("", Ui.SMALL_SIZE)
var _probe_readout := Ui.label("", Ui.SMALL_SIZE)
## Whether a change is waiting to be drawn: several may come in one frame.
var _stale := false
var _probe_listener := 0
## What the bridge probe has seen since the readout last changed.
var _probe_messages := 0
var _probe_worst_gap := 0
var _probe_last_message := 0
var _probe_tick := 0
var _probe_json_usec := 0
var _probe_second := 0.0


func _init() -> void:
	_column = Ui.centred_column(self, 24)


func _ready() -> void:
	var porter := Online.porter
	for changed: Signal in [porter.connection_changed, porter.room_changed, porter.game_changed]:
		changed.connect(func(_part: Variant) -> void: _stale = true)
	_probe_listener = porter.on("moved", _probe_moved)
	_render()


func _exit_tree() -> void:
	Online.porter.off(_probe_listener)


func _process(delta: float) -> void:
	if _stale:
		_render()
	_probe_second += delta
	if _probe_second < 1.0:
		return
	_probe_second = 0.0
	_probe_readout.text = ""
	if _probe_messages > 0:
		_probe_readout.text = "Bridge probe: %d messages/s, worst gap %d ms, JSON %d us each, %d fps, Tick %d" % [
			_probe_messages, _probe_worst_gap, _probe_json_usec / _probe_messages,
			Engine.get_frames_per_second(), _probe_tick,
		]
	_probe_messages = 0
	_probe_json_usec = 0
	_probe_worst_gap = 0


func _probe_moved(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if _probe_messages > 0:
		_probe_worst_gap = maxi(_probe_worst_gap, now - _probe_last_message)
	_probe_last_message = now
	_probe_messages += 1
	_probe_tick = int(snapshot.tick)
	# The addon parsed this message before handing it over, where it cannot be timed. Writing it
	# and parsing it again costs more than that did, so this is a ceiling.
	var before := Time.get_ticks_usec()
	JSON.parse_string(JSON.stringify(snapshot))
	_probe_json_usec += Time.get_ticks_usec() - before


func _render() -> void:
	_stale = false
	var focused := get_viewport().gui_get_focus_owner() as Button
	var focused_text := "" if focused == null else focused.text
	# Kept out of the rebuild: they hold text that outlives a change of the Room.
	for kept: Label in [_notice, _probe_readout]:
		if kept.get_parent() != null:
			_column.remove_child(kept)
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var room: Variant = Online.porter.room
	if room == null:
		return  # on the way out
	var game: Dictionary = Online.porter.game
	var situation: Dictionary = game["match"]
	var playing: bool = situation.status == "running" or situation.status == "paused"

	_column.add_child(Ui.label("Room %s" % room.id, Ui.TITLE_SIZE))
	_column.add_child(_probe_readout)
	if Online.porter.connection.status == "reconnecting":
		_column.add_child(Ui.label("Reconnecting...", 0, Color(1.0, 0.8, 0.3)))
	var users := HBoxContainer.new()
	users.alignment = BoxContainer.ALIGNMENT_CENTER
	users.add_theme_constant_override("separation", 32)
	for user: Dictionary in room.users:
		users.add_child(_user_card(user, room))
	_column.add_child(users)

	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var copy := Ui.button("Copy Invite Link", func() -> void:
		_notice.text = "Link copied" if Online.copy_address() else "Copy this page's address to invite")
	menu.add_child(copy)
	if room.isAdmin:
		menu.add_child(Ui.button("Unlock Room" if room.locked else "Lock Room",
				_send.bind("porter:lockRoom", {"locked": not room.locked})))
		# For measuring the bridge to Godot, not part of the game.
		if game.name != PROBE:
			menu.add_child(Ui.button("Bridge Probe", _send.bind("porter:changeGame", {"game": PROBE})))
		elif playing:
			menu.add_child(Ui.button("Stop Probe", _send.bind("porter:endMatch")))
		else:
			menu.add_child(Ui.button("Start Probe", _send.bind("porter:startMatch")))
			menu.add_child(Ui.button("Close Probe", _send.bind("porter:changeGame", {"game": "bombercat"})))
	elif room.locked:
		menu.add_child(Ui.label("The Room is locked", Ui.SMALL_SIZE))
	menu.add_child(Ui.button("Leave", _leave))
	_column.add_child(menu)
	_column.add_child(_notice)
	# The button that had the focus is gone; the one that took its place gets it back.
	var buttons := _column.find_children("", "Button", true, false)
	var same := buttons.filter(func(button: Button) -> bool: return button.text == focused_text)
	(copy if same.is_empty() else same[0] as Button).grab_focus()


func _user_card(user: Dictionary, room: Dictionary) -> Control:
	var card := VBoxContainer.new()
	var cat := ModelView.new(Roster.cat_scene(int(user.profile.cat)), Vector2(180, 200))
	cat.play("idle")
	cat.modulate.a = 0.4 if user.status == "reconnecting" else 1.0
	card.add_child(cat)
	card.add_child(Ui.label(user.name, 0, Color(1.0, 0.8, 0.3) if user.name == room.you.name else Color.WHITE))
	card.add_child(Ui.label("Admin" if user.name == room.admin else "", Ui.SMALL_SIZE))
	if room.isAdmin and user.name != room.you.name:
		card.add_child(Ui.button("Remove", _send.bind("porter:kickUser", {"name": user.name})))
	return card


func _send(event: String, data: Variant = null) -> void:
	Online.porter.send(event, data)


func _leave() -> void:
	Online.porter.leave()
