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
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: play(&"ui_move"))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		play(&"ui_cancel")


## Plays the effect in assets/audio named `sound`.
func play(sound: StringName, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load(FOLDER + sound + ".wav")
	player.bus = &"Effects"
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


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
