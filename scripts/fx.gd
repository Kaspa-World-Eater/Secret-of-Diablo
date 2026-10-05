extends Node2D
## Short-lived visual effects (rings, bursts, poison clouds, curse marks).

var kind := "ring"
var color := Color.WHITE
var radius := 40.0
var duration := 0.4
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	match kind:
		"ring":
			draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * k), 0, TAU, 48, Color(color, 1.0 - k), 3.0)
		"burst":
			draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(color, 0.55 * (1.0 - k)))
		"cloud":
			for i in 7:
				var a := TAU * i / 7.0 + k
				draw_circle(Vector2.from_angle(a) * radius * 0.55 * (0.5 + k * 0.5), radius * 0.45, Color(color, 0.22 * (1.0 - k)))
		"curse":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.12 * (1.0 - k)))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, 0.8 * (1.0 - k)), 2.0)
