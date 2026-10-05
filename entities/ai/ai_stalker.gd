extends "res://entities/ai/brain.gd"
## STALKER CRONES: they skulk in your rear arc (2.6 yd behind a hip, 3.2 when far) and, when your front turns away
## (her place relative to you against your facing < -0.15) within 4 yd and a clear line, crouch (the kind's wind) and
## spring in a straight dash at 7 yd/s for 0.35 s: one heavy blow (x1.4). A wall ends the dash. Seen, she circles
## wide and waits. Tell: the crouch. zz_monsters_new.js AI22.stalker. The hero's facing is his view and mirror.

var hit_once := false

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	match state:
		"dash":
			var from := m.tp
			var went := shove(m, aim_dir * 7.0 * dt)
			m.look(aim_dir)
			if not hit_once and m.tp.distance_to(h.tp) < m.radius + h.radius + 0.25:
				hit_once = true
				if hero_open(h):
					Combat.hit_hero(h, m.roll_damage() * 1.4, "phys", from)
			if went < 7.0 * dt * 0.4 or t > 0.35:
				set_state("srec")
				cd = 2.4
			return
		"swait":
			m.look(aim_dir)
			if t > wind:
				set_state("dash")
				hit_once = false
			return
		"srec":
			if t > rec:
				state = "chase"
			return
	if h.dead or d > 26.0 or state == "home":
		melee_rhythm(m, h, dt)
		return
	state = "chase"
	var f := hero_front(h)
	if d < 4.0 and cd <= 0.0 and m.zone.line_clear(m.tp, h.tp):
		var rel := (m.tp - h.tp).dot(f) / maxf(0.001, d)
		if rel < -0.15:
			set_state("swait")
			aim_dir = dir_to(m, h.tp)
			return
	# skulk: a slow rear-arc orbit at a shy radius, creeping in from a hip; approach when far
	var side := Vector2(-f.y, f.x)
	var rad := 3.2 if d > 6.0 else 2.6
	var g := h.tp - f * rad + side * circle_dir() * 0.9
	if m.zone.is_solid(g):
		odir = -circle_dir()
	_approach(m, g, dt, 0.85 if d > 6.0 else 0.55)
	if d < 6.0:
		m.look(h.tp - m.tp)

func pose_of(s: String) -> String:
	match s:
		"swait":
			return "wind"
		"srec":
			return "idle"
	return super.pose_of(s)

func interrupted(m: Monster) -> void:
	super.interrupted(m)
	cd = 1.0

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
