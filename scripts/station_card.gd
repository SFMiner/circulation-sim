class_name StationCard
extends Button
## A draggable (and tappable / keyboard-activatable) quiz card for one station.

signal selected(index: int)

var station_index: int = 0
var used: bool = false
var _drag_started: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(180, 44)
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_down.connect(_on_button_down)
	pressed.connect(_on_pressed)


func setup(index: int) -> void:
	station_index = index
	text = CirculationData.station_name(index)


func mark_used() -> void:
	used = true
	disabled = true
	text = "%s  (done)" % CirculationData.station_name(station_index)


func shake() -> void:
	var base_x: float = position.x
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:x", base_x + 9.0, 0.05)
	tw.tween_property(self, "position:x", base_x - 9.0, 0.08)
	tw.tween_property(self, "position:x", base_x + 6.0, 0.06)
	tw.tween_property(self, "position:x", base_x, 0.05)


func _on_button_down() -> void:
	_drag_started = false


func _on_pressed() -> void:
	if _drag_started or get_viewport().gui_is_dragging():
		return
	selected.emit(station_index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or used:
		return null
	_drag_started = true
	var root: Control = Control.new()
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	box.border_color = Color(0.23, 0.30, 0.75)
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)
	var lbl: Label = Label.new()
	lbl.text = CirculationData.station_name(station_index)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.1, 0.18))
	panel.add_child(lbl)
	panel.position = Vector2(-70, -22)
	root.add_child(panel)
	set_drag_preview(root)
	return {"station_index": station_index}
