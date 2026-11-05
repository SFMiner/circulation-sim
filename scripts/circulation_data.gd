class_name CirculationData
extends RefCounted
## Single source of truth for the circulation loop.
## All coordinates are in MAP-LOCAL space: a 680 x 720 area (see MAP_SIZE).
## The map background is art/circulatory_background.png, rendered from
## art/source/circulatory-path.svg (1001.825 x 1062.065) scaled by SVG_SCALE.
## The cell path and station positions were traced from that SVG's guide path.
## Station i connects to station (i + 1) % STATION_COUNT via SEGMENTS[i].

const MAP_SIZE: Vector2 = Vector2(680, 720)
const SVG_SCALE: float = 680.0 / 1001.825
const BACKGROUND_PATH: String = "res://art/circulatory_background.png"
const BACKGROUND_SIZE: Vector2 = Vector2(680.0, 1062.065 * 680.0 / 1001.825)
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
##   circuit     – "heart", "lung" or "body"
##   info        – one or two sentences shown in the info panel
const STATIONS: Array[Dictionary] = [
	{
		"name": "Right Atrium",
		"pos": Vector2(277.8, 340.5),
		"circuit": "heart",
		"info": "Oxygen-poor blood from the body collects in the right atrium, the heart's upper right chamber.",
	},
	{
		"name": "Right Ventricle",
		"pos": Vector2(296.8, 372.6),
		"circuit": "heart",
		"info": "The right ventricle squeezes and pumps oxygen-poor blood out toward the lungs.",
	},
	{
		"name": "Pulmonary Arteries",
		"pos": Vector2(208.1, 181.1),
		"circuit": "lung",
		"info": "The pulmonary arteries carry oxygen-poor blood from the heart to the lungs.",
	},
	{
		"name": "Capillaries of Lungs",
		"pos": Vector2(332.3, 125.7),
		"circuit": "lung",
		"info": "In the tiny lung capillaries the cell drops off carbon dioxide and picks up oxygen. It turns bright red!",
	},
	{
		"name": "Pulmonary Veins",
		"pos": Vector2(451.3, 180.3),
		"circuit": "lung",
		"info": "The pulmonary veins bring oxygen-rich blood from the lungs back to the heart.",
	},
	{
		"name": "Left Atrium",
		"pos": Vector2(344.2, 315.1),
		"circuit": "heart",
		"info": "Oxygen-rich blood from the lungs fills the left atrium, the heart's upper left chamber.",
	},
	{
		"name": "Left Ventricle",
		"pos": Vector2(349.4, 376.5),
		"circuit": "heart",
		"info": "The left ventricle is the strongest chamber. It pumps oxygen-rich blood out to the whole body.",
	},
	{
		"name": "Aorta and Branches",
		"pos": Vector2(454.4, 251),
		"circuit": "body",
		"info": "The aorta is the body's largest artery. Its branches carry oxygen-rich blood everywhere.",
	},
	{
		"name": "Capillaries of Body",
		"pos": Vector2(329.8, 557.1),
		"circuit": "body",
		"info": "In the body's capillaries the cell gives oxygen to the body's cells and picks up carbon dioxide. It turns bluish-purple.",
	},
	{
		"name": "Vena Cava",
		"pos": Vector2(217.4, 285.4),
		"circuit": "body",
		"info": "The vena cava is the large vein that returns oxygen-poor blood from the body to the heart.",
	},
]

