class_name Online
## Porter's client and the page around it. Both exist only in the web build, inside the page
## that starts the engine (ADR 0005).

const Client := preload("res://addons/porter/porter.gd")

## What to tell a User whose connection closed without its asking.
const CLOSED: Dictionary[String, String] = {
	"kicked": "The Admin removed you from the Room",
	"replaced": "You opened this Room in another tab",
	"unreachable": "The server cannot be reached",
	"notInRoom": "You were away from the Room for too long",
	"invalidToken": "That Room no longer exists",
	"roomNotFound": "That Room no longer exists",
}

## Null wherever there is no online play.
static var porter: Client


## Looks for the page's Porter client. The addon is not an autoload because it logs an error
## wherever there is no page, and the native builds and the tests have none.
static func start(parent: Node) -> void:
	if not OS.has_feature("web") or JavaScriptBridge.get_interface("porterGodot") == null:
		return
	porter = Client.new()
	parent.add_child(porter)


## The Room the page's address invites to, or "".
static func room_in_address() -> String:
	return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('room') || ''"))


## Makes the page's address the link to a Room, or to no Room with "".
static func set_room_in_address(room_id: String) -> void:
	var query := "" if room_id == "" else "?room=" + room_id.uri_encode()
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + '%s')" % query)


## Whether the page let it be copied: a browser refuses on an address that is not secure.
static func copy_address() -> bool:
	return JavaScriptBridge.eval("!!navigator.clipboard && (navigator.clipboard.writeText(location.href), true)")


## Whether the connection closed for want of a server, with the User still in its Room.
static func unreachable() -> bool:
	return porter.connection.status == "closed" and porter.connection.reason == "unreachable"
