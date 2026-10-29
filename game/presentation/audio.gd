extends Node
## The game's sound, available everywhere as `Audio`: effects by name on the Effects bus, one
## music loop at a time on the Music bus, and the sounds of every menu.

const FOLDER := "res://assets/audio/"

var _music := AudioStreamPlayer.new()
var _music_name := &""
## Every effect, read once: a stream let go when its last voice ends is read again next time.
var _effects: Dictionary[StringName, AudioStream] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus also sound while the game is paused
	_music.bus = &"Music"
	add_child(_music)
	for file in ResourceLoader.list_directory(FOLDER):
		if file.ends_with(".ogg") and not file.begins_with("music_"):
			_effects[StringName(file.get_basename())] = load(FOLDER + file)


## Moving through a menu sounds here, for every menu at once; confirming and cancelling
## sound where they happen.
func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() == null:
		return
	for direction: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(direction):
			play(&"ui_move")


func has(sound: StringName) -> bool:
	return _effects.has(sound)


## Plays the effect in assets/audio named `sound`.
func play(sound: StringName, pitch: float = 1.0) -> void:
	var voice := AudioStreamPlayer.new()
	voice.stream = _effects[sound]
	voice.bus = &"Effects"
	voice.pitch_scale = pitch
	voice.finished.connect(voice.queue_free)
	add_child(voice)
	voice.play()


## Loops the music named `music` at `speed`; asking for the one already playing only
## changes its speed.
func play_music(music: StringName, speed: float = 1.0) -> void:
	_music.pitch_scale = speed
	if music == _music_name:
		return
	_music_name = music
	var stream: AudioStreamOggVorbis = load(FOLDER + music + ".ogg")
	stream.loop = true
	_music.stream = stream
	_music.play()
