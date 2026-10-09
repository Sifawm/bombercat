extends Powerup


func apply(cat: CatState, config: GameConfig, _random: RandomNumberGenerator) -> void:
	cat.speed = minf(cat.speed + config.catnip_speed_bonus, config.max_cat_speed)
