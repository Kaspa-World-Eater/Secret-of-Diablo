extends "res://skills/animancer/tree_soul.gd"
## The Hollow Mystic, part 4 of 5: the Thread tree. Soul Swarm, Soul Storm, Needle's Mark, Spool, Unravelling,
## Binding Thread, Soul Leash, Soul Lantern, Needle and Thread's darting wisps, the Veil and Wraith Form.

# ------------------------------------------------------------------ Thread tree
func _cast_swarm(a: Vector2) -> bool:
	if aR("a_sage"):
		# The Aether-Sage reversed: a thread that drains its creature into you for 3 s
		var t = null
		var bd := 3.0
		for m in mons():
			var dd: float = m.tp.distance_to(a)
			if dd < bd and m.tp.distance_to(hero.tp) < 7.0 and zone.sight_clear(hero.tp, m.tp):
				bd = dd
				t = m
		if t == null:
			say("Nothing near to drink from.", 1.0)
			return false
		if not spend("swarm"):
			return false
		drains.append({"m": t, "t": 3.0, "tick": 0.0})
		return true
	# no wisps is a weaker swarm, never a refused one (the user, 2026-09-30): he sends two threads of his own
	if not spend("swarm"):
		return false
	hero.spend_poise(4.0)
	var n := mini(3, wisps.size())
	for i in n:
		take_wisp()
	var count := (1 + n * (ws_souls_per_wisp() - 1) + wisps.size() / 2) if n > 0 else 2
	var base := atan2(a.y - hero.tp.y, a.x - hero.tp.x)
	var dmg := ws_soul_dmg() * (1.0 if n > 0 else 0.65)
	for i in count:
		new_soul(hero.tp, base + (randf() - 0.5) * 1.6, 6.0, dmg)
	return true

func _toggle_wraith() -> bool:
	if wraith:
		end_wraith()
		return true
	if not spend("wraith"):
		return false
	wraith = true
	infusing = false
	return true

func _cast_storm(a: Vector2) -> bool:
	# fewer than two wisps makes a shorter storm, never a refused one
	if not spend("storm"):
		return false
	var fed := mini(2, wisps.size())
	for i in fed:
		take_wisp()
	storms.append({"tp": a, "life": ws_storm_life() * (0.5 + 0.25 * fed), "st": 0.0, "spin": 0.0})
	return true

func _cast_mark(a: Vector2) -> bool:
	if not spend("mark"):
		return false
	var R := ws_mark_r()
	var life := ws_mark_life() * (2.0 if aM("g_mark") else 1.0)
	var n := 0
	for m in mons():
		if m.tp.distance_to(a) < R + m.radius:
			m.marked = life
			m.set_meta("mys_mark", true)
			wake(m)
			n += 1
	ring(a, 0.3, 0.6, R)
	return true

