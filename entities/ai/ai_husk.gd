extends "res://entities/ai/brain.gd"
## HUSKS (and Drowned Husks, Kneelers): they wait for company, then surge. With two or more awake kin within 4.5 yd a
## husk surges (x1.35 speed) and charge-lunges from 1.3-2.6 yd (0.38 s wind, 6.5 yd/s for 0.3 s, x1.2 blow); alone it
## shambles (x0.78) but still lunges when you turn your back. Tell: head snaps up, arms spread (the wind pose).
## zc_combat22.js AI22.husk, with the imps' skittishness (zz_zz_imps67) over the plain rhythm.

var hit_once := false

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	match state:
		"lwind":
			m.look(aim_dir)
			if t > 0.38:
				set_state("lunge")
				hit_once = false
			return
		"lunge":
			shove(m, aim_dir * 6.5 * dt)
			m.look(aim_dir)
			if not hit_once and m.tp.distance_to(h.tp) < m.radius + h.radius + 0.25:
				hit_once = true
				if hero_open(h):
					Combat.hit_hero(h, m.roll_damage() * 1.2, "phys", m.tp)
			if t > 0.3:
				state = "recover"
				st = rec
			return
	var surge := awake_packmates(m, 4.5) >= 2
	if state == "chase" and cd <= 0.0 and d > 1.3 and d < 2.6 and not h.dead and m.zone.line_clear(m.tp, h.tp):
		if surge or behind_hero(m, h):
			set_state("lwind")
			aim_dir = dir_to(m, h.tp)
			cd = 2.5
			return
	melee_k(m, h, dt, 1.35 if surge else 0.78)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
