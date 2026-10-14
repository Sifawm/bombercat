class_name OnlineEntry
extends Control
## The way into a Room: a name, a Cat, and either a new Room or the one the page's address
## invites to.

signal back_pressed

const REFUSALS: Dictionary[String, String] = {
	"invalidName": "That name will not do",
	"nameTaken": "Someone in the Room already has that name",
	"roomFull": "The Room is full",
	"roomLocked": "The Room is locked",
	"roomNotFound": "That Room no longer exists",
	"failed": "The server could not create a Room",
}

## Kept for the next time this screen is shown.
static var _last_name := ""
static var _last_cat := 0

var _room_id := Online.room_in_address()
var _cat := _last_cat
var _name_field := LineEdit.new()
var _cat_views: Array[ModelView] = []
var _cat_name := Ui.label("")
var _enter: Button
var _retry: Button
var _status := Ui.label("", Ui.SMALL_SIZE)


func _init() -> void:
	var column := Ui.centred_column(self, 32)
	column.add_child(Ui.label("Play Online", Ui.TITLE_SIZE))
	_name_field.placeholder_text = "Your name"
	_name_field.text = _last_name
	_name_field.max_length = 20
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_field.text_submitted.connect(_login.unbind(1))
	column.add_child(_name_field)
	var chooser := HBoxContainer.new()
	chooser.alignment = BoxContainer.ALIGNMENT_CENTER
	chooser.add_child(Ui.button("<", _choose.bind(-1)))
	for pick in Roster.CATS.size():
		var view := ModelView.new(Roster.cat_scene(pick), Vector2(260, 320))
		view.play("idle")
		_cat_views.append(view)
		chooser.add_child(view)
	chooser.add_child(Ui.button(">", _choose.bind(1)))
	column.add_child(chooser)
	column.add_child(_cat_name)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter = Ui.button("", _login)
	menu.add_child(_enter)
	_retry = Ui.button("Try Again", Online.porter.reconnect)
	menu.add_child(_retry)
	menu.add_child(Ui.button("Back", back_pressed.emit))
	column.add_child(menu)
	column.add_child(_status)
	_choose(0)
	_refresh()


func _ready() -> void:
	_name_field.grab_focus()
	Online.porter.connection_changed.connect(_on_connection_changed)
	_on_connection_changed(Online.porter.connection)


## Says why the User is here when it did not choose to be: a Token that no longer opens its
## Room, a Room it was removed from, a server that does not answer.
func _on_connection_changed(connection: Dictionary) -> void:
	_retry.visible = Online.unreachable()
	if connection.status == "closed":
		_status.text = Online.CLOSED.get(connection.reason, "")
	elif connection.status != "idle":
		_status.text = "Connecting..."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Audio.play(&"ui_cancel")
		back_pressed.emit()


func _choose(step: int) -> void:
	_cat = posmod(_cat + step, Roster.CATS.size())
	for pick in _cat_views.size():
		_cat_views[pick].visible = pick == _cat
	_cat_name.text = Roster.cat_name(_cat)


func _refresh() -> void:
	_enter.text = "Create Room" if _room_id == "" else "Join Room"


func _login() -> void:
	var user_name := _name_field.text.strip_edges()
	if user_name == "" or _enter.disabled:
		return
	_last_name = user_name
	_last_cat = _cat
	_enter.disabled = true
	var request := {"name": user_name, "profile": {"cat": _cat}}
	if _room_id != "":
		request.roomId = _room_id
	var result: Variant = await Online.porter.login(request)
	_enter.disabled = false
	if result == null:
		_status.text = "The server did not answer"
	elif not result.ok:
		_status.text = REFUSALS.get(result.reason, result.reason)
		if result.reason == "roomNotFound":
			# Nothing to join any more: the same screen now creates a Room.
			_room_id = ""
			Online.set_room_in_address("")
			_refresh()
