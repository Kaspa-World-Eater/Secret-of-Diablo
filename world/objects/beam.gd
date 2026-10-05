extends Node2D
## mode 0: the column over an unwoken god altar (zd_world22 drawAltars), faint, in the god's colour (never red).
## mode 1: the faint gold breath on the ground under an vow's object (zz_quests qGroundDraw).
## Drawn additively; not a light source.

var col := Color.WHITE
var mode := 0
var t := 0.0

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	t = randf() * 6.0

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	var W := Iso.WPX
	if mode == 1:
		var a := 0.2 + 0.08 * sin(t * 3.0)
		for i in 5:
			var k := 1.0 - i / 5.0
			var c := col
			c.a = a * 0.22
			_ell(Vector2(0, -8 * W * 0.25), 14 * W * k, 7 * W * k, c)
		return
	var k := 0.5 + 0.2 * sin(t * 2.0)
	var c0 := col
	c0.a = 0.0
	var c1 := col
	c1.a = 0.2 * k
	draw_polygon(PackedVector2Array([Vector2(-7 * W, -140 * W), Vector2(7 * W, -140 * W), Vector2(7 * W, -6 * W), Vector2(-7 * W, -6 * W)]),
		PackedColorArray([c0, c0, c1, c1]))
	var c2 := col
	c2.a = 0.12 * k
	draw_rect(Rect2(-2 * W, -160 * W, 4 * W, 154 * W), c2)

func _ell(c: Vector2, rx: float, ry: float, colr: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, colr)
