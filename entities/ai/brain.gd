class_name Brain
extends RefCounted
## The shared behaviour of every creature (checklist 15.2): sleeping and loitering about its spot, waking by sight
## (7.5 yd, less at low level or with the wick dimmed), packmates waking one by one, attack tokens, and the standard
## melee rhythm: chase -> wind-up -> strike -> recover -> gap. Each AI kind overrides what it needs (entities/ai/*.gd).

var state := "sleep"
var lost_t := 0.0             # The Unwritten reversed: time the hero has been out of sight
var st := 0.0            # time in the state / timer
var loiter_t := 0.0
var loiter_to := Vector2.ZERO
var aim := Vector2.ZERO  # where a strike lands
var wind := 0.5
var rec := 0.7
var reach := 0.95
var gap := 0.3
var wake_delay := -1.0
var token := false
var struck := false

static var TOKENS := {}  # zone instance id -> number of melee tokens held

static func make(m: Monster) -> Brain:
	var path := "res://entities/ai/ai_%s.gd" % m.ai
	var b: Brain
	if ResourceLoader.exists(path):
		b = load(path).new()
	else:
		b = Brain.new()
	b.init(m)
	return b

func init(m: Monster) -> void:
	var a = m.kd.get("attack")
	if a is Dictionary:
		wind = _num(a.get("windup_s"), 0.5)
		rec = _num(a.get("recover_s"), 0.7)
		reach = _num(a.get("range_yd"), 0.95)
	loiter_to = m.home
	loiter_t = randf_range(0.5, 3.0)

static func _num(v, fb: float) -> float:
	return float(v) if (v is float or v is int) else fb

# ------------------------------------------------------------------ hooks a kind may override
func damage_taken_mult(m: Monster, elem: String, from: Vector2, opts: Dictionary) -> float:
	return 1.0

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	if state == "sleep":
		wake(m)

func on_reel(m: Monster) -> void:
	if state == "wind":
		state = "recover"
		st = rec

func on_death(m: Monster) -> void:
	_release_token(m)

func tick(m: Monster, dt: float) -> void:
	var h := m.hero()
	if h == null:
		_anim(m, dt)
		return
	if not m.walks_now():
		m.buried = true
		_anim(m, dt)
		return
	elif m.buried and state != "burrowed":
		m.buried = false
	if not m.can_act():
		m.spr.play("hit" if m.spr.set.has("hit") else "idle")
		m.spr.step(dt)
		return
	if state == "sleep":
		_sleep(m, h, dt)
	else:
		think(m, h, dt)
	_anim(m, dt)

## the awake behaviour: the standard melee rhythm. Kinds override this.
func think(m: Monster, h: Hero, dt: float) -> void:
	melee_rhythm(m, h, dt)

# ------------------------------------------------------------------ sleep, loiter, wake
func wake_range(m: Monster, h: Hero) -> float:
	var r := 7.5
	if h.st.level <= 3:
		r *= 0.7
	elif h.st.level <= 8:
		r *= 0.85
	if h.st.dim_wick:
		r *= 0.7
	var a = h.st.arc
	if a:
		if a.aM("h_quiet"):
			r *= 0.7   # Unheard
		if a.aR("v_silence"):
			r *= 0.5   # the Last Silence reversed: your skills make no light
	return r

func _sleep(m: Monster, h: Hero, dt: float) -> void:
	if wake_delay >= 0.0:
		wake_delay -= dt
		if wake_delay < 0.0:
			wake(m)
			return
	var d := m.tp.distance_to(h.tp)
	if d < wake_range(m, h) and not h.dead and m.zone.sight_clear(m.tp, h.tp) and not (h.skills and h.skills.unseen(m)):
		wake(m)
		return
	# loiter: small hops about the spot
	loiter_t -= dt
	if loiter_t <= 0.0:
		loiter_t = randf_range(1.2, 3.0)
		var a := randf() * TAU
		loiter_to = m.home + Vector2(cos(a), sin(a)) * randf_range(0.5, 2.6)
	if m.tp.distance_to(loiter_to) > 0.1:
		m.step_toward(loiter_to, dt, m.speed * 0.35)

func wake(m: Monster) -> void:
	if state != "sleep":
		return
	state = "chase"
	st = 0.0
	m.awake = true
	if m.boss:
		Bus.boss_woke.emit(m)
	# packmates within 10 yd wake one by one
	for o in m.get_tree().get_nodes_in_group("monsters"):
		if o != m and o.pack == m.pack and o.brain and o.brain.state == "sleep" and o.brain.wake_delay < 0.0:
			var d: float = o.tp.distance_to(m.tp)
			if d < 10.0:
				o.brain.wake_delay = randf_range(0.35, 1.6) + 0.08 * d

