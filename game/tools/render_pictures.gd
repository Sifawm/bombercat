extends SceneTree
## Renders the still pictures of the Cats (assets/portraits and assets/faces) from the game's own
## models, framed and lit as ModelView shows them, so they always look like the Cats being played
## (ADR 0006). Run it again whenever a Cat's model or the cartoon look changes; it needs a
## window, so not --headless:
##
##     godot --path game -s tools/render_pictures.gd

const PORTRAIT := Vector2i(312, 480)
const FACE := 240
## Rendered this many times larger, then shrunk, to smooth the edges.
const OVERSAMPLE := 2
## The face is a square of the portrait, centred, this wide and starting this far down (fractions
## of the portrait's width and height): from the tips of the ears to the collar.
const FACE_WIDTH := 1.0
const FACE_TOP := 0.12


func _init() -> void:
	for pick in Roster.CATS.size():
		var view := ModelView.new(Roster.cat_scene(pick), Vector2(PORTRAIT * OVERSAMPLE), false, true)
		view.play("idle")
		root.add_child(view)
		for frame in 3:  # framed in _ready, drawn on the next frames
			await process_frame
		await RenderingServer.frame_post_draw
		var image := (view.get_child(0) as SubViewport).get_texture().get_image()
		var name: String = Roster.CATS[pick].portrait

		var side := int(image.get_width() * FACE_WIDTH)
		var face := image.get_region(Rect2i((image.get_width() - side) / 2, int(image.get_height() * FACE_TOP), side, side))
		face.resize(FACE, FACE, Image.INTERPOLATE_LANCZOS)
		face.save_png("res://assets/faces/%s.png" % name)
		image.resize(PORTRAIT.x, PORTRAIT.y, Image.INTERPOLATE_LANCZOS)
		image.save_png("res://assets/portraits/%s.png" % name)
		view.queue_free()
	quit()
