extends Node2D
## (creature AI port) One per zone, made on demand by the first brain (Brain.kind_tick -> AIWorld.of(zone)).
## Holds what the creatures leave in the world and what they feel of it:
##  - the Pyre-Saints' ground fires (zc_combat22 enemyFire: burn the hero and his allies every 0.35 s; max 60)
##  - the Vein-Worms' soil ripples (the only tell of a burrower; no surfacing marker since v0.55)
##  - boss telegraphs (zz_zz_boss83): dust and grit lifting in a slam's circle, a charge scoring its lane, the small
##    grit tell under a great creature's wind-up; the slam's cracked ground (2.5 s, drains 14 poise/s). Bone-grey,
##    never red, no glow; drawn unshaded so the dark never hides a tell.
##  - bell tolls as a ring of kicked-up grit, grit bursts, the Pontiff's bone walls (they block walking, 5 s)
##  - the Chorister's dirge (the hero walks at 55% within 5.5 yd), the Silent One's hush on the lantern (x0.45 in 6 yd)
##  - the god altars: come to one and its Herald wakes (zd_world22), once per god
##  - the lights a Gasp or a Moth-Saint feels (lanterns, altars, braziers, candles, fires)
##  - a death scatters the skittish ones nearby (zz_zz_imps67)

const BONE := Color(0.847, 0.808, 0.722)
const GODS := {
	"bone": {"name": "Old Upright", "herald": "The Marrow Pontiff", "mon": "hbone"},
	"flesh": {"name": "the Red Mother", "herald": "The Wet Nurse", "mon": "hflesh"},
	"breath": {"name": "the Last Breath", "herald": "The Long Exhale", "mon": "hbreath"},
	"hollow": {"name": "the Hush", "herald": "A Silent One", "mon": "hhollow"},
}
static var gods_done := {}     # god -> true once its Herald is unmade (one per god per playthrough)

var zone: Zone
var fires: Array = []          # {p, R, dps, t, max, tick}
var ripples: Array = []        # {p, t}
var hazards: Array = []        # {p, r, t, T, s}
var rings: Array = []          # {p, r0, r1, t, T, col}
var walls: Array = []          # {p, t, max, node}
var lights: Array = []         # [{p, r}] the still lights
var altars: Array = []         # the zone's altar objects
var dirge := 0.0               # the frw we took from the hero
var hushed := false
var clock := 0.0

static func of(z: Zone) -> Node:
	if z.has_meta("ai_world"):
		var w0 = z.get_meta("ai_world")
		if is_instance_valid(w0):
			return w0
	var w = load("res://entities/ai/ai_world.gd").new()
	w.zone = z
	z.set_meta("ai_world", w)
	z.floor_layer.add_child(w)
	w._setup()
	return w

func _setup() -> void:
	z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for L in zone.d.get("lights", []):
		if L.get("type") != "fire":
			continue
		var r := 0.0
		match str(L.get("kind", "")):
			"lantern":
				r = 5.0
			"brazier", "candles", "sconce":
				r = 3.2
			_:
				r = 2.2
		lights.append({"p": Vector2(L["x"], L["y"]), "r": r})
	for o in zone.objects:
		if o.get("type") == "altar":
			lights.append({"p": Vector2(o["x"], o["y"]), "r": 5.0})
			if not o.get("used", false):
				altars.append(o)
	Bus.monster_killed.connect(_on_killed)

func _exit_tree() -> void:
	if Bus.monster_killed.is_connected(_on_killed):
		Bus.monster_killed.disconnect(_on_killed)
	_lift_dirge()

# ------------------------------------------------------------------ what the creatures ask of the world
## the nearest light a creature of the dark feels (the web's lightNear), or Vector2.INF
func light_near(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for L in lights:
		var d: float = p.distance_to(L["p"])
		if d < L["r"] and d < bd:
			bd = d
			best = L["p"]
	for f in fires:
		var d2: float = p.distance_to(f["p"])
		if d2 < 2.2 and d2 < bd:
			bd = d2
			best = f["p"]
	return best

## a patch of burning ground (Pyre-Saints): not on walls or in the shallows
func fire(p: Vector2, r: float, dps: float, secs: float, owner: Object = null) -> void:
	if zone.is_solid(p) or zone.type_at(p) == 12:
		return
	fires.append({"p": p, "R": r, "dps": dps, "t": secs, "max": secs, "tick": 0.0, "s": randf() * 9.0, "who": Combat.who(owner) if owner is Monster else ""})
	while fires.size() > 60:
		fires.pop_front()

func ripple(p: Vector2) -> void:
	ripples.append({"p": p + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15)), "t": 0.9})

