extends Powerup


func apply(cat: CatState, _config: GameConfig, _random: RandomNumberGenerator) -> void:
	cat.paw_swipe = true
