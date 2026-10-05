extends Node2D
## The Shrine Keeper's transient things, drawn from the skill book's lists (skills/miasmancer.gd) every frame. On the
## floor: miasma clouds (violet, as gas: puffs that drift and breathe, never green), haze and mirage (cold blue-grey),
## traps lying in wait, the lure's charm, rings. Above: the exhalation's rolling ring, the tide, knives and needles,
## the shuriken, the scythe, claw marks, contagion's leaps, her cloud's motes, the words. No glow, no trails.

const U := preload("res://ui/uikit.gd")
var book
var floor_mode := false

const VIOLET := Color8(176, 112, 224)
const VIOLET_D := Color8(138, 74, 184)
const VIOLET_K := Color8(74, 50, 104)
const WARP := Color8(168, 192, 224)
const PALE := Color8(232, 226, 208)
const BONE := Color8(207, 198, 174)

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
	for i in 33:
		var a = i / 32.0 * TAU
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

func _floor() -> void:
	var b = book
	var t: float = b.time
	# miasma clouds: gas in puffs, each puff breathing on its own slow beat
	for c in b.clouds:
		var k = clampf(c["t"] / 0.8, 0.0, 1.0) * clampf((c["max"] - c["t"]) / 0.3 + 0.2, 0.0, 1.0)
		var p = S(c["tp"])
		var haze: bool = c["kind"] == "haze"
		var n = 3 + int(c["R"] * 3.0)
		for i in n:
			var s: float = c["seed"] + i * 1.7
			var a = s + t * (0.25 if i % 2 else -0.2)
			var rr = c["R"] * (0.25 + 0.55 * fmod(s * 0.37, 1.0))
			var q = p + Vector2(cos(a) * rr * Iso.HX * 1.4, sin(a) * rr * Iso.HX * 0.7)
			var pr = c["R"] * (0.35 + 0.2 * sin(t * 1.3 + s)) * 0.9
			var col = (WARP if haze else (VIOLET_K if i % 3 == 0 else VIOLET_D))
			ell(q, pr, Color(col, (0.16 if haze else 0.2) * k), 1.0, true)
		ell(p, c["R"], Color(WARP if haze else VIOLET, 0.18 * k), 1.0)
	for f in b.mirages:
		var km = clampf(f["t"] / 0.5, 0.0, 1.0)
		var pm = S(f["tp"])
		for i in 3:
			ell(pm + Vector2(sin(t * 2.0 + i) * 6.0, 0), f["R"] * (0.6 + 0.2 * i), Color(WARP, 0.25 * km), 1.5)
	for l in b.lures:
		var pl = S(l["tp"])
		draw_line(pl, pl + Vector2(0, -40), BONE, 3.0)
		draw_line(pl + Vector2(-10, -30), pl + Vector2(10, -34), BONE, 2.0)
		ell(pl, l["R"] * (0.3 + 0.7 * fmod(t * 0.8, 1.0)), Color(WARP, 0.3), 1.0)
	for tr in b.traps:
		var pt = S(tr["tp"])
		var armed: bool = tr["arm"] <= 0.0
		match tr["kind"]:
			"ntrap":
				draw_rect(Rect2(pt + Vector2(-6, -10), Vector2(12, 10)), Color8(84, 78, 70))
				for i in 5:
					draw_line(pt + Vector2(-6 + i * 3, -10), pt + Vector2(-8 + i * 4, -18), BONE, 1.0)
			"mwake":
				draw_colored_polygon(PackedVector2Array([pt + Vector2(-8, 0), pt + Vector2(8, 0), pt + Vector2(6, -12), pt + Vector2(-6, -12)]), Color8(90, 64, 28))
				draw_line(pt + Vector2(-6, -12), pt + Vector2(6, -12), Color8(194, 154, 86), 2.0)
			"bmine":
				var sw = 1.0 + 0.08 * sin(t * 3.0)
				ell(pt + Vector2(0, -6), 0.18 * sw, Color8(110, 70, 120), 1.0, true)
				ell(pt + Vector2(-3, -8), 0.06, Color8(170, 130, 180), 1.0, true)
		if not armed:
			draw_circle(pt + Vector2(0, -22), 2.0, Color(PALE, 0.5))
	for r in b.rings:
		var kr: float = r["t"] / r["max"]
		ell(S(r["tp"]), lerpf(r["R"], r["R0"], kr), Color(r["col"], 0.6 * kr), 2.0)
	for n in b.novas:
		var kn = clampf(1.0 - n["r"] / n["max"], 0.0, 1.0)
		ell(S(n["tp"]), n["r"], Color(VIOLET, 0.6 * kn + 0.2), 3.0)
		ell(S(n["tp"]), maxf(0.1, n["r"] - 0.4), Color(VIOLET_K, 0.4 * kn), 5.0)

