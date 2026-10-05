extends "res://skills/monk/tree_destroyer.gd"
## The Empty Hand (class id "monk"), part 5 of 5: casting (which skill runs what), the hooks the shared game calls,
## and the frame (tick). The state, the glass, numbers and helpers are in skills/monk/base.gd (its header has the API);
## each tree's skills are in skills/monk/tree_*.gd.

# ================================================================== casting


func rooted() -> bool:
	return not lotus.is_empty() or not eye.is_empty() or not leap.is_empty() or not flurry.is_empty() or not palm.is_empty() or not thousand.is_empty()

func move_k() -> float:
	var k := 1.0
	if obsid > 0.0:
		k *= 0.85
	if walk:
		k *= 1.1
	if rooted():
		k = 0.0
	return k

func melee_k() -> float:
	return 1.45 + 0.03 * L1("kobsid") if obsid > 0.0 else 1.0

func use(id: String, at: Vector2, target: Monster) -> bool:
	if id == "attack" or id == "" or hero == null or zone == null:
		return false
	if lvl(id) <= 0 or is_passive(id):
		return false
	# toggles can be used mid-cast
	if id == "kamber":
		return _toggle_amber()
	if id == "kwalk":
		return _toggle_walk()
	if nothing_t > 0.0 and id != "kbowl":
		return false
	if not leap.is_empty() or (not lotus.is_empty() and id != "klotus") or not flurry.is_empty():
		return false
	if hero.act != "" and hero.act != "swing" and hero.act != "cast":
		return false
	if target != null and is_instance_valid(target):
		at = target.tp
	at = _los_point(at)
	if id in HOLD:
		if (id == "keye" and not eye.is_empty()) or (id == "klotus" and not lotus.is_empty()):
			return false
		pay(id, 0.4)
		if id == "keye":
			eye = {"ang": (at - hero.tp).angle(), "t": 0.0, "tick": 0.0}
			Sfx.play("cast_mirror", 0.6, 1.6)
		else:
			lotus = {"t": 0.0, "tick": 0.0, "R": 1.1}
			Sfx.play("cast_soul", 0.6, 0.8)
		hold_id = id
		_after(id, at)
		cast_anim = "cast"
		cast_len = 0.3
		return true
	if id == "kbowl":
		if bowl <= 0:
			say("The bowl is empty.", 1.0)
			return false
		_drink_bowl()
		cast_anim = "cast"
		return true
	if id == "kweep" and buddha != null:
		_command_buddha(at)
		cast_anim = "cast"
		cast_len = 0.3
		return true
	# melee skills walk you in, then strike
	if MELEE.has(id) and not (id == "kfinger" and aR("kd_finger")):
		var m := _melee_target(at, target, float(MELEE[id]))
		if m == null:
			var far := near(at, 3.6)
			if far == null:
				say("No enemy in reach.", 0.8)
				return false
			pending = {"id": id, "m": far, "t": 3.0}
			hero.target = null
			hero.walk_to(far.tp)
			return false
		target = m
		at = m.tp
	var ok := _cast(id, at, target)
	if ok:
		pay(id, 0.5 if id in ["kdawn", "keclipse"] and not zone.d.get("outdoor", false) else 1.0)
		_after(id, at)
		hero.stats_changed.emit()
	return ok


func _cast(id: String, a: Vector2, target) -> bool:
	match id:
		"kdawn": return _turn_sky("noon")
		"keclipse": return _turn_sky("night")
		"khands": return _cast_hundred(target)
		"kstar": return _cast_star(a)
		"kfist": return _cast_fist(a)
		"ksutra": return _cast_sutra(a)
		"ktears": return _cast_tears()
		"kbell": return _cast_bell()
		"ksun": return _cast_sun()
		"kpalm": return _cast_palm()
		"kclap": return _cast_clap()
		"kspade": return _cast_spade(a)
		"kpinch": return _cast_pinch(a)
		"kbelow": return _cast_below(a)
		"kspit": return _cast_spit(a)
		"kmirror": return _cast_mirror()
		"knothing": return _cast_nothing()
		"kgrip": return _cast_grip(target)
		"kfinger": return _cast_finger(target)
		"kobsid": return _cast_obsid()
		"kmount": return _cast_mount(a)
		"kstep": return _cast_step(a)
		"kpagoda": return _cast_pagoda(a)
		"kweep": return _summon_buddha(a)
		"kthousand": return _cast_thousand(a)
	return false


