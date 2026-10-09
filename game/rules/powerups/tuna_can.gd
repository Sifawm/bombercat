extends Powerup


func apply(cat: CatState, config: GameConfig, _random: RandomNumberGenerator) -> void:
	cat.bomb_range = mini(cat.bomb_range + 1, config.max_bomb_range)
