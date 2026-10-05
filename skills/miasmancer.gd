extends "res://skills/miasmancer/tree_death.gd"
## The Shrine Keeper (class id "miasmancer"), part 5 of 5: casting (which skill runs what), the hooks the shared game
## calls, and the frame: the cloud, breathing, sickness, clouds and traps, the Mirror-Sister, the --autocast driver.
## The state, numbers and helpers are in skills/miasmancer/base.gd; each tree's skills are in skills/miasmancer/tree_*.gd.

# ================================================================== casting
func use(id: String, at: Vector2, target: Monster) -> bool:
	if id == "attack" or id == "" or hero == null or zone == null:
		return false
	if lvl(id) <= 0 or is_passive(id):
		return false
	if hero.act != "" and hero.act != "swing" and hero.act != "cast":
		return false
	if not dash.is_empty():
		return false
	if target != null and is_instance_valid(target):
		at = target.tp
	at = _los_point(at)
	var c := cost(id)
	if hero.st.res < c:
		say("Not enough Miasma.", 1.0)
		return false
	var pc := poise_cost(id)
	if id == "execute" and K("execcheap") > 0:
		pc = 0.0
	if pc > 0.0 and hero.st.poise < pc * 0.5:
		say("Too weary.", 0.8)
		return false
	if MELEE.has(id):
		var m := melee_target(at, float(MELEE[id]))
		if m == null:
			var far := near(at, 3.6)
			if far != null and far.tp.distance_to(hero.tp) < 7.0:
				pending = {"id": id, "m": far, "t": 3.0}
				hero.target = null
				hero.walk_to(far.tp)
				return false
			if id == "execute":
				say("Nothing in reach to execute.", 0.8)
				return false
	cast_anim = POSE.get(id, "cast")
	var ok := _cast(id, at, target)
	if not ok:
		return false
	hero.st.res -= c
	if trace:
		dmg_log["_spent"] = float(dmg_log.get("_spent", 0.0)) + c
	if pc > 0.0:
		hero.spend_poise(pc)
	var tb := int(data.get(id, {}).get("tab", 0))
	Sfx.play(["cast_soul", "cast_mirror", "swing"][tb], 0.7, [0.7, 1.2, 1.1][tb])
	if cast_len < 0.0:
		cast_len = 0.45 / (hero.st.cast_speed() * cast_k())
	hero._face(at - hero.tp)
	hero.stats_changed.emit()
	return true

func _cast(id: String, a: Vector2, target) -> bool:
	match id:
		"vblade":
			venom_t = 40.0
			puff(hero.tp, VIOLET, 12)
			say("Miasma coats your claws.", 1.0)
			cast_len = 0.3
			return true
		"shuriken": return _shuriken(a)
		"pnova": return _nova(a)
		"contagion":
			var m := near(a, 2.5)
			if m == null:
				say("No enemy near the cursor.", 1.0)
				return false
			m.set_meta("k_cont", 10.0)
			psn(m, cont_psn(), 5.0)
			say_at(m.tp, "contagion", VIOLET)
			return true
		"rotwall": return _tide(a)
		"exhale": return _exhale()
		"mstorm":
			mstorm_t = storm_life()
			mstorm_tick = 0.0
			return true
		"blur": return _blur(a)
		"ntrap", "mwake", "bmine": return _throw_trap(id, a)
		"haze":
			if aR("z_hanged"):
				haze_mantle = 6.0 * ctrl()
				say("The haze wraps you.", 1.0)
			else:
				add_cloud(clamp_cast(a, 9.0), 2.2, 6.0 if K("hazelong") > 0 else 4.0, 0.0, "haze")
			return true
		"mirage":
			var p := clamp_cast(a, 9.0)
			var t := 9.0 if K("miragelong") > 0 else 6.0
			mirages.append({"tp": p, "R": 2.6, "t": t, "max": t})
			return true
		"lure":
			lures.append({"tp": clamp_cast(a, 9.0), "t": 5.0 if K("lurelong") > 0 else 3.0, "R": 8.0 if K("lurewide") > 0 else 5.0})
			return true
		"gstrike": return _grave_strike(a)
		"talon": return _talon(a)
		"flurry": return _flurry(a)
		"rarc": return _rarc(a)
		"thrust": return _thrust(a)
		"dstep": return _death_step(a)
		"reap":
			if aR("z_reaper"):
				return _throw_scythe(a)
			return _reap()
		"execute": return _execute(a)
	return false