# ================================================================== hooks the shared game calls
func before_hit(d: float, elem: String, from: Vector2, opts: Dictionary) -> float:
	if nothing_t > 0.0:
		return 0.0
	if sun_t > 0.0 and elem == "phys":
		say_at(hero.tp + Vector2(0, -0.5), "untouched", Color8(255, 216, 112))
		return 0.0
	var src_m: Monster = null
	if from != Vector2.INF:
		src_m = near(from, 0.6)
	var melee := elem == "phys" and src_m != null and src_m.tp.distance_to(hero.tp) < 2.6
	if melee and mirror_t > 0.0:
		var k := 3.0 if K("kmirror2") > 0 else 2.0
		slams.append({"tp": src_m.tp, "z": 0, "t": 0.35, "max": 0.35, "kind": "mirror"})
		hurt(src_m, d * k, "kmirror")
		say_at(hero.tp + Vector2(0, -0.4), "swallowed", Color8(138, 122, 168))
		return 0.0
	if melee and not bell.is_empty():
		d *= 0.3
		_bell_ring()
	if melee and K("kbarthorn") > 0:
		hurt(src_m, d * 0.2, "kbar")
	if melee and aR("kr_sutra") and halo > 0:
		# the halo is worn: a blow burns a talisman away, and it bursts on the one who struck for double
		halo -= 1
		hurt(src_m, D("ksutra", 9, 4) * 2.0, "ksutra")
		dust(src_m.tp, Color(1.0, 0.85, 0.44), 10)
	if shell_t > 0.0:
		d *= 0.6
		if melee:
			hurt(src_m, fist() * 1.2, "kthousand")
			slams.append({"tp": src_m.tp, "z": 14, "t": 0.3, "max": 0.3, "kind": "palm", "s": 1.4, "stone": true})
	if aM("kd_door") and still_t > 1.0:
		d *= 0.9
	if elem == "phys":
		d *= 1.0 - dr()
	if not lotus.is_empty() or obsid > 0.0:
		d *= 0.85
	return d

func catch_missile(mi) -> bool:
	if hero == null or hero.dead:
		return false
	var d: float = mi.tp.distance_to(hero.tp)
	if not bell.is_empty() and d > 0.9:
		dust(mi.tp, Color(0.94, 0.85, 0.56), 5, 1.2)
		_bell_ring()
		return true
	if K("kbowl") > 0:
		var v: Vector2 = mi.vel.normalized() if "vel" in mi else Vector2.ZERO
		var fv := _facing()
		var front := -(v.dot(fv)) > 0.2
		if (front or K("kbowlw") > 0) and randf() < bowl_chance():
			bowl = mini(6, bowl + 1)
			say_at(hero.tp + Vector2(0, -0.3), "into the bowl", Color8(201, 166, 107))
			Sfx.play("coins", 0.3, 1.4)
			if bowl >= 6:
				_drink_bowl()
			return true
	return false

func _facing() -> Vector2:
	var sx: float = hero.face
	var sy := -1.0 if hero.view in ["back", "up"] else 1.0
	var v := Vector2((sx + sy) / 2.0, (sy - sx) / 2.0)
	return v.normalized() if v.length() > 0.01 else Vector2(1, 1).normalized()

func light_mod(r: float) -> float:
	var k := sky_k()
	if k < 0.0:
		return r
	return r + 3.5 * k if k > 0.5 else r * 0.8

func unseen(m) -> bool:
	if nothing_t > 0.0:
		return true
	if Game.sky_force == "night" and not m.boss and m.tp.distance_to(hero.tp) > (4.0 if K("kecl3") > 0 else 6.0):
		return true
	return false

