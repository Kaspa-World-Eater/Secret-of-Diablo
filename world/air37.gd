extends Node2D
## world/air37.gd: what hangs in the air of each place that world/atmos.gd and world/weather.gd did not yet carry,
## from the web's older atmosphere, still alive in v105 (y_light21.js:313-466, zz_env.js:33-82). Drawn by the
## atmosphere's layer, over the dark (world/atmos.gd makes one and calls bind).
## - the fen's fireflies: a quarter of its motes, a dithered green-white glow that breathes (y_light21.js:387);
## - the underground's slow dust, pale specks drifting down (y_light21.js:388);
## - a cold pool of light on certain vault floor tiles, under a crack, with motes falling into it (y_light21.js:154);
## - by day, a few bright motes hanging in the light (zz_env.js:74-79);
## - moonlit clearings (zz_zz_moon86.js:13-56): two or three in each outdoor place lie under a gap in the cloud; at night
##   motes fall slowly there, and standing in one your poise comes back half again as fast and your wounds close a
##   little (the web's pool of moonlight never reached its dark layer in v105, so there is none here either);
## Taken out 2026-10-05 (the user: the fog that pops up on the screen, the bars of light): the mist puffs, the shafts
## drawn as bars over the vaults, the dawn rays and the canopy shafts. They were laid over the screen, not in the world.

const Flame = preload("res://fx/flame.gd")
const PX := 4.0
const TALL := [2, 3, 5, 7, 8, 9, 10]
const WATER := 4
const FLOOR := 6

var zone: Zone
var hero
var clearings: Array = []    # {tp, s, said}
const R_MOON := 2.3
var dark
var kind := "moor"           # moor | fen | deep (atmosKind)
var outdoor := false
var t := 0.0
var motes: Array = []        # fireflies and dust (screen px, carried by the camera)
var dmotes: Array = []       # day motes (screen px)
var last_cam := Vector2.INF
var pools: Array = []        # PointLights under the shafts (the dark layer opens a pool for each)
var cracks: Array = []       # the floor tiles under a crack in the vault (found once per place)
var add: Node2D              # what is laid on as light (the motes in the cracks' light, the fireflies' glow)

func bind(z: Zone, d, h = null) -> void:
	zone = z
	hero = h
	dark = d
	outdoor = z.d.get("outdoor", false)
	var th := str(z.d.get("theme", ""))
	kind = "fen" if th == "fen" else ("moor" if th == "moor" or th == "" else "deep")
	motes.clear()
	dmotes.clear()
	last_cam = Vector2.INF
	pools.clear()
	cracks.clear()
	var land := z.id + str(z.d.get("theme", ""))
	_find_clearings()
	if not outdoor and kind == "deep":
		for y in int(z.h):
			for x in int(z.w):
				if Flame.hash2(x * 13 + 7, y * 17 + 3) >= 0.9955 and z.type_at(Vector2(x, y)) == FLOOR:
					cracks.append(Vector2i(x, y))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if add == null:
		add = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.material = mat
		add.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add.draw.connect(_draw_add)
		add_child(add)

func _vs() -> Vector2:
	return get_viewport_rect().size

func _xf() -> Transform2D:
	return get_viewport().get_canvas_transform()

