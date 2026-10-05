extends "res://skills/monk/tree_absence.gd"
## The Empty Hand, part 4 of 5: the Destroyer tree, and the Weeping One who walks.

# ------------------------------------------------------------------ Destroyer
func _cast_grip(m) -> bool:
	if m == null:
		return false
	var stone := func(q, t: float):
		var tt := 1.0 if q.boss else t
		q.set_meta("k_stone", now() + tt)
		stun(q, tt)
		root(q, tt)
		dust(q.tp, Color(0.54, 0.53, 0.49), 12, 1.6)
		say_at(q.tp, "weeping stone", Color8(176, 172, 160))
	stone.call(m, 5.0 if aM("kd_stone") else 4.0)
	hurt(m, fist() * 0.5, "kgrip", {"melee": true})
	if K("kgrip2") > 0:
		var o := near(m.tp, 2.0, func(q): return q != m)
		if o:
			stone.call(o, 3.0)
	Sfx.play("break", 0.6, 1.2)
	return true

func _cast_finger(m) -> bool:
	if aR("kd_finger"):
		# reversed: the finger points and does not touch: the first enemy in a 7 yd line, through armour, at 80%
		var dv := (aim_point() - hero.tp).normalized()
		var best = null
		var bd := 99.0
		for q in mons():
			var o: Vector2 = q.tp - hero.tp
			var al := o.dot(dv)
			if al > 0.0 and al < 7.0 + q.radius and absf(o.x * dv.y - o.y * dv.x) < 0.5 + q.radius and al < bd:
				bd = al
				best = q
		if best == null:
			say("Nothing in the line.", 0.8)
			return false
		m = best
	if m == null:
		return false
	var ranged := aR("kd_finger")
	var st := is_stone(m)
	var dmg := fist() * (1.7 + 0.16 * L1("kfinger")) * syn("kfinger") * (2.5 if st else 1.0)
	var poke := func(q):
		hurt(q, dmg * (100.0 + q.armor) / 100.0 * (0.8 if ranged else 1.0), "kfinger", {"melee": not ranged, "heavy": true})   # no armour, no guard
		fault(q)
		if aU("kd_finger") and not q.dead and not is_stone(q):
			q.set_meta("k_stone", now() + (1.0 if q.boss else 2.0))
			stun(q, 2.0)
			root(q, 2.0)
			say_at(q.tp, "the answer hardens", Color8(176, 172, 160))
	poke.call(m)
	if st:
		say_at(m.tp, "truth", Color.WHITE)
	var ang: float = (m.tp - hero.tp).angle()
	slams.append({"tp": m.tp, "z": 14, "t": 0.5, "max": 0.5, "kind": "hole", "a": ang})
	if K("kfinger2") > 0:
		var o := near(m.tp + Vector2(cos(ang), sin(ang)) * 1.3, 1.2, func(q): return q != m)
		if o:
			poke.call(o)
			slams.append({"tp": o.tp, "z": 14, "t": 0.5, "max": 0.5, "kind": "hole", "a": ang})
	Sfx.play("hit", 1.0, 1.5)
	return true

func _cast_obsid() -> bool:
	obsid = 10.0 + 0.5 * L1("kobsid") + (4.0 if aM("kd_obsid") else 0.0)
	dust(hero.tp, Color(0.11, 0.09, 0.15), 20, 2.2)
	ring(hero.tp, 2.4, 0.6, Color8(154, 146, 192))
	say_at(hero.tp + Vector2(0, -0.4), "ON KOKUYO", Color8(138, 134, 160))
	return true

func _cast_mount(a: Vector2) -> bool:
	if aR("kd_mount"):
		# reversed: no leap. He drops where he stands; the stone rolls twice as far and stuns
		leap = {"from": hero.tp, "to": hero.tp, "t": 0.0, "dur": 0.3, "far": true}
		cast_len = 0.5
		return true
	var p := clamp_cast(a, 5.0)
	if zone.is_solid(p):
		p = hero.tp.lerp(p, 0.5)
	leap = {"from": hero.tp, "to": p, "t": 0.0, "dur": 0.55}
	hero.invuln = maxf(hero.invuln, 0.5)
	cast_len = 0.7
	say_at(hero.tp + Vector2(0, -0.3), "ha")
	return true

