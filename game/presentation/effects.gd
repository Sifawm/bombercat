class_name Effects
## The particle bursts and glows of a Round. Everything here looks after itself: a burst
## frees itself when it is over.


## Small cubes thrown in every direction from where the burst is placed, shrinking as they go.
static func burst(color: Color, amount: int, speed: float, seconds: float, size: float,
		gravity: Vector3 = Vector3.DOWN * 9.8) -> CPUParticles3D:
	var particles := cubes(color, amount, seconds, size)
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = gravity
	particles.finished.connect(particles.queue_free)
	return particles


## A steady stream of small cubes; the caller gives it its motion and switches it on and off.
static func cubes(color: Color, amount: int, seconds: float, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = flat_material(color)
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = seconds
	particles.gravity = Vector3.ZERO
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = shrink
	return particles


## A see-through ball of light.
static func glow(color: Color, radius: float) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := flat_material(color)
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	ball.mesh = mesh
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ball


## An unlit material; see-through when `color` is.
static func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
