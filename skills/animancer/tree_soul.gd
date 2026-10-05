extends "res://skills/animancer/tree_mirror.gd"
## The Hollow Mystic, part 3 of 5: the Soul tree. The choir of wisps (seeking, striking, the four chances), Cull,
## Condense's great wisp, sparks and needles, seeking souls.

# ------------------------------------------------------------------ Soul tree
func _cast_cull(a: Vector2) -> bool:
	var foes: Array = mons().filter(func(m): return m.tp.distance_to(a) < 3.5 and m.tp.distance_to(hero.tp) < 11.0 and zone.sight_clear(hero.tp, m.tp))
	if foes.is_empty():
		say("Nothing near to cull.", 1.0)
		return false
	var revs: Array = wisps.filter(func(w): return w.state == "drift")
	if revs.is_empty():
		say("No wisp drifts free.", 1.0)
		return false
	if not spend("cull"):
		return false
	revs = revs.filter(func(w): return not w.gone)
	var i := 0
	for w in revs:
		w.state = "dive"
		w.target = foes[i % foes.size()]
		w.cull_t = 2.4 if K("cullreturn") > 0 else 1.4
		w.cull_pool = foes
		w.hit_t = {}
		i += 1
	return true

func _infuse_one() -> void:
	var g = golem
	if g == null:
		infusing = false
		return
	if hero.tp.distance_to(g.tp) > 8.0:
		say("Too far from your golem.", 1.0)
		return
	if g.ramp > 0.0:
		say("Your golem already burns.", 0.8)
		return
	# with no wisp to give he gives his own breath of Essence: half as much (never refused)
	var gave := 1.0
	if take_wisp() == null:
		gave = 0.5 if hero.st.res >= 3.0 else 0.2
		hero.st.res = maxf(0.0, hero.st.res - 3.0)
	if g.state == "dormant":
		g.boost = minf(1.0 + minf(0.5, 0.025 * K("overcharge")), g.boost + (0.12 + 0.004 * K("wisps")) * gave)
	else:
		g.infused += 1
		if g.hp < g.max_hp - 0.5:
			g.hp = minf(g.max_hp, g.hp + (g.max_hp * 0.07 + 4.0 * K("wisps")) * gave)
		g.add_charge(gave)

func _condense_one() -> void:
	if wisps.is_empty():
		return
	if great == null:
		great = Wisp.new()
		great.tp = hero.tp
		great.z = 26.0
		great.state = "form"
		great.pulse = 0.8
	if great.state == "hunt":
		great.state = "form"
	if great.size >= ws_cond_max():
		say("The great wisp can hold no more.", 0.8)
		return
	if not spend("condense"):
		return
	take_wisp()
	great.size += 1


# ------------------------------------------------------------------ the choir
func _update_wisps(dt: float) -> void:
	var cap := eff_cap()
	while wisps.size() > cap:
		var w: Wisp = wisps.pop_back()
		w.gone = true
	if wisps.size() < cap and not condensing and not infusing:
		wisp_t += dt
		if wisp_t >= ws_wisp_regen():
			wisp_t = 0.0
			spawn_wisp()
	elif wisps.size() >= cap:
		wisp_t = 0.0
	for w in wisps.duplicate():
		if not w.gone:
			_rev(w, dt)

func _drift(w: Wisp, dt: float, calm: bool) -> void:
	w.wt += dt
	w.ang += dt * (0.5 + 0.5 * sin(w.wt * 0.6 + w.rad)) * (0.5 if calm else 1.0)
	var spread: float = 0.6 + 0.2 * wbeh["x"]
	w.rad = clampf(w.rad + (randf() - 0.5) * dt * 2.2, 0.5, 2.3 * spread)
	var tgt: Vector2 = hero.tp + Vector2(cos(w.ang) * w.rad + sin(w.wt * 1.3) * 0.35, sin(w.ang) * w.rad + cos(w.wt * 1.1) * 0.35)
	var k := 3.0 if calm else 6.0
	w.v += ((tgt - w.tp) * k - w.v * 2.6) * dt
	w.tp += w.v * dt
	w.z += (13.0 + sin(w.wt * 2.3) * 3.0 - w.z) * minf(1.0, dt * 4.0)

func _wisp_focus(maxd: float) -> Variant:
	var t = last_hit
	if wbeh["focus"] and t != null and is_instance_valid(t) and not t.dead and not t.buried and t.tp.distance_to(hero.tp) < maxd + 1.5 and zone.sight_clear(hero.tp, t.tp):
		return t
	return null


