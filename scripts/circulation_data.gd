class_name CirculationData
extends RefCounted
## Single source of truth for the circulation loop.
## All coordinates are in MAP-LOCAL space: a 680 x 720 area (see MAP_SIZE).
## Station i connects to station (i + 1) % STATION_COUNT via SEGMENTS[i].

const MAP_SIZE: Vector2 = Vector2(680, 720)
const STATION_COUNT: int = 10

# Station indices (in loop order)
const RIGHT_ATRIUM: int = 0
const RIGHT_VENTRICLE: int = 1
const PULMONARY_ARTERIES: int = 2
const LUNG_CAPILLARIES: int = 3
const PULMONARY_VEINS: int = 4
const LEFT_ATRIUM: int = 5
const LEFT_VENTRICLE: int = 6
const AORTA: int = 7
const BODY_CAPILLARIES: int = 8
const VENA_CAVA: int = 9

const START_STATION: int = RIGHT_ATRIUM

## Oxygen colours (fill only — the outline is always yellow)
const COLOR_HIGH_O2: Color = Color(0.92, 0.08, 0.14)
const COLOR_LOW_O2: Color = Color(0.36, 0.26, 0.78)
const COLOR_OUTLINE: Color = Color(1.0, 0.86, 0.1)

## Each station:
##   name        – display name
##   pos         – marker position (map-local), lies exactly on the path
##   label_side  – "left" or "right": which side of the marker its label goes
##   circuit     – "heart", "lung" or "body"
##   info        – one or two sentences shown in the info panel
const STATIONS: Array[Dictionary] = [
	{
		"name": "Right Atrium",
		"pos": Vector2(295, 350),
		"label_side": "left",
		"circuit": "heart",
		"info": "Oxygen-poor blood from the body collects in the right atrium, the heart's upper right chamber.",
	},
	{
		"name": "Right Ventricle",
		"pos": Vector2(300, 440),
		"label_side": "left",
		"circuit": "heart",
		"info": "The right ventricle squeezes and pumps oxygen-poor blood out toward the lungs.",
	},
	{
		"name": "Pulmonary Arteries",
		"pos": Vector2(170, 190),
		"label_side": "left",
		"circuit": "lung",
		"info": "The pulmonary arteries carry oxygen-poor blood from the heart to the lungs.",
	},
	{
		"name": "Capillaries of Lungs",
		"pos": Vector2(340, 110),
		"label_side": "right",
		"circuit": "lung",
		"info": "In the tiny lung capillaries the cell drops off carbon dioxide and picks up oxygen. It turns bright red!",
	},
	{
		"name": "Pulmonary Veins",
		"pos": Vector2(510, 200),
		"label_side": "right",
		"circuit": "lung",
		"info": "The pulmonary veins bring oxygen-rich blood from the lungs back to the heart.",
	},
	{
		"name": "Left Atrium",
		"pos": Vector2(385, 345),
		"label_side": "right",
		"circuit": "heart",
		"info": "Oxygen-rich blood from the lungs fills the left atrium, the heart's upper left chamber.",
	},
	{
		"name": "Left Ventricle",
		"pos": Vector2(385, 440),
		"label_side": "right",
		"circuit": "heart",
		"info": "The left ventricle is the strongest chamber. It pumps oxygen-rich blood out to the whole body.",
	},
	{
		"name": "Aorta and Branches",
		"pos": Vector2(590, 400),
		"label_side": "right",
		"circuit": "body",
		"info": "The aorta is the body's largest artery. Its branches carry oxygen-rich blood everywhere.",
	},
	{
		"name": "Capillaries of Body",
		"pos": Vector2(340, 650),
		"label_side": "right",
		"circuit": "body",
		"info": "In the body's capillaries the cell gives oxygen to the body's cells and picks up carbon dioxide. It turns bluish-purple.",
	},
	{
		"name": "Vena Cava",
		"pos": Vector2(100, 430),
		"label_side": "left",
		"circuit": "body",
		"info": "The vena cava is the large vein that returns oxygen-poor blood from the body to the heart.",
	},
]