func toll(p: Vector2, crack: bool = false) -> void:
	rings.append({"p": p, "r0": 0.3, "r1": 2.4 if not crack else 1.6, "t": 0.5, "T": 0.5, "col": Color(0.72, 0.63, 0.44)})

func ring(p: Vector2, r0: float, r1: float, secs: float, col: Color) -> void:
	rings.append({"p": p, "r0": r0, "r1": r1, "t": secs, "T": secs, "col": col})

func slam_scar(p: Vector2, r: float) -> void:
	hazards.append({"p": p, "r": r, "t": 2.5, "T": 2.5, "s": randf() * 99.0})

func bone_wall(p: Vector2, secs: float) -> void:
	if zone.is_solid(p):
		return
	var n := BoneWall.new()
	n.tp = p
	n.life = secs
	n.max_life = secs
	zone.sorted.add_child(n)
	walls.append(n)

## a puff of grit or ash (never a flash): small dull squares that fall
func grit_burst(p: Vector2, col: Color, n: int, spread: float = 1.0, h: float = 30.0) -> void:
	var c := CPUParticles2D.new()
	c.one_shot = true
	c.emitting = true
	c.amount = maxi(2, n)
	c.lifetime = 0.6
	c.explosiveness = 0.95
	c.direction = Vector2.UP
	c.spread = 80.0
	c.initial_velocity_min = 40.0 * spread
	c.initial_velocity_max = 130.0 * spread
	c.gravity = Vector2(0, 320)
	c.scale_amount_min = 3.0
	c.scale_amount_max = 5.0
	c.color = col
	c.position = Iso.to_screen(p) + Vector2(0, -h)
	zone.sorted.add_child(c)
	c.finished.connect(c.queue_free)

# ------------------------------------------------------------------ the frame
func _physics_process(dt: float) -> void:
	clock += dt
	var h: Hero = zone.hero_ref
	var alive_h := h != null and is_instance_valid(h) and not h.dead
	# fires
	for f in fires:
		f["t"] -= dt
		f["tick"] -= dt
		if f["tick"] <= 0.0:
			f["tick"] = 0.35
			# overlapping fires burn as one: at most one ground hazard hurts him every 0.33 s (the clarity rule)
			if alive_h and h.tp.distance_to(f["p"]) < f["R"] + h.radius and Time.get_ticks_msec() > int(h.get_meta("ground_hurt", 0)):
				h.set_meta("ground_hurt", Time.get_ticks_msec() + 330)
				Combat.hit_hero(h, f["dps"] * 0.35, "magic", f["p"], {"src": f.get("who", "") + "|its fire" if f.get("who", "") != "" else "fire on the ground"})
			Brain.hit_allies(get_tree(), f["p"], f["R"], f["dps"] * 0.35, "magic", f["p"])
	fires = fires.filter(func(f): return f["t"] > 0.0)
	for r in ripples:
		r["t"] -= dt
	ripples = ripples.filter(func(r): return r["t"] > 0.0)
	for r in rings:
		r["t"] -= dt
	rings = rings.filter(func(r): return r["t"] > 0.0)
	# the slam's broken ground: the footing is gone
	for z in hazards:
		z["t"] -= dt
		if alive_h and h.invuln <= 0.0 and h.tp.distance_to(z["p"]) < z["r"]:
			h.st.poise = maxf(0.0, h.st.poise - 14.0 * dt)
			h.st.poise_delay = maxf(h.st.poise_delay, 0.3)
	hazards = hazards.filter(func(z): return z["t"] > 0.0)
	# bone walls push the hero (and allies) out of their footing
	for w in walls:
		if not is_instance_valid(w):
			continue
		if alive_h:
			var dd: float = h.tp.distance_to(w.tp)
			var mm: float = 0.45 + h.radius
			if dd < mm and dd > 0.001:
				h.tp = zone.move(h.tp, (h.tp - w.tp) / dd * (mm - dd), h.radius)
				h.position = Iso.to_screen(h.tp)
	walls = walls.filter(func(w): return is_instance_valid(w) and w.life > 0.0)
	if alive_h:
		_bodies(h)
		_dirge(h)
		_hush(h)
		_altars(h)
	queue_redraw()

