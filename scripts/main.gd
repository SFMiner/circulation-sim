extends Control
## App layer: builds all UI in code, owns modes, movement and input.

const SIDE_X: float = 680.0
const SIDE_W: float = 600.0
const DWELL_TIME: float = 0.6
const COL_BG: Color = Color("#f4f1f7")
const COL_PANEL: Color = Color("#ffffff")
const COL_TEXT: Color = Color("#2a2438")
const COL_MUTED: Color = Color("#6d6680")
const COL_RED: Color = Color("#c8102e")
const COL_BLUE: Color = Color("#3b4cc0")
const COL_GREEN: Color = Color("#1d7a3a")

var speed: float = 140.0
var current_station: int = CirculationData.START_STATION
var quiz_mode: bool = false
var quiz_complete: bool = false
var mistakes: int = 0
var steps_done: int = 0
var loop_forever: bool = false

var _moving: bool = false
var _moving_segment: int = 0
var _t: float = 0.0
var _playing: bool = false
var _dwell: float = 0.0
var _arrivals_in_play: int = 0
var _syncing: bool = false

var _map: CirculationMap
var _cell: BloodCell
var _drop_area: MapDropArea

var _explore_box: VBoxContainer
var _quiz_box: VBoxContainer
var _explore_btn: Button
var _quiz_btn: Button
var _step_btn: Button
var _play_btn: Button
var _reset_btn: Button
var _speed_slider: HSlider
var _speed_label: Label
var _loop_check: CheckBox
var _station_label: Label
var _circuit_label: Label
var _info_label: Label
var _o2_swatch: ColorRect
var _o2_word: Label
var _route_markers: Array[Label] = []
var _route_names: Array[Label] = []

var _prompt_label: Label
var _feedback_label: Label
var _stats_label: Label
var _card_grid: GridContainer
var _try_again_btn: Button
var _cards: Array[StationCard] = []


func _ready() -> void:
	_register_actions()
	theme = _build_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_map = CirculationMap.new()
	_map.position = Vector2.ZERO
	add_child(_map)
	_cell = BloodCell.new()
	_map.add_child(_cell)

	_drop_area = MapDropArea.new()
	_drop_area.position = Vector2.ZERO
	_drop_area.size = CirculationData.MAP_SIZE
	_drop_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_area.station_dropped.connect(_on_station_dropped)
	add_child(_drop_area)

	_build_side_panel()
	_set_mode(false)
	_step_btn.call_deferred("grab_focus")


# ---------------------------------------------------------------- input

func _register_actions() -> void:
	_add_key_action("circ_play", [KEY_SPACE])
	_add_key_action("circ_step", [KEY_RIGHT, KEY_N])
	_add_key_action("circ_reset", [KEY_R])
	_add_key_action("circ_mode", [KEY_M])


