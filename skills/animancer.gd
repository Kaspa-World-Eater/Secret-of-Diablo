extends "res://skills/animancer/tree_thread.gd"
## The Hollow Mystic (class id "animancer"), part 5 of 5: casting (which skill runs what), the frame (tick), held
## skills, the views in the zone, the lantern and death, and the --autocast test driver.
## The state, numbers and helpers are in skills/animancer/base.gd (its header lists the API the panels use); each
## tree's skills are in skills/animancer/tree_*.gd.

# ================================================================== casting
func held(id: String) -> bool:
	if hold_force == id or pending_tap == id:
		return true
	if hero == null or hero.dead:
		return false
	if hero.skills.right == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return true
	if hero.skills.left == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return false

## the Mystic's own use(): costs are paid inside each cast (as the web's spendMana), held skills run in tick()
## which of the three the skill belongs to, for its sound: glass, breath or thread
const TREE_OF := {"pillars": "mirror", "golem": "mirror", "fissure": "mirror", "cage": "mirror", "anvil": "mirror",
	"cull": "soul", "totem": "soul", "leash": "thread", "swarm": "thread", "wraith": "thread", "storm": "thread",
	"mark": "thread", "orb": "thread", "word": "thread", "chain": "thread", "lance": "thread"}

func use(id: String, at: Vector2, target: Monster) -> bool:
	if id == "attack" or id == "":
		return false
	if lvl(id) <= 0 or is_passive(id):
		return false
	if id in HOLD:
		if id == "overcharge" and golem == null:
			say("Summon your golem first.", 1.0)
			return false
		pending_tap = id
		return false
	if hero.act != "" and hero.act != "swing" and hero.act != "cast":
		return false
	if aR("a_bell") and time < bell_lock:
		return false
	cf = -1.0 if id in OWN else minf(1.0, float(wisps.size()) / maxi(1, eff_cap()))
	var ok := false
	ok = _cast(id, at, target)
	cf = -1.0
	if ok:
		Sfx.play("cast_" + str(TREE_OF.get(id, "soul")))
		if id != "wraith":
			end_wraith()
		# The Bell-Warden: every fifth spell rings; reversed, the bell silences you a breath
		if aU("a_bell"):
			bell_n += 1
			if bell_n % 5 == 0:
				ring(hero.tp, 3.5, 0.5, 0.4)
				for m in mons():
					if m.tp.distance_to(hero.tp) < 3.5 + m.radius and not m.boss:
						m.stun = maxf(m.stun, 0.5)
		if aR("a_bell"):
			bell_lock = time + 1.0
		hero.stats_changed.emit()
	return ok

func _cast(id: String, at: Vector2, target: Monster) -> bool:
	if target != null and is_instance_valid(target):
		at = target.tp
	at = _los_point(at)
	match id:
		"pillars": return _cast_pillars(at)
		"golem": return _cast_golem(at)
		"fissure": return _cast_fissure(at)
		"cage": return _cast_cage(at)
		"anvil": return _cast_anvil(at)
		"cull": return _cast_cull(at)
		"swarm": return _cast_swarm(at)
		"wraith": return _toggle_wraith()
		"storm": return _cast_storm(at)
		"mark": return _cast_mark(at)
		"orb": return _cast_orb(at)
		"leash": return _cast_leash(at)
		"word": return _cast_word(at)
		"chain": return _cast_chain(at)
		"totem": return _cast_totem(at)
	return false

## skills need sight: a point behind a wall is pulled back to it (d_play.js losPoint)
func _los_point(a: Vector2) -> Vector2:
	var d := a.distance_to(hero.tp)
	if d < 0.3:
		return a
	var n := int(ceil(d / 0.2))
	var last := hero.tp
	for i in range(1, n + 1):
		var p := hero.tp.lerp(a, float(i) / n)
		if zone.blocks_sight(p):
			return last
		last = p
	return a


