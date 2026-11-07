# Circulation Sim — Journey of a Red Blood Cell

A simple, visual Godot 4.5 illustration of the human circulatory system's double loop.
A stylized red blood cell (yellow outline) travels:

Right Atrium → Right Ventricle → Pulmonary Arteries → **Capillaries of Lungs** (turns bright red)
→ Pulmonary Veins → Left Atrium → Left Ventricle → Aorta and Branches → **Capillaries of Body**
(turns purplish-blue) → Vena Cava → back to the Right Atrium.

## Modes
- **Explore** — Step one station at a time, or Play the loop continuously (optionally loop forever). Speed slider.
- **Quiz** — Drag the name of the *next* station from the list onto the map to move the cell there.
  Tapping/clicking a card (or Enter on a focused card) also submits it. Mistakes are counted.

## Controls
| Key | Action |
|-----|--------|
| Space | Play / Pause (Explore) |
| Right arrow / N | Step to next station |
| R | Reset / restart |
| M | Switch Explore ↔ Quiz |
| F11 | Full screen on/off (also the "Full screen" button) |
| Tab / arrows + Enter | Move between and press buttons/cards |

Mouse and touch work for everything (buttons, slider, drag-and-drop).

## Opening & exporting
1. Open `project.godot` in Godot 4.5.
2. Run with F5.
3. Web build: Project → Export → **Web** preset → Export Project (needs Godot 4.5 export templates).
   Output goes to `exports/web/index.html`. Serve that folder from a web server (browsers block
   opening it straight from disk).

## Project layout
- `scenes/main.tscn` — single scene; UI is built in code by `scripts/main.gd`.
- `scripts/circulation_data.gd` — stations, path geometry, colours (edit here to move things).
- `art/circulatory_background.png` — map background, rendered from `art/source/circulatory-path.svg`
  (the SVG's thin magenta guide path is hidden in the render; the cell path was traced from it).
- `scripts/circulation_map.gd` — draws the background, station markers, highlight and box labels.
- `scripts/blood_cell.gd` — the cell.
- `scripts/station_card.gd`, `scripts/map_drop_area.gd` — quiz drag-and-drop.
- `docs/SPEC.md` — build specification.
