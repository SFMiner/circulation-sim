# Circulation Sim — Build Spec (manager-owned; agents must follow exactly)

Godot 4.5, GDScript only, **TABS for indentation (never spaces)**, static type hints everywhere,
GL Compatibility renderer, exported to HTML5. Viewport 1280x720, stretch `canvas_items`/`keep`.
All UI is built **in code** (no extra .tscn files). The only scene is `res://scenes/main.tscn`
(a full-rect `Control` with `scripts/main.gd`). Do not add UIDs or `.uid` files by hand.

## What it teaches
A stylized red blood cell (yellow outline, fill changes colour) travels the double loop:
Right Atrium → Right Ventricle → Pulmonary Arteries → Capillaries of Lungs (gains O2, turns bright red)
→ Pulmonary Veins → Left Atrium → Left Ventricle → Aorta and Branches → Capillaries of Body
(loses O2, turns purplish-blue) → Vena Cava → back to Right Atrium.

## Shared data — `scripts/circulation_data.gd` (DONE, read-only for agents)
`class_name CirculationData`. Read it. Use its constants and static functions; never duplicate coordinates.

## Screen layout (1280 x 720)
- Left: the map, a 680x720 area at x=0..680. `CirculationMap` (Node2D) positioned at (0,0) — map-local == screen.
- Right: side panel x=680..1280 (600 wide), a `PanelContainer` with margins ~16 px.
- `BloodCell` (Node2D) is a CHILD of `CirculationMap`, so it uses map-local coordinates.
- A full-size transparent `MapDropArea` Control covers the map area (x 0..680, y 0..720) and sits ABOVE the map
  (used only in quiz mode; `mouse_filter = MOUSE_FILTER_IGNORE` in play mode, `MOUSE_FILTER_PASS` in quiz mode).

## Files & owners

### `scripts/circulation_map.gd` — Agent MAP
```
class_name CirculationMap
extends Node2D
func set_labels_visible(on: bool) -> void      # play mode: true (all names shown); quiz: false
func reveal_label(index: int) -> void            # quiz: show this one station's real name
func hide_all_labels() -> void                   # quiz reset (all markers show "?")
func set_highlight(index: int) -> void           # -1 = none; draws a pulsing ring around that station marker
```
Draws everything with `_draw()` (no textures): background areas, lungs (two pinkish-lilac lobes with
capillary squiggles), heart (rounded pinkish shape; left half bluish = right side of heart, right half reddish),
body silhouette (simple grey person: circle head + rounded torso/limbs) inside a body capillary net,
vessels (thick ~22 px rounded polylines following `CirculationData.SEGMENTS`; colour each vessel by its O2:
use `o2_to_color` of the segment's mean O2, lightened ~35% for a soft look; draw lung/body capillary segments as
gradient-ish by splitting into sub-pieces), small dark station dots at each station pos, and labels
(`draw_string` with `ThemeDB.fallback_font`, size 18, dark text, on the `label_side` side, with a short leader line).
Hidden labels show "?" in a small rounded box. Also draw "Lung Circuit" / "Body Circuit" captions and a small
legend ("High Oxygen" red swatch / "Low Oxygen" blue swatch) in the bottom-left corner. Highlight pulse via
`_process` + `queue_redraw()` only while a highlight is set. Must look good, uncluttered, readable at 1280x720.

### `scripts/blood_cell.gd` — Agent CELL
```
class_name BloodCell
extends Node2D
var oxygen: float  (setter clamps 0..1 and calls queue_redraw())
@export var radius: float = 15.0
func pop() -> void   # quick scale tween 1.0 -> 1.25 -> 1.0 (0.25 s) used on arrival / correct answer
```
`_draw()`: stylized red blood cell (biconcave disc, top-down): filled circle in
`CirculationData.o2_to_color(oxygen)`, a slightly darker inner ellipse (centre dimple, ~55% radius) and a small
light highlight arc; then a **yellow outline** (`CirculationData.COLOR_OUTLINE`, width 3, antialiased).
Only the fill changes colour. Soft drop shadow (dark circle, alpha 0.25, offset (2,3)) drawn first.

### `scripts/main.gd`, `scripts/station_card.gd`, `scripts/map_drop_area.gd` — Agent APP
Builds all UI in code, owns modes, movement, input.

**Movement**: cell state = `current_station: int`, and while moving `moving_segment: int`, `t: float`.
Speed in map px/sec (`speed` default 140, slider 60–320). Each frame while moving:
`t += speed * delta / CirculationData.segment_length(seg)`; position = `point_on_segment`, oxygen = `o2_on_segment`.
On t >= 1: arrive at next station (snap pos, oxygen = `station_o2`), `cell.pop()`, update info panel, highlight.
Station dwell in continuous play: 0.6 s pause at each station before continuing.