func _add_key_action(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k: Key in keys:
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.is_echo():
		return
	if event.is_action_pressed("circ_mode"):
		toggle_mode()
	elif event.is_action_pressed("circ_reset"):
		if quiz_mode:
			restart_quiz()
		else:
			reset_cell()
	elif event.is_action_pressed("circ_step"):
		if quiz_mode:
			return
		step()
	elif event.is_action_pressed("circ_play"):
		if quiz_mode:
			return
		toggle_play()
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- theme

func _box(bg_color: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _make_check_icon(checked: bool) -> ImageTexture:
	var s: int = 26
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill: Color = COL_BLUE if checked else Color.WHITE
	for y: int in range(2, s - 2):
		for x: int in range(2, s - 2):
			var edge: bool = x < 4 or y < 4 or x >= s - 4 or y >= s - 4
			img.set_pixel(x, y, COL_BLUE if edge else fill)
	if checked:
		for i: int in range(5):
			for w: int in range(3):
				img.set_pixel(6 + i, 13 + i + w - 1, Color.WHITE)
		for i: int in range(9):
			for w: int in range(3):
				img.set_pixel(10 + i, 17 - i + w - 1, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _build_theme() -> Theme:
	var th: Theme = Theme.new()
	th.default_font_size = 18
	for ctrl: String in ["Label", "Button", "CheckBox"]:
		th.set_color("font_color", ctrl, COL_TEXT)
	for ctrl: String in ["Button", "CheckBox"]:
		th.set_color("font_hover_color", ctrl, COL_TEXT)
		th.set_color("font_focus_color", ctrl, COL_TEXT)
		th.set_color("font_pressed_color", ctrl, COL_TEXT)
		th.set_color("font_hover_pressed_color", ctrl, COL_TEXT)
		th.set_color("font_disabled_color", ctrl, COL_MUTED)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_stylebox("normal", "Button", _box(Color("#ece8f4"), Color("#cfc8de"), 2, 10, 10))
	th.set_stylebox("hover", "Button", _box(Color("#e0dbee"), COL_BLUE, 2, 10, 10))
	th.set_stylebox("pressed", "Button", _box(COL_BLUE, COL_BLUE, 2, 10, 10))
	th.set_stylebox("hover_pressed", "Button", _box(COL_BLUE, COL_BLUE, 2, 10, 10))
	th.set_stylebox("disabled", "Button", _box(Color("#e6e3eb"), Color("#d8d4df"), 2, 10, 10))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), COL_RED, 3, 10, 10)
	focus.draw_center = false
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("focus", "CheckBox", focus)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		th.set_stylebox(st, "CheckBox", empty)
	th.set_icon("checked", "CheckBox", _make_check_icon(true))
	th.set_icon("unchecked", "CheckBox", _make_check_icon(false))
	th.set_icon("checked_disabled", "CheckBox", _make_check_icon(true))
	th.set_icon("unchecked_disabled", "CheckBox", _make_check_icon(false))
	th.set_constant("h_separation", "CheckBox", 10)
	th.set_stylebox("panel", "PanelContainer", _box(COL_PANEL, Color("#e2dcec"), 2, 16, 14))
	var track: StyleBoxFlat = _box(Color("#d6d0e0"), Color(0, 0, 0, 0), 0, 4, 0)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	th.set_stylebox("slider", "HSlider", track)
	var area: StyleBoxFlat = _box(COL_BLUE, Color(0, 0, 0, 0), 0, 4, 0)
	area.content_margin_top = 4.0
	area.content_margin_bottom = 4.0
	th.set_stylebox("grabber_area", "HSlider", area)
	th.set_stylebox("grabber_area_highlight", "HSlider", area)
	return th


# ---------------------------------------------------------------- layout

func _make_button(label_text: String) -> Button:
	var b: Button = Button.new()
	b.text = label_text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _make_label(label_text: String, font_size: int, color: Color = COL_TEXT) -> Label:
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _build_side_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(SIDE_X + 8.0, 8.0)
	panel.size = Vector2(SIDE_W - 16.0, CirculationData.MAP_SIZE.y - 16.0)
	add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title: Label = _make_label("Journey of a Red Blood Cell", 28, COL_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	var group: ButtonGroup = ButtonGroup.new()
	_explore_btn = _make_button("Explore")
	_quiz_btn = _make_button("Quiz")
	for b: Button in [_explore_btn, _quiz_btn]:
		b.toggle_mode = true
		b.button_group = group
		tabs.add_child(b)
	_explore_btn.set_pressed_no_signal(true)
	_explore_btn.toggled.connect(_on_explore_tab_toggled)
	_quiz_btn.toggled.connect(_on_quiz_tab_toggled)

	_explore_box = VBoxContainer.new()
	_explore_box.add_theme_constant_override("separation", 10)
	root.add_child(_explore_box)
	_build_explore()

	_quiz_box = VBoxContainer.new()
	_quiz_box.add_theme_constant_override("separation", 10)
	root.add_child(_quiz_box)
	_build_quiz()


func _build_explore() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_explore_box.add_child(row)
	_step_btn = _make_button("Step >")
	_play_btn = _make_button("Play")
	_reset_btn = _make_button("Reset")
	for b: Button in [_step_btn, _play_btn, _reset_btn]:
		row.add_child(b)
	_step_btn.pressed.connect(step)
	_play_btn.pressed.connect(toggle_play)
	_reset_btn.pressed.connect(reset_cell)

	var srow: HBoxContainer = HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	_explore_box.add_child(srow)
	_speed_label = _make_label("Speed: 140", 18)
	_speed_label.custom_minimum_size = Vector2(110, 44)
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	srow.add_child(_speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 60.0
	_speed_slider.max_value = 320.0
	_speed_slider.step = 10.0
	_speed_slider.value = speed
	_speed_slider.custom_minimum_size = Vector2(150, 44)
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.focus_mode = Control.FOCUS_ALL
	_speed_slider.value_changed.connect(_on_speed_changed)
	srow.add_child(_speed_slider)
	_loop_check = CheckBox.new()
	_loop_check.text = "Loop forever"
	_loop_check.custom_minimum_size = Vector2(44, 44)
	_loop_check.focus_mode = Control.FOCUS_ALL
	_loop_check.toggled.connect(_on_loop_toggled)
	srow.add_child(_loop_check)

	var info_panel: PanelContainer = PanelContainer.new()
	_explore_box.add_child(info_panel)
	var ibox: VBoxContainer = VBoxContainer.new()
	ibox.add_theme_constant_override("separation", 6)
	info_panel.add_child(ibox)
	_station_label = _make_label("", 28, COL_BLUE)
	ibox.add_child(_station_label)
	_circuit_label = _make_label("", 16, COL_MUTED)
	ibox.add_child(_circuit_label)
	_info_label = _make_label("", 18)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(0, 80)
	ibox.add_child(_info_label)
	var orow: HBoxContainer = HBoxContainer.new()
	orow.add_theme_constant_override("separation", 10)
	ibox.add_child(orow)
	var olbl: Label = _make_label("Oxygen:", 18, COL_MUTED)
	orow.add_child(olbl)
	_o2_swatch = ColorRect.new()
	_o2_swatch.custom_minimum_size = Vector2(28, 28)
	orow.add_child(_o2_swatch)
	_o2_word = _make_label("", 18)
	orow.add_child(_o2_word)

	var route_title: Label = _make_label("Route", 18, COL_MUTED)
	_explore_box.add_child(route_title)
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	_explore_box.add_child(cols)
	for c: int in range(2):
		var colbox: VBoxContainer = VBoxContainer.new()
		colbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colbox.add_theme_constant_override("separation", 2)
		cols.add_child(colbox)
		for r: int in range(5):
			var idx: int = c * 5 + r
			var line: HBoxContainer = HBoxContainer.new()
			var marker: Label = _make_label("", 18, COL_RED)
			marker.custom_minimum_size = Vector2(22, 0)
			var nm: Label = _make_label("%d. %s" % [idx + 1, CirculationData.station_name(idx)], 18)
			line.add_child(marker)
			line.add_child(nm)
			colbox.add_child(line)
			_route_markers.append(marker)
			_route_names.append(nm)


func _build_quiz() -> void:
	_prompt_label = _make_label("", 22, COL_BLUE)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size = Vector2(0, 62)
	_quiz_box.add_child(_prompt_label)
	_feedback_label = _make_label("", 18)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.custom_minimum_size = Vector2(0, 90)
	_quiz_box.add_child(_feedback_label)
	_stats_label = _make_label("", 18, COL_MUTED)
	_quiz_box.add_child(_stats_label)
	_card_grid = GridContainer.new()
	_card_grid.columns = 2
	_card_grid.add_theme_constant_override("h_separation", 10)
	_card_grid.add_theme_constant_override("v_separation", 8)
	_quiz_box.add_child(_card_grid)
	_try_again_btn = _make_button("Try Again")
	_try_again_btn.pressed.connect(restart_quiz)
	_try_again_btn.visible = false
	_quiz_box.add_child(_try_again_btn)


# ---------------------------------------------------------------- modes

func toggle_mode() -> void:
	_set_mode(not quiz_mode)


func _on_explore_tab_toggled(on: bool) -> void:
	if on and not _syncing:
		_set_mode(false)


func _on_quiz_tab_toggled(on: bool) -> void:
	if on and not _syncing:
		_set_mode(true)


func _set_mode(want_quiz: bool) -> void:
	quiz_mode = want_quiz
	_syncing = true
	_explore_btn.set_pressed_no_signal(not want_quiz)
	_quiz_btn.set_pressed_no_signal(want_quiz)
	_syncing = false
	_explore_box.visible = not want_quiz
	_quiz_box.visible = want_quiz
	_drop_area.mouse_filter = Control.MOUSE_FILTER_STOP if want_quiz else Control.MOUSE_FILTER_IGNORE
	if want_quiz:
		restart_quiz()
	else:
		_map.set_labels_visible(true)
		reset_cell()
		_step_btn.call_deferred("grab_focus")


func _place_cell_at_start() -> void:
	_moving = false
	_playing = false
	_dwell = 0.0
	_t = 0.0
	current_station = CirculationData.START_STATION
	_cell.position = CirculationData.station_pos(current_station)
	_cell.oxygen = CirculationData.station_o2(current_station)
	_map.set_highlight(current_station)


# ---------------------------------------------------------------- explore

func reset_cell() -> void:
	if quiz_mode:
		return
	_place_cell_at_start()
	_update_info()
	_refresh_buttons()


func step() -> void:
	if quiz_mode or _moving or _playing:
		return
	_begin_move()


func toggle_play() -> void:
	if quiz_mode:
		return
	if _playing:
		_playing = false
	else:
		_playing = true
		_arrivals_in_play = 0
		_dwell = 0.0
	_refresh_buttons()


func _on_speed_changed(value: float) -> void:
	speed = value
	_speed_label.text = "Speed: %d" % int(value)


func _on_loop_toggled(on: bool) -> void:
	loop_forever = on


func _refresh_buttons() -> void:
	_play_btn.text = "Pause" if _playing else "Play"
	_step_btn.disabled = _moving or _playing


func _update_info() -> void:
	var st: Dictionary = CirculationData.STATIONS[current_station]
	_station_label.text = st["name"]
	var circuit: String = st["circuit"]
	match circuit:
		"lung":
			_circuit_label.text = "Lung Circuit"
		"body":
			_circuit_label.text = "Body Circuit"
		_:
			_circuit_label.text = "Heart"
	_info_label.text = st["info"]
	for i: int in range(CirculationData.STATION_COUNT):
		var here: bool = i == current_station
		_route_markers[i].text = ">" if here else ""
		_route_names[i].add_theme_color_override("font_color", COL_RED if here else COL_TEXT)
	_update_oxygen()


func _oxygen_word() -> String:
	var seg: int = _moving_segment if _moving else -1
	if seg == -1:
		if current_station == CirculationData.LUNG_CAPILLARIES:
			return "Picking up oxygen…"
		if current_station == CirculationData.BODY_CAPILLARIES:
			return "Dropping off oxygen…"
	if seg == 2 or seg == 3:
		return "Picking up oxygen…"
	if seg == 7 or seg == 8:
		return "Dropping off oxygen…"
	return "Oxygen-rich" if _cell.oxygen >= 0.5 else "Oxygen-poor"


func _update_oxygen() -> void:
	_o2_swatch.color = CirculationData.o2_to_color(_cell.oxygen)
	_o2_word.text = _oxygen_word()


# ---------------------------------------------------------------- movement

func _begin_move() -> void:
	_moving = true
	_moving_segment = current_station
	_t = 0.0
	_map.set_highlight(-1)
	_refresh_buttons()
	_update_oxygen()


func _process(delta: float) -> void:
	if _moving:
		_advance(delta)
	elif _playing and not quiz_mode:
		_dwell -= delta
		if _dwell <= 0.0:
			_begin_move()


func _advance(delta: float) -> void:
	_t += speed * delta / CirculationData.segment_length(_moving_segment)
	if _t >= 1.0:
		_arrive()
		return
	_cell.position = CirculationData.point_on_segment(_moving_segment, _t)
	_cell.oxygen = CirculationData.o2_on_segment(_moving_segment, _t)
	if not quiz_mode:
		_update_oxygen()


func _arrive() -> void:
	_moving = false
	current_station = CirculationData.next_station(_moving_segment)
	_cell.position = CirculationData.station_pos(current_station)
	_cell.oxygen = CirculationData.station_o2(current_station)
	_cell.pop()
	_map.set_highlight(current_station)
	if quiz_mode:
		_on_quiz_arrived()
		return
	_update_info()
	if _playing:
		_arrivals_in_play += 1
		_dwell = DWELL_TIME
		if _arrivals_in_play >= CirculationData.STATION_COUNT and not loop_forever:
			_playing = false
			_arrivals_in_play = 0
	_refresh_buttons()


# ---------------------------------------------------------------- quiz

func restart_quiz() -> void:
	_place_cell_at_start()
	quiz_complete = false
	mistakes = 0
	steps_done = 0
	_map.set_labels_visible(false)
	_map.hide_all_labels()
	_map.reveal_label(CirculationData.RIGHT_ATRIUM)
	_try_again_btn.visible = false
	for c: StationCard in _cards:
		_card_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	var order: Array[int] = []
	for i: int in range(CirculationData.STATION_COUNT):
		order.append(i)
	order.shuffle()
	for idx: int in order:
		var card: StationCard = StationCard.new()
		card.setup(idx)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.selected.connect(_submit_answer)
		_card_grid.add_child(card)
		_cards.append(card)
	_prompt_label.text = "The cell is in the Right Atrium. Drag the NEXT station onto the map!"
	_feedback_label.text = "Tap a card, or press Enter on it, if you cannot drag."
	_feedback_label.add_theme_color_override("font_color", COL_MUTED)
	_update_stats()
	_focus_first_card()


func _update_stats() -> void:
	_stats_label.text = "Progress: %d / %d     Mistakes: %d" % [steps_done, CirculationData.STATION_COUNT, mistakes]


func _focus_first_card() -> void:
	call_deferred("_do_focus_first_card")


func _do_focus_first_card() -> void:
	if not quiz_mode:
		return
	for c: StationCard in _cards:
		if is_instance_valid(c) and c.is_inside_tree() and not c.disabled:
			c.grab_focus()
			return


func _on_station_dropped(index: int) -> void:
	_submit_answer(index)


func _find_card(index: int) -> StationCard:
	for c: StationCard in _cards:
		if c.station_index == index:
			return c
	return null


func _submit_answer(index: int) -> void:
	if not quiz_mode or _moving or quiz_complete:
		return
	var expected: int = CirculationData.next_station(current_station)
	var card: StationCard = _find_card(index)
	if index == expected:
		steps_done += 1
		if card != null:
			card.mark_used()
		_feedback_label.text = "Correct! Off we go to the %s…" % CirculationData.station_name(index)
		_feedback_label.add_theme_color_override("font_color", COL_GREEN)
		_update_stats()
		_begin_move()
	else:
		mistakes += 1
		_feedback_label.text = "Not quite — where does blood go after the %s?" % CirculationData.station_name(current_station)
		_feedback_label.add_theme_color_override("font_color", COL_RED)
		_update_stats()
		if card != null:
			card.shake()


func _on_quiz_arrived() -> void:
	_map.reveal_label(current_station)
	_update_stats()
	if steps_done >= CirculationData.STATION_COUNT:
		quiz_complete = true
		_prompt_label.text = "You completed the double loop! Mistakes: %d" % mistakes
		_feedback_label.text = "Great work! The blood is back in the Right Atrium, ready for another trip."
		_feedback_label.add_theme_color_override("font_color", COL_GREEN)
		for c: StationCard in _cards:
			c.disabled = true
		_try_again_btn.visible = true
		_try_again_btn.call_deferred("grab_focus")
		return
	_prompt_label.text = "The cell is in the %s. Drag the NEXT station onto the map!" % CirculationData.station_name(current_station)
	var info: String = CirculationData.STATIONS[current_station]["info"]
	_feedback_label.text = "Correct! %s" % info
	_feedback_label.add_theme_color_override("font_color", COL_GREEN)
	_focus_first_card()
