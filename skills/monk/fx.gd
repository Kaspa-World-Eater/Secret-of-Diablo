extends Node2D
## The Empty Hand's transient things, drawn from the skill book's lists (skills/monk.gd) every frame. One of these lives
## on the floor layer (what he leaves behind, roots, rings, cracks, tears lying in wait, the lotus and the palm's pull)
## and one above the world (the fist from the sky, the paper sutras, the beam of the third eye, the bell, the pagoda,
## the thousand arms, the words he laughs). Flat pixel shapes in the web's colours: no glow, no trails, no red light.

const U := preload("res://ui/uikit.gd")
var book
var floor_mode = false

const AMBER := Color8(255, 216, 112)
const PALEGOLD := Color8(255, 240, 176)
const VOID := Color8(138, 106, 200)
const INK := Color8(20, 14, 26)
const STONE := Color8(176, 172, 160)
const STONE_D := Color8(96, 92, 84)

func _process(_dt: float) -> void:
	if book == null or (book.fx_air != self and book.fx_floor != self):
		queue_free()
		return
	queue_redraw()

static func S(tp: Vector2, z: float = 0.0) -> Vector2:
	return Iso.to_screen(tp) + Vector2(0, -z * 4.0)

func ell(c: Vector2, R: float, col: Color, w: float = 2.0, filled: bool = false) -> void:
	var rx = R * Iso.HX * 1.414
	var ry = rx * 0.5
	var pts = PackedVector2Array()
	for i in 41:
		var a = i / 40.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(pts, col)
	else:
		draw_polyline(pts, col, w)

func _draw() -> void:
	if book == null or book.zone == null or book.hero == null:
		return
	if floor_mode:
		_floor()
	else:
		_air()

