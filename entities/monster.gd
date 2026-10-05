class_name Monster
extends Node2D
## A creature of the god, spawned from the zone export. Numbers come from data/monsters.json (the web build's final
## makeMon, sampled per rank and level). Behaviour lives in a Brain (entities/ai/*.gd) chosen by the kind's AI.
## The body keeps the shared state every brain and skill reads: poise and reel, statuses, burrowing, facing.

var zone: Zone
var info: Dictionary
var kd: Dictionary        # the kind's row in monsters.json
var kind := ""
var ai := "husk"
var rank := "normal"
var name_shown := ""
var level := 1
var tp := Vector2.ZERO
var home := Vector2.ZERO
var hp := 10.0
var hp_max := 10.0
var dmg := Vector2(1, 2)
var speed := 1.5
var armor := 0.0
var xp := 1
var radius := 0.3
var resists := {}
var mods: Array = []
var pack := ""
var boss := false
var spr: AnimSprite
var shadow: Polygon2D
var face := 1
var view := "front"
var dead := false
var buried := false        # burrowed or not in its hours: untargetable, takes nothing
var flying := false
var z_lift := 0.0          # height above the ground (flyers), in screen px
var awake := false
var brain: Brain

# poise and reel (checklist section 6)
var poise := 10.0
var poise_max := 10.0
var poise_quiet := 0.0     # time since the last poise damage
var reeling := 0.0
var after_reel := 0.0
var reel_grace := 0.0
var finisher_lock := 0.0

# statuses
var stun := 0.0
var root := 0.0
var slow := 0.0
var feared := 0.0
var confused := 0.0
var _confused_t := 0.0
var _confused_to := Vector2.ZERO
var marked := 0.0
var dots: Array = []       # [{dps, t, elem, tick}]
var hit_flash := 0.0
var corpse_t := 0.0

func setup(z: Zone, m: Dictionary) -> void:
	zone = z
	info = m
	kind = m["kind"]
	ai = m.get("ai", "husk")
	rank = m.get("rank", "normal")
	level = int(m.get("level", 1))
	pack = str(m.get("pack", ""))
	boss = bool(m.get("boss", false)) or rank == "boss"
	mods = m.get("mods", [])
	name_shown = m.get("name", kind)
	tp = Vector2(m["x"], m["y"])
	home = tp
	kd = Data.table("monsters").get("kinds", {}).get(kind, {})
	_numbers()
	Affixes.roll(self)
	var sk := kind
	if rank == "champion" or rank == "unique":
		if ResourceLoader.exists("res://art/sprites/%s@%s.json" % [kind, rank]):
			sk = kind + "@" + rank
	spr = AnimSprite.new(Data.sprite_set(sk))
	add_child(spr)
	_true_size()
	spr.play("idle")
	spr.t = randf()
	spr.face = 1 if randf() < 0.5 else -1
	face = spr.face
	_shadow()
	position = Iso.to_screen(tp)
	add_to_group("monsters")
	brain = Brain.make(self)

## true size (Derek 2026-10-05: "I want the world true to size"). One yard is about 100 px on screen and a man stands
## about two yards (the heroes, ~200 px). The browser's creature sprites were drawn about a quarter too small (a Husk
## ~1.25 yd, a Warden ~1.5): they are drawn at true size here. Bosses and the PixelForge sets (already true) keep theirs.
const TRUE_SIZE := 1.3
func _true_size() -> void:
	if boss or spr.set == null:
		return
	if str(spr.set.meta.get("source", "")) in ["pixelforge", "lpc"]:
		return
	spr.scale = Vector2(TRUE_SIZE, TRUE_SIZE)

