class_name CirculationMap
extends Node2D
## Draws the whole circulation diagram (lungs, heart, body, vessels, labels) with _draw().
## Vessels follow CirculationData.SEGMENTS exactly. Map-local space == screen (680 x 720).

const VESSEL_WIDTH: float = 22.0
const OUTLINE_EXTRA: float = 3.5
const PIECE_LENGTH: float = 14.0
const LABEL_FONT_SIZE: int = 18
const CAPTION_FONT_SIZE: int = 21
const LEGEND_FONT_SIZE: int = 16
const SPLIT_X: float = 340.0

const COL_BG: Color = Color(0.957, 0.945, 0.969)
const COL_LUNG_ZONE: Color = Color(0.925, 0.91, 0.97)
const COL_BODY_ZONE: Color = Color(0.985, 0.93, 0.935)
const COL_VESSEL_OUTLINE: Color = Color(0.34, 0.28, 0.46)
const COL_TEXT: Color = Color(0.11, 0.1, 0.2)
const COL_CAPTION: Color = Color(0.36, 0.3, 0.55)
const COL_DOT: Color = Color(0.12, 0.1, 0.18)
const COL_HIGHLIGHT: Color = Color(1.0, 0.72, 0.0)
const COL_LUNG_OUTLINE: Color = Color(0.93, 0.72, 0.0)
const COL_BODY_OUTLINE: Color = Color(0.15, 0.6, 0.3)
const COL_LUNG_FILL: Color = Color(0.96, 0.76, 0.84)
const COL_LUNG_EDGE: Color = Color(0.82, 0.5, 0.64)
const COL_LUNG_CAP: Color = Color(0.86, 0.3, 0.42, 0.7)

## Heart outline control points (closed Catmull-Rom spline).
static var HEART_CTRL: PackedVector2Array = PackedVector2Array([
	Vector2(226, 345), Vector2(241, 305), Vector2(289, 288), Vector2(336, 302),
	Vector2(382, 288), Vector2(431, 302), Vector2(454, 345), Vector2(451, 408),
	Vector2(426, 468), Vector2(379, 508), Vector2(339, 522), Vector2(296, 505),
	Vector2(254, 465), Vector2(229, 405),
])

## Left lung lobe control points (right lobe is the mirror image about x = 340).
static var LOBE_CTRL: PackedVector2Array = PackedVector2Array([
	Vector2(205, 92), Vector2(255, 78), Vector2(300, 90), Vector2(320, 135),
	Vector2(314, 185), Vector2(282, 212), Vector2(232, 210), Vector2(192, 186),
	Vector2(180, 135),
])

## Label block anchor per station: x = edge of the block nearest the marker, y = vertical centre.
const LABEL_ANCHORS: Array[Vector2] = [
	Vector2(232, 370),
	Vector2(240, 475),
	Vector2(135, 190),
	Vector2(385, 50),
	Vector2(545, 180),
	Vector2(468, 375),
	Vector2(468, 445),
	Vector2(568, 505),
	Vector2(372, 686),
	Vector2(150, 255),
]

var _all_labels: bool = true
var _revealed: Array[bool] = []
var _highlight: int = -1
var _pulse: float = 0.0

var _font: Font
var _box_style: StyleBoxFlat
var _pieces: Array[Dictionary] = []
var _label_lines: Array[PackedStringArray] = []
var _heart_poly: PackedVector2Array = PackedVector2Array()
var _heart_blue: Array[PackedVector2Array] = []
var _heart_red: Array[PackedVector2Array] = []
var _lobes: Array[PackedVector2Array] = []
var _net_left: PackedVector2Array = PackedVector2Array()
var _net_right: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_box_style = StyleBoxFlat.new()
	_revealed.resize(CirculationData.STATION_COUNT)
	_revealed.fill(false)
	_build_geometry()
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


## Quiz reset: every marker shows "?".
func hide_all_labels() -> void:
	_all_labels = false
	_revealed.fill(false)
	queue_redraw()


## -1 = none. Otherwise draws a pulsing ring around that station marker.
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


# --------------------------------------------------------------------------------------
# Geometry preparation
# --------------------------------------------------------------------------------------

