extends "res://entities/ai/brain.gd"
## VEIN-WORMS (Mire and Elder too): severed arteries that swim in the soil. Awake, a worm dives (untargetable, takes
## nothing: m.buried) and runs at you under the ground, the soil rippling over it. Beneath you it waits 0.75 s and
## bursts up (x1.4 in 0.95 yd), lashes (0.35 s, reach 1.3) while you stay close, and dives again after 2.8 s. It cannot
## dig through stone: roads, flagstones, dungeon floors and pillars (tiles 1, 14, 6, 9; zc_combat22.js isStone) stop it, and
## on them it circles you at 3 yd.
## Tell: the soil ripples (no surfacing marker since v0.55). zc_combat22.js AI22.burrow.

var spot := Vector2.ZERO
var rip := 0.0
var up := 0.0
var oa := 0.0

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)
	m.buried = state in ["under", "rwind"] and not m.dead

static func stone(z: Zone, p: Vector2) -> bool:
	var ty := z.type_at(p)
	return ty == 1 or ty == 14 or ty == 6 or ty == 9

func _can(m: Monster, p: Vector2) -> bool:
	# (a worm stranded on stone, where it surfaced, may crawl off it)
	return not m.zone.is_solid(p) and (not stone(m.zone, p) or stone(m.zone, m.tp))

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if state in ["chase", "under"]:
		if h.dead or d > 26.0:
			state = "home"
			m.buried = false
			return
		state = "under"
		m.buried = true
		rip -= dt
		if rip <= 0.0 and world:
			rip = 0.18
			world.ripple(m.tp)
		var s := m.move_speed()
		if stone(m.zone, h.tp):
			# it smells you on the flagstones but cannot reach: it circles at the edge
			oa += dt * 0.9
			var g := h.tp + Vector2(cos(oa), sin(oa)) * 3.0
			var n := m.tp + (g - m.tp).clamp(Vector2(-1, -1), Vector2(1, 1)) * s * dt
			if _can(m, n):
				m.look(n - m.tp)
				m.tp = n
			return
		var n2 := m.tp + dir_to(m, h.tp) * minf(d, s * dt)
		if _can(m, n2):
			m.look(n2 - m.tp)
			m.tp = n2
		elif _can(m, Vector2(n2.x, m.tp.y)):
			m.tp.x = n2.x
		elif _can(m, Vector2(m.tp.x, n2.y)):
			m.tp.y = n2.y
		else:
			# a stone or a root in the way: it feels round it
			var v := dir_to(m, h.tp).rotated(1.1 * circle_dir()) * s * dt
			if _can(m, m.tp + v):
				m.tp += v
			else:
				odir = -circle_dir()
		if d < 0.5 and cd <= 0.0:
			set_state("rwind")
			spot = h.tp
		return
	match state:
		"rwind":
			if t > 0.75:
				_surface(m, h)
			return
		"lash":
			m.look(h.tp - m.tp)
			if t > 0.35:
				set_state("recover")
				strike_at(m, h, reach)
			return
		"recover", "surfaced":
			if state == "recover" and t > 0.5:
				state = "surfaced"
			up += dt
			if state == "surfaced" and d < 1.4 and cd <= 0.0 and not h.dead:
				set_state("lash")
				aim = h.tp
				cd = 0.9
				return
			if up > 2.8:
				up = 0.0
				set_state("under")
				cd = 1.2
				if world:
					world.grit_burst(m.tp, Color(0.35, 0.16, 0.13), 10, 0.8)
			return
		"home":
			m.buried = false
			melee_rhythm(m, h, dt)
			return
	state = "under"

func _surface(m: Monster, h: Hero) -> void:
	set_state("surfaced")
	up = 0.0
	m.buried = false
	m.tp = spot
	if m.zone.is_solid(m.tp):
		var c := m.zone._nearest_open(Vector2i(int(m.tp.x), int(m.tp.y)))
		m.tp = Vector2(c.x + 0.5, c.y + 0.5)
	if world:
		world.grit_burst(m.tp, Color(0.3, 0.2, 0.14), 16, 1.2)
		world.grit_burst(m.tp, Color(0.4, 0.08, 0.1), 10, 1.0)
	var dmg := m.roll_damage() * 1.4
	if hero_open(h) and h.tp.distance_to(m.tp) < 0.95:
		Combat.hit_hero(h, dmg, "phys", m.tp, {"src": Combat.who(m) + "|rising from below"})
	hit_allies(m.get_tree(), m.tp, 0.95, dmg, "phys", m.tp)
	m.spr.play("atk", true, false)

func pose_of(s: String) -> String:
	match s:
		"surfaced":
			return "atk" if t < 0.35 else "idle"
		"lash":
			return "wind" if t < 0.2 else "atk"
		"recover":
			return "idle"
	return super.pose_of(s)

func tell(m: Monster) -> Dictionary:
	return {}

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
