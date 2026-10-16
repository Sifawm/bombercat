class_name SkyBackdrop
extends Control
## The sky behind the design's screens, covering the window, with its clouds drifting right.

## The clouds of the design, in its frame; each drifts right at a twelfth of its width a second.
const CLOUDS: Array[Rect2] = [
	Rect2(120, 120, 352, 132), Rect2(1500, 80, 288, 108), Rect2(1640, 560, 224, 84),
	Rect2(40, 640, 192, 72), Rect2(760, 40, 160, 60),
]

var _clouds: Array[TextureRect] = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := Ui.picture("res://assets/splash/sky.png", Rect2(Vector2.ZERO, Ui.FRAME), self)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	for cloud: Rect2 in CLOUDS:
		var node := Ui.picture("res://assets/splash/cloud.png", cloud, self)
		node.modulate.a = 0.9
		_clouds.append(node)


func _ready() -> void:
	for i in _clouds.size():  # from where they stand in the design, whatever the window
		_clouds[i].position = CLOUDS[i].position + (size - Ui.FRAME) / 2.0


func _process(delta: float) -> void:
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += cloud.size.x / 12.0 * delta
		if cloud.position.x > size.x:
			cloud.position.x = -cloud.size.x
		cloud.position.y = (size.y - Ui.FRAME.y) / 2.0 + CLOUDS[i].position.y
