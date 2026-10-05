extends Node2D
## The Ossuarch's transient things, drawn from his skill book's lists every frame (skills/ossumancer/*.gd).
## On the floor: grit where bone tears out of the ground. Above: the Mantle (shards hanging about him in a loose,
## slow drift, more as it fills), shards flying in to him, Bone Lances grown dead straight, small words.
## Bone is matter, never light: pale, flat, stepped at the pixel grain. No glow, no trails.

const U := preload("res://ui/uikit.gd")
const P := 3.0                # the pixel grain: the heroes' own (3 scene px an art pixel)
var book
var floor_mode := false

const BONE := Color8(232, 226, 208)
const BONE_M := Color8(196, 188, 164)
const BONE_D := Color8(140, 132, 112)
const GRIT := Color8(92, 86, 74)

var rings: Array = []     # D2's Bone Spear trail (BoneSpearTrail): rings left along the flight, expanding and fading
var ring_t := 0.0
var spear_lights: Array = []   # a small cold light that rides each spear (D2R lights the dark round it)
var spear_cv: Node2D       # the spears' own canvas: unshaded, so the night never dims them (D2R's spear lights itself)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # the rendered spear keeps its pixels
	spear_cv = Node2D.new()
	spear_cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	spear_cv.material = mat
	# above the dark layer (world/dark_layer.gd is CanvasLayer 5), following the camera like the world: D2R's spear
	# lights itself, so the night and the lanterns' warmth never dim or tint it
	var over := CanvasLayer.new()
	over.layer = 6
	over.follow_viewport_enabled = true
	add_child(over)
	over.add_child(spear_cv)
	spear_cv.draw.connect(_draw_spears)
	for i in 4:
		var pl := PointLight2D.new()
		pl.color = Color(0.72, 0.84, 1.0)
		pl.energy = 0.9
		pl.visible = false
		pl.set_meta("dark_r", 16.0)
		add_child(pl)
		spear_lights.append(pl)

func _process(dt: float) -> void:
	_spear_trail(dt)
	if book == null or (book.fx_air != self and book.fx_floor != self):
		queue_free()
		return
	queue_redraw()
	if spear_cv:
		spear_cv.queue_redraw()

static func S(tp: Vector2, z: float = 0.0) -> Vector2:
	return Iso.to_screen(tp) + Vector2(0, -z * 4.0)

func px(p: Vector2, col: Color, n: float = 1.0) -> void:
	draw_rect(Rect2(Vector2(floorf(p.x / P) * P, floorf(p.y / P) * P), Vector2(P * n, P * n)), col)