func _numbers() -> void:
	var r := rank if rank in ["normal", "champion", "unique", "minion", "boss"] else "normal"
	var row: Dictionary = kd.get("scaled", {}).get(r, {}).get(str(clampi(level, 1, 99)), {})
	if row.is_empty():
		hp_max = float(info.get("hp", 20))
		dmg = Vector2(2, 5)
		speed = 1.5
	else:
		hp_max = float(row.get("life", info.get("hp", 20)))
		var dd: Array = row.get("dmg", [2, 5])
		dmg = Vector2(dd[0], dd[1])
		speed = float(row.get("spd", 1.5))
		armor = float(row.get("armor", 0))
		xp = int(row.get("xp", 1))
	if info.has("hp"):
		hp_max = float(info["hp"])     # the export's own spawned life wins (packs, uniques, bosses)
	hp = hp_max
	radius = float(info.get("r", kd.get("radius", 0.3)))
	var rr = kd.get("resists_at_spawn")
	resists = rr.duplicate() if rr is Dictionary else {}
	for md in mods:
		match md:
			"Extra Fast":
				speed *= 1.4
			"Extra Strong":
				dmg *= 1.5
			"Stone Skin":
				armor += 80.0
	var pk: float = Brain._num(kd.get("poiseK"), 0.5)
	if boss:
		pk *= 1.6
	elif rank == "unique":
		pk *= 1.2
	poise_max = hp_max * pk * 3.0
	poise = poise_max
	flying = ai == "flyer"

func _shadow() -> void:
	shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	var rw := 34.0 * clampf(radius / 0.3, 0.7, 3.5)
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * rw, sin(a) * rw * 0.4 + 6.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.22)   # the contact shadow under the feet
	add_child(shadow)
	move_child(shadow, 0)
	# the silhouette the hero's lantern (or the sun) throws on the ground (entities/sil_shadow.gd)
	if zone.shadow_layer:
		zone.shadow_layer.add_child(SilShadow.new(spr, self, false))

# ------------------------------------------------------------------ numbers the brain and skills use
func roll_damage() -> float:
	Combat.striker = self   # the blow about to land knows whose it is (the deeds: Thirsting, Nail-Fisted)
	Combat.striker_frame = Engine.get_physics_frames()
	var weak := 0.6 if float(get_meta("k_weak", -1.0)) > Time.get_ticks_msec() / 1000.0 else 1.0   # the Pinch drains it
	return randf_range(dmg.x, dmg.y) * hour_mult() * weak

func hour_mult() -> float:
	if zone == null or not zone.d.get("outdoor", false):
		return 1.0
	var h = kd.get("hours")
	if not (h is Dictionary):
		return 1.0
	var v = h.get(Game.hour_name(), 1.0)
	return float(v) if (v is float or v is int) else 1.0

func walks_now() -> bool:
	var hh = kd.get("hours")
	if not (hh is Dictionary):
		return true
	var when: Array = hh.get("when", [])
	if when.is_empty() or zone == null or not zone.d.get("outdoor", false):
		return true
	return Game.hour_name() in when

func move_speed() -> float:
	var s := speed * (Game.hour_speed() if zone.d.get("outdoor", false) else 1.0)
	if slow > 0.0:
		s *= 1.0 - minf(0.6, slow)
	if after_reel > 0.0:
		s *= 0.55
	return s

func can_act() -> bool:
	return not dead and stun <= 0.0 and reeling <= 0.0

## the raised dead: bone and husk the Ossuary stood back up (the Reading's "damage to the raised dead", the Unraised)
const RAISED := ["hollow", "drowned", "archer", "ossarcher", "marrow", "knight", "hbone", "hhollow", "calc_knight", "marrow_ghoul", "chalk_wraith", "osteo"]
func is_raised() -> bool:
	if kind in RAISED:
		return true
	var n := name_shown.to_lower()
	return n.contains("husk") or n.contains("ossuary") or n.contains("weeper") or n.contains("bone") or n.contains("marrow")