func _build_geometry() -> void:
	# Vessel pieces (split into sub-pieces where oxygen changes, for a gradient look).
	_pieces.clear()
	for seg: int in range(CirculationData.SEGMENTS.size()):
		var o2: Vector2 = CirculationData.SEGMENT_O2[seg]
		var outline: Color = _circuit_outline(CirculationData.SEGMENT_CIRCUIT[seg])
		var count: int = 1
		if not is_equal_approx(o2.x, o2.y):
			count = maxi(2, ceili(CirculationData.segment_length(seg) / PIECE_LENGTH))
		for k: int in range(count):
			var f0: float = float(k) / float(count)
			var f1: float = float(k + 1) / float(count)
			var mean_o2: float = lerpf(o2.x, o2.y, (f0 + f1) * 0.5)
			var col: Color = CirculationData.o2_to_color(mean_o2).lerp(Color.WHITE, 0.35)
			_pieces.append({"pts": _sub_polyline(seg, f0, f1), "color": col, "outline": outline})

	# Heart and its two halves.
	_heart_poly = _closed_spline(HEART_CTRL, 8)
	var left_rect: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(SPLIT_X, 0), Vector2(SPLIT_X, 720), Vector2(0, 720)])
	var right_rect: PackedVector2Array = PackedVector2Array([Vector2(SPLIT_X, 0), Vector2(680, 0), Vector2(680, 720), Vector2(SPLIT_X, 720)])
	_heart_blue = Geometry2D.intersect_polygons(_heart_poly, left_rect)
	_heart_red = Geometry2D.intersect_polygons(_heart_poly, right_rect)

	# Lungs.
	var left_lobe: PackedVector2Array = _closed_spline(LOBE_CTRL, 8)
	var right_lobe: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in left_lobe:
		right_lobe.append(Vector2(2.0 * SPLIT_X - p.x, p.y))
	_lobes = [left_lobe, right_lobe]

	# Body capillary bed (left half blue-ish, right half red-ish).
	_net_left = PackedVector2Array([
		Vector2(150, 592), Vector2(240, 604), Vector2(SPLIT_X, 608),
		Vector2(SPLIT_X, 714), Vector2(215, 696), Vector2(160, 660),
	])
	for p: Vector2 in _net_left:
		_net_right.append(Vector2(2.0 * SPLIT_X - p.x, p.y))
	_net_right.reverse()

	# Label text, wrapped onto two lines at the space nearest the middle.
	_label_lines.clear()
	for i: int in range(CirculationData.STATION_COUNT):
		_label_lines.append(_wrap_name(CirculationData.station_name(i)))


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


static func _closed_spline(ctrl: PackedVector2Array, samples: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = ctrl.size()
	for i: int in range(n):
		var p0: Vector2 = ctrl[(i - 1 + n) % n]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n]
		for s: int in range(samples):
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(samples)))
	return out


## Part of SEGMENTS[seg] between progress f0 and f1 (0..1, by distance).
static func _sub_polyline(seg: int, f0: float, f1: float) -> PackedVector2Array:
	var pts: PackedVector2Array = CirculationData.SEGMENTS[seg]
	var total: float = CirculationData.segment_length(seg)
	var d0: float = f0 * total
	var d1: float = f1 * total
	var out: PackedVector2Array = PackedVector2Array()
	out.append(CirculationData.point_on_segment(seg, f0))
	var acc: float = 0.0
	for i: int in range(pts.size() - 1):
		acc += pts[i].distance_to(pts[i + 1])
		if acc > d0 + 0.01 and acc < d1 - 0.01:
			out.append(pts[i + 1])
	out.append(CirculationData.point_on_segment(seg, f1))
	return out


static func _ellipse(center: Vector2, rx: float, ry: float, count: int = 32) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(count):
		var a: float = TAU * float(i) / float(count)
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _circuit_outline(circuit: String) -> Color:
	match circuit:
		"lung":
			return COL_LUNG_OUTLINE
		"body":
			return COL_BODY_OUTLINE
	return COL_VESSEL_OUTLINE


static func _lighten(c: Color, amount: float) -> Color:
	return c.lerp(Color.WHITE, amount)


func _o2_light(o2: float) -> Color:
	return _lighten(CirculationData.o2_to_color(o2), 0.35)


# --------------------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------------------