# ================================================================== hooks the shared game calls
func before_hit(d: float, elem: String, from: Vector2, opts: Dictionary) -> float:
	if unseen_t > 0.0:
		return 0.0
	if randf() < evade():
		say_at(hero.tp + Vector2(0, -0.3), "miss", WARP)
		puff(hero.tp, WARP, 3, 1.0)
		return 0.0
	# a worn trap springs at her feet (The Trapper-Queen reversed)
	if not worn_traps.is_empty():
		var k: String = worn_traps.pop_front()
		_place_trap(k, hero.tp, true, 1.0)
		if k == "bmine":
			_trap_trigger(traps.back())
	# Last Breath: once in each place a killing blow leaves her standing (twice with Grave Breath). It used to be once
	# a minute; there are no waits in the Hide (the user's rule).
	var st = hero.st
	var after: float = d * (100.0 / (100.0 + st.armor()) if elem == "phys" else 1.0)
	var bz: String = str(hero.zone.id) if hero.zone else ""
	if K("lbreath") > 0 and int(breath_used.get(bz, 0)) < (2 if aM("zx_breath") else 1) and st.hp - after <= 0.0:
		breath_used[bz] = int(breath_used.get(bz, 0)) + 1
		st.hp = st.life_max() * 0.3 if K("breathheal") > 0 else 1.0
		hero.invuln = 2.0
		unseen_t = 2.0
		for m in mons():
			_lose(m)
		var ui = hero.get_tree().root.find_child("GodmarrowWorldUI", true, false)
		if ui:
			ui.banner("LAST BREATH", PALE, 1.4)
		puff(hero.tp, PALE, 20, 2.0)
		return 0.0
	return d

func unseen(m) -> bool:
	return unseen_t > 0.0

func catch_missile(mi) -> bool:
	return false


func melee_k() -> float:
	return (1.0 + 0.06 * K("deathm")) * (1.0 + 0.06 * omens)

func hud_gauge() -> Dictionary:
	return {"text": "OMENS %d/%d" % [omens, omen_max()], "pips": omens, "max": omen_max(), "col": PALE}

func on_lantern() -> void:
	hero.st.res = hero.st.res_max()

func on_death() -> void:
	_reset()

func _reset() -> void:
	for d in decoys:
		if is_instance_valid(d):
			d.queue_free()
	decoys.clear()
	if sister != null and is_instance_valid(sister):
		sister.queue_free()
	sister = null
	omens = 0
	venom_t = 0.0
	blur_ev = 0.0
	unseen_t = 0.0
	haze_mantle = 0.0
	worn_traps.clear()
	mstorm_t = 0.0
	dash = {}
	pending = {}
	queue.clear()

func _on_kill(m) -> void:
	if hero == null or hero.st == null or hero.cls != "miasmancer" or not is_instance_valid(m):
		return
	if float(m.get_meta("k_cont", 0.0)) > 0.0:
		add_cloud(m.tp, 2.2, 6.0, cont_psn() * 1.2)
	if aU("z_death"):
		add_omen()
	if sick(m) and (K("cbloom") > 0 or (aM("zm_carrion") and randf() < 0.15)):
		add_cloud(m.tp, 1.8, 5.0, aura_dps())

