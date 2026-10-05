extends Control
## the stone ring round an orb, carved in plain strokes
func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 90.0, Color(0.09, 0.085, 0.08))
	draw_arc(c, 84.0, 0.0, TAU, 96, Color(0.3, 0.27, 0.22), 6.0, true)
	draw_arc(c, 88.5, 0.0, TAU, 96, Color(0.05, 0.045, 0.04), 2.0, true)
	draw_arc(c, 79.0, 0.0, TAU, 96, Color(0.05, 0.045, 0.04), 2.0, true)
	for i in 12:
		var a := i / 12.0 * TAU
		draw_circle(c + Vector2(cos(a), sin(a)) * 84.0, 2.2, Color(0.16, 0.14, 0.11))