## a sliver of bone from a to b in the grain: a light edge on a darker body
func sliver(a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	var n := maxi(1, int(a.distance_to(b) / P))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		px(q, col if i < n else BONE, w)

func _draw() -> void:
	if book == null or book.zone == null or book.hero == null:
		return
	if floor_mode:
		for g in book.grit:
			var k: float = clampf(g["t"] / 0.4, 0.0, 1.0)
			px(S(g["tp"]), Color(GRIT, 0.8 * k))
		# the Pale Lords' white waymarks
		for l in book.lords:
			var c := S(l["tp"])
			draw_rect(Rect2(c + Vector2(-14, -6), Vector2(28, 12)), Color(0.16, 0.15, 0.14, 0.5))
			draw_rect(Rect2(c + Vector2(-12, -14), Vector2(24, 12)), Color8(222, 218, 206))
			draw_rect(Rect2(c + Vector2(-12, -4), Vector2(24, 4)), Color8(170, 164, 150))
		# Marrow Siphon: the cone, scored in the dust
		for f in book.siph_fx:
			var k: float = clampf(f["t"] / 0.3, 0.0, 1.0)
			for side in [-0.75, 0.0, 0.75]:
				var d: Vector2 = f["dir"].rotated(side)
				sliver(S(f["tp"]), S(f["tp"] + d * f["R"] * (1.0 - 0.3 * absf(side))), Color(BONE_D, 0.6 * k))
		# Ossify's ring and the spurs' roots
		for f in book.spikes_fx:
			if f.get("ring", false):
				var k2: float = clampf(f["t"] / 0.5, 0.0, 1.0)
				for i in 24:
					var ang := i / 24.0 * TAU
					px(S(f["tp"] + Vector2(cos(ang), sin(ang)) * f["len"] * (1.0 - k2 * 0.3)), Color(BONE_M, 0.7 * k2))
		return
	var hero = book.hero
	var t: float = book.time
	# the Mantle: shards hanging about him, drifting slowly round at hip to shoulder height
	var n := mini(int(book.shards), 40)
	for i in n:
		var s := i * 2.399
		var a := s + t * (0.35 + 0.04 * (i % 5)) * (1.0 if i % 2 else -1.0)
		var r := 0.55 + 0.35 * fmod(s * 0.61, 1.0) + 0.1 * sin(t * 0.7 + s)
		var z := 6.0 + 20.0 * fmod(s * 0.37, 1.0) + 2.0 * sin(t * 1.3 + s)
		var c: Vector2 = S(hero.tp + Vector2(cos(a), sin(a)) * r, z)
		var d := Vector2(cos(a + 1.3), sin(a + 1.3) * 0.5) * 6.0
		sliver(c - d, c + d, BONE_M if i % 3 else BONE_D)
	# shards flying in
	for b in book.motes:
		var c := S(b["tp"], b["z"])
		var to: Vector2 = S(hero.tp, 6.0) - c
		var d := to.normalized() * 6.0 if to.length() > 0.1 else Vector2(6, 0)
		sliver(c - d, c + d, BONE_M)
	# Bone Lances: a long straight spear of packed bone (splinters and the Storm's shards are slivers)
	for sp in book.spears:
		var c := S(sp["tp"], 8.0)
		var u: Vector2 = Iso.to_screen(sp["v"].normalized()).normalized()
		if sp["small"]:
			sliver(c - u * 9.0, c + u * 9.0, BONE_M)
		elif SPEAR_TEX != null:
			pass                                      # drawn on the unshaded canvas (_draw_spears)
		else:
			lance(c, u, int(sp.get("tier", 0)), 1.0)
	# the lance growing at his side while he charges it
	if not book.charging.is_empty():
		var ch: Dictionary = book.charging
		var tier: int = ch["tier"]
		var nxt: float = book.LANCE_T[mini(tier, 2)]
		var prev: float = 0.0 if tier == 0 else book.LANCE_T[tier - 1]
		var grow := 1.0 if tier >= 3 else clampf((ch["t"] - prev) / maxf(0.01, nxt - prev), 0.0, 1.0)
		var dir: Vector2 = ch["at"] - hero.tp
		var u2: Vector2 = Iso.to_screen(dir.normalized() if dir.length() > 0.05 else Vector2(1, 1).normalized()).normalized()
		var side := Vector2(-u2.y, u2.x) * (1.0 if u2.x >= 0.0 else -1.0)
		var rise := clampf(ch["t"] / 0.2, 0.0, 1.0)
		if SPEAR_TEX != null:
			pass                                      # drawn on the unshaded canvas (_draw_spears)
		else:
			lance(S(hero.tp, 4.0 + 10.0 * rise) + side * 16.0, u2, tier, 0.55 + 0.45 * grow)
	_draw_blade(hero)
	# Charnel Cages: ribs curving up round the ring, lumpy arms gripping inside
	for c in book.cages:
		var k: float = clampf((c["max"] - c["t"]) / 0.15, 0.0, 1.0) * clampf(c["t"] / 0.3, 0.0, 1.0)
		for i in 10:
			var ang: float = i / 10.0 * TAU + c["seed"]
			var base: Vector2 = c["tp"] + Vector2(cos(ang), sin(ang)) * c["R"]
			var top: Vector2 = c["tp"] + Vector2(cos(ang), sin(ang)) * c["R"] * 0.35
			sliver(S(base), S(top, 22.0 * k), BONE_M if i % 2 else BONE_D, 1.0)
		for i in 4:
			var ang2: float = i * 1.9 + c["seed"]
			var q: Vector2 = c["tp"] + Vector2(cos(ang2), sin(ang2)) * c["R"] * 0.5
			sliver(S(q), S(q, 12.0 * k) + Vector2(sin(book.time * 3.0 + i) * 3.0, 0), BONE_D)
	# spurs bursting from a wound: jagged, wild bone
	for f in book.spikes_fx:
		if f.get("ring", false):
			continue
		var k3: float = clampf(f["t"] / 0.5, 0.0, 1.0)
		var tip: Vector2 = f["tp"] + Vector2(cos(f["a"]), sin(f["a"])) * f["len"]
		sliver(S(f["tp"], 4.0), S(tip, 10.0 * k3), Color(BONE, k3))
	# Bone Rain: straight falling shards
	for r in book.rains:
		for d in r["drops"]:
			var c2 := S(d["tp"], d["z"] / 4.0)
			sliver(c2 - Vector2(0, 10), c2, BONE_M)
	# small words
	var font = U.font("italic")
	for w in book.words:
		var kw: float = clampf(w["t"] / 0.4, 0.0, 1.0)
		var pw := S(w["tp"], 30.0 + (1.0 - w["t"]) * 10.0)
		var wd := font.get_string_size(w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, pw + Vector2(-wd / 2.0 + 1, 1), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.7 * kw))
		draw_string(font, pw + Vector2(-wd / 2.0, 0), w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(w["col"], kw))