func _wisp_target(w: Wisp, maxd: float, is_great: bool = false) -> Variant:
	if not is_great:
		maxd = wisp_range(maxd)
		var f = _wisp_focus(maxd)
		if f != null:
			return f
	var best: Array = []
	for m in mons():
		if absf(m.tp.x - hero.tp.x) > maxd or absf(m.tp.y - hero.tp.y) > maxd:
			continue
		var d: float = m.tp.distance_to(hero.tp)
		if is_idle(m) and d > 5.0:
			continue
		if not is_great and not _wisp_allowed(m):
			continue
		if d > maxd or not zone.sight_clear(hero.tp, m.tp):
			continue
		best.append([d + m.tp.distance_to(w.tp) * 0.4, m])
	if best.is_empty():
		return null
	best.sort_custom(func(p, q): return p[0] < q[0])
	return best[randi() % mini(3, best.size())][1]

func _perish(w: Wisp) -> void:
	wisps.erase(w)
	w.gone = true
	glass_burst(w.tp, 2, 1.2, w.z)
	_wisp_lost()
	if aM("w_wake"):
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.02)
	if aM("a_revenant") and wisps.size() < eff_cap():
		spawn_wisp(w.tp)
		if not wisps.is_empty():
			var nw: Wisp = wisps[wisps.size() - 1]
			nw.armor_t = 5.0
			nw.scale = 1.15
	if K("burst") > 0:
		var r := ws_burst_r()
		var dmg := ws_burst_dmg()
		for m in mons():
			if m.tp.distance_to(w.tp) < r:
				hurt(m, dmg, "restless", {"from": w.tp})
		ring(w.tp, r, 0.35, 0.2)

## a standing mirror, the golem and its shield: what the wisps and darts rebound from (d_play.js metals)
func metals() -> Array:
	var out: Array = []
	if golem != null and golem.state != "dormant":
		out.append({"key": golem, "tp": golem.tp, "r": golem.r, "cracked": false, "hall": false, "z": 20.0})
		if not golem.fly.is_empty():
			out.append({"key": "shield", "tp": golem.fly["tp"], "r": 0.42, "cracked": false, "hall": false, "z": 14.0})
	for o in mirrors:
		if o.standing():
			out.append({"key": o, "tp": o.tp, "r": o.r, "cracked": o.cracked or o.kind == "great", "hall": o.hall, "z": 22.0 if o.kind == "great" else 18.0})
	return out

func _metal(key) -> Variant:
	for mt in metals():
		var k2 = mt["key"]
		if typeof(k2) == typeof(key) and k2 == key:
			return mt
	return null

func _next_foe(from: Vector2, hit: Dictionary, R: float) -> Variant:
	var best = null
	var bd := R
	for m in mons():
		if hit.has(m.get_instance_id()):
			continue
		var d: float = m.tp.distance_to(from)
		if d < bd and zone.sight_clear(from, m.tp):
			bd = d
			best = m
	return best

func _near_mirror(from: Vector2, used: Dictionary, R: float) -> Variant:
	var best = null
	var bd := R
	for mt in metals():
		if used.has(mt["key"]):
			continue
		var d: float = mt["tp"].distance_to(from)
		if d < bd and d > 0.2 and zone.sight_clear(from, mt["tp"]) and _next_foe(mt["tp"], {}, 6.5) != null:
			bd = d
			best = mt
	return best

## the Mirror tree promises that the choir rebounds off mirrors renewed (the v90 choir lost it with the lantern
## wisps): after a strike, a wisp near a standing mirror flies to it, rebounds x1.25 (Resonance more) with more
## strikes left in it (a leap, two with Resonance, one more off the Hall), up to 3 rebounds (4+ with Resonance) a sortie.
func _maybe_mirror(w: Wisp) -> void:
	if not CHOIR_REBOUND or w.bounces >= ws_max_bounce():
		return
	var mt = _near_mirror(w.tp, w.used, 3.0)
	if mt != null:
		w.state = "mirror"
		w.mirror = mt["key"]

