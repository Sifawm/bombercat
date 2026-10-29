class_name ModelView
extends SubViewportContainer
## A 3D model shown inside the UI, framed to fit: the Cats of the title screen, Cat Select and
## the Match Result, and the still pictures of tools/render_pictures.tscn.

## Where the camera looks from: in front of the model and a little above it.
const VIEW := Vector3(0.0, 0.3, 1.0)
## Room left around the model, so its animations and its outline stay inside the view.
const MARGIN := 1.12

var _model: Node3D
var _camera := Camera3D.new()
var _grounded: bool
## The size it is framed at; `_room` more pixels are left free on each side (x) and above it (y).
var _pixels: Vector2
var _room: Vector2
## How high the animation it plays lifts the model, left free above it.
var _lift := 0.0


## A `grounded` model fills the view, framed by its front, and stands on its bottom edge; any
## other is seen whole, in the middle of the view. `room` pixels around `pixels`, at the same
## scale, on each side (x) and on top (y), leave room for a model that turns or leaps out of its
## frame: the view grows by them, and whoever places it moves it back by them.
func _init(scene: PackedScene, pixels: Vector2, grounded: bool = false, room: Vector2 = Vector2.ZERO) -> void:
	_grounded = grounded
	_pixels = pixels
	_room = room
	stretch = true
	custom_minimum_size = pixels + Vector2(2.0 * room.x, room.y)
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
	if _grounded:
		_frame_grounded(bounds)
	else:
		_frame_whole()
	if _room.y > 0.0:  # the sides need nothing: the view keeps its height, so a wider one sees further
		_raise_ceiling(bounds.get_center())


## Framed by its front, as a tail behind it doesn't widen it, with the front of its paws on the
## bottom edge.
func _frame_grounded(bounds: AABB) -> void:
	bounds.position.z = bounds.end.z - bounds.size.x
	bounds.size.z = bounds.size.x
	var fit := maxf(bounds.size.y, bounds.size.x * _pixels.y / _pixels.x) * MARGIN
	var distance := fit / 2.0 / tan(deg_to_rad(_camera.fov / 2.0)) + bounds.size.z / 4.0
	_camera.position = bounds.get_center() + VIEW.normalized() * distance
	_camera.look_at(bounds.get_center())
	var feet := _camera.global_transform.affine_inverse() \
			* (bounds.get_center() + Vector3(0.0, -bounds.size.y, bounds.size.z / 2.0) / 2.0)
	_camera.v_offset = feet.y - feet.z * tan(deg_to_rad(_camera.fov / 2.0))


## Every vertex of the model inside the view, the model in its middle: fitted to its outline
## rather than to its box, which a round model fills only in part.
func _frame_whole() -> void:
	var basis := Basis.looking_at(-VIEW)
	var points: Array[Vector3] = []  # as the camera's axes see them
	var lowest := Vector2(INF, INF)
	var highest := -lowest
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var seen := basis.inverse() * (mesh.global_transform * vertex)
				points.append(seen)
				lowest = lowest.min(Vector2(seen.x, seen.y))
				highest = highest.max(Vector2(seen.x, seen.y))
	var middle := (lowest + highest) / 2.0
	var tan_up := tan(deg_to_rad(_camera.fov / 2.0))
	var tan_across := tan_up * _pixels.x / _pixels.y
	var distance := 0.0
	for seen in points:  # a point nearer the camera needs it further back
		distance = maxf(distance, maxf(absf(seen.x - middle.x) / tan_across, absf(seen.y - middle.y) / tan_up) + seen.z)
	_camera.transform = Transform3D(basis, basis * Vector3(middle.x, middle.y, distance * MARGIN))


## Makes the view taller by the room at its top, the model keeping its size and its place at the bottom.
func _raise_ceiling(target: Vector3) -> void:
	var tan_up := tan(deg_to_rad(_camera.fov / 2.0))
	var per_pixel := 2.0 * _camera.position.distance_to(target) * tan_up / _pixels.y
	_camera.fov = rad_to_deg(2.0 * atan(tan_up * (_pixels.y + _room.y) / _pixels.y))
	_camera.v_offset += _room.y / 2.0 * per_pixel


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