## The Bone Spear after Diablo II Resurrected's (2026-10-05, Derek: "very very close to the bone spear in d2r"): the
## rendered spear (docs/concepts/bone_spear: a jagged spike of pale cold bone, knuckled like a spine, barbs swept back),
## the heading nearest its flight out of 32, and in flight D2R's pale blue-white streak tapering away behind it with a
## few wisps curling off it and a faint cold halo. Bigger with each tier of the charge.
static var SPEAR_TEX: Texture2D = load("res://art/fx/bone_spear.png") if ResourceLoader.exists("res://art/fx/bone_spear.png") else null
static var SPEAR_FR: Array = _spear_frames()

static func _spear_frames() -> Array:
	if not FileAccess.file_exists("res://art/fx/bone_spear.json"):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/fx/bone_spear.json"))
	return d.get("frames", []) if d is Dictionary else []
const STREAK := Color(0.78, 0.88, 1.0)

func _spear_trail(dt: float) -> void:
	if floor_mode or book == null:
		return
	for h in book.spear_hits:
		h["t"] += dt
	book.spear_hits = book.spear_hits.filter(func(h): return h["t"] < 0.3)
	for c in book.spear_casts:
		c["t"] += dt
	book.spear_casts = book.spear_casts.filter(func(c): return c["t"] < 0.22)
	for r in rings:
		r["t"] += dt
	rings = rings.filter(func(r): return r["t"] < 0.28)
	ring_t -= dt
	var k := 0
	for sp in book.spears:
		if sp["small"]:
			continue
		var u: Vector2 = Iso.to_screen(sp["v"].normalized()).normalized()
		if ring_t <= 0.0:
			rings.append({"c": S(sp["tp"], 8.0), "u": u, "t": 0.0, "tier": int(sp.get("tier", 0))})
		if k < spear_lights.size():
			spear_lights[k].position = S(sp["tp"])
			spear_lights[k].visible = true
			k += 1
	if ring_t <= 0.0:
		ring_t = 0.016
	for j in range(k, spear_lights.size()):
		spear_lights[j].visible = false