func _update_leap(dt: float) -> void:
	if leap.is_empty():
		return
	leap["t"] += dt
	var k: float = minf(1.0, leap["t"] / leap["dur"])
	var p: Vector2 = leap["from"].lerp(leap["to"], k)
	if not zone.is_solid(p):
		hero.tp = p
	float_z = sin(k * PI) * 30.0
	hero.walking = false
	if k >= 1.0:
		var leap_was := leap
		leap = {}
		float_z = 0.0
		var R := 2.3
		var dmg := D("kmount", 20, 8) * 1.25 * (0.6 if leap_was.get("second", false) else 1.0)
		for m in foes(hero.tp, R):
			hurt(m, dmg, "kmount", {"heavy": true})
			stun(m, 0.8)
			fault(m)
		slams.append({"tp": hero.tp, "z": 0, "t": 0.6, "max": 0.6, "kind": "crater", "R": R})
		var far: bool = leap_was.get("far", false)
		quake = {"tp": hero.tp, "r": R * 0.6, "max": R + (6.0 if far else 3.0), "hit": {}, "dmg": dmg * 0.4, "stun": far}
		if aU("kd_mount") and not leap_was.get("second", false) and not far:
			# the mountain lands twice: a bounce 2 yd onward
			var dv: Vector2 = (leap_was["to"] - leap_was["from"]).normalized()
			if dv.length() < 0.1:
				dv = Vector2(1, 0)
			var p2: Vector2 = hero.tp + dv * 2.0
			if not zone.is_solid(p2):
				leap = {"from": hero.tp, "to": p2, "t": 0.0, "dur": 0.35, "second": true}
		Game.shake(8.0)
		dust(hero.tp, Color(0.54, 0.48, 0.35), 24, 4.0)
		ring(hero.tp, R + 1.0, 0.6, Color8(216, 200, 160))
		Sfx.play("heavy", 1.0, 0.5)

func _update_quake(dt: float) -> void:
	if quake.is_empty():
		return
	quake["r"] += 7.0 * dt
	for m in mons():
		if quake["hit"].has(m.get_instance_id()):
			continue
		if absf(m.tp.distance_to(quake["tp"]) - quake["r"]) < 0.5 + m.radius:
			quake["hit"][m.get_instance_id()] = true
			hurt(m, quake["dmg"], "kmount")
			if K("kmount2") > 0 or quake.get("stun", false):
				stun(m, 1.0)
	for i in 3:
		var a := randf() * TAU
		spikes.append({"tp": quake["tp"] + Vector2(cos(a), sin(a)) * quake["r"], "t": 0.45, "max": 0.45, "h": randf_range(5, 9)})
	if quake["r"] >= quake["max"]:
		quake = {}

func _cast_step(a: Vector2) -> bool:
	var base := (a - hero.tp).angle()
	var angs := [base, base - 0.35, base + 0.35] if K("kstep2") > 0 else [base]
	for ang: float in angs:
		stepq.append({"tp": hero.tp, "d": Vector2(cos(ang), sin(ang)), "i": 0, "n": 15 if aM("kd_bedrock") else 11, "tick": 0.0, "dmg": D("kstep", 15, 6.5) * (1.0 if ang == base else 0.7), "hit": {}})
	Game.shake(4.0)
	return true

func _update_step(dt: float) -> void:
	for q in stepq:
		q["tick"] -= dt
		if q["tick"] > 0.0:
			continue
		q["tick"] = 0.045
		q["i"] += 1
		var p: Vector2 = q["tp"] + q["d"] * (0.4 + q["i"] * 0.6)
		var g := ground_key(p)
		if g in ["water", "shallow"] or zone.is_solid(p):
			q["i"] = q["n"]
			dust(p, Color(0.54, 0.69, 0.75), 6, 1.2)
			continue
		var road := g in ["road", "flags"]
		spikes.append({"tp": p, "t": 0.6, "max": 0.6, "h": 14.0 if road else 11.0})
		for m in foes(p, 0.75):
			if q["hit"].has(m.get_instance_id()):
				continue
			q["hit"][m.get_instance_id()] = true
			hurt(m, q["dmg"] * (2.0 if road else 1.0), "kstep")
			stun(m, 0.4)
		if q["i"] % 3 == 0:
			Sfx.play("break", 0.35, 1.3)
	stepq = stepq.filter(func(q): return q["i"] < q["n"])

func _cast_pagoda(a: Vector2) -> bool:
	var m := near(a, 2.2)
	if m == null:
		m = near(hero.tp, 7.0, func(q): return q.tp.distance_to(a) < 3.5)
	if m == null:
		say("No enemy near the cursor.", 1.0)
		return false
	pagodas.append({"m": m, "tp": m.tp, "t": 0.0, "dur": 1.5 if aM("kd_snap") else 2.2, "dmg": D("kpagoda", 34, 13), "r": m.radius, "done": false})
	stun(m, 2.3)
	root(m, 2.3)
	Game.shake(3.0)
	Sfx.play("break", 0.7, 0.8)
	return true

