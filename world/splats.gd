extends Node2D
## world/splats.gd: what the slain leave on the ground (za_death21.js deathFx / drawSplats): a fleshy death bleeds three
## to six dark pools that fade over 26 s (a bloat's are bile-green); a bony one scatters four chips of bone that lie
## 45 s. Matter, never light: no glow, drawn flat on the floor under every standing thing. At most 140 at once.
## Lives in the zone's floor layer; Splats.at(zone) finds or makes it.

const BONY := ["archer", "ossarcher", "knight", "marrow", "calc_knight", "oath_blade"]
var list: Array = []   # {p: tile pos, r: tiles, t, seed, col: "r" | "g" | "b"}

static func at(z: Zone) -> Node2D:
	if z == null or z.floor_layer == null:
		return null
	var s = z.floor_layer.get_node_or_null("Splats")
	if s == null:
		s = load("res://world/splats.gd").new()
		s.name = "Splats"
		z.floor_layer.add_child(s)
	return s

func death(kind: String, p: Vector2, big: bool) -> void:
	if kind in BONY:
		for i in 4:
			list.append({"p": p + Vector2(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3)), "r": 0.06, "t": 45.0, "seed": randf() * 9.0, "col": "b"})
	else:
		for i in 3 + (3 if big else 0):
			list.append({"p": p + Vector2(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25)), "r": 0.12 + randf() * 0.22, "t": 26.0, "seed": randf() * 9.0, "col": "g" if kind.contains("bloat") else "r"})
	while list.size() > 140:
		list.pop_front()
	queue_redraw()

func _process(dt: float) -> void:
	if list.is_empty():
		return
	for s in list:
		s["t"] -= dt
	list = list.filter(func(s): return s["t"] > 0.0)
	queue_redraw()

func _draw() -> void:
	var W := Iso.WPX
	for s in list:
		var q := Iso.to_screen(s["p"]).snapped(Vector2(W, W))
		var a := minf(1.0, float(s["t"]) / 8.0)
		if s["col"] == "b":
			draw_rect(Rect2(q, Vector2(2, 1) * W), Color(210 / 255.0, 200 / 255.0, 180 / 255.0, 0.8 * a))
			draw_rect(Rect2(q + Vector2(1, 1) * W, Vector2(W, W)), Color(120 / 255.0, 112 / 255.0, 100 / 255.0, 0.8 * a))
			continue
		var c := Color8(70, 80, 30) if s["col"] == "g" else Color8(70, 8, 14)
		c.a = 0.75 * a
		var R: float = float(s["r"]) * Iso.HX
		_ellipse(q, R, R * 0.5, c)
		for i in 4:
			var an: float = float(s["seed"]) + i * 1.7
			var d: float = R * (1.0 + (i % 2) * 0.5)
			_ellipse(q + Vector2(cos(an) * d, sin(an) * d * 0.5), R * 0.3, R * 0.16, c)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var q := (c + Vector2(cos(a) * rx, sin(a) * ry)).snapped(Vector2(Iso.WPX, Iso.WPX))
		if pts.is_empty() or (q != pts[pts.size() - 1] and q != pts[0]):
			pts.append(q)
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		# a drop too small for the pixel grid to hold its outline: a block of art pixels instead
		var W := Iso.WPX
		var hs := Vector2(maxf(W, snappedf(rx, W)), maxf(W, snappedf(ry, W)))
		draw_rect(Rect2((c - hs).snapped(Vector2(W, W)), hs * 2.0), col)
		return
	draw_colored_polygon(pts, col)
