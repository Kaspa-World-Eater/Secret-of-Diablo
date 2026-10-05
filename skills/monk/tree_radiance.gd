extends "res://skills/monk/base.gd"
## The Empty Hand, part 2 of 5: the sky (Halo-That-Turns, Gate-Without-A-Gate) and the Radiance tree.
## Chain: base -> tree_radiance -> tree_absence -> tree_destroyer -> skills/monk.gd.

# ------------------------------------------------------------------ the sky
func _turn_sky(kind: String) -> bool:
	var id := "kdawn" if kind == "noon" else "keclipse"
	var t := sky_len(id)
	Game.sky_force = kind
	Game.sky_t = t
	sky_bonus = 0.0
	sky_flash = {"kind": kind, "t": 0.9}
	if kind == "noon":
		banner(data[id]["name"].to_upper(), Color8(255, 240, 176))
		say("A blinding noon. Radiance peaks.", 2.0)
		Sfx.play("bell_far", 0.8, 1.6)
		for m in mons():
			if m.tp.distance_to(hero.tp) > 13.0:
				continue
			if m.ai in ["ghost", "flyer"] or m.kind in ["moth", "chalk_wraith", "a5_wraith"]:
				stun(m, 1.6)
				m.slow = maxf(m.slow, 0.5)
				say_at(m.tp, "dazzled", Color8(255, 240, 176))
				if K("kdawn3") > 0:
					burn(m, D("kdawn", 6, 2.5), 4.0)
	else:
		banner(data[id]["name"].to_upper(), Color8(138, 122, 168))
		say("The sun goes out. Every light but yours gutters.", 2.0)
		Sfx.play("bell_far", 0.8, 0.6)
	ring(hero.tp, 4.0, 0.7, Color8(255, 244, 176) if kind == "noon" else Color8(184, 160, 240))
	return true

func _end_sky() -> void:
	var was := Game.sky_force
	Game.sky_force = ""
	Sfx.play("bell_far", 0.7, 1.2)
	say("The false noon cracks and falls away." if was == "noon" else "The sun comes back through the crack.", 2.0)

# ------------------------------------------------------------------ Radiance
func _toggle_amber() -> bool:
	if amber:
		amber = false
		dust(hero.tp, Color(1.0, 0.85, 0.56), 8)
		return false
	pay("kamber")
	amber = true
	amber_t = 0.0
	ring(hero.tp, amber_r(), 0.5, Color8(255, 208, 64))
	dust(hero.tp, Color(1.0, 0.91, 0.63), 18, 2.4)
	_after("kamber", aim_point())
	return false

func _cast_hundred(m) -> bool:
	if m == null:
		return false
	flurry = {"m": m, "t": 0.0, "n": 0, "tick": 0.0, "dmg": fist() * (0.07 + 0.008 * L1("khands")) * sky(0) * sand(0) * syn("khands")}
	cast_len = 1.5
	return true

func _update_flurry(dt: float) -> void:
	if flurry.is_empty():
		return
	var F := flurry
	F["t"] += dt
	F["tick"] -= dt
	var m = F["m"]
	if m == null or not is_instance_valid(m) or m.dead or m.tp.distance_to(hero.tp) > 2.6 + m.radius:
		flurry = {}
		return
	hero._face(m.tp - hero.tp)
	stun(m, 0.15)
	while F["tick"] <= 0.0 and F["n"] < 100:
		F["tick"] += 1.5 / 100.0
		F["n"] += 1
		hurt(m, F["dmg"], "khands", {"melee": true, "poise": F["dmg"] * 0.5})
		if F["n"] % 3 == 0 and not m.dead:
			burn(m, F["dmg"] * 2.0, 2.0)
			slams.append({"tp": m.tp + Vector2(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5)), "z": randf_range(2, 34), "t": 0.24, "max": 0.24, "kind": "palm", "s": 1.5 if randf() < 0.2 else 1.0})
		if F["n"] % 20 == 0:
			fault(m)
		if F["n"] % 6 == 0:
			Sfx.play("hit", 0.3, randf_range(1.2, 1.6))
		if m.dead:
			break
	if F["n"] >= 100 or m.dead:
		if not m.dead:
			var big := K("khshove") > 0
			shove(m, hero.tp, 3.0 if big else 1.5)
			stun(m, 1.5 if big else 0.5)
			hurt(m, F["dmg"] * 8.0, "khands", {"melee": true, "heavy": true})
			slams.append({"tp": m.tp, "z": 4, "t": 0.5, "max": 0.5, "kind": "palm", "s": 3.0})
		if aM("kr_ash"):
			seals.append({"tp": m.tp, "t": 4.0, "max": 4.0, "R": 1.3, "dps": F["dmg"] * 6.0, "tick": 0.0})
			ring(m.tp, 2.0, 0.45, Color8(255, 244, 176))
			Sfx.play("heavy", 1.0, 0.8)
			Game.shake(4.0)
		flurry = {}