func _cast_orb(a: Vector2) -> bool:
	if not spend("orb"):
		return false
	var d := (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.01 else Vector2(1, 1).normalized()
	var heavy := aM("g_orb")
	orbs.append({"tp": hero.tp, "v": d * (3.0 if heavy else 4.0), "life": 3.0 if heavy else 2.0, "ang": randf() * 6.0, "st": 0.0, "pow": 1.0, "gen": 0})
	return true

func _cast_leash(_a: Vector2) -> bool:
	if aR("a_rebuke"):
		# The Rebuke reversed: a harpoon that strikes hard and pins
		var tgt = null
		var bd := 9.0
		for m in mons():
			var dd: float = m.tp.distance_to(_a)
			if dd < 2.5 and m.tp.distance_to(hero.tp) < 8.0 and zone.sight_clear(hero.tp, m.tp) and dd < bd:
				bd = dd
				tgt = m
		if tgt == null:
			say("Nothing near to strike.", 1.0)
			return false
		if not spend("leash"):
			return false
		hurt(tgt, ws_leash_dps() * 1.6, "leash", {"heavy": true})
		if not tgt.dead:
			tgt.root = maxf(tgt.root, 2.0)
		dart_lines.append({"a": hero.tp, "za": 12.0, "b": tgt.tp, "zb": 9.0, "t": 0.4})
		hero._face(tgt.tp - hero.tp)
		return true
	var near: Array = mons().filter(func(m): return m.tp.distance_to(hero.tp) < 7.0 and zone.sight_clear(hero.tp, m.tp))
	if near.is_empty():
		say("Nothing near enough to bind.", 1.0)
		return false
	if not spend("leash"):
		return false
	var per := 2 if K("twin") > 0 else 1
	var used := {}
	var dur := ws_leash_dur()
	var srcs: Array = wisps.duplicate()
	var pick := func(src: Vector2):
		var best = null
		var bd := 1e9
		for m in near:
			var dd: float = m.tp.distance_to(src)
			if dd > 5.0:
				continue
			var sc: float = dd + int(used.get(m.get_instance_id(), 0)) * 3.0
			if sc < bd:
				bd = sc
				best = m
		if best != null:
			used[best.get_instance_id()] = int(used.get(best.get_instance_id(), 0)) + 1
		return best
	if not srcs.is_empty():
		for w in srcs:
			for i in per:
				var m = pick.call(w.tp)
				if m != null:
					threads.append({"src": w, "m": m, "life": dur, "max": dur, "tick": 0.05, "k": 1.0, "freed": false})
	else:
		for i in 3 * per:
			var m = pick.call(hero.tp)
			if m != null:
				threads.append({"src": null, "m": m, "life": dur, "max": dur, "tick": 0.05, "k": 0.65, "freed": false})
	hero._face(near[0].tp - hero.tp)
	return true

func thread_src(th: Dictionary) -> Vector3:
	var s = th["src"]
	if s != null and not s.gone:
		return Vector3(s.tp.x, s.tp.y, s.z)
	return Vector3(hero.tp.x, hero.tp.y, 12.0)

func _cast_word(a: Vector2) -> bool:
	if not spend("word"):
		return false
	var p := clamp_cast(a, 9.0)
	var R := 2.4 * (1.5 if K("wordwide") > 0 else 1.0)
	var dmg := ws_word_dmg()
	words.append({"tp": p, "R": R, "t": 0.0, "dur": 1.1, "dmg": dmg, "seed": randf() * 6.0, "done": false})
	if K("wordecho") > 0:
		words.append({"tp": p, "R": R, "t": -0.9, "dur": 1.1, "dmg": dmg * 0.7, "seed": randf() * 6.0, "done": false})
	return true

func _cast_chain(a: Vector2) -> bool:
	var first = null
	var bd := 2.5
	for m in mons():
		var d: float = m.tp.distance_to(a)
		if d < bd and m.tp.distance_to(hero.tp) < 10.0 and zone.sight_clear(hero.tp, m.tp):
			bd = d
			first = m
	if first == null:
		say("Nothing near to bind.", 0.9)
		return false
	if not spend("chain"):
		return false
	var n := maxi(0, ws_chain_n() - 1) + (2 if K("chainfork") > 0 else 0)
	var others: Array = mons().filter(func(o): return o != first and o.tp.distance_to(first.tp) < 5.5 and zone.sight_clear(first.tp, o.tp))
	others.sort_custom(func(p, q): return p.tp.distance_to(first.tp) < q.tp.distance_to(first.tp))
	others = others.slice(0, n)
	var dmg := ws_chain_dmg()
	hurt(first, dmg * 0.4, "chain")
	last_hit = first
	binds.append({"a": first, "bound": others, "t": 0.0, "dur": 0.55, "dmg": dmg, "done": false, "fade": 0.0})
	return true

func _cast_totem(a: Vector2) -> bool:
	if aR("a_lantern"):
		say("Your lantern is in your hand: strike with it.", 1.4)
		return false
	if zone.is_solid(a) or a.distance_to(hero.tp) > 9.0:
		say("It cannot stand there.", 1.0)
		return false
	if not spend("totem"):
		return false
	for t in totems:
		t.gone = true
		for w in t.wisps:
			w.gone = true
	totems.clear()
	var o := Mirror.new()
	o.kind = "lantern"
	o.tp = a
	o.life = ws_totem_life()
	o.max_life = o.life
	o.hp = 1e9
	# it houses its wisps (they are held out of the choir while it stands)
	var n := ws_totem_n()
	for i in n:
		var w := Wisp.new()
		w.state = "totem"
		w.ang = float(i) / n * TAU
		w.tp = a
		w.z = 22.0
		w.scale = 0.8
		w.cd = 0.3 + 0.2 * i
		o.wisps.append(w)
	totems.append(o)
	return true


# ------------------------------------------------------------------ Spool
func _shard(p: Vector2, ang: float, pw: float) -> void:
	shards.append({"tp": p, "v": Vector2(cos(ang), sin(ang)) * 6.5, "t": 0.75, "dmg": ws_orb_dmg() * pw, "pierce": ws_shard_pierce(), "hit": {}})

func _orb_burst(o: Dictionary) -> void:
	for i in 14:
		_shard(o["tp"], i / 14.0 * TAU, o["pow"] * 1.2)
	glass_burst(o["tp"], 4, 2.0, 12.0)
	if o["gen"] == 0 and ws_cascade_n() > 0 and not aR("a_sage"):
		var k := ws_cascade_n()
		var base: float = o["v"].angle()
		for i in k:
			var a := base + (i - (k - 1) / 2.0) * 0.9
			orbs.append({"tp": o["tp"], "v": Vector2(cos(a), sin(a)) * 4.5, "life": 0.9, "ang": randf() * 6.0, "st": 0.0, "pow": ws_cascade_pct(), "gen": 1})

func _update_orbs(dt: float) -> void:
	var burst: Array = []
	for o in orbs:
		o["life"] -= dt
		o["st"] -= dt
		var n: Vector2 = o["tp"] + o["v"] * dt
		if zone.blocks_sight(n):
			o["life"] = 0.0
		else:
			o["tp"] = n
		while o["st"] <= 0.0 and o["life"] > 0.0:
			o["st"] += ws_orb_rate() * (1.6 if o["gen"] else 1.0)
			o["ang"] += 2.3
			_shard(o["tp"], o["ang"], o["pow"])
		if o["life"] <= 0.0:
			burst.append(o)
	orbs = orbs.filter(func(o): return o["life"] > 0.0)
	for o in burst:
		_orb_burst(o)
	for s in shards:
		s["t"] -= dt
		var n2: Vector2 = s["tp"] + s["v"] * dt
		if zone.blocks_sight(n2):
			s["t"] = 0.0
			continue
		s["tp"] = n2
		for m in mons():
			var k: int = m.get_instance_id()
			if s["hit"].has(k) or absf(m.tp.x - n2.x) > 1.0 or m.tp.distance_to(n2) > m.radius + 0.1:
				continue
			s["hit"][k] = true
			hurt(m, s["dmg"], "orb", {"from": n2})
			if aU("a_pyre") and not m.dead:
				m.add_dot(s["dmg"] * 0.3, 3.0, "fire")
			if aU("a_sage") and not s.get("jumped", false) and s["pierce"] <= 1:
				for jj in 2:
					var ang := randf() * TAU
					shards.append({"tp": n2, "v": Vector2(cos(ang), sin(ang)) * 6.5, "t": 0.5, "dmg": s["dmg"] * 0.6, "pierce": 1, "hit": s["hit"].duplicate(), "jumped": true})
			s["pierce"] -= 1
			if s["pierce"] <= 0:
				s["t"] = 0.0
				break
	shards = shards.filter(func(s): return s["t"] > 0.0)
	if shards.size() > 400:
		shards = shards.slice(shards.size() - 400)

# ------------------------------------------------------------------ Soul Storm
func _update_storms(dt: float) -> void:
	for s in storms:
		s["life"] -= dt
		s["st"] -= dt
		if aM("g_storm"):
			s["tp"] = s["tp"].move_toward(hero.tp, 3.5 * dt)
		s["spin"] += dt * 6.0
		while s["st"] <= 0.0:
			s["st"] += ws_storm_rate()
			var so := new_soul(s["tp"], randf() * TAU, 5.0, ws_soul_dmg() * 0.75)
			so["storm"] = true
			if K("tempest") > 0:
				so["hits"] += 1
	storms = storms.filter(func(s): return s["life"] > 0.0)

# ------------------------------------------------------------------ Unravelling
func _update_words(dt: float) -> void:
	for w in words:
		w["t"] += dt
		if w["t"] < 0.0:
			continue
		if w["t"] < w["dur"]:
			for m in mons():
				if m.boss:
					continue
				var d: float = m.tp.distance_to(w["tp"])
				if d < w["R"] + 1.2 and d > 0.2:
					shove(m, (w["tp"] - m.tp) / d * minf(d - 0.15, 2.6 * dt))
					m.slow = maxf(m.slow, 0.5)
		elif not w["done"]:
			w["done"] = true
			for m in mons():
				if m.tp.distance_to(w["tp"]) < w["R"] + m.radius:
					hurt(m, w["dmg"], "word", {"from": w["tp"], "heavy": true})
					if not m.boss:
						m.stun = maxf(m.stun, 0.6)
			glass_burst(w["tp"], 8, 2.5, 10.0)
			if Settings.screen_shake:
				Game.hitstop(0.05)
	words = words.filter(func(w): return not w["done"] or w["t"] < w["dur"] + 0.3)

# ------------------------------------------------------------------ Binding Thread (zz_zz_mystic90.js)
func _update_binds(dt: float) -> void:
	for b in binds:
		if b["done"]:
			b["fade"] += dt
			continue
		b["t"] += dt
		var A = b["a"]
		var alive_a: bool = is_instance_valid(A) and not A.dead
		for m in b["bound"]:
			if not is_instance_valid(m) or m.dead or not alive_a:
				continue
			m.slow = maxf(m.slow, 0.5)
			if m.boss:
				continue     # the great are held, not dragged
			var dv: Vector2 = A.tp - m.tp
			var d := maxf(dv.length(), 0.001)
			var stop: float = A.radius + m.radius + 0.15
			if d <= stop:
				continue
			var left := maxf(0.06, b["dur"] - b["t"])
			var step := minf(d - stop, minf(9.0, (d - stop) / left) * dt) * (0.6 if m.rank in ["champion", "unique"] else 1.0)
			shove(m, dv / d * step)
		if b["t"] >= b["dur"]:
			b["done"] = true
			var all: Array = [A] + b["bound"]
			for m in all:
				if not is_instance_valid(m) or m.dead:
					continue
				hurt(m, b["dmg"], "chain", {"from": A.tp if alive_a else hero.tp})
				if not m.dead:
					m.add_poise_damage(18.0 * 1.2, false)
					m.slow = maxf(m.slow, 0.8)
					if K("chainmark") > 0:
						m.marked = maxf(m.marked, 3.0)
			if Settings.screen_shake and all.size() > 1:
				Game.hitstop(0.04)
	binds = binds.filter(func(b): return not b["done"] or b["fade"] < 0.3)

# ------------------------------------------------------------------ Soul Leash (zz_zz_thread93.js): threads from the wisps
func _update_threads(dt: float) -> void:
	for th in threads:
		th["life"] -= dt
		var src = th["src"]
		if src != null and src.gone:
			th["life"] = minf(th["life"], 0.15)     # its wisp is gone: the thread falls slack
		var m = th["m"]
		if not is_instance_valid(m) or m.dead:
			if is_instance_valid(m) and m.dead and not th["freed"] and K("snare") > 0 and wisps.size() < eff_cap():
				th["freed"] = true
				spawn_wisp(m.tp)
			th["life"] = minf(th["life"], 0.15)
			continue
		if m.buried:
			th["life"] = minf(th["life"], 0.15)
			continue
		var s3 := thread_src(th)
		var s := Vector2(s3.x, s3.y)
		if m.tp.distance_to(s) > 6.5:
			th["life"] = minf(th["life"], 0.15)
			continue
		if K("barbs") > 0:
			m.slow = maxf(m.slow, 0.4)
		# The Rebuke: the rope cracks like a whip every second
		if aU("a_rebuke"):
			th["crack"] = float(th.get("crack", 1.0)) - dt
			if th["crack"] <= 0.0:
				th["crack"] = 1.0
				for o in mons():
					if seg_dist(o.tp, s, m.tp) < o.radius + 0.3:
						hurt(o, ws_leash_dps() * 0.6, "leash", {"from": s, "poise": ws_leash_dps() * 0.5})
						if not o.boss and not o.dead:
							var away: Vector2 = o.tp - hero.tp
							shove(o, away.normalized() * 0.9 if away.length() > 0.01 else Vector2.RIGHT * 0.9)
		th["tick"] -= dt
		if th["tick"] > 0.0 or th["life"] <= 0.15:
			continue
		th["tick"] = 0.25
		var dmg := ws_leash_dps() * 0.25 * float(th["k"])
		hurt(m, dmg, "leash", {"from": s, "poise": dmg * 0.4})
		for o in mons():
			if o == m:
				continue
			if seg_dist(o.tp, s, m.tp) < o.radius + 0.18:
				hurt(o, dmg * 0.7, "leash", {"from": s, "poise": dmg * 0.3})
				if K("barbs") > 0:
					o.slow = maxf(o.slow, 0.5)
	threads = threads.filter(func(th): return th["life"] > 0.0)

# ------------------------------------------------------------------ Soul Lantern
func _update_totems(dt: float) -> void:
	for t in totems:
		t.life -= dt
		if aU("a_lantern"):
			var want: Vector2 = hero.tp + Vector2(0.9, -0.6)
			if t.tp.distance_to(want) > 0.2:
				t.tp = t.tp.move_toward(want, 4.5 * dt)
		t.pulse -= dt
		if t.pulse <= 0.0:
			t.pulse = 0.4
			for m in mons():
				var d: float = m.tp.distance_to(t.tp)
				if d > 4.2:
					continue
				m.set_meta("mys_frail", time + 0.5)
				m.set_meta("mys_lantern", time + 0.5)
				if K("lantgrasp") > 0 and not m.boss and d > 0.8:
					shove(m, (t.tp - m.tp) / d * 0.35)
		# its housed wisps turn about it and loose thin lines at what stands in its light
		for w in t.wisps:
			w.ang += dt * 1.6
			w.tp = t.tp + Vector2(cos(w.ang), sin(w.ang)) * 0.5
			w.z = 20.0 + sin(time * 3.0 + w.ang) * 2.0
			if w.beam.is_empty():
				w.cd -= dt
				if w.cd > 0.0:
					continue
				var best = null
				var bd := 5.5
				for m in mons():
					var dd: float = m.tp.distance_to(w.tp)
					if dd < bd and not (is_idle(m) and m.tp.distance_to(hero.tp) > 6.0) and zone.sight_clear(w.tp, m.tp):
						bd = dd
						best = m
				if best != null:
					w.beam = {"t": 0.0, "dur": 0.8, "tick": 0.0, "target": best}
				else:
					w.cd = 0.3
				continue
			var b: Dictionary = w.beam
			b["t"] += dt
			b["tick"] -= dt
			var tg = b["target"]
			if tg == null or not is_instance_valid(tg) or tg.dead or tg.buried or b["t"] >= b["dur"]:
				w.beam = {}
				w.cd = 1.1
				continue
			totem_beams.append({"a": w.tp, "za": w.z, "b": tg.tp, "t": 0.05})
			if b["tick"] <= 0.0:
				b["tick"] = 0.15
				hurt(tg, ws_totem_dps() * 0.15 * (1.0 - 0.6 * b["t"] / b["dur"]), "totem", {"from": w.tp})
		if K("beacon") > 0:
			if hero.tp.distance_to(t.tp) < 3.0:
				hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.02 * dt)
			if golem != null and golem.state != "dormant" and golem.tp.distance_to(t.tp) < 3.0:
				golem.hp = minf(golem.max_hp, golem.hp + golem.max_hp * 0.02 * dt)
		if t.life <= 0.0:
			t.gone = true
			for w in t.wisps:
				w.gone = true
	totems = totems.filter(func(t): return not t.gone)