func _box(rect: Rect2, fill: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	_box_style.bg_color = fill
	_box_style.set_corner_radius_all(radius)
	_box_style.border_color = border
	_box_style.set_border_width_all(border_w)
	_box_style.anti_aliasing = true
	draw_style_box(_box_style, rect)


func _draw() -> void:
	if _font == null:
		return
	_draw_background()
	_draw_lungs()
	_draw_body()
	_draw_heart()
	_draw_vessels()
	_draw_stations()
	_draw_labels()
	_draw_legend()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, CirculationData.MAP_SIZE), COL_BG)
	_box(Rect2(10, 8, 660, 280), COL_LUNG_ZONE, 26, COL_LUNG_OUTLINE, 3)
	_box(Rect2(10, 296, 660, 414), COL_BODY_ZONE, 26, COL_BODY_OUTLINE, 3)
	draw_string(_font, Vector2(30, 44), "Lung Circuit", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT_SIZE, COL_CAPTION)
	draw_string(_font, Vector2(125, 528), "Body Circuit", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT_SIZE, Color(0.6, 0.28, 0.36))


func _draw_lungs() -> void:
	for li: int in range(_lobes.size()):
		var poly: PackedVector2Array = _lobes[li]
		var is_left: bool = li == 0
		# Both lungs are the same pink: oxygen is picked up in BOTH lungs.
		draw_colored_polygon(poly, COL_LUNG_FILL)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, COL_LUNG_EDGE, 2.5, true)

		var cx: float = 250.0 if is_left else 430.0
		var cap: Color = COL_LUNG_CAP
		# Wavy horizontal capillaries.
		for r: int in range(7):
			var y: float = 100.0 + float(r) * 17.0
			var rel: float = (y - 150.0) / 68.0
			var hw: float = 54.0 * sqrt(maxf(0.0, 1.0 - rel * rel))
			if hw < 8.0:
				continue
			var pts: PackedVector2Array = PackedVector2Array()
			var x: float = cx - hw
			while x <= cx + hw:
				pts.append(Vector2(x, y + 3.5 * sin((x - cx) * 0.22 + float(r) * 1.3)))
				x += 4.0
			draw_polyline(pts, cap, 2.2, true)
		# Wavy vertical connectors.
		for c: int in range(5):
			var vx: float = cx - 40.0 + float(c) * 20.0
			var relx: float = (vx - cx) / 62.0
			var hh: float = 56.0 * sqrt(maxf(0.0, 1.0 - relx * relx))
			var vpts: PackedVector2Array = PackedVector2Array()
			var vy: float = 150.0 - hh
			while vy <= 150.0 + hh:
				vpts.append(Vector2(vx + 3.0 * sin(vy * 0.2 + float(c) * 1.7), vy))
				vy += 4.0
			if vpts.size() >= 2:
				draw_polyline(vpts, cap, 1.8, true)


func _draw_body() -> void:
	# Capillary bed background.
	draw_colored_polygon(_net_left, Color(0.62, 0.68, 0.95, 0.4))
	draw_colored_polygon(_net_right, Color(0.97, 0.6, 0.68, 0.4))
	# Capillary net: wavy lines coloured by oxygen (blue left, red right).
	for r: int in range(5):
		var y: float = 622.0 + float(r) * 16.0
		var hw: float = lerpf(170.0, 110.0, (y - 600.0) / 100.0)
		var pts: PackedVector2Array = PackedVector2Array()
		var cols: PackedColorArray = PackedColorArray()
		var x: float = SPLIT_X - hw
		while x <= SPLIT_X + hw:
			pts.append(Vector2(x, y + 3.5 * sin(x * 0.17 + float(r) * 1.1)))
			var o2: float = clampf(0.5 + (x - SPLIT_X) / (2.0 * hw) * 0.9, 0.0, 1.0)
			var c: Color = CirculationData.o2_to_color(o2)
			c.a = 0.8
			cols.append(c)
			x += 5.0
		draw_polyline_colors(pts, cols, 2.2, true)
	for c: int in range(9):
		var vx: float = 190.0 + float(c) * 37.5
		var pts2: PackedVector2Array = PackedVector2Array()
		var cols2: PackedColorArray = PackedColorArray()
		var vy: float = 606.0
		var bottom: float = 700.0 - absf(vx - SPLIT_X) * 0.12
		while vy <= bottom:
			pts2.append(Vector2(vx + 3.5 * sin(vy * 0.19 + float(c)), vy))
			var o2b: float = clampf(0.5 + (vx - SPLIT_X) / 340.0, 0.0, 1.0)
			var cc: Color = CirculationData.o2_to_color(o2b)
			cc.a = 0.75
			cols2.append(cc)
			vy += 5.0
		if pts2.size() >= 2:
			draw_polyline_colors(pts2, cols2, 1.8, true)

	# Grey person.
	var grey: Color = Color(0.56, 0.57, 0.63, 0.85)
	_box(Rect2(315, 640, 25, 70), grey, 11)
	_box(Rect2(340, 640, 25, 70), grey, 11)
	_box(Rect2(291, 576, 19, 68), grey, 9)
	_box(Rect2(370, 576, 19, 68), grey, 9)
	_box(Rect2(311, 570, 58, 84), grey, 18)
	_box(Rect2(333, 558, 14, 20), grey, 5)
	draw_circle(Vector2(340, 548), 15.0, grey, true, -1.0, true)