func _rebound(w: Wisp, mt: Dictionary) -> void:
	w.used[mt["key"]] = true
	w.bounces += 1
	w.mult = maxf(1.0, w.mult) * ws_bounce_mult()
	w.hits -= 1 + (1 if K("resonance") > 0 else 0) + (1 if mt["hall"] else 0)
	if mt["cracked"]:
		_spark_split(w.tp, {}, 2, ws_rev_dmg() * 0.6)
		glass_burst(mt["tp"], 3, 1.2, mt["z"])
	var n = _next_foe(mt["tp"], {}, 6.5)
	if n != null:
		w.state = "dive"
		w.target = n
		w.dir = (n.tp - w.tp).normalized()
	else:
		w.state = "drift"
		w.cd = 0.2

func _rev(w: Wisp, dt: float) -> void:
	if w.armor_t > 0.0:
		w.armor_t -= dt
		if w.armor_t <= 0.0:
			w.scale = 1.0
			w.hits = 0
	if proc["on"]:
		_proc_wisp(w, dt)
		return
	var spd := ws_fly_spd()
	if w.state == "drift" or w.state == "proc":
		if w.state == "proc":
			w.state = "drift"
		_drift(w, dt, false)
		w.cd -= dt
		w.bounces = 0
		w.used = {}
		w.mult = 1.0
		w.split_done = false
		if w.cd <= 0.0:
			var t = _wisp_target(w, 4.6)
			if t != null:
				w.state = "dive"
				w.target = t
			else:
				w.cd = 0.25
		return
	if w.cull_t > 0.0:
		w.cull_t -= dt
		if w.cull_t <= 0.0:
			w.state = "drift"
			w.cd = 0.4
			w.cull_pool = []
			return
	if w.state == "mirror":
		var mt = _metal(w.mirror)
		if mt == null:
			w.state = "over"
			w.over = 0.0
		else:
			var dv: Vector2 = mt["tp"] - w.tp
			w.dir = dv.normalized() if dv.length() > 0.001 else w.dir
			if dv.length() < mt["r"] + 0.25:
				_rebound(w, mt)
	if w.state == "dive":
		var t = w.target
		if t == null or not is_instance_valid(t) or t.dead or t.buried:
			var n = _wisp_target(w, 5.0)
			if n != null:
				w.target = n
			else:
				w.state = "drift"
				w.cd = 0.2
				return
		var dv2: Vector2 = w.target.tp - w.tp
		var l := dv2.length()
		if l > 0.001:
			w.dir = dv2 / l
		if l < 0.3:
			w.state = "over"
			w.over = 0.22 + randf() * 0.15
	elif w.state == "over":
		w.over -= dt
		if w.over <= 0.0:
			var n2 = null
			if w.cull_t > 0.0:
				var cp: Array = w.cull_pool.filter(func(q): return is_instance_valid(q) and not q.dead and not q.buried)
				if not cp.is_empty():
					n2 = cp[randi() % cp.size()]
			if n2 == null:
				n2 = _wisp_target(w, 5.2)
			if n2 != null:
				w.state = "dive"
				w.target = n2
				_maybe_mirror(w)
			else:
				w.state = "drift"
				w.cd = 0.15
	w.v = w.dir * spd
	w.tp += w.v * dt
	w.z += (9.0 - w.z) * minf(1.0, dt * 8.0)
	# cracked mirror-glass fissures a wisp that crosses it into sparks
	if CHOIR_REBOUND and not w.split_done:
		for c in cracks:
			if c["tp"].distance_to(w.tp) < 0.45:
				w.split_done = true
				_spark_split(w.tp, {}, 2, ws_rev_dmg() * 0.6)
				break
	for m in mons():
		if absf(m.tp.x - w.tp.x) > 1.0 or absf(m.tp.y - w.tp.y) > 1.0:
			continue
		if m.tp.distance_to(w.tp) > m.radius + 0.22:
			continue
		var key: int = m.get_instance_id()
		if time - float(w.hit_t.get(key, -9.0)) < 0.45:
			continue
		w.hit_t[key] = time
		var dmg := ws_rev_dmg() * w.mult
		w.mult = 1.0
		hurt(m, dmg, "wisps", {"from": w.tp})
		var lp := ws_leech()
		if lp > 0.0:
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dmg * lp)
			hero.st.res = minf(hero.st.res_max(), hero.st.res + dmg * lp)
		_chances(w, m, true)
		if aR("a_choir") and not m.boss and not m.dead:
			m.confused = maxf(m.confused, 3.0)   # held: it turns on its own kind
		if w.cull_t > 0.0:
			if K("cullmark") > 0:
				m.set_meta("mys_cull", time + 4.0)
		else:
			w.hits += 1
		if w.hits >= ws_hits() and w.armor_t <= 0.0:
			_perish(w)
			return
	if w.tp.distance_to(hero.tp) > (12.0 if w.cull_t > 0.0 else 7.5):
		w.state = "drift"
		w.cd = 0.3
		w.cull_t = 0.0