func _draw_spears() -> void:
	if floor_mode or SPEAR_TEX == null or book == null or book.zone == null or book.hero == null:
		return
	var hero = book.hero
	for r in rings:
		var q: float = r["t"] / 0.28
		var rad: float = (4.0 + 18.0 * q) * (1.0 + 0.15 * r["tier"])
		var u: Vector2 = r["u"]
		var n := Vector2(-u.y, u.x)
		var pts := PackedVector2Array()
		for a_i in 21:
			var aa := a_i / 20.0 * TAU
			pts.append(r["c"] + n * cos(aa) * rad + u * sin(aa) * rad * 0.32)
		spear_cv.draw_polyline(pts, Color(STREAK, 0.85 * (1.0 - q) * (1.0 - q)), 2.6 - 1.2 * q)
	# the flash at his hand as a spear leaves it: a pale ring opening and a few slivers of bone flung forward
	for cst in book.spear_casts:
		var q: float = cst["t"] / 0.22
		var cc := S(cst["at"], 8.0)
		var rr := 6.0 + 20.0 * q
		var ring := PackedVector2Array()
		for a_i in 19:
			var aa := a_i / 18.0 * TAU
			ring.append(cc + Vector2(cos(aa) * rr, sin(aa) * rr * 0.5))
		spear_cv.draw_polyline(ring, Color(STREAK, 0.8 * (1.0 - q)), 2.0)
		spear_cv.draw_circle(cc, 5.0 * (1.0 - q), Color(1, 1, 1, 0.5 * (1.0 - q)))
	# where a spear pierces: a burst of bone splinters flung on along its path and out to the sides, and a pale ring
	for h in book.spear_hits:
		var q2: float = h["t"] / 0.3
		var hc := S(h["at"], 10.0)
		var u3: Vector2 = Iso.to_screen(h["v"].normalized()).normalized()
		var r2 := 4.0 + 16.0 * q2
		var ring2 := PackedVector2Array()
		for a_i in 19:
			var aa2 := a_i / 18.0 * TAU
			ring2.append(hc + Vector2(cos(aa2) * r2, sin(aa2) * r2 * 0.5))
		spear_cv.draw_polyline(ring2, Color(STREAK, 0.7 * (1.0 - q2)), 1.5)
		for k in 7:
			var ang := u3.angle() + (k - 3) * 0.42 + sin(k * 12.9898) * 0.15
			var d := Vector2(cos(ang), sin(ang) * 0.6)
			var a2 := hc + d * (6.0 + 26.0 * q2 * (0.7 + 0.1 * k))
			spear_cv.draw_line(a2, a2 + d * (5.0 - 3.0 * q2), Color(0.93, 0.95, 0.97, 1.0 - q2), 2.0)
	for sp in book.spears:
		if sp["small"]:
			continue
		var c := S(sp["tp"], 8.0)
		var u: Vector2 = Iso.to_screen(sp["v"].normalized()).normalized()
		spear(c, u, int(sp.get("tier", 0)), 1.0, true)
	if not book.charging.is_empty():
		var ch: Dictionary = book.charging
		var tier: int = ch["tier"]
		var nxt: float = book.LANCE_T[mini(tier, 2)]
		var prev: float = 0.0 if tier == 0 else book.LANCE_T[tier - 1]
		var grow := 1.0 if tier >= 3 else clampf((ch["t"] - prev) / maxf(0.01, nxt - prev), 0.0, 1.0)
		var dir: Vector2 = ch["at"] - hero.tp
		var u2: Vector2 = Iso.to_screen(dir.normalized() if dir.length() > 0.05 else Vector2(1, 1).normalized()).normalized()
		var side := Vector2(-u2.y, u2.x) * (1.0 if u2.x >= 0.0 else -1.0)
		var rise := clampf(ch["t"] / 0.2, 0.0, 1.0)
		spear(S(hero.tp, 4.0 + 10.0 * rise) + side * 16.0, u2, tier, 0.55 + 0.45 * grow, false)