# ------------------------------------------------------------------ attack tokens
func max_tokens(m: Monster) -> int:
	# the HERO's level, as zz_mobai63 tokensFor(): 4 at level 1, 7 from level 15. (It was the creature's level, which
	# handed 7 tokens at hero level 1 in a level-15 zone: the "zerged at level 1" complaint.)
	var h := m.hero()
	var lv: int = h.st.level if h else m.level
	var n := mini(7, int(round((3 + floori(lv / 5.0)) * 1.2)))
	if h and m.zone:
		# v0.88 (user): a big pack presses the attack; half of those close get a turn
		var close := 0
		for o in m.get_tree().get_nodes_in_group("monsters"):
			if o.zone == m.zone and not o.dead and o.brain and o.brain.state != "sleep" and o.tp.distance_to(h.tp) < 5.0:
				close += 1
		n = maxi(n, ceili(close * 0.5))
	return n

func _key(m: Monster) -> int:
	return m.zone.get_instance_id()

func take_token(m: Monster) -> bool:
	if float(m.get_meta("k_silent", -1.0)) > Time.get_ticks_msec() / 1000.0:
		return false   # the Pinch: it cannot strike for a while
	if token:
		return true
	var k := _key(m)
	var n: int = TOKENS.get(k, 0)
	if n < max_tokens(m):
		TOKENS[k] = n + 1
		token = true
	return token

func _release_token(m: Monster) -> void:
	if token:
		var k := _key(m)
		TOKENS[k] = maxi(0, TOKENS.get(k, 1) - 1)
		token = false

# ------------------------------------------------------------------ the standard melee rhythm
## the creature's foe: the hero, or a standing ally (the golem) when one is nearer or has challenged it
## (skills/animancer.gd nearest_target; checklist 15.2 "taunted: attacks the golem")
static var _mys = null
func foe(m: Monster, h: Hero):
	if _mys == null:
		_mys = load("res://skills/animancer.gd")
	if m.get_tree().get_nodes_in_group("allies").is_empty():
		return h
	var f = _mys.nearest_target(m.zone, m)
	return f if f != null else h

func melee_rhythm(m: Monster, h: Hero, dt: float, spd_k: float = 1.0) -> void:
	st -= dt
	var f = foe(m, h)
	var fp: Vector2 = f.tp
	var gone: bool = h.dead if f == h else (f.has_method("is_down") and f.is_down())
	var d := m.tp.distance_to(fp)
	match state:
		"chase":
			if gone:
				state = "home"
				return
			if f == h and h.st.arc and h.st.arc.aR("v_unwritten"):
				lost_t = lost_t + dt if not m.zone.sight_clear(m.tp, h.tp) else 0.0
				if lost_t > 2.0:
					lost_t = 0.0
					state = "home"
					return
			if d > 26.0:
				state = "home"
				return
			if d <= reach + m.radius:
				if take_token(m):
					state = "wind"
					st = wind
					aim = fp
					m.look(fp - m.tp)
				else:
					_circle(m, h, dt)
			else:
				if not take_token(m) and d < 3.0 and f == h:
					_circle(m, h, dt)
				else:
					_approach(m, fp, dt, spd_k)
		"wind":
			m.look(fp - m.tp)
			aim = fp
			if st <= 0.0:
				state = "strike"
				st = 0.18
				struck = false
		"strike":
			if not struck:
				struck = true
				if f == h:
					strike(m, h)
				elif f.tp.distance_to(aim) <= 0.8 + float(f.get("radius") if f.get("radius") != null else 0.5):
					f.take_hit(m.roll_damage(), "phys", m.tp)
			if st <= 0.0:
				state = "recover"
				st = rec
		"recover":
			if st <= 0.0:
				state = "gap"
				st = gap
				if randf() < 0.5:
					_release_token(m)
					st = randf_range(0.8, 1.8)
		"gap":
			if st <= 0.0:
				state = "chase"
		"home":
			_release_token(m)
			if m.step_toward(m.home, dt) == false or m.tp.distance_to(m.home) < 0.5:
				state = "sleep"
		_:
			state = "chase"