func _process(dt: float) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	dt = minf(dt, 0.05)
	t += dt
	var vs := _vs()
	var xf := _xf()
	var cam := xf.affine_inverse() * (vs / 2.0)
	var dcam := Vector2.ZERO if last_cam == Vector2.INF else (cam - last_cam)
	last_cam = cam
	var dk := Game.day_k() if outdoor else 0.0
	# fireflies over the fen, dust under the ground
	var want := 15 if kind == "fen" else (18 if kind == "deep" else 0)
	while motes.size() < want:
		motes.append({"p": Vector2(randf() * vs.x, (40.0 + randf() * (270.0 - 60.0)) * PX if kind == "fen" else randf() * vs.y), "t": 0.0,
			"life": (6.0 + randf() * 8.0) if kind == "fen" else 40.0, "s": randf() * 100.0, "vy": 0.0 if kind == "fen" else 1.5 + randf() * 2.5})
	for m in motes:
		m["t"] += dt
		if kind == "fen":
			m["p"] += Vector2(sin(t * 1.3 + m["s"]) * 6.0, cos(t * 1.1 + m["s"] * 2.0) * 4.0) * PX * dt
		else:
			m["p"] += Vector2(sin(t * 0.4 + m["s"]) * 2.0, m["vy"]) * PX * dt
		m["p"] -= dcam
	motes = motes.filter(func(m): return m["t"] < m["life"] and Rect2(Vector2(-80, -80), vs + Vector2(160, 120)).has_point(m["p"]))
	# day motes in the open
	if outdoor and dk > 0.3:
		while dmotes.size() < 14:
			dmotes.append({"p": Vector2(randf() * vs.x, randf() * vs.y), "s": randf() * TAU, "t": 0.0, "life": 6.0 + randf() * 6.0})
		for d in dmotes:
			d["t"] += dt
			d["p"] += Vector2(sin(t * 0.5 + d["s"]) * 4.0, 2.0 + cos(t * 0.3 + d["s"])) * PX * dt - dcam
		dmotes = dmotes.filter(func(d): return d["t"] < d["life"] and d["p"].y < vs.y + 16)
	else:
		dmotes.clear()
	_shaft_pools(xf, vs)
	_rest(dt)
	queue_redraw()
	if add:
		add.queue_redraw()

# ------------------------------------------------------------------ moonlit clearings
func _night() -> float:
	return 1.0 - Game.day_k() if outdoor else 0.0

func _find_clearings() -> void:
	clearings.clear()
	if not outdoor or RegEx.create_from_string("town|camp").search(zone.id) != null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash(zone.id) ^ 0x86a1
	var W := maxi(20, zone.w)
	var H := maxi(20, zone.h)
	var want := 2 + r.randi() % 2
	var start: Vector2 = Vector2(zone.arrive.get("x", -99), zone.arrive.get("y", -99)) if zone.arrive is Dictionary else Vector2(-99, -99)
	for n in 900:
		if clearings.size() >= want:
			break
		var x := 6 + r.randi() % (W - 12)
		var y := 6 + r.randi() % (H - 12)
		var open := true
		for j in range(-3, 4):
			for i in range(-3, 4):
				if zone.is_solid(Vector2(x + i + 0.5, y + j + 0.5)):
					open = false
		if not open or start.distance_to(Vector2(x, y)) < 8.0:
			continue
		var far := true
		for c in clearings:
			if (c["tp"] as Vector2).distance_to(Vector2(x, y)) < 18.0:
				far = false
		if far:
			clearings.append({"tp": Vector2(x + 0.5, y + 0.5), "s": r.randf() * 99.0, "said": false})

