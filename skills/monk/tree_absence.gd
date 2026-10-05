extends "res://skills/monk/tree_radiance.gd"
## The Empty Hand, part 3 of 5: the Absence tree.

# ------------------------------------------------------------------ Absence
func _cast_palm() -> bool:
	if aR("ka_palm"):
		# reversed: the palm casts out: everything in reach thrown to the edge, stunned 1 s, torn as it goes
		var R := float(palm_r())
		for m in foes(hero.tp, R):
			hurt(m, D("kpalm", 3.5, 1.7) * 5.0, "kpalm")
			if not m.boss:
				var d: float = m.tp.distance_to(hero.tp)
				shove(m, hero.tp, maxf(0.0, R - d))
			stun(m, 1.0)
		ring(hero.tp, R, 0.6, Color8(138, 106, 200), R * 0.2)
		return true
	palm = {"t": 1.0, "tick": 0.0, "R": float(palm_r())}
	cast_len = 1.0
	ring(hero.tp, palm["R"], 0.9, Color8(138, 106, 200))
	return true

func _update_palm(dt: float) -> void:
	if palm.is_empty():
		return
	palm["t"] -= dt
	palm["tick"] -= dt
	var tick: bool = palm["tick"] <= 0.0
	if tick:
		palm["tick"] = 0.2
	for m in foes(hero.tp, palm["R"]):
		var d: float = m.tp.distance_to(hero.tp)
		if not m.boss and d > 0.9 + m.radius:
			var s := minf(d - 0.8, 6.0 * dt)
			m.tp = zone.move(m.tp, (hero.tp - m.tp) / d * s, m.radius * 0.6)
		if tick:
			hurt(m, D("kpalm", 3.5, 1.7), "kpalm")
		wake(m)
		# The Hungry Ghost: what reaches your feet weak enough is swallowed whole
		if aU("ka_palm") and not m.dead and not m.boss and m.rank != "unique" and m.tp.distance_to(hero.tp) < 1.3 and m.hp < m.hp_max * 0.15:
			say_at(m.tp, "swallowed", Color8(138, 122, 168))
			src = "dust"
			Combat.hit_monster(m, m.hp + 1.0, "void", hero.tp, {"poise": 0.0})
			src = ""
	if palm["t"] <= 0.0:
		palm = {}

func _cast_clap() -> bool:
	var R := clap_r()
	if aR("ka_clap"):
		# reversed: no sound. Nothing is stunned, but every enemy missile near is unmade and the ring cannot strike
		for mi in hero.get_tree().get_nodes_in_group("missiles"):
			if mi.side != "hero" and mi.tp.distance_to(hero.tp) < 6.0:
				mi.queue_free()
		for m in foes(hero.tp, R):
			m.set_meta("k_silent", now() + 4.0)
		claps.append({"tp": hero.tp, "t": 0.0, "dur": 0.45, "R": R})
		return true
	if aU("ka_clap"):
		clap2 = {"t": 0.4, "R": R * 1.4}
	var st := clap_stun()
	var dmg := D("kclap", 6, 2.6)
	var broke := 0
	for m in foes(hero.tp, R):
		if m.brain and m.brain.state in ["wind", "charge", "chargeWind"]:
			broke += 1
			m.brain.state = "chase"
			say_at(m.tp, "hushed", Color8(184, 168, 216))
		stun(m, st)
		hurt(m, dmg, "kclap")
	claps.append({"tp": hero.tp, "t": 0.0, "dur": 0.45, "R": R})
	Game.shake(4.0)
	Sfx.play("heavy", 0.9, 1.4)
	if broke > 0:
		say("%d blow%s never landed." % [broke, "s" if broke > 1 else ""], 1.0)
	return true