# ================================================================== the frame
func tick(dt: float) -> void:
	if hero == null or hero.zone == null:
		return
	time += dt
	if zone != hero.zone:
		_enter_zone()
	if _was_dead:
		_was_dead = false
	_upkeep(dt)
	_holds(dt)
	_update_wisps(dt)
	_update_great(dt)
	_update_fx(dt)
	_update_souls(dt)
	_update_mirrors(dt)
	_update_fissures(dt)
	_update_orbs(dt)
	_update_storms(dt)
	_update_words(dt)
	_update_binds(dt)
	_update_threads(dt)
	_update_totems(dt)
	_update_darts(dt)
	_update_whips(dt)
	_update_phantoms(dt)
	_arcana_tick(dt)
	if golem != null:
		golem.tick(dt)
	_push_out()
	_views()
	if auto_on:
		_autocast(dt)
	if trace:
		trace_t -= dt
		if trace_t <= 0.0:
			trace_t = 5.0
			var parts := []
			var sts := {}
			for w in wisps:
				sts[w.state] = int(sts.get(w.state, 0)) + 1
			var near := mons().filter(func(q): return q.tp.distance_to(hero.tp) < 6.0).map(func(q): return "%s:%s:%.1f" % [q.kind, q.brain.state if q.brain else "-", q.tp.distance_to(hero.tp)])
			print("   states ", sts, " near ", near, " hero ", hero.tp, " act ", hero.act)
			for k in dmg_log:
				parts.append("%s=%d" % [k, int(dmg_log[k])])
			print("MYS t=%.0f wisps %d/%d res %.0f/%.0f golem %s great %s mirrors %d souls %d threads %d dmg {%s}" % [time, wisps.size(), eff_cap(),
				hero.st.res, hero.st.res_max(), (golem.state + " " + str(int(golem.hp))) if golem != null else "-",
				str(great.size) if great != null else "-", mirrors.size(), souls.size(), threads.size(), ", ".join(parts)])

func _enter_zone() -> void:
	zone = hero.zone
	# what was cast stays behind; the choir, the golem and the great wisp come along
	for o in mirrors:
		o.gone = true
	mirrors.clear()
	for t in totems:
		t.gone = true
		for w in t.wisps:
			w.gone = true
	totems.clear()
	for arr in [cages, fissures, cracks, spikes, glass, gshots, rings, fires, souls, sparks, needles, snags, binds, threads, darts, dart_lines, orbs, shards, storms, words, whips, phantoms]:
		arr.clear()
	for w in wisps:
		w.tp = hero.tp
		w.state = "drift"
		w.cd = 0.4
		w.node = null
	if great != null:
		great.tp = hero.tp
		great.target = null
		great.node = null
	if golem != null:
		golem.tp = walkable_near(hero.tp + Vector2(0.8, 0))
		golem.atk = {}
		golem.path = PackedVector2Array()
		golem.order = {}
		golem.fly = {}
		golem.shield = true
		if golem.state == "charge" or golem.state == "chargeWind":
			golem.state = "active"
		if gbeh["hold"]:
			golem.hold = golem.tp
		golem.node = null
	fx_air = null
	fx_floor = null
	if wisps.is_empty():
		for i in eff_cap():
			spawn_wisp()

## Essence while in Wraith Form (it drains, and does not come back), Thread Mastery's regen, the Veil's
## looks, the wraith's speed and its afterimages
func _upkeep(dt: float) -> void:
	var st = hero.st
	var base: float = st.res_regen()
	if wraith:
		st.res = maxf(0.0, st.res - base * dt - ws_wraith_drain() * dt)
		if st.res <= 0.0:
			end_wraith()
			say("Your Essence gives out.", 1.2)
		if hero.act in ["atk", "atk2", "swing", "roll", "heavy"]:
			end_wraith()
	elif K("nmastery") > 0:
		st.res = minf(st.res_max(), st.res + base * 0.05 * K("nmastery") * dt)
	if wraith:
		hero.spr.modulate = Color(0.78, 0.86, 1.0, 0.55)
		# the wraith is quicker (x1.2..1.35): the extra stride along the hero's own path
		if hero.walking and hero.path_i < hero.path.size():
			var wp: Vector2 = hero.path[hero.path_i]
			var to := wp - hero.tp
			var extra := st.move_speed() * (ws_wraith_spd() - 1.0) * dt
			if to.length() > 0.05:
				hero.tp = zone.move(hero.tp, to.normalized() * minf(extra, to.length() - 0.02), hero.radius)
		# Phantom Step
		if K("phantom") > 0 and hero.walking:
			phantom_t -= dt
			if phantom_t <= 0.0:
				phantom_t = 0.3
				phantoms.append({"tp": hero.tp, "t": 0.8, "tex": hero.spr.texture, "off": hero.spr.offset, "flip": hero.spr.flip_h})
	if hero.dead:
		end_wraith()
		infusing = false
		condensing = false
		proc["on"] = false

# ------------------------------------------------------------------ held skills: Needle and Thread, Condense, Procession, Overcharge
func _root() -> void:
	hero.walking = false
	hero.target = null
	if hero.act == "":
		hero._start_act("cast", 0.3)