## a strike lands if the hero is within 0.8 yd of the aim point
func strike(m: Monster, h: Hero) -> void:
	if h.tp.distance_to(aim) <= 0.8 + h.radius and h.tp.distance_to(m.tp) <= reach + m.radius + 0.6:
		Combat.hit_hero(h, m.roll_damage(), "phys", m.tp)

func _approach(m: Monster, p: Vector2, dt: float, spd_k: float = 1.0) -> void:
	if m.zone.line_clear(m.tp, p) or m.flying:
		m.step_toward(p, dt, m.move_speed() * spd_k)
	else:
		if not has_meta_path(m) or path_t <= 0.0:
			path = m.zone.path(m.tp, p)
			path_i = 1 if path.size() > 1 else 0
			path_t = 0.6
		path_t -= dt
		if path_i < path.size():
			if m.tp.distance_to(path[path_i]) < 0.2:
				path_i += 1
			if path_i < path.size():
				m.step_toward(path[path_i], dt, m.move_speed() * spd_k)

var path := PackedVector2Array()
var path_i := 0
var path_t := 0.0
func has_meta_path(m: Monster) -> bool:
	return path.size() > 0

## without a token: hold a loose ring about the hero and feint
func _circle(m: Monster, h: Hero, dt: float) -> void:
	var off := m.tp - h.tp
	var r := maxf(1.8, off.length())
	var a := atan2(off.y, off.x) + dt * 0.6 * (1.0 if (m.get_instance_id() % 2) == 0 else -1.0)
	var want := h.tp + Vector2(cos(a), sin(a)) * clampf(r, 1.8, 2.6)
	m.step_toward(want, dt, m.move_speed() * 0.6)
	m.look(h.tp - m.tp)

# ------------------------------------------------------------------ drawing
func _anim(m: Monster, dt: float) -> void:
	var a := "idle"
	match state:
		"wind":
			a = "wind" if m.spr.set.has("wind") else "atk"
		"strike":
			a = "atk"
		"chase", "home":
			a = "walk"
		"sleep":
			a = "walk" if m.tp.distance_to(loiter_to) > 0.1 else "idle"
	m.spr.play(a)
	var k := 1.0
	if a == "walk":
		k = m.move_speed() / maxf(0.5, float(m.kd.get("speed_yd_s", 1.5)))
	m.spr.step(dt, k)

# ==================================================================== (creature AI port): shared helpers for ai_*.gd
# Everything below is additive: the AI kinds (entities/ai/ai_<ai>.gd) override tick() with kind_tick(), which keeps
# the base's sleep/loiter/wake and adds the web build's per-creature timers (m.t, m.cd), the hour-hiding rule of
# zv_time24 (hidden only while you are more than 9 yd off), stun breaking wind-ups, D2-imp skittishness
# (zz_zz_imps67), the struck recoil pose, and helpers for lunges, allies, lights and spawning.
const AIWorld := preload("res://entities/ai/ai_world.gd")
var t := 0.0              # time in the current state (the web's m.t)
var cd := 0.0             # a creature's own rest before its next move (the web's m.cd; a rhythm, not a player wait)
var hurt_t := 0.0         # struck recoil pose
var time_hidden := false  # lying hidden outside its hours
var last_tp := Vector2.INF
var moved := false
var odir := 0             # which way it circles (+1/-1)
var aim_dir := Vector2.RIGHT  # a locked heading (lunges, charges, dashes)
var world: Node           # the zone's AIWorld (ground fires, ripples, telegraphs, bone walls, altars)
# skittishness (zz_zz_imps67)
var sk := -1.0
var panic := 0.0
var pv := 0.0
var back_t := 0.0
var bv := 0.0
var ap := 0.0
var hes := false
var wv := 0.0
var low_fled := false
var crowd_t := 0.0
var crowd_k := 1.0

## states a stun or reel breaks (the web: windup, slamWind, chargeWind, charge)
static var DBG := OS.has_environment("AIDBG")
const BREAKABLE := ["wind", "lwind", "cwind", "charge", "lunge", "swind", "dash", "swoop", "swait"]