## bodies keep their space (d_play updateMonsters v0.22d): the crowd spreads into a ring instead of piling onto one
## spot, and a creature's body shoulders the hero aside. Drifting, flying and buried things pass through.
func _bodies(h: Hero) -> void:
	var act: Array = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.buried or m.flying or m.brain == null or m.brain.state == "sleep" or m.ai == "ghost" or (m.ai == "herald" and m.kind == "hbreath"):
			continue
		if absf(m.tp.x - h.tp.x) < 16.0 and absf(m.tp.y - h.tp.y) < 16.0:
			act.append(m)
	for m in act:
		if h.invuln <= 0.0:
			var d: float = m.tp.distance_to(h.tp)
			var mm: float = m.radius + h.radius
			if d < mm and d > 0.001:
				h.tp = zone.move(h.tp, (h.tp - m.tp) / d * (mm - d) * 0.5, h.radius)
		for o in act:
			if o == m:
				continue
			var lim: float = (m.radius + o.radius) * 1.2
			if absf(m.tp.x - o.tp.x) > lim or absf(m.tp.y - o.tp.y) > lim:
				continue
			var dd: float = m.tp.distance_to(o.tp)
			var u: Vector2
			if dd < 0.001:
				var a := fmod(float(m.get_instance_id() % 1000) * 2.399, TAU)
				u = Vector2(cos(a), sin(a))
				dd = 0.0
			else:
				u = (m.tp - o.tp) / dd
			if dd < lim:
				var k: float = (lim - dd) * (0.25 if m.radius >= o.radius * 1.6 else 0.55)
				m.tp = zone.move(m.tp, u * k, m.radius * 0.6)

func _dirge(h: Hero) -> void:
	var near := false
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.kind == "chorister" and not m.buried and m.tp.distance_to(h.tp) < 5.5:
			near = true
			break
	_lift_dirge()
	if near:
		var f: float = h.st.item("frw")
		dirge = -0.45 * (100.0 + f)
		h.st.extra["frw"] = float(h.st.extra.get("frw", 0.0)) + dirge

func _lift_dirge() -> void:
	if dirge != 0.0 and zone and zone.hero_ref and is_instance_valid(zone.hero_ref):
		var st: HeroStats = zone.hero_ref.st
		st.extra["frw"] = float(st.extra.get("frw", 0.0)) - dirge
	dirge = 0.0

## a Silent One: no light near it (the lantern shrinks to 45% within 6 yd)
func _hush(h: Hero) -> void:
	var near := false
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.kind == "hhollow" and m.tp.distance_to(h.tp) < 6.0:
			near = true
			break
	if h.lamp == null:
		return
	var base := h.light_radius() * Iso.HX * 2.0 / 512.0 * 1.25
	var want := base * (0.45 if near else 1.0)
	if near or hushed:
		h.lamp.texture_scale = lerpf(h.lamp.texture_scale, want, 0.08)
		if not near and absf(h.lamp.texture_scale - base) < 0.01:
			h.lamp.texture_scale = base
			hushed = false
	if near:
		hushed = true

func _altars(h: Hero) -> void:
	for o in altars:
		if o.get("woke", false) or o.get("used", false):
			continue
		if h.tp.distance_to(Vector2(o["x"], o["y"])) < 1.4:
			_wake_altar(o)

func _wake_altar(o: Dictionary) -> void:
	var g: Dictionary = GODS.get(str(o.get("god", "")), {})
	if g.is_empty():
		return
	o["woke"] = true
	if gods_done.get(o["god"], false):
		Bus.say.emit("The altar is cold.", 1.2)
		return
	Bus.say.emit("The altar of %s wakes. Its Herald comes." % g["name"], 3.0)
	var at := Vector2(o["x"], o["y"])
	ring(at, 0.3, 5.0, 1.0, BONE)
	var lvl := 3
	for m in get_tree().get_nodes_in_group("monsters"):
		lvl = maxi(lvl, m.level)
	var kd: Dictionary = Data.table("monsters").get("kinds", {}).get(g["mon"], {})
	var row: Dictionary = kd.get("scaled", {}).get("unique", {}).get(str(clampi(lvl, 1, 99)), {})
	var life: float = float(row.get("life", kd.get("base_life", 200))) * 0.45
	var m: Monster = Brain.spawn(zone, g["mon"], at + Vector2(2, 1), lvl, "unique", "herald", round(life))
	if m == null:
		return
	m.name_shown = g["herald"]
	m.set_meta("altar", o)
	m.brain.set("rise", 1.2)

