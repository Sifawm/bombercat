class_name WaitingRoom
extends Control
## The Room between Matches: who is in it, the link that invites to it, and what the Admin
## may do to it. Built again after every change of the Room.

const REJECTIONS: Dictionary[String, String] = {
	"belowMinPlayers": "A Match needs at least 2 Users",
	"tooManyUsers": "This Map has no room for so many Users",
}

var _column: VBoxContainer
var _notice := Ui.label("", Ui.SMALL_SIZE)
## Whether a change is waiting to be drawn: several may come in one frame.
var _stale := false
var _rejection_listener := 0


func _init() -> void:
	_column = Ui.centred_column(self, 24)


func _ready() -> void:
	var porter := Online.porter
	for changed: Signal in [porter.connection_changed, porter.room_changed, porter.game_changed]:
		changed.connect(func(_part: Variant) -> void: _stale = true)
	_rejection_listener = porter.on("porter:messageRejected", _rejected)
	_render()


func _exit_tree() -> void:
	Online.porter.off(_rejection_listener)


func _process(_delta: float) -> void:
	if _stale:
		_render()


func _rejected(rejection: Dictionary) -> void:
	var reason: Variant = rejection.reason
	var code: String = reason if reason is String else reason.reason
	_notice.text = REJECTIONS.get(code, code)


func _render() -> void:
	_stale = false
	var focused := get_viewport().gui_get_focus_owner() as Button
	var focused_text := "" if focused == null else focused.text
	# Kept out of the rebuild: it holds text that outlives a change of the Room.
	if _notice.get_parent() != null:
		_column.remove_child(_notice)
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var room: Variant = Online.porter.room
	if room == null:
		return  # on the way out
	_column.add_child(Ui.label("Room %s" % room.id, Ui.TITLE_SIZE))
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
	if room.isAdmin:
		menu.add_child(Ui.button("Start Match", Online.porter.send.bind("porter:startMatch")))
	var copy := Ui.button("Copy Invite Link", func() -> void:
		_notice.text = "Link copied" if Online.copy_address() else "Copy this page's address to invite")
	menu.add_child(copy)
	if room.isAdmin:
		menu.add_child(Ui.button("Unlock Room" if room.locked else "Lock Room",
				_send.bind("porter:lockRoom", {"locked": not room.locked})))
	elif room.locked:
		menu.add_child(Ui.label("The Room is locked", Ui.SMALL_SIZE))
	menu.add_child(Ui.button("Leave", _leave))
	_column.add_child(menu)
	_column.add_child(_notice)
	# The button that had the focus is gone; the one that took its place gets it back.
	var buttons := _column.find_children("", "Button", true, false)
	var same := buttons.filter(func(button: Button) -> bool: return button.text == focused_text)
	((menu.get_child(0) as Button) if same.is_empty() else same[0] as Button).grab_focus()


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