func on_weapon_hit(m: Monster, d: float) -> void:
	if m == null or m.dead:
		return
	fault(m)
	if is_stone(m):
		hurt(m, 1.0, "rubble")
	if hero.st.inv and hero.st.inv.weapon() and hero.st.inv.weapon().base == "shakujo":
		Sfx.play("glass", 0.2, 2.0)
	slams.append({"tp": m.tp, "z": 10, "t": 0.16, "max": 0.16, "kind": "palm", "s": 0.8})

func on_lantern() -> void:
	kR = 0.0
	kA = 0.0
	sync_res()

func on_death() -> void:
	_reset()

func _reset() -> void:
	amber = false
	walk = false
	obsid = 0.0
	shell_t = 0.0
	mirror_t = 0.0
	nothing_t = 0.0
	sun_t = 0.0
	bowl = 0
	bell = {}
	eye = {}
	lotus = {}
	leap = {}
	flurry = {}
	palm = {}
	thousand = {}
	quake = {}
	pending = {}
	hold_id = ""
	float_z = 0.0
	Game.sky_force = ""
	if buddha != null and is_instance_valid(buddha):
		buddha.queue_free()
	buddha = null
	buddha_mem = {}
	kR = 0.0
	kA = 0.0

## his kills leave no corpse: glass, dust, rubble or red mist (Ur-Nihl's servants leave nothing to raise)
func _on_kill(m) -> void:
	if hero == null or hero.st == null or hero.cls != "monk" or not is_instance_valid(m):
		return
	run_back(0.07)
	if trace:
		print("KILL ", m.kind, " src=", src, " hpmax=", m.hp_max)
	if src == "kamber" and K("kash") > 0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.03)
	faults.erase(m.get_instance_id())
	if aM("kh_lantern") and Game.sky_force != "" and sky_bonus < 10.0:
		Game.sky_t += 1.0
		sky_bonus += 1.0
	if aM("kh_unraised") and raised(m):
		for o in foes(m.tp, 1.6):
			stun(o, 0.5)
		dust(m.tp, Color(0.85, 0.82, 0.74), 14)
	if m.boss:
		return
	var kind := "glass"
	if src in ["dust", "kpinch"]:
		kind = "dust"
	elif src == "kthousand":
		kind = "mist"
	elif src in ["rubble", "kpagoda", "kgrip"] or is_stone(m):
		kind = "rubble"
	var life: float = {"glass": 14.0, "rubble": 10.0, "dust": 2.2, "mist": 2.2}[kind]
	remains.append({"tp": m.tp, "r": m.radius, "t": life, "max": life, "kind": kind, "seed": randf() * 99.0})
	while remains.size() > 40:
		remains.pop_front()
	var col: Color = {"glass": Color(0.05, 0.04, 0.07), "rubble": Color(0.54, 0.53, 0.49), "dust": Color(0.69, 0.67, 0.63), "mist": Color(0.45, 0.1, 0.13)}[kind]
	dust(m.tp, col, 18, 2.4)
	m.visible = false
	m.corpse_t = 0.0
	m.modulate.a = 0.0