func _cast_star(a: Vector2) -> bool:
	var ang := (a - hero.tp).angle()
	var sdmg := D("kstar", 12, 5.5) * (0.7 if aR("kr_star") else 1.0)
	cones.append({"tp": hero.tp, "a0": ang - 0.7, "a1": ang + 0.7, "t": 0.0, "dur": 0.6, "R": 4.6 * area(), "hit": {}, "dmg": sdmg})
	if aU("kr_star"):
		# the breath sweeps back the way it came
		cones.append({"tp": hero.tp, "a0": ang + 0.7, "a1": ang - 0.7, "t": -0.6, "dur": 0.6, "R": 4.6 * area(), "hit": {}, "dmg": sdmg * 0.6})
	say_at(hero.tp + Vector2(0, -0.2), "ha")
	return true

func _update_cones(dt: float) -> void:
	for c in cones:
		c["t"] += dt
		if c["t"] < 0.0:
			continue
		var k: float = minf(1.0, c["t"] / c["dur"])
		var sweep: float = lerpf(c["a0"], c["a1"], k)
		c["sweep"] = sweep
		for m in mons():
			if c["hit"].has(m.get_instance_id()):
				continue
			var dv: Vector2 = m.tp - c["tp"]
			var d := dv.length()
			if d > c["R"] + m.radius or d < 0.1:
				continue
			var da := wrapf(dv.angle() - c["a0"], -PI, PI)
			var span: float = c["a1"] - c["a0"]
			if span >= 0.0:
				if da < -0.15 or da > span + 0.15 or c["a0"] + da > sweep + 0.1:
					continue
			else:
				if da > 0.15 or da < span - 0.15 or c["a0"] + da < sweep - 0.1:
					continue
			c["hit"][m.get_instance_id()] = true
			var und := raised(m)
			hurt(m, c["dmg"] * (1.5 if und else 1.0), "kstar")
			burn(m, c["dmg"] * 0.25, 3.0)
			if und and K("kstarun") > 0:
				burn(m, c["dmg"] * 0.4, 5.0)
			if aR("kr_star") and not m.dead:
				# drawn in, not out: dragged 2 yd toward you and blinded a moment
				if not m.boss:
					var tv: Vector2 = hero.tp - m.tp
					m.tp = zone.move(m.tp, tv.normalized() * minf(2.0, maxf(0.0, tv.length() - 0.9)), m.radius * 0.6)
				stun(m, 0.5)
	cones = cones.filter(func(c): return c["t"] < c["dur"] + 0.35)

func _cast_fist(a: Vector2) -> bool:
	if aR("kr_noon"):
		# reversed: the fist is your own, on the enemy in reach, at once and 60% harder
		var mm := near(hero.tp, 2.2)
		if mm == null:
			say("No enemy in reach.", 0.8)
			return false
		fists.append({"tp": mm.tp, "m": mm, "t": 0.6, "dur": 0.6, "dmg": D("kfist", 42, 18) * 1.6, "done": false, "own": true})
		return true
	var p := clamp_cast(a, 9.0)
	var m := near(p, 1.6)
	fists.append({"tp": m.tp if m else p, "m": m, "t": 0.0, "dur": 0.6, "dmg": D("kfist", 42, 18), "done": false})
	return true