## SEGMENTS[i] is the polyline from station i to station (i + 1) % 10.
## First point == STATIONS[i].pos, last point == STATIONS[i + 1].pos.
const SEGMENTS: Array[PackedVector2Array] = [
	# 0: Right Atrium -> Right Ventricle (through the tricuspid valve)
	PackedVector2Array([Vector2(295, 350), Vector2(300, 440)]),
	# 1: Right Ventricle -> Pulmonary Arteries
	PackedVector2Array([Vector2(300, 440), Vector2(320, 400), Vector2(330, 300), Vector2(330, 265), Vector2(300, 250), Vector2(200, 250), Vector2(170, 220), Vector2(170, 190)]),
	# 2: Pulmonary Arteries -> Capillaries of Lungs
	PackedVector2Array([Vector2(170, 190), Vector2(170, 140), Vector2(200, 110), Vector2(260, 105), Vector2(340, 110)]),
	# 3: Capillaries of Lungs -> Pulmonary Veins
	PackedVector2Array([Vector2(340, 110), Vector2(420, 105), Vector2(480, 110), Vector2(510, 140), Vector2(510, 200)]),
	# 4: Pulmonary Veins -> Left Atrium
	PackedVector2Array([Vector2(510, 200), Vector2(510, 300), Vector2(480, 330), Vector2(385, 345)]),
	# 5: Left Atrium -> Left Ventricle (through the mitral valve)
	PackedVector2Array([Vector2(385, 345), Vector2(385, 440)]),
	# 6: Left Ventricle -> Aorta and Branches
	PackedVector2Array([Vector2(385, 440), Vector2(370, 380), Vector2(370, 250), Vector2(390, 225), Vector2(560, 225), Vector2(590, 255), Vector2(590, 400)]),
	# 7: Aorta and Branches -> Capillaries of Body
	PackedVector2Array([Vector2(590, 400), Vector2(590, 540), Vector2(560, 580), Vector2(450, 620), Vector2(340, 650)]),
	# 8: Capillaries of Body -> Vena Cava
	PackedVector2Array([Vector2(340, 650), Vector2(230, 620), Vector2(130, 580), Vector2(100, 540), Vector2(100, 430)]),
	# 9: Vena Cava -> Right Atrium
	PackedVector2Array([Vector2(100, 430), Vector2(100, 330), Vector2(130, 300), Vector2(220, 300), Vector2(295, 350)]),
]

## Oxygen level (0.0 = depleted, 1.0 = full) at the START and END of each segment.
## Oxygen is interpolated linearly by distance along the segment.
## The cell is half-way through gas exchange when it sits on a capillary station.
const SEGMENT_O2: Array[Vector2] = [
	Vector2(0.0, 0.0),	# RA -> RV
	Vector2(0.0, 0.0),	# RV -> PA
	Vector2(0.0, 0.5),	# PA -> lung capillaries (loading oxygen)
	Vector2(0.5, 1.0),	# lung capillaries -> PV (loading oxygen)
	Vector2(1.0, 1.0),	# PV -> LA
	Vector2(1.0, 1.0),	# LA -> LV
	Vector2(1.0, 1.0),	# LV -> aorta
	Vector2(1.0, 0.5),	# aorta -> body capillaries (unloading oxygen)
	Vector2(0.5, 0.0),	# body capillaries -> vena cava (unloading oxygen)
	Vector2(0.0, 0.0),	# vena cava -> RA
]


static func next_station(index: int) -> int:
	return (index + 1) % STATION_COUNT


static func station_name(index: int) -> String:
	return STATIONS[index]["name"]


static func station_pos(index: int) -> Vector2:
	return STATIONS[index]["pos"]


## Oxygen level of a cell resting AT a station (start of its outgoing segment).
static func station_o2(index: int) -> float:
	return SEGMENT_O2[index].x


static func o2_to_color(o2: float) -> Color:
	return COLOR_LOW_O2.lerp(COLOR_HIGH_O2, clampf(o2, 0.0, 1.0))


## Total length of a segment polyline in map pixels.
static func segment_length(seg: int) -> float:
	var pts: PackedVector2Array = SEGMENTS[seg]
	var total: float = 0.0
	for i: int in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	return total


## Position along a segment at progress t (0..1, by distance).
static func point_on_segment(seg: int, t: float) -> Vector2:
	var pts: PackedVector2Array = SEGMENTS[seg]
	var target: float = clampf(t, 0.0, 1.0) * segment_length(seg)
	for i: int in range(pts.size() - 1):
		var piece: float = pts[i].distance_to(pts[i + 1])
		if target <= piece or i == pts.size() - 2:
			if piece <= 0.0:
				return pts[i + 1]
			return pts[i].lerp(pts[i + 1], clampf(target / piece, 0.0, 1.0))
		target -= piece
	return pts[pts.size() - 1]


## Oxygen level along a segment at progress t (0..1).
static func o2_on_segment(seg: int, t: float) -> float:
	var o2: Vector2 = SEGMENT_O2[seg]
	return lerpf(o2.x, o2.y, clampf(t, 0.0, 1.0))
