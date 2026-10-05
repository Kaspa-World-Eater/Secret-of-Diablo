extends "res://skills/animancer/base.gd"
## The Hollow Mystic, part 2 of 5: the Mirror tree. Standing Mirrors, Mirror Fissure, Hall of Mirrors, Falling Mirror,
## the Iron Golem's casts, and mirrors as cover. Chain: base -> tree_mirror -> tree_soul -> tree_thread -> skills/animancer.gd.

# ------------------------------------------------------------------ Mirror tree
func _raise_pane(p: Vector2, life: float, dmg: float, hall: bool = false, cracked: bool = false) -> bool:
	if zone.is_solid(p) or p.distance_to(hero.tp) < hero.radius + 0.3:
		return false
	var o := Mirror.new()
	o.kind = "pane"
	o.tp = p
	o.life = life
	o.max_life = life
	o.dmg = dmg
	o.hall = hall
	o.cracked = cracked
	o.hp = 40.0 + 5.0 * (maxi(1, K("pillars")) - 1)
	o.seed = randi()
	mirrors.append(o)
	var panes := mirrors.filter(func(x): return x.kind == "pane" and not x.gone)
	while panes.size() > 18:
		panes[0].gone = true
		panes.pop_front()
	mirrors = mirrors.filter(func(x): return not x.gone)
	return true

func _cast_pillars(a: Vector2) -> bool:
	if not spend("pillars"):
		return false
	var t := clamp_cast(a, 8.0)
	var d := maxf(0.001, t.distance_to(hero.tp))
	var perp := Vector2(-(t.y - hero.tp.y) / d, (t.x - hero.tp.x) / d)
	var n := ws_pillar_n()
	var life := ws_pillar_life()
	var dmg := ws_pillar_dmg()
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.8
		_raise_pane(t + perp * off, life, dmg)
	return true

func _cast_cage(a: Vector2) -> bool:
	if not spend("cage"):
		return false
	if aR("a_maiden"):
		a = hero.tp   # the hall closes on you
		maiden_t = ws_cage_life()
	elif aU("a_maiden"):
		for m in mons():
			var dm2: float = m.tp.distance_to(a)
			if dm2 < 3.0 + 1.8 and dm2 > 1.2 and not m.boss:
				shove(m, (a - m.tp) / dm2 * (dm2 - 1.0))
	var n := ws_cage_n()
	var life := ws_cage_life()
	var dmg := ws_cage_dmg()
	for i in n:
		var ang := float(i) / n * TAU
		_raise_pane(a + Vector2(cos(ang), sin(ang)) * 1.8, life, dmg, true)
	cages.append({"tp": a, "t": life, "tick": 1.0})
	return true

