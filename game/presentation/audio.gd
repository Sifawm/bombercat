extends Node
## The game's sound, available everywhere as `Audio`: effects by name on the Effects bus, one
## music loop at a time on the Music bus, and the sounds of every menu.

const FOLDER := "res://assets/audio/"

var _music := AudioStreamPlayer.new()
var _music_name := &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus also sound while the game is paused
	_music.bus = &"Music"
	add_child(_music)


## Moving through a menu sounds here, for every menu at once; confirming and cancelling
## sound where they happen.
func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() == null:
		return
	for direction: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(direction):
			play(&"ui_move")


func has(sound: StringName) -> bool:
	return ResourceLoader.exists(FOLDER + sound + ".wav")


## Plays the effect in assets/audio named `sound`.
func play(sound: StringName, pitch: float = 1.0) -> void:
	var voice := AudioStreamPlayer.new()
	voice.stream = load(FOLDER + sound + ".wav")
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
	var stream: AudioStreamWAV = load(FOLDER + music + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music.stream = stream
	_music.play()