## the one choir (v90): chances rolled on each wisp strike
func _chances(w: Wisp, m, with_pass: bool) -> void:
	if with_pass and randf() < ch_pass():
		w.hits -= 1
	if not m.dead and randf() < ch_thread():
		m.slow = maxf(m.slow, 0.6)
		m.add_poise_damage(10.0 * 1.2, false)
		snags.append({"w": w, "m": m, "tp": w.tp, "t": 0.0, "dur": 0.5})
	if randf() < ch_needle():
		_needle(w, m)
	if randf() < ch_split():
		_spark_split(m.tp, {m.get_instance_id(): true}, spark_n(), spark_dmg())

func _needle(w: Wisp, m) -> void:
	var d: Vector2 = w.dir if w.dir.length() > 0.01 else (m.tp - hero.tp).normalized()
	var len := needle_len()
	var end := len
	var s := 0.25
	while s < len:
		if zone.blocks_sight(m.tp + d * s):
			end = s
			break
		s += 0.25
	var dmg := needle_dmg()
	for o in mons():
		if o == m:
			continue
		var p: Vector2 = o.tp - m.tp
		var t := p.dot(d)
		if t < 0.0 or t > end or absf(p.x * d.y - p.y * d.x) > o.radius + 0.2:
			continue
		hurt(o, dmg, "beam", {"from": m.tp})
		if K("beamburn") > 0 and not o.dead:
			o.add_dot(dmg * 0.5, 2.0, "fire")
	if K("beamburn") > 0 and not m.dead:
		m.add_dot(dmg * 0.5, 2.0, "fire")
	needles.append({"tp": m.tp, "d": d, "end": end, "t": 0.0, "dur": 0.05 + end * 0.035})

func _spark_split(from: Vector2, skip: Dictionary, n: int, dmg: float) -> void:
	var near: Array = mons().filter(func(o): return not skip.has(o.get_instance_id()) and o.tp.distance_to(from) < 4.5)
	near.sort_custom(func(p, q): return p.tp.distance_to(from) < q.tp.distance_to(from))
	for i in mini(n, near.size()):
		sparks.append({"tp": from, "z": 9.0, "tgt": near[i], "dmg": dmg, "t": 0.0})

## Procession: the choir walks a slow ring about the cursor and strikes what is inside it
func _proc_wisp(w: Wisp, dt: float) -> void:
	var n := maxi(1, wisps.size())
	var i := wisps.find(w)
	var R := proc_r()
	var ang: float = float(i) / n * TAU + float(proc["t"]) * 1.1
	var tgt: Vector2 = proc["tp"] + Vector2(cos(ang), sin(ang)) * R
	var dv := tgt - w.tp
	var d := maxf(dv.length(), 0.0001)
	var st := minf(d, ws_fly_spd() * 1.15 * dt)
	w.dir = dv / d
	w.tp += w.dir * st
	w.z += (9.0 - w.z) * minf(1.0, dt * 6.0)
	w.state = "proc"
	w.p_t -= dt
	if w.p_t > 0.0:
		return
	var best = null
	var bd := 1.6
	for m in mons():
		if m.tp.distance_to(proc["tp"]) > R + m.radius:
			continue
		var dm2: float = m.tp.distance_to(w.tp)
		if dm2 < bd:
			bd = dm2
			best = m
	if best == null:
		w.p_t = 0.15
		return
	w.p_t = 0.45
	hurt(best, ws_rev_dmg() * 0.6, "proc", {"from": w.tp})
	if K("procslow") > 0:
		best.slow = maxf(best.slow, 0.45)
	if not best.dead:
		_chances(w, best, false)

