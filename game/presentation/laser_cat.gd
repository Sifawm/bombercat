class_name LaserCat
extends Control
## A Cat in the menus that hunts the Laser Pointer's dot (docs/laser-pointer.md): it watches the
## dot, hops and swats at it when it is near and bites at it when it is on it. It stays in its
## place; its view reaches beyond it so its turns and hops are not cut off.

## Room around the Cat, as a share of its size: on each side for its turns, and above it for its
## highest hop (`pounce` lifts it 0.3 of a model about 1.4 tall).
## ponytail: shares tuned by eye, measure the model's framing if the Cats change shape.
const ROOM := Vector2(0.3, 0.22)
## How long one animation blends into the next.
const BLEND := 0.3
## How quickly the body and head turn towards the dot.
const TURN_RATE := 10.0

var _dot: LaserDot
var _view: ModelView
var _animations: AnimationPlayer
var _gaze := Gaze.new()
## How far through its idle loop the Cat stands whenever it rests, out of step with the others.
var _phase: float
## The swat comes after the hop, then the hop again.
var _swat_next := false


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
	_animations.animation_finished.connect(_on_finished.unbind(1))
	var skeleton: Skeleton3D = _view.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.add_child(_gaze)


func _process(delta: float) -> void:
	var chase := LaserChase.new(get_global_rect().get_center(), _dot)
	var weight := 1.0 - exp(-TURN_RATE * delta)
	_gaze.body_yaw = lerpf(_gaze.body_yaw, chase.body_yaw, weight)
	_gaze.head_yaw = lerpf(_gaze.head_yaw, chase.head_yaw, weight)
	_gaze.head_pitch = lerpf(_gaze.head_pitch, chase.head_pitch, weight)
	if _animations.current_animation != "idle" and _animations.is_playing():
		return  # a hop, a swat or a bite plays to its end
	if chase.band == LaserChase.Band.BITE:
		_animations.play("bite", BLEND)
	elif chase.hop > 0.0 and _swat_next:
		_animations.play("swat_" + chase.paw.to_lower(), BLEND)
		_swat_next = false
	elif chase.hop > 0.0:
		_gaze.lift = chase.hop
		_animations.play("pounce", BLEND)
		_swat_next = true
	elif _animations.current_animation != "idle":
		_rest()


func _on_finished() -> void:
	_rest()


## Back to idle, at the Cat's own place in the loop.
func _rest() -> void:
	_animations.play("idle", BLEND)
	_animations.seek(_animations.current_animation_length * _phase)


## Turns the Cat's body and head towards the dot over whatever animation plays, and scales how
## high it lifts.
class Gaze extends SkeletonModifier3D:
	## Degrees towards the screen's right (yaw) and up (pitch), as LaserChase gives them.
	var body_yaw := 0.0
	var head_yaw := 0.0
	var head_pitch := 0.0
	## The share of the animation's lift kept, for hops lower than `pounce`'s full height.
	var lift := 1.0

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		var root := skeleton.find_bone("Root")
		var pose := skeleton.get_bone_pose(root)
		pose.origin.y *= lift
		skeleton.set_bone_pose(root, pose)
		var body := skeleton.find_bone("Body")
		var turned := skeleton.get_bone_global_pose(body)
		turned.basis = Basis(Vector3.UP, deg_to_rad(body_yaw)) * turned.basis
		skeleton.set_bone_global_pose(body, turned)
		var head := skeleton.find_bone("Head")
		turned = skeleton.get_bone_global_pose(head)
		var facing := Basis(Vector3.UP, deg_to_rad(body_yaw + head_yaw))
		turned.basis = Basis(facing * Vector3.RIGHT, deg_to_rad(-head_pitch)) * Basis(Vector3.UP, deg_to_rad(head_yaw)) * turned.basis
		skeleton.set_bone_global_pose(head, turned)
