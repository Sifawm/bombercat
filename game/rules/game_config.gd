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

@export_group("Bomb")
## Seconds between placing a Bomb and its detonation.
@export var fuse: float = 3.0
## Seconds an Explosion stays lethal.
@export var explosion_lifetime: float = 0.5

@export_group("Round")
## Seconds before a Round ends in a Draw.
@export var round_time: float = 120.0
