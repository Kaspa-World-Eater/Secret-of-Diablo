extends "res://entities/ai/brain.gd"
## GASPS (Mire Gasps, Choristers): stray breath. They drift straight through walls to a spot 4.5-5 yd off you, bobbing,
## and loose a slow orb (4.6 yd/s, magic) from under 7.5 yd when they float over open ground with a clear line.
## Any light within reach (a lantern or altar 5 yd, a brazier or candles 3.2, a fire 2.2) drives them off, and while
## lit they take x1.5; the core of your own lantern (half its radius) lights them too, so close in to punish them.
## They walk only at dusk, night and dawn (zv_time24: hidden where they stood by day, never before your eyes).
## A Chorister's dirge slows your walk within 5.5 yd (AIWorld). Tell: it inhales, the veil billows.
## zc_combat22.js AI22.ghost, zv_time24.js, zz_monsters_new.js.

var lit := 0.0
var hx := 0.0
var hy := 0.0

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	reach = 7.5
	hx = randf() * TAU
	hy = randf() * TAU

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func damage_taken_mult(m: Monster, elem: String, from: Vector2, opts: Dictionary) -> float:
	return 1.5 if lit > 0.0 else 1.0

func think(m: Monster, h: Hero, dt: float) -> void:
	ghost_step(m, h, dt)

## shared with the Long Exhale (ai_herald)
func ghost_step(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if h.dead or d > 26.0:
		_drift(m, m.home, dt, 1.0)
		if m.tp.distance_to(m.home) < 0.5:
			state = "sleep"
		else:
			state = "home"
		return
	var L: Vector2 = world.light_near(m.tp) if world else Vector2.INF
	var in_lamp := d < h.light_radius() * 0.5
	lit = 0.4 if (L != Vector2.INF or in_lamp) else maxf(0.0, lit - dt)
	if L != Vector2.INF:
		# it recoils from the light
		var away := dir_to(m, L) * -1.0
		m.tp += away * m.move_speed() * 1.3 * dt
		m.look(away)
		_clamp(m)
		if state != "chase":
			set_state("chase")
		return
	if state == "wind":
		aim = h.tp
		m.look(h.tp - m.tp)
		if t > wind:
			var dir := dir_to(m, h.tp)
			var mi := Missile.fire(m.zone, m.tp + dir * 0.4, h.tp, 4.6, m.roll_damage(), "magic", "monster", "orb")
			mi.col = Color(0.66, 0.72, 0.8)
			mi.radius = 0.3
			set_state("shot")
			cd = 2.0 + randf()
		return
	if state == "shot" and t > 0.3:
		state = "chase"
	elif state != "shot":
		state = "chase"
	# drift: straight through walls toward a spot a few yards off the hero, bobbing
	var want := 4.5 if d > 6.0 else (5.0 if d < 3.5 else d)
	var g := h.tp - dir_to(m, h.tp) * want
	_drift(m, g, dt, 1.0)
	m.tp += Vector2(cos(Time.get_ticks_msec() / 1000.0 * 1.3 + hx), sin(Time.get_ticks_msec() / 1000.0 * 1.1 + hy)) * 0.3 * dt
	_clamp(m)
	m.look(h.tp - m.tp)
	if d < 7.5 and cd <= 0.0 and state == "chase" and not m.zone.is_solid(m.tp) and m.zone.line_clear(m.tp, h.tp) and in_sight_of(m, h):
		set_state("wind")
		aim = h.tp

func _drift(m: Monster, g: Vector2, dt: float, k: float) -> void:
	var l := m.tp.distance_to(g)
	if l > 0.2:
		m.tp += (g - m.tp) / l * minf(l, m.move_speed() * k * dt)

func _clamp(m: Monster) -> void:
	m.tp.x = clampf(m.tp.x, 2.0, m.zone.w - 3.0)
	m.tp.y = clampf(m.tp.y, 2.0, m.zone.h - 3.0)

func pose_of(s: String) -> String:
	if s == "shot":
		return "atk"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
