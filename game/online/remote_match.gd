class_name RemoteMatch
extends Match
## The Match of a Room, as far as this client knows it. Its Rounds are RemoteRounds, built
## from the state the server keeps, and it counts them as any Match does.

## The Game's state as the server last gave it whole: set it before starting a Round.
var state: Dictionary


func _init(map: MapData, game_config: GameConfig, match_state: Dictionary) -> void:
	super(map, game_config, (match_state.players as Array).size())
	state = match_state


func start_round() -> Round:
	wins.assign(state.wins)
	bombs_placed.assign(state.bombsPlaced)
	crates_destroyed.assign(state.cratesDestroyed)
	powerups_collected.assign(state.powerupsCollected)
	round_number = int(state.roundNumber)
	current_round = RemoteRound.new(_map, config, state.round)
	current_round.round_ended.connect(_on_round_ended)
	return current_round