func _holds(dt: float) -> void:
	var rolling: bool = hero.act == "roll" or hero.act == "stun"
	var a := aim_point()
	# Overcharge (or Condense with the cursor on the golem): pour wisps into it
	var cond_on_golem: bool = golem != null and K("overcharge") > 0 and held("condense") and a.distance_to(golem.tp) < 1.6
	var want_inf: bool = (cond_on_golem or (held("overcharge") and K("overcharge") > 0)) and golem != null and not rolling
	if want_inf and not infusing:
		infusing = true
		inf_t = 0.0
		end_wraith()
	if infusing and not want_inf:
		infusing = false
	if infusing:
		_root()
		inf_t -= dt
		if inf_t <= 0.0:
			inf_t = 0.16
			_infuse_one()
		if golem != null:
			hero._face(golem.tp - hero.tp)
	# Needle and Thread: a darting wisp with every pulse while held
	an_hold = an_hold + dt if (held("lance") and K("lance") > 0) else 0.0
	if held("lance") and K("lance") > 0 and not rolling and not infusing:
		lance_t -= dt
		if lance_t <= 0.0 and hero.act in ["", "cast"]:
			if spend("lance"):
				end_wraith()
				hero._face(a - hero.tp)
				var cs: float = 1.0 + hero.st.item("fcr") / 100.0
				lance_t = 0.42 / cs
				hero._start_act("cast", 0.22 / cs)
				hero.walking = false
				hero.target = null
				_lance_pulse(a)
				hero.stats_changed.emit()
			else:
				lance_t = 0.3
	else:
		lance_t = 0.0
	# Condense: crush wisps into the great wisp
	condensing = not infusing and held("condense") and K("condense") > 0 and not rolling
	if condensing:
		end_wraith()
		_root()
		cond_t -= dt
		if cond_t <= 0.0:
			cond_t = ws_cond_rate()
			_condense_one()
			hero.stats_changed.emit()
	else:
		cond_t = 0.0
	# Procession: the choir circles the cursor while held, a little Essence a second
	var want_p: bool = K("proc") > 0 and held("proc") and not rolling and not hero.dead
	if want_p:
		var need: float = float(data.get("proc", {}).get("cost", {}).get("base", 3.6)) * dt
		if hero.st.res < need:
			if proc["on"]:
				say("Your Essence is spent.", 0.8)
			proc["on"] = false
		else:
			hero.st.res -= need
			var d := a - hero.tp
			proc["tp"] = hero.tp + d.normalized() * 8.0 if d.length() > 8.0 else a
			proc["on"] = true
			proc["t"] = float(proc["t"]) + dt
	elif proc["on"]:
		proc["on"] = false
		for w in wisps:
			w.state = "drift"
			w.cd = 0.3
	pending_tap = ""


# ------------------------------------------------------------------ the views in the zone
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
	for w in wisps:
		_wisp_view(w)
	if great != null:
		_wisp_view(great)
	for t in totems:
		_prop_view(t)
		for w in t.wisps:
			_wisp_view(w)
	for o in mirrors:
		_prop_view(o)
	if golem != null and (golem.node == null or not is_instance_valid(golem.node)):
		var gv := GolemView.new()
		zone.sorted.add_child(gv)
		gv.setup(golem)

func _wisp_view(w: Wisp) -> void:
	if w.node == null or not is_instance_valid(w.node):
		var v := WispView.new()
		zone.sorted.add_child(v)
		v.setup(w)

func _prop_view(o: Mirror) -> void:
	if o.node == null or not is_instance_valid(o.node):
		var v := PropView.new()
		zone.sorted.add_child(v)
		v.setup(o)


func _on_kill(m) -> void:
	if hero == null or m == null or not is_instance_valid(m) or hero.zone == null or m.zone != hero.zone:
		return
	if aU("v_unwritten"):
		hero.st.res = minf(hero.st.res_max(), hero.st.res + hero.st.res_max() * 0.05)
	if m.marked > 0.0 and m.has_meta("mys_mark") and K("markSoul") > 0:
		new_soul(m.tp, randf() * TAU, 5.0, ws_soul_dmg())
	var hv := ws_harvest()
	if hv > 0.0 and randf() < hv and wisps.size() < eff_cap():
		spawn_wisp(m.tp)
	# the Soul Lantern: each death in its light frees a wisp and mends a little
	if float(m.get_meta("mys_lantern", -1.0)) > time and not totems.is_empty() and m.tp.distance_to(totems[0].tp) < 4.5:
		if wisps.size() < eff_cap():
			spawn_wisp(m.tp)
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.02)
	if K("hymn") > 0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.01 * (wisps.size() / 3))
	if K("lastword") > 0:
		hero.st.res = minf(hero.st.res_max(), hero.st.res + 3.0)
	if last_hit == m:
		last_hit = null