func kind_tick(m: Monster, dt: float) -> void:
	if world == null:
		world = AIWorld.of(m.zone)
	var h := m.hero()
	t += dt
	cd -= dt
	hurt_t -= dt
	if h == null:
		pose(m, dt)
		return
	if _hours_hidden(m, h):
		return
	if not m.can_act():
		if state in BREAKABLE:
			interrupted(m)
		m.spr.play("hit" if m.spr.set.has("hit") else "idle")
		m.spr.step(dt)
		last_tp = m.tp
		return
	if state == "sleep":
		if m.tp.distance_to(h.tp) > 32.0 and wake_delay < 0.0:
			return
		_sleep(m, h, dt)
	else:
		think(m, h, dt)
	_anim(m, dt)
	if DBG and Engine.get_physics_frames() % 30 == 0 and m.tp.distance_to(h.tp) < 12.0:
		print("AI %s %s st=%s t=%.2f cd=%.2f d=%.2f hp=%d/%d tok=%s bur=%s z=%.0f" % [m.kind, m.rank, state, t, cd, m.tp.distance_to(h.tp), m.hp, m.hp_max, token, m.buried, m.z_lift])

## a stun or a reel breaks the wind-up (a boss goes to recover)
func interrupted(m: Monster) -> void:
	_release_token(m)
	if m.boss:
		state = "recover"
		st = rec
	else:
		state = "chase"
	t = 0.0

func set_state(s: String) -> void:
	state = s
	t = 0.0

## zv_time24: out of its hours a creature lies hidden where it stood, but never vanishes before your eyes
func _hours_hidden(m: Monster, h: Hero) -> bool:
	var out := m.walks_now()
	if not out and not time_hidden and m.tp.distance_to(h.tp) > 9.0:
		time_hidden = true
		m.buried = true
		_release_token(m)
		state = "sleep"
		wake_delay = -1.0
	elif out and time_hidden:
		time_hidden = false
		m.buried = false
		if world:
			world.grit_burst(m.tp, Color(0.36, 0.4, 0.5), 10)
	return time_hidden

## the hero's front as a tile-space unit vector, from the way he faces (view + mirror)
static func hero_front(h: Hero) -> Vector2:
	var s := Vector2(1, 0)
	match h.view:
		"down":
			s = Vector2(0, 1)
		"up":
			s = Vector2(0, -1)
		"front":
			s = Vector2(h.face, 1).normalized()
		"back":
			s = Vector2(h.face, -1).normalized()
		"side":
			s = Vector2(h.face, 0)
	var v := Iso.to_tile(s)
	return v.normalized() if v.length() > 0.0001 else Vector2(1, 0)

func behind_hero(m: Monster, h: Hero) -> bool:
	return (m.tp - h.tp).dot(hero_front(h)) < 0.0

## can the hero see it? Open ground by day, inside his lantern's pool (and a step past it), or near a world light.
## The user's rule: every danger is plainly seen, so nothing looses a shot from the dark (it closes in first).
static func in_sight_of(m: Monster, h: Hero) -> bool:
	if m.zone and m.zone.d.get("outdoor", false) and Game.hour_name() != "night":
		return true
	if m.tp.distance_to(h.tp) <= h.light_radius() + 0.5:
		return true
	var w = AIWorld.of(m.zone) if m.zone else null
	return w != null and w.has_method("light_near") and w.light_near(m.tp) != Vector2.INF

func dir_to(m: Monster, p: Vector2) -> Vector2:
	var v := p - m.tp
	return v.normalized() if v.length() > 0.0001 else Vector2(1, 0)

## packmates of the same kind that are awake within R (the web's awakePackmates)
func awake_packmates(m: Monster, r: float) -> int:
	var n := 0
	for o in m.get_tree().get_nodes_in_group("monsters"):
		if o != m and o.kind == m.kind and o.brain and o.brain.state != "sleep" and o.tp.distance_to(m.tp) < r:
			n += 1
	return n

## move by v sliding on walls (a lunge or a charge); returns how far it really went
func shove(m: Monster, v: Vector2) -> float:
	var o := m.tp
	m.tp = m.zone.move(m.tp, v, m.radius * 0.6)
	return m.tp.distance_to(o)

func circle_dir() -> int:
	if odir == 0:
		odir = 1 if randf() < 0.5 else -1
	return odir

## the minions and summons that monster blows can also strike (group "allies": tp, radius, take_hit)
static func hit_allies(tree: SceneTree, c: Vector2, r: float, dmg: float, elem: String, from: Vector2) -> void:
	for a in tree.get_nodes_in_group("allies"):
		if a.has_method("take_hit") and a.get("tp") != null and a.tp.distance_to(c) < r + float(a.get("radius") if a.get("radius") != null else 0.3):
			a.take_hit(dmg, elem, from)

func hero_open(h: Hero) -> bool:
	return h != null and not h.dead and h.invuln <= 0.0

