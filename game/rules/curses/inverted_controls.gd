extends Curse


func _init() -> void:
	id = &"inverted_controls"


func redirect(direction: Vector2i) -> Vector2i:
	return -direction