# ================================================================== the frame
func tick(dt: float) -> void:
	if hero == null or hero.zone == null:
		return
	time += dt
	if zone != hero.zone:
		_enter_zone()
	var st = hero.st
	if has_meta("sand_test"):
		var sv: Array = get_meta("sand_test")
		kR = sv[0] * bulb()
		kA = sv[1] * bulb()
		cast_t = time
		pour_tab = 0 if fmod(time, 2.0) < 1.0 else 1
		pour_t = time
	# potions and finishing blows fill st.res from outside: that is sand running back
	if last_res >= 0.0 and st.res > last_res + 0.01:
		var gain: float = st.res - last_res
		var take := minf(gain, kR + kA)
		var fr := kR / maxf(0.001, kR + kA)
		kR = maxf(0.0, kR - take * fr)
		kA = maxf(0.0, kA - take * (1.0 - fr))
	# the sand always runs back: slowly while he casts, fast once he stops
	var casting: bool = hero.act == "cast" or not eye.is_empty() or not lotus.is_empty() or walk or time - cast_t < 0.9
	if not hero.dead:
		var rate := bulb() * (0.02 if casting else 0.25)
		kR = maxf(0.0, kR - rate * dt)
		kA = maxf(0.0, kA - rate * dt)
	kR = clampf(kR, 0.0, bulb())
	kA = clampf(kA, 0.0, bulb())
	sync_res()
	# the sky he holds
	if Game.sky_force != "":
		Game.sky_t -= dt
		if Game.sky_t <= 0.0:
			_end_sky()
	if not sky_flash.is_empty():
		sky_flash["t"] -= dt
		if sky_flash["t"] <= 0.0:
			sky_flash = {}
	# a melee skill walking in
	if not pending.is_empty():
		pending["t"] -= dt
		var pm = pending["m"]
		if pm == null or not is_instance_valid(pm) or pm.dead or pending["t"] <= 0.0 or hero.dead:
			pending = {}
		elif pm.tp.distance_to(hero.tp) <= float(MELEE[pending["id"]]) + pm.radius + 0.2 and hero.act == "":
			var pid: String = pending["id"]
			pending = {}
			hero.walking = false
			cast_anim = "cast"
			cast_len = -1.0
			if use(pid, pm.tp, pm):
				hero._start_act(cast_anim, cast_len if cast_len > 0.0 else 0.55 / st.cast_speed())
		elif not hero.walking:
			hero.walk_to(pm.tp)
	# the halo of paper sutras regrows
	if K("ksutra") > 0:
		var mx := halo_max()
		if halo < mx:
			halo_t += dt
			if halo_t >= (1.4 / 1.3 if aM("kr_brush") else 1.4):
				halo_t = 0.0
				halo += 1
		else:
			halo_t = 0.0
		halo = mini(halo, mx)
	# Amber-That-Eats-Itself
	if amber:
		st.hp = maxf(1.0, st.hp - st.life_max() * 0.01 * dt * (2.0 / 3.0 if aM("kr_wax") else 1.0))
		amber_t -= dt
		if amber_t <= 0.0:
			amber_t = 0.5
			for m in foes(hero.tp, amber_r()):
				hurt(m, D("kamber", 6.5, 3) * 0.5, "kamber")
		if randf() < 0.5:
			var a := randf() * TAU
			var r := randf() * amber_r()
			motes.append({"tp": hero.tp + Vector2(cos(a), sin(a)) * r, "z": randf_range(0, 6), "v": Vector2.ZERO, "vz": randf_range(14, 30), "t": 0.5, "col": Color(1.0, 0.85, 0.44) if randf() < 0.5 else Color(1.0, 0.94, 0.75)})
	# Walks-Without-Feet
	if walk:
		pour(1, 1.5 * dt * (2.0 / 3.0 if aM("ka_pitch") else 1.0))
		walk_t -= dt
		if walk_t <= 0.0:
			walk_t = 1.2
			waves.append({"tp": hero.tp, "t": 0.0, "dur": 0.6, "R": 2.8})
			var d := D("kwalk", 7, 3.2)
			for m in foes(hero.tp, 2.8):
				hurt(m, d, "kwalk")
				if K("kwalkw") > 0:
					m.slow = maxf(m.slow, 0.5)
	# Laughter-Without-Warmth
	if K("klaugh") > 0:
		laugh_t -= dt
		if laugh_t <= 0.0:
			if not foes(hero.tp, laugh_r() + 1.0).is_empty():
				laugh_t = laugh_every()
				_laugh()
			else:
				laugh_t = 0.5
	if obsid > 0.0:
		obsid -= dt
		if obsid <= 0.0:
			obsid = 0.0
			say_at(hero.tp + Vector2(0, -0.4), "the stone softens", Color8(138, 134, 160))
	if mirror_t > 0.0:
		mirror_t -= dt
	if shell_t > 0.0:
		shell_t -= dt
	if last_tp != Vector2.INF and hero.tp.distance_to(last_tp) < 0.002:
		still_t += dt
	else:
		still_t = 0.0
	last_tp = hero.tp
	if not clap2.is_empty():
		clap2["t"] -= dt
		if clap2["t"] <= 0.0:
			for m in foes(hero.tp, clap2["R"]):
				stun(m, clap_stun() * 0.6)
				hurt(m, D("kclap", 6, 2.6) * 0.6, "kclap")
			claps.append({"tp": hero.tp, "t": 0.0, "dur": 0.45, "R": clap2["R"]})
			Sfx.play("heavy", 0.6, 1.6)
			clap2 = {}
	for sl in seals:
		sl["t"] -= dt
		sl["tick"] -= dt
		if sl["tick"] <= 0.0:
			sl["tick"] = 0.5
			for m in foes(sl["tp"], sl["R"]):
				hurt(m, sl["dps"] * 0.5, "ksutra")
	seals = seals.filter(func(q): return q["t"] > 0.0)
	if nothing_t > 0.0:
		nothing_t -= dt
		hero.invuln = maxf(hero.invuln, 0.1)
		for m in foes(hero.tp, 1.6):
			if not m in marks:
				marks.append(m)
				say_at(m.tp, "marked", Color8(154, 148, 168))
		for m in mons():
			if m.tp.distance_to(hero.tp) < 20.0 and (buddha == null or m.tp.distance_to(buddha.tp) > 9.0):
				_lose(m)
		if nothing_t <= 0.0:
			_end_nothing()
	elif Game.sky_force == "night":
		for m in mons():
			if unseen(m) and m.brain and m.brain.state in ["chase", "gap"]:
				_lose(m)
	if not bell.is_empty():
		bell["t"] -= dt
		bell["cd"] = maxf(0.0, bell["cd"] - dt)
		bell["ring"] = maxf(0.0, bell["ring"] - dt)
		bell["drop"] = maxf(0.0, bell["drop"] - dt)
		if bell["t"] <= 0.0:
			bell = {}
	# shadowless creatures bleed spirit
	for m in mons():
		if float(m.get_meta("k_shadow", -1.0)) > now():
			var tk := float(m.get_meta("k_shadow_tick", 0.0)) - dt
			if tk <= 0.0:
				tk = 0.5
				hurt(m, float(m.get_meta("k_shadow_dps", 0.0)) * 0.5, "kspade")
			m.set_meta("k_shadow_tick", tk)
	# the chokepoint: standing in a door or a narrow pass, nothing small presses past
	bar_hold = false
	if K("kbar") > 0:
		var x := floorf(hero.tp.x)
		var y := floorf(hero.tp.y)
		var s := func(i: int, j: int): return zone.is_solid(Vector2(x + i + 0.5, y + j + 0.5))
		bar_hold = (s.call(-1, 0) and s.call(1, 0) and not s.call(0, -1) and not s.call(0, 1)) or (s.call(0, -1) and s.call(0, 1) and not s.call(-1, 0) and not s.call(1, 0))
		if bar_hold:
			for m in foes(hero.tp, 1.2):
				if m.radius >= 0.5 or m.boss or m.flying:
					continue
				var d: float = m.tp.distance_to(hero.tp)
				var need: float = m.radius + hero.radius + 0.35
				if d < need and d > 0.001:
					m.tp = zone.move(m.tp, (m.tp - hero.tp) / d * (need - d), m.radius * 0.6)
	# the float: lotus, sun, walking on nothing
	if leap.is_empty():
		var want := 0.0
		if sun_t > 0.0:
			want = 16.0 + sin(time * 2.0) * 2.0
		elif not lotus.is_empty():
			want = 7.0 + sin(time * 2.4) * 1.2
		elif walk:
			want = 2.0 + sin(time * 3.0) * 0.6
		float_z += (want - float_z) * minf(1.0, dt * 6.0)
		if absf(float_z) < 0.05:
			float_z = 0.0
	if hero.spr:
		hero.spr.position.y = -float_z
		hero.spr.modulate = Color(0.55, 0.5, 0.62, 0.35) if nothing_t > 0.0 else (Color(0.62, 0.6, 0.72) if obsid > 0.0 else Color.WHITE)
	_update_flurry(dt)
	_update_cones(dt)
	_update_fists(dt)
	_update_ofuda(dt)
	_update_tears(dt)
	_update_eye(dt)
	_update_lotus(dt)
	_update_sun(dt)
	_update_palm(dt)
	_update_hands(dt)
	_update_roots(dt)
	_update_leap(dt)
	_update_quake(dt)
	_update_step(dt)
	_update_pagodas(dt)
	_update_thousand(dt)
	if rooted() and hero.act == "":
		hero.walking = false
	for arr in [claps, waves]:
		for q in arr:
			q["t"] += dt
	claps = claps.filter(func(q): return q["t"] < q["dur"])
	waves = waves.filter(func(q): return q["t"] < q["dur"])
	for arr in [beams, spikes, slams, remains, rings, words]:
		for q in arr:
			q["t"] -= dt
	for q in shades:
		q["t"] -= dt
		q["tp"] += q["v"] * dt
	for q in motes:
		q["t"] -= dt
		q["tp"] += q["v"] * dt
		q["z"] = maxf(0.0, q["z"] + q["vz"] * dt)
		q["vz"] -= 60.0 * dt
	beams = beams.filter(func(q): return q["t"] > 0.0)
	spikes = spikes.filter(func(q): return q["t"] > 0.0)
	slams = slams.filter(func(q): return q["t"] > 0.0)
	remains = remains.filter(func(q): return q["t"] > 0.0)
	rings = rings.filter(func(q): return q["t"] > 0.0)
	words = words.filter(func(q): return q["t"] > 0.0)
	shades = shades.filter(func(q): return q["t"] > 0.0)
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
			print("MONK hp %d t=%.0f sand R %.1f A %.1f / %.1f res %.0f/%.0f poise %.0f sky %s(%.1f) dmg {%s}" % [int(st.hp), time, kR, kA, bulb(), st.res, st.res_max(), st.poise, Game.sky_force, sky_k(), ", ".join(parts)])