func _update_fists(dt: float) -> void:
	var new_fists: Array = []
	for f in fists:
		f["t"] += dt
		var m = f["m"]
		if m != null and is_instance_valid(m) and not m.dead and f["t"] < f["dur"]:
			f["tp"] = m.tp
		if f["t"] >= f["dur"] and not f["done"]:
			f["done"] = true
			Game.shake(7.0)
			Sfx.play("heavy", 1.0, 0.6)
			var main = m if m != null and is_instance_valid(m) and not m.dead and m.tp.distance_to(f["tp"]) < 1.2 else near(f["tp"], 1.2)
			if main:
				hurt(main, f["dmg"], "kfist", {"heavy": true})
				stun(main, 0.6)
			var RR := 2.5 + (1.0 if K("kfring") > 0 else 0.0)
			for o in foes(f["tp"], RR):
				if o == main:
					continue
				hurt(o, f["dmg"] * 0.35, "kfist")
				if K("kfring") > 0:
					burn(o, f["dmg"] * 0.15, 4.0)
			if aU("kr_noon") and not f.get("lesser", false):
				# two lesser fists follow on the nearest enemies round the first
				var others := foes(f["tp"], 4.0).filter(func(q): return q != main)
				others.sort_custom(func(p1, p2): return p1.tp.distance_to(f["tp"]) < p2.tp.distance_to(f["tp"]))
				for q in others.slice(0, 2):
					new_fists.append({"tp": q.tp, "m": q, "t": 0.15, "dur": 0.6, "dmg": f["dmg"] * 0.5, "done": false, "lesser": true})
			ring(f["tp"], RR, 0.5, Color8(255, 216, 112))
			ring(f["tp"], RR * 0.6, 0.4, Color8(255, 240, 176))
			dust(f["tp"], Color(1.0, 0.91, 0.63), 24, 4.0)
	fists = fists.filter(func(f): return f["t"] < f["dur"] + 0.5)
	fists.append_array(new_fists)

func _cast_sutra(a: Vector2) -> bool:
	var n := halo
	if n <= 0:
		say("The halo is burnt out. It regrows.", 1.0)
		return false
	var fs := foes(a, 5.0)
	fs.sort_custom(func(p, q): return p.tp.distance_to(a) < q.tp.distance_to(a))
	for i in n:
		var ang := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.5
		ofuda.append({"tp": hero.tp - Vector2(0.2, 0.2), "z": 30.0, "v": Vector2(cos(ang + PI / 4.0), sin(ang + PI / 4.0)) * 3.0,
			"target": fs[i % fs.size()] if not fs.is_empty() else null, "aim": a, "t": 3.0, "delay": i * 0.07, "spin": randf() * 6.0, "dmg": D("ksutra", 9, 4)})
	halo = 0
	halo_t = 0.0
	return true

func _update_ofuda(dt: float) -> void:
	for o in ofuda:
		if o["delay"] > 0.0:
			o["delay"] -= dt
			o["tp"] = hero.tp - Vector2(0.2, 0.2)
			continue
		o["t"] -= dt
		o["spin"] += dt * 9.0
		var tg = o["target"]
		if tg == null or not is_instance_valid(tg) or tg.dead:
			tg = near(o["aim"], 6.0)
			if tg == null:
				tg = near(o["tp"], 6.0)
			o["target"] = tg
		var to: Vector2 = (tg.tp if tg else o["aim"]) - o["tp"]
		var d := maxf(0.001, to.length())
		o["v"] += (to / d * 11.0 - o["v"]) * minf(1.0, dt * 5.0)
		o["tp"] += o["v"] * dt
		o["z"] += (10.0 - o["z"]) * minf(1.0, dt * 4.0)
		var hit := near(o["tp"], 0.5)
		if hit != null and hit.tp.distance_to(o["tp"]) > hit.radius + 0.3:
			hit = null
		if hit != null or o["t"] <= 0.0 or (tg == null and d < 0.3):
			o["t"] = 0.0
			for m in foes(o["tp"], 1.2):
				hurt(m, o["dmg"], "ksutra")
				burn(m, o["dmg"] * 0.2, 2.0)
			if aU("kr_sutra"):
				seals.append({"tp": o["tp"], "t": 3.0, "max": 3.0, "R": 0.9, "dps": o["dmg"] * 0.5, "tick": 0.0})
			ring(o["tp"], 1.2, 0.25, Color8(255, 176, 96))
			dust(o["tp"], Color(1.0, 0.85, 0.44), 10)
			Sfx.play("hit", 0.4, 1.5)
	ofuda = ofuda.filter(func(o): return o["t"] > 0.0)

