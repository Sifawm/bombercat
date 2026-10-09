extends Powerup

const CURSES: Array[GDScript] = [
	preload("res://rules/curses/inverted_controls.gd"),
	preload("res://rules/curses/slowness.gd"),
]


func apply(cat: CatState, config: GameConfig, random: RandomNumberGenerator) -> void:
	var curse: Curse = CURSES[random.randi_range(0, CURSES.size() - 1)].new()
	curse.time_left = config.curse_duration
	cat.curse = curse


func is_held_by(cat: CatState) -> bool:
	return cat.curse != null