func damage_taken_mult(elem: String, from: Vector2, opts: Dictionary) -> float:
	var k := 1.0
	var h := hero()
	if h and h.st and not opts.get("dot", false) and h.st.fate.has("raised") and is_raised():
		k *= 1.0 + float(h.st.fate["raised"]) / 100.0
	if marked > 0.0:
		k *= 1.3
	if brain:
		k *= brain.damage_taken_mult(self, elem, from, opts)
	return k

# ------------------------------------------------------------------ poise, reel and stagger
func add_poise_damage(pd: float, heavy: bool) -> void:
	if reel_grace > 0.0 or reeling > 0.0:
		return
	poise -= pd * (2.5 if heavy else 1.0)
	poise_quiet = 0.0
	if poise <= 0.0:
		var base := 0.2 if boss else (0.25 if rank == "unique" else 0.35)
		reeling = base * Combat.STAGGER
		Sfx.play("break", 0.8)
		poise = poise_max
		if brain:
			brain.on_reel(self)

func on_hit(d: float, elem: String, from: Vector2, opts: Dictionary) -> void:
	hit_flash = 0.12
	awake = true
	if brain:
		brain.on_hit(self, d, from, opts)
	var dir := Vector2.UP
	if from != Vector2.INF:
		dir = (Iso.to_screen(tp) - Iso.to_screen(from)).normalized()
	if not opts.get("dot", false):
		Fx.blood(zone.sorted, position + Vector2(0, -40), dir, 3)
	if Settings.damage_numbers:
		Fx.number(zone.sorted, position + Vector2(0, -110), d)

func add_dot(dps: float, secs: float, elem: String) -> void:
	dots.append({"dps": dps, "t": secs, "elem": elem, "tick": 0.5})

func die(from: Vector2 = Vector2.INF) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	remove_from_group("monsters")
	add_to_group("corpses")
	var back := from != Vector2.INF and (tp - from).dot(Vector2(1, 1)) < 0.0
	if spr.set and spr.set.has("death_back") and back:
		spr.play("death_back", true, false)
	else:
		spr.play("death", true, false)
	corpse_t = 30.0
	var sp = load("res://world/splats.gd").at(zone)   # the ground it bleeds or scatters bone into (za_death21.js)
	if sp:
		sp.death(kind, tp, radius > 0.35)
	if brain:
		brain.on_death(self)
	if not mods.is_empty():
		Affixes.on_death(self)
	Bus.monster_killed.emit(self)
	z_index = -5

# ------------------------------------------------------------------ the frame
func _physics_process(dt: float) -> void:
	if dead:
		spr.step(dt)
		corpse_t -= dt
		# the corpse darkens, browns and sinks as it lies (za_death21.js: brightness 0.62 -> 0.28, saturation down,
		# sepia up, a flattening of 45% from 4 s after death to 10 s before it goes)
		var rot := clampf((26.0 - corpse_t) / 20.0, 0.0, 1.0)
		var br := 0.62 - 0.34 * rot
		modulate = Color(br * (1.0 + 0.12 * rot), br * (1.0 + 0.04 * rot), br * (1.0 - 0.1 * rot), modulate.a)
		spr.scale.y = absf(spr.scale.x) * (1.0 - 0.45 * rot)
		if corpse_t < 0.0:
			modulate.a = maxf(0.0, modulate.a - dt * 0.2)
			if modulate.a <= 0.0:
				queue_free()
		return
	_tick_status(dt)
	if feared > 0.0 and not boss and can_act():
		# feared: it flees from the hero, and does nothing else (checklist 5)
		var h := hero()
		if h:
			step_toward(tp + (tp - h.tp).normalized() * 2.0, dt)
			if spr.set.has("walk"):
				spr.play("walk")
	elif confused > 0.0 and not boss and can_act():
		# confused: it wanders and strikes whatever creature it meets
		_confused_t -= dt
		if _confused_t <= 0.0:
			_confused_t = 0.6
			_confused_to = tp + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			for o in get_tree().get_nodes_in_group("monsters"):
				if o != self and not o.dead and o.tp.distance_to(tp) < 1.4:
					Combat.hit_monster(o, roll_damage(), "phys", tp, {"poise": 0.0})
					break
		step_toward(_confused_to, dt)
	elif brain:
		brain.tick(self, dt)
		if not mods.is_empty():
			Affixes.tick(self, dt)
		if brain.state != _heard_state:
			_heard_state = brain.state
			_voice(_heard_state)
	spr.face = face
	spr.view = view
	position = Iso.to_screen(tp) + Vector2(0, -z_lift)
	if shadow:
		shadow.position = Vector2(0, z_lift)
		shadow.visible = not buried
	spr.visible = not buried
	if hit_flash > 0.0:
		hit_flash -= dt
		spr.self_modulate = Color(1.35, 1.2, 1.15) if hit_flash > 0.0 and Settings.hit_flash else Color.WHITE

