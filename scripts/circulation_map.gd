class_name CirculationMap
extends Node2D
## Draws the circulation diagram: the artwork background (art/circulatory_background.png),
## station markers, the current-station highlight and the station names in the label boxes.
## Map-local space == screen (680 x 720). Geometry comes from CirculationData.

const LABEL_FONT_SIZE: int = 20
const QUESTION_FONT_SIZE: int = 30

const COL_TEXT: Color = Color(0.11, 0.1, 0.2)
const COL_DOT: Color = Color(0.12, 0.1, 0.18)
const COL_HIGHLIGHT: Color = Color(1.0, 0.55, 0.0)
const COL_QUESTION: Color = Color(0.55, 0.0, 0.62)
## Matches the label boxes in the artwork (pink fill, magenta border).
const COL_BOX_FILL: Color = Color(1.0, 0.804, 0.914)
const COL_BOX_BORDER: Color = Color(0.835, 0.0, 0.976)

var _all_labels: bool = true
var _revealed: Array[bool] = []
var _highlight: int = -1
var _pulse: float = 0.0

var _font: Font
var _background: Texture2D
var _label_lines: Array[PackedStringArray] = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_background = load(CirculationData.BACKGROUND_PATH) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_revealed.resize(CirculationData.STATION_COUNT)
	_revealed.fill(false)
	_label_lines.clear()
	for i: int in range(CirculationData.STATION_COUNT):
		_label_lines.append(_wrap_name(CirculationData.station_name(i)))
	set_process(false)
	queue_redraw()


## Play mode: true shows every station name. Quiz mode: false shows only revealed names ("?" otherwise).
func set_labels_visible(on: bool) -> void:
	_all_labels = on
	queue_redraw()


## Quiz: show the real name of one station.
func reveal_label(index: int) -> void:
	if index < 0 or index >= _revealed.size():
		return
	_revealed[index] = true
	queue_redraw()


## Quiz reset: every box shows "?".
func hide_all_labels() -> void:
	_all_labels = false
	_revealed.fill(false)
	queue_redraw()


## -1 = none. Otherwise draws a pulsing ring around that station and outlines its label box.
func set_highlight(index: int) -> void:
	if index < 0 or index >= CirculationData.STATION_COUNT:
		_highlight = -1
	else:
		_highlight = index
	_pulse = 0.0
	set_process(_highlight >= 0)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


static func _wrap_name(full_name: String) -> PackedStringArray:
	var mid: float = float(full_name.length()) * 0.5
	var best: int = -1
	var best_dist: float = 1000.0
	for i: int in range(full_name.length()):
		if full_name[i] == " ":
			var dist: float = absf(float(i) - mid)
			if dist < best_dist:
				best_dist = dist
				best = i
	if best < 0:
		return PackedStringArray([full_name])
	return PackedStringArray([full_name.substr(0, best), full_name.substr(best + 1)])


# --------------------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------------------

func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, CirculationData.MAP_SIZE), Color.WHITE)
	if _background != null:
		draw_texture_rect(_background, Rect2(Vector2.ZERO, CirculationData.BACKGROUND_SIZE), false)
	_draw_extra_box()
	_draw_stations()
	_draw_labels()


## The artwork has no box for the Capillaries of Body, so draw one (with an arrow) in the same style.
func _draw_extra_box() -> void:
	var idx: int = CirculationData.DRAWN_BOX_STATION
	var box: Rect2 = CirculationData.LABEL_BOXES[idx]
	var target: Vector2 = CirculationData.station_pos(idx)
	var start: Vector2 = Vector2(box.position.x, box.get_center().y)
	var dir: Vector2 = (target - start).normalized()
	var tip: Vector2 = target - dir * 10.0
	draw_line(start, tip - dir * 8.0, COL_BOX_BORDER, 3.0, true)
	var side: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 + side * 6.0, tip - dir * 12.0 - side * 6.0]), COL_BOX_BORDER)
	draw_rect(box, COL_BOX_FILL)
	draw_rect(box, COL_BOX_BORDER, false, 3.4)


func _draw_stations() -> void:
	for i: int in range(CirculationData.STATION_COUNT):
		var p: Vector2 = CirculationData.station_pos(i)
		draw_circle(p, 5.5, Color.WHITE, true, -1.0, true)
		draw_circle(p, 3.5, COL_DOT, true, -1.0, true)
	if _highlight >= 0:
		var hp: Vector2 = CirculationData.station_pos(_highlight)
		var wave: float = 0.5 + 0.5 * sin(_pulse * 6.0)
		var ring_r: float = 19.0 + 5.0 * wave
		draw_arc(hp, ring_r + 5.0, 0.0, TAU, 48, Color(COL_HIGHLIGHT.r, COL_HIGHLIGHT.g, COL_HIGHLIGHT.b, 0.35 * (1.0 - wave)), 4.0, true)
		draw_arc(hp, ring_r, 0.0, TAU, 48, COL_HIGHLIGHT, 4.0, true)


func _draw_labels() -> void:
	var line_h: float = _font.get_height(LABEL_FONT_SIZE)
	var ascent: float = _font.get_ascent(LABEL_FONT_SIZE)
	for i: int in range(CirculationData.STATION_COUNT):
		var box: Rect2 = CirculationData.LABEL_BOXES[i]
		if i == _highlight:
			draw_rect(box.grow(2.0), COL_HIGHLIGHT, false, 4.0)
		var known: bool = _all_labels or _revealed[i]
		if known:
			var lines: PackedStringArray = _label_lines[i]
			var top: float = box.get_center().y - line_h * float(lines.size()) * 0.5
			for li: int in range(lines.size()):
				var baseline: float = top + float(li) * line_h + ascent
				draw_string(_font, Vector2(box.position.x, baseline), lines[li], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, LABEL_FONT_SIZE, COL_TEXT)
		else:
			var q_ascent: float = _font.get_ascent(QUESTION_FONT_SIZE)
			var q_h: float = _font.get_height(QUESTION_FONT_SIZE)
			var baseline_q: float = box.get_center().y - q_h * 0.5 + q_ascent
			draw_string(_font, Vector2(box.position.x, baseline_q), "?", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, QUESTION_FONT_SIZE, COL_QUESTION)