# ------------------------------------------------------------------ the great wisp (Condense)
func _update_great(dt: float) -> void:
	var gw := great
	if gw == null:
		return
	gw.wt += dt
	gw.scale = minf(3.5, 1.0 + 0.12 * gw.size)
	if gw.state == "form":
		var tgt := hero.tp - Vector2(0.35, 0.35)
		gw.v += ((tgt - gw.tp) * 8.0 - gw.v * 4.0) * dt
		gw.tp += gw.v * dt
		gw.z += (26.0 + gw.size * 0.4 - gw.z) * minf(1.0, dt * 4.0)
		if not condensing:
			if gw.size <= 0:
				gw.gone = true
				great = null
				return
			gw.state = "hunt"
			gw.life = ws_cond_life() + 0.15 * gw.size
			gw.hit_t = {}
			gw.target = null
		return
	gw.life -= dt
	var spd := 5.5
	var R := 0.3 + 0.035 * gw.size
	if gw.over > 0.0:
		gw.over -= dt
		if gw.over <= 0.0:
			gw.target = _wisp_target(gw, 7.5, true)
	else:
		if gw.target == null or not is_instance_valid(gw.target) or gw.target.dead or gw.target.buried:
			gw.target = _wisp_target(gw, 7.5, true)
		if gw.target != null:
			var dv: Vector2 = gw.target.tp - gw.tp
			if dv.length() > 0.001:
				gw.dir = dv.normalized()
			if dv.length() < 0.3:
				gw.over = 0.35
	if gw.target != null or gw.over > 0.0:
		gw.tp += gw.dir * spd * dt
	else:
		var t2 := hero.tp + Vector2(cos(gw.wt), sin(gw.wt)) * 1.2
		gw.tp += (t2 - gw.tp) * minf(1.0, dt * 3.0)
	gw.z += (14.0 + gw.size * 0.3 - gw.z) * minf(1.0, dt * 5.0)
	var dmg := ws_cond_dmg() * (1.0 + 0.35 * gw.size)
	if gw.target != null and is_instance_valid(gw.target):
		last_hit = gw.target
	for m in mons():
		if m.tp.distance_to(gw.tp) > m.radius + R:
			continue
		var key: int = m.get_instance_id()
		if time - float(gw.hit_t.get(key, -9.0)) < 0.5:
			continue
		gw.hit_t[key] = time
		hurt(m, dmg, "condense", {"from": gw.tp})
	if K("radiance") > 0:
		gw.pulse -= dt
		if gw.pulse <= 0.0:
			gw.pulse = 0.8
			var r := 1.2 + 0.05 * gw.size
			var pd := ws_rad_dmg() * (1.0 + 0.15 * gw.size)
			for m in mons():
				if m.tp.distance_to(gw.tp) < r:
					hurt(m, pd, "condense", {"from": gw.tp})
	if gw.tp.distance_to(hero.tp) > 11.0:
		gw.tp += (hero.tp - gw.tp) * 0.5
	if gw.life <= 0.0:
		if K("nova") > 0:
			var r2 := 1.5 + 0.08 * gw.size
			var nd := ws_nova_dmg() * (1.0 + 0.25 * gw.size)
			for m in mons():
				if m.tp.distance_to(gw.tp) < r2:
					hurt(m, nd, "condense", {"from": gw.tp})
			ring(gw.tp, r2, 0.5, 0.2)
		glass_burst(gw.tp, 6, 2.0, gw.z)
		gw.gone = true
		great = null

