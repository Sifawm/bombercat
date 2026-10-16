class_name RoundHud
extends Control
## The design's RoundHud over the Round: each Player's PlayerPanel in a corner of its own, by
## index (top left, top right, bottom left, bottom right), and between the top two the
## RoundTimer over the Round's number, or the RoundBanner once the Round is over.

## How far the parts of the HUD stand from the edges of the picture.
const MARGIN := 24
## The corner of each Player's panel, by index.
const CORNERS: Array[LayoutPreset] = [PRESET_TOP_LEFT, PRESET_TOP_RIGHT, PRESET_BOTTOM_LEFT, PRESET_BOTTOM_RIGHT]
## How far the RoundBanner falls from, over the picture, and for how long.
const BANNER_DROP := 300.0
const BANNER_SECONDS := 0.6

var _panels: Array[PlayerPanel] = []
var _status := VBoxContainer.new()
var _timer := PanelContainer.new()
var _time := Ui.label("", 64, Ui.INK, Ui.LILITA)
var _round_badge := Ui.badge("", true)
var _calm := _timer_box(Ui.YELLOW)
var _hurried := _timer_box(Ui.RED)
var _banner: Control


## `cat_picks` holds the index in Roster.CATS of each Player's Cat, and `names` what to call
## each Player.
func _init(cat_picks: Array[int], names: PackedStringArray) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for player in cat_picks.size():
		var right := player % 2 == 1
		var bottom := player >= 2
		var panel := PlayerPanel.new(cat_picks[player], names[player], Roster.PLAYER_COLORS[player], right)
		panel.set_anchors_preset(CORNERS[player])
		panel.offset_left = -MARGIN if right else MARGIN
		panel.offset_right = panel.offset_left
		panel.offset_top = -MARGIN if bottom else MARGIN
		panel.offset_bottom = panel.offset_top
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
		add_child(panel)
		_panels.append(panel)
	_status.add_theme_constant_override("separation", 12)
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.offset_top = MARGIN
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer.custom_minimum_size = Vector2(240, 104)
	_timer.add_theme_stylebox_override("panel", _calm)
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer.add_child(_time)
	_status.add_child(_timer)
	_round_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status.add_child(_round_badge)
	add_child(_status)


## The parts of the picture the HUD covers while a Round is played, which the Map stays clear
## of: the panels and the timer. The Round's number may stand on the far Wall, as in the design.
## Measured from what the parts need, so it holds before they are laid out.
func covered() -> Array[Rect2]:
	var picture := get_viewport_rect().size
	var rects: Array[Rect2] = []
	for player in _panels.size():
		var size := _panels[player].get_combined_minimum_size()
		var x := picture.x - MARGIN - size.x if player % 2 == 1 else float(MARGIN)
		var y := picture.y - MARGIN - size.y if player >= 2 else float(MARGIN)
		rects.append(Rect2(x, y, size.x, size.y))
	var timer := _timer.get_combined_minimum_size()
	rects.append(Rect2((picture.x - timer.x) / 2.0, MARGIN, timer.x, timer.y))
	return rects


func show_wins(wins: Array[int], rounds_to_win: int) -> void:
	for player in _panels.size():
		_panels[player].show_wins(wins[player], rounds_to_win)


## A new Round: its number under the timer, where the last one's banner was.
func show_round(number: int) -> void:
	(_round_badge.get_child(0) as Label).text = "Round %d" % number
	_status.visible = true
	if _banner != null:
		_banner.queue_free()
		_banner = null


## The time left; in a hurry it turns red and swells by `pulse` of its size.
func show_time(seconds: int, hurry: bool, pulse: float) -> void:
	_time.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_timer.add_theme_stylebox_override("panel", _hurried if hurry else _calm)
	_timer.pivot_offset = _timer.size / 2.0
	_timer.scale = Vector2.ONE * (1.0 + pulse)


func show_cat(player: int, cat: CatState, config: GameConfig) -> void:
	_panels[player].show_cat(cat, config)


