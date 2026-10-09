class_name BombView
extends Node3D
## A Bomb on the Map. It throbs, blinks red and ticks at a rate that depends only on the Fuse
## left: 1.5 beats a second when placed, 7 just before it detonates.

const MODEL: PackedScene = preload("res://assets/models/bomb.glb")
const MODEL_SCALE := 0.8
const SLOWEST_BEAT := 1.5
const FASTEST_BEAT := 7.0

var _blink := Effects.flat_material(Color(1.0, 0.1, 0.05, 0.0))
var _beats_ticked := 0


func _init() -> void:
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _blink
	var spark := Effects.cubes(Color(1.0, 0.85, 0.3), 8, 0.25, 0.07)
	spark.position.y = 0.85
	spark.spread = 60.0
	spark.initial_velocity_max = 1.5
	add_child(spark)


## Called every frame. `fuse` is the full Fuse of a Bomb.
func show_state(bomb: Bomb, fuse: float) -> void:
	var elapsed := fuse - bomb.fuse_left
	var beats := SLOWEST_BEAT * elapsed + (FASTEST_BEAT - SLOWEST_BEAT) * elapsed * elapsed / (2.0 * fuse)
	var throb := sin(TAU * beats)
	scale = Vector3.ONE * (1.0 + 0.12 * throb)
	_blink.albedo_color.a = maxf(throb, 0.0) * 0.6
	if int(beats) > _beats_ticked:
		_beats_ticked = int(beats)
		Audio.play(&"fuse_tick")
