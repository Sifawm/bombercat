class_name Roster
## The selectable Cats and the colour that identifies each Player on screen.

const CATS: Array[Dictionary] = [
	{"name": "Turing", "scene": preload("res://assets/models/turing.glb"), "portrait": "turing"},
	{"name": "Berni", "scene": preload("res://assets/models/berni.glb"), "portrait": "berni"},
	{"name": "Aquiles", "scene": preload("res://assets/models/aquiles.glb"), "portrait": "aquiles"},
	{"name": "Hami", "scene": preload("res://assets/models/hami.glb"), "portrait": "hami"},
	{"name": "Ada Lovelace", "scene": preload("res://assets/models/ada.glb"), "portrait": "ada"},
]
## The design's player colours, in the order the Users joined the Room.
const PLAYER_COLORS: Array[Color] = [Color("ff5a5f"), Color("4d9bff"), Color("3ccb6e"), Color("c084ff")]


static func cat_name(pick: int) -> String:
	return CATS[pick].name


static func cat_scene(pick: int) -> PackedScene:
	return CATS[pick].scene


## The design's picture of the Cat standing, exported from Penpot.
static func portrait(pick: int) -> String:
	return "res://assets/portraits/%s.png" % CATS[pick].portrait