func _draw_heart() -> void:
	draw_colored_polygon(_heart_poly, Color(0.97, 0.82, 0.86))
	for poly: PackedVector2Array in _heart_blue:
		draw_colored_polygon(poly, Color(0.68, 0.74, 0.96))
	for poly: PackedVector2Array in _heart_red:
		draw_colored_polygon(poly, Color(0.98, 0.66, 0.72))
	# Inner chambers.
	var blue_c: Color = Color(0.4, 0.48, 0.9, 0.9)
	var red_c: Color = Color(0.92, 0.36, 0.44, 0.9)
	draw_colored_polygon(_ellipse(Vector2(282, 352), 38.0, 36.0), blue_c)
	draw_colored_polygon(_ellipse(Vector2(292, 450), 40.0, 46.0), blue_c)
	draw_colored_polygon(_ellipse(Vector2(400, 350), 38.0, 36.0), red_c)
	draw_colored_polygon(_ellipse(Vector2(390, 450), 40.0, 46.0), red_c)
	# Septum.
	draw_line(Vector2(SPLIT_X, 312), Vector2(SPLIT_X, 512), Color(0.55, 0.42, 0.62, 0.7), 3.0, true)
	var closed: PackedVector2Array = _heart_poly.duplicate()
	closed.append(_heart_poly[0])
	draw_polyline(closed, Color(0.7, 0.42, 0.55), 3.0, true)
	draw_string(_font, Vector2(320, 512), "Heart", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.3, 0.45))


func _draw_vessels() -> void:
	var outline_w: float = VESSEL_WIDTH + OUTLINE_EXTRA * 2.0
	for piece: Dictionary in _pieces:
		var pts: PackedVector2Array = piece["pts"]
		var oc: Color = piece["outline"]
		draw_polyline(pts, oc, outline_w, true)
		draw_circle(pts[0], outline_w * 0.5, oc, true, -1.0, true)
		draw_circle(pts[pts.size() - 1], outline_w * 0.5, oc, true, -1.0, true)
	for piece: Dictionary in _pieces:
		var pts: PackedVector2Array = piece["pts"]
		var col: Color = piece["color"]
		draw_polyline(pts, col, VESSEL_WIDTH, true)
		draw_circle(pts[0], VESSEL_WIDTH * 0.5, col, true, -1.0, true)
		draw_circle(pts[pts.size() - 1], VESSEL_WIDTH * 0.5, col, true, -1.0, true)
	# The aorta crosses OVER the pulmonary veins: redraw that stretch (outline + fill, flat
	# ends) on top so the two vessels read as separate tubes instead of a T-junction.
	# The fill is drawn longer than the outline so the outline's flat ends are hidden.
	var b0: Vector2 = CirculationData.AORTA_BRIDGE[0]
	var b1: Vector2 = CirculationData.AORTA_BRIDGE[1]
	var dir: Vector2 = (b1 - b0).normalized()
	draw_polyline(PackedVector2Array([b0, b1]), COL_BODY_OUTLINE, outline_w, true)
	draw_polyline(PackedVector2Array([b0 - dir * 15.0, b1 + dir * 15.0]), _o2_light(1.0), VESSEL_WIDTH, true)