func spear(c: Vector2, u: Vector2, tier: int, k: float, flying: bool) -> void:
	var cv: Node2D = spear_cv
	var sc := (1.0 + 0.18 * tier) * k
	var ang := rad_to_deg(u.angle())
	var best = null
	var bd := 999.0
	for f in SPEAR_FR:
		var d := absf(wrapf(float(f["angle"]) - ang, -180.0, 180.0))
		if d < bd:
			bd = d
			best = f
	if best == null:
		return
	var r: Array = best["rect"]
	var an: Array = best["anchor"]
	var half_len := float(maxf(r[2], r[3])) * 0.5 * sc
	if flying:
		var t: float = book.time
		var n := Vector2(-u.y, u.x)
		# the streak: a long pale taper behind the spear, brightest where it leaves the tail
		var L := half_len * 3.0
		var w0 := (5.5 + 1.5 * tier) * sc
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var tail := c - u * half_len * 0.7
		for i in 9:
			var q := float(i) / 8.0
			var wq := w0 * (1.0 - q) + 0.5
			pts.append(tail - u * L * q + n * wq)
			cols.append(Color(STREAK, 0.6 * (1.0 - q) * (1.0 - q * 0.3)))
		for i in range(8, -1, -1):
			var q := float(i) / 8.0
			var wq := w0 * (1.0 - q) + 0.5
			pts.append(tail - u * L * q - n * wq)
			cols.append(Color(STREAK, 0.6 * (1.0 - q) * (1.0 - q * 0.3)))
		cv.draw_polygon(pts, cols)
		# the core line of the streak, brighter and thin
		cv.draw_line(tail, tail - u * L * 0.55, Color(1, 1, 1, 0.55), 2.0)
		# wisps curling away off the streak
		for wi in 3:
			var ph := t * 9.0 + wi * 2.1
			var a := tail - u * (L * (0.2 + 0.25 * wi))
			var b := a - u * 10.0 + n * sin(ph) * (5.0 + 3.0 * wi)
			cv.draw_line(a, b, Color(STREAK, 0.25), 1.0)
		# a faint cold halo round the spear itself
		for ring in 2:
			var hp := PackedVector2Array()
			for a_i in 18:
				var aa := a_i / 18.0 * TAU
				hp.append(c + u * cos(aa) * (half_len + 4.0 - ring * 3.0) + n * sin(aa) * (w0 + 3.0 - ring * 1.5))
			cv.draw_colored_polygon(hp, Color(STREAK, 0.1))
	cv.draw_set_transform(c, 0.0, Vector2(sc, sc))
	cv.draw_texture_rect_region(SPEAR_TEX, Rect2(-float(an[0]), -float(an[1]), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]))
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## (the old drawing, kept for a build without the rendered spear) a lance of packed bone along u, after D2's Bone Spear but solid bone in our colours: a long barbed head tapering
## to a hard point, a thin shaft knuckled like a spine, a light edge on the upper side and shade below, a dark
## outline. From tier 1 a faint warmth of marrow about it that deepens with each tier (the user asked for this
## subtle glow, 2026-09-30); at tier 3 amber marrow shows through the core of the shaft.
func lance(c: Vector2, u: Vector2, tier: int, k: float) -> void:
	var half := int((12.0 + 4.0 * tier) * k)          # art pixels from the middle to either end
	var head := int((6 + 2 * tier) * clampf(k, 0.6, 1.0))
	var n := Vector2(-u.y, u.x)
	if n.y > 0.0:
		n = -n                                         # n points up the screen: the lit side
	if tier >= 1:
		for ring in 3:
			var rr := (half + 5.0 - ring * 2.5) * P
			var ww := (1.5 + tier * 1.2 - ring * 0.6) * P
			var pts := PackedVector2Array()
			for a_i in 20:
				var a := a_i / 20.0 * TAU
				pts.append(c + u * cos(a) * rr + n * sin(a) * ww)
			draw_colored_polygon(pts, Color(1.0, 0.86, 0.62, 0.03 * tier))
	var sw := 0 if tier < 2 else 1                     # half-width of the shaft (cells beside the core)
	var OUT := Color(0.16, 0.14, 0.12)
	var AMBER := Color(0.86, 0.62, 0.3)
	for i in range(-half, half + 1):
		var from_tip := half - i
		var hw := sw
		var barb := false
		if from_tip < head:
			# the head: widest at its base, straight taper to the point
			hw = int(round((sw + 2.0) * float(from_tip) / head))
			barb = from_tip == head - 1
		elif (i + half) % 5 == 0 and i > -half + 1:
			hw = sw + 1                                  # a knuckle of the spine
		for j in range(-hw - 1, hw + 2):
			var q := c + u * i * P + n * j * P
			var col := BONE_M
			if absi(j) == hw + 1:
				col = OUT
			elif hw > 0 and j == hw:
				col = BONE
			elif hw > 0 and j == -hw:
				col = BONE_D
			if tier >= 3 and from_tip >= head and j == 0:
				col = BONE_M.lerp(AMBER, 0.55)
			elif tier == 2 and from_tip >= head and j == 0 and (i + half) % 5 == 0:
				col = BONE_M.lerp(AMBER, 0.4)
			draw_rect(Rect2(Vector2(floorf(q.x / P) * P, floorf(q.y / P) * P), Vector2(P, P)), col)
		if barb:   # two barbs swept back from the head's base
			for side in [-1, 1]:
				for b in 2:
					var q2: Vector2 = c + u * (i - 1 - b) * P + n * side * (sw + 2 + b) * P
					draw_rect(Rect2(Vector2(floorf(q2.x / P) * P, floorf(q2.y / P) * P), Vector2(P, P)), BONE if side > 0 else BONE_D)


## The Bone Blade (skills/ossumancer/tree_count.gd): while he charges, bone grows out over the head of his weapon, longer
## and more crooked with each tier, and three small bone pips under him fill; each stroke leaves its mark: the thrust a
## straight streak, the cleave an arc of slivers, the split a cracked line in the ground with shards thrown up.
func _blade_shape(base: Vector2, u: Vector2, length: float, width: float, crook: float) -> void:
	var n := Vector2(-u.y, u.x)
	var pts := PackedVector2Array()
	var segs := 7
	for i in segs + 1:                        # the upper edge, base to tip, bending toward the crook
		var q := float(i) / segs
		pts.append(base + u * length * q + n * (width * (1.0 - q) + crook * sin(q * PI) * length * 0.06))
	for i in range(segs, -1, -1):              # the lower edge back, with notches cut in it
		var q := float(i) / segs
		var notch := 0.35 if i % 2 == 1 and i < segs else 0.0
		pts.append(base + u * length * q - n * (width * (1.0 - q) * (1.0 - notch) - crook * sin(q * PI) * length * 0.06))
	draw_colored_polygon(pts, BONE_M)
	draw_polyline(pts, Color(0.16, 0.14, 0.12), 1.5)
	draw_line(base + n * width * 0.5, base + u * length * 0.92, BONE, 1.5)   # the lit ridge