func _cast_spade(a: Vector2) -> bool:
	var ang := (a - hero.tp).angle()
	if aR("ka_spade"):
		# reversed: the cut flies as a black crescent, 7 yd through everything
		var dv := Vector2(cos(ang), sin(ang))
		for m in mons():
			var o: Vector2 = m.tp - hero.tp
			var al := o.dot(dv)
			if al < 0.0 or al > 7.0 + m.radius or absf(o.x * dv.y - o.y * dv.x) > 0.6 + m.radius:
				continue
			hurt(m, spade_dmg() * 0.8, "kspade")
			_tear_shadow(m, ang)
		shades.append({"tp": hero.tp, "v": dv * 12.0, "t": 0.6, "w": 0.9})
		Sfx.play("swing", 0.9, 0.7)
		return true
	var R := 2.1
	var dmg := spade_dmg()
	for m in foes(hero.tp, R):
		if absf(wrapf((m.tp - hero.tp).angle() - ang, -PI, PI)) > 1.65:
			continue
		hurt(m, dmg, "kspade", {"melee": true})
		fault(m)
		_tear_shadow(m, ang)
	slams.append({"tp": hero.tp, "z": 10, "t": 0.25, "max": 0.25, "kind": "arc", "a": ang, "R": R})
	Sfx.play("swing", 0.9, 0.9)
	return true

## tear a creature's shadow loose (lit ones only, or all with Grave-Light); The Gravedigger sends it on to pin another
func _tear_shadow(m, ang: float, crawl: bool = true) -> void:
	var l := lit(m)
	if not (l or K("kspadew") > 0):
		return
	var k := 1.0 if l else 0.5
	root(m, 2.5 * dur() * k)
	m.set_meta("k_shadow", now() + 4.0 * dur() * k)
	m.set_meta("k_shadow_dps", D("kspade", 7, 3))
	shades.append({"tp": m.tp, "v": Vector2(cos(ang), sin(ang)) * 2.0 + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)), "t": 1.1, "w": m.radius})
	say_at(m.tp, "shadowless", Color8(138, 122, 168))
	if crawl and aU("ka_spade"):
		var o := near(m.tp, 3.0, func(q): return q != m and float(q.get_meta("k_shadow", -1.0)) < now())
		if o:
			root(o, 2.5 * dur() * k)
			o.set_meta("k_shadow", now() + 4.0 * dur() * k)
			o.set_meta("k_shadow_dps", D("kspade", 7, 3))
			shades.append({"tp": m.tp, "v": (o.tp - m.tp) / 1.1, "t": 1.1, "w": o.radius})

func _cast_pinch(a: Vector2) -> bool:
	var m := near(a, 2.2)
	if m == null:
		m = near(hero.tp, 8.0, func(q): return zone.sight_clear(hero.tp, q.tp) and q.tp.distance_to(a) < 4.0)
	if m == null:
		say("Nothing near the cursor to pinch.", 1.0)
		return false
	hero._face(m.tp - hero.tp)
	beams.append({"tp": m.tp, "t": 0.3, "col": Color8(240, 216, 144), "thread": true})
	var weak := raised(m) and (m.rank in ["normal", "minion"] or (m.rank == "champion" and K("kpinchx") > 0))
	if weak:
		say_at(m.tp, "strings cut", Color8(240, 216, 144))
		src = "dust"
		Combat.hit_monster(m, m.hp + 1.0, "void", hero.tp, {"poise": 0.0})
		src = ""
		Sfx.play("glass", 0.5, 1.6)
		return true
	hurt(m, D("kpinch", 14, 6) * (2.0 if raised(m) else 1.0), "kpinch")
	if not m.dead:
		m.set_meta("k_silent", now() + 3.0)
		m.set_meta("k_weak", now() + 6.0)
		if m.brain and m.brain.state in ["wind", "charge"]:
			m.brain.state = "chase"
		say_at(m.tp, "silenced", Color8(184, 168, 216))
	return true

func _cast_below(a: Vector2) -> bool:
	var pick := func(ex: Array):
		var best = null
		var bh := -1.0
		for m in foes(a, 3.0):
			if m in ex:
				continue
			var h: float = m.hp_max * (3.0 if m.boss else (2.0 if m.rank == "unique" else (1.5 if m.rank == "champion" else 1.0)))
			if h > bh:
				bh = h
				best = m
		return best
	var t1 = pick.call([])
	if t1 == null:
		say("No enemy near the cursor.", 1.0)
		return false
	var tg := [t1]
	if K("kbelow2") > 0:
		var t2 = pick.call([t1])
		if t2 != null:
			tg.append(t2)
	for m in tg:
		var hold := 0.6 if m.boss else 3.0 * dur() + (1.0 if aM("ka_grip") else 0.0)
		hands.append({"m": m, "tp": m.tp, "t": 0.0, "dur": hold, "tick": 0.0, "dps": D("kbelow", 12, 5)})
		stun(m, hold)
		root(m, hold)
	Game.shake(3.0)
	Sfx.play("heavy", 0.8, 0.6)
	return true

