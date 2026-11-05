class_name BloodCell
extends Node2D
## Stylized top-down red blood cell. Only the fill follows the oxygen level;
## the outline is always CirculationData.COLOR_OUTLINE (yellow).

@export var radius: float = 15.0

var oxygen: float = 0.0:
	set(value):
		oxygen = clampf(value, 0.0, 1.0)
		queue_redraw()

var _pop_tween: Tween


func pop() -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.1)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.15)


func _draw() -> void:
	var fill: Color = CirculationData.o2_to_color(oxygen)
	# Soft drop shadow
	draw_circle(Vector2(2, 3), radius, Color(0, 0, 0, 0.25))
	# Fill
	draw_circle(Vector2.ZERO, radius, fill)
	# Centre dimple (flattened ellipse via transform)
	var dimple: Color = fill.darkened(0.25)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, radius * 0.55, dimple)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Small highlight
	draw_arc(Vector2.ZERO, radius * 0.72, deg_to_rad(200), deg_to_rad(260), 12, Color(1, 1, 1, 0.45), 2.0, true)
	# Outline last (always yellow)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, CirculationData.COLOR_OUTLINE, 3.0, true)
