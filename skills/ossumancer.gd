extends "res://skills/ossumancer/tree_count.gd"
## The Ossuarch (class id "ossumancer"), part 5 of 5: casting (which skill runs what), the hooks the shared game calls,
## and the frame (tick). The state, numbers and helpers are in skills/ossumancer/base.gd (its header tells how the
## Mantle works); each tree's skills are in skills/ossumancer/tree_*.gd.
## Ported so far: the Ossuary and Carapace trees, Bone Blade. The Count follows.

const DONE := ["aura", "spear", "raise", "blade", "barmor", "siphon", "ribcage", "ossify", "spikes", "sstorm", "bonerain", "spirit",
	"offering", "unearth", "horn", "colossus", "host"]

var mantle_set := false

# ================================================================== casting
func use(id: String, at: Vector2, target: Monster) -> bool:
	if id == "attack" or id == "" or hero == null or zone == null:
		return false
	if lvl(id) <= 0 or is_passive(id) or not id in DONE:
		return false
	if hero.act != "" and hero.act != "swing" and hero.act != "cast":
		return false
	if target != null and is_instance_valid(target):
		at = target.tp
	at = _los_point(at)
	var c := cost(id)
	if hero.st.res < c:
		say("Not enough Marrow.", 1.0)
		return false
	var pc := poise_cost(id)
	if pc > 0.0 and hero.st.poise < pc * 0.5:
		say("Too weary.", 0.8)
		return false
	if shards < shard_cost(id):
		say("Not enough bone shards.", 1.1)
		return false
	cast_anim = POSE.get(id, "cast")
	if not _cast(id, at, target):
		return false
	pay_shards(id)
	hero.st.res -= c
	if trace:
		dmg_log["_spent"] = float(dmg_log.get("_spent", 0.0)) + c
	if pc > 0.0:
		hero.spend_poise(pc)
	if cast_len < 0.0:
		cast_len = 0.4 / hero.st.cast_speed()
	hero._face(at - hero.tp)
	hero.stats_changed.emit()
	return true

func _cast(id: String, a: Vector2, target) -> bool:
	match id:
		"aura":
			pull_hold = 0.35
			cast_len = 0.3
			return true
		"blade":
			return cast_blade(a, target)
		"barmor":
			return cast_armor()
		"offering":
			return cast_offering(a)
		"unearth":
			return cast_unearth(a)
		"horn":
			return cast_march()
		"colossus":
			cast_len = 0.3
			return press_colossus(a)
		"host":
			cast_len = 0.3
			return press_host()
		"spirit":
			return cast_lord(a)
	if _cast_bone(id, a):
		echo(id, a)
		return true
	return false


# ================================================================== hooks the shared game calls
## the Bone Host: every skeleton fused onto him makes his blows heavier and his step quicker
func melee_k() -> float:
	return 1.0 + host_melee() * int(host.get("n", 0))

func move_k() -> float:
	return 1.0 + 0.03 * mini(8, int(host.get("n", 0)))

func hud_gauge() -> Dictionary:
	var extra := ""
	if colossus != null:
		extra = " · COLOSSUS %d" % colossus.n
	elif int(host.get("n", 0)) > 0:
		extra = " · HOST %d" % int(host["n"])
	return {"text": "SHARDS %d/%d · DEAD %d%s" % [int(shards), mantle_cap(), skels.size(), extra], "pips": skels.size(), "max": skel_max(), "col": BONE}

func before_hit(d: float, _elem: String, _from: Vector2, opts: Dictionary) -> float:
	# Bone Spurs (the Mantle at 5): a creature that strikes him in melee is cut by his shards
	var by = opts.get("by", Combat.striker if Combat.striker_frame == Engine.get_physics_frames() else null)
	if K("spurs") > 0 and shards >= 1.0 and by != null and is_instance_valid(by) and by.tp.distance_to(hero.tp) < 2.2:
		hurt(by, spurs_dmg(), "aura", {"poise": 0.0})
	return d

func on_lantern() -> void:
	hero.st.res = hero.st.res_max()
	shards = free_cap()
	for e in skels:
		if is_instance_valid(e):
			e.hp = e.max_hp

func on_death() -> void:
	_reset()

func _reset() -> void:
	clear_dead()
	host = {}
	march_t = 0.0
	clear_spells()
	plates = 0.0
	shards = 0.0
	motes.clear()
	spears.clear()
	pull_hold = 0.0

