class_name Roster
## The selectable Cats and the colour that identifies each Player on screen.

const CATS: Array[Dictionary] = [
	{"name": "Turing", "scene": preload("res://assets/models/turing.glb")},
	{"name": "Berni", "scene": preload("res://assets/models/berni.glb")},
	{"name": "Aquiles", "scene": preload("res://assets/models/aquiles.glb")},
	{"name": "Hami", "scene": preload("res://assets/models/hami.glb")},
	{"name": "Ada Lovelace", "scene": preload("res://assets/models/ada.glb")},
]
const PLAYER_COLORS: Array[Color] = [Color(1.0, 0.45, 0.3), Color(0.35, 0.75, 1.0)]


static func cat_name(pick: int) -> String:
	return CATS[pick].name


static func cat_scene(pick: int) -> PackedScene:
	return CATS[pick].scene