func _draw_stations() -> void:
	for i: int in range(CirculationData.STATION_COUNT):
		var p: Vector2 = CirculationData.station_pos(i)
		draw_circle(p, 8.5, Color.WHITE, true, -1.0, true)
		draw_circle(p, 6.0, COL_DOT, true, -1.0, true)
	if _highlight >= 0:
		var hp: Vector2 = CirculationData.station_pos(_highlight)
		var wave: float = 0.5 + 0.5 * sin(_pulse * 6.0)
		var ring_r: float = 17.0 + 5.0 * wave
		draw_arc(hp, ring_r + 5.0, 0.0, TAU, 48, Color(COL_HIGHLIGHT.r, COL_HIGHLIGHT.g, COL_HIGHLIGHT.b, 0.35 * (1.0 - wave)), 4.0, true)
		draw_arc(hp, ring_r, 0.0, TAU, 48, COL_HIGHLIGHT, 4.5, true)


func _draw_labels() -> void:
	for i: int in range(CirculationData.STATION_COUNT):
		_draw_one_label(i)


func _draw_one_label(i: int) -> void:
	var anchor: Vector2 = LABEL_ANCHORS[i]
	var marker: Vector2 = CirculationData.station_pos(i)
	# Block sits left of its anchor when the anchor is left of the marker (the Aorta label
	# deviates from its "right" hint so it stays inside the 680 px map).
	var is_left: bool = anchor.x < marker.x
	var known: bool = _all_labels or _revealed[i]
	var lines: PackedStringArray = _label_lines[i]
	var line_h: float = _font.get_height(LABEL_FONT_SIZE)
	var ascent: float = _font.get_ascent(LABEL_FONT_SIZE)

	var text_w: float = 0.0
	var text_h: float = line_h * float(lines.size())
	if known:
		for line: String in lines:
			text_w = maxf(text_w, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x)
	else:
		text_w = 22.0
		text_h = 22.0

	var pad: Vector2 = Vector2(6, 3)
	var bw: float = text_w + pad.x * 2.0
	var bh: float = text_h + pad.y * 2.0
	var bx: float = anchor.x - bw if is_left else anchor.x
	bx = clampf(bx, 4.0, 676.0 - bw)
	var bg: Rect2 = Rect2(bx, anchor.y - bh * 0.5, bw, bh)

	# Leader line from the marker to the nearest edge of the block.
	var edge_x: float = bg.end.x if is_left else bg.position.x
	var edge_y: float = clampf(marker.y, bg.position.y + 6.0, bg.end.y - 6.0)
	draw_line(marker, Vector2(edge_x, edge_y), COL_DOT, 2.0, true)
	draw_circle(marker, 6.0, COL_DOT, true, -1.0, true)

	if known:
		_box(bg, Color(1, 1, 1, 0.82), 7, Color(0.8, 0.77, 0.88), 1)
		for li: int in range(lines.size()):
			var lw: float = _font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
			var tx: float = bg.end.x - pad.x - lw if is_left else bg.position.x + pad.x
			var ty: float = bg.position.y + pad.y + float(li) * line_h + ascent
			draw_string(_font, Vector2(tx, ty), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COL_TEXT)
	else:
		_box(bg, Color(1, 1, 1, 0.9), 8, Color(0.55, 0.5, 0.7), 2)
		var qs: Vector2 = _font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		draw_string(_font, Vector2(bg.position.x + (bg.size.x - qs.x) * 0.5, bg.position.y + (bg.size.y - qs.y) * 0.5 + ascent), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COL_CAPTION)


func _draw_legend() -> void:
	_box(Rect2(14, 640, 134, 62), Color(1, 1, 1, 0.85), 10, Color(0.8, 0.77, 0.88), 1)
	_box(Rect2(24, 649, 18, 18), _o2_light(1.0), 4, COL_VESSEL_OUTLINE, 1)
	_box(Rect2(24, 675, 18, 18), _o2_light(0.0), 4, COL_VESSEL_OUTLINE, 1)
	var ascent: float = _font.get_ascent(LEGEND_FONT_SIZE)
	var lh: float = _font.get_height(LEGEND_FONT_SIZE)
	draw_string(_font, Vector2(50, 658.0 - lh * 0.5 + ascent), "High Oxygen", HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, COL_TEXT)
	draw_string(_font, Vector2(50, 684.0 - lh * 0.5 + ascent), "Low Oxygen", HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, COL_TEXT)
