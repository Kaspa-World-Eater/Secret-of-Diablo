extends Node2D
## A monster corpse. Fuel for Raise Skeleton, Revive and Corpse Explosion.

var kind := ""
var level := 1
var max_hp := 10.0
var color := Color.GRAY
var size := 10.0
var used := false
var life := 150.0


func _ready() -> void:
	Game.corpses.append(self)


func _exit_tree() -> void:
	Game.corpses.erase(self)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
	elif life < 5.0:
		modulate.a = life / 5.0


func consume() -> void:
	used = true
	queue_free()


func _draw() -> void:
	_ellipse(Vector2(2, 0), size * 1.4, size * 0.6, Color(0.45, 0.05, 0.05, 0.75))
	_ellipse(Vector2(0, -3), size * 1.1, size * 0.5, Color(0.1, 0.07, 0.08))
	_ellipse(Vector2(0, -3), size, size * 0.42, color.darkened(0.45))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