# ------------------------------------------------------------------ Needle and Thread: darting wisps that ricochet (zy_anim.js)
func _dart(o: Dictionary) -> Dictionary:
	var M := {"tp": hero.tp, "z": 12.0, "t": 0.0, "tk": "pt", "tgt": null, "hops": 1, "mult": 1.0, "decay": 0.85, "dmg": 1.0,
		"hit": {}, "used": {}, "bounces": 0, "maxB": 3, "mir_hops": 1, "bounce_k": 1.0, "mir_r": 3.0, "leap": 4.2, "spd": 14.0,
		"turn": 10.0, "gen": 0, "v": Vector2.RIGHT, "split": false, "small": false, "split_n": 2, "kind": "lance", "last": hero.tp}
	M.merge(o, true)
	return M

func _launch(M: Dictionary, tgt, tk: String, bend: float) -> void:
	M["tgt"] = tgt
	M["tk"] = tk
	var p: Vector2 = tgt if tgt is Vector2 else (tgt["tp"] if tgt is Dictionary else tgt.tp)
	var a := atan2(p.y - M["tp"].y, p.x - M["tp"].x) + bend
	M["v"] = Vector2(cos(a), sin(a))

func _lance_pulse(a: Vector2) -> void:
	if aR("a_blade"):
		_spirit_sword(a)
		return
	if aU("a_blade"):
		var end := hero.tp + (a - hero.tp).limit_length(ws_lance_range())
		for i in 3:
			ground_fire(hero.tp.lerp(end, (i + 1) / 3.5), 0.55, ws_lance_dps() * 0.25, 1.5)
	var R0 := ws_lance_range()
	var first = null
	var bd := 2.2
	for m in mons():
		var dc: float = m.tp.distance_to(a)
		var dp: float = m.tp.distance_to(hero.tp)
		if dp > R0 + m.radius or dc > bd or not zone.sight_clear(hero.tp, m.tp):
			continue
		bd = dc
		first = m
	var focus := 1.0 + ws_focus_max() * minf(1.0, an_hold / 2.0)
	var M := _dart({"tp": hero.tp + Vector2(hero.face * 0.15, 0), "z": 13.0, "dmg": ws_lance_dps() * 0.42 * focus, "hops": ws_lance_pierce() + 1,
		"decay": 0.82, "maxB": 99, "mir_hops": 2, "bounce_k": 1.0, "mir_r": 3.2, "leap": 4.2, "spd": 16.0, "turn": 12.0, "kind": "lance"})
	if first != null:
		_launch(M, first, "mon", (randf() - 0.5) * 0.8)
	else:
		var d := minf(R0, a.distance_to(hero.tp))
		var dir := (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.01 else Vector2(1, 1).normalized()
		_launch(M, hero.tp + dir * maxf(d, 1.0), "pt", 0.0)
	darts.append(M)

func _dart_split(M: Dictionary, n: int, pct: float) -> void:
	var from: Vector2 = M["tp"]
	var foes: Array = mons().filter(func(m): return not M["hit"].has(m.get_instance_id()) and m.tp.distance_to(from) < 5.0 and zone.sight_clear(from, m.tp))
	foes.sort_custom(func(p, q): return p.tp.distance_to(from) < q.tp.distance_to(from))
	foes = foes.slice(0, n)
	var i := 0
	for m in foes:
		var s := _dart({"tp": from, "z": M["z"], "dmg": M["dmg"] * pct, "hops": 1, "decay": 0.8, "maxB": 1, "mir_hops": 0, "spd": M["spd"] * 1.15,
			"turn": 14.0, "gen": M["gen"] + 1, "hit": M["hit"].duplicate(), "small": true, "used": M["used"].duplicate(), "kind": M["kind"]})
		_launch(s, m, "mon", (i - (foes.size() - 1) / 2.0) * 0.9 + (randf() - 0.5) * 0.3)
		darts.append(s)
		i += 1

func _dart_fly(M: Dictionary, dt: float) -> bool:
	M["t"] += dt
	if M["t"] > 5.0:
		return true
	var T = M["tgt"]
	if M["tk"] == "mon" and (T == null or not is_instance_valid(T) or T.dead or T.buried):
		var n = _next_foe(M["tp"], M["hit"], 4.5)
		if n == null:
			return true
		M["tgt"] = n
		T = n
	if M["tk"] == "mir":
		var mt = _metal(T["key"]) if T is Dictionary else null
		if mt == null:
			var n2 = _next_foe(M["tp"], M["hit"], 5.0)
			if n2 == null:
				return true
			M["tk"] = "mon"
			M["tgt"] = n2
			T = n2
		else:
			M["tgt"] = mt
			T = mt
	if T == null:
		return true
	var tpos: Vector2 = T if T is Vector2 else (T["tp"] if T is Dictionary else T.tp)
	var tz: float = 9.0 if M["tk"] == "mon" else (T["z"] if M["tk"] == "mir" else 8.0)
	var dv: Vector2 = tpos - M["tp"]
	var l := maxf(dv.length(), 1e-6)
	var step: float = M["spd"] * dt
	var reach: float = (T.radius * 0.5 + 0.08) if M["tk"] == "mon" else 0.25
	if l <= step + reach:
		M["tp"] = tpos - dv / l * reach
		M["z"] += (tz - M["z"]) * 0.6
		return _dart_arrive(M)
	var k := 1.0 if l < 1.1 else minf(1.0, dt * M["turn"])
	M["v"] = (M["v"] + (dv / l - M["v"]) * k).normalized()
	M["tp"] += M["v"] * step
	M["z"] += (tz + sin(M["t"] * 21.0) * 1.5 - M["z"]) * minf(1.0, dt * 9.0)
	# cracked mirror-glass fissures it into more wisps
	if M["gen"] == 0 and not M["split"]:
		for c in cracks:
			if c["tp"].distance_to(M["tp"]) <= 0.45:
				M["split"] = true
				glass_burst(c["tp"], 4, 1.5, 3.0)
				_dart_split(M, M["split_n"], 0.6)
				break
	return false

func _dart_arrive(M: Dictionary) -> bool:
	if M["tk"] == "pt":
		return true
	if M["tk"] == "mon":
		var m = M["tgt"]
		var dmg: float = M["dmg"] * M["mult"]
		hurt(m, dmg, "lance", {"from": M["last"]})
		M["hit"][m.get_instance_id()] = true
		# Siphon: part of it comes back as life and Essence
		var sp := ws_siphon()
		if sp > 0.0:
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dmg * sp)
			hero.st.res = minf(hero.st.res_max(), hero.st.res + dmg * sp)
		last_hit = m
		dart_lines.append({"a": M["last"], "za": 10.0, "b": m.tp, "zb": 9.0, "t": 0.35})
		M["last"] = m.tp
		if aU("a_sage") and int(M["gen"]) == 0 and not M.get("sage", false):
			M["sage"] = true
			_dart_split(M, 2, 0.6)
		M["hops"] -= 1
		M["mult"] *= M["decay"]
		if M["bounces"] < M["maxB"]:
			var mir = _near_mirror(m.tp, M["used"], M["mir_r"])
			if mir != null:
				M["tk"] = "mir"
				M["tgt"] = mir
				return false
		if M["hops"] > 0:
			var n = _next_foe(m.tp, M["hit"], M["leap"])
			if n != null:
				M["tgt"] = n
				return false
		return true
	# a mirror: the wisp rebounds renewed
	var o: Dictionary = M["tgt"]
	M["used"][o["key"]] = true
	M["bounces"] += 1
	M["mult"] = maxf(1.0, M["mult"]) * M["bounce_k"]
	M["hops"] += M["mir_hops"] + (1 if o["hall"] else 0)
	dart_lines.append({"a": M["last"], "za": 10.0, "b": o["tp"], "zb": o["z"], "t": 0.35})
	M["last"] = o["tp"]
	if o["cracked"] and M["gen"] == 0:
		_dart_split(M, M["split_n"], 0.6)
		glass_burst(o["tp"], 3, 1.2, o["z"])
	if K("prismL") > 0 and M["kind"] == "lance":
		_dart_split(M, ws_prism_ln(), ws_prism_lpct())
	var n3 = _next_foe(o["tp"], M["hit"], 6.5)
	if n3 == null:
		return true
	M["tk"] = "mon"
	M["tgt"] = n3
	M["v"] = (n3.tp - o["tp"]).normalized()
	return false

