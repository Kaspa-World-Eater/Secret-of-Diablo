extends "res://entities/ai/brain.gd"
## GRAVEBLOATS and BLOATLINGS: walking stomachs. They shuffle close (1.2 yd), swell (the kind's fuse: 0.8 s, a
## Bloatling 0.55 s) and burst for their damage as magic in 1.9 yd, dying. The burst hurts the hero and his allies
## alike. Tell: it swells and gurgles (the wind pose, the body filling out). d_play.js updateMon (bomber).

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	reach = 1.2

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if state == "wind":
		var k := clampf(t / wind, 0.0, 1.0)
		m.spr.scale = Vector2(1.0 + 0.12 * k, 1.0 + 0.08 * k)
		if t > wind:
			burst(m, h)
		return
	if h.dead or d > 26.0 or state == "home":
		melee_rhythm(m, h, dt)
		return
	state = "chase"
	if d > 1.2:
		_approach(m, h.tp, dt)
	else:
		set_state("wind")
		m.look(h.tp - m.tp)

func burst(m: Monster, h: Hero) -> void:
	var dmg := m.roll_damage()
	if world:
		world.grit_burst(m.tp, Color(0.36, 0.4, 0.2), 26, 1.4, 40.0)
		world.grit_burst(m.tp, Color(0.22, 0.05, 0.04), 12, 1.0, 30.0)
	if hero_open(h) and m.tp.distance_to(h.tp) < 1.9:
		Combat.hit_hero(h, dmg, "magic", m.tp, {"src": Combat.who(m) + "|its burst"})
	hit_allies(m.get_tree(), m.tp, 1.9, dmg, "magic", m.tp)
	m.spr.scale = Vector2.ONE
	m.die(m.tp)

func interrupted(m: Monster) -> void:
	m.spr.scale = Vector2.ONE
	super.interrupted(m)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