func herald_unmade(m: Monster, god: String) -> void:
	gods_done[god] = true
	var o = m.get_meta("altar") if m.has_meta("altar") else null
	if o is Dictionary:
		o["used"] = true
	Bus.say.emit("%s is unmade." % m.name_shown, 4.0)

func _on_killed(dead_m) -> void:
	if not is_instance_valid(dead_m) or dead_m.zone != zone:
		return
	for o in get_tree().get_nodes_in_group("monsters"):
		if o.brain and o.brain.has_method("scatter_from"):
			o.brain.scatter_from(o, dead_m.tp)

# ------------------------------------------------------------------ drawing (flat on the ground, unshaded)
static func h01(x: int, y: int, s: int) -> float:
	var hh := (x * 374761393 + y * 668265263 + s * 97) & 0xffffffff
	hh = ((hh ^ (hh >> 13)) * 1274126177) & 0xffffffff
	return float((hh ^ (hh >> 16)) & 0xffffffff) / 4294967295.0

func _px(p: Vector2, col: Color, s: float = 4.0) -> void:
	var q := Iso.to_screen(p)
	draw_rect(Rect2(q.x - s * 0.5, q.y - s * 0.5, s, s), col)

func _draw() -> void:
	for f in fires:
		_draw_fire(f)
	for r in ripples:
		var q := Iso.to_screen(r["p"])
		var a: float = r["t"] / 0.9
		var k := 1.0 - a
		draw_set_transform(q, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 8.0 + 24.0 * k, 0.0, TAU, 18, Color(0.24, 0.13, 0.1, 0.7 * a), 3.0)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(q.x - 4, q.y - 2, 8, 4), Color(0.35, 0.24, 0.16, 0.6 * a))
	for r in rings:
		var k: float = 1.0 - r["t"] / r["T"]
		var rad: float = lerpf(r["r0"], r["r1"], k)
		var col: Color = r["col"]
		col.a = 0.75 * (1.0 - k)
		var n := maxi(16, int(rad * 22.0))
		for i in n:
			if i % 3 == 2:
				continue
			var ang := float(i) / n * TAU
			_px(r["p"] + Vector2(cos(ang), sin(ang)) * rad, col)
	for z in hazards:
		_draw_scar(z)
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.dead or m.buried or m.brain == null or m.zone != zone:
			continue
		var tl: Dictionary = m.brain.tell(m)
		if tl.is_empty():
			continue
		var sd := int(m.get_instance_id() % 997)
		if tl.has("disc"):
			_dust_disc(tl["disc"], tl["r"], tl["k"], sd)
		elif tl.has("lane"):
			_dust_lane(tl["lane"], tl["dir"], tl["len"], tl["half"], tl["k"], sd)

func _draw_fire(f: Dictionary) -> void:
	var q := Iso.to_screen(f["p"])
	var a: float = minf(1.0, f["t"] / 0.6)
	var R: float = f["R"]
	draw_set_transform(q, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, R * Iso.HX, Color(0.2, 0.07, 0.03, 0.55 * a))
	draw_set_transform(Vector2.ZERO)
	var s: float = f["s"]
	for i in 5:
		var ox := sin(i * 2.3 + s) * R * 40.0
		var hh := (10.0 + 12.0 * absf(sin(clock * 9.0 + i * 1.7 + s))) * a
		var col := Color(0.93, 0.55, 0.22) if i % 2 else Color(0.96, 0.78, 0.4)
		draw_rect(Rect2(q.x + ox, q.y - hh + cos(i) * 6.0, 4, hh), col)