func _update_darts(dt: float) -> void:
	for d in darts.duplicate():
		if _dart_fly(d, dt):
			d["done"] = true
	darts = darts.filter(func(d): return not d.get("done", false))
	if darts.size() > 160:
		darts = darts.slice(darts.size() - 160)

# ------------------------------------------------------------------ the Veil's Rebuke, and Phantom Step
func _update_whips(dt: float) -> void:
	for w in whips:
		w["t"] += dt
		var k := minf(1.0, w["t"] / w["dur"])
		var pts: Array = []
		var sweep: float = w["base"] - 1.1 + 2.2 * k
		for i in 13:
			var t := i / 12.0
			var a := sweep - sin(t * PI) * 0.35 * (1.0 - k) + t * t * 0.5 * (k - 0.5)
			pts.append(hero.tp + Vector2(cos(a), sin(a)) * w["len"] * t)
		w["pts"] = pts
		for m in mons():
			var key: int = m.get_instance_id()
			if w["hit"].has(key):
				continue
			for i in pts.size() - 1:
				if seg_dist(m.tp, pts[i], pts[i + 1]) < m.radius + 0.15:
					w["hit"][key] = true
					hurt(m, w["dmg"], "rebuke")
					var away: Vector2 = (m.tp - hero.tp).normalized()
					for j in 5:
						shove(m, away * 0.22)
					m.stun = maxf(m.stun, 0.3)
					break
	whips = whips.filter(func(w): return w["t"] < w["dur"] + 0.12)

