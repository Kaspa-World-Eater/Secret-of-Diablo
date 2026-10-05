extends "res://skills/miasmancer/tree_distortion.gd"
## The Shrine Keeper, part 4 of 5: the Death (Sigil) tree: claw strikes, finishers, Omens, and what a claw does on a hit.

# ------------------------------------------------------------------ Death
func _grave_strike(a: Vector2) -> bool:
	var m := melee_target(a, 1.1)
	if m == null:
		cast_anim = "atk"
		return true
	var dmg := weapon() * (1.4 + 0.12 * L1("gstrike")) * syn("gstrike")
	gcount = (gcount + 1) % 3
	var hit := func():
		if not m.dead:
			hurt(m, crit(dmg), "gstrike", {"melee": true})
			claw(m)
	hit.call()
	if K("gravecombo") > 0 and gcount == 0:
		later(0.13, hit)
	_grave_root(m)
	_sister_hex(m)
	if K("soulrend") > 0 and omens > 0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.02 * omens)
	add_omen()
	return true

func _grave_root(m) -> void:
	if aU("z_grave") and m and not m.dead:
		root(m, 1.0)

func _sister_hex(m) -> void:
	if sister_cast and K("sisterhex") > 0 and m and not m.dead:
		confuse(m, 1.0)

func _talon(a: Vector2) -> bool:
	var m := melee_target(a, 1.2)
	if m == null:
		return true
	var n := _kicks()
	var dmg := weapon() * (0.55 + 0.06 * L1("talon")) * syn("talon")
	var sis := sister_cast
	for i in n:
		var last := i == n - 1
		later(i * 0.09, func():
			if m.dead:
				return
			hurt(m, dmg if sis else crit(dmg), "talon", {"melee": true})
			psn(m, aura_dps() * 0.5, 2.0)
			puff(m.tp, PALE, 4, 1.4)
			Sfx.play("hit", 0.5, 1.0 + i * 0.1)
			if last:
				shove(m, hero.tp, 1.1)
				if K("talonstun") > 0:
					stun(m, 1.0)
				Game.shake(2.0))
	_grave_root(m)
	_sister_hex(m)
	add_omen()
	cast_len = 0.5
	return true

func _flurry(a: Vector2) -> bool:
	var n := 6 if K("flurrymore") > 0 else 4
	var R := 1.3 + (0.15 if claw_on() else 0.0)
	var dmg := weapon() * (0.5 + 0.05 * L1("flurry")) * syn("flurry")
	var sis := sister_cast
	var every := 3 if K("flurryomen") > 0 else 4
	if foes(hero.tp, R).is_empty():
		return true
	var used: Array = []
	for i in n:
		later(i * 0.07, func():
			var nr := foes(hero.tp, R)
			if nr.is_empty():
				return
			var m = null
			for q in nr:
				if not q in used:
					m = q
					break
			if m == null:
				used.clear()
				m = nr[0]
			used.append(m)
			hurt(m, dmg if sis else crit(dmg), "flurry", {"melee": true})
			claw(m)
			if venom_t > 0.0:
				psn(m, blade_psn(), 4.0)
			if (i + 1) % every == 0:
				add_omen()
			Sfx.play("swing", 0.4, 1.6))
	cast_len = 0.45
	return true

func _rarc(a: Vector2) -> bool:
	var dv := (a - hero.tp).normalized()
	if dv.length() < 0.1:
		dv = Vector2(1, 0)
	var R := 1.8 + (0.15 if claw_on() else 0.0) + (0.6 if K("arcwide") > 0 else 0.0)
	var sis := sister_cast
	var sweep := func(k: float):
		var hits: Array = []
		for m in foes(hero.tp, R):
			var o: Vector2 = m.tp - hero.tp
			if o.length() > 0.01 and o.normalized().dot(dv) < cos(1.45):
				continue
			hits.append(m)
		var dmg := weapon() * (0.95 + 0.09 * L1("rarc")) * syn("rarc") * (1.0 + 0.1 * maxf(0, hits.size() - 1)) * k
		for m in hits:
			hurt(m, dmg if sis else crit(dmg), "rarc", {"melee": true})
			claw(m)
			on_weapon_hit(m, 0.0)
			shove(m, hero.tp, 0.25)
		if hits.size() >= 3:
			add_omen()
		clawfx.append({"tp": hero.tp, "a": dv.angle(), "t": 0.18, "arc": R})
	sweep.call(1.0)
	if K("arcdouble") > 0:
		later(0.15, func(): sweep.call(0.6))
	Game.shake(1.0)
	return true

