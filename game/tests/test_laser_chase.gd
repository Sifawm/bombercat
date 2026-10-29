extends RulesTestCase
## The Laser Pointer's hunt (docs/laser-pointer.md): what each Cat does with the dot, and when the
## dot is seen at all.

## A Cat's place on screen: its centre at (960, 540), its feet at 690.
const CAT := Rect2(860, 390, 200, 300)
const CENTRE := Vector2(960, 540)


## A dot the mouse has just moved to `at`.
func dot_at(at: Vector2) -> LaserDot:
	var dot := LaserDot.new()
	move(dot, at)
	return dot


func move(dot: LaserDot, to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = to
	dot.take(motion)


## What a Cat does on its first look at a dot just moved to `offset` from its centre.
func chase(offset: Vector2) -> LaserChase:
	var chase := LaserChase.new()
	chase.follow(CAT, dot_at(CENTRE + offset), 0.0)
	return chase


func test_the_cat_acts_on_the_distance_to_the_dot() -> void:
	check_eq(chase(Vector2(600, 0)).act, LaserChase.Act.WATCH, "far away")
	check_eq(chase(Vector2(0, -300)).act, LaserChase.Act.HOP, "near")
	check_eq(chase(Vector2(60, 40)).act, LaserChase.Act.SWAT, "within the paw's reach")


func test_a_resting_mouse_puts_the_dot_out_and_every_cat_idles() -> void:
	var dot := dot_at(CENTRE)
	dot.advance(2.9)
	check(dot.visible, "still seen just before the timeout")
	dot.advance(0.2)
	check(not dot.visible, "out once the mouse has rested")
	var chase := LaserChase.new()
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.act, LaserChase.Act.IDLE, "a Cat with no dot to see")


func test_the_dot_goes_out_when_the_mouse_leaves_the_window_and_comes_back_on_a_move() -> void:
	var dot := dot_at(CENTRE)
	dot.leave()
	check(not dot.visible, "out of the window")
	move(dot, CENTRE)
	check(dot.visible, "back on the next move")


func test_touch_never_shows_the_dot() -> void:
	var dot := LaserDot.new()
	var touch := InputEventScreenDrag.new()
	touch.position = CENTRE
	dot.take(touch)
	var emulated := InputEventMouseMotion.new()  # what Godot makes of a touch
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = CENTRE
	dot.take(emulated)
	check(not dot.visible, "a finger is not a laser")


## The Cat faces the screen, so its left paw is on the screen's right.
func test_the_cat_reaches_out_with_the_paw_on_the_dots_side() -> void:
	check_eq(chase(Vector2(250, -100)).paw, &"L", "dot on the screen's right")
	check_eq(chase(Vector2(-250, -100)).paw, &"R", "dot on the screen's left")


func test_the_cat_swats_with_the_paw_on_the_dots_side() -> void:
	check_eq(chase(Vector2(60, 40)).paw, &"L", "dot on the screen's right")
	check_eq(chase(Vector2(-60, 40)).paw, &"R", "dot on the screen's left")


func test_a_dot_wavering_right_above_the_cat_keeps_the_same_paw_out() -> void:
	var dot := dot_at(CENTRE + Vector2(-200, -200))
	var chase := LaserChase.new()
	chase.follow(CAT, dot, 0.0)
	move(dot, CENTRE + Vector2(5, -200))
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.paw, &"R", "not swapped for a dot a hair to the other side")
	move(dot, CENTRE + Vector2(100, -200))
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.paw, &"L", "swapped once the dot is clearly on the other side")


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
	check_eq(chase(Vector2(0, 2000)).head_pitch, -LaserChase.HEAD_DOWN, "less far down, so its face still shows")


func test_a_cat_with_no_dot_to_see_faces_the_front() -> void:
	var idle := LaserChase.new()
	idle.follow(CAT, LaserDot.new(), 0.0)
	check_eq([idle.body_yaw, idle.head_yaw, idle.head_pitch], [0.0, 0.0, 0.0], "at rest")


func test_the_band_edges_belong_to_the_nearer_band() -> void:
	check_eq(chase(Vector2(LaserChase.HUNT_DISTANCE, 0)).act, LaserChase.Act.HOP, "at the hunt band's far edge")
	check_eq(chase(Vector2(LaserChase.HUNT_DISTANCE + 1.0, 0)).act, LaserChase.Act.WATCH, "just beyond it")
	check_eq(chase(Vector2(LaserChase.REACH_DISTANCE, 0)).act, LaserChase.Act.HOP, "at the paw's reach")
	check_eq(chase(Vector2(LaserChase.REACH_DISTANCE - 1.0, 0)).act, LaserChase.Act.SWAT, "just inside it")


