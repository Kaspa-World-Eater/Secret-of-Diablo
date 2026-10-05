extends Node2D
## The Mystic's transient things, drawn from the skill book's lists every frame. Two of these live in a zone: one on
## the floor layer (cracked glass, sigils, the storm's eye, the procession's worn ring, pale ground fires) and one
## above the world (threads, needles, sparks, souls, darts, shards, glass, the golem's thrown shield and its beam).
## Everything is thin and pale: no glow, no comet tails, no swing arcs (rules in PORTING.md; zz_zz_mystic90.js and
## zz_zz_thread93.js drawing: "thin, pale, no glow").

var book
var floor_mode := false

const PALE := Color(0.84, 0.86, 0.82)
const THREAD := Color("#aebdc6")   # the web's Soul Leash (zz_zz_thread93.js:137)
const SNAG := Color("#c9d6de")
const BIND := Color("#d6cfbf")
const SOUL := Color(0.9, 0.95, 0.98)
const GLASS := Color(0.81, 0.91, 0.98)

func _process(_dt: float) -> void:
	if book == null or book.fx_air != self and book.fx_floor != self:
		queue_free()
		return
	queue_redraw()

static func S(tp: Vector2, z: float = 0.0) -> Vector2:
	return Iso.to_screen(tp) + Vector2(0, -z * 4.0)

## one cell of the art grid (1 web px = 4 px here), at a screen point
func cell(p: Vector2, col: Color, cw: float = 1.0, ch: float = 1.0) -> void:
	var g := global_position
	var q := Vector2(floor((p.x + g.x) / 4.0) * 4.0, floor((p.y + g.y) / 4.0) * 4.0) - g
	draw_rect(Rect2(q, Vector2(cw, ch) * 4.0), col)

## a line one web px wide, stepped on the art grid (the web's 1 px canvas strokes)
func pix_line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / 4.0))
	for i in n + 1:
		cell(a.lerp(b, i / float(n)), col)

## a thread that sags between two screen points (zz_zz_mystic90 sag: a quadratic one web px wide), laid on the art
## grid, with the user's ghostly shimmer: a faint brightening that runs along it (HANDOFF §5.5)
func sag(a: Vector2, b: Vector2, s: float, col: Color, _w: float = 2.0) -> void:
	var mid := (a + b) * 0.5 + Vector2(0, s)
	var n := maxi(2, int((a.distance_to(mid) + mid.distance_to(b)) / 4.0))
	var g := global_position
	var seen := {}
	var t0: float = book.time if book else 0.0
	for i in n + 1:
		var t := i / float(n)
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		var key := Vector2i(int(floor((p.x + g.x) / 4.0)), int(floor((p.y + g.y) / 4.0)))
		if seen.has(key):
			continue
		seen[key] = true
		var sh := 0.85 + 0.15 * sin(t * 9.0 - t0 * 4.0)
		cell(p, Color(col.r, col.g, col.b, col.a * sh))

func ellipse(c: Vector2, R: float, col: Color, w: float = 2.0, dashed: bool = false) -> void:
	var rx := R * Iso.HX * 1.414
	var ry := rx * 0.5
	var n := 40
	if dashed:
		for i in n:
			if i % 3 != 0:
				continue
			var a0 := i / float(n) * TAU
			var a1 := (i + 1) / float(n) * TAU
			draw_line(c + Vector2(cos(a0) * rx, sin(a0) * ry), c + Vector2(cos(a1) * rx, sin(a1) * ry), col, w)
		return
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := i / float(n) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)

func mote(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r, Color(col.r, col.g, col.b, col.a * 0.35))
	draw_circle(p, r * 0.5, col)

func _draw() -> void:
	if book == null or book.zone == null:
		return
	if floor_mode:
		_floor()
	else:
		_air()