func _draw_blade(hero) -> void:
	if not book.has_method("tick_blade"):
		return
	var ch: Dictionary = book.bcharge
	if not ch.is_empty():
		var tier: int = ch["tier"]
		var nxt: float = book.BLADE_T[mini(tier, 1)]
		var prev: float = 0.0 if tier == 0 else book.BLADE_T[tier - 1]
		var grow := 1.0 if tier >= 2 else clampf((ch["t"] - prev) / maxf(0.01, nxt - prev), 0.0, 1.0)
		var dir: Vector2 = ch["at"] - hero.tp
		var u: Vector2 = Iso.to_screen(dir.normalized() if dir.length() > 0.05 else Vector2(1, 1).normalized()).normalized()
		var hand := S(hero.tp, 14.0) + u * 22.0
		var length := (26.0 + 16.0 * tier + 14.0 * grow * (1.0 if tier < 2 else 0.0)) * (1.0 + 0.04 * tier)
		_blade_shape(hand, u, length, 4.0 + tier * 1.5, float(tier))
		# the gauge: three bone pips under his feet, filling
		var foot := S(hero.tp) + Vector2(0, 14)
		for i in 3:
			var c := foot + Vector2((i - 1) * 16.0, 0)
			var full := i < tier or (i == tier and tier == 2)
			var part := 1.0 if i < tier else (grow if i == tier else 0.0)
			draw_rect(Rect2(c - Vector2(6, 2), Vector2(12, 4)), Color(0.12, 0.11, 0.1, 0.8))
			draw_rect(Rect2(c - Vector2(6, 2), Vector2(12.0 * (1.0 if full else part), 4)), BONE if full else BONE_D)
	for f in book.blade_fx:
		var k: float = 1.0 - f["t"] / 0.5
		match f["kind"]:
			"thrust":
				var u1: Vector2 = Iso.to_screen(f["dir"]).normalized()
				var a1 := S(f["tp"], 12.0)
				draw_line(a1, a1 + u1 * f["reach"] * 70.0, Color(BONE, 0.8 * k), 3.0 * k + 1.0)
				draw_line(a1, a1 + u1 * f["reach"] * 70.0, Color(1, 1, 1, 0.5 * k), 1.0)
			"cleave":
				var c2 := S(f["tp"], 10.0)
				var base_a: float = Iso.to_screen(f["dir"]).angle()
				for i in 13:
					var ang := base_a - 1.2 + i * 0.2
					var r: float = f["reach"] * 62.0 + 10.0
					var d := Vector2(cos(ang), sin(ang) * 0.55)
					sliver(c2 + d * r * (0.55 + 0.25 * (1.0 - k)), c2 + d * r, Color(BONE_M, k))
			"split", "split_flash":
				if f["kind"] == "split":
					var u3: Vector2 = Iso.to_screen(f["dir"]).normalized()
					var p0 := S(f["tp"])
					var L3: float = f["len"] * Iso.to_screen(f["dir"]).length()
					var n3 := Vector2(-u3.y, u3.x)
					var last := p0
					for i in range(1, 13):
						var q := float(i) / 12.0
						var p := p0 + u3 * L3 * q + n3 * sin(q * 37.0) * 3.0
						draw_line(last, p, Color(0.08, 0.07, 0.06, 0.9 * k), 3.0)
						draw_line(last + Vector2(0, -1), p + Vector2(0, -1), Color(BONE_D, 0.7 * k), 1.0)
						last = p
						if i % 2 == 0:
							sliver(p, p + Vector2(sin(i * 7.1) * 6.0, -10.0 - 8.0 * k), Color(BONE, k))
			"close":
				var c4 := S(f["tp"], 30.0)
				for i in 9:
					var ang4 := i / 9.0 * TAU
					draw_line(c4, c4 + Vector2(cos(ang4), sin(ang4) * 0.6) * (10.0 + 14.0 * (1.0 - k)), Color(1, 1, 1, 0.8 * k), 1.5)
