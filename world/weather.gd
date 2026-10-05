class_name Weather
extends CanvasLayer
## What falls from the sky (and the roof). Each land has its own, and it comes and goes on its own slow beat:
## - the moor and the heath: ash, still falling from the god's burning, grey flakes turning on the wind;
## - the fen and the bog: rain in long thin strokes (s05), seen best where a light catches it, and small splashes
##   on the ground about you;
## - the woods by day: shafts of light through the canopy (s15), slow, drifting, breathing;
## - under the ground: drips from the roof, each landing in a small ring of water near the lantern.
## Everything takes its colour and strength from the light round it (the dark layer's light_at), never red.

const WPX := 4.0
var zone: Zone
var hero: Hero
var dark: DarkLayer
var kind := ""               # ash | rain | none
var woody := false
var outdoor := false
var canvas: Node2D
var add_canvas: Node2D
var flakes: Array = []
var drops: Array = []
var splashes: Array = []
var shafts: Array = []
var drips: Array = []
var t := 0.0
var beat := 0.0              # the weather's own slow swell 0..1
var beat_ph := 0.0
var last_cam := Vector2.INF
var bind_t := 0.0
var snd: Node                # the soundscape: a drip landing makes a sound

func _ready() -> void:
	layer = 6
	canvas = Node2D.new()
	canvas.draw.connect(_draw)
	add_child(canvas)
	add_canvas = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_canvas.material = mat
	add_canvas.draw.connect(_draw_add)
	add_child(add_canvas)

func bind(z: Zone, h: Hero, d: DarkLayer) -> void:
	zone = z
	hero = h
	dark = d
	flakes.clear()
	drops.clear()
	splashes.clear()
	shafts.clear()
	drips.clear()
	last_cam = Vector2.INF
	bind_t = t
	outdoor = zone.d.get("outdoor", false)
	var th: String = str(zone.d.get("theme", "")) + " " + zone.id
	kind = "none"
	if outdoor:
		if th.contains("fen") or th.contains("bog") or th.contains("drown") or th.contains("marsh"):
			kind = "rain"
		elif th.contains("moor") or th.contains("heath") or th.contains("ash"):
			kind = "ash"
	woody = outdoor and (th.contains("wood") or th.contains("root") or th.contains("fern") or th.contains("grove"))
	beat_ph = float(hash(zone.id) % 1000) / 1000.0 * TAU

func _light(p: Vector2) -> Array:
	return dark.light_at(p) if dark else [0.5, Color(0.62, 0.66, 0.78)]