# ------------------------------------------------------------------ on the ground
func _floor() -> void:
	var b = book
	# what his kills leave: black glass, rubble, dust
	for r in b.remains:
		var k: float = clampf(r["t"] / minf(2.0, r["max"]), 0.0, 1.0)
		var p = S(r["tp"])
		var rng = RandomNumberGenerator.new()
		rng.seed = int(r["seed"] * 1000.0)
		match r["kind"]:
			"glass":
				for i in 9:
					var o = Vector2(rng.randf_range(-30, 30), rng.randf_range(-12, 12))
					var s = rng.randf_range(4, 10)
					var pl = PackedVector2Array([p + o + Vector2(0, -s), p + o + Vector2(s * 0.6, 0), p + o + Vector2(0, s * 0.4), p + o + Vector2(-s * 0.7, 0)])
					draw_colored_polygon(pl, Color(0.05, 0.04, 0.08, 0.9 * k))
					draw_line(pl[0], pl[1], Color(0.75, 0.72, 0.9, 0.5 * k), 1.0)
			"rubble":
				for i in 8:
					var o = Vector2(rng.randf_range(-28, 28), rng.randf_range(-11, 11))
					var s = rng.randf_range(4, 9)
					draw_rect(Rect2(p + o - Vector2(s, s * 0.6) / 2.0, Vector2(s, s * 0.6)), Color(STONE_D, 0.9 * k))
					draw_rect(Rect2(p + o - Vector2(s, s * 0.6) / 2.0, Vector2(s, 2)), Color(STONE, 0.8 * k))
			_:
				ell(p, 0.5 * k + 0.2, Color(0.6, 0.58, 0.55, 0.35 * k), 1.0, true)
	# the roots of the starved dead
	for r in b.roots:
		var k2: float = clampf(r["t"] / 0.5, 0.0, 1.0) * clampf((r["max"] - r["t"]) / 0.3, 0.0, 1.0)
		var c = S(r["tp"])
		var rng2 = RandomNumberGenerator.new()
		rng2.seed = int(r["seed"] * 100.0)
		for i in 10:
			var a = rng2.randf() * TAU
			var len = rng2.randf_range(0.4, 1.0) * r["R"]
			var pts = PackedVector2Array()
			for j in 6:
				var t = j / 5.0
				pts.append(c + Vector2(cos(a + sin(t * 3.0 + i) * 0.4) * len * t * Iso.HX * 1.41, sin(a + sin(t * 3.0 + i) * 0.4) * len * t * Iso.HX * 0.7))
			draw_polyline(pts, Color(0.1, 0.06, 0.08, 0.9 * k2), 3.0)
		ell(c, r["R"], Color(0.22, 0.12, 0.16, 0.35 * k2), 1.5)
	# burning seals where the sutras burst (The Burning Sutra), and burnt ground where the hundred hands ended
	for sl in b.seals:
		var ks = clampf(sl["t"] / 0.5, 0.0, 1.0)
		var sc = S(sl["tp"])
		ell(sc, sl["R"], Color(AMBER, 0.55 * ks), 2.0)
		ell(sc, sl["R"] * 0.55, Color(PALEGOLD, 0.35 * ks), 1.0)
		for i in 4:
			var aa = b.time * 0.8 + i * PI / 2.0
			draw_rect(Rect2(sc + Vector2(cos(aa) * sl["R"] * 60.0, sin(aa) * sl["R"] * 30.0) - Vector2(2, 2), Vector2(4, 4)), Color(AMBER, 0.8 * ks))
	# tears lying in wait
	for t in b.tears:
		if t["fall"] > 0.0:
			continue
		var p2 = S(t["tp"])
		var a2 = 0.5 + 0.3 * sin(b.time * 4.0 + p2.x)
		draw_circle(p2, 4.0, Color(0.75, 0.9, 1.0, a2))
		draw_circle(p2 + Vector2(-1, -1), 1.5, Color(1, 1, 1, a2))
	# the palm's pull, the lotus, the walk's waves, the clap
	if not b.palm.is_empty():
		var c2 = S(b.hero.tp)
		for i in 3:
			var R: float = b.palm["R"] * fmod(1.0 - b.time * 0.9 + i / 3.0, 1.0)
			ell(c2, R, Color(VOID, 0.4), 1.5)
	if not b.lotus.is_empty():
		var c3 = S(b.hero.tp)
		var R3: float = b.lotus["R"]
		for i in 8:
			var a3: float = b.time * 2.2 + i * TAU / 8.0
			var pts3 = PackedVector2Array()
			for j in 10:
				var aa = a3 + j * 0.12
				var rr = R3 * (0.3 + j * 0.07)
				pts3.append(c3 + Vector2(cos(aa) * rr * Iso.HX * 1.41, sin(aa) * rr * Iso.HX * 0.7))
			draw_polyline(pts3, Color(PALEGOLD, 0.55), 2.0)
		ell(c3, R3, Color(AMBER, 0.5), 2.0)
	for w in b.waves:
		var k4: float = w["t"] / w["dur"]
		ell(S(w["tp"]), w["R"] * k4, Color(0.3, 0.22, 0.4, 0.6 * (1.0 - k4)), 3.0)
	for q in b.claps:
		var k5: float = q["t"] / q["dur"]
		ell(S(q["tp"]), q["R"] * k5, Color(0.85, 0.78, 1.0, 0.7 * (1.0 - k5)), 3.0)
		ell(S(q["tp"]), q["R"] * k5 * 0.7, Color(0.05, 0.03, 0.08, 0.5 * (1.0 - k5)), 5.0)
	for r in b.rings:
		var k6: float = r["t"] / r["max"]
		ell(S(r["tp"]), lerpf(r["R"], r["R0"], k6), Color(r["col"], 0.6 * k6), 2.0)
	# the star's sweep: the arc it has burnt so far
	for c in b.cones:
		if not c.has("sweep"):
			continue
		var cc = S(c["tp"])
		var fade = clampf(1.0 - (c["t"] - c["dur"]) / 0.35, 0.0, 1.0)
		var a0: float = c["a0"]
		var a1: float = c["sweep"]
		var n = 12
		for i in n + 1:
			var a = lerpf(a0, a1, i / float(n))
			var d = Vector2(cos(a), sin(a))
			for j in 4:
				var rr: float = c["R"] * (0.35 + j * 0.2)
				var p3 = Iso.to_screen(c["tp"] + d * rr)
				draw_rect(Rect2(p3 - Vector2(2, 2), Vector2(4, 4)), Color(AMBER if (i + j) % 2 else PALEGOLD, 0.8 * fade))
		var tip = Iso.to_screen(c["tp"] + Vector2(cos(a1), sin(a1)) * c["R"])
		draw_line(cc, tip, Color(PALEGOLD, 0.6 * fade), 2.0)
	# cracks and craters where he lands, the hand that grips from below
	for s in b.slams:
		var k7: float = s["t"] / s["max"]
		match s["kind"]:
			"crater":
				var cp = S(s["tp"])
				ell(cp, s["R"], Color(0.1, 0.08, 0.06, 0.6 * k7), 1.0, true)
				for i in 8:
					var a = i / 8.0 * TAU + 0.3
					draw_line(cp, cp + Vector2(cos(a) * s["R"] * 70.0, sin(a) * s["R"] * 35.0), Color(0.05, 0.04, 0.03, 0.8 * k7), 2.0)
			"implode":
				ell(S(s["tp"]), 1.2 * k7, Color(0.6, 0.58, 0.66, 0.8), 2.0)
	for h in b.hands:
		var m = h["m"]
		var k8 = clampf(h["t"] / 0.25, 0.0, 1.0) * clampf((h["dur"] + 0.4 - h["t"]) / 0.4, 0.0, 1.0)
		var hp = S(h["tp"])
		ell(hp, 0.9, Color(INK, 0.8 * k8), 1.0, true)

