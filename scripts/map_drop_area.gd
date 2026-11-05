class_name MapDropArea
extends Control
## Transparent drop target covering the map. Emits the dropped station index.

signal station_dropped(index: int)

var _drag_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_drag_active = mouse_filter != Control.MOUSE_FILTER_IGNORE
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_drag_active = false
		queue_redraw()


func _draw() -> void:
	if _drag_active:
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.23, 0.30, 0.75, 0.7), false, 3.0)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("station_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and (data as Dictionary).has("station_index"):
		station_dropped.emit(int((data as Dictionary)["station_index"]))
