extends RulesTestCase
## The Laser Pointer's hunt (docs/laser-pointer.md): what each Cat does with the dot, and when the
## dot is seen at all.

const CAT := Vector2(960, 540)


## A dot the mouse has just moved to `at`.
func dot_at(at: Vector2) -> LaserDot:
	var dot := LaserDot.new()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	dot.take(motion)
	return dot


func chase(offset: Vector2) -> LaserChase:
	return LaserChase.new(CAT, dot_at(CAT + offset))


func test_the_band_follows_the_distance_to_the_dot() -> void:
	check_eq(chase(Vector2(600, 0)).band, LaserChase.Band.WATCH, "far away")
	check_eq(chase(Vector2(0, -300)).band, LaserChase.Band.HUNT, "near")
	check_eq(chase(Vector2(60, 40)).band, LaserChase.Band.BITE, "right on the Cat")


func test_a_resting_mouse_puts_the_dot_out_and_every_cat_idles() -> void:
	var dot := dot_at(CAT)
	dot.advance(2.9)
	check(dot.visible, "still seen just before the timeout")
	dot.advance(0.2)
	check(not dot.visible, "out once the mouse has rested")
	check_eq(LaserChase.new(CAT, dot).band, LaserChase.Band.IDLE, "a Cat with no dot to see")


func test_the_dot_goes_out_when_the_mouse_leaves_the_window_and_comes_back_on_a_move() -> void:
	var dot := dot_at(CAT)
	dot.leave()
	check(not dot.visible, "out of the window")
	var motion := InputEventMouseMotion.new()
	motion.position = CAT
	dot.take(motion)
	check(dot.visible, "back on the next move")


func test_touch_never_shows_the_dot() -> void:
	var dot := LaserDot.new()
	var touch := InputEventScreenDrag.new()
	touch.position = CAT
	dot.take(touch)
	var emulated := InputEventMouseMotion.new()  # what Godot makes of a touch
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = CAT
	dot.take(emulated)
	check(not dot.visible, "a finger is not a laser")


func test_the_hops_get_lower_as_the_dot_comes_nearer() -> void:
	var far := chase(Vector2(LaserChase.HUNT_DISTANCE, 0)).hop
	var middle := chase(Vector2(265, 0)).hop
	var near := chase(Vector2(LaserChase.BITE_DISTANCE, 0)).hop
	check_eq(far, 1.0, "the highest hop at the band's far edge")
	check(middle < far and near < middle, "lower and lower: %s, %s, %s" % [far, middle, near])
	check(near > 0.0, "still a hop at the near edge")
	check_eq(chase(Vector2(600, 0)).hop, 0.0, "no hop from too far")
	check_eq(chase(Vector2(60, 0)).hop, 0.0, "no hop while biting")


func test_a_still_dot_is_only_watched() -> void:
	var dot := dot_at(CAT + Vector2(300, 0))
	dot.advance(0.5)
	var still := LaserChase.new(CAT, dot)
	check_eq(still.band, LaserChase.Band.HUNT, "still in reach")
	check_eq(still.hop, 0.0, "no hop at a dot that does not move")
	check_eq(still.paw, &"", "no swat either")


## The Cat faces the screen, so its left paw is on the screen's right.
func test_the_cat_swats_with_the_paw_on_the_dots_side() -> void:
	check_eq(chase(Vector2(250, 0)).paw, &"L", "dot on the screen's right")
	check_eq(chase(Vector2(-250, 0)).paw, &"R", "dot on the screen's left")
	check_eq(chase(Vector2(600, 0)).paw, &"", "no swat from too far")


func test_the_cat_turns_its_body_and_head_towards_the_dot_within_their_limits() -> void:
	var aside := chase(Vector2(150, 0))
	var far_aside := chase(Vector2(900, 0))
	check(aside.body_yaw > 0.0 and aside.head_yaw > 0.0, "towards a dot on the screen's right")
	check(far_aside.body_yaw > aside.body_yaw, "further round for a dot further aside")
	check_eq(far_aside.body_yaw, LaserChase.BODY_YAW, "the body stops at its limit")
	check_eq(far_aside.head_yaw, LaserChase.HEAD_YAW, "the head stops at its own limit on top")
	check_eq(chase(Vector2(-900, 0)).body_yaw, -LaserChase.BODY_YAW, "the other way for a dot on the left")
	check_eq(chase(Vector2(0, -300)).body_yaw, 0.0, "straight ahead for a dot right above")


func test_the_cat_looks_up_and_down_at_the_dot() -> void:
	check(chase(Vector2(0, -300)).head_pitch > 0.0, "up at a dot above")
	check(chase(Vector2(0, 300)).head_pitch < 0.0, "down at a dot below")
	check_eq(chase(Vector2(0, -2000)).head_pitch, LaserChase.HEAD_PITCH, "no further than its limit")


func test_a_cat_with_no_dot_to_see_faces_the_front() -> void:
	var idle := LaserChase.new(CAT, LaserDot.new())
	check_eq([idle.body_yaw, idle.head_yaw, idle.head_pitch, idle.hop], [0.0, 0.0, 0.0, 0.0], "at rest")


func test_the_band_edges_belong_to_the_nearer_band() -> void:
	check_eq(chase(Vector2(LaserChase.HUNT_DISTANCE, 0)).band, LaserChase.Band.HUNT, "at the hunt band's far edge")
	check_eq(chase(Vector2(LaserChase.HUNT_DISTANCE + 1.0, 0)).band, LaserChase.Band.WATCH, "just beyond it")
	check_eq(chase(Vector2(LaserChase.BITE_DISTANCE, 0)).band, LaserChase.Band.HUNT, "at the bite band's edge")
	check_eq(chase(Vector2(LaserChase.BITE_DISTANCE - 1.0, 0)).band, LaserChase.Band.BITE, "just inside it")
