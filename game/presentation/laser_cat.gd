class_name LaserCat
extends Control
## A Cat in the menus that hunts the Laser Pointer's dot (docs/laser-pointer.md): it watches the
## dot, hops at it with a paw stretched out when it is near, stalks it when it rests or is below
## its feet, pounces when it moves again and bites at it when it is on it. It stays in its place;
## its view reaches beyond it so its turns and leaps are not cut off.

## Room around the Cat, as a share of its size: on each side for its turns, and above it for its
## highest leap (`pounce` lifts it 0.3 of a model about 1.4 tall).
## ponytail: shares tuned by eye, measure the model's framing if the Cats change shape.
const ROOM := Vector2(0.3, 0.22)
## How long one animation blends into the next.
const BLEND := 0.3
## How quickly the body and head turn towards the dot, and the head snaps round after a miss.
const TURN_RATE := 10.0
const SNAP_RATE := 30.0
## How far back, in degrees, and for how long the ear flicks after a miss.
const EAR_FLICK := 25.0
const FLICK_TIME := 0.3
const LOOPS: Array[StringName] = [&"idle", &"hop_l", &"hop_r", &"stalk"]

var _dot: LaserDot
var _view: ModelView
var _animations: AnimationPlayer
var _chase := LaserChase.new()
var _gaze := Gaze.new()
## How far through its idle loop the Cat stands whenever it rests, out of step with the others.
var _phase: float
## How long since the Cat last missed.
var _since_miss := FLICK_TIME


func _init(scene: PackedScene, pixels: Vector2, dot: LaserDot, phase: float) -> void:
	_dot = dot
	_phase = phase
	custom_minimum_size = pixels
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room := pixels * ROOM
	_view = ModelView.new(scene, pixels, true, room)
	_view.position = -room
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.play("idle", phase)
	add_child(_view)
	_animations = _view.find_children("*", "AnimationPlayer", true, false)[0]
	for looping in LOOPS:
		_animations.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	_animations.animation_finished.connect(func(_clip: StringName) -> void: _chase.finish(_dot))
	var skeleton: Skeleton3D = _view.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.add_child(_gaze)


func _process(delta: float) -> void:
	var was := _chase.act
	_chase.follow(get_global_rect(), _dot, delta)
	var missed := _chase.act == LaserChase.Act.MISS
	if missed and was != LaserChase.Act.MISS:
		_since_miss = 0.0
	_since_miss += delta
	_gaze.ear = sin(PI * minf(_since_miss / FLICK_TIME, 1.0))
	var weight := 1.0 - exp(-(SNAP_RATE if missed else TURN_RATE) * delta)
	_gaze.body_yaw = lerpf(_gaze.body_yaw, _chase.body_yaw, weight)
	_gaze.head_yaw = lerpf(_gaze.head_yaw, _chase.head_yaw, weight)
	_gaze.head_pitch = lerpf(_gaze.head_pitch, _chase.head_pitch, weight)
	var clip := _clip()
	if clip != _animations.current_animation:  # a one-shot that ended has none, and may play again
		_animations.play(clip, BLEND)
		if clip == &"idle":
			_animations.seek(_animations.current_animation_length * _phase)


func _clip() -> StringName:
	match _chase.act:
		LaserChase.Act.HOP:
			return &"hop_l" if _chase.paw == &"L" else &"hop_r"
		LaserChase.Act.STALK:
			return &"stalk"
		LaserChase.Act.POUNCE:
			return &"pounce"
		LaserChase.Act.PIN:
			return &"pin"
		LaserChase.Act.BITE:
			return &"bite"
	return &"idle"  # resting, watching, or standing where it missed


## Turns the Cat's body and head towards the dot over whatever animation plays, and flicks an ear.
class Gaze extends SkeletonModifier3D:
	## Degrees towards the screen's right (yaw) and up (pitch), as LaserChase gives them.
	var body_yaw := 0.0
	var head_yaw := 0.0
	var head_pitch := 0.0
	## How far the left ear is flicked back, from 0 to 1.
	var ear := 0.0

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		var flicked := skeleton.find_bone("Ear.L")
		var pose := skeleton.get_bone_pose(flicked)
		pose.basis = pose.basis * Basis(Vector3.RIGHT, deg_to_rad(-EAR_FLICK * ear))  # bone-local X, as in Blender
		skeleton.set_bone_pose(flicked, pose)
		var body := skeleton.find_bone("Body")
		var turned := skeleton.get_bone_global_pose(body)
		turned.basis = Basis(Vector3.UP, deg_to_rad(body_yaw)) * turned.basis
		skeleton.set_bone_global_pose(body, turned)
		var head := skeleton.find_bone("Head")
		turned = skeleton.get_bone_global_pose(head)
		var facing := Basis(Vector3.UP, deg_to_rad(body_yaw + head_yaw))
		turned.basis = Basis(facing * Vector3.RIGHT, deg_to_rad(-head_pitch)) * Basis(Vector3.UP, deg_to_rad(head_yaw)) * turned.basis
		skeleton.set_bone_global_pose(head, turned)