# ================================================================== the frame
func tick(dt: float) -> void:
	if hero == null or hero.zone == null:
		return
	time += dt
	if zone != hero.zone:
		_enter_zone()
	var st = hero.st
	var fr := frac()
	# delayed blows
	for q in queue:
		q["t"] -= dt
	var due := queue.filter(func(q): return q["t"] <= 0.0)
	queue = queue.filter(func(q): return q["t"] > 0.0)
	for q in due:
		if not hero.dead:
			q["f"].call()
	# a melee skill walking in
	if not pending.is_empty():
		pending["t"] -= dt
		var pm = pending["m"]
		if pm == null or not is_instance_valid(pm) or pm.dead or pending["t"] <= 0.0 or hero.dead:
			pending = {}
		elif pm.tp.distance_to(hero.tp) <= float(MELEE[pending["id"]]) + pm.radius + 0.25 and hero.act == "":
			var pid: String = pending["id"]
			pending = {}
			hero.walking = false
			cast_anim = "cast"
			cast_len = -1.0
			if use(pid, pm.tp, pm):
				hero._start_act(cast_anim, cast_len)
		elif not hero.walking:
			hero.walk_to(pm.tp)
	# the cloud about her: it sickens what stands in it (The Grave reversed: slows and weakens; The Plague-Bearer
	# reversed: drinks)
	aura_t -= dt
	var R := aura_r()
	if aura_t <= 0.0 and not hero.dead and K("mcloud") > 0:
		aura_t = 0.5
		var fed := 0
		for m in foes(hero.tp, R):
			fed += 1
			if aR("z_grave"):
				m.slow = maxf(m.slow, 0.4)
				m.set_meta("k_grave", time + 0.7)
			elif aR("z_plague"):
				st.hp = minf(st.life_max(), st.hp + st.life_max() * 0.005)
			else:
				psn(m, aura_dps(), 2.0, 1, false)
			if aM("z_veiled") and randf() < 0.15:
				confuse(m, 1.0)
			_warp(m, hero.tp)
		fed_aura = fed
	if fed_aura > 0 and K("thickair") > 0:
		st.res = minf(st.res_max(), st.res + st.res_regen() * dt)
	# the sickened: their sickness ticks, and they leak little clouds behind them
	for m in mons():
		var q: Dictionary = m.get_meta("k_psn", {})
		if q.is_empty():
			continue
		q["t"] -= dt
		q["tick"] -= dt
		if q["tick"] <= 0.0:
			q["tick"] = 0.5
			hurt(m, float(q["dps"]) * 0.5 * PSN_K, "psn", {"elem": "miasma", "poise": 0.0})
		var drip := float(m.get_meta("k_drip", 0.0)) - dt
		if drip <= 0.0:
			drip = 1.0 if K("toxdrip") > 0 else 2.0
			var c := add_cloud(m.tp + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)), 0.55, 2.5, 0.0)
			if not c.is_empty():
				c["drip"] = true
		m.set_meta("k_drip", drip)
		if q["t"] <= 0.0 or m.dead:
			m.remove_meta("k_psn")
	# standing in her own miasma thickens hers
	in_miasma = false
	for c in clouds:
		if c["kind"] == "poison" and (c["tp"] as Vector2).distance_to(hero.tp) < c["R"] + 0.3:
			in_miasma = true
			break
	if in_miasma and not hero.dead:
		st.res = minf(st.res_max(), st.res + st.res_regen() * 1.5 * (2.0 if K("toxfeed") > 0 else 1.0) * dt)
	_inhale(dt)
	# The Plague-Bearer: a trail of miasma where she walks
	if aU("z_plague") and not hero.dead and last_tp != Vector2.INF:
		trail_d += hero.tp.distance_to(last_tp)
		if trail_d > 1.2:
			trail_d = 0.0
			add_cloud(hero.tp, 0.8, 3.0, aura_dps() * 0.6)
	last_tp = hero.tp
	if K("mcloud") > 0 and randf() < 0.3 + fr * 0.5 + 0.05 * mini(6, K("mcloud") / 2):
		var a := randf() * TAU
		var rr := randf() * R * 0.8
		motes.append({"tp": hero.tp + Vector2(cos(a), sin(a)) * rr, "z": randf_range(2, 10), "v": Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), "vz": 1.6, "t": randf_range(0.9, 1.4), "col": Color8(143, 138, 124) if aR("z_grave") else (VIOLET_D if randf() < 0.5 else VIOLET)})
	# timers
	venom_t = maxf(0.0, venom_t - dt)
	blur_ev = maxf(0.0, blur_ev - dt)
	breath_cd = maxf(0.0, breath_cd - dt)
	unseen_t = maxf(0.0, unseen_t - dt)
	if omens > 0 and not aR("z_death"):
		omen_t -= dt
		if omen_t <= 0.0:
			omens = 0
			say_at(hero.tp + Vector2(0, -0.3), "omens fade", Color8(111, 106, 121))
	if haze_mantle > 0.0:
		haze_mantle -= dt
		for m in foes(hero.tp, 1.9):
			confuse(m, 2.0)
	_update_dash(dt)
	_update_traps(dt)
	_update_scythes(dt)
	_update_shuris(dt)
	_update_storm(dt)
	_update_sister(dt)
	_update_novas(dt)
	_update_tides(dt)
	_update_clouds(dt)
	_update_knives(dt)
	_update_fields(dt)
	# contagion leaps
	for m in mons():
		var ct := float(m.get_meta("k_cont", 0.0))
		if ct <= 0.0:
			continue
		ct -= dt
		m.set_meta("k_cont", ct)
		var cl := float(m.get_meta("k_cont_t", 0.0)) - dt
		if cl <= 0.0:
			cl = 1.5
			var n := (3 if K("epidemic") > 0 else 2) + (1 if aM("zm_contag") else 0)
			var LR := 5.0 if K("contspread") > 0 else 3.2
			var nb := foes(m.tp, LR).filter(func(o): return o != m)
			nb.sort_custom(func(p, q): return p.tp.distance_to(m.tp) < q.tp.distance_to(m.tp))
			for o in nb.slice(0, n):
				psn(o, cont_psn(), 4.0)
				zaps.append({"a": m.tp, "b": o.tp, "t": 0.2})
		m.set_meta("k_cont_t", cl)
	for arr in [clawfx, zaps, words, rings]:
		for q in arr:
			q["t"] -= dt
	for q in motes:
		q["t"] -= dt
		q["tp"] += q["v"] * dt
		q["z"] += q["vz"] * dt
	clawfx = clawfx.filter(func(q): return q["t"] > 0.0)
	zaps = zaps.filter(func(q): return q["t"] > 0.0)
	words = words.filter(func(q): return q["t"] > 0.0)
	rings = rings.filter(func(q): return q["t"] > 0.0)
	motes = motes.filter(func(q): return q["t"] > 0.0)
	_views()
	if auto_on:
		_autocast(dt)
	if trace:
		trace_t -= dt
		if trace_t <= 0.0:
			trace_t = 5.0
			var parts := []
			for k in dmg_log:
				parts.append("%s=%d" % [k, int(dmg_log[k])])
			print("MIAS hp %d t=%.0f res %.0f/%.0f omens %d clouds %d traps %d sister %s dmg {%s}" % [int(st.hp), time, st.res, st.res_max(), omens, clouds.size(), traps.size(), "yes" if sister != null else "-", ", ".join(parts)])