func _process(dt: float) -> void:
	if zone == null or not is_instance_valid(zone) or hero == null or not is_instance_valid(hero):
		return
	t += dt
	var vs := get_viewport().get_visible_rect().size
	var c2 := get_viewport().get_camera_2d()
	var cam := c2.get_screen_center_position() if c2 else hero.position
	var dcam := Vector2.ZERO if last_cam == Vector2.INF else cam - last_cam
	last_cam = cam
	if dcam.length() > 300.0:   # a cut, not a pan
		dcam = Vector2.ZERO
	var wind := Game.wind
	# the swell: showers and ash-falls come and go over a minute or two, never quite to nothing
	beat = clampf(0.55 + 0.35 * sin(t * 0.05 + beat_ph) + 0.15 * sin(t * 0.13 + beat_ph * 2.0), 0.08, 1.0)
	# --- ash
	if kind == "ash":
		var want := int(190 * beat)
		while flakes.size() < want:
			flakes.append({"p": Vector2(randf_range(-100, vs.x + 100), randf_range(-40, vs.y) if t - bind_t < 0.3 else randf_range(-30.0, -6.0)),
				"v": randf_range(9.0, 17.0) * WPX, "ph": randf() * TAU, "s": 1 if randf() < 0.75 else 2, "z": randf_range(0.7, 1.3)})
		for f in flakes:
			f["ph"] += dt * 2.2
			f["p"] += Vector2((wind * 26.0 + sin(f["ph"]) * 5.0) * WPX * f["z"], f["v"] * f["z"] + cos(f["ph"] * 1.3) * 2.0 * WPX) * dt - dcam * f["z"]
		flakes = flakes.filter(func(f): return f["p"].y < vs.y + 20 and f["p"].x > -200 and f["p"].x < vs.x + 200)
		if flakes.size() > want + 10:
			flakes.resize(want + 10)
	# --- rain
	if kind == "rain":
		var want := int(280 * beat)
		for i in maxi(0, want - drops.size()):
			var sp := Vector2(randf_range(-200, vs.x + 100), randf_range(-60, vs.y * 0.9))
			drops.append({"p": sp, "land": sp.y + randf_range(60, 260), "z": randf_range(0.8, 1.2)})
		var fall := Vector2(wind * 80.0 + 20.0, 260.0) * WPX
		for d in drops:
			d["p"] += fall * d["z"] * dt - dcam
			d["land"] -= dcam.y
			if d["p"].y >= d["land"]:
				d["dead"] = true
				if splashes.size() < 60 and randf() < 0.5:
					splashes.append({"p": d["p"], "t": 0.0})
		drops = drops.filter(func(d): return not d.get("dead", false) and d["p"].y < vs.y + 40)
		for s in splashes:
			s["t"] += dt
			s["p"] -= dcam
		splashes = splashes.filter(func(s): return s["t"] < 0.28)
	# --- light shafts in the woods by day
	var dk := Game.day_k() if outdoor else 0.0
	# (the woods' shafts are the web's canopy shafts now, drawn by world/air37.gd)
	for s in shafts:
		s["t"] += dt
		s["x"] += (2.0 + wind * 4.0) * dt - dcam.x
	shafts = shafts.filter(func(s): return s["t"] < s["life"])
	# --- drips under the ground: near the lantern, now and then
	if not outdoor:
		if drips.size() < 3 and randf() < dt * 0.35:
			var g := get_viewport().get_canvas_transform() * hero.position + Vector2(randf_range(-260, 260), randf_range(-140, 120))
			drips.append({"g": g, "y": g.y - randf_range(90, 180), "t": 0.0, "hit": false})
		for d in drips:
			d["t"] += dt
			d["g"] -= dcam
			d["y"] -= dcam.y
			if not d["hit"]:
				d["y"] += 300.0 * WPX * 0.25 * dt * (1.0 + d["t"] * 3.0)
				if d["y"] >= d["g"].y:
					d["hit"] = true
					d["t"] = 0.0
					if snd:
						snd.drip()
		drips = drips.filter(func(d): return not d["hit"] or d["t"] < 0.9)
	canvas.queue_redraw()
	add_canvas.queue_redraw()

func _snap(p: Vector2) -> Vector2:
	return Vector2(floorf(p.x / WPX) * WPX, floorf(p.y / WPX) * WPX)