# ------------------------------------------------------------------ sparks, needles, snags, rings, glass, fires
func _update_fx(dt: float) -> void:
	for s in sparks:
		s["t"] += dt
		var g = s["tgt"]
		if g == null or not is_instance_valid(g) or g.dead or g.buried:
			s["t"] = 9.0
			continue
		var dv: Vector2 = g.tp - s["tp"]
		var d := maxf(dv.length(), 0.001)
		var tr: Array = s.get_or_add("trail", [])   # the last three places it was (zz_zz_mystic90.js:127)
		tr.append(s["tp"])
		if tr.size() > 3:
			tr.pop_front()
		s["tp"] += dv / d * minf(d, 11.0 * dt)
		if d < 0.3:
			hurt(g, s["dmg"], "prism", {"from": s["tp"]})
			s["t"] = 9.0
	sparks = sparks.filter(func(s): return s["t"] < 1.0)
	for n in needles:
		n["t"] += dt
	needles = needles.filter(func(n): return n["t"] < n["dur"])
	for s in snags:
		s["t"] += dt
		if not s["w"].gone:
			s["tp"] = s["w"].tp
	snags = snags.filter(func(s): return s["t"] < s["dur"] and is_instance_valid(s["m"]) and not s["m"].dead)
	for r in rings:
		r["t"] -= dt
	rings = rings.filter(func(r): return r["t"] > 0.0)
	for g in glass:
		g["t"] -= dt
		g["vz"] -= 70.0 * dt
		g["z"] += g["vz"] * dt
		g["tp"] += g["v"] * dt
		if g["z"] <= 0.0:
			g["z"] = 0.0
			g["vz"] = -g["vz"] * 0.3 if absf(g["vz"]) > 8.0 else 0.0
			g["v"] *= 0.4
	glass = glass.filter(func(g): return g["t"] > 0.0)
	for gs in gshots:
		gs["t"] -= dt
		gs["tp"] += gs["v"] * dt
		if zone.is_solid(gs["tp"]):
			gs["t"] = 0.0
			continue
		for m in mons():
			var k: int = m.get_instance_id()
			if gs["hit"].has(k) or m.tp.distance_to(gs["tp"]) > m.radius + 0.15:
				continue
			gs["hit"][k] = true
			hurt(m, gs["dmg"], gs["id"], {"from": gs["tp"]})
	gshots = gshots.filter(func(g): return g["t"] > 0.0)
	for f in fires:
		f["t"] -= dt
		f["tick"] -= dt
		if f["tick"] <= 0.0:
			f["tick"] = 0.5
			for m in mons():
				if m.tp.distance_to(f["tp"]) < f["R"] + m.radius:
					hurt(m, f["dps"] * 0.5, "overcharge", {"from": f["tp"], "golem": true})
	fires = fires.filter(func(f): return f["t"] > 0.0)
	for dl in dart_lines:
		dl["t"] -= dt
	dart_lines = dart_lines.filter(func(d): return d["t"] > 0.0)
	for tb in totem_beams:
		tb["t"] -= dt
	totem_beams = totem_beams.filter(func(t): return t["t"] > 0.0)

# ------------------------------------------------------------------ seeking souls (d_play.js updateProjectiles)
func _update_souls(dt: float) -> void:
	for s in souls:
		s["t"] -= dt
		s["retarget"] -= dt
		s["wob"] += dt * 9.0
		var tg = s["target"]
		if tg == null or not is_instance_valid(tg) or tg.dead or tg.buried or s["retarget"] <= 0.0:
			var opts: Array = mons().filter(func(m): return m.tp.distance_to(s["tp"]) < 6.5)
			var fresh: Array = opts.filter(func(m): return not s["hit"].has(m.get_instance_id()))
			s["target"] = fresh[randi() % fresh.size()] if not fresh.is_empty() else (opts[randi() % opts.size()] if not opts.is_empty() else null)
			s["retarget"] = 0.5
			tg = s["target"]
		if tg != null:
			var dv: Vector2 = (tg.tp - s["tp"]).normalized()
			s["v"] += (dv * 9.0 - s["v"]) * minf(1.0, dt * 5.0)
		var n: Vector2 = s["tp"] + (s["v"] + Vector2(cos(s["wob"]), sin(s["wob"])) * 1.2) * dt
		if zone.blocks_sight(n):
			s["t"] = 0.0
			continue
		s["tp"] = n
		for m in mons():
			var k: int = m.get_instance_id()
			if s["hit"].has(k) or absf(m.tp.x - n.x) > 1.0 or absf(m.tp.y - n.y) > 1.0:
				continue
			if m.tp.distance_to(n) < m.radius + 0.15:
				var got := hurt(m, s["dmg"], "swarm", {"from": n})
				if aM("a_hunger"):
					hero.st.hp = minf(hero.st.life_max(), hero.st.hp + got * 0.05)
				if s.get("storm", false) and aU("a_pyre") and not m.dead:
					m.add_dot(s["dmg"] * 0.4, 3.0, "fire")
				if aU("a_sage") and not s.get("jumped", false) and s["hits"] <= 1:
					for jj in 2:
						var js := new_soul(m.tp, randf() * TAU, 6.0, s["dmg"] * 0.6, 1)
						js["jumped"] = true
						js["hit"][k] = true
				last_hit = m
				s["hits"] -= 1
				s["hit"][k] = true
				if s["hits"] <= 0:
					s["t"] = 0.0
					break
				s["target"] = null
				s["retarget"] = 0.0
	souls = souls.filter(func(s): return s["t"] > 0.0)
	if souls.size() > 300:
		souls = souls.slice(souls.size() - 300)
