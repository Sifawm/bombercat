class_name WaitingRoom
extends Control
## The Room between Matches, where each User chooses its Cat: the five Cats, each with the User
## that brings it, the link that invites to the Room, and what the Admin may do to it. Its parts
## stand where the design's WaitingRoom puts them.

## ponytail: the server's capacity, which Porter does not send; follow server/src/app.module.ts.
const CAPACITY := 4
const REJECTIONS: Dictionary[String, String] = {
	"invalidProfile": "That Cat is taken",
	"belowMinPlayers": "A Match needs at least 2 Users",
	"tooManyUsers": "This Map has no room for so many Users",
	"tooFewUsers": "A Match needs at least 2 Users connected",
}
const TITLE := Vector2(64, 48)
const ACTIONS := Rect2(1112, 57, 744, 88)
const RECONNECTING := Rect2(64, 176, 1792, 80)
const ROSTER := Rect2(64, 154, 1792, 766)
const FOOTER := Rect2(64, 920, 1792, 112)
const LEAVE := Rect2(64, 932, 360, 88)
const MAIN := Rect2(1256, 920, 600, 112)

var _cards: Array[CatCard] = []
var _copy := Ui.button("Copy Invite Link", _copy_link)
var _copied := VBoxContainer.new()
var _lock := Ui.button("", _toggle_lock)
var _locked := Ui.badge("Room locked", true)
var _reconnecting := CenterContainer.new()
var _count := Ui.label("", 32, Ui.INK, Ui.LILITA)
var _footer_notice := CenterContainer.new()
var _start := Ui.button("Start Match", _send.bind("porter:startMatch"), true)
var _waiting := Ui.label("", 32, Ui.INK, Ui.FREDOKA_SEMIBOLD)
## Whether a change is waiting to be drawn: several may come in one frame.
var _stale := false
var _rejection_listener := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var title := Ui.title("Choose your cat")
	title.position = TITLE
	frame.add_child(title)
	frame.add_child(_actions())
	_reconnecting.position = RECONNECTING.position
	_reconnecting.size = RECONNECTING.size
	_reconnecting.add_child(Ui.notice(Ui.Tone.PROGRESS, "Reconnecting..."))
	frame.add_child(_reconnecting)
	var roster := HBoxContainer.new()
	roster.alignment = BoxContainer.ALIGNMENT_CENTER
	roster.add_theme_constant_override("separation", 32)
	for pick in Roster.CATS.size():
		var card := CatCard.new(pick, _choose.bind(pick))
		_cards.append(card)
		roster.add_child(card)
	var centre := CenterContainer.new()
	centre.position = ROSTER.position
	centre.size = ROSTER.size
	centre.add_child(roster)
	frame.add_child(centre)
	_footer(frame)


func _actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = ACTIONS.position
	row.size = ACTIONS.size
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 24)
	# The copy button and, under it, what became of the copy.
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 32)
	_copy.custom_minimum_size = Vector2(360, 88)
	copy.add_child(_copy)
	copy.add_child(_copied)
	row.add_child(copy)
	_lock.custom_minimum_size = Vector2(360, 88)
	_lock.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_lock)
	_locked.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_locked.custom_minimum_size.y = 42
	var badge := MarginContainer.new()  # level with the middle of the copy button
	badge.add_theme_constant_override("margin_top", 23)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.add_child(_locked)
	row.add_child(badge)
	return row


func _footer(frame: Control) -> void:
	var leave := Ui.button("Leave", Online.porter.leave)
	leave.position = LEAVE.position
	leave.custom_minimum_size = LEAVE.size
	frame.add_child(leave)
	_footer_notice.position = FOOTER.position
	_footer_notice.size = FOOTER.size
	_footer_notice.add_child(_count)
	frame.add_child(_footer_notice)
	var main := HBoxContainer.new()
	main.position = MAIN.position
	main.size = MAIN.size
	main.alignment = BoxContainer.ALIGNMENT_END
	_start.custom_minimum_size = MAIN.size
	main.add_child(_start)
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_waiting.size_flags_horizontal = Control.SIZE_SHRINK_END
	main.add_child(_waiting)
	frame.add_child(main)


func _ready() -> void:
	var porter := Online.porter
	for changed: Signal in [porter.connection_changed, porter.room_changed, porter.game_changed]:
		changed.connect(func(_part: Variant) -> void: _stale = true)
	_rejection_listener = porter.on("porter:messageRejected", _rejected)
	_render()
	_first_focus().grab_focus()


func _exit_tree() -> void:
	Online.porter.off(_rejection_listener)


func _process(_delta: float) -> void:
	if _stale:
		_render()


## The first free Cat, or the main button when every Cat is taken.
func _first_focus() -> Control:
	for card in _cards:
		if card.button.focus_mode != Control.FOCUS_NONE:
			return card.button
	return _start if _start.visible else _copy


func _render() -> void:
	_stale = false
	var room: Variant = Online.porter.room
	if room == null:
		return  # on the way out
	var focused := get_viewport().gui_get_focus_owner()
	var kick_focused := "" if focused == null else String(focused.name)  # a tag's kick, drawn anew
	var owners: Dictionary[int, int] = {}  # by Cat, the index of the User that brings it
	for at in room.users.size():
		owners[int(room.users[at].profile.cat)] = at
	for pick in _cards.size():
		var at: int = owners.get(pick, -1)
		_cards[pick].show_owner(null if at == -1 else room.users[at], at, room, _kick)
	OnlineEntry.last_cat = int(room.you.profile.cat)
	_lock.visible = room.isAdmin
	_lock.text = "Unlock Room" if room.locked else "Lock Room"
	_locked.get_parent().visible = not room.isAdmin and room.locked
	_reconnecting.visible = Online.porter.connection.status == "reconnecting"
	_count.text = "%d / %d players" % [room.users.size(), CAPACITY]
	_start.visible = room.isAdmin
	_waiting.visible = not room.isAdmin
	_waiting.text = "Waiting for %s to start the Match..." % room.admin
	# A control that had the focus and can no longer take it hands it on.
	var kick := find_child(kick_focused, true, false) as Control if kick_focused.begins_with("kick") else null
	if kick != null:
		kick.grab_focus()
	elif focused == null or not is_instance_valid(focused) or not focused.is_inside_tree() \
			or not focused.is_visible_in_tree() or focused.focus_mode == Control.FOCUS_NONE:
		_first_focus().grab_focus()