func _tick_status(dt: float) -> void:
	stun = maxf(0.0, stun - dt)
	root = maxf(0.0, root - dt)
	feared = maxf(0.0, feared - dt)
	confused = maxf(0.0, confused - dt)
	marked = maxf(0.0, marked - dt)
	reel_grace = maxf(0.0, reel_grace - dt)
	finisher_lock = maxf(0.0, finisher_lock - dt)
	slow = maxf(0.0, slow - 0.8 * dt)
	if reeling > 0.0:
		reeling -= dt
		if reeling <= 0.0:
			after_reel = 0.8
			reel_grace = 0.9 if boss else (1.4 if rank == "unique" else 2.0)
	elif after_reel > 0.0:
		after_reel -= dt
	poise_quiet += dt
	if poise_quiet > 2.2:
		poise = minf(poise_max, poise + poise_max * 0.5 * dt)
	for d in dots:
		d["t"] -= dt
		d["tick"] -= dt
		if d["tick"] <= 0.0:
			d["tick"] += 0.5
			Combat.hit_monster(self, float(d["dps"]) * 0.5, d["elem"], Vector2.INF, {"dot": true, "poise": 0.0})
			if dead:
				return
	dots = dots.filter(func(d): return d["t"] > 0.0)

## move toward a tile point by speed*dt, sliding on walls; flyers ignore terrain
func step_toward(p: Vector2, dt: float, spd: float = -1.0) -> bool:
	if root > 0.0:
		return false
	var s := (move_speed() if spd < 0.0 else spd) * dt
	var to := p - tp
	if to.length() < 0.02:
		return false
	var v := to.normalized() * minf(s, to.length())
	if flying:
		tp += v
	else:
		tp = zone.move(tp, v, radius * 0.6)
	look(v)
	return true

func look(dir: Vector2) -> void:
	# a hand-drawn set (PixelForge, eight views) turns eight ways; the old painted sets have front and back only
	var r := AnimSprite.hero_view(dir, face, spr.set) if spr and spr.set and spr.set.has_view("side") else AnimSprite.mon_view(dir, face)
	if r[0] != "":
		view = r[0]
		face = r[1]

func hero() -> Hero:
	return zone.hero_ref


# ------------------------------------------------------------------ what you hear it do
var _heard_state := ""
## a wind-up creaks and scrapes (the tell you can hear), the blow itself cuts the air; quieter the farther it is
func _voice(s: String) -> void:
	var h = zone.hero_ref if zone else null
	if h == null or not is_instance_valid(h):
		return
	var k := clampf(1.0 - tp.distance_to(h.tp) / 12.0, 0.0, 1.0)
	if k <= 0.05:
		return
	var low := 0.75 if boss else (0.9 if radius > 0.45 else 1.1)
	if s.ends_with("wind"):
		Sfx.play("m_wind", k, low)
	elif s in ["strike", "lunge", "charge", "lash", "dash", "swoop"]:
		Sfx.play("swing", k * 0.9, low * 0.72)