func _update_phantoms(dt: float) -> void:
	for p in phantoms:
		p["t"] -= dt
		if p["t"] <= 0.0:
			for m in mons():
				if m.tp.distance_to(p["tp"]) < 1.2 + m.radius:
					hurt(m, ws_phantom_dmg(), "phantom", {"from": p["tp"]})
			ring(p["tp"], 1.2, 0.3, 0.2)
	phantoms = phantoms.filter(func(p): return p["t"] > 0.0)


# ================================================================== the Veil, Wraith Form, weapon blows, kills
## Wraith Form: physical blows pass through untouched (core/combat.gd asks this before anything lands)
func phases(elem: String) -> bool:
	return wraith and elem == "phys"

## the Veil: Essence answers the blow first (70% -> 95% of it; 1 Essence stops 1.06 -> 2.2); the wraith takes magic x1.5
func absorb(d: float, elem: String) -> float:
	# The Anvil reversed: the worn iron takes half of every blow
	if shell > 0.0:
		var half := d * 0.5
		shell -= half
		d -= half
		if shell <= 0.0:
			shell = 0.0
			glass_burst(hero.tp, 16, 2.5, 20.0)
			say("The iron shell splits and falls away.", 1.6)
	# The Maiden's Kiss reversed: what strikes you in melee takes 60% of the blow back
	if maiden_t > 0.0 and elem == "phys":
		for m in mons():
			if m.tp.distance_to(hero.tp) < 1.8 + m.radius:
				hurt(m, d * 0.6, "cage", {"nochoir": true})
				break
	if wraith:
		if elem == "phys":
			return 0.0
		d *= 1.5
	var pct := ws_ward_pct()
	if pct > 0.0 and hero.st.res > 0.0:
		var eff := ws_ward_eff()
		var use_e := minf(hero.st.res, d * pct / eff)
		hero.st.res -= use_e
		d -= use_e * eff
		_rebuke(use_e * eff)
	return maxf(0.0, d)