func _choose(pick: int) -> void:
	_send("porter:updateProfile", {"profile": {"cat": pick}})


func _kick(user_name: String) -> void:
	_send("porter:kickUser", {"name": user_name})


func _toggle_lock() -> void:
	_send("porter:lockRoom", {"locked": not Online.porter.room.locked})


func _copy_link() -> void:
	_clear_error()
	for child in _copied.get_children():
		child.queue_free()
	if Online.copy_address():
		_copied.add_child(Ui.notice(Ui.Tone.SUCCESS, "Link copied"))
	else:
		_copied.add_child(Ui.notice(Ui.Tone.INFO, "Copy this page's address to invite"))


## Every action of the User puts away the error it had been told.
func _send(event: String, data: Variant = null) -> void:
	_clear_error()
	Online.porter.send(event, data)


func _rejected(rejection: Dictionary) -> void:
	var reason: Variant = rejection.reason
	var code: String = reason if reason is String else reason.reason
	_clear_error()
	_count.hide()
	_footer_notice.add_child(Ui.notice(Ui.Tone.ERROR, REJECTIONS.get(code, code)))


func _clear_error() -> void:
	for child in _footer_notice.get_children():
		if child != _count:
			child.queue_free()
	_count.show()


## The design's CatCard: one Cat on its sky, free to choose or claimed, in its colour, by the User
## named on the tag above it.
class CatCard:
	extends VBoxContainer

	const SIZE := Vector2(300, 460)
	const TAG_HEIGHT := 62

	## What takes the focus and is pressed to choose this Cat.
	var button := Button.new()
	var _tag := CenterContainer.new()

	func _init(pick: int, on_chosen: Callable) -> void:
		alignment = BoxContainer.ALIGNMENT_END
		add_theme_constant_override("separation", 0)
		_tag.custom_minimum_size.y = TAG_HEIGHT
		add_child(_tag)
		button.custom_minimum_size = SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # however wide its tag
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override("focus", Ui.surface(Ui.CREAM, true, 40))
		button.mouse_entered.connect(func() -> void:
			if button.focus_mode != Control.FOCUS_NONE:
				button.grab_focus())
		button.focus_entered.connect(Ui.bounce.bind(button))
		button.pressed.connect(on_chosen)
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
		var sky := Ui.rounded(Color("a8e2ff"), 28, 0)
		sky.content_margin_bottom = 12
		portrait.add_theme_stylebox_override("panel", sky)
		portrait.custom_minimum_size = Vector2(268, 352)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(portrait)
		var cat := ModelView.new(Roster.cat_scene(pick), Vector2(193, 300), false, true)
		cat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cat.size_flags_vertical = Control.SIZE_SHRINK_END
		cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat.play("idle", float(pick) / Roster.CATS.size())
		portrait.add_child(cat)
		column.add_child(Ui.label(Roster.cat_name(pick), 32, Ui.INK, Ui.LILITA))

	## Free when `user` is null; otherwise claimed by that User, the `at`-th of the Room.
	func show_owner(user: Variant, at: int, room: Dictionary, on_kick: Callable) -> void:
		for child in _tag.get_children():
			_tag.remove_child(child)
			child.queue_free()
		var free := user == null
		var box: StyleBox = Ui.surface(Ui.CREAM, false, 40) if free else Ui.claimed(Ui.CREAM, Roster.PLAYER_COLORS[at])
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			button.add_theme_stylebox_override(state, box)
		button.disabled = not free
		button.focus_mode = Control.FOCUS_ALL if free else Control.FOCUS_NONE
		button.modulate.a = 0.5 if not free and user.status == "reconnecting" else 1.0
		if not free:
			_tag.add_child(_player_tag(user, at, room, on_kick))

	## The design's PlayerTag: the User's name in its colour, with what it is in the Room.
	func _player_tag(user: Dictionary, at: int, room: Dictionary, on_kick: Callable) -> PanelContainer:
		var tag := PanelContainer.new()
		var box := Ui.rounded(Roster.PLAYER_COLORS[at], 28, 0)
		box.set_border_width_all(6)
		box.border_color = Ui.INK
		box.content_margin_left = 24
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		tag.add_theme_stylebox_override("panel", box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		tag.add_child(row)
		row.add_child(Ui.label(user.name, 28, Ui.INK, Ui.LILITA))
		if user.name == room.admin:
			row.add_child(Ui.badge("Admin", true))
		if user.name == room.you.name:
			row.add_child(Ui.badge("You", false))
		elif user.status == "reconnecting":
			row.add_child(Ui.badge("Reconnecting...", false))
		if room.isAdmin and user.name != room.you.name:
			var kick := Ui.round_button("×", 40, on_kick.bind(user.name))
			kick.name = "kick %s" % user.name.validate_node_name()
			kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(kick)
		box.content_margin_right = 12 if row.get_child_count() > 1 else 24
		return tag