**Top of side panel**: title "Journey of a Red Blood Cell", and mode tabs: `Explore` / `Quiz` (two toggle Buttons
in a ButtonGroup).

**Explore (play) mode**:
- Buttons: `Step ▶|` (move to next station, one at a time; ignored while moving), `Play ▶` / `Pause ⏸`
  (continuous loop; keeps looping round the double loop until paused), `Reset ⟲` (cell to Right Atrium, O2 0).
- Speed `HSlider` with label.
- A `Loop forever` CheckBox (default OFF): when OFF, Play stops automatically after one full double loop
  (back at the station it started from); when ON it repeats.
- Info panel: current station name (large), circuit ("Heart" / "Lung Circuit" / "Body Circuit"), the station's
  `info` text (autowrap RichTextLabel or Label), and a NON-NUMERIC oxygen indicator: colour swatch + word
  ("Oxygen-poor", "Oxygen-rich", "Picking up oxygen…", "Dropping off oxygen…"). This is an illustration — never show numbers/percentages.
- Ordered "Route" list showing all 10 stations with the current one highlighted (bold / coloured ▶ marker).
- Map labels all visible; highlight current station.

**Quiz mode**:
- On enter/restart: cell at Right Atrium (O2 0), `map.hide_all_labels()`, `map.reveal_label(RIGHT_ATRIUM)`,
  mistakes = 0, steps_done = 0. Prompt: "The cell is in the Right Atrium. Drag the NEXT station onto the map!"
- Side panel shows the 10 station names as `StationCard`s in a SHUFFLED vertical list (2 columns `GridContainer`
  is fine). Used cards are disabled/greyed with a ✓; Right Atrium card stays available because it's the final answer.
- Student drags a card and drops it anywhere on the map (`MapDropArea`). If the card's station ==
  `next_station(current)`: cell animates there (same movement code), label revealed on arrival, card marked used,
  prompt updates ("Correct! ... Where next?"), green feedback. If wrong: mistakes += 1, red feedback text
  "Not quite — where does blood go after the <current name>?", the card does a quick shake tween. Drops ignored while moving.
- After the 10th correct move (back to Right Atrium) → completion message "You completed the double loop!
  Mistakes: N" and a `Try Again` button.
- Keyboard/accessible alternative to drag: cards are focusable Buttons; pressing a card (click/tap without
  dragging, Enter or Space when focused) submits it as the answer, same as dropping it. Arrow keys / Tab move focus.

**Drag & drop** (works with mouse and touch; `emulate_mouse_from_touch` is on):
- `station_card.gd`: `class_name StationCard extends Button`; `var station_index: int`;
  `_get_drag_data(at_position)` returns `{"station_index": station_index}` and calls `set_drag_preview()` with a
  styled Label/PanelContainer copy of the name. Return null if disabled.
- `map_drop_area.gd`: `class_name MapDropArea extends Control`; `signal station_dropped(index: int)`;
  `_can_drop_data` true for a Dictionary with "station_index"; `_drop_data` emits the signal.

**Keyboard** (register actions in code in `main._ready()` via `InputMap.add_action`/`action_add_event`, guarding
with `has_action`): Space = play/pause, Right arrow or N = step, R = reset/restart, M = toggle mode.
Handle in `_unhandled_input` so focused Buttons still get Enter/Space first. Use `get_viewport().set_input_as_handled()`.

**Style**: build one `Theme` in code (default font size 18, buttons min height 44 for touch, rounded StyleBoxFlat
panels, soft palette: panel #ffffff, background #f4f1f7, accent #c8102e red / #3b4cc0 blue). Buttons min size 44x44.

## Rules for all agents
- Tabs only. Typed GDScript. No `@onready` paths into nodes that don't exist in the .tscn (build nodes in code).
- Don't edit files you don't own. Don't touch `circulation_data.gd`, `project.godot`, `main.tscn`.
- Godot 4.5 API only (e.g. `draw_polyline(points, color, width, antialiased)`, `draw_string(font, pos, text,
  HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)`, `Tween` via `create_tween()`). No deprecated 3.x API.
- Avoid shadowing built-ins (`name`, `position`, `scale`, `show`, `visible`…) with local variables/params —
  warnings-as-errors must stay clean. Do not name a parameter `show`.
- Verify with: `$GODOT --headless --path /home/user/circulation-sim --check-only --script res://scripts/<file>.gd`
  is not reliable for class_name deps; instead run
  `$GODOT --headless --path /home/user/circulation-sim --quit-after 120 2>&1 | grep -iE "error|warning"`
  and fix every error/warning that comes from your files.
  `GODOT=/tmp/claude-0/-home-user-circulation-sim/ad8ec746-7a5d-5f4a-a6b7-cc516f1289cc/scratchpad/Godot_v4.5-stable_linux.x86_64`
