extends "res://entities/ai/brain.gd"
## MOTH-SAINTS (and the Canopy's): porcelain faces on moths' bodies. They hover out of reach (14 px up; blows land
## only 35% high up) in a slow 4.2 yd circle round you, drawn toward any light; then fold their wings (0.45 s, sinking)
## and swoop through you in a 0.75 s arc that ends 2.2 yd past you (one blow), low enough to take 130%. They walk only
## in their hours (dusk and night), lying hidden otherwise. Tell: the wings fold back. zc_combat22.js AI22.flyer.

const WPX := 4.0   # the web's heights are world px; ours are screen px
var z := 6.0
var oa := INF
var from_p := Vector2.ZERO
var to_p := Vector2.ZERO
var hit_once := false

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	m.flying = true
	reach = 7.0
	z = randf_range(3.0, 7.0)
	m.z_lift = z * WPX

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)
	if state == "sleep":
		z = 5.0 + sin(Time.get_ticks_msec() / 700.0 + m.home.x) * 1.5
	m.z_lift = z * WPX

func damage_taken_mult(m: Monster, elem: String, from: Vector2, opts: Dictionary) -> float:
	return 0.35 if z > 8.0 else 1.3

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	match state:
		"cwind":
			z = maxf(9.0, z - dt * 8.0)
			m.look(h.tp - m.tp)
			if t > wind:
				set_state("swoop")
				from_p = m.tp
				to_p = h.tp + dir_to(m, h.tp) * 2.2
				hit_once = false
			return
		"swoop":
			var k := minf(1.0, t / 0.75)
			# a sideways bow that crosses you at the pass (the web's plain bow could sail wide of you)
			var kp := clampf((to_p - from_p).length() - 2.2, 0.3, 20.0) / maxf(0.5, (to_p - from_p).length())
			var side := (sin(PI * k / kp) * 1.2 if k < kp else -sin(PI * (k - kp) / maxf(0.05, 1.0 - kp)) * 0.5) * circle_dir()
			var b := from_p.lerp(to_p, k)
			var n := Vector2(-(to_p.y - from_p.y), to_p.x - from_p.x).normalized()
			var was := m.tp
			m.tp = b + n * side
			m.look(m.tp - was)
			z = 3.0 + 11.0 * absf(k - 0.5) * 2.0 * 0.6
			if not hit_once and m.tp.distance_to(h.tp) < 0.75:
				hit_once = true
				if hero_open(h):
					Combat.hit_hero(h, m.roll_damage(), "phys", m.tp)
			if not hit_once:
				for a in m.get_tree().get_nodes_in_group("allies"):
					if a.get("tp") != null and a.tp.distance_to(m.tp) < 0.75 and a.has_method("take_hit"):
						hit_once = true
						a.take_hit(m.roll_damage(), "phys", m.tp)
						break
			if k >= 1.0:
				set_state("chase")
				cd = 2.4 + randf()
			return
	if h.dead or d > 26.0:
		state = "home"
		var l := m.tp.distance_to(m.home)
		if l > 0.3:
			m.step_toward(m.home, dt)
		else:
			state = "sleep"
		return
	z = minf(14.0, z + dt * 10.0)
	state = "chase"
	# hover in a slow circle, drawn toward light when there is any
	var L: Vector2 = world.light_near(m.tp) if world else Vector2.INF
	var c := h.tp if L == Vector2.INF else h.tp.lerp(L, 0.5)
	if oa == INF:
		oa = randf() * TAU
	oa += dt * 0.8 * circle_dir()
	var g := c + Vector2(cos(oa), sin(oa)) * 4.2
	var l2 := m.tp.distance_to(g)
	if l2 > 0.1:
		var v := (g - m.tp) / l2 * minf(l2, m.move_speed() * dt)
		m.tp += v
		m.look(v)
	m.tp.x = clampf(m.tp.x, 2.0, m.zone.w - 3.0)
	m.tp.y = clampf(m.tp.y, 2.0, m.zone.h - 3.0)
	if cd <= 0.0 and d < 7.0 and not h.dead:
		set_state("cwind")

func interrupted(m: Monster) -> void:
	super.interrupted(m)
	cd = 1.0

func pose_of(s: String) -> String:
	match s:
		"swoop":
			return "atk"
		"chase", "home":
			return "walk"
		"sleep":
			return "idle"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