func _draw() -> void:
	# ash: pale grey flakes, brighter where a light finds them
	for f in flakes:
		var l := _light(f["p"])
		var lum: float = l[0]
		var col: Color = l[1]
		var g := 0.5 + 0.6 * lum
		var c := Color(0.62 * g + col.r * 0.2 * lum, 0.6 * g + col.g * 0.2 * lum, 0.6 * g + col.b * 0.2 * lum, 0.6 + 0.3 * lum)
		var p := _snap(f["p"])
		canvas.draw_rect(Rect2(p, Vector2(WPX * f["s"], WPX)), c)
	# rain: thin strokes along the fall, one pixel wide, strongest in the light
	var slope := Vector2(Game.wind * 80.0 + 20.0, 260.0).normalized()
	for d in drops:
		var l := _light(d["p"])
		var lum: float = l[0]
		var col: Color = l[1]
		var a := 0.13 + 0.45 * lum * lum
		var c := Color(col.r * 0.5 + 0.35, col.g * 0.5 + 0.38, col.b * 0.5 + 0.45, a)
		var ln: float = 10.0 * WPX * d["z"]
		var p0: Vector2 = d["p"]
		for i in int(ln / WPX):
			var q := _snap(p0 - slope * float(i) * WPX)
			canvas.draw_rect(Rect2(q, Vector2(2, WPX)), c)
	for s in splashes:
		var l := _light(s["p"])
		var a: float = (0.15 + 0.5 * float(l[0])) * (1.0 - s["t"] / 0.28)
		var p := _snap(s["p"])
		var c := Color(0.7, 0.74, 0.82, a)
		var k := 1 + int(s["t"] / 0.1)
		canvas.draw_rect(Rect2(p + Vector2(-WPX * k, 0), Vector2(WPX, WPX)), c)
		canvas.draw_rect(Rect2(p + Vector2(WPX * k, 0), Vector2(WPX, WPX)), c)
		if s["t"] < 0.1:
			canvas.draw_rect(Rect2(p + Vector2(0, -WPX), Vector2(WPX, WPX)), c)
	# drips: a bead falling, then a small ring spreading on the floor
	for d in drips:
		var l := _light(d["g"])
		var lum: float = l[0]
		var c := Color(0.62, 0.7, 0.78, 0.2 + 0.6 * lum)
		if not d["hit"]:
			canvas.draw_rect(Rect2(_snap(Vector2(d["g"].x, d["y"])), Vector2(WPX, WPX * 2)), c)
		else:
			var r: float = (2.0 + d["t"] * 9.0) * WPX
			c.a *= 1.0 - d["t"] / 0.9
			var ctr := _snap(d["g"])
			for i in 12:
				var ang := TAU * i / 12.0
				canvas.draw_rect(Rect2(_snap(ctr + Vector2(cos(ang) * r, sin(ang) * r * 0.5)), Vector2(WPX, WPX)), c)

func _draw_add() -> void:
	# the shafts: long leaning bands of warm light, dithered in steps. They are never still: the canopy they come
	# through moves, so each ray swings a little about its top, widens and narrows, and brightens and dims as
	# leaves cross it, faster in a gust; now and then a leaf's shadow slides down its length.
	if shafts.is_empty():
		return
	var vs := get_viewport().get_visible_rect().size
	var dk := Game.day_k()
	var wind := Game.wind
	for s in shafts:
		var ph: float = s["ph"]
		# a slow rise and a slow fade (four seconds each way), so no ray ever blinks in or out
		var life_k: float = smoothstep(0.0, 4.0, s["t"]) * smoothstep(0.0, 4.0, s["life"] - s["t"])
		# the canopy: a slow breath and a quicker shiver that grows with the wind
		var shimmer := 0.72 + 0.18 * sin(t * 0.45 + ph) + (0.06 + 0.12 * wind) * sin(t * (1.7 + wind) + ph * 3.0) * sin(t * 0.61 + ph)
		var br: float = 0.075 * dk * life_k * shimmer
		if br <= 0.002:
			continue
		# the swing: the ray pivots on its top, a few degrees, slowly; the gust leans it a touch more
		var lean := 0.55 + 0.05 * sin(t * 0.12 + ph) + 0.03 * sin(t * 0.29 + ph * 2.0) + 0.04 * wind
		var w: float = s["w"] * (1.0 + 0.14 * sin(t * 0.23 + ph * 1.7))
		var sway := 14.0 * sin(t * 0.17 + ph) + 6.0 * sin(t * 0.41 + ph * 0.5)
		# a leaf-shadow gap travelling down the ray
		var gap_y := fmod(t * (30.0 + 20.0 * wind) + ph * 300.0, vs.y * 1.6)
		var y := 0.0
		while y < vs.y:
			var fade := 1.0 - y / vs.y * 0.8
			var gap := 1.0 - 0.55 * clampf(1.0 - absf(y - gap_y) / 60.0, 0.0, 1.0)
			var x0: float = s["x"] + sway + y * lean
			var c := Color(1.0, 0.8, 0.5, br * fade * gap)
			add_canvas.draw_rect(Rect2(Vector2(floorf(x0 / WPX) * WPX, y), Vector2(w, WPX * 2)), c)
			add_canvas.draw_rect(Rect2(Vector2(floorf((x0 + w * 0.2) / WPX) * WPX, y), Vector2(w * 0.6, WPX * 2)), c)
			y += WPX * 2
