class_name PowerupPool
extends RefCounted
## Hides a Map's Powerup Pool in its Crates: the quantities are fixed, the Crates are random.


## Which Powerup (by id) each chosen Crate holds. A pool larger than `crates` fills them all.
static func distribute(pool: Dictionary[StringName, int], crates: Array[Vector2i],
		random: RandomNumberGenerator) -> Dictionary[Vector2i, StringName]:
	var shuffled := crates.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):  # Fisher-Yates, on the injected random source
		var other := random.randi_range(0, index)
		var held: Vector2i = shuffled[index]
		shuffled[index] = shuffled[other]
		shuffled[other] = held
	var hidden: Dictionary[Vector2i, StringName] = {}
	for powerup: StringName in pool:
		for count in pool[powerup]:
			if hidden.size() < shuffled.size():
				hidden[shuffled[hidden.size()]] = powerup
	return hidden