func _enter_zone() -> void:
	zone = hero.zone
	for arr in [cones, fists, ofuda, tears, geysers, beams, claps, shades, hands, roots, waves, spikes, stepq, pagodas, slams, remains, marks, rings, motes, words, seals]:
		arr.clear()
	flurry = {}
	palm = {}
	thousand = {}
	quake = {}
	leap = {}
	lotus = {}
	eye = {}
	pending = {}
	float_z = 0.0
	faults.clear()
	fx_air = null
	fx_floor = null
	if buddha != null:
		var keep = {"hp": buddha.hp, "max": buddha.max_hp}
		if is_instance_valid(buddha):
			buddha.queue_free()
		buddha = BuddhaView.new()
		buddha.book = self
		buddha.tp = hero.tp + Vector2(1.0, 0.0)
		if zone.is_solid(buddha.tp):
			buddha.tp = hero.tp
		buddha.hp = keep["hp"]
		buddha.max_hp = keep["max"]
		buddha.rise = 0.0
		zone.sorted.add_child(buddha)

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

## --autocast: use the learned skills in turn at the nearest creature (tests)
func _autocast(dt: float) -> void:
	auto_t -= dt
	if auto_t > 0.0 or hero.dead:
		return
	auto_t = float(OS.get_environment("GM_AUTO_T")) if OS.has_environment("GM_AUTO_T") else 1.2
	var ids: Array = auto_ids if not auto_ids.is_empty() else hard.keys()
	ids = ids.filter(func(i): return lvl(i) > 0 and not is_passive(i))
	if ids.is_empty():
		return
	var m := near(hero.tp, 9.0)
	if trace and m == null:
		print("AUTO none: ids ", ids.size(), " mons ", mons().size(), " all ", hero.get_tree().get_nodes_in_group("monsters").size())
	if m == null:
		return
	auto_i = (auto_i + 1) % ids.size()
	var id: String = ids[auto_i]
	demo_at = m.tp
	if id in HOLD:
		auto_hold = id
	cast_anim = "cast"
	cast_len = -1.0
	var okc := hero.act == "" and use(id, m.tp, m)
	if trace:
		print("AUTO ", id, " ok=", okc, " act=", hero.act, " d=", m.tp.distance_to(hero.tp))
	if okc:
		hero._start_act(cast_anim, cast_len if cast_len > 0.0 else 0.55 / hero.st.cast_speed())
	if id in HOLD:
		hero.get_tree().create_timer(1.6).timeout.connect(func(): if auto_hold == id: auto_hold = "")
	demo_at = null
