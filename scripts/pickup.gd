extends Node2D
## Gold and potions on the ground; picked up by walking over them.

var kind := "gold"
var amount := 0
var _t := 0.0
var life := 120.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var p = Game.player
	if p != null and not p.dead and p.global_position.distance_to(global_position) < 26.0:
		if p.pick_up(self):
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var y = -4.0 - abs(sin(_t * 3.0)) * 2.0
	match kind:
		"gold":
			for i in 3:
				draw_circle(Vector2(i * 3 - 3, y - i), 3.5, Color(0.3, 0.2, 0.05))
				draw_circle(Vector2(i * 3 - 3, y - i), 2.6, Color(1, 0.82, 0.25))
		"hp", "mp":
			var c := Color(0.9, 0.12, 0.12) if kind == "hp" else Color(0.2, 0.3, 0.95)
			draw_circle(Vector2(0, y), 5.5, Color(0.1, 0.07, 0.08))
			draw_circle(Vector2(0, y), 4.5, c)
			draw_rect(Rect2(-2, y - 10, 4, 5), Color(0.75, 0.75, 0.8))
			draw_circle(Vector2(-1.5, y - 1.5), 1.3, Color(1, 1, 1, 0.7))