## SEGMENTS[i] is the polyline from station i to station (i + 1) % 10.
## First point == STATIONS[i].pos, last point == STATIONS[i + 1].pos.
static var SEGMENTS: Array[PackedVector2Array] = [
	# 0: Right Atrium -> Right Ventricle
	PackedVector2Array([Vector2(277.8, 340.5), Vector2(277.7, 343.1), Vector2(277.7, 345.6), Vector2(277.9, 348.1), Vector2(278.3, 350.5), Vector2(278.8, 352.9), Vector2(279.6, 355.1), Vector2(280.7, 357.2), Vector2(281.8, 359.2), Vector2(283.1, 361.1), Vector2(284.4, 362.8), Vector2(285.8, 364.4), Vector2(287.3, 365.8), Vector2(288.7, 367.1), Vector2(290.1, 368.3), Vector2(291.4, 369.3), Vector2(292.7, 370.2), Vector2(293.8, 370.9), Vector2(294.8, 371.5), Vector2(295.7, 372), Vector2(296.3, 372.4), Vector2(296.8, 372.6)]),
	# 1: Right Ventricle -> Pulmonary Arteries
	PackedVector2Array([Vector2(296.8, 372.6), Vector2(296.8, 372.2), Vector2(296.8, 370.9), Vector2(296.7, 368.9), Vector2(296.7, 366.1), Vector2(296.7, 362.8), Vector2(296.8, 359), Vector2(297, 354.7), Vector2(297.3, 350.1), Vector2(297.7, 345.2), Vector2(298.3, 340.1), Vector2(299.1, 334.9), Vector2(300.1, 329.6), Vector2(301.4, 324.4), Vector2(302.9, 319.3), Vector2(304.8, 314.4), Vector2(306.9, 309.8), Vector2(309.3, 305.5), Vector2(311.8, 301.6), Vector2(314.3, 297.9), Vector2(316.8, 294.5), Vector2(319.1, 291.3), Vector2(321.4, 288.3), Vector2(323.3, 285.5), Vector2(325, 282.8), Vector2(326.3, 280.3), Vector2(327.1, 277.8), Vector2(327.4, 275.4), Vector2(327.1, 273), Vector2(326.2, 270.6), Vector2(324.5, 268.2), Vector2(322, 265.7), Vector2(318.7, 263.2), Vector2(315, 260.7), Vector2(311.3, 258.6), Vector2(307.7, 256.6), Vector2(304.1, 255), Vector2(300.6, 253.5), Vector2(297.1, 252.3), Vector2(293.6, 251.2), Vector2(290.2, 250.3), Vector2(286.8, 249.5), Vector2(283.4, 248.9), Vector2(280, 248.3), Vector2(276.6, 247.8), Vector2(273.2, 247.4), Vector2(269.7, 247), Vector2(266.2, 246.7), Vector2(262.7, 246.3), Vector2(259.2, 245.8), Vector2(255.5, 244.9), Vector2(251.8, 243.8), Vector2(248.1, 242.5), Vector2(244.4, 240.9), Vector2(240.7, 239.1), Vector2(237.2, 237.1), Vector2(233.8, 234.9), Vector2(230.5, 232.6), Vector2(227.5, 230.2), Vector2(224.7, 227.6), Vector2(222.1, 224.9), Vector2(219.9, 222.2), Vector2(218, 219.4), Vector2(216.4, 216.6), Vector2(215.3, 213.8), Vector2(213.8, 209), Vector2(212.3, 204.2), Vector2(211, 199.5), Vector2(209.9, 194.8), Vector2(209, 190.1), Vector2(208.4, 185.6), Vector2(208.1, 181.1)]),
	# 2: Pulmonary Arteries -> Capillaries of Lungs
	PackedVector2Array([Vector2(208.1, 181.1), Vector2(208.2, 176.7), Vector2(208.7, 172.3), Vector2(209.7, 168.1), Vector2(211.2, 164), Vector2(213.2, 160), Vector2(215.9, 156.1), Vector2(219.2, 152.4), Vector2(223.3, 148.7), Vector2(228, 145.3), Vector2(233.1, 142.1), Vector2(237.9, 139.5), Vector2(242.5, 137.3), Vector2(247, 135.4), Vector2(251.3, 133.9), Vector2(255.6, 132.7), Vector2(259.9, 131.8), Vector2(264.1, 131), Vector2(268.5, 130.5), Vector2(272.9, 130), Vector2(277.5, 129.6), Vector2(282.2, 129.2), Vector2(287.2, 128.9), Vector2(292.5, 128.4), Vector2(298, 127.8), Vector2(303.9, 127.1), Vector2(310.3, 126.4), Vector2(317.3, 126), Vector2(324.6, 125.7), Vector2(332.3, 125.7)]),
	# 3: Capillaries of Lungs -> Pulmonary Veins
	PackedVector2Array([Vector2(332.3, 125.7), Vector2(340.1, 125.8), Vector2(348.1, 126.1), Vector2(356, 126.4), Vector2(363.8, 126.9), Vector2(371.4, 127.4), Vector2(378.6, 127.9), Vector2(385.4, 128.5), Vector2(391.6, 129), Vector2(397.1, 129.4), Vector2(401.8, 129.8), Vector2(405.6, 130.1), Vector2(408.5, 130.2), Vector2(410.9, 130.3), Vector2(413.7, 130.6), Vector2(416.7, 131.1), Vector2(419.8, 131.7), Vector2(423.1, 132.6), Vector2(426.5, 133.7), Vector2(429.8, 135), Vector2(433.1, 136.7), Vector2(436.3, 138.6), Vector2(439.3, 140.9), Vector2(442.1, 143.6), Vector2(444.6, 146.6), Vector2(446.7, 150.1), Vector2(448.5, 153.9), Vector2(449.7, 158.3), Vector2(450.5, 163.1), Vector2(450.9, 168.4), Vector2(451.1, 174.1), Vector2(451.3, 180.3)]),
	# 4: Pulmonary Veins -> Left Atrium
	PackedVector2Array([Vector2(451.3, 180.3), Vector2(451.4, 186.8), Vector2(451.3, 193.5), Vector2(451.2, 200.3), Vector2(450.9, 207.3), Vector2(450.6, 214.2), Vector2(450.2, 221), Vector2(449.8, 227.7), Vector2(449.2, 234.2), Vector2(448.7, 240.4), Vector2(448, 246.1), Vector2(447.4, 251.4), Vector2(446.6, 256.2), Vector2(445.9, 260.3), Vector2(445.1, 264), Vector2(444.1, 267.6), Vector2(443, 271), Vector2(441.6, 274.3), Vector2(440.1, 277.4), Vector2(438.2, 280.4), Vector2(436.1, 283.1), Vector2(433.7, 285.7), Vector2(431, 288.1), Vector2(427.9, 290.3), Vector2(424.4, 292.2), Vector2(420.5, 294), Vector2(416.2, 295.5), Vector2(411.4, 296.8), Vector2(406.1, 297.9), Vector2(400.3, 298.7), Vector2(394.4, 299.2), Vector2(388.9, 299.5), Vector2(383.7, 299.6), Vector2(378.9, 299.6), Vector2(374.4, 299.4), Vector2(370.3, 299.3), Vector2(366.5, 299.2), Vector2(363, 299.2), Vector2(359.9, 299.3), Vector2(357, 299.6), Vector2(354.4, 300.1), Vector2(352.1, 300.9), Vector2(350, 302.1), Vector2(348.2, 303.7), Vector2(346.7, 305.7), Vector2(345.4, 308.3), Vector2(344.5, 311.4), Vector2(344.2, 315.1)]),
	# 5: Left Atrium -> Left Ventricle
	PackedVector2Array([Vector2(344.2, 315.1), Vector2(344.3, 319.2), Vector2(344.8, 323.7), Vector2(345.6, 328.6), Vector2(346.6, 333.6), Vector2(347.8, 338.8), Vector2(349.1, 344), Vector2(350.4, 349.1), Vector2(351.6, 354.1), Vector2(352.7, 358.8), Vector2(353.5, 363.2), Vector2(354.1, 367.2), Vector2(354.3, 370.7), Vector2(354.1, 373.7), Vector2(353.4, 375.9), Vector2(351.8, 377), Vector2(349.4, 376.5)]),
	# 6: Left Ventricle -> Aorta and Branches
	PackedVector2Array([Vector2(349.4, 376.5), Vector2(346.1, 374.6), Vector2(342.1, 371.5), Vector2(337.6, 367.2), Vector2(332.8, 362), Vector2(327.7, 356), Vector2(322.5, 349.2), Vector2(317.4, 342), Vector2(312.5, 334.3), Vector2(307.9, 326.4), Vector2(303.8, 318.4), Vector2(300.3, 310.3), Vector2(297.6, 302.5), Vector2(295.8, 295), Vector2(295.1, 287.9), Vector2(295.1, 281.4), Vector2(295.3, 275.4), Vector2(295.9, 269.9), Vector2(296.7, 264.9), Vector2(297.8, 260.4), Vector2(299.1, 256.3), Vector2(300.7, 252.7), Vector2(302.6, 249.4), Vector2(304.7, 246.6), Vector2(307, 244.1), Vector2(309.6, 242), Vector2(312.3, 240.2), Vector2(315.3, 238.8), Vector2(318.5, 237.6), Vector2(321.9, 236.7), Vector2(325.5, 236.1), Vector2(328.5, 235.7), Vector2(332.5, 235.1), Vector2(337.5, 234.5), Vector2(343.3, 233.8), Vector2(349.9, 233.2), Vector2(357.2, 232.6), Vector2(364.9, 232.1), Vector2(373.1, 231.8), Vector2(381.6, 231.7), Vector2(390.3, 231.8), Vector2(399.1, 232.2), Vector2(407.8, 233), Vector2(416.4, 234.2), Vector2(424.8, 235.9), Vector2(432.7, 238), Vector2(440.2, 240.7), Vector2(444.3, 242.7), Vector2(447.9, 245.1), Vector2(451.3, 247.9), Vector2(454.4, 251)]),
	# 7: Aorta and Branches -> Capillaries of Body
	PackedVector2Array([Vector2(454.4, 251), Vector2(457.1, 254.4), Vector2(459.6, 258), Vector2(461.8, 261.7), Vector2(463.7, 265.5), Vector2(465.4, 269.4), Vector2(466.8, 273.3), Vector2(467.9, 277.2), Vector2(468.9, 280.9), Vector2(469.6, 284.4), Vector2(470.1, 287.8), Vector2(470.4, 290.8), Vector2(470.6, 293.5), Vector2(470.8, 302.2), Vector2(471.1, 312.7), Vector2(471.6, 324.8), Vector2(472.1, 338.1), Vector2(472.6, 352.4), Vector2(473, 367.4), Vector2(473.4, 382.8), Vector2(473.6, 398.2), Vector2(473.6, 413.4), Vector2(473.3, 428.1), Vector2(472.8, 441.9), Vector2(471.9, 454.6), Vector2(470.6, 465.9), Vector2(468.8, 475.5), Vector2(466.6, 483), Vector2(463.8, 488.2), Vector2(460.5, 492.3), Vector2(456.7, 496.7), Vector2(452.4, 501.2), Vector2(447.8, 505.9), Vector2(442.8, 510.7), Vector2(437.4, 515.5), Vector2(431.8, 520.2), Vector2(425.9, 524.9), Vector2(419.9, 529.4), Vector2(413.6, 533.7), Vector2(407.3, 537.7), Vector2(400.8, 541.3), Vector2(394.4, 544.6), Vector2(387.9, 547.4), Vector2(381.4, 549.7), Vector2(375, 551.4), Vector2(368.7, 552.8), Vector2(362.2, 554), Vector2(355.7, 555.1), Vector2(349.2, 555.9), Vector2(342.7, 556.6), Vector2(336.2, 557), Vector2(329.8, 557.1)]),
	# 8: Capillaries of Body -> Vena Cava
	PackedVector2Array([Vector2(329.8, 557.1), Vector2(323.4, 556.9), Vector2(317.1, 556.5), Vector2(310.9, 555.6), Vector2(304.8, 554.4), Vector2(298.9, 552.8), Vector2(293.1, 550.8), Vector2(287.6, 548.3), Vector2(282.2, 545.3), Vector2(277.1, 541.9), Vector2(272, 538.1), Vector2(266.7, 534.1), Vector2(261.1, 529.9), Vector2(255.6, 525.5), Vector2(250, 521), Vector2(244.4, 516.4), Vector2(239.1, 511.6), Vector2(233.9, 506.6), Vector2(229, 501.6), Vector2(224.5, 496.4), Vector2(220.5, 491.2), Vector2(217, 485.8), Vector2(214.1, 480.4), Vector2(211.8, 474.9), Vector2(210.3, 469.3), Vector2(209.7, 463.7), Vector2(209.5, 457.5), Vector2(209.3, 451.2), Vector2(209.2, 444.7), Vector2(209.1, 438.2), Vector2(209.1, 431.6), Vector2(209.1, 424.9), Vector2(209.2, 418.2), Vector2(209.2, 411.4), Vector2(209.3, 404.5), Vector2(209.4, 397.5), Vector2(209.4, 390.5), Vector2(209.5, 383.5), Vector2(209.6, 376.5), Vector2(209.6, 369.4), Vector2(209.7, 362.3), Vector2(209.7, 355.2), Vector2(209.6, 347.8), Vector2(209.3, 340.9), Vector2(209, 334.5), Vector2(208.6, 328.6), Vector2(208.2, 323), Vector2(207.8, 317.9), Vector2(207.6, 313.2), Vector2(207.6, 308.8), Vector2(207.8, 304.7), Vector2(208.3, 300.9), Vector2(209.2, 297.4), Vector2(210.5, 294.1), Vector2(212.3, 291), Vector2(214.6, 288.1), Vector2(217.4, 285.4)]),
	# 9: Vena Cava -> Right Atrium
	PackedVector2Array([Vector2(217.4, 285.4), Vector2(220.9, 282.8), Vector2(224.7, 280.5), Vector2(228.1, 278.8), Vector2(231.4, 277.5), Vector2(234.4, 276.7), Vector2(237.2, 276.3), Vector2(239.8, 276.3), Vector2(242.2, 276.6), Vector2(244.5, 277.3), Vector2(246.7, 278.2), Vector2(248.8, 279.3), Vector2(250.7, 280.7), Vector2(252.7, 282.2), Vector2(254.5, 283.9), Vector2(256.3, 285.7), Vector2(258.1, 287.5), Vector2(259.9, 289.4), Vector2(261.7, 291.2), Vector2(263.4, 292.9), Vector2(264.9, 294.5), Vector2(266.3, 296), Vector2(267.7, 297.4), Vector2(268.9, 298.8), Vector2(270.1, 300.2), Vector2(271.2, 301.6), Vector2(272.2, 303), Vector2(273.1, 304.5), Vector2(274, 306), Vector2(274.8, 307.6), Vector2(275.6, 309.3), Vector2(276.3, 311.1), Vector2(277, 313.1), Vector2(277.7, 315.3), Vector2(278.3, 317.6), Vector2(278.6, 320), Vector2(278.8, 322.4), Vector2(278.8, 324.9), Vector2(278.7, 327.5), Vector2(278.6, 330.1), Vector2(278.3, 332.7), Vector2(278.1, 335.3), Vector2(277.9, 337.9), Vector2(277.8, 340.5)]),
]