func _rebuke(a: float) -> void:
	if K("rebuke") <= 0:
		return
	rebuke_acc += a
	if rebuke_acc < ws_rebuke_need():
		return
	rebuke_acc = 0.0
	var tgt = null
	var bd := 5.0
	for m in mons():
		var d: float = m.tp.distance_to(hero.tp)
		if d < bd:
			bd = d
			tgt = m
	var base: float = atan2(tgt.tp.y - hero.tp.y, tgt.tp.x - hero.tp.x) if tgt != null else randf() * TAU
	whips.append({"base": base, "t": 0.0, "dur": 0.32, "hit": {}, "dmg": ws_rebuke_dmg(), "len": 4.5})

func on_weapon_hit(m: Monster, d: float) -> void:
	last_hit = m
	end_wraith()
	# The Lantern-Bearer reversed: the lantern swung as a flail
	if aR("a_lantern") and m != null:
		for o in mons():
			if o != m and o.tp.distance_to(m.tp) < 1.3 + o.radius:
				hurt(o, d * 0.5, "totem", {"from": m.tp, "nochoir": true})
		lantern_blow += 1
		if lantern_blow % 2 == 0:
			spawn_wisp(m.tp)
	# the finishing blow gives the Mystic a wisp (zz_zz_study82.js)
	if m != null and m.finisher_lock >= 1.49:
		spawn_wisp(m.tp)
