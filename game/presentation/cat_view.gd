class_name CatView
extends Node3D
## One Cat in a Round: its model and everything that shows the state the rules give it.

## The Cat models are about 1.2 m tall; this fits them to a 1 m Tile.
const CAT_SCALE := 0.72
const DROP_HEIGHT := 9.0
const DROP_SECONDS := 0.7
const BLINKS_PER_SECOND := 8.0
const MEOW_SECONDS := 0.9

static var _spiral_image: Texture2D

var _model: Node3D
var _animations: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _aura := Effects.glow(Color(1.0, 0.85, 0.3, 0.25), 0.62)
var _curse_tint := Effects.flat_material(Color(0.2, 0.9, 0.2, 0.4))
var _spiral := MeshInstance3D.new()
var _trail := Effects.cubes(Color(0.5, 1.0, 0.4), 14, 0.35, 0.12)
var _bubble := Label3D.new()
var _bubble_timer: Tween


func _init(scene: PackedScene) -> void:
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * CAT_SCALE
	add_child(_model)
	_animations = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for looping: String in ["idle", "walk", "win"]:
		_animations.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	_animations.play("idle")
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)

	_aura.position.y = 0.45
	add_child(_aura)

	var spiral_mesh := QuadMesh.new()
	spiral_mesh.size = Vector2(0.7, 0.7)
	spiral_mesh.orientation = PlaneMesh.FACE_Y
	var spiral_material := Effects.flat_material(Color(0.6, 1.0, 0.3, 0.99))
	spiral_material.albedo_texture = _spiral_texture()
	spiral_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	spiral_mesh.material = spiral_material
	_spiral.mesh = spiral_mesh
	_spiral.position.y = 1.05
	add_child(_spiral)

	_trail.position.y = 0.15
	_trail.local_coords = false
	_trail.emitting = false
	add_child(_trail)

	_bubble.text = "Meow!"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 96
	_bubble.outline_size = 48  # black on a thick white outline: the speech bubble
	_bubble.modulate = Color.BLACK
	_bubble.outline_modulate = Color.WHITE
	_bubble.pixel_size = 0.004
	_bubble.position.y = 1.4
	_bubble.visible = false
	add_child(_bubble)


## Called every frame with the Cat's state. `moving` is whether it moved in the last rules
## step, `fast` whether it runs faster than a Cat without Catnip, and `resting` stops the
## walk and idle animations from replacing a result pose.
func show_state(cat: CatState, moving: bool, fast: bool, resting: bool) -> void:
	rotation.y = atan2(cat.facing.x, cat.facing.y)  # the models face +Z (south)
	var busy := _animations.is_playing() and _animations.current_animation in ["place_bomb", "die"]
	if cat.alive and not busy and not resting:
		_animations.play("walk" if moving else "idle")
	_aura.visible = cat.alive and cat.nine_lives
	_model.visible = fmod(cat.invulnerable_left * BLINKS_PER_SECOND, 1.0) < 0.5
	_spiral.visible = cat.curse != null
	_spiral.rotation.y = Time.get_ticks_msec() / 1000.0 * -7.0
	for mesh in _meshes:
		mesh.material_overlay = _curse_tint if cat.curse != null else null
	_trail.emitting = cat.alive and moving and fast


func play(animation: String) -> void:
	_animations.play(animation)


## Falls from the sky onto its Tile.
func drop() -> void:
	_model.position.y = DROP_HEIGHT
	create_tween().tween_property(_model, "position:y", 0.0, DROP_SECONDS) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func meow() -> void:
	Audio.play(&"meow", randf_range(0.9, 1.15))
	_bubble.visible = true
	if _bubble_timer != null:
		_bubble_timer.kill()  # a new meow keeps the bubble up
	_bubble_timer = create_tween()
	_bubble_timer.tween_callback(func() -> void: _bubble.visible = false).set_delay(MEOW_SECONDS)


## A white spiral on a clear background, drawn once and shared by every Cat.
static func _spiral_texture() -> Texture2D:
	if _spiral_image != null:
		return _spiral_image
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for step in 600:
		var turn := step / 600.0
		var point := Vector2(32, 32) + Vector2.from_angle(turn * TAU * 3.0) * turn * 29.0
		image.fill_rect(Rect2i(Vector2i(point) - Vector2i.ONE, Vector2i(3, 3)), Color.WHITE)
	_spiral_image = ImageTexture.create_from_image(image)
	return _spiral_image