## Label boxes (map-local), taken from the boxes in the SVG. Capillaries of Body has no
## box in the art, so the map draws one in the same style.
static var LABEL_BOXES: Array[Rect2] = [
	_svg_rect(45.622, 477.802, 261.847, 565.328),	# Right Atrium
	_svg_rect(45.622, 588.006, 261.847, 675.532),	# Right Ventricle
	_svg_rect(45.622, 217.313, 261.847, 304.839),	# Pulmonary Arteries
	_svg_rect(621.784, 76.821, 838.009, 164.347),	# Capillaries of Lungs
	_svg_rect(716.648, 206.026, 932.872, 293.552),	# Pulmonary Veins
	_svg_rect(743.861, 422.12, 960.086, 509.646),	# Left Atrium
	_svg_rect(743.861, 529.253, 960.086, 616.779),	# Left Ventricle
	_svg_rect(749.039, 314.986, 965.264, 402.512),	# Aorta and Branches
	_svg_rect(716.0, 790.0, 932.0, 877.5),	# Capillaries of Body (drawn by the map)
	_svg_rect(45.622, 370.698, 261.847, 458.224),	# Vena Cava
]
const DRAWN_BOX_STATION: int = BODY_CAPILLARIES


## Oxygen level (0.0 = depleted, 1.0 = full) at the START and END of each segment.
## The change happens only inside SEGMENT_O2_RAMP (fractions of the segment), so the
## colour shifts while the cell is inside the lungs / body capillaries.
## The cell is half-way through gas exchange when it sits on a capillary station.
const SEGMENT_O2_RAMP: Array[Vector2] = [
	Vector2(0, 1),
	Vector2(0, 1),
	Vector2(0.546, 1),
	Vector2(0, 0.426),
	Vector2(0, 1),
	Vector2(0, 1),
	Vector2(0, 1),
	Vector2(0.685, 1),
	Vector2(0, 0.304),
	Vector2(0, 1),
]

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
	var ramp: Vector2 = SEGMENT_O2_RAMP[seg]
	var u: float = clampf((t - ramp.x) / maxf(ramp.y - ramp.x, 0.001), 0.0, 1.0)
	return lerpf(o2.x, o2.y, u)


static func _svg_rect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(Vector2(x0, y0) * SVG_SCALE, Vector2(x1 - x0, y1 - y0) * SVG_SCALE)
