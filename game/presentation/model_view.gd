class_name ModelView
extends SubViewportContainer
## A 3D model shown inside the UI, framed to fit: Cat portraits, the Cats of Cat Select,
## the Powerups of How to Play.

const SPIN_SPEED := 1.5

var _model: Node3D
var _camera := Camera3D.new()
var _spin: bool


func _init(scene: PackedScene, pixels: Vector2, spin: bool = false) -> void:
	_spin = spin
	stretch = true
	custom_minimum_size = pixels
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	viewport.add_child(light)
	_camera.fov = 30.0
	_camera.environment = Environment.new()
	_camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_camera.environment.ambient_light_color = Color.WHITE
	_camera.environment.ambient_light_energy = 0.5
	viewport.add_child(_camera)
	_model = scene.instantiate()
	viewport.add_child(_model)


func _ready() -> void:
	var bounds := AABB()
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var distance := bounds.size.length() / 2.0 / sin(deg_to_rad(_camera.fov / 2.0))
	_camera.position = bounds.get_center() + Vector3(0.0, 0.3, 1.0).normalized() * distance
	_camera.look_at(bounds.get_center())
	set_process(_spin)


func _process(delta: float) -> void:
	_model.rotate_y(SPIN_SPEED * delta)


## Loops one of the model's animations.
func play(animation: String) -> void:
	var animations: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	animations.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	animations.play(animation)
