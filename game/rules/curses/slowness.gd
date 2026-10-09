extends Curse


func _init() -> void:
	id = &"slowness"


func speed_factor(config: GameConfig) -> float:
	return config.slowness_factor
