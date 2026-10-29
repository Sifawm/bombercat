class_name OnlineEntry
extends Control
## The way into a Room: a name, and either a new Room or the one the page's address invites to.
## The Cat is chosen inside the Room. Its parts stand where the design's OnlineEntry puts them.

signal back_pressed

const REFUSALS: Dictionary[String, String] = {
	"invalidName": "That name will not do",
	"nameTaken": "Someone in the Room already has that name",
	"roomFull": "The Room is full",
	"roomLocked": "The Room is locked",
	"roomNotFound": "That Room no longer exists",
	"failed": "The server could not create a Room",
}
## The refusals that are about the name, told under the field.
const NAME_REFUSALS: Array[String] = ["invalidName", "nameTaken"]
const BACK := Rect2(64, 48, 360, 88)
## Where the panel is centred.
const MAIN := Rect2(64, 136, 1792, 896)
## Where the bomb and the Cat stand, from the panel's top left and bottom right corners.
const BOMB := Rect2(-70, -90, 126, 200)
const CAT := Rect2(-120, -236, 169, 260)

## Kept for the next time this screen is shown.
static var _last_name := ""
## The Cat proposed on entering a Room; the first Cat until the User has had one.
static var last_cat := 0

var _room_id := Online.room_in_address()
var _panel := Ui.panel()
var _bomb: TextureRect
var _cat := ModelView.new(Roster.cat_scene(last_cat), CAT.size, true)
var _subtitle := Ui.label("You've been invited to a Room", 32, Ui.INK, Ui.FREDOKA_MEDIUM)
var _name_field := Ui.text_field(Vector2(640, 104))
## Where a Notice goes: under the field, under it and over the button, or under the button.
var _field_slot := VBoxContainer.new()
var _middle_slot := VBoxContainer.new()
var _bottom_slot := VBoxContainer.new()
var _hint := Ui.label("You'll pick your cat in the Room", 28, Ui.INK, Ui.FREDOKA_MEDIUM)
var _enter: Button
var _retry: Button
var _logging_in := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SkyBackdrop.new())
	var frame := Ui.frame(self)
	var back := Ui.button("Back", back_pressed.emit)
	back.position = BACK.position
	back.custom_minimum_size = BACK.size
	frame.add_child(back)
	var centre := CenterContainer.new()
	centre.position = MAIN.position
	centre.size = MAIN.size
	frame.add_child(centre)
	centre.add_child(_panel)
	_panel.add_child(_content())
	_bomb = Ui.picture("res://assets/splash/bomb.png", BOMB, frame)
	_bomb.rotation_degrees = -14.0
	_cat.play("idle")
	frame.add_child(_cat)
	_panel.item_rect_changed.connect(_place_decor.bind(centre))
	_refresh()


func _content() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 40)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.add_child(Ui.label("Play Online", 88, Ui.INK, Ui.LILITA))
	heading.add_child(_subtitle)
	column.add_child(heading)
	var name_group := VBoxContainer.new()
	name_group.add_theme_constant_override("separation", 12)
	var name_label := Ui.label("Your name", 28, Ui.INK, Ui.FREDOKA_SEMIBOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_group.add_child(name_label)
	_name_field.placeholder_text = "Your name"
	_name_field.text = _last_name
	_name_field.max_length = 20
	_name_field.keep_editing_on_text_submit = true  # a name refused is mended at once
	_name_field.text_submitted.connect(_login.unbind(1))
	_name_field.text_changed.connect(_clear_refusal.unbind(1))
	name_group.add_child(_name_field)
	name_group.add_child(_field_slot)
	column.add_child(name_group)
	column.add_child(_middle_slot)
	_enter = Ui.button("", _login, true)
	_enter.custom_minimum_size = Vector2(520, 112)
	_enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_enter)
	_retry = Ui.button("Try Again", _try_again)
	_retry.custom_minimum_size = Vector2(360, 88)
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_retry)
	column.add_child(_bottom_slot)
	column.add_child(_hint)
	return column


func _ready() -> void:
	_name_field.grab_focus()
	_name_field.caret_column = _name_field.text.length()
	Online.porter.connection_changed.connect(_on_connection_changed)
	_on_connection_changed(Online.porter.connection)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Audio.play(&"ui_cancel")
		back_pressed.emit()


## The bomb peeks over the panel's top left corner and the Cat stands at its bottom right.
func _place_decor(centre: CenterContainer) -> void:
	var top_left := centre.position + _panel.position
	_bomb.position = top_left + BOMB.position
	_cat.position = top_left + Vector2(_panel.size.x, _panel.size.y) + CAT.position


## Says why the User is here when it did not choose to be: a Token that no longer opens its
## Room, a Room it was removed from, a server that does not answer.
func _on_connection_changed(connection: Dictionary) -> void:
	_retry.visible = Online.unreachable()
	if connection.status == "closed":
		var reason: String = connection.reason
		if Online.CLOSED.has(reason):
			_tell(Ui.Tone.INFO if reason == "replaced" else Ui.Tone.ERROR, Online.CLOSED[reason], _middle_slot)
		else:
			_tell_nothing()
	elif connection.status != "idle":
		_tell(Ui.Tone.PROGRESS, "Connecting...", _bottom_slot)
	elif not _logging_in:
		_tell_nothing()
	_refresh()


func _refresh() -> void:
	_subtitle.visible = _room_id != ""
	_enter.text = "Create Room" if _room_id == "" else "Join Room"
	var busy: bool = _logging_in or Online.porter.connection.status not in ["idle", "closed"]
	_enter.disabled = busy


## Shows one Notice in one slot, in place of whatever was told before.
func _tell(tone: Ui.Tone, message: String, slot: VBoxContainer) -> void:
	_tell_nothing()
	slot.add_child(Ui.notice(tone, message))
	slot.show()
	Ui.mark_field(_name_field, slot == _field_slot)
	_hint.visible = slot == _field_slot


func _tell_nothing() -> void:
	for slot: VBoxContainer in [_field_slot, _middle_slot, _bottom_slot]:
		for child: Node in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
		slot.hide()
	Ui.mark_field(_name_field, false)
	_hint.show()


## A refusal is told until the User does something about it.
func _clear_refusal() -> void:
	if not (_bottom_slot.visible or _logging_in):
		_tell_nothing()


func _try_again() -> void:
	_tell_nothing()
	Online.porter.reconnect()


func _login() -> void:
	var user_name := _name_field.text.strip_edges()
	if user_name == "" or _enter.disabled:
		return
	_last_name = user_name
	_logging_in = true
	_tell(Ui.Tone.PROGRESS, "Connecting...", _bottom_slot)
	_refresh()
	var request := {"name": user_name, "profile": {"cat": last_cat}}
	if _room_id != "":
		request.roomId = _room_id
	var result: Variant = await Online.porter.login(request)
	_logging_in = false
	if result == null:
		_tell(Ui.Tone.ERROR, "The server did not answer", _middle_slot)
	elif not result.ok:
		var reason: String = result.reason
		_tell(Ui.Tone.ERROR, REFUSALS.get(reason, reason),
				_field_slot if reason in NAME_REFUSALS else _middle_slot)
		if reason == "roomNotFound":
			# Nothing to join any more: the same screen now creates a Room.
			_room_id = ""
			Online.set_room_in_address("")
	_refresh()
