extends "res://entities/ai/brain.gd"
## THE ACT I BOSSES (the Carrion Warden, the Ossuary Matron): the boss chassis of d_play.js updateBoss, with the rules
## of zz_zz_perf74 (never sealed in) and zz_zz_boss83 (telegraphs, the slam's broken ground, no healing when left).
## The fight begins when you step inside its room (or come within 8.5 yd of its spot). It chases; under 2.5 yd it
## slams (0.9 s wind, x1.3 magic in 2.1 yd, 1.2 yd ahead), at 2.5-8 yd it charges (0.7 s wind, 10 yd/s for 0.6 s);
## it recovers 0.9 s. At half life it calls four of its dead (the Warden: Ossuary Wardens and Husks; the Matron: Marrow
## Duelists and Ossuary Weepers) and moves x1.25 faster. You can run as far as you like: left 34 yd behind, it walks
## home and waits there, unhealed. Telegraphs are dust and grit on the ground, bone-grey, never red, never a glow.

var phase := 1
var target_p := Vector2.ZERO
var hit_once := false
var room := Rect2()

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	reach = 2.5
	# a boss row has no poiseK (null): monster.gd's float(null) stops _numbers early and leaves poise at 10, so the
	# boss would reel at every blow. The web uses 0.6 (monPoiseMax); x1.6 boss, x3 (zz_tune_batch_d).
	if not (m.kd.get("poiseK") is float or m.kd.get("poiseK") is int):
		m.poise_max = m.hp_max * 0.6 * 1.6 * 3.0
		m.poise = m.poise_max
	var r = m.zone.markers.get("bossRoom")
	if r is Dictionary and m.tp.distance_to(Vector2(r.get("cx", 0), r.get("cy", 0))) < 12.0:
		room = Rect2(r["x"], r["y"], r["w"], r["h"])
	var sp = m.zone.markers.get("bossSpot")
	if sp is Dictionary:
		m.home = Vector2(sp["x"], sp["y"])

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func fast() -> float:
	return 1.25 if phase == 2 else 1.0

## the fight simply begins when you come in; nothing seals behind you
func _sleep(m: Monster, h: Hero, dt: float) -> void:
	if h.dead:
		return
	var inside := false
	if room.size.x > 0.0:
		inside = h.tp.x > room.position.x + 0.8 and h.tp.y > room.position.y + 0.8 and h.tp.x < room.end.x - 0.8 and h.tp.y < room.end.y - 0.8
	else:
		inside = h.tp.distance_to(m.home) < 8.5
	if inside:
		wake(m)
	elif m.tp.distance_to(m.home) > 0.3:
		m.step_toward(m.home, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if state == "home" or h.dead or d > 34.0:
		# left behind: it goes home and waits, and it does not heal
		if state != "home":
			set_state("home")
		_approach(m, m.home, dt)
		if m.tp.distance_to(m.home) < 0.6:
			state = "sleep"
		return
	if phase == 1 and m.hp < m.hp_max * 0.5:
		phase = 2
		_call_the_dead(m)
	var k := fast()
	match state:
		"chase":
			if d > 1.7:
				_approach(m, h.tp, dt, k)
			else:
				m.look(h.tp - m.tp)
			if cd <= 0.0:
				if d < 2.5:
					set_state("swind")
					wind = 0.9 / k
					target_p = m.tp + dir_to(m, h.tp) * 1.2
					m.look(h.tp - m.tp)
				elif d < 8.0 and m.zone.line_clear(m.tp, h.tp):
					set_state("cwind")
					wind = 0.7 / k
					aim_dir = dir_to(m, h.tp)
					m.look(aim_dir)
		"swind":
			if t > 0.9 / k:
				set_state("recover")
				var dmg := m.roll_damage() * 1.3
				if hero_open(h) and h.tp.distance_to(target_p) < 2.1:
					Combat.hit_hero(h, dmg, "magic", target_p, {"heavy": true, "src": Combat.who(m) + "|its slam"})
				hit_allies(m.get_tree(), target_p, 2.1, dmg, "magic", target_p)
				if world:
					world.grit_burst(target_p, Color(0.62, 0.6, 0.55), 26, 1.6, 10.0)
					world.slam_scar(target_p, 2.1)
					Game.shake(9.0)
					Game.hitstop(0.08)
		"cwind":
			if t > 0.7 / k:
				set_state("charge")
				hit_once = false
		"charge":
			var from := m.tp
			var went := shove(m, aim_dir * 10.0 * dt)
			m.look(aim_dir)
			if not hit_once and h.tp.distance_to(m.tp) < m.radius + h.radius + 0.1:
				hit_once = true
				if hero_open(h):
					Combat.hit_hero(h, m.roll_damage(), "phys", from)
			for a in m.get_tree().get_nodes_in_group("allies"):
				if a.get("tp") != null and a.tp.distance_to(m.tp) < m.radius + 0.4 and a.has_method("take_hit"):
					a.take_hit(m.roll_damage(), "phys", from)
					set_state("recover")
					return
			if t > 0.6 or went < 0.0001:
				set_state("recover")
		"recover":
			if t > 0.9 / k:
				state = "chase"
				cd = 0.5 + randf() * 0.8
		_:
			state = "chase"

func _call_the_dead(m: Monster) -> void:
	Bus.say.emit("%s calls the dead" % m.name_shown, 2.0)
	var sum: Array = m.kd.get("flags", {}).get("summon", ["knight", "hollow"])
	for i in 4:
		var p: Vector2
		if room.size.x > 3.0:
			p = Vector2(room.position.x + 1.5 + randf() * (room.size.x - 3.0), room.position.y + 1.5 + randf() * (room.size.y - 3.0))
		else:
			var a := randf() * TAU
			p = m.tp + Vector2(cos(a), sin(a)) * randf_range(2.0, 4.0)
		var s := Brain.spawn(m.zone, str(sum[i % sum.size()]), p, m.level - 1, "normal", "boss_call")
		if s and world:
			world.grit_burst(s.tp, Color(0.5, 0.47, 0.42), 14, 1.0, 10.0)

func interrupted(m: Monster) -> void:
	set_state("recover")

func on_reel(m: Monster) -> void:
	if state in ["swind", "cwind", "charge"]:
		set_state("recover")

func on_death(m: Monster) -> void:
	super.on_death(m)
	Bus.boss_felled.emit(m)

func tell(m: Monster) -> Dictionary:
	var k := fast()
	if state == "swind":
		return {"disc": target_p, "r": 2.1, "k": clampf(t / (0.9 / k), 0.0, 1.0)}
	if state == "cwind":
		return {"lane": m.tp, "dir": aim_dir, "len": 6.0, "half": m.radius + 0.35, "k": clampf(t / (0.7 / k), 0.0, 1.0)}
	return {}

func pose_of(s: String) -> String:
	match s:
		"swind", "cwind":
			return "wind"
		"charge":
			return "walk"
		"recover":
			return "atk" if t < 0.4 else "idle"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)
	if state == "charge":
		m.spr.step(dt, 2.0)
