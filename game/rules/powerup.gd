@tool
class_name Powerup
extends RefCounted
## Something a Cat gains by walking over it. Each Powerup is one script in rules/powerups/
## named after its id, so adding a Powerup means adding a file there (and its model).

const FOLDER := "res://rules/powerups/"

var id: StringName


static func exists(powerup_id: StringName) -> bool:
	return ResourceLoader.exists(FOLDER + powerup_id + ".gd")


static func create(powerup_id: StringName) -> Powerup:
	var script: GDScript = load(FOLDER + powerup_id + ".gd")
	var powerup: Powerup = script.new()
	powerup.id = powerup_id
	return powerup


## The ids of the Powerups `cat` collected and still has, in the order it collected them.
static func held_by(cat: CatState) -> Array[StringName]:
	return cat.collected.filter(func(powerup_id: StringName) -> bool: return create(powerup_id).is_held_by(cat))


## Whether `cat`, which collected this Powerup, still has it. Most last the whole Round.
func is_held_by(_cat: CatState) -> bool:
	return true


## Changes `cat` for the rest of the Round. `random` is the Round's only source of chance.
func apply(_cat: CatState, _config: GameConfig, _random: RandomNumberGenerator) -> void:
	pass