## Inhale, a passive: every few beats she sips the miasma about her (zz_miasma_breath.js)
func _inhale(dt: float) -> void:
	var L := K("inhale")
	if L <= 0 or hero.dead:
		return
	inhale_t -= dt
	if inhale_t > 0.0:
		return
	inhale_t = maxf(0.9, 2.4 - 0.08 * L)
	var gain := 0.0
	var R := (5.0 + 0.1 * L) * (2.0 if aM("zm_breath") else 1.0)
	for c in clouds:
		if c["kind"] == "poison" and (c["tp"] as Vector2).distance_to(hero.tp) <= R:
			gain += 0.5 + c["t"] * 0.15
	for m in foes(hero.tp, R):
		var q: Dictionary = m.get_meta("k_psn", {})
		if q.is_empty():
			continue
		gain += minf(1.5, float(q["dps"]) * 0.05)
		if K("deepdraw") > 0 and not m.boss:
			m.tp = zone.move(m.tp, (hero.tp - m.tp).normalized() * 0.08, m.radius * 0.6)
		for i in 2:
			motes.append({"tp": m.tp, "z": 4.0, "v": (hero.tp - m.tp) * 2.0, "vz": 4.0, "t": 0.45, "col": VIOLET})
	gain = gain * (1.5 if K("sickbreath") > 0 else 1.0) + 0.6 + 0.08 * L
	# G1 balance: one breath draws at most a tenth of her pool (a field of clouds used to refill her four times
	# faster than the Mystic's Essence comes back)
	gain = minf(gain, hero.st.res_max() * (0.1 if not aM("zm_breath") else 0.13))
	hero.st.res = minf(hero.st.res_max(), hero.st.res + gain)

