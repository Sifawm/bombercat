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


## Changes `cat` for the rest of the Round. `random` is the Round's only source of chance.
func apply(_cat: CatState, _config: GameConfig, _random: RandomNumberGenerator) -> void:
	pass
