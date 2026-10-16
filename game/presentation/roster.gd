class_name Roster
## The selectable Cats and the colour that identifies each Player on screen.

const CATS: Array[Dictionary] = [
	{"name": "Turing", "scene": preload("res://assets/models/turing.glb")},
	{"name": "Berni", "scene": preload("res://assets/models/berni.glb")},
	{"name": "Aquiles", "scene": preload("res://assets/models/aquiles.glb")},
	{"name": "Hami", "scene": preload("res://assets/models/hami.glb")},
	{"name": "Ada Lovelace", "scene": preload("res://assets/models/ada.glb")},
]
## The design's player colours, in the order the Users joined the Room.
const PLAYER_COLORS: Array[Color] = [Color("ff5a5f"), Color("4d9bff"), Color("3ccb6e"), Color("c084ff")]


static func cat_name(pick: int) -> String:
	return CATS[pick].name


static func cat_scene(pick: int) -> PackedScene:
	return CATS[pick].scene