## Warped Miasma: distortion in every cloud
func _warp(m, c: Vector2) -> void:
	if m.dead or m.boss or randf() >= warp_chance():
		return
	var opts := ["confuse", "slow", "twist"]
	if K("warpfear") > 0:
		opts.append("fear")
	var k: String = opts[randi() % opts.size()]
	match k:
		"confuse": confuse(m, 1.2)
		"slow": m.slow = maxf(m.slow, 0.8)
		"fear": fear(m, 1.2)
		_:
			var d: float = maxf(0.01, c.distance_to(m.tp))
			m.tp = zone.move(m.tp, (c - m.tp) / d * minf(d, 0.9), m.radius * 0.6)
	say_at(m.tp, {"twist": "twisted", "slow": "warped", "fear": "terror"}.get(k, "lost"), WARP)

func _update_clouds(dt: float) -> void:
	for c in clouds:
		c["t"] -= dt
		c["tick"] -= dt
		if c["tick"] > 0.0:
			continue
		c["tick"] = 0.5
		for m in foes(c["tp"], c["R"]):
			if c["kind"] == "haze":
				if aU("z_hanged") and float(m.get_meta("k_hung", -1.0)) < 0.0:
					m.set_meta("k_hung", time)
					stun(m, 1.5)
					m.z_lift = 0.0
				elif not aU("z_hanged") or time - float(m.get_meta("k_hung", time)) > 1.5:
					confuse(m, 1.6)
			elif c["dps"] > 0.0:
				psn(m, c["dps"], 2.0, 1, false)
				if aM("z_veiled") and randf() < 0.1:
					confuse(m, 1.0)
				_warp(m, c["tp"])
	clouds = clouds.filter(func(c): return c["t"] > 0.0)

func _update_novas(dt: float) -> void:
	for n in novas:
		n["r"] += 8.0 * dt
		for m in mons():
			if n["hit"].has(m.get_instance_id()):
				continue
			if absf(m.tp.distance_to(n["tp"]) - n["r"]) < 0.5 + m.radius:
				n["hit"][m.get_instance_id()] = true
				hurt(m, n["dmg"], "pnova")
				psn(m, n["psn"], 4.0)
				shove(m, n["tp"], 0.9)
		if n["r"] >= n["max"]:
			n["done"] = true
			if K("novacloud") > 0 or aU("z_bloom"):
				for i in 8:
					var a := i / 8.0 * TAU
					add_cloud(n["tp"] + Vector2(cos(a), sin(a)) * 4.2, 1.0, 8.0 if aU("z_bloom") else 5.0, n["psn"] * 0.5)
	novas = novas.filter(func(n): return not n.get("done", false))

func _update_tides(dt: float) -> void:
	for w in tides:
		w["t"] -= dt
		if w.get("spin", false):
			if w["follow"]:
				w["c"] = hero.tp
			w["ang"] += dt * 7.0
			w["tp"] = w["c"] + Vector2(cos(w["ang"]), sin(w["ang"])) * w["w"]
			for m in mons():
				var d: float = m.tp.distance_to(w["c"])
				if d > w["w"] + 0.6 + m.radius or d < w["w"] - 0.7:
					continue
				var last := float(w["hitT"].get(m.get_instance_id(), -9.0))
				if time - last < 0.4:
					continue
				w["hitT"][m.get_instance_id()] = time
				hurt(m, w["dmg"], "rotwall")
				psn(m, w["dmg"] * 0.3, 3.0)
			continue
		var stp: float = (6.0 if w.get("wake", false) else 7.0) * dt
		w["tp"] += w["d"] * stp
		if zone.is_solid(w["tp"]):
			w["t"] = 0.0
			continue
		for m in mons():
			if w["hit"].has(m.get_instance_id()):
				continue
			var o: Vector2 = m.tp - w["tp"]
			var along: float = o.dot(w["d"])
			var side: float = absf(o.x * w["d"].y - o.y * w["d"].x)
			if absf(along) > 0.5 + m.radius or side > w["w"] / 2.0 + m.radius:
				continue
			w["hit"][m.get_instance_id()] = m
			hurt(m, w["dmg"], "mwake" if w.get("wake", false) else "rotwall")
			psn(m, w["dmg"] * 0.4, 4.0)
		# a wave carries what it hits along before it
		for id in w["hit"]:
			var m = w["hit"][id]
			if m is Object and is_instance_valid(m) and not m.dead and not m.boss:
				var o: Vector2 = m.tp - w["tp"]
				var along: float = o.dot(w["d"])
				if along > -0.9 and along < 0.9 + m.radius and absf(o.x * w["d"].y - o.y * w["d"].x) < w["w"] / 2.0 + m.radius:
					m.tp = zone.move(m.tp, w["d"] * stp * (0.6 if w.get("wake", false) else 0.9), m.radius * 0.6)
		if w.get("trail", false):
			w["trailT"] -= stp
			if w["trailT"] <= 0.0:
				w["trailT"] = 1.2
				add_cloud(w["tp"], 1.0, 4.0, w["dmg"] * 0.15)
	tides = tides.filter(func(w): return w["t"] > 0.0)