## the plain web strike: a blow lands if the hero is within 0.8 yd of the point reach*0.8 ahead
func strike_at(m: Monster, h: Hero, r: float, mult: float = 1.0) -> bool:
	var hx := m.tp + dir_to(m, aim) * r * 0.8
	if world:
		world.grit_burst(hx, Color(0.44, 0.42, 0.47), 3)
	hit_allies(m.get_tree(), hx, 0.8, m.roll_damage() * mult, "phys", m.tp)
	if h.tp.distance_to(hx) < 0.8 + h.radius:
		Combat.hit_hero(h, m.roll_damage() * mult, "phys", m.tp)
		return true
	return false

## a new creature mid-fight (a boss's call, a birth): a row shaped like the export's monster rows
static func spawn(zone: Zone, kind: String, at: Vector2, level: int, rank: String = "normal", pack: String = "", hp: float = -1.0) -> Monster:
	var kd: Dictionary = Data.table("monsters").get("kinds", {}).get(kind, {})
	if kd.is_empty():
		return null
	var p := at
	if zone.is_solid(p):
		var c := zone._nearest_open(Vector2i(int(p.x), int(p.y)))
		p = Vector2(c.x + 0.5, c.y + 0.5)
	var row := {"kind": kind, "name": kd.get("name", kind), "spr": kd.get("sprite", kind), "ai": kd.get("ai", "husk"),
		"level": maxi(1, level), "rank": rank, "pack": pack if pack != "" else "spawn%d" % randi(), "x": p.x, "y": p.y,
		"r": float(kd.get("radius", 0.3)), "mods": [], "boss": false}
	if hp > 0.0:
		row["hp"] = hp
	var m := Monster.new()
	zone.sorted.add_child(m)
	m.setup(zone, row)
	m.brain.state = "chase"
	m.awake = true
	return m

# ------------------------------------------------------------------ skittishness (zz_zz_imps67, zz_mobai63)
func skit(m: Monster) -> float:
	if sk < 0.0:
		var x := maxf(1.0, float(m.kd.get("xp", 20)))
		sk = 0.0 if m.boss else clampf(14.4 / x, 0.08, 0.48) * (0.5 if m.rank == "unique" else 1.0)
	return sk

func _crowd(m: Monster) -> float:
	if Time.get_ticks_msec() / 1000.0 > crowd_t:
		crowd_t = Time.get_ticks_msec() / 1000.0 + 0.5
		var n := 0
		for o in m.get_tree().get_nodes_in_group("monsters"):
			if o != m and o.brain and o.brain.state != "sleep" and absf(o.tp.x - m.tp.x) < 5.0 and absf(o.tp.y - m.tp.y) < 5.0:
				n += 1
		crowd_k = 0.3 if n >= 5 else (0.6 if n >= 3 else 1.0)
	return crowd_k

## run from the hero, veering so a pack scatters rather than retreating in a line
func _flee_step(m: Monster, h: Hero, dt: float, k: float = 1.15) -> void:
	var a := atan2(m.tp.y - h.tp.y, m.tp.x - h.tp.x) + pv
	var to := m.tp + Vector2(cos(a), sin(a)) * 2.0
	if not m.zone.is_solid(to):
		m.step_toward(to, dt, m.move_speed() * k)
	else:
		pv += 0.8 * (-1.0 if randf() < 0.5 else 1.0)

## returns true when skittishness took the frame (a weaving approach, a hop back, a panic)
func skittish(m: Monster, h: Hero, dt: float) -> bool:
	var k := skit(m)
	if k <= 0.0 or h.dead or reach >= 2.2:
		return false
	k *= _crowd(m)
	if panic > 0.0:
		panic -= dt
		_flee_step(m, h, dt)
		return true
	if not low_fled and m.hp < m.hp_max * 0.18 and randf() < k * 0.45:
		low_fled = true
		panic = randf_range(0.9, 1.5)
		pv = randf_range(-0.7, 0.7)
		_release_token(m)
		return true
	if back_t > 0.0:
		back_t -= dt
		var a := atan2(m.tp.y - h.tp.y, m.tp.x - h.tp.x) + bv
		var to := m.tp + Vector2(cos(a), sin(a))
		if not m.zone.is_solid(to):
			m.step_toward(to, dt, m.move_speed() * 0.9)
		return false   # the recover timer still runs
	var d := m.tp.distance_to(h.tp)
	var ringed := not token and d < 4.4
	if state == "chase" and not ringed and d > reach + 0.6 and d < 26.0:
		ap -= dt
		if ap <= 0.0:
			if hes:
				hes = false
				ap = randf_range(0.5, 1.2)
				wv = randf_range(-0.9, 0.9)
			elif randf() < 0.2 * k and d > 2.8:
				hes = true
				ap = randf_range(0.2, 0.5) * (0.5 + k)
			else:
				ap = randf_range(0.4, 1.0)
				wv = randf_range(-0.9, 0.9) * k
		if hes:
			m.look(h.tp - m.tp)
			return true
		var a := atan2(h.tp.y - m.tp.y, h.tp.x - m.tp.x) + (wv if d > 2.0 else 0.0)
		var to := m.tp + Vector2(cos(a), sin(a)) * minf(2.0, d)
		if not m.zone.is_solid(to) and m.zone.line_clear(m.tp, to):
			m.step_toward(to, dt, m.move_speed() * (1.0 + 0.25 * k))
			return true
	return false