func _update_hands(dt: float) -> void:
	for h in hands:
		h["t"] += dt
		var m = h["m"]
		if m != null and is_instance_valid(m) and not m.dead:
			m.tp = h["tp"]
			h["tick"] -= dt
			if h["tick"] <= 0.0 and h["t"] < h["dur"]:
				h["tick"] = 0.4
				hurt(m, h["dps"] * 0.4, "kbelow")
	hands = hands.filter(func(h): return h["t"] < h["dur"] + 0.4)

func _cast_spit(a: Vector2) -> bool:
	var p := clamp_cast(a, 8.0)
	var R := spit_r()
	var t := 3.0 * dur() + (1.0 if aM("ka_roots") else 0.0)
	roots.append({"tp": p, "R": R, "t": t, "max": t, "tick": 0.0, "dps": D("kspit", 7, 3.2), "seed": randf() * 99.0})
	for m in foes(p, R):
		root(m, 2.5 * dur())
	beams.append({"tp": p, "t": 0.25, "col": Color8(58, 42, 42), "spit": true})
	Sfx.play("cast_thread", 0.6, 0.6)
	return true

func _update_roots(dt: float) -> void:
	for r in roots:
		r["t"] -= dt
		r["tick"] -= dt
		if r["tick"] > 0.0:
			continue
		r["tick"] = 0.5
		for m in foes(r["tp"], r["R"]):
			var d: float = r["dps"] * 0.5
			var dealt := hurt(m, d, "kspit")
			root(m, 0.6)
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dealt * 0.2)
	roots = roots.filter(func(r): return r["t"] > 0.0)

func _toggle_walk() -> bool:
	if walk:
		walk = false
		dust(hero.tp, Color(0.16, 0.13, 0.2), 8)
		return false
	pay("kwalk")
	walk = true
	walk_t = 0.3
	ring(hero.tp, 2.8, 0.6, Color8(122, 90, 176))
	_after("kwalk", aim_point())
	return false

func _cast_mirror() -> bool:
	mirror_t = 3.0 + 0.1 * L1("kmirror") + (1.0 if aM("ka_face") else 0.0)
	dust(hero.tp, Color(0.07, 0.05, 0.09), 16)
	cast_len = 0.25
	return true

func _cast_nothing() -> bool:
	nothing_t = 8.0
	marks.clear()
	hero.walking = true
	for m in mons():
		_lose(m)
	banner(data["knothing"]["name"].to_upper(), Color8(154, 148, 168))
	Sfx.play("bell_far", 0.6, 0.4)
	cast_len = 0.3
	return true

func _end_nothing() -> void:
	nothing_t = 0.0
	var n := 0
	var dmg := D("knothing", 34, 13)
	for m in marks:
		if not is_instance_valid(m) or m.dead:
			continue
		n += 1
		slams.append({"tp": m.tp, "z": 0, "t": 0.5, "max": 0.5, "kind": "implode"})
		hurt(m, dmg, "knothing")
		if K("knoth2") > 0:
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.02)
	marks.clear()
	banner("RETURNED", Color8(232, 226, 208))
	if n > 0:
		Game.shake(5.0)
		Sfx.play("heavy", 0.9, 0.5)

func _drink_bowl() -> void:
	var f := bowl
	if f <= 0:
		return
	bowl = 0
	hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.015 * f)
	kR *= 0.75
	kA *= 0.75
	if aM("ka_bowl"):
		run_back(0.03 * f)
	sync_res()
	say_at(hero.tp + Vector2(0, -0.3), "drinks nothing (%d)" % f, Color8(201, 166, 107))
	Sfx.play("drink", 0.6)