# ================================================================== the test driver (--autocast)
func _autocast(dt: float) -> void:
	if hero.dead:
		return
	auto_t -= dt
	# go to the nearest creature the hero can see (the demo's own pick may sit behind rocks)
	var seen = Combat.nearest_monster(zone, hero.tp, 40.0, true)
	if seen != null and hold_force == "" and not auto_stand:
		hero.target = seen
	var m = Combat.nearest_monster(zone, hero.tp, 9.0, true)
	if hold_force != "":
		if m != null:
			demo_at = m.tp
		if auto_t <= 0.0:
			hold_force = ""
			demo_at = null
			auto_t = 0.4
		return
	if auto_t > 0.0 or m == null:
		if auto_t <= 0.0 and OS.get_cmdline_user_args().has("--autodbg"):
			print("AUTO no target")
		return
	var ids: Array = auto_ids if not auto_ids.is_empty() else data.keys().filter(func(k): return not is_passive(k))
	ids = ids.filter(func(k): return lvl(k) > 0)
	if ids.is_empty():
		return
	auto_i = (auto_i + 1) % ids.size()
	var id: String = ids[auto_i]
	auto_t = 1.1
	if id in HOLD:
		hold_force = id
		demo_at = m.tp
		auto_t = 1.6
		return
	if id == "wraith" and wraith:
		return
	var at: Vector2 = m.tp
	if id == "golem" and golem != null:
		at = hero.tp + (m.tp - hero.tp) * 0.5
	if hero.act == "" or hero.act == "cast":
		hero.act = ""
		hero._face(at - hero.tp)
		if use(id, at, m):
			hero._start_act("cast", 0.55 / hero.st.cast_speed())
			hero.walking = false
		elif OS.get_cmdline_user_args().has("--autodbg"):
			print("AUTO fail ", id, " act=", hero.act, " res=", hero.st.res, " cost=", cost(id), " lvl=", lvl(id))

# ================================================================== for the monster AI helper
## the nearest of the hero and the standing allies to a creature (or a point); Dazzling Challenge draws a
## challenged creature to the golem for its 3 s
static func nearest_target(z, from):
	var p: Vector2 = from.tp if (from is Node2D and "tp" in from) else from
	if from is Node2D and from.has_meta("mys_taunt_by"):
		var by = from.get_meta("mys_taunt_by")
		var until := float(from.get_meta("mys_taunt_until", 0.0))
		if is_instance_valid(by) and by.is_in_group("allies") and Time.get_ticks_msec() / 1000.0 < until:
			return by
	var best = null
	var bd := INF
	var h = z.hero_ref
	if h != null and not h.dead:
		best = h
		bd = p.distance_to(h.tp)
	for a in z.get_tree().get_nodes_in_group("allies"):
		if a.has_method("is_down") and a.is_down():
			continue
		var d: float = p.distance_to(a.tp)
		if d < bd:
			bd = d
			best = a
	return best


# ================================================================== the lantern and death (checklist 18.4, 18.5)
func on_lantern() -> void:
	while wisps.size() < eff_cap():
		spawn_wisp()
	if golem != null:
		if golem.state == "dormant":
			golem.rise()
		golem.hp = golem.max_hp
	elif not golem_mem.is_empty():
		golem_mem["frac"] = 1.0
		golem_mem["dormant"] = false

func on_death() -> void:
	for w in wisps:
		w.gone = true
		if w.node != null and is_instance_valid(w.node):
			w.node.queue_free()
	wisps.clear()
	great = null
	if golem != null:
		if golem.node != null and is_instance_valid(golem.node):
			golem.node.queue_free()
		golem.node = null
		golem = null
	golem_mem = {}
	infusing = false
	for arr in [mirrors, totems, cages, fissures, cracks, spikes, glass, gshots, rings, fires]:
		for o in arr:
			if o is Object and "gone" in o:
				o.gone = true


## the bar's gauge (ui/bar.gd): the choir's wisps as pips
func hud_gauge() -> Dictionary:
	return {"text": "WISPS %d/%d" % [wisps.size(), wisp_cap()], "pips": wisps.size(), "max": wisp_cap(), "col": Color8(191, 232, 255)}
