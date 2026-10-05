extends "res://entities/ai/brain.gd"
## THE HERALDS of the four gods (zd_world22 AI22.herald), woken at a god's altar (AIWorld): unique rank at the zone's
## highest level with 45% life, rising for 1.2 s. Below half life each is enraged (x1.3: faster, its trick sooner).
##  - The Marrow Pontiff (bone): every 7 s within 7 yd rings you with seven bone walls (5 s, they block your way);
##    at half life calls three Ossuary Wardens, once; the plain melee rhythm otherwise.
##  - The Wet Nurse (flesh): every 6 s births two Husks (never more than six of hers alive); at 2-6 yd spews a fan
##    of five bile orbs (5 yd/s, 45% damage, magic) every 3.5 s.
##  - The Long Exhale (breath): drifts like a Gasp and looses its orbs; every 5 s within 6 yd it breathes you away
##    (with a blow at 60%) or pulls you in, about 3.4 yd either way.
##  - A Silent One (hollow): no light near it (the lantern shrinks, AIWorld); every 4.5 s within 9 yd it steps out of
##    the dark 1.2 yd behind you, already mid-swing.

var god := ""
var rise := 0.0
var sk_t := 3.0
var spew_t := 2.0
var called := false
var kids: Array = []
var gb      # the Long Exhale drifts with a Gasp's mind

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	god = str(m.kd.get("flags", {}).get("god", ""))
	if god == "breath":
		gb = load("res://entities/ai/ai_ghost.gd").new()
		gb.init(m)
		gb.state = "chase"

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)
	if rise > 0.0:
		m.spr.position.y = 90.0 * rise / 1.2
		m.spr.self_modulate.a = 1.0 - rise / 1.2
	elif m.spr.position.y != 0.0:
		m.spr.position.y = 0.0
		m.spr.self_modulate.a = 1.0

func think(m: Monster, h: Hero, dt: float) -> void:
	if rise > 0.0:
		rise -= dt
		m.look(h.tp - m.tp)
		return
	var d := m.tp.distance_to(h.tp)
	var enr := 1.3 if m.hp < m.hp_max * 0.5 else 1.0
	sk_t -= dt
	match god:
		"bone":
			if sk_t <= 0.0 and d < 7.0 and not h.dead:
				sk_t = 7.0 / enr
				for i in 7:
					var a := i / 7.0 * TAU + randf() * 0.3
					if world:
						world.bone_wall(h.tp + Vector2(cos(a), sin(a)) * 2.6, 5.0)
				Bus.say.emit("Bone rises around you", 1.0)
			if not called and m.hp < m.hp_max * 0.5:
				called = true
				for i in 3:
					var s := Brain.spawn(m.zone, "knight", m.tp + Vector2(randf_range(-2, 2), randf_range(-2, 2)), m.level - 1, "normal", "herald_call")
					if s and world:
						world.grit_burst(s.tp, Color(0.8, 0.77, 0.7), 12, 1.0, 10.0)
			melee_rhythm(m, h, dt, enr)
		"flesh":
			if sk_t <= 0.0:
				sk_t = 6.0 / enr
				kids = kids.filter(func(k): return is_instance_valid(k) and not k.dead)
				if kids.size() < 6:
					for i in 2:
						var s := Brain.spawn(m.zone, "hollow", m.tp + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), maxi(1, m.level - 2), "normal", "nurse")
						if s:
							kids.append(s)
							if world:
								world.grit_burst(s.tp, Color(0.4, 0.08, 0.1), 16, 1.0, 10.0)
			if d > 2.0 and d < 6.0:
				spew_t -= dt
				if spew_t <= 0.0:
					spew_t = 3.5
					var a0 := atan2(h.tp.y - m.tp.y, h.tp.x - m.tp.x)
					for i in range(-2, 3):
						var a := a0 + i * 0.18
						var to := m.tp + Vector2(cos(a), sin(a)) * 6.0
						var mi := Missile.fire(m.zone, m.tp, to, 5.0, m.roll_damage() * 0.45, "magic", "monster", "orb")
						mi.col = Color(0.55, 0.5, 0.22)
						mi.life = 1.4
						mi.radius = 0.25
			melee_rhythm(m, h, dt, 1.0)
		"breath":
			if sk_t <= 0.0 and d < 6.0 and not h.dead:
				sk_t = 5.0 / enr
				var inhale := randf() < 0.5
				var k := -1.0 if inhale else 1.0
				var v := (h.tp - m.tp) / maxf(0.001, d)
				for i in 12:
					h.tp = m.zone.move(h.tp, v * 0.28 * k, h.radius)
				h.position = Iso.to_screen(h.tp)
				if not inhale and hero_open(h):
					Combat.hit_hero(h, m.roll_damage() * 0.6, "magic", m.tp)
				Bus.say.emit("It breathes in..." if inhale else "It breathes out", 0.9)
				if world:
					world.ring(m.tp, 4.0 if inhale else 0.4, 0.4 if inhale else 5.0, 0.5, Color(0.75, 0.85, 0.9))
			gb.world = world
			gb.t += dt
			gb.cd -= dt
			gb.ghost_step(m, h, dt)
			state = gb.state
			t = gb.t
		_:
			# a Silent One steps out of the dark behind you
			if sk_t <= 0.0 and d < 9.0 and not h.dead:
				sk_t = 4.5 / enr
				var b := h.tp - hero_front(h) * 1.2
				if not m.zone.is_solid(b):
					if world:
						world.grit_burst(m.tp, Color(0.1, 0.09, 0.14), 16, 1.0)
					m.tp = b
					m.look(h.tp - m.tp)
					take_token(m)
					state = "wind"
					st = maxf(0.05, wind - 0.1)
					aim = h.tp
					return
			melee_rhythm(m, h, dt, enr)

func on_death(m: Monster) -> void:
	super.on_death(m)
	m.spr.position.y = 0.0
	m.spr.self_modulate.a = 1.0
	if world:
		world.herald_unmade(m, god)
	Bus.herald_felled.emit(m, god)

func pose_of(s: String) -> String:
	if rise > 0.0:
		return "idle"
	if s == "shot":
		return "atk"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
