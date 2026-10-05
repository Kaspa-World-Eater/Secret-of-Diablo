extends "res://entities/ai/brain.gd"
## BELLWETHERS: hulks with their heads sealed in bells. At 2.8-9 yd with a clear line one tolls twice (at 0.2 and
## 0.55 s; it tracks you until 0.65 s) and at 0.9 s charges at 8.5 yd/s for up to 1.3 s: x1.6 damage, your poise
## emptied, and you are thrown about a yard (allies are knocked senseless 0.6 s). A wall stops it dead: it reels,
## dazed, 2.2 s. Otherwise the plain melee rhythm. Tell: the two tolls (a ring of kicked-up grit, the head drawn back).
## zc_combat22.js AI22.charger, bellToll.

var toll1 := false
var toll2 := false
var hit_set: Array = []

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	match state:
		"dazed":
			if t > 2.2:
				state = "chase"
				cd = 1.5
			return
		"cwind":
			if t < 0.65:
				aim_dir = dir_to(m, h.tp)
			m.look(aim_dir)
			if t > 0.2 and not toll1:
				toll1 = true
				if world:
					world.toll(m.tp)
			if t > 0.55 and not toll2:
				toll2 = true
				if world:
					world.toll(m.tp)
			if t > 0.9:
				set_state("charge")
				hit_set.clear()
			return
		"charge":
			var from := m.tp
			var went := shove(m, aim_dir * 8.5 * dt)
			m.look(aim_dir)
			if hero_open(h) and not (h in hit_set) and h.tp.distance_to(m.tp) < m.radius + h.radius + 0.15:
				hit_set.append(h)
				Combat.hit_hero(h, m.roll_damage() * 1.6, "phys", from, {"poise": h.st.poise_max() + 1.0, "heavy": true})
				for i in 4:
					h.tp = m.zone.move(h.tp, aim_dir * 0.25, h.radius)
				h.position = Iso.to_screen(h.tp)
			for a in m.get_tree().get_nodes_in_group("allies"):
				if not (a in hit_set) and a.get("tp") != null and a.tp.distance_to(m.tp) < m.radius + 0.45 and a.has_method("take_hit"):
					hit_set.append(a)
					a.take_hit(m.roll_damage() * 1.6, "phys", from)
					if a.get("stun") != null:
						a.stun = maxf(a.stun, 0.6)
			if went < 8.5 * dt * 0.3:
				# a wall stops it dead
				set_state("dazed")
				m.reeling = 2.2
				if world:
					world.toll(m.tp, true)
					world.grit_burst(m.tp + aim_dir * 0.6, Color(0.72, 0.63, 0.44), 20, 1.3)
				return
			if t > 1.3:
				state = "recover"
				st = rec
			return
	if state == "chase" and cd <= 0.0 and d > 2.8 and d < 9.0 and not h.dead and m.zone.line_clear(m.tp, h.tp):
		set_state("cwind")
		toll1 = false
		toll2 = false
		aim_dir = dir_to(m, h.tp)
		cd = 5.0
		_release_token(m)
		return
	melee_k(m, h, dt, 1.0)

func pose_of(s: String) -> String:
	if s == "dazed":
		return "idle"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