func _thrust(a: Vector2) -> bool:
	var dv := (a - hero.tp).normalized()
	if dv.length() < 0.1:
		dv = Vector2(1, 0)
	var L := 3.0 + (1.0 if K("thrustlong") > 0 else 0.0) + (0.15 if claw_on() else 0.0)
	var dmg := weapon() * (1.25 + 0.11 * L1("thrust")) * syn("thrust")
	var hits: Array = []
	for m in mons():
		var o: Vector2 = m.tp - hero.tp
		var along := o.dot(dv)
		if along < -0.1 or along > L + m.radius or absf(o.x * dv.y - o.y * dv.x) > 0.4 + m.radius or not zone.sight_clear(hero.tp, m.tp):
			continue
		hits.append([along, m])
	hits.sort_custom(func(p, q): return p[0] < q[0])
	for i in hits.size():
		var m = hits[i][1]
		hurt(m, dmg if sister_cast else crit(dmg), "thrust", {"melee": true})
		claw(m)
		on_weapon_hit(m, 0.0)
		if i == 0 and K("thrustpin") > 0:
			root(m, 1.0)
	if not hits.is_empty():
		add_omen()
	clawfx.append({"tp": hero.tp, "a": dv.angle(), "t": 0.22, "line": L})
	return true

func _death_step(a: Vector2) -> bool:
	var d := maxf(0.01, a.distance_to(hero.tp))
	var L := minf(d, 8.0 if K("steplong") > 0 else 5.0)
	dash = {"d": (a - hero.tp) / d, "left": L, "hit": {}, "omen": false, "trail": 0.0}
	cast_len = L / 14.0 + 0.12
	hero.invuln = maxf(hero.invuln, L / 14.0 + 0.1)
	return true

func _update_dash(dt: float) -> void:
	if dash.is_empty():
		return
	var st := minf(dash["left"], 14.0 * dt)
	var o := hero.tp
	hero.tp = zone.move(hero.tp, dash["d"] * st, hero.radius)
	dash["left"] -= st
	if hero.tp.distance_to(o) < st * 0.3:
		dash["left"] = 0.0
	hero.walking = false
	puff(hero.tp, Color8(106, 90, 122), 1, 0.8)
	if aM("zx_step"):
		dash["trail"] -= st
		if dash["trail"] <= 0.0:
			dash["trail"] = 1.0
			add_cloud(hero.tp, 0.8, 3.0, aura_dps())
	for m in foes(hero.tp, hero.radius + 0.5):
		if dash["hit"].has(m.get_instance_id()):
			continue
		dash["hit"][m.get_instance_id()] = true
		hurt(m, crit(weapon() * (0.9 + 0.08 * L1("dstep")) * syn("dstep")), "dstep", {"melee": true})
		claw(m)
		if not dash["omen"] or K("stepomen") > 0:
			dash["omen"] = true
			add_omen()
	if dash["left"] <= 0.0:
		dash = {}

func _finisher_kill(m, n: int) -> void:
	if not m.dead:
		return
	if K("knell") > 0:
		for o in foes(hero.tp, 4.0):
			fear(o, 2.0 + (1.0 if aM("zx_knell") else 0.0))
		ring(hero.tp, 4.0, 0.6, PALE)
		Sfx.play("bell_far", 0.7, 0.8)
	if aM("z_widow"):
		for o in foes(m.tp, 2.5):
			root(o, 1.5)
		ring(m.tp, 2.5, 0.4, VIOLET_D, 2.5)
		add_cloud(m.tp, 1.8, 3.0, aura_dps())
	if aU("z_reaper"):
		reap_kept = n