func _on_kill(m) -> void:
	if hero == null or hero.cls != "ossumancer" or not is_instance_valid(m):
		return
	ossified_death(m)
	spiked_death(m)
	# Grave Tithe: the slain give up bone (always two from champions and uniques with Full Tithe)
	if K("tithe") > 0:
		var big: bool = K("tithemore") > 0 and m.rank in ["champion", "unique"]
		var n := 2 if big else (1 if randf() < minf(0.4, 0.12 + 0.012 * K("tithe")) else 0)
		for i in n:
			motes.append({"tp": m.tp, "z": 0.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": mote_dmg(), "hit": {}, "val": 1.0})
			if K("tithemend") > 0:
				hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.01)

func _arg(k: String, _v: String) -> void:
	match k:
		"ossutrace":
			trace = true
		"shards":   # tests: start with a full Mantle
			shards = 999.0

# ================================================================== the frame
func tick(dt: float) -> void:
	if hero == null or hero.zone == null:
		return
	time += dt
	if zone != hero.zone:
		_enter_zone()
	if not mantle_set:   # he comes into the Hide with his Mantle about him (and carries it from place to place)
		mantle_set = true
		shards = mantle_cap()
	_views()
	tick_mantle(dt)
	tick_fusing(dt)
	tick_dead(dt)
	tick_charge(dt)
	tick_blade(dt)
	for f in blade_fx:
		f["t"] += dt
	blade_fx = blade_fx.filter(func(f): return f["t"] < 0.5)
	tick_spears(dt)
	tick_cages(dt)
	tick_rains(dt)
	tick_lords(dt)
	tick_ossified()
	for f in spikes_fx:
		f["t"] -= dt
	spikes_fx = spikes_fx.filter(func(f): return f["t"] > 0.0)
	for f in siph_fx:
		f["t"] -= dt
	siph_fx = siph_fx.filter(func(f): return f["t"] > 0.0)
	for g in grit:
		g["t"] -= dt
	grit = grit.filter(func(g): return g["t"] > 0.0)
	for w in words:
		w["t"] -= dt
	words = words.filter(func(w): return w["t"] > 0.0)
	# hold to keep striking
	if hero.act == "" and not hero.dead:
		for id in ["blade", "siphon"]:
			if K(id) > 0 and held(id):
				cast_anim = POSE.get(id, "cast")
				cast_len = -1.0
				if use(id, aim_point(), null):
					hero._start_act(cast_anim, cast_len)
				break
	if auto_on:
		_autocast(dt)
	if trace:
		trace_t -= dt
		if trace_t <= 0.0:
			trace_t = 5.0
			print("OSSU hp %.0f res %.0f/%.0f shards %.1f/%d dead %d dmg %s" % [hero.st.hp, hero.st.res, hero.st.res_max(), shards, mantle_cap(), skels.size(), str(dmg_log)])

func _enter_zone() -> void:
	clear_dead()
	zone = hero.zone
	motes.clear()
	clear_spells()
	grit.clear()
	words.clear()
	fx_air = null
	fx_floor = null
	rise_t = 0.5

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

# ================================================================== the test driver (--autocast)
func _autocast(dt: float) -> void:
	auto_t -= dt
	auto_hold_t -= dt
	if auto_t > 0.0 or hero.dead or hero.act != "" or not charging.is_empty():
		return
	auto_t = 0.6
	var ids: Array = auto_ids if not auto_ids.is_empty() else hard.keys()
	ids = ids.filter(func(i): return lvl(i) > 0 and not is_passive(i) and i in DONE)
	if ids.is_empty():
		return
	var m := near(hero.tp, 9.0)
	if m == null:
		return
	auto_i = (auto_i + 1) % ids.size()
	var id: String = ids[auto_i]
	demo_at = m.tp
	if id == "offering" and not skels.is_empty():
		demo_at = skels[0].tp
	cast_anim = POSE.get(id, "cast")
	cast_len = -1.0
	if id == "blade" and m.tp.distance_to(hero.tp) > hero._reach() + 0.6 + m.radius:
		hero.walk_to(m.tp)
	elif use(id, demo_at, m if id != "offering" else null):
		hero._start_act(cast_anim, cast_len)
		if id == "spear" and not charging.is_empty():
			charging["goal"] = randi() % 4
		if id == "blade" and not bcharge.is_empty():
			bcharge["goal"] = randi() % 3
		if id in ["colossus", "host", "aura"]:
			auto_hold = id
			auto_hold_t = 2.0
			auto_t = 2.2
	elif trace:
		print("AUTO ", id, " refused: act '", hero.act, "' res ", hero.st.res, " shards ", shards, " poise ", hero.st.poise)
	demo_at = null
