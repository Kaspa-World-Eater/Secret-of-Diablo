extends "res://entities/ai/brain.gd"
## WEEPERS: faceless mourners who keep their distance. Back off inside 4.2 yd (sliding sideways when something is
## behind), close in past 6.5 yd or without a line, and loose a bone needle (8.5 yd/s, physical) from under 8 yd with
## a clear line; half the time they duck back after a shot. Tell: the head tilts back. zc_combat22.js AI22.kiter.

var duck := 0.0

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	reach = 8.0

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if h.dead or d > 26.0 or state == "home":
		melee_rhythm(m, h, dt)
		return
	var see := m.zone.sight_clear(m.tp, h.tp) and in_sight_of(m, h)   # out in the dark it closes in, never shoots
	if state == "wind":
		aim = h.tp
		m.look(h.tp - m.tp)
		if t > wind:
			var dir := dir_to(m, h.tp)
			var mi := Missile.fire(m.zone, m.tp + dir * 0.4, h.tp, 8.5, m.roll_damage(), "phys", "monster", "needle")
			mi.col = Color(0.86, 0.83, 0.74)
			mi.radius = 0.2
			set_state("shot")
			cd = 1.8 + randf() * 0.8
			if randf() < 0.5:
				duck = 1.2
		return
	if state == "shot" and t > 0.3:
		state = "chase"
	elif state != "shot":
		state = "chase"
	if d < 4.2 or duck > 0.0:
		if duck > 0.0:
			duck -= dt
		# back off; if something is behind, slide sideways
		var a := -dir_to(m, h.tp)
		if m.zone.is_solid(m.tp + a * 0.8):
			var s := circle_dir()
			a = Vector2(-a.y, a.x) * -s
			if m.zone.is_solid(m.tp + a * 0.8):
				odir = -s
		m.step_toward(m.tp + a, dt, m.move_speed() * 1.1)
	elif d > 6.5 or not see:
		_approach(m, h.tp, dt)
	if see and d < 8.0 and cd <= 0.0 and duck <= 0.0 and state == "chase":
		set_state("wind")
		aim = h.tp

func pose_of(s: String) -> String:
	if s == "shot":
		return "atk"
	return super.pose_of(s)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