# ------------------------------------------------------------------ on the ground
func _floor() -> void:
	var b = book
	for c in b.cracks:       # cracked mirror-glass lying in the ground
		var k: float = clampf(c["t"] / 0.6, 0.0, 1.0)
		var p := S(c["tp"])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(c["v"])
		var pl := PackedVector2Array()
		for i in 6:
			var a := i / 6.0 * TAU + rng.randf() * 0.4
			pl.append(p + Vector2(cos(a) * rng.randf_range(20, 34), sin(a) * rng.randf_range(10, 17)))
		draw_colored_polygon(pl, Color(0.5, 0.66, 0.8, 0.5 * k))
		for i in 4:
			var a := rng.randf() * TAU
			draw_line(p, p + Vector2(cos(a) * 26, sin(a) * 13), Color(0.05, 0.06, 0.09, 0.8 * k), 1.5)
		draw_line(p + Vector2(-10, -3), p + Vector2(-2, -6), Color(1, 1, 1, 0.5 * k), 1.0)
	for f in b.fires:        # pale ground fire from the berserk golem's beam
		var k2: float = clampf(f["t"] / f["max"], 0.0, 1.0)
		ellipse(S(f["tp"]), f["R"], Color(0.8, 0.92, 0.78, 0.25 * k2), 1.5)
	for w in b.words:        # Unravelling's sigil
		if w["t"] < 0.0:
			continue
		var k3: float = 1.0 - clampf((w["t"] - w["dur"]) / 0.3, 0.0, 1.0)
		var c2 := S(w["tp"])
		ellipse(c2, w["R"], Color(0.9, 0.9, 0.86, 0.45 * k3), 2.0)
		ellipse(c2, w["R"] * 0.62, Color(0.9, 0.9, 0.86, 0.3 * k3), 1.5)
		var rot: float = w["seed"] + w["t"] * 0.8
		var rx: float = w["R"] * Iso.HX * 1.414
		for i in 6:
			var a0 := rot + i * TAU / 6.0
			var a1 := rot + (i + 2) * TAU / 6.0
			draw_line(c2 + Vector2(cos(a0) * rx, sin(a0) * rx * 0.5), c2 + Vector2(cos(a1) * rx, sin(a1) * rx * 0.5), Color(0.9, 0.9, 0.86, 0.35 * k3), 1.5)
	for s in b.storms:       # the storm's throat: a slow turning on the ground
		var c3 := S(s["tp"])
		for i in 3:
			var a: float = s["spin"] + i * TAU / 3.0
			var pts := PackedVector2Array()
			for j in 12:
				var aa := a + j * 0.18
				var rr := 0.3 + j * 0.12
				pts.append(c3 + Vector2(cos(aa) * rr * Iso.HX, sin(aa) * rr * Iso.HY))
			draw_polyline(pts, Color(0.8, 0.86, 0.9, 0.35), 1.5, true)
	for r in b.rings:        # thin, faint rings where a blow lands wide (no glow)
		var k4: float = r["t"] / r["max"]
		var R: float = lerpf(r["R"], r["R0"], k4)
		ellipse(S(r["tp"]), R, Color(0.88, 0.9, 0.9, 0.3 * k4), 1.5)
	var pr: Dictionary = b.proc
	if pr["on"]:             # the procession's worn ring
		pix_ring(S(pr["tp"]), b.proc_r(), Color(200 / 255.0, 214 / 255.0, 222 / 255.0, 0.18))   # dashed [2,4] (zz_zz_thread93.js:142-146)

