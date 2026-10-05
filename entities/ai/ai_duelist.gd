extends "res://entities/ai/brain.gd"
## MARROW DUELISTS: skeleton fencers. Three light blows within 1.2 s and it parries (0.7 s, the blade up): light blows
## then do nothing, and the first one within 1.8 yd is answered with a riposte of x1.5 that takes 60% of your poise.
## Heavy blows (over 14% of its life) break through. It does not parry while reeling, winding up or senseless.
## Otherwise the plain melee rhythm, a touch quick (x1.05). Tell: the blade tip rises. zc_combat22.js monDmg22.

var hit_log: Array = []
var riposted := false

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	if state == "parry":
		m.look(h.tp - m.tp)
		if t > 0.7:
			state = "chase"
			cd = 0.2
		return
	melee_k(m, h, dt, 1.05)

func damage_taken_mult(m: Monster, elem: String, from: Vector2, opts: Dictionary) -> float:
	if m.reeling > 0.0 or opts.get("dot", false):
		return 1.0
	var now := Time.get_ticks_msec() / 1000.0
	hit_log = hit_log.filter(func(x): return now - x < 1.2)
	hit_log.append(now)
	var raw: float = float(opts.get("raw", 0.0))
	var heavy: bool = raw > m.hp_max * 0.14 or (raw <= 0.0 and bool(opts.get("heavy", false)))
	if state == "parry" and not heavy:
		if world:
			world.grit_burst(m.tp, Color(0.9, 0.88, 0.82), 3, 0.5, 70.0)
		var h := m.hero()
		if not riposted and h and not h.dead and m.tp.distance_to(h.tp) < 1.8:
			riposted = true
			aim = h.tp
			m.look(h.tp - m.tp)
			m.spr.play("atk", true, false)
			Combat.hit_hero(h, m.roll_damage() * 1.5, "phys", m.tp, {"poise": h.st.poise_max() * 0.6})
		return 0.0
	if not heavy and hit_log.size() >= 3 and state != "wind" and m.stun <= 0.0 and state != "sleep":
		_release_token(m)
		set_state("parry")
		riposted = false
		hit_log.clear()
	return 1.0

func pose_of(s: String) -> String:
	if s == "parry":
		return "atk" if riposted and t < 0.3 else "parry"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	if state != "parry":
		hurt_t = 0.24
