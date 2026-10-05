extends Node2D
## Blood, bone and viscera for the waystone passage (zz_zz_maw95.js gore / reform / stains / drips): matter, never light.
## Pieces fly and fall; some stay on the ground a while; stains fade over forty seconds; at a rising, pieces are drawn
## back in to where the body is forming; afterwards the hero drips for a few seconds. Positions in tiles, heights and
## sizes in the web's world px (x4).

const BLOOD := [Color8(0x3a, 0x08, 0x0b), Color8(0x52, 0x0c, 0x10), Color8(0x6a, 0x12, 0x16)]
const BONE := [Color8(0xcd, 0xbf, 0xa0), Color8(0xa8, 0x99, 0x7a), Color8(0xe2, 0xd6, 0xbb)]
const MEAT := [Color8(0x5a, 0x2a, 0x2a), Color8(0x7a, 0x3a, 0x36), Color8(0x40, 0x18, 0x1a), Color8(0x6e, 0x4a, 0x3e)]

var parts: Array = []    # {p: tile pos, z, v: tile/s, vz, t, col, w}
var chunks: Array = []   # {p, col, w, life}
var reform_l: Array = [] # {p0, z0, t, dur, w, col}
var stains: Node2D
var hero: Node2D
var drips := 0.0

class Stains extends Node2D:
	var list: Array = []   # {p, dots: [[dx, dy, w]], life}
	func _process(dt: float) -> void:
		for s in list:
			s["life"] -= dt
		list = list.filter(func(s): return s["life"] > 0.0)
		queue_redraw()
	func _draw() -> void:
		for s in list:
			var q := Iso.to_screen(s["p"])
			var a := minf(1.0, s["life"] / 6.0) * 0.85
			var c := Color(40 / 255.0, 6 / 255.0, 9 / 255.0, a)
			for d in s["dots"]:
				draw_rect(Rect2(q.x + roundf(d[0]) * Iso.WPX, q.y + roundf(d[1]) * Iso.WPX, d[2] * Iso.WPX, Iso.WPX), c)

func setup(zone: Zone) -> void:
	z_index = 4
	stains = Stains.new()
	stains.z_index = 3
	zone.floor_layer.add_child(stains)

static func _pick(a: Array) -> Color:
	return a[randi() % a.size()]

## a spray of pieces at p; up = thrown higher (the throat giving way)
func gore(p: Vector2, n: int, up: bool) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 0.6 + randf() * 2.2
		var r := randf()
		var col: Color = _pick(BLOOD) if r < 0.6 else (_pick(MEAT) if r < 0.8 else _pick(BONE))
		parts.append({"p": p, "z": 4.0 + randf() * (24.0 if up else 8.0), "v": Vector2(cos(a), sin(a)) * s,
			"vz": 12.0 + randf() * (34.0 if up else 16.0), "t": 0.6 + randf() * 0.7, "col": col, "w": 1 + randi() % 2})
		if r > 0.6 and chunks.size() < 60:
			chunks.append({"p": p + Vector2(cos(a), sin(a)) * s * 0.35, "col": col, "w": 1 + randi() % 2, "life": 5.0 + randf() * 4.0})
	if parts.size() > 700:
		parts = parts.slice(parts.size() - 700)

func stain(p: Vector2, n: int, r: float) -> void:
	var dots := []
	for i in n:
		var a := randf() * TAU
		var d := randf() * r
		dots.append([cos(a) * d * 1.6, sin(a) * d * 0.8, 1 + randi() % 3])
	stains.list.append({"p": p, "dots": dots, "life": 40.0})
	if stains.list.size() > 12:
		stains.list.pop_front()

## blood, bone and viscera drawn back in from the pit and the ground to where the body is forming
func reform(at: Vector2, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var d := 0.8 + randf() * 1.6
		var r := randf()
		var col: Color = _pick(BLOOD) if r < 0.6 else (_pick(MEAT.slice(0, 2)) if r < 0.8 else _pick(BONE.slice(0, 2)))
		reform_l.append({"p0": at + Vector2(cos(a) * d, sin(a) * d * 0.8), "z0": randf() * 3.0, "t": -randf() * 0.5,
			"dur": 0.5 + randf() * 0.4, "w": 1 + randi() % 2, "col": col})

func _process(dt: float) -> void:
	for p in parts:
		p["t"] -= dt
		p["p"] += p["v"] * dt
		p["v"] *= maxf(0.0, 1.0 - dt * 2.0)
		p["vz"] -= 90.0 * dt
		p["z"] = maxf(0.0, p["z"] + p["vz"] * dt)
	parts = parts.filter(func(p): return p["t"] > 0.0)
	for c in chunks:
		c["life"] -= dt
	chunks = chunks.filter(func(c): return c["life"] > 0.0)
	for r in reform_l:
		r["t"] += dt
	reform_l = reform_l.filter(func(r): return r["t"] < r["dur"])
	drips = maxf(0.0, drips - dt)
	queue_redraw()

func _draw() -> void:
	var W := Iso.WPX
	for c in chunks:
		var q := Iso.to_screen(c["p"])
		var col: Color = c["col"]
		col.a = minf(1.0, c["life"] / 1.5)
		draw_rect(Rect2(roundf(q.x / W) * W, roundf(q.y / W) * W, (c["w"] + 1) * W, c["w"] * W), col)
	for p in parts:
		var q := Iso.to_screen(p["p"])
		draw_rect(Rect2(roundf(q.x / W) * W, roundf((q.y - p["z"] * W) / W) * W, p["w"] * W, p["w"] * W), p["col"])
	if hero and is_instance_valid(hero):
		var hp: Vector2 = hero.tp
		for r in reform_l:
			if r["t"] < 0.0:
				continue
			var k := minf(1.0, r["t"] / r["dur"])
			var e := k * k
			var at: Vector2 = r["p0"].lerp(hp, e)
			var q := Iso.to_screen(at)
			var z: float = r["z0"] + (18.0 - r["z0"]) * e
			draw_rect(Rect2(roundf(q.x / W) * W, roundf((q.y - z * W) / W) * W, r["w"] * W, r["w"] * W), r["col"])
		if drips > 0.0:
			var q := Iso.to_screen(hp)
			var kk := minf(1.0, drips / 2.0)
			var tt := Time.get_ticks_msec() / 1000.0
			for i in 6:
				var h := fmod(tt * 0.8 + i * 0.37, 1.0)
				var x := roundf(q.x / W - 6 + i * 2.4)
				var y := roundf(q.y / W - 30 + float((i * 3) % 9) + h * 26)
				draw_rect(Rect2(x * W, y * W, W, 2 * W), Color(74 / 255.0, 13 / 255.0, 16 / 255.0, 0.8 * kk * (1.0 - h)))