func _reap() -> bool:
	var n := spend_omens()
	var R := (1.6 + 0.3 * n) * (1.3 if K("reapwide") > 0 else 1.0) + (0.15 if claw_on() else 0.0)
	var dmg := weapon() * (1.2 + 0.1 * L1("reap")) * syn("reap") * (1.0 + 0.7 * n) * (2.0 if aR("z_death") else 1.0)
	reap_kept = 0
	var hits: Array = []
	for m in foes(hero.tp, R):
		hurt(m, crit(dmg, true), "reap", {"melee": true})
		hits.append(m)
		_grave_root(m)
		if n >= 3:
			shove(m, hero.tp, 1.1)
	for m in hits:
		_finisher_kill(m, n)
	if K("reapmend") > 0 and n > 0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.03 * n)
	if reap_kept > 0:
		omens = mini(omen_max(), reap_kept)
		omen_t = omen_life()
	ring(hero.tp, R, 0.3, PALE)
	clawfx.append({"tp": hero.tp, "a": 0.0, "t": 0.3, "arc": R, "full": true})
	if n > 0:
		say_at(hero.tp + Vector2(0, -0.3), "reap x%d" % n)
	Game.shake(1.0 + n)
	cast_len = 0.5
	return true

func _throw_scythe(a: Vector2) -> bool:
	var n := spend_omens()
	var d := maxf(0.01, a.distance_to(hero.tp))
	scythes.append({"tp": hero.tp, "d": (a - hero.tp) / d, "out": minf(6.0, d + 1.0), "dist": 0.0, "back": false, "hit": {},
		"dmg": weapon() * (1.2 + 0.1 * L1("reap")) * (1.0 + 0.7 * n) * (2.0 if aR("z_death") else 1.0), "n": n, "spin": 0.0})
	return true

func _execute(a: Vector2) -> bool:
	var m := melee_target(a, 1.2)
	if m == null:
		return false
	var n := spend_omens()
	var thr := (0.15 if K("execthr") > 0 else 0.1) + 0.08 * n
	var dmg := weapon() * (1.6 + 0.12 * L1("execute")) * syn("execute") * (1.0 + 0.9 * n) * (2.0 if aR("z_death") else 1.0)
	if m.hp / maxf(1.0, m.hp_max) < thr:
		if m.boss:
			dmg *= 3.0
		else:
			dmg = m.hp + 9999.0
			say_at(m.tp, "EXECUTED", Color.WHITE)
	hurt(m, crit(dmg, true), "execute", {"melee": true, "poise": dmg})
	claw(m)
	puff(m.tp, PALE, 14, 2.4)
	Game.shake(2.0 + n)
	reap_kept = 0
	_finisher_kill(m, n)
	if reap_kept > 0:
		omens = mini(omen_max(), reap_kept)
		omen_t = omen_life()
	return true


func on_weapon_hit(m: Monster, d: float) -> void:
	if m == null:
		return
	if d > 0.0 and K("dhead") > 0 and randf() < crit_ch():
		hurt(m, _wavg() * hero.st.melee_mult() * (2.0 if K("critdmg") > 0 else 1.0), "claw", {"melee": true})
		say_at(hero.tp + Vector2(0, -0.3), "critical", Color.WHITE)
		if K("critomen") > 0:
			add_omen()
	claw(m)
	if venom_t > 0.0 and not m.dead:
		var stk := 5 if aU("z_venom") else (3 if K("vdeep") > 0 else 1)
		psn(m, blade_psn(), 4.0, stk)
		var q: Dictionary = m.get_meta("k_psn", {})
		m.slow = maxf(m.slow, 0.25 + 0.08 * int(q.get("n", 1)) if aU("z_venom") else 0.3)
		venom_n += 1
		if K("vflick") > 0 and venom_n % 3 == 0:
			var o = near(m.tp, 5.0, func(x): return x != m)
			if o == null:
				o = m
			knife(hero.tp, (o.tp - hero.tp).angle(), fang_dmg() * 0.8, 1)
		if K("vclaw") > 0:
			var o2 := near(m.tp, 1.4, func(x): return x != m and x.tp.distance_to(hero.tp) < 2.2)
			if o2:
				hurt(o2, _wavg() * hero.st.melee_mult() * 0.6, "claw", {"melee": true})
				psn(o2, blade_psn(), 4.0)
				claw(o2)
		if aR("z_venom") and d > 0.0:
			# The Coil reversed: the claws throw as they cut
			var b := (m.tp - hero.tp).angle()
			for o3: float in [-0.18, 0.0, 0.18]:
				knife(hero.tp, b + o3, _wavg() * hero.st.melee_mult() * 0.6, 1)