## the rest a clearing gives: poise back half again as fast, a little life
func _rest(dt: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.dead or _night() < 0.35:
		return
	for c in clearings:
		if hero.tp.distance_to(c["tp"]) < R_MOON * 0.8:
			var st = hero.st
			st.poise = minf(st.poise_max(), st.poise + 15.0 * dt)
			st.hp = minf(st.life_max(), st.hp + st.life_max() * 0.006 * dt)
			if not c["said"]:
				c["said"] = true
				Bus.say.emit("A gap in the cloud. The moon finds this one place, and lets you breathe.", 3.0)

# ------------------------------------------------------------------ the vault shafts
func _shaft_tiles(xf: Transform2D, vs: Vector2) -> Array:
	var out := []
	var view := Rect2(Vector2(-300, -200), vs + Vector2(600, 900))
	for c in cracks:
		if view.has_point(xf * Iso.to_screen(Vector2(c.x + 0.5, c.y + 0.5))):
			out.append([c.x, c.y, 0.75 + 0.25 * sin(t * 0.5 + c.x)])
	return out

func _shaft_pools(xf: Transform2D, vs: Vector2) -> void:
	var tiles := _shaft_tiles(xf, vs)
	while pools.size() < tiles.size():
		var l := PointLight2D.new()
		l.texture = Lights.radial(64)
		l.color = Color8(170, 185, 215)
		l.shadow_enabled = false
		l.set_meta("dark_r", 34.0)
		l.set_meta("dark_core", 0.3)
		l.set_meta("dark_far", 1.5)
		l.set_meta("dark_w", 0.4)
		zone.sorted.add_child(l)
		pools.append(l)
	for i in pools.size():
		var l: PointLight2D = pools[i]
		if not is_instance_valid(l):
			continue
		l.visible = i < tiles.size()
		if l.visible:
			var s: Array = tiles[i]
			l.position = Iso.to_screen(Vector2(s[0] + 0.5, s[1] + 0.5))
			l.set_meta("dark_r", 24.0 * s[2])

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var vs := _vs()
	var xf := _xf()
	var dk := Game.day_k() if outdoor else 0.0
	# fireflies and dust
	for m in motes:
		var fade := minf(1.0, minf(m["t"] / 0.6, (m["life"] - m["t"]) / 0.8))
		var p: Vector2 = ((m["p"] as Vector2) / PX).round() * PX
		if kind == "fen":
			var b := 0.5 + 0.5 * sin(t * 3.0 + m["s"])
			draw_rect(Rect2(p, Vector2(PX, PX)), Color(220 / 255.0, 1.0, 180 / 255.0, b * fade))
		else:
			draw_rect(Rect2(p, Vector2(PX, PX)), Color(Color("#d8d0c0"), 0.3 * fade * (0.6 + 0.4 * sin(t * 2.0 + m["s"]))))
	# day: a few bright motes hanging in the light
	for d in dmotes:
		var f: float = minf(1.0, minf(d["t"] / 1.5, (d["life"] - d["t"]) / 1.5)) * dk * (0.5 + 0.5 * sin(t * 2.0 + d["s"] * 3.0))
		draw_rect(Rect2(((d["p"] as Vector2) / PX).round() * PX, Vector2(PX, PX)), Color(232 / 255.0, 224 / 255.0, 200 / 255.0, 0.45 * f))

	# motes falling in the moonlight
	var nk := _night()
	if nk >= 0.35:
		for c in clearings:
			for i in 14:
				var ph := fmod(t * 0.12 + i * 0.137 + c["s"], 1.0)
				var an := fmod(i * 2.4 + c["s"], TAU)
				var rr := fmod(i * 0.37 + c["s"], 1.0) * R_MOON * 0.8
				var p: Vector2 = xf * Iso.to_screen((c["tp"] as Vector2) + Vector2(cos(an), sin(an)) * rr)
				var q := Vector2(roundf(p.x / PX + sin(t + i) * 2.0), roundf(p.y / PX - 40.0 * (1.0 - ph))) * PX
				draw_rect(Rect2(q, Vector2(PX, PX)), Color(Color("#dde6f4"), 0.5 * sin(ph * PI) * nk))

## what is laid on as light: motes falling into the cracks' light, the fireflies' glow
func _draw_add() -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var vs := _vs()
	var xf := _xf()
	var dk := Game.day_k() if outdoor else 0.0
	# the cracks in the vaults: motes falling into the cold pool (the bar of light over them is gone)
	for s in _shaft_tiles(xf, vs):
		var p: Vector2 = xf * Iso.to_screen(Vector2(s[0] + 0.5, s[1] + 0.5))
		for i in 4:
			var k := fmod(t * 0.08 + i * 0.27 + s[0] * 0.1, 1.0)
			var mp := (p / PX).round() + Vector2(36.0 - k * 34.0 + sin(i * 5.0) * 4.0, -146.0 + k * 140.0)
			add.draw_rect(Rect2(mp.round() * PX, Vector2(PX, PX)), Color(Color("#eef0ff"), 0.6 * sin(k * PI)))
	if kind == "fen":
		for m in motes:
			var fade := minf(1.0, minf(m["t"] / 0.6, (m["life"] - m["t"]) / 0.8))
			var b := 0.5 + 0.5 * sin(t * 3.0 + m["s"])
			var p: Vector2 = ((m["p"] as Vector2) / PX).round() * PX
			var g := Flame.dither_glow(4, Color8(150, 255, 110))
			add.draw_texture_rect(g, Rect2(p - Vector2(4, 4) * PX, g.get_size() * PX), false, Color(1, 1, 1, 0.5 * b * fade * (1.2 - dk * 0.6)))