func _cast_tears() -> bool:
	var n := tears_n()
	for i in n:
		var a := i / float(n) * TAU + randf_range(-0.3, 0.3)
		var p := hero.tp + Vector2(cos(a), sin(a)) * randf_range(1.2, 3.2)
		if zone.is_solid(p):
			continue
		tears.append({"tp": p, "from": hero.tp, "fall": 0.35 + i * 0.05, "arm": 0.6 + i * 0.05, "t": 15.0, "dmg": D("ktears", 16, 7)})
	say_at(hero.tp + Vector2(0, -0.3), "boo hoo", Color8(191, 232, 255))
	while tears.size() > 30:
		tears.pop_front()
	return true

func _update_tears(dt: float) -> void:
	for t in tears:
		t["t"] -= dt
		if t["fall"] > 0.0:
			t["fall"] -= dt
		if t["arm"] > 0.0:
			t["arm"] -= dt
			continue
		for m in mons():
			if not m.flying and m.tp.distance_to(t["tp"]) < m.radius + 0.45:
				t["t"] = 0.0
				geysers.append({"tp": t["tp"], "t": 0.7})
				for q in foes(t["tp"], 1.3):
					hurt(q, t["dmg"], "ktears")
					burn(q, t["dmg"] * 0.2, 3.0)
				dust(t["tp"], Color(1.0, 0.97, 0.82), 16, 3.0)
				Sfx.play("cast_soul", 0.6, 1.6)
				break
	tears = tears.filter(func(t): return t["t"] > 0.0)
	for g in geysers:
		g["t"] -= dt
	geysers = geysers.filter(func(g): return g["t"] > 0.0)

func _cast_bell() -> bool:
	var T := 5.0 + 0.15 * L1("kbell")
	bell = {"t": T, "max": T, "cd": 0.0, "ring": 0.0, "drop": 0.25}
	say_at(hero.tp + Vector2(0, -0.4), "OM", Color8(240, 216, 144))
	Sfx.play("bell_far", 1.0, 1.3)
	return true

func _bell_ring() -> void:
	if bell.is_empty() or bell["cd"] > 0.0:
		return
	bell["cd"] = 0.35
	bell["ring"] = 0.4
	var dmg := D("kbell", 10, 4.5)
	for m in foes(hero.tp, 3.0):
		hurt(m, dmg, "kbell")
		stun(m, 1.5 if K("kbloud") > 0 else 0.5)
	ring(hero.tp, 3.0, 0.4, Color8(240, 216, 144))
	Sfx.play("bell_far", 0.8, 1.8)