## The design's RoundBanner falls in the timer's place: who won the Round, with the face of
## its Cat (`pick` in Roster.CATS), or that it was a Draw.
func show_result(winner: int, pick: int, winner_name: String, number: int) -> void:
	_status.visible = false
	var won := winner != Round.DRAW
	_banner = PanelContainer.new()
	var box := Ui.claimed(Ui.CREAM if won else Ui.YELLOW, Roster.PLAYER_COLORS[winner] if won else Ui.INK, 40)
	box.set_content_margin_all(20)
	box.content_margin_left = 48
	_banner.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_banner.add_child(row)
	if won:
		row.add_child(Ui.portrait(Roster.face(pick), 112, 6, Roster.PLAYER_COLORS[winner]))
	else:
		row.add_child(Ui.portrait("res://assets/icons/bomb.png", 112, 12, Ui.SKY, 40, true))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	var badge := Ui.badge("Round %d" % number, true)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	texts.add_child(badge)
	var headline := HBoxContainer.new()
	headline.add_theme_constant_override("separation", 24)
	headline.add_child(Ui.label("%s wins the Round!" % winner_name if won else "Draw!", 88, Ui.INK, Ui.LILITA))
	if not won:
		var detail := Ui.label("Nobody scores.\nThe Round is replayed.", 32, Ui.INK, Ui.FREDOKA_MEDIUM)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		headline.add_child(detail)
	texts.add_child(headline)
	row.add_child(texts)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = MARGIN
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)
	# Between the top panels, smaller when a long name would not fit there.
	var room := get_viewport_rect().size.x - 2.0 * (MARGIN * 2 + _widest_top_panel())
	var needed := _banner.get_combined_minimum_size()
	_banner.pivot_offset = Vector2(needed.x / 2.0, 0.0)
	_banner.scale = Vector2.ONE * minf(1.0, room / needed.x)
	_banner.position.y = -BANNER_DROP
	_banner.create_tween().tween_property(_banner, "position:y", float(MARGIN), BANNER_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _widest_top_panel() -> float:
	var widest := 0.0
	for player in mini(_panels.size(), 2):
		widest = maxf(widest, _panels[player].get_combined_minimum_size().x)
	return widest


## The design's RoundTimer: the time on a yellow surface, or a red one in a hurry.
static func _timer_box(fill: Color) -> StyleBox:
	var box := Ui.surface(fill)
	box.set_content_margin_all(0)
	return box


## The design's PlayerPanel: a Player's Cat, name and Rounds won, what its Cat can do now and
## the Powerups it holds. A Player whose Cat is out of the Round fades.
class PlayerPanel:
	extends PanelContainer

	## The Powerups that count up what a Cat can do, in the order the design shows them.
	const STATS: Array[StringName] = [&"yarn_ball", &"tuna_can", &"catnip"]
	## The Powerups held one at a time, which light their slot.
	const ABILITIES: Array[StringName] = [&"nine_lives", &"paw_swipe", &"cucumber"]
	## The design's width; a long name or many Rounds to win make it wider.
	const WIDTH := 344

	var _color: Color
	var _portrait: Control
	var _pips := HBoxContainer.new()
	var _out := Ui.badge("Out", true)
	var _stats := HBoxContainer.new()
	var _values: Array[Label] = []
	var _abilities := HBoxContainer.new()
	var _slots: Array[PanelContainer] = []
	var _curse_time := Ui.label("", 28, Ui.INK, Ui.LILITA)
	## What the panel shows, to restyle it only when that changes.
	var _shown := []

	## The panels on the right read from the right.
	func _init(pick: int, player_name: String, color: Color, right: bool) -> void:
		_color = color
		var box := Ui.rounded(Ui.CREAM, 40, 0)
		box.set_border_width_all(12)
		box.border_color = color
		box.content_margin_top = 20
		box.content_margin_left = 24
		box.content_margin_right = 24
		box.content_margin_bottom = 24
		add_theme_stylebox_override("panel", box)
		custom_minimum_size.x = WIDTH
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		add_child(column)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 16)
		header.size_flags_horizontal = side
		_portrait = Ui.portrait(Roster.face(pick), 96, 6, color)
		var identity := VBoxContainer.new()
		identity.add_theme_constant_override("separation", 8)
		identity.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_label := Ui.label(player_name, 32, Ui.INK, Ui.LILITA)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		identity.add_child(name_label)
		_pips.add_theme_constant_override("separation", 8)
		var wins := HBoxContainer.new()
		wins.add_theme_constant_override("separation", 8)
		wins.size_flags_horizontal = side
		wins.add_child(_pips)
		_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wins.add_child(_out)
		identity.add_child(wins)
		header.add_child(identity if right else _portrait)
		header.add_child(_portrait if right else identity)
		column.add_child(header)

		_stats.add_theme_constant_override("separation", 16)
		_stats.size_flags_horizontal = side
		for powerup_id in STATS:
			var stat := HBoxContainer.new()
			stat.add_theme_constant_override("separation", 4)
			stat.add_child(_icon(powerup_id, 56))
			var value := Ui.label("0", 32, Ui.INK, Ui.LILITA)  # measured before the first Cat is shown
			stat.add_child(value)
			_values.append(value)
			_stats.add_child(stat)
		column.add_child(_stats)

		_abilities.add_theme_constant_override("separation", 8)
		_abilities.size_flags_horizontal = side
		for powerup_id in ABILITIES:
			var slot := PanelContainer.new()
			slot.custom_minimum_size = Vector2(64, 64)
			var inside := HBoxContainer.new()
			inside.add_theme_constant_override("separation", 4)
			inside.alignment = BoxContainer.ALIGNMENT_CENTER
			inside.add_child(_icon(powerup_id, 48))
			slot.add_child(inside)
			_slots.append(slot)
			_abilities.add_child(slot)
		_curse_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_curse_time.visible = false
		_slots[2].get_child(0).add_child(_curse_time)
		column.add_child(_abilities)

	func show_wins(won: int, rounds_to_win: int) -> void:
		for pip in _pips.get_children():
			pip.queue_free()
		for at in rounds_to_win:
			_pips.add_child(Ui.pip(at < won))

	## The Catnip a Cat has is told by how much faster than the others it runs, so it stops
	## counting at the top speed.
	func show_cat(cat: CatState, config: GameConfig) -> void:
		var catnip := roundi((cat.speed - config.cat_speed) / config.catnip_speed_gain)
		var curse_left := ceili(cat.curse.time_left) if cat.curse != null and cat.alive else 0
		var shown := [cat.alive, cat.bomb_capacity, cat.bomb_range, catnip, cat.nine_lives, cat.paw_swipe, curse_left]
		if shown == _shown:
			return
		_shown = shown
		var out := not cat.alive
		_out.modulate.a = 1.0 if out else 0.0  # it keeps its room, so the panel never changes size
		var back: Panel = _portrait.get_child(0)
		back.add_theme_stylebox_override("panel", Ui.rounded(Ui.INK if out else _color, 40, 0))
		back.get_child(0).modulate.a = 0.5 if out else 1.0
		for at in _values.size():
			_values[at].text = str([cat.bomb_capacity, cat.bomb_range, catnip][at])
		_stats.modulate.a = 0.5 if out else 1.0
		_abilities.modulate.a = 0.5 if out else 1.0
		_show_slot(_slots[0], Ui.SKY if cat.nine_lives and not out else Color.TRANSPARENT)
		_show_slot(_slots[1], Ui.SKY if cat.paw_swipe and not out else Color.TRANSPARENT)
		_show_slot(_slots[2], Ui.RED if curse_left > 0 else Color.TRANSPARENT)
		_curse_time.visible = curse_left > 0
		_curse_time.text = "%ds" % curse_left

	## The design's AbilitySlot: lit in `fill`, or off without one.
	static func _show_slot(slot: PanelContainer, fill: Color) -> void:
		var off := fill == Color.TRANSPARENT
		var box := Ui.rounded(Ui.CREAM if off else fill, 28, 0)
		box.set_border_width_all(6)
		box.border_color = Ui.INK
		box.set_content_margin_all(8)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		if fill == Ui.RED:  # the time left beside the icon
			box.content_margin_left = 10
			box.content_margin_right = 10
		slot.add_theme_stylebox_override("panel", box)
		slot.modulate.a = 0.5 if off else 1.0

	static func _icon(powerup_id: StringName, side: int) -> TextureRect:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % powerup_id)
		icon.custom_minimum_size = Vector2(side, side)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return icon
