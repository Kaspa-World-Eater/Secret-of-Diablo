extends Node2D
## Camp fire: a permanent light source at the camp.

var radius := 260.0
var light: PointLight2D
var _t := 0.0


func _ready() -> void:
	light = Lighting.make_light(radius, Color(1.0, 0.7, 0.4), 1.1)
	light.position = Vector2(0, -8)
	add_child(light)
	Game.light_sources.append(self)


func _exit_tree() -> void:
	Game.light_sources.erase(self)


func light_radius_px() -> float:
	return radius


func light_pos() -> Vector2:
	return global_position


func _process(delta: float) -> void:
	_t += delta
	light.energy = (1.05 + 0.08 * sin(_t * 7.0) + 0.05 * sin(_t * 19.0)) * Game.light_visual()
	queue_redraw()


func _draw() -> void:
	var o := Color(0.1, 0.07, 0.08)
	for i in 6:
		var a := TAU * i / 6.0
		draw_circle(Vector2(cos(a) * 13, sin(a) * 6), 4.0, Color(0.45, 0.45, 0.48))
	draw_line(Vector2(-9, 2), Vector2(9, -3), o, 5.0)
	draw_line(Vector2(-9, 2), Vector2(9, -3), Color(0.45, 0.3, 0.15), 3.0)
	draw_line(Vector2(-8, -3), Vector2(8, 2), Color(0.4, 0.26, 0.12), 3.0)
	for i in 5:
		var h = 10.0 + 6.0 * abs(sin(_t * 8.0 + i * 1.3))
		var x := (i - 2) * 3.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -1), Vector2(x + 3, -1), Vector2(x + sin(_t * 9.0 + i) * 1.5, -1 - h)]),
			Color(1, 0.45 + 0.1 * i, 0.1, 0.9))
	draw_circle(Vector2(0, -4), 3.0, Color(1, 0.95, 0.6))
