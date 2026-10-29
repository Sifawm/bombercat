extends Node
## Renders the still pictures of the Cats (assets/portraits and assets/faces) and of the Maps
## (assets/maps) from the game's own models, so they always look like what is played (ADR 0006):
## the Cats framed and lit as ModelView shows them, the Maps lit as a Round lights them. Run it
## again whenever a model, a Map or the cartoon look changes. It is a scene, so the game's autoloads
## are there, and needs a window, so not --headless:
##
##     godot --path game tools/render_pictures.tscn

const ROUND_VIEW: PackedScene = preload("res://presentation/round_view.tscn")
const PORTRAIT := Vector2i(312, 480)
const FACE := 240
## Rendered this many times larger, then shrunk, to smooth the edges.
const OVERSAMPLE := 2
## The face is a square of the portrait, centred, this wide and starting this far down (fractions
## of the portrait's width and height): from the tips of the ears to the collar.
const FACE_WIDTH := 1.0
const FACE_TOP := 0.12
const MAP_WIDTH := 1100
## A Map is seen isometrically, from above its south-east corner.
const ISOMETRIC := Vector3(1.0, 1.0, 1.0)
## The camera stands this far away, so its perspective is as flat as an isometric drawing (the
## outline needs a perspective camera).
const MAP_DISTANCE := 300.0
## The picture frames the Map's outline at the foot and at the top of its Walls, with this room.
const WALL_HEIGHT := 0.7
const MAP_MARGIN := 1.03


func _ready() -> void:
	for pick in Roster.CATS.size():
		await _render_cat(pick)
	for file in DirAccess.get_files_at("res://maps"):
		if file.ends_with(".tscn"):
			await _render_map(file.get_basename())
	get_tree().quit()


func _render_cat(pick: int) -> void:
	var view := ModelView.new(Roster.cat_scene(pick), Vector2(PORTRAIT * OVERSAMPLE), false, true)
	view.play("idle")
	(view.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).pause()  # the same pose every run
	add_child(view)
	var image := await _drawn(view.get_child(0) as SubViewport)
	var name: String = Roster.CATS[pick].portrait

	var side := int(image.get_width() * FACE_WIDTH)
	var face := image.get_region(Rect2i((image.get_width() - side) / 2, int(image.get_height() * FACE_TOP), side, side))
	face.resize(FACE, FACE, Image.INTERPOLATE_LANCZOS)
	face.save_png("res://assets/faces/%s.png" % name)
	image.resize(PORTRAIT.x, PORTRAIT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("res://assets/portraits/%s.png" % name)
	view.queue_free()


## The Map as painted in Map Studio, Crates and Spawn Points included, on a transparent ground.
func _render_map(map: String) -> void:
	var node: MapScene = (load("res://maps/%s.tscn" % map) as PackedScene).instantiate()
	var round_view := ROUND_VIEW.instantiate()  # its sun and environment, as they light a Round
	var sun: DirectionalLight3D = round_view.get_node("Sun").duplicate()
	var environment: Environment = (round_view.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate()
	round_view.free()
	sun.light_color = node.light
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = MAP_DISTANCE * 1.2
	environment.ambient_light_color = node.light
	environment.background_mode = Environment.BG_CLEAR_COLOR

	var size := node.to_map_data().size
	var centre := node.tile_to_local(Vector2(size - Vector2i.ONE) / 2.0)
	var basis := Basis.looking_at(-ISOMETRIC)
	var left := INF
	var right := -INF
	var bottom := INF
	var top := -INF
	for x: float in [-0.5, size.x - 0.5]:
		for y: float in [-0.5, size.y - 0.5]:
			for height: float in [0.0, WALL_HEIGHT]:
				var seen := node.tile_to_local(Vector2(x, y)) + Vector3(0.0, height, 0.0) - centre
				left = minf(left, seen.dot(basis.x))
				right = maxf(right, seen.dot(basis.x))
				bottom = minf(bottom, seen.dot(basis.y))
				top = maxf(top, seen.dot(basis.y))
	var camera := Camera3D.new()
	camera.environment = environment
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = rad_to_deg(2.0 * atan((right - left) * MAP_MARGIN / 2.0 / MAP_DISTANCE))
	camera.near = MAP_DISTANCE / 2.0
	camera.far = MAP_DISTANCE * 2.0
	camera.transform = Transform3D(basis, centre + basis.x * (left + right) / 2.0 + basis.y * (bottom + top) / 2.0
			+ basis.z * MAP_DISTANCE)

	var stage := SubViewport.new()
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = Vector2i(MAP_WIDTH, roundi(MAP_WIDTH * (top - bottom) / (right - left))) * OVERSAMPLE
	for child: Node in [node, sun, camera]:
		stage.add_child(child)
	add_child(stage)
	var image := await _drawn(stage)
	image.resize(stage.size.x / OVERSAMPLE, stage.size.y / OVERSAMPLE, Image.INTERPOLATE_LANCZOS)
	image.save_png("res://assets/maps/%s.png" % map)
	stage.queue_free()


func _drawn(viewport: SubViewport) -> Image:
	for frame in 3:  # laid out and framed in _ready, drawn on the next frames
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