## the standard melee rhythm with the imps' skittishness laid over it
func melee_k(m: Monster, h: Hero, dt: float, spd_k: float = 1.0) -> void:
	if skittish(m, h, dt):
		return
	var was := state
	melee_rhythm(m, h, dt, spd_k)
	if was == "strike" and state == "recover" and randf() < 0.45 * skit(m):
		back_t = randf_range(0.25, 0.45)
		bv = randf_range(-0.8, 0.8)

## a death close by scatters the skittish ones (called by AIWorld on Bus.monster_killed)
func scatter_from(m: Monster, dead_at: Vector2) -> void:
	var k := skit(m)
	if k <= 0.0 or state == "sleep" or m.tp.distance_to(dead_at) > 5.0 or reach >= 2.2:
		return
	if randf() < 0.3 * k:
		panic = randf_range(0.5, 1.0) * (0.6 + k)
		pv = randf_range(-0.9, 0.9)
		_release_token(m)

# ------------------------------------------------------------------ poses
## which anim a state shows; kinds extend it. "move" = walk when it moved this frame, else idle.
func pose_of(s: String) -> String:
	match s:
		"wind", "lwind", "cwind", "swind":
			return "wind"
		"strike", "lunge", "charge", "dash", "lash":
			return "atk"
		"sleep", "chase", "home", "gap", "flee":
			return "move"
	return "idle"

func pose(m: Monster, dt: float) -> void:
	moved = last_tp != Vector2.INF and m.tp.distance_to(last_tp) > 0.0005
	last_tp = m.tp
	var a := pose_of(state)
	if a == "move":
		a = "walk" if moved else "idle"
	if hurt_t > 0.0 and a in ["walk", "idle"] and m.spr.set.has("hit"):
		a = "hit"
	if not m.spr.set.has(a):
		a = {"wind": "atk", "hit": "idle", "parry": "wind"}.get(a, "idle")
		if not m.spr.set.has(a):
			a = "idle"
	var once := a in ["wind", "atk", "hit", "parry"]
	if m.spr.anim != a:
		m.spr.play(a, true, not once)
		m.spr.fps_override = 0.0
		if a == "wind":
			m.spr.fps_override = m.spr.frame_count() / maxf(0.15, wind)
	var k := 1.0
	if a == "walk":
		k = m.move_speed() / maxf(0.5, float(m.kd.get("speed_yd_s", 1.5)))
	m.spr.step(dt, k)

## kinds whose export has no body of their own (the fen's Mire Vein-Worm) borrow their family's, tinted
func fix_sprite(m: Monster) -> void:
	if m.spr and m.spr.set and not m.spr.set.has("walk"):
		var alt: String = str(m.kd.get("sprite", ""))
		if alt != "" and alt != m.kind and ResourceLoader.exists("res://art/sprites/%s.json" % alt):
			m.spr.set = Data.sprite_set(alt)
			m.spr.play("idle", true)
			var tint = m.kd.get("flags", {}).get("tint")
			if tint is String:
				m.spr.modulate = Color(tint).lerp(Color.WHITE, 0.55)

## the small grit tell under a great creature's melee wind-up (zz_zz_boss83); kinds give their own tells
func tell(m: Monster) -> Dictionary:
	if state == "wind" and (m.rank == "champion" or m.rank == "unique" or m.boss):
		var k := clampf(1.0 - st / maxf(0.2, wind), 0.0, 1.0)
		return {"disc": m.tp + dir_to(m, aim) * 0.8, "r": 0.8, "k": k}
	return {}
