extends Node2D
## Short-lived visual effects (rings, bursts, poison clouds, weapon swings).

var kind := "ring"
var color := Color.WHITE
var radius := 40.0
var duration := 0.4
var dir := Vector2.RIGHT
var arc := 0.0
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
		"arc":
			# weapon swing: a crescent sweeping across the arc
			var a0 := dir.angle() - arc * 0.5
			var sweep: float = arc * min(1.0, k * 1.6)
			var lift := Vector2(0, -12)
			draw_arc(lift, radius * 0.92, a0, a0 + sweep, 24, Color(color, 0.85 * (1.0 - k)), 6.0)
			draw_arc(lift, radius * 0.7, a0, a0 + sweep, 24, Color(color, 0.35 * (1.0 - k)), 3.0)
		"line":
			var lift := Vector2(0, -12)
			var half := dir * radius * 0.5
			draw_line(lift - half, lift - half + dir * radius * min(1.0, k * 2.0), Color(color, 0.9 * (1.0 - k)), 4.0)
		"pin":
			var lift := Vector2(0, -6)
			for i in 3:
				var off := Vector2((i - 1) * 6.0, 0)
				draw_line(lift + off + Vector2(0, 6), lift + off + Vector2(0, -16), Color(0.1, 0.07, 0.08, 1.0 - k), 4.0)
				draw_line(lift + off + Vector2(0, 6), lift + off + Vector2(0, -16), Color(color, 1.0 - k), 2.0)