func test_a_dot_resting_near_the_cat_is_stalked() -> void:
	var dot := dot_at(CENTRE + Vector2(300, -100))
	var chase := LaserChase.new()
	dot.advance(LaserChase.STALK_AFTER - 0.1)
	chase.follow(CAT, dot, 0.1)
	check_eq(chase.act, LaserChase.Act.HOP, "still hopping for a moment")
	dot.advance(0.2)
	chase.follow(CAT, dot, 0.2)
	check_eq(chase.act, LaserChase.Act.STALK, "crouched once the dot has rested")


func test_a_dot_resting_far_away_is_only_watched() -> void:
	var dot := dot_at(CENTRE + Vector2(600, 0))
	dot.advance(1.0)
	var chase := LaserChase.new()
	chase.follow(CAT, dot, 1.0)
	check_eq(chase.act, LaserChase.Act.WATCH, "no stalking from too far")


func test_a_dot_below_the_cats_feet_is_stalked_not_hopped_at() -> void:
	check_eq(chase(Vector2(150, 200)).act, LaserChase.Act.STALK, "below its feet, moving")
	check_eq(chase(Vector2(150, 100)).act, LaserChase.Act.HOP, "beside it, above its feet")


## A Cat that has crouched at a dot resting at `offset` from it.
func stalking(dot: LaserDot, offset: Vector2) -> LaserChase:
	move(dot, CENTRE + offset)
	dot.advance(LaserChase.STALK_AFTER)
	var chase := LaserChase.new()
	chase.follow(CAT, dot, LaserChase.STALK_AFTER)
	return chase


## A Cat that has leapt at a dot it stalked, which moved on to `offset` from it.
func pouncing(dot: LaserDot, offset: Vector2) -> LaserChase:
	var chase := stalking(dot, offset - Vector2(20, 0))
	move(dot, CENTRE + offset)
	chase.follow(CAT, dot, 0.0)
	return chase


func test_a_stalked_dot_that_moves_again_is_pounced_on() -> void:
	var dot := LaserDot.new()
	var chase := stalking(dot, Vector2(200, -100))
	move(dot, CENTRE + Vector2(220, -100))
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.act, LaserChase.Act.POUNCE, "the moment it moves")


func test_a_dot_rising_above_the_cats_feet_is_pounced_on() -> void:
	var dot := LaserDot.new()
	var chase := stalking(dot, Vector2(150, 200))
	move(dot, CENTRE + Vector2(150, 100))
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.act, LaserChase.Act.POUNCE, "up from below the Cat's feet")


func test_in_the_air_the_cat_no_longer_follows_the_dot() -> void:
	var dot := LaserDot.new()
	var chase := pouncing(dot, Vector2(220, -100))
	var aimed := [chase.body_yaw, chase.head_yaw, chase.head_pitch]
	move(dot, CENTRE + Vector2(-300, 50))
	chase.follow(CAT, dot, 0.1)
	check_eq(chase.act, LaserChase.Act.POUNCE, "a leap is not called off")
	check_eq([chase.body_yaw, chase.head_yaw, chase.head_pitch], aimed, "still facing where the dot was")
	dot.leave()
	chase.follow(CAT, dot, 0.1)
	check_eq(chase.act, LaserChase.Act.POUNCE, "not even when the dot goes out")


func test_landing_on_the_dot_pins_it_then_bites_it() -> void:
	var dot := LaserDot.new()
	var chase := pouncing(dot, Vector2(220, -100))
	move(dot, CENTRE + Vector2(260, -100))
	chase.finish(dot)
	check_eq(chase.act, LaserChase.Act.PIN, "caught: the dot is within reach of where the Cat aimed")
	chase.follow(CAT, dot, 0.1)
	check_eq(chase.act, LaserChase.Act.PIN, "the paws stay down until they are done")
	chase.finish(dot)
	check_eq(chase.act, LaserChase.Act.BITE, "then the bite")
	chase.finish(dot)
	chase.follow(CAT, dot, 0.0)
	check_eq(chase.act, LaserChase.Act.HOP, "then the hunt carries on")


func test_landing_away_from_the_dot_is_a_miss() -> void:
	var dot := LaserDot.new()
	var chase := pouncing(dot, Vector2(220, -100))
	var aimed := chase.body_yaw
	move(dot, CENTRE + Vector2(-250, -100))
	chase.finish(dot)
	check_eq(chase.act, LaserChase.Act.MISS, "landed on an empty spot")
	chase.follow(CAT, dot, LaserChase.MISS_PAUSE - 0.1)
	check_eq(chase.act, LaserChase.Act.MISS, "a pause")
	check_eq(chase.body_yaw, aimed, "the body still facing the empty spot")
	check(chase.body_yaw + chase.head_yaw < 0.0, "the head snapped round to the dot")
	chase.follow(CAT, dot, 0.2)
	check_eq(chase.act, LaserChase.Act.HOP, "then the hunt carries on")
	check(chase.body_yaw < 0.0, "the body turned to the dot again")
