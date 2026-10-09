class_name GameConfig
extends Resource
## Every tunable balance value. The rules receive this resource and never hard-code numbers.
## Edit res://config/game_config.tres in the inspector to tune the game.

@export_group("Cat")
## Tiles per second.
@export var cat_speed: float = 4.0
## How far (in Tiles) a Cat may be from a corridor and still slide into it when turning.
@export_range(0.0, 1.0) var corner_assist: float = 0.7
@export var bomb_capacity: int = 1
@export var bomb_range: int = 2
@export var max_bomb_capacity: int = 8
@export var max_bomb_range: int = 8
@export var max_cat_speed: float = 7.0

@export_group("Bomb")
## Seconds between placing a Bomb and its detonation.
@export var fuse: float = 3.0
## Seconds an Explosion stays lethal.
@export var explosion_lifetime: float = 0.5

## Tiles per second of a Bomb pushed with Paw Swipe.
@export var bomb_slide_speed: float = 8.0

@export_group("Powerups")
## Tiles per second added by each Catnip.
@export var catnip_speed_gain: float = 0.75
## Seconds a Cat cannot be hurt after Nine Lives absorbs an Explosion.
@export var nine_lives_invulnerability: float = 1.5
## Seconds a Curse lasts.
@export var curse_duration: float = 10.0
## Speed multiplier under the slowness Curse.
@export_range(0.1, 1.0) var slowness_factor: float = 0.5

@export_group("Round")
## Seconds before a Round ends in a Draw.
@export var round_time: float = 120.0

@export_group("Match")
## Round wins that win a Match.
@export var rounds_to_win: int = 2