func _cast_fissure(a: Vector2) -> bool:
	if not spend("fissure"):
		return false
	var d := (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.01 else Vector2(1, 1).normalized()
	var L := ws_fissure_len()
	fissures.append({"tp": hero.tp, "d": d, "i": 0, "n": int(round(L / 0.6)), "t": 0.0, "keep": ws_fissure_keep() + (1 if aM("i_spikes") else 0), "hit": {}})
	return true

func _cast_anvil(a: Vector2) -> bool:
	if not spend("anvil"):
		return false
	var p := clamp_cast(a, 9.0)
	_drop_anvil(p, 1.0, 0.0)
	if K("anvilrain") > 0:
		for i in 2:
			var ang := randf() * TAU
			_drop_anvil(clamp_cast(p + Vector2(cos(ang), sin(ang)) * 1.7, 11.0), 0.7, 0.2 + i * 0.2)
	return true

func _drop_anvil(p: Vector2, k: float, delay: float) -> void:
	if zone.is_solid(p):
		return
	var o := Mirror.new()
	o.kind = "great"
	o.tp = p
	o.r = 0.42
	o.fall = 0.5 + delay
	o.fall_max = 0.5
	o.life = 16.0 if K("anvilstay") > 0 else 8.0
	o.max_life = o.life
	o.dmg = ws_anvil_dmg() * k
	o.hp = 1e9
	o.seed = randi()
	mirrors.append(o)
	var gr := mirrors.filter(func(x): return x.kind == "great" and not x.gone)
	while gr.size() > 8:
		gr[0].gone = true
		gr.pop_front()

func _cast_golem(a: Vector2) -> bool:
	if aR("a_anvil"):
		# The Anvil reversed: the golem is worn, not called
		if shell > 0.0:
			say("You already wear the iron.", 1.0)
			return false
		if not spend("golem"):
			return false
		if golem != null:
			golem.node = null
			golem = null
		shell = float(ws_golem()["max"])
		dust(hero.tp, 14, 2.0)
		say("The iron closes round you.", 1.4)
		return true
	if golem != null:
		if golem.tp.distance_to(a) < 1.3:
			# banish: the same golem comes back when called again, its wounds and its sleep kept
			golem_mem = {"frac": golem.hp / maxf(1.0, golem.max_hp), "dormant": golem.state == "dormant", "rt": golem.rt,
				"rt_max": golem.rt_max, "down_t": golem.down_t, "boost": golem.boost, "at": time}
			golem.node = null
			golem = null
			infusing = false
			say("The golem is sent away.", 1.6)
			return true
		return _command_golem(a)
	if not spend("golem"):
		return false
	var t := clamp_cast(a, 6.0)
	var p := walkable_near(Vector2(floor(t.x) + 0.5, floor(t.y) + 0.5))
	golem = GolemL.new(self, p)
	if not golem_mem.is_empty():
		var M := golem_mem
		golem_mem = {}
		var el: float = time - M["at"]
		golem.hp = maxf(1.0, minf(golem.max_hp, golem.max_hp * (M["frac"] + 0.01 * el)))
		if M["dormant"]:
			var left: float = maxf(0.0, M["rt"] - el)
			var dl: float = M["down_t"] + el
			if left > 0.0 or dl < GolemL.MIN_DOWN:
				golem.go_down(maxf(left, 0.1), "Your golem is still dormant.")
				golem.rt_max = M["rt_max"]
				golem.down_t = dl
				golem.boost = M["boost"]
				golem.hp = 0.0
	if gbeh["hold"]:
		golem.hold = golem.tp
	dust(golem.tp, 12, 2.0)
	return true

func _command_golem(a: Vector2) -> bool:
	if golem.state == "dormant":
		say("Your golem is dormant.", 1.0)
		return false
	var p := walkable_near(Vector2(floor(a.x) + 0.5, floor(a.y) + 0.5))
	golem.order = {"tp": p, "t": 7.0}
	golem.atk = {}
	golem.path = PackedVector2Array()
	if golem.state == "charge" or golem.state == "chargeWind":
		golem.state = "active"
	if gbeh["hold"]:
		golem.hold = p
	ring(p, 0.25, 0.5, 0.9)
	return true


# ------------------------------------------------------------------ mirrors: rise, stand, break; the great mirror falls
func _update_mirrors(dt: float) -> void:
	for o in mirrors:
		if o.gone:
			continue
		if o.kind == "pane":
			if o.rise > 0.0:
				o.rise -= dt
				if o.rise <= 0.0 and o.fresh:
					o.fresh = false
					glass_burst(o.tp, 4, 1.5, 12.0)
					for m in mons():
						var dd: float = m.tp.distance_to(o.tp)
						if dd > 0.9 + m.radius:
							continue
						if o.dmg > 0.0:
							hurt(m, o.dmg, "pillars", {"from": o.tp})
							m.stun = maxf(m.stun, 1.0 if aM("i_quake") else 0.5)
						if dd < o.r + m.radius:
							shove(m, ((m.tp - o.tp).normalized() if dd > 0.001 else Vector2.RIGHT) * (o.r + m.radius - dd + 0.05))
			else:
				o.life -= dt
		elif o.kind == "great":
			if o.fall > 0.0:
				o.fall -= dt
				if o.fall <= 0.0 and o.fresh:
					o.fresh = false
					o.cracked = true
					glass_burst(o.tp, 30, 4.0, 22.0)
					if Settings.screen_shake:
						Game.hitstop(0.06)
					for m in mons():
						var d: float = m.tp.distance_to(o.tp)
						if d > 1.25 + m.radius:
							continue
						hurt(m, o.dmg, "anvil", {"from": o.tp, "heavy": true})
						m.stun = maxf(m.stun, 0.4 if m.boss else 1.2)
						if d < o.r + m.radius:
							shove(m, ((m.tp - o.tp).normalized() if d > 0.001 else Vector2.RIGHT) * (o.r + m.radius - d + 0.05))
					if aU("a_anvil"):
						_splinter_ring(o.tp, 1.4, 7)
					var q := K("anvilquake") > 0
					var n := 16 if q else 8
					var k := 0.4 if q else 0.22
					for i in n:
						var ang := float(i) / n * TAU + 0.2
						var dv := Vector2(cos(ang), sin(ang))
						gshots.append({"tp": o.tp + dv * 0.4, "v": dv * 8.0, "dmg": o.dmg * k, "t": 0.4 if q else 0.3, "hit": {}, "id": "anvil"})
				continue
			o.life -= dt
			if K("anvilstay") > 0:
				for m in mons():
					if m.tp.distance_to(o.tp) < 1.8 + m.radius:
						m.slow = maxf(m.slow, 0.4)
		if o.life <= 0.0 or o.hp <= 0.0:
			o.gone = true
			glass_burst(o.tp, 12 if o.kind == "pane" else 24, 2.0, 18.0)
	mirrors = mirrors.filter(func(o): return not o.gone)
	# mirrors break: creatures within 0.9 yd bash them every 0.4 s (zz_tune_batch_c.js)
	if int(time / 0.4) != int((time - dt) / 0.4):
		for o in mirrors:
			if o.kind != "pane" or not o.standing():
				continue
			for m in mons():
				if m.tp.distance_to(o.tp) > 0.9 + m.radius or is_idle(m):
					continue
				var bd: float = maxf(1.0, randf_range(m.dmg.x, m.dmg.y)) * 0.6
				if (m.boss or m.ai == "charger") and bd >= (40.0 + 5.0 * (maxi(1, K("pillars")) - 1)) * 0.75:
					o.hp = 0.0
				else:
					o.hp -= bd
	# Lure of the Glass: the mirrors drag creatures toward their reflections
	if K("magnet") > 0:
		var R := ws_magnet_r()
		var pull := ws_magnet_pull() * dt
		for m in mons():
			if m.boss:
				continue
			var best = null
			var bd2 := R
			for o in mirrors:
				if o.kind != "pane" or not o.standing():
					continue
				var dd: float = m.tp.distance_to(o.tp)
				if dd < bd2:
					bd2 = dd
					best = o
			if best != null and bd2 > best.r + m.radius + 0.08:
				shove(m, (best.tp - m.tp) / bd2 * pull)
	# the Hall of Mirrors: Razor Glass cuts what is caged; the Shattering Hall falls inward at its end
	for c in cages:
		c["t"] -= dt
		c["tick"] -= dt
		if c["tick"] <= 0.0 and K("spikedcage") > 0:
			c["tick"] = 1.0
			for m in mons():
				if m.tp.distance_to(c["tp"]) < 1.7:
					hurt(m, ws_cage_dmg() * 0.3, "cage", {"from": c["tp"]})
		if c["t"] <= 0.0 and K("maidcrush") > 0:
			for m in mons():
				if m.tp.distance_to(c["tp"]) < 1.9:
					hurt(m, ws_cage_dmg() * 1.5, "cage", {"from": c["tp"]})
					if not m.boss:
						m.stun = maxf(m.stun, 1.0)
			glass_burst(c["tp"], 24, 3.0, 14.0)
	cages = cages.filter(func(c): return c["t"] > 0.0)

# ------------------------------------------------------------------ Mirror Fissure: a crack of mirror-glass racing out
func _update_fissures(dt: float) -> void:
	for f in fissures:
		f["t"] -= dt
		while f["t"] <= 0.0 and f["i"] < f["n"]:
			f["t"] += 0.045
			f["i"] += 1
			var d: Vector2 = f["d"]
			var p: Vector2 = f["tp"] + d * f["i"] * 0.6
			if zone.is_solid(p):
				f["i"] = f["n"]
				break
			spikes.append({"tp": p, "t": 0.5, "max": 0.5, "v": (int(f["i"]) * 7 + randi() % 3) % 4})
			var life := ws_crack_life()
			cracks.append({"tp": p + Vector2(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08)), "t": life, "max": life, "v": randi()})
			while cracks.size() > 90:
				cracks.pop_front()
			glass_burst(p, 3, 2.0, 8.0)
			for m in mons():
				var k: int = m.get_instance_id()
				if f["hit"].has(k) or m.tp.distance_to(p) >= 0.7 + m.radius:
					continue
				f["hit"][k] = true
				hurt(m, ws_fissure_dmg(), "fissure", {"from": p})
				m.stun = maxf(m.stun, 0.8 if K("fdeep") > 0 else 0.4)
			if K("fshrap") > 0:
				for sg in [1.0, -1.0]:
					gshots.append({"tp": p, "v": Vector2(-d.y, d.x) * 9.0 * sg, "dmg": ws_fissure_dmg() * 0.3, "t": 0.45, "hit": {}, "id": "fissure"})
			if f["i"] > f["n"] - f["keep"]:
				_raise_pane(p + Vector2(d.y, 0) * 0.01, ws_pillar_life() * 0.7, 0.0, false, true)
	fissures = fissures.filter(func(f): return f["i"] < f["n"])
	for c in cracks:
		c["t"] -= dt
	cracks = cracks.filter(func(c): return c["t"] > 0.0)
	for s in spikes:
		s["t"] -= dt
		if s["t"] <= 0.0:
			glass_burst(s["tp"], 3, 1.4, 6.0)
	spikes = spikes.filter(func(s): return s["t"] > 0.0)