func _update_shuris(dt: float) -> void:
	for s in shuris:
		s["t"] += dt
		s["spin"] += dt * 30.0
		var ang: float = s["a0"] + s["dir"] * 6.5 * s["t"]
		var r: float = 0.5 + 1.7 * s["t"]
		var o: Vector2 = s["tp"]
		s["tp"] = s["c"] + Vector2(cos(ang), sin(ang)) * r
		if zone.is_solid(s["tp"]):
			continue
		s["trail"] -= (s["tp"] as Vector2).distance_to(o)
		if s["trail"] <= 0.0:
			s["trail"] = 0.55
			add_cloud(s["tp"], 0.55, 2.2, s["dmg"] * 0.15)
		for m in foes(s["tp"], 0.45):
			var last := float(s["hitT"].get(m.get_instance_id(), -9.0))
			if time - last < 0.45:
				continue
			s["hitT"][m.get_instance_id()] = time
			hurt(m, s["dmg"], "shuriken")
			psn(m, s["dmg"] * 0.3, 3.0)
			if K("shurisplit") > 0:
				var o2 := near(m.tp, 5.0, func(q): return q != m)
				if o2:
					knife(m.tp, (o2.tp - m.tp).angle(), s["dmg"] * 0.5, 1)
	shuris = shuris.filter(func(s): return s["t"] < s["life"])

func _update_storm(dt: float) -> void:
	if mstorm_t <= 0.0:
		return
	mstorm_t -= dt
	mstorm_tick -= dt
	var R := storm_r()
	for i in 2:
		var a := randf() * TAU
		var rr := R * (0.3 + randf() * 0.7)
		motes.append({"tp": hero.tp + Vector2(cos(a), sin(a)) * rr, "z": randf_range(2, 16), "v": Vector2(-sin(a), cos(a)) * 4.0, "vz": 3.0, "t": 0.5, "col": VIOLET_D if randf() < 0.5 else VIOLET})
	if mstorm_tick > 0.0:
		return
	mstorm_tick = 0.35
	for m in foes(hero.tp, R):
		hurt(m, storm_dmg() * 0.35, "mstorm")
		psn(m, storm_dmg() * 0.25, 2.0)
		m.slow = maxf(m.slow, 0.35)
		if not m.boss:
			var dv: Vector2 = m.tp - hero.tp
			var d := dv.length()
			if d > 0.1:
				m.tp = zone.move(m.tp, Vector2(-dv.y, dv.x) / d * 0.3, m.radius * 0.6)
				if K("stormpull") > 0 and d > 1.0:
					m.tp = zone.move(m.tp, -dv / d * 0.3, m.radius * 0.6)

func _update_knives(dt: float) -> void:
	for k in knives:
		k["t"] -= dt
		k["tp"] += k["v"] * dt
		if zone.is_solid(k["tp"]):
			k["t"] = 0.0
			continue
		for m in foes(k["tp"], 0.2):
			if k["hit"].has(m.get_instance_id()):
				continue
			k["hit"][m.get_instance_id()] = true
			hurt(m, k["dmg"], "knife")
			psn(m, k["dmg"] * 0.5, 3.0)
			k["pierce"] -= 1
			if k["pierce"] <= 0:
				k["t"] = 0.0
				break
	knives = knives.filter(func(k): return k["t"] > 0.0)

func _update_scythes(dt: float) -> void:
	for s in scythes:
		s["spin"] += dt * 20.0
		if not s["back"]:
			var stp := 11.0 * dt
			s["tp"] += s["d"] * stp
			s["dist"] += stp
			if s["dist"] >= s["out"] or zone.is_solid(s["tp"]):
				s["back"] = true
				s["hit"].clear()
		else:
			var d: float = (s["tp"] as Vector2).distance_to(hero.tp)
			if d < 0.5:
				s["done"] = true
				continue
			s["tp"] += (hero.tp - s["tp"]) / d * minf(d, 13.0 * dt)
		for m in foes(s["tp"], 0.7):
			if s["hit"].has(m.get_instance_id()):
				continue
			s["hit"][m.get_instance_id()] = true
			hurt(m, crit(s["dmg"], true), "reap")
			_finisher_kill(m, s["n"])
	scythes = scythes.filter(func(s): return not s.get("done", false))