func _air() -> void:
	var b = book
	var t: float = b.time
	# the tide: a slanting wall of violet breath
	for w in b.tides:
		var k = clampf(w["t"] / 0.3, 0.0, 1.0)
		if w.get("spin", false):
			var c = S(w["c"])
			ell(c, w["w"], Color(VIOLET, 0.5 * k), 4.0)
			var e = S(w["tp"], 8)
			draw_circle(e, 8.0, Color(VIOLET_D, 0.8 * k))
			continue
		var d: Vector2 = w["d"]
		var side = Vector2(-d.y, d.x) * w["w"] / 2.0
		var a = S(w["tp"] - side)
		var bb = S(w["tp"] + side)
		for i in 5:
			var off = Vector2(0, -8.0 - i * 9.0)
			draw_line(a + off, bb + off, Color(VIOLET if i % 2 else VIOLET_D, (0.7 - i * 0.1) * k), 4.0)
	# the shuriken, the thrown scythe
	for s in b.shuris:
		var p = S(s["tp"], 8)
		var sp: float = s["spin"]
		for i in 4:
			var aa = sp + i * PI / 2.0
			draw_line(p, p + Vector2(cos(aa), sin(aa) * 0.6) * 12.0, Color8(40, 36, 44), 3.0)
			draw_line(p, p + Vector2(cos(aa), sin(aa) * 0.6) * 10.0, BONE, 1.0)
	for s in b.scythes:
		var p2 = S(s["tp"], 12)
		draw_arc(p2, 22.0, s["spin"], s["spin"] + PI * 1.2, 12, Color(PALE, 0.9), 3.0)
	# knives and needles
	for kn in b.knives:
		var p3 = S(kn["tp"], 10)
		var v: Vector2 = Iso.to_screen(kn["v"]).normalized()
		draw_line(p3 - v * 8.0, p3 + v * 8.0, BONE, 2.0)
		draw_line(p3 + v * 4.0, p3 + v * 8.0, VIOLET, 2.0)
	# traps in flight
	for th in b.throws:
		var kt = clampf(th["t"] / th["dur"], 0.0, 1.0)
		var p4 = S((th["from"] as Vector2).lerp(th["to"], kt), 18.0 + sin(kt * PI) * 22.0)
		draw_rect(Rect2(p4 - Vector2(4, 4), Vector2(8, 8)), BONE)
	# claw marks: three thin rakes; the arc and the thrust as a single pale cut
	for c in b.clawfx:
		var kc = clampf(c["t"] / 0.2, 0.0, 1.0)
		var pc = S(c["tp"], 10)
		if c.has("arc"):
			var R: float = c["arc"]
			var pts = PackedVector2Array()
			var a0 = -PI if c.get("full", false) else c["a"] - 1.45
			var a1 = PI if c.get("full", false) else c["a"] + 1.45
			for i in 17:
				var aa = lerpf(a0, a1, i / 16.0)
				pts.append(S(c["tp"] + Vector2(cos(aa), sin(aa)) * R, 10))
			draw_polyline(pts, Color(PALE, 0.7 * kc), 2.0)
		elif c.has("line"):
			var e2 = S(c["tp"] + Vector2(cos(c["a"]), sin(c["a"])) * c["line"], 10)
			draw_line(pc, e2, Color(PALE, 0.8 * kc), 2.0)
		else:
			var dv = Vector2(cos(c["a"]), sin(c["a"]) * 0.6)
			var nv = Vector2(-dv.y, dv.x)
			for i in 3:
				var o = nv * (i - 1) * 7.0
				draw_line(pc + o - dv * 14.0, pc + o + dv * 14.0, Color(PALE, 0.85 * kc), 1.5)
	# contagion leaping between the sick
	for z in b.zaps:
		var kz = clampf(z["t"] / 0.2, 0.0, 1.0)
		draw_line(S(z["a"], 12), S(z["b"], 12), Color(VIOLET, 0.8 * kz), 2.0)
	# motes of her breath
	for m in b.motes:
		var km = clampf(m["t"] / 0.4, 0.0, 1.0)
		draw_rect(Rect2(S(m["tp"], m["z"]) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(m["col"], 0.8 * km))
	# the haze wrapped round her (The Hanged Man reversed)
	if b.haze_mantle > 0.0:
		ell(S(b.hero.tp), 1.9, Color(WARP, 0.35), 2.0)
	var font = U.font("italic")
	for w in b.words:
		var kw = clampf(w["t"] / 0.4, 0.0, 1.0)
		var pw = S(w["tp"], 30.0 + (1.0 - w["t"]) * 10.0)
		var wd = font.get_string_size(w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, pw + Vector2(-wd / 2.0 + 1, 1), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.7 * kw))
		draw_string(font, pw + Vector2(-wd / 2.0, 0), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(w["col"], kw))