# ------------------------------------------------------------------ bodies keep their space: mirrors and the golem are cover
func _push_out() -> void:
	var obs: Array = []
	for o in mirrors:
		if o.standing():
			obs.append([o.tp, o.r])
	if golem != null and golem.state == "dormant":
		obs.append([golem.tp, golem.r])
	var bodies: Array = mons()
	for b in obs:
		var c: Vector2 = b[0]
		for m in bodies:
			if m.flying:
				continue
			var d: float = m.tp.distance_to(c)
			var mm: float = m.radius + b[1]
			if d < mm:
				shove(m, ((m.tp - c) / d if d > 0.001 else Vector2.RIGHT) * (mm - d))
		var dh: float = hero.tp.distance_to(c)
		var mh: float = hero.radius + b[1]
		if dh < mh and not wraith:
			hero.tp = zone.move(hero.tp, ((hero.tp - c) / dh if dh > 0.001 else Vector2.RIGHT) * (mh - dh), hero.radius)
	# creatures give way to the standing golem
	if golem != null and golem.state != "dormant":
		for m in bodies:
			if m.flying:
				continue
			var d2: float = m.tp.distance_to(golem.tp)
			var mm2: float = m.radius + golem.r
			if d2 < mm2 and d2 > 0.001:
				shove(m, (m.tp - golem.tp) / d2 * (mm2 - d2) * 0.6)