func _update_traps(dt: float) -> void:
	for th in throws:
		th["t"] += dt
		if th["t"] >= th["dur"] and not th.get("done", false):
			th["done"] = true
			_place_trap(th["kind"], th["to"], false, th["k"])
	throws = throws.filter(func(t): return not t.get("done", false))
	for t in traps:
		if t.get("done", false):
			continue
		t["t"] -= dt
		if t["t"] <= 0.0:
			t["done"] = true
			puff(t["tp"], Color8(111, 106, 121), 8)
			continue
		if t["arm"] > 0.0:
			t["arm"] -= dt
			continue
		match t["kind"]:
			"ntrap":
				t["cd"] -= dt
				if t["cd"] <= 0.0:
					var m := near(t["tp"], 5.5, func(q): return zone.sight_clear(t["tp"], q.tp))
					if m == null:
						t["cd"] = 0.2
					else:
						t["cd"] = 0.7
						var a: float = (m.tp - t["tp"]).angle()
						for k in (2 if aM("zd_needle") else 1):
							knife(t["tp"], a + (0.12 if k > 0 else 0.0), needle_dmg() * t["k"], (2 if aM("zm_fang") else 1) + (1 if K("needlepierce") > 0 else 0))
						t["charges"] -= 1
						if t["charges"] <= 0:
							t["done"] = true
						Sfx.play("glass", 0.15, 2.4)
				if K("sentryburst") > 0:
					t["burstT"] -= dt
					if t["burstT"] <= 0.0:
						t["burstT"] = 2.0
						for c in hero.get_tree().get_nodes_in_group("corpses"):
							if c.visible and not c.has_meta("k_burst") and c.tp.distance_to(t["tp"]) < 5.0:
								c.set_meta("k_burst", true)
								for o in foes(c.tp, 1.8):
									hurt(o, sentry_dmg() * 0.6 * t["k"], "ntrap")
									psn(o, sentry_dmg() * 0.12 * t["k"], 4.0)
								add_cloud(c.tp, 2.2, 6.0, sentry_dmg() * 0.12 * t["k"])
								puff(c.tp, VIOLET_D, 20, 3.0)
								c.modulate.a = 0.0
								break
			"mwake":
				t["leakT"] -= dt
				if t["leakT"] <= 0.0:
					t["leakT"] = 0.7
					var a2 := randf() * TAU
					add_cloud(t["tp"] + Vector2(cos(a2), sin(a2)) * randf() * 1.2, 0.8, 3.0, wake_dmg() * 0.12 * t["k"])
				t["waveT"] -= dt
				if t["waveT"] <= 0.0:
					var m2 := near(t["tp"], 5.5, func(q): return zone.sight_clear(t["tp"], q.tp))
					if m2 == null:
						t["waveT"] = 0.3
					else:
						t["waveT"] = 1.2
						var dv: Vector2 = (m2.tp - t["tp"]).normalized()
						tides.append({"tp": t["tp"] + dv * 0.3, "d": dv, "w": 2.4 if K("wakewide") > 0 else 1.6, "t": 1.0 if K("wakewide") > 0 else 0.75, "hit": {}, "dmg": wake_dmg() * t["k"], "trailT": 0.0, "trail": true, "wake": true})
			_:
				var m3 := near(t["tp"], 1.8)
				if m3 and m3.tp.distance_to(t["tp"]) < 1.4 + m3.radius:
					_trap_trigger(t)
	traps = traps.filter(func(t): return not t.get("done", false))

