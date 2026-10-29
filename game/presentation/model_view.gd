class_name ModelView
extends SubViewportContainer
## A 3D model shown inside the UI, framed to fit: Cat portraits, the Cats of Cat Select,
## the Powerups of How to Play.

const SPIN_SPEED := 1.5
## Room left around a grounded model, so its animations and its outline stay inside the view.
const MARGIN := 1.12

var _model: Node3D
var _camera := Camera3D.new()
var _spin: bool
var _grounded: bool
## How high the animation it plays lifts the model, left free above it.
var _lift := 0.0


## A `grounded` model fills the view, framed by its front, and stands on its bottom edge.
func _init(scene: PackedScene, pixels: Vector2, spin: bool = false, grounded: bool = false) -> void:
	_spin = spin
	_grounded = grounded
	stretch = true
	custom_minimum_size = pixels
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 60.0, 0.0)  # from the side, so the cartoon shade shows
	light.light_energy = 0.4
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
	bounds.size.y += _lift
	var distance := bounds.size.length() / 2.0 / sin(deg_to_rad(_camera.fov / 2.0))
	if _grounded:  # framed by its front, as a tail behind it doesn't widen it
		bounds.position.z = bounds.end.z - bounds.size.x
		bounds.size.z = bounds.size.x
		var fit := maxf(bounds.size.y, bounds.size.x * custom_minimum_size.y / custom_minimum_size.x) * MARGIN
		distance = fit / 2.0 / tan(deg_to_rad(_camera.fov / 2.0)) + bounds.size.z / 4.0
	_camera.position = bounds.get_center() + Vector3(0.0, 0.3, 1.0).normalized() * distance
	_camera.look_at(bounds.get_center())
	if _grounded:  # about the front of its paws on the bottom edge
		var feet := _camera.global_transform.affine_inverse() \
				* (bounds.get_center() + Vector3(0.0, -bounds.size.y, bounds.size.z / 2.0) / 2.0)
		_camera.v_offset = feet.y - feet.z * tan(deg_to_rad(_camera.fov / 2.0))
	set_process(_spin)


func _process(delta: float) -> void:
	_model.rotate_y(SPIN_SPEED * delta)


## Loops one of the model's animations, starting `phase` (0 to 1) of the way through it. Called
## before the view enters the tree, it is framed with room for the animation's jumps.
func play(animation: String, phase: float = 0.0) -> void:
	var animations: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	var clip := animations.get_animation(animation)
	clip.loop_mode = Animation.LOOP_LINEAR
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var heights: Array[float] = []
			for key in clip.track_get_key_count(track):
				heights.append((clip.track_get_key_value(track, key) as Vector3).y)
			_lift = maxf(_lift, heights.max() - heights.min())
	animations.play(animation)
	animations.seek(animations.current_animation_length * phase, true)