## a slam's circle: grit lifting, thickening from the centre as the blow comes; a broken rim; cracks near the end
func _dust_disc(c: Vector2, r: float, k: float, sd: int) -> void:
	var front := 0.25 + 0.75 * k
	var n := int(r * r * 70.0)
	for i in n:
		var ang := h01(i, 1, sd) * TAU
		var rr := sqrt(h01(i, 2, sd)) * r
		if rr > r * front:
			continue
		var dens := (0.35 + 0.65 * k) * (1.0 - rr / r * 0.45)
		if h01(i, 3, sd) > dens:
			continue
		var col := BONE
		col.a = (0.25 + 0.45 * k) * (0.6 + 0.4 * h01(i, 4, sd))
		_px(c + Vector2(cos(ang), sin(ang)) * rr, col)
	var m := maxi(24, int(r * 30.0))
	var rim := BONE
	rim.a = 0.35 + 0.45 * k
	for i in m:
		if (i + sd) % 3 == 2:
			continue
		var ang := float(i) / m * TAU
		_px(c + Vector2(cos(ang), sin(ang)) * r, rim)
	if k > 0.55:
		var cr := Color(0.23, 0.2, 0.17, (k - 0.55) * 1.6)
		for j in 5:
			var ang := fmod(j * 1.3 + sd, TAU)
			var s := 0.2
			while s < r * (k - 0.3):
				var w := sin(s * 9.0 + j) * 0.06
				_px(c + Vector2(cos(ang + w), sin(ang + w)) * s, cr)
				s += 0.08

## a charge scores its lane: two broken edges and grit down the middle
func _dust_lane(p: Vector2, ax: Vector2, length: float, half: float, k: float, sd: int) -> void:
	var px := Vector2(-ax.y, ax.x)
	var L := length * (0.3 + 0.7 * k)
	var s := 0.0
	var i := 0
	while s < L:
		for sdv in [-1.0, 1.0]:
			if (int(s * 25.0) + sd) % 4 != 3:
				var col := BONE
				col.a = (0.3 + 0.5 * k) * (1.0 - s / (length * 1.1))
				_px(p + ax * s + px * half * sdv, col)
		s += 0.12
	s = 0.3
	while s < L:
		var w := -half + 0.12
		while w < half:
			i += 1
			if h01(i, 5, sd) < 0.34:
				var col2 := BONE
				col2.a = (0.15 + 0.3 * k) * (1.0 - s / (length * 1.1))
				_px(p + ax * s + px * w, col2)
			w += 0.18
		s += 0.1

func _draw_scar(z: Dictionary) -> void:
	var k: float = z["t"] / z["T"]
	var sd := int(z["s"])
	for j in 7:
		var ang := fmod(j * 0.9 + z["s"], TAU)
		var s := 0.15
		while s < z["r"] * 0.95:
			var w := sin(s * 8.0 + j * 2.0) * 0.08
			var p: Vector2 = z["p"] + Vector2(cos(ang + w), sin(ang + w)) * s
			_px(p, Color(0.07, 0.06, 0.05, 0.9 * k))
			var lip := BONE
			lip.a = 0.45 * k
			var q := Iso.to_screen(p)
			draw_rect(Rect2(q.x - 2, q.y + 2, 4, 4), lip)
			s += 0.06
	for n in 40:
		var ang := h01(n, 3, sd) * TAU
		var rr := sqrt(h01(n, 7, sd)) * float(z["r"])
		var col := BONE
		col.a = 0.35 * k * h01(n, 11, sd)
		_px(z["p"] + Vector2(cos(ang), sin(ang)) * rr, col)

# ------------------------------------------------------------------ the Pontiff's bone walls
class BoneWall extends Node2D:
	var tp := Vector2.ZERO
	var life := 5.0
	var max_life := 5.0

	func _ready() -> void:
		position = Iso.to_screen(tp)

	func _physics_process(dt: float) -> void:
		life -= dt
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := minf(1.0, minf((max_life - life) / 0.25, life / 0.4))
		var hgt := 64.0 * k
		for i in 3:
			var col := Color(0.91, 0.886, 0.816) if i == 1 else Color(0.66, 0.63, 0.54)
			var x := -16.0 + i * 12.0
			var y := -hgt + (i % 2) * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 8, 4), Vector2(x + 5, y), Vector2(x + 3, y)]), col)
			draw_rect(Rect2(x + 2, y, 4, 8), Color(0.957, 0.937, 0.886))