## Mirage and Siren Lure: fields that slow and bend missiles, charms that drag
func _update_fields(dt: float) -> void:
	for f in mirages:
		f["t"] -= dt
		for m in foes(f["tp"], f["R"]):
			m.slow = maxf(m.slow, 0.5)
			if aM("zd_mirage"):
				m.set_meta("k_frail", time + 0.3)
		for mi in hero.get_tree().get_nodes_in_group("missiles"):
			if mi.side != "hero" and not mi.has_meta("k_veered") and mi.tp.distance_to(f["tp"]) < f["R"]:
				mi.set_meta("k_veered", true)
				if K("miragewarp") > 0:
					mi.vel = -mi.vel
					mi.side = "hero"
				else:
					mi.vel = mi.vel.rotated((1.0 if randf() < 0.5 else -1.0) * randf_range(0.7, 1.4))
	mirages = mirages.filter(func(f): return f["t"] > 0.0)
	for l in lures:
		l["t"] -= dt
		for m in foes(l["tp"], l["R"]):
			if m.boss:
				continue
			var d: float = m.tp.distance_to(l["tp"])
			if d > 0.4:
				m.tp = zone.move(m.tp, (l["tp"] - m.tp) / d * minf(d, 2.5 * dt), m.radius * 0.6)
				if aM("zd_lure"):
					confuse(m, 1.0)
	lures = lures.filter(func(l): return l["t"] > 0.0)

# ------------------------------------------------------------------ the Mirror-Sister
func _update_sister(dt: float) -> void:
	if K("sister") <= 0 or hero.dead:
		if sister != null and is_instance_valid(sister):
			sister.queue_free()
		sister = null
		return
	if sister == null or not is_instance_valid(sister):
		sister = Ally.new()
		sister.book = self
		sister.kind = "sister"
		sister.tp = hero.tp + Vector2(-1.2, 0.4)
		sister.max_hp = hero.st.life_max() * (0.35 + 0.02 * (K("sister") - 1))
		sister.hp = sister.max_hp
		sister.cd = 1.5
		zone.sorted.add_child(sister)
		puff(sister.tp, WARP, 18, 2.0)

## she casts one of your skills, from where she stands, at her strength
func sister_cast_now(id: String, at: Vector2, foe) -> void:
	var keep_tp := hero.tp
	var keep_face := hero.face
	var keep_view := hero.view
	var keep_om := omens
	var keep_anim := cast_anim
	var keep_len := cast_len
	hero.tp = sister.tp
	sister_cast = true
	omens = 0
	_cast(id, at, foe)
	sister_cast = false
	sister.tp = hero.tp
	hero.tp = keep_tp
	hero.face = keep_face
	hero.view = keep_view
	omens = keep_om
	cast_anim = keep_anim
	cast_len = keep_len
	if K("sisterhex") > 0 and foe != null and is_instance_valid(foe) and not foe.dead:
		confuse(foe, 1.0)
	puff(sister.tp, WARP, 6, 1.2)

func _enter_zone() -> void:
	zone = hero.zone
	for arr in [clouds, novas, tides, traps, throws, mirages, lures, scythes, shuris, clawfx, knives, zaps, motes, words, rings]:
		arr.clear()
	for d in decoys:
		if is_instance_valid(d):
			d.queue_free()
	decoys.clear()
	if sister != null and is_instance_valid(sister):
		sister.queue_free()
	sister = null
	dash = {}
	pending = {}
	queue.clear()
	fx_air = null
	fx_floor = null

func _views() -> void:
	if zone == null:
		return
	if fx_floor == null or not is_instance_valid(fx_floor):
		fx_floor = FxNode.new()
		fx_floor.book = self
		fx_floor.floor_mode = true
		zone.floor_layer.add_child(fx_floor)
	if fx_air == null or not is_instance_valid(fx_air):
		fx_air = FxNode.new()
		fx_air.book = self
		fx_air.z_index = 40
		zone.add_child(fx_air)

func _autocast(dt: float) -> void:
	auto_t -= dt
	if auto_t > 0.0 or hero.dead:
		return
	auto_t = 1.0
	var ids: Array = auto_ids if not auto_ids.is_empty() else hard.keys()
	ids = ids.filter(func(i): return lvl(i) > 0 and not is_passive(i))
	if ids.is_empty():
		return
	var m := near(hero.tp, 9.0)
	if m == null:
		return
	auto_i = (auto_i + 1) % ids.size()
	var id: String = ids[auto_i]
	demo_at = m.tp
	cast_anim = "cast"
	cast_len = -1.0
	var ok := hero.act == "" and use(id, m.tp, m)
	if ok:
		hero._start_act(cast_anim, cast_len)
	demo_at = null