# ------------------------------------------------------------------ above the world
func _air() -> void:
	var b = book
	# Binding Thread: threads from the held one to the bound, drawing taut
	for bd in b.binds:
		var A = bd["a"]
		if not is_instance_valid(A):
			continue
		var k: float = 0.0 if bd["done"] else 1.0 - bd["t"] / bd["dur"]
		var al: float = 0.6 * (1.0 - bd["fade"] / 0.3) if bd["done"] else 0.6
		var pa := S(A.tp, 11)
		for e in bd["bound"]:
			var m = e
			if not is_instance_valid(m) or m.dead:
				continue
			sag(pa, S(m.tp, 11), (2.0 + k * 12.0) * 4.0, Color(BIND.r, BIND.g, BIND.b, al))
		if not bd["done"]:   # the knot on the held one
			cell(S(A.tp, 12) + Vector2(-4, 0), Color(BIND.r, BIND.g, BIND.b, 0.7), 2.0, 2.0)
	# Soul Leash: pale threads from the wisps to what they hold
	for th in b.threads:
		var m = th["m"]
		if not is_instance_valid(m) or m.dead:
			continue
		var s: Vector3 = b.thread_src(th)
		var f: float = minf(1.0, th["life"] / 0.3) * minf(1.0, (th["max"] - th["life"]) / 0.12 + 0.2)
		var a := S(Vector2(s.x, s.y), s.z)
		var e := S(m.tp, 10)
		sag(a, e, (8.0 + 4.0 * sin(b.time * 3.0 + a.x * 0.025)) * 4.0, Color(THREAD.r, THREAD.g, THREAD.b, 0.38 * f))
	# snags: a wisp's strike catches a thread on the foe
	for sn in b.snags:
		var m2 = sn["m"]
		if not is_instance_valid(m2) or m2.dead:
			continue
		var k2: float = 1.0 - sn["t"] / sn["dur"]
		sag(S(sn["tp"], 9), S(m2.tp, 10), (6.0 * k2 + 1.0) * 4.0, Color(SNAG.r, SNAG.g, SNAG.b, 0.5 * k2))
	# needles: a short pale dash that runs out and is gone
	for n in b.needles:
		var k3: float = n["t"] / n["dur"]
		var s1: float = n["end"] * k3
		var s0: float = maxf(0.0, s1 - 0.7)
		pix_line(S(n["tp"] + n["d"] * s0, 10), S(n["tp"] + n["d"] * s1, 10), Color(0.722, 0.816, 0.871, 0.5 * (1.0 - k3 * 0.5)))   # #b8d0de
	# sparks: motes like the wisps themselves
	for sp in b.sparks:
		var tr: Array = sp.get("trail", [])
		for i in tr.size():   # a 3-point trail, then a 2x2 spark (zz_zz_mystic90.js:158-160)
			cell(S(tr[i], sp["z"]), Color(200 / 255.0, 228 / 255.0, 240 / 255.0, 0.15 + i * 0.12))
		cell(S(sp["tp"], sp["z"]) + Vector2(-4, -4), Color("#e4f4fa"), 2.0, 2.0)
	# seeking souls (Soul Swarm, Soul Storm, the golem's overflow, a branded death)
	for so in b.souls:
		mote(S(so["tp"], 9.0 + sin(so["wob"]) * 1.5), 5.0, Color(SOUL.r, SOUL.g, SOUL.b, 0.85))
	# Needle and Thread: the darting wisp, and a thread left hanging where it turned
	for dl in b.dart_lines:
		var k4: float = dl["t"] / 0.35
		draw_line(S(dl["a"], dl["za"]), S(dl["b"], dl["zb"]), Color(0.78, 0.86, 0.9, 0.4 * k4), 1.5)
	for d in b.darts:
		mote(S(d["tp"], d["z"]), 6.0 if not d.get("small", false) else 4.0, Color(0.92, 0.97, 1.0, 0.95))
	# Spool: the slow white orb and its shards
	for o in b.orbs:
		var p := S(o["tp"], 12)
		draw_circle(p, 13.0 if o["gen"] == 0 else 8.0, Color(0.93, 0.94, 0.92, 0.85))
		draw_circle(p, 7.0 if o["gen"] == 0 else 4.0, Color(1, 1, 1, 0.95))
	for sh in b.shards:
		var dv: Vector2 = (S(sh["tp"] + sh["v"].normalized() * 0.2) - S(sh["tp"])).normalized()
		var p2 := S(sh["tp"], 10)
		draw_line(p2 - dv * 8.0, p2 + dv * 4.0, Color(0.95, 0.95, 0.92, 0.9), 2.0)
	# flying mirror-glass: slivers from the fissure's flanks and the great mirror's burst
	for gs in b.gshots:
		var p3 := S(gs["tp"], 8)
		var dv2: Vector2 = (S(gs["tp"] + gs["v"].normalized() * 0.2) - S(gs["tp"])).normalized()
		draw_line(p3 - dv2 * 7.0, p3 + dv2 * 3.0, GLASS, 2.0)
	for g in b.glass:        # glass that falls and lies a moment
		var p4 := S(g["tp"], g["z"])
		draw_rect(Rect2(p4 - Vector2(2, 2), Vector2(4, 4) * g["s"]), Color(0.82, 0.9, 0.98, clampf(g["t"] / 0.4, 0.0, 1.0)))
	for s2 in b.spikes:      # jagged slivers bursting up from the crack
		var k5: float = s2["t"] / s2["max"]
		var p5 := S(s2["tp"])
		var hgt := 44.0 * minf(1.0, (1.0 - k5) * 6.0) * (0.4 + 0.6 * k5)
		var v: int = s2["v"]
		for i in 3:
			var ox := (i - 1) * 9.0 + v * 2.0
			draw_colored_polygon(PackedVector2Array([p5 + Vector2(ox - 5, 0), p5 + Vector2(ox + 1, -hgt * (0.6 + 0.2 * ((i + v) % 3))), p5 + Vector2(ox + 5, 0)]), Color(0.66, 0.8, 0.92, 0.9))
			draw_line(p5 + Vector2(ox - 4, -2), p5 + Vector2(ox + 1, -hgt * (0.6 + 0.2 * ((i + v) % 3))), Color(1, 1, 1, 0.7), 1.0)
	# Rebuke: a lash of pale light that sweeps and curls
	for wh in b.whips:
		if wh.has("pts"):
			var pts := PackedVector2Array()
			for q in wh["pts"]:
				pts.append(S(q, 10))
			draw_polyline(pts, Color(0.95, 0.95, 0.92, 0.7), 2.0, true)
	# Phantom Step: afterimages of the Mystic
	for ph in b.phantoms:
		if ph["tex"] == null:
			continue
		var a2: float = 0.2 + 0.3 * (1.0 - ph["t"] / 0.8)
		var tex: Texture2D = ph["tex"]
		var off: Vector2 = ph["off"]
		draw_set_transform(S(ph["tp"]) + Vector2(off.x + (tex.get_size().x if ph["flip"] else 0.0), off.y), 0.0, Vector2(-1 if ph["flip"] else 1, 1))
		draw_texture(tex, Vector2.ZERO, Color(0.75, 0.85, 0.95, a2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the golem's thrown shield, and its thin beam while berserk
	var gm = b.golem
	if gm != null:
		if not gm.fly.is_empty():
			var sp2 := S(gm.fly["tp"], 14)
			var sq: float = absf(cos(gm.fly["spin"]))
			draw_colored_polygon(_oval(sp2, 20.0 * (0.35 + 0.65 * sq), 26.0), Color("#9aa2b4"))
			draw_colored_polygon(_oval(sp2, 14.0 * (0.35 + 0.65 * sq), 19.0), Color("#cfe8fa"))
			draw_line(sp2 + Vector2(-4 * sq, -10), sp2 + Vector2(2 * sq, 4), Color(1, 1, 1, 0.8), 2.0)
		if not gm.phos.is_empty():
			draw_line(S(gm.tp, 20), S(gm.phos["end"], 4), Color(0.9, 1.0, 0.86, 0.55), 2.0)
	# the lantern's wisps loose thin lines at what stands in its light
	for tb in b.totem_beams:
		draw_line(S(tb["a"], tb["za"]), S(tb["b"], 9), Color(0.93, 0.92, 0.84, 0.4 * tb["t"] / 0.2), 1.5)
	# Needle's Mark: a true name blisters in the air above the branded
	for m3 in b.mons():
		if m3.marked > 0.0 and m3.has_meta("mys_mark"):
			var p6: Vector2 = m3.position + Vector2(0, -150 - m3.z_lift * 0.0)
			var al2 := clampf(m3.marked / 0.5, 0.0, 1.0) * 0.6
			var seed: int = m3.get_instance_id() % 7
			for i in 4:
				var x0: float = -12 + i * 7 + (seed % 3)
				draw_line(p6 + Vector2(x0, -4 + (i + seed) % 3 * 2), p6 + Vector2(x0 + 4, 4 - (i * seed) % 3 * 2), Color(0.92, 0.9, 0.84, al2), 1.5)

func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## a ring on the ground one web px wide, dashed two on and four off along its length, on the art grid
func pix_ring(c: Vector2, R: float, col: Color) -> void:
	var rx := R * Iso.HX * 1.414
	var ry := rx * 0.5
	var n := maxi(24, int(TAU * rx / 4.0))
	var run := 0.0
	var last := c + Vector2(rx, 0)
	for i in n:
		var a := i / float(n) * TAU
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		run += p.distance_to(last) / 4.0
		last = p
		if fmod(run, 6.0) < 2.0:
			cell(p, col)