func _update_eye(dt: float) -> void:
	if eye.is_empty():
		return
	if (not held("keye") and eye["t"] > 0.35) or hero.dead or hero.act == "roll":
		eye = {}
		if hold_id == "keye":
			hold_id = ""
		return
	if hold_id == "keye" and eye["t"] > 0.35:
		hold_id = ""
	pour(0, cost("keye") * dt)
	cast_t = time
	eye["t"] += dt
	hero.walking = false
	var want := (aim_point() - hero.tp).angle()
	var da := wrapf(want - eye["ang"], -PI, PI)
	eye["ang"] += clampf(da, -3.0 * dt, 3.0 * dt)
	hero._face(Vector2(cos(eye["ang"]), sin(eye["ang"])))
	eye["tick"] -= dt
	if eye["tick"] > 0.0:
		return
	eye["tick"] = 0.15
	var L := 7.5
	var dv := Vector2(cos(eye["ang"]), sin(eye["ang"]))
	var dmg := D("keye", 24, 9) * 0.15
	for m in mons():
		var o: Vector2 = m.tp - hero.tp
		var al := o.dot(dv)
		if al < 0.0 or al > L + m.radius or absf(o.x * dv.y - o.y * dv.x) > 0.35 + m.radius:
			continue
		hurt(m, dmg * (1.0 + m.armor / 100.0) * 100.0 / (100.0 + minf(m.armor, 60.0)), "keye")
		if K("keyecut") > 0 and float(m.get_meta("k_cut", -1.0)) < now():
			m.set_meta("k_cut", now() + 4.0)
			var cut: float = m.armor * 0.33
			m.armor -= cut
			var mm = m
			hero.get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(mm): mm.armor += cut)

func _update_lotus(dt: float) -> void:
	if lotus.is_empty():
		return
	if (not held("klotus") and lotus["t"] > 0.35) or hero.dead:
		lotus = {}
		if hold_id == "klotus":
			hold_id = ""
		return
	if hold_id == "klotus" and lotus["t"] > 0.35:
		hold_id = ""
	pour(0, cost("klotus") * dt)
	cast_t = time
	lotus["t"] += dt
	hero.walking = false
	var R := minf(3.6, 1.1 + lotus["t"] * 0.65) * area()
	lotus["R"] = R
	if K("klpull") > 0:
		for m in foes(hero.tp, R + 1.5):
			if m.boss:
				continue
			var d: float = m.tp.distance_to(hero.tp)
			if d > 0.9:
				m.tp = zone.move(m.tp, (hero.tp - m.tp) / d * 1.6 * dt, m.radius * 0.6)
	lotus["tick"] -= dt
	if lotus["tick"] > 0.0:
		return
	lotus["tick"] = 0.25
	var dmg := D("klotus", 14, 6) * 0.25 * (0.55 + 0.45 * minf(1.0, lotus["t"] / 4.0))
	for m in foes(hero.tp, R):
		hurt(m, dmg, "klotus")

func _cast_sun() -> bool:
	sun_t = sun_len()
	sun_tick = 0.0
	banner(data["ksun"]["name"].to_upper(), Color8(255, 216, 112))
	say_at(hero.tp + Vector2(0, -0.4), "HA HA HA", Color8(255, 240, 208))
	return true

func _update_sun(dt: float) -> void:
	if sun_t <= 0.0:
		return
	sun_t -= dt
	sun_tick -= dt
	if sun_tick <= 0.0:
		sun_tick = 0.35
		var dmg := D("ksun", 20, 7) * 0.35
		var fs := foes(hero.tp, 7.5)
		fs.sort_custom(func(a, b): return a.tp.distance_to(hero.tp) < b.tp.distance_to(hero.tp))
		for m in fs.slice(0, sun_n()):
			hurt(m, dmg, "ksun")
			beams.append({"tp": m.tp, "t": 0.22, "col": Color8(255, 216, 112)})
	if sun_t <= 0.0:
		sun_t = 0.0
		dust(hero.tp, Color(1.0, 0.85, 0.44), 20, 2.5)

func _laugh() -> void:
	var R := laugh_r()
	var dmg := D("klaugh", 5.6, 2.8)
	for m in foes(hero.tp, R):
		hurt(m, dmg, "klaugh")
		if m.brain and m.brain.state == "parry":
			m.brain.state = "chase"
	ring(hero.tp, R, 0.5, Color8(255, 240, 160))
	ring(hero.tp, R * 0.6, 0.35, Color8(255, 255, 255))
	say_at(hero.tp + Vector2(0, -0.3), "HA!", Color8(255, 244, 192))
	Sfx.play("cast_soul", 0.5, 0.6)
