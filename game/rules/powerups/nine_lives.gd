extends Powerup


## A flag, not a count: Nine Lives does not stack.
func apply(cat: CatState, _config: GameConfig, _random: RandomNumberGenerator) -> void:
	cat.nine_lives = true


func is_held_by(cat: CatState) -> bool:
	return cat.nine_lives