# ------------------------------------------------------------------ above the world
func _air() -> void:
	var b = book
	var hp = S(b.hero.tp, b.float_z / 4.0)
	var font = U.font("italic")
	# the hand from below: black fingers closing round the held one
	for h in b.hands:
		var k = clampf(h["t"] / 0.25, 0.0, 1.0) * clampf((h["dur"] + 0.4 - h["t"]) / 0.4, 0.0, 1.0)
		var c = S(h["tp"])
		for i in 5:
			var a = PI + i * PI / 4.0
			var tip = c + Vector2(cos(a) * 34.0, sin(a) * 60.0 - 30.0) * k
			draw_line(c + Vector2(cos(a) * 20, 6), tip, Color(0.06, 0.04, 0.09, 0.95), 7.0)
			draw_line(c + Vector2(cos(a) * 20, 6), tip, Color(0.4, 0.3, 0.6, 0.5), 1.0)
	# stone spears
	for s in b.spikes:
		var k2: float = s["t"] / s["max"]
		var up = minf(1.0, (1.0 - k2) * 5.0) * k2 * 1.6
		var p = S(s["tp"])
		var hgt: float = s["h"] * 4.0 * clampf(up, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 3), p + Vector2(9, 3), p + Vector2(1, -hgt)]), STONE_D)
		draw_line(p + Vector2(-9, 3), p + Vector2(1, -hgt), STONE, 2.0)
	# the pagoda
	for pg in b.pagodas:
		var k3: float = clampf(pg["t"] / 0.3, 0.0, 1.0)
		if pg["done"]:
			k3 = clampf(1.0 - (pg["t"] - pg["dur"]) / 0.3, 0.0, 1.0)
		var c2 = S(pg["tp"])
		for i in 4:
			var w = (46.0 - i * 9.0) * k3
			var y = -i * 30.0 * k3
			draw_rect(Rect2(c2 + Vector2(-w / 2.0, y - 22.0 * k3), Vector2(w, 22.0 * k3)), STONE_D)
			draw_colored_polygon(PackedVector2Array([c2 + Vector2(-w / 2.0 - 10, y - 18 * k3), c2 + Vector2(w / 2.0 + 10, y - 18 * k3), c2 + Vector2(0, y - 30 * k3)]), STONE)
	# his remains of shadow sliding away from the shadowless
	for q in b.shades:
		var k4: float = q["t"] / 1.1
		ell(S(q["tp"]), q["w"] * 1.4, Color(0.05, 0.03, 0.08, 0.6 * k4), 1.0, true)
	# the fist from the sky
	for f in b.fists:
		var k5: float = clampf(f["t"] / f["dur"], 0.0, 1.0)
		var c3 = S(f["tp"])
		if not f["done"]:
			var y0 = -700.0 * (1.0 - k5 * k5) - 60.0
			var col = Color(PALEGOLD, 0.55 + 0.4 * k5)
			var dk = Color(0.35, 0.22, 0.06, 0.9)
			# a fist of light, knuckles down: wrist, back of the hand, four knuckles, the thumb
			draw_rect(Rect2(c3 + Vector2(-20, y0 - 160), Vector2(40, 90)), Color(AMBER, 0.4 + 0.4 * k5))
			draw_rect(Rect2(c3 + Vector2(-34, y0 - 72), Vector2(68, 58)), col)
			draw_rect(Rect2(c3 + Vector2(-34, y0 - 72), Vector2(68, 58)), dk, false, 2.0)
			for i in 4:
				draw_rect(Rect2(c3 + Vector2(-34 + i * 17, y0 - 16), Vector2(16, 16)), col)
				draw_rect(Rect2(c3 + Vector2(-34 + i * 17, y0 - 16), Vector2(16, 16)), dk, false, 1.5)
			draw_rect(Rect2(c3 + Vector2(-46, y0 - 60), Vector2(14, 30)), col)
			draw_rect(Rect2(c3 + Vector2(-46, y0 - 60), Vector2(14, 30)), dk, false, 1.5)
			ell(c3, 1.0 * k5, Color(AMBER, 0.5), 2.0)
		else:
			var kk = clampf(1.0 - (f["t"] - f["dur"]) / 0.5, 0.0, 1.0)
			draw_rect(Rect2(c3 + Vector2(-38, -40), Vector2(76, 40)), Color(PALEGOLD, 0.7 * kk))
	# geysers of white fire
	for g in b.geysers:
		var k6: float = g["t"] / 0.7
		var c4 = S(g["tp"])
		draw_rect(Rect2(c4 + Vector2(-7, -120 * k6), Vector2(14, 120 * k6)), Color(1.0, 0.97, 0.85, 0.8 * k6))
		draw_rect(Rect2(c4 + Vector2(-3, -150 * k6), Vector2(6, 30 * k6)), Color(1, 1, 1, 0.8 * k6))
	# falling tears
	for t in b.tears:
		if t["fall"] <= 0.0:
			continue
		var k7: float = clampf(1.0 - t["fall"] / 0.35, 0.0, 1.0)
		var p2: Vector2 = S(t["from"].lerp(t["tp"], k7), 26.0 * (1.0 - k7) + sin(k7 * PI) * 8.0)
		draw_circle(p2, 3.0, Color(0.75, 0.9, 1.0))
	# paper sutras: the halo behind his head and the loosed ones
	if b.K("ksutra") > 0 and b.halo > 0 and b.nothing_t <= 0.0:
		for i in b.halo:
			var a2: float = -PI / 2.0 + (i - (b.halo - 1) / 2.0) * 0.45 + sin(b.time) * 0.05
			var pp = hp + Vector2(0, -150) + Vector2(cos(a2), sin(a2)) * 36.0
			draw_rect(Rect2(pp - Vector2(4, 8), Vector2(8, 16)), Color(0.94, 0.88, 0.72))
			draw_line(pp + Vector2(0, -6), pp + Vector2(0, 6), Color(0.6, 0.12, 0.1), 1.0)
	for o in b.ofuda:
		var p3 = S(o["tp"], o["z"])
		var s = absf(cos(o["spin"]))
		draw_rect(Rect2(p3 - Vector2(4 * s + 1, 8), Vector2(8 * s + 2, 16)), Color(0.94, 0.88, 0.72))
		draw_rect(Rect2(p3 - Vector2(1, 4), Vector2(2, 8)), Color(AMBER, 0.9))
	# the third eye's beam
	if not b.eye.is_empty():
		var a3: float = b.eye["ang"]
		var from = hp + Vector2(0, -118)
		var to = S(b.hero.tp + Vector2(cos(a3), sin(a3)) * 7.5, 20)
		draw_line(from, to, Color(1, 1, 1, 0.9), 3.0)
		draw_line(from, to, Color(PALEGOLD, 0.5), 7.0)
		draw_circle(from, 4.0, Color.WHITE)
	# the sun he hangs as: beams to what he melts
	if b.sun_t > 0.0:
		draw_circle(hp + Vector2(0, -170), 18.0, Color(PALEGOLD, 0.85))
		draw_circle(hp + Vector2(0, -170), 11.0, Color(1, 1, 1, 0.9))
	for bm in b.beams:
		var k8: float = clampf(bm["t"] / 0.3, 0.0, 1.0)
		var to2 = S(bm["tp"], 12)
		var col2: Color = bm["col"]
		var from2 = hp + Vector2(0, -170 if b.sun_t > 0.0 else -110)
		if bm.get("spit", false):
			draw_line(hp + Vector2(0, -110), to2, Color(0.2, 0.14, 0.14, k8), 3.0)
		else:
			draw_line(from2, to2, Color(col2, 0.85 * k8), 2.0 if bm.get("thread", false) else 4.0)
	# the bell over him
	if not b.bell.is_empty():
		var drop: float = b.bell["drop"] / 0.25
		var top = hp + Vector2(0, -210 - 200 * drop)
		var ring_k: float = b.bell["ring"] / 0.4
		var fade: float = clampf(b.bell["t"] / 0.5, 0.0, 1.0)
		var bc = Color(0.78 + 0.2 * ring_k, 0.6 + 0.2 * ring_k, 0.3, (0.12 + 0.25 * ring_k) * fade)
		var pts = PackedVector2Array()
		for i in 13:
			var t = i / 12.0
			var x = lerpf(-70.0, 70.0, t)
			pts.append(top + Vector2(x * (0.55 + 0.45 * absf(x) / 70.0), 220.0 * (0.35 + 0.65 * pow(absf(x) / 70.0, 3.0)) - 220.0 * 0.35 + 30))
		var shell = PackedVector2Array([top + Vector2(-40, 0), top + Vector2(40, 0), top + Vector2(70, 210), top + Vector2(-70, 210)])
		draw_colored_polygon(shell, bc)
		draw_polyline(PackedVector2Array([top + Vector2(-40, 0), top + Vector2(-70, 210), top + Vector2(70, 210), top + Vector2(40, 0), top + Vector2(-40, 0)]), Color(0.9, 0.75, 0.4, 0.8 * fade), 2.0)
		draw_line(top + Vector2(-60, 170), top + Vector2(60, 170), Color(0.9, 0.75, 0.4, 0.5 * fade), 1.0)
		draw_line(top + Vector2(-48, 60), top + Vector2(48, 60), Color(0.9, 0.75, 0.4, 0.5 * fade), 1.0)
		draw_rect(Rect2(top + Vector2(-8, -16), Vector2(16, 16)), Color(0.9, 0.75, 0.4, 0.8 * fade), false, 2.0)
	# palms: prints of light (the flurry, the thousand arms), black mirrors
	for s in b.slams:
		var k9: float = s["t"] / s["max"]
		var p4 = S(s["tp"], s.get("z", 0.0))
		match s["kind"]:
			"palm":
				var sc: float = s.get("s", 1.0) * 8.0
				var col3 = Color(STONE, 0.9 * k9) if s.get("stone", false) else Color(PALEGOLD, 0.9 * k9)
				draw_rect(Rect2(p4 - Vector2(sc, sc) * 0.6, Vector2(sc * 1.2, sc * 1.2)), col3)
				for i in 4:
					draw_rect(Rect2(p4 + Vector2(-sc * 0.6 + i * sc * 0.32, -sc * 1.3), Vector2(sc * 0.24, sc * 0.7)), col3)
			"arc":
				var a4: float = s["a"]
				var pts2 = PackedVector2Array()
				for i in 13:
					var aa = a4 - 1.4 + i * 2.8 / 12.0
					pts2.append(Iso.to_screen(s["tp"] + Vector2(cos(aa), sin(aa)) * s["R"]) + Vector2(0, -40))
				draw_polyline(pts2, Color(0.1, 0.07, 0.14, 0.85 * k9), 5.0)
			"hole":
				draw_circle(p4 + Vector2(0, -40), 6.0, Color(0.02, 0.02, 0.02, k9))
				draw_arc(p4 + Vector2(0, -40), 7.0, 0, TAU, 16, Color(1.0, 0.7, 0.4, k9), 1.0)
			"mirror":
				draw_rect(Rect2(p4 + Vector2(-16, -90), Vector2(32, 80)), Color(0.05, 0.03, 0.08, 0.7 * k9))
	# the arms closed round him as a shell (The Thousand-Armed reversed)
	if b.shell_t > 0.0:
		var ksh = clampf(b.shell_t / 0.5, 0.0, 1.0)
		for i in 10:
			var a6 = i * TAU / 10.0 + b.time * 0.3
			var p6 = hp + Vector2(cos(a6) * 70.0, sin(a6) * 34.0 - 70.0)
			draw_line(hp + Vector2(0, -80), p6, Color(STONE_D, 0.5 * ksh), 7.0)
			draw_rect(Rect2(p6 - Vector2(6, 6), Vector2(12, 12)), Color(STONE, 0.7 * ksh))
	# the thousand arms: the figure standing up behind him
	if not b.thousand.is_empty():
		var kt = clampf(b.thousand["t"] / 0.35, 0.0, 1.0) * clampf((1.8 - b.thousand["t"]) / 0.4, 0.0, 1.0)
		var c5 = hp + Vector2(0, -60)
		for i in 12:
			var a5 = -PI + i * PI / 11.0
			draw_line(c5 + Vector2(0, -120), c5 + Vector2(cos(a5) * 150.0, -120 + sin(a5) * 110.0), Color(STONE if i % 2 else PALEGOLD, 0.45 * kt), 6.0)
		draw_circle(c5 + Vector2(0, -170), 26.0, Color(STONE, 0.45 * kt))
	# motes
	for m in b.motes:
		var k10: float = clampf(m["t"] / 0.4, 0.0, 1.0)
		draw_rect(Rect2(S(m["tp"], m["z"]) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(m["col"], k10))
	# the words he says, rising
	for w in b.words:
		var k11: float = clampf(w["t"] / 0.4, 0.0, 1.0)
		var p5 = S(w["tp"], 30.0 + (1.0 - w["t"]) * 10.0)
		var sz = 22
		var wd = font.get_string_size(w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(font, p5 + Vector2(-wd / 2.0 + 1, 1), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7 * k11))
		draw_string(font, p5 + Vector2(-wd / 2.0, 0), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(w["col"], k11))