func _update_pagodas(dt: float) -> void:
	for p in pagodas:
		p["t"] += dt
		var m = p["m"]
		if m != null and is_instance_valid(m) and not m.dead and p["t"] < p["dur"]:
			m.tp = p["tp"]
		if p["t"] >= p["dur"] and not p["done"]:
			p["done"] = true
			Sfx.play("heavy", 1.0, 0.6)
			if m != null and is_instance_valid(m) and not m.dead:
				hurt(m, p["dmg"], "rubble", {"heavy": true})
			if K("kpagoda2") > 0:
				for q in foes(p["tp"], 2.0):
					if q != m:
						hurt(q, p["dmg"] * 0.4, "rubble")
			dust(p["tp"], Color(0.54, 0.53, 0.49), 24, 3.0)
			Game.shake(5.0)
	pagodas = pagodas.filter(func(p): return p["t"] < p["dur"] + 0.6)

func _cast_thousand(a: Vector2) -> bool:
	if aR("kd_arms"):
		# reversed: the arms close round him as a shell for 6 s
		shell_t = 6.0
		ring(hero.tp, 1.6, 0.6, Color8(176, 172, 160))
		return true
	thousand = {"t": 0.0, "ang": (a - hero.tp).angle(), "tick": 0.0, "n": 0, "max": 18 if K("kthous2") > 0 else 12, "dmg": D("kthousand", 9, 3.5), "pulv": {}}
	cast_len = 1.5
	return true

func _update_thousand(dt: float) -> void:
	if thousand.is_empty():
		return
	var T := thousand
	T["t"] += dt
	T["tick"] -= dt
	hero.walking = false
	if T["t"] > 0.35 and T["tick"] <= 0.0 and T["n"] < T["max"]:
		T["tick"] = 1.1 / T["max"]
		T["n"] += 1
		for m in foes(hero.tp, 5.5):
			if not aU("kd_arms") and absf(wrapf((m.tp - hero.tp).angle() - T["ang"], -PI, PI)) > 0.85:
				continue
			hurt(m, T["dmg"], "kthousand")
			if not T["pulv"].has(m.get_instance_id()):
				T["pulv"][m.get_instance_id()] = true
				m.armor = roundf(m.armor * 0.5)
		for i in 4:
			var aa: float = T["ang"] + (randf() * TAU if aU("kd_arms") else randf_range(-0.8, 0.8))
			slams.append({"tp": hero.tp + Vector2(cos(aa), sin(aa)) * randf_range(1.2, 5.5), "z": randf_range(4, 24), "t": 0.3, "max": 0.3, "kind": "palm", "s": randf_range(1.0, 1.8), "stone": randf() < 0.5})
		if T["n"] % 2 == 1:
			Sfx.play("hit", 0.5, randf_range(0.7, 0.9))
		Game.shake(2.0)
	if T["t"] > 1.8:
		thousand = {}

# ------------------------------------------------------------------ the Weeping One
func _summon_buddha(a: Vector2) -> bool:
	var p := clamp_cast(a, 5.0)
	if zone.is_solid(p):
		p = hero.tp + Vector2(0.8, 0)
	var stt := buddha_stats()
	var hp: float = stt["max"]
	if not buddha_mem.is_empty():
		hp = minf(stt["max"], buddha_mem["frac"] * stt["max"] + (time - buddha_mem["at"]) * 0.01 * stt["max"])
	buddha = BuddhaView.new()
	buddha.book = self
	buddha.tp = p
	buddha.hp = maxf(stt["max"] * 0.25, hp)
	buddha.max_hp = stt["max"]
	zone.sorted.add_child(buddha)
	buddha_mem = {}
	Game.shake(5.0)
	dust(p, Color(0.54, 0.53, 0.49), 24, 3.0)
	say("The Weeping One rises.", 1.5)
	return true

func _command_buddha(a: Vector2) -> void:
	if buddha == null:
		return
	if buddha.tp.distance_to(a) < 1.4:
		buddha_mem = {"frac": buddha.hp / buddha.max_hp, "at": time}
		dust(buddha.tp, Color(0.54, 0.53, 0.49), 20, 2.4)
		buddha.queue_free()
		buddha = null
		say("The Weeping One sinks back into the earth. It keeps its wounds.", 1.6)
		return
	buddha.order = {"tp": a, "t": 4.0}
	buddha.atk = {}
	say_at(buddha.tp + Vector2(0, -0.6), "go", Color8(176, 172, 160))

func buddha_fell() -> void:
	if buddha == null:
		return
	dust(buddha.tp, Color(0.54, 0.53, 0.49), 30, 3.5)
	buddha_mem = {"frac": 0.5, "at": time}
	buddha.queue_free()
	buddha = null
	say("The Weeping One crumbles.", 1.6)
	Game.shake(5.0)
