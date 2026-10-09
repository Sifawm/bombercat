extends Powerup


func apply(cat: CatState, config: GameConfig, _random: RandomNumberGenerator) -> void:
	cat.bomb_capacity = mini(cat.bomb_capacity + 1, config.max_bomb_capacity)
