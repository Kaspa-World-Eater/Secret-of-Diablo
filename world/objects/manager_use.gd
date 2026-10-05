extends "res://world/objects/manager_build.gd"
## The world's objects, part 2 of 3: using things (talking, lanterns, chests, shrines, altars), the vows in the
## world (relics, captives, kneeling waves), kills and Heralds, landmarks' inscriptions, waystones.
## Chain: manager_build (state, building, zone entry) -> manager_use -> manager.gd (the frame, hover, clicks).

# ------------------------------------------------------------------ using things
func _interact(e: Dictionary) -> void:
	if not e["live"]:
		return
	match e["type"]:
		"lantern":
			_touch_lantern(e)
		"vendor", "npc":
			_talk(e)
		"chest":
			_open_chest(e)
		"shrine":
			_use_shrine(e)
		"altar":
			_wake_altar(e)
		"wp":
			_open_waystones()
		"relic":
			_take_relic(e)
		"captive":
			_free_captive(e)
		"qshrine":
			_kneel(e)

func _say(who: String, text: String, inscr: bool = false) -> void:
	if _greeting != "" and not inscr:
		text = _greeting + " " + text
	_greeting = ""
	if ui:
		ui.speak(who, text, -1.0, inscr)

static func _short(s: String) -> String:
	var i := s.find(",")
	return s.substr(0, i) if i >= 0 else s

func _loot():
	return load("res://items/loot.gd") if ResourceLoader.exists("res://items/loot.gd") else null

func _shop():
	return load("res://items/shop.gd") if ResourceLoader.exists("res://items/shop.gd") else null

func _panel(p: String, who: String) -> void:
	if Bus.has_signal("panel_requested"):
		Bus.emit_signal("panel_requested", p, who)

var _greeting := ""            # "Godmarrow." once a day, before the first words (Q.greet)

func _talk(e: Dictionary) -> void:
	var o: Dictionary = e["o"]
	var role: String = "vendor" if e["type"] == "vendor" else String(o.get("role", ""))
	var nm: String = e["name"]
	var s := Q.state()
	if role != "stash":
		_greeting = Q.greet(nm, role)
	match role:
		"vendor":
			_say(_short(nm), Q.bark(act_n, "vendor"))
			_panel("vendor", nm)
		"healer":
			var sh = _shop()
			if sh and sh.has_method("heal"):
				sh.heal(hero, nm)
			else:
				hero.st.hp = hero.st.life_max()
				hero.st.res = hero.st.res_max()
				hero.st.poise = hero.st.poise_max()
			hero.stats_changed.emit()
			_say(_short(nm), Q.bark(act_n, "healer"))
		"smith":
			_say(_short(nm), Q.bark(act_n, "smith"))
			_panel("smith", nm)
		"stash":
			_say(nm, Q.bark(act_n, "stash"), true)
			_panel("stash", nm)
		"giver":
			if not s["seen"].has("giver:" + nm):
				s["seen"]["giver:" + nm] = true
				var pend := Q.pending(act_n)
				var line := ("One vow is still owed." if pend == 1 else "%d vows are still owed." % pend) + " The dead are patient. I am less so." if pend > 0 else "Nothing left here that needs you. Go down."
				_say(_short(nm), line)
			else:
				_say(_short(nm), Q.bark(act_n, "giver"))
			_panel("journal", nm)
		"stranger":
			# his own lines and the voice's take turns
			e["alt"] = not e.get("alt", false)
			if e["alt"]:
				if ui:
					ui.speak_line(Q.stranger_line(act_n), 4.5)
			else:
				_say("The Stranger", Q.bark(act_n, "stranger"))

func _touch_lantern(e: Dictionary) -> void:
	var st := hero.st
	st.hp = st.life_max()
	st.res = st.res_max()
	st.poise = st.poise_max()
	hero.stats_changed.emit()
	Sfx.play("kindle")
	var o: Dictionary = e["o"]
	if "last_lantern" in main:
		main.last_lantern = {"zone": zone.id, "x": e["tp"].x, "y": e["tp"].y, "name": e["name"]}
	if hero.skills:
		hero.skills.on_lantern()
	if main.has_method("save_game"):
		main.save_game()
	var key := "%s:%d" % [zone.id, int(o.get("idx", 0))]
	Q.state()["lanterns"][key] = {"zone": zone.id, "x": e["tp"].x, "y": e["tp"].y, "name": e["name"]}
	_say(e["name"], Q.lantern_inscription(zone.id, o), true)
	_panel("lantern", e["name"])

func _open_chest(e: Dictionary) -> void:
	var mem := Q.obj(zone.id, e["i"])
	if mem.get("open", false):
		return
	mem["open"] = true
	e["live"] = false
	e["name"] = ""
	if is_instance_valid(e["node"]):
		_swap(e["node"], "chest_open")
	Sfx.play("chest")
	var L = _loot()
	if L and L.has_method("open_chest"):
		L.open_chest(zone, e["tp"], int(e["o"].get("ilvl", 1)), hero)

func _use_shrine(e: Dictionary) -> void:
	var o: Dictionary = e["o"]
	var mem := Q.obj(zone.id, e["i"])
	if mem.get("used", false):
		return
	mem["used"] = true
	e["live"] = false
	Sfx.play("shrine")
	_swap(e["node"], "shrine_used")
	var kind: String = o.get("kind", "")
	var st := hero.st
	if kind == "arcana":
		if not Q.state()["done"].has("shrine:" + zone.id):
			Q.state()["done"]["shrine:" + zone.id] = true
			st.arcana_points += 1
			if ui:
				ui.banner("ARCANUM", Color8(232, 214, 160), 3.0)
			Bus.say.emit("A hidden shrine gives up an Arcanum.", 3.0)
	elif kind == "refill":
		st.hp = st.life_max()
		st.res = st.res_max()
		Bus.say.emit(SHRINE_TEXT["refill"], 2.5)
	else:
		_buff(kind, 60.0)
		Bus.say.emit(SHRINE_TEXT.get(kind, "Shrine"), 2.5)
	hero.stats_changed.emit()

## the shrines' blessings last 60 s, kept in hero.st.extra (echo x1.5 skill damage, stone +100 armor, wisp +2 wisps, +100% wisp regrowth)
const BUFF_STATS := {"echo": {"echo": 1.0}, "stone": {"armor": 100.0}, "wisp": {"shrine_wisp": 1.0}}   # echo: skill damage x1.5 (hero_stats.skill_mult); wisp: +2 choir, +100% regrowth (animancer)

func _buff(kind: String, secs: float) -> void:
	var b: Dictionary = Q.state().get("buffs", {})
	Q.state()["buffs"] = b
	if not b.has(kind):
		for k in BUFF_STATS.get(kind, {}):
			hero.st.extra[k] = float(hero.st.extra.get(k, 0.0)) + BUFF_STATS[kind][k]
	b[kind] = secs

func _tick_buffs(dt: float) -> void:
	var b: Dictionary = Q.state().get("buffs", {})
	if b.is_empty() or hero == null:
		return
	for kind in b.keys():
		b[kind] -= dt
		if b[kind] <= 0.0:
			b.erase(kind)
			for k in BUFF_STATS.get(kind, {}):
				hero.st.extra[k] = float(hero.st.extra.get(k, 0.0)) - BUFF_STATS[kind][k]
			hero.stats_changed.emit()

## the altar wakes when you come to it (entities/ai/ai_world.gd AIWorld, which raises the Herald); a click only walks
## you up to it. What we keep: its column goes out once it wakes, and a spent altar stays cold on every return.
func _wake_altar(_e: Dictionary) -> void:
	pass

func _tick_altars() -> void:
	for e in things:
		if e["type"] != "altar":
			continue
		var o: Dictionary = e["o"]
		var woke: bool = o.get("woke", false) or o.get("used", false)
		if woke and e["live"]:
			e["live"] = false
			for c in e["node"].get_children():
				if c is Node2D and c.get("mode") != null:
					c.visible = false
		if o.get("used", false):
			Q.obj(zone.id, e["i"])["used"] = true

func _open_spot(p: Vector2) -> Vector2:
	if not zone.is_solid(p):
		return p
	for r in range(1, 6):
		for k in 12:
			var a := k / 12.0 * TAU
			var q := p + Vector2(cos(a), sin(a)) * r
			if not zone.is_solid(q):
				return q
	return p

func _spawn(kind: String, at: Vector2, level: int, rank: String, mods: Array, pk: String) -> Monster:
	var m: Monster = Brain.spawn(zone, kind, _open_spot(at), level, rank, pk)
	if m and mods.has("Extra Fast"):
		m.mods = mods
		m.speed *= 1.4
	return m

# ------------------------------------------------------------------ vows in the world
func _take_relic(e: Dictionary) -> void:
	var qid: String = e["o"].get("qid", "")
	if Q.st(qid).is_empty() or Q.is_done(qid):
		return
	Q.obj(zone.id, e["i"])["taken"] = true
	e["live"] = false
	_vanish(e["node"])
	Q.complete(qid, hero, zone, e["tp"])

func _free_captive(e: Dictionary) -> void:
	var qid: String = e["o"].get("qid", "")
	if Q.st(qid).is_empty() or Q.is_done(qid):
		return
	var left := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.zone == zone and not m.dead and m.pack == "q" + qid and m.tp.distance_to(e["tp"]) < 12.0:
			left += 1
	if left > 0:
		var who := "Her" if "Nell" in String(e["name"]) or "daughter" in String(e["name"]) else "Its"
		Bus.say.emit("%s keepers still stand (%d). Cut them down first." % [who, left], 2.5)
		return
	Q.obj(zone.id, e["i"])["freed"] = true
	e["live"] = false
	_vanish(e["node"])
	Q.complete(qid, hero, zone, e["tp"])

func _vanish(n: Node2D) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.8)
	tw.tween_callback(n.queue_free)

## the vow's shrine: kneel, and hold it through two waves (5, then 6 with an Extra Fast champion)
func _kneel(e: Dictionary) -> void:
	var qid: String = e["o"].get("qid", "")
	if Q.st(qid).is_empty() or Q.is_done(qid) or not wave.is_empty():
		return
	_start_wave(e, qid, 0)

func _zone_type() -> Array:
	var c := {}
	var lvl := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.zone != zone or m.dead or m.boss or m.rank == "unique" or m.ai == "bomber" or m.has_meta("qwave"):
			continue
		c[m.kind] = c.get(m.kind, 0) + 1
		lvl = maxi(lvl, m.level)
	var best := "hollow"
	var bn := 0
	for k in c:
		if c[k] > bn:
			bn = c[k]
			best = k
	return [best, lvl if lvl > 0 else int(zone.d.get("mlvl", [1, 5])[1])]

func _start_wave(e: Dictionary, qid: String, k: int) -> void:
	var zt := _zone_type()
	var n := 5 if k == 0 else 6
	wave = {"qid": qid, "k": k, "e": e, "t": 1.0}
	var q := Q.quest(qid)
	for i in n:
		var a := float(i) / n * TAU + randf()
		var r := 4.0 + randf() * 2.0
		var p: Vector2 = e["tp"] + Vector2(cos(a), sin(a)) * r
		if zone.is_solid(p):
			continue
		var champ := k == 1 and i == 0
		var m := _spawn(zt[0], p, zt[1], "champion" if champ else "normal", ["Extra Fast"] if champ else [], "qwave_" + qid)
		if m:
			m.set_meta("qwave", qid)
			if m.brain:
				m.brain.wake(m)
			Fx.blood(zone.sorted, m.position + Vector2(0, -20), Vector2.UP, 2)
	Bus.say.emit(("You kneel at %s. The drinkers of light come" % String(q.get("target", "it"))) if k == 0 else "Hold. More of them", 2.5)

func _wave_check() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.zone == zone and not m.dead and m.has_meta("qwave") and m.get_meta("qwave") == wave["qid"]:
			return
	var e: Dictionary = wave["e"]
	var qid: String = wave["qid"]
	if int(wave["k"]) == 0:
		_start_wave(e, qid, 1)
		return
	wave = {}
	Q.obj(zone.id, e["i"])["used"] = true
	e["live"] = false
	var old: Node2D = e["node"]
	e["node"] = _asset_node("shrine_used", e["tp"])
	if is_instance_valid(old):
		old.queue_free()
	Q.complete(qid, hero, zone, e["tp"])

# ------------------------------------------------------------------ kills
func _on_kill(m) -> void:
	if not is_instance_valid(self) or m == null or m.zone != zone:
		return
	Q.on_kill(m, zone, hero)

## a Herald unmade (entities/ai/ai_herald.gd emits it; the Arcana system grants the Major Arcanum): remember the god
## and the altar, and the moment's banner
func _on_herald(m, god: String) -> void:
	if not is_instance_valid(self) or m == null or m.zone != zone:
		return
	var s := Q.state()
	for e in things:
		if e["type"] == "altar" and e["o"].get("god", "") == god:
			Q.obj(zone.id, e["i"])["used"] = true
	if s["done"].has("herald:" + god):
		return
	s["done"]["herald:" + god] = true
	s["majors"] = int(s.get("majors", 0)) + 1
	var g: Dictionary = Q.GODS.get(god, {})
	_later(0.9, func():
		if ui:
			ui.banner("MAJOR ARCANUM", Color8(232, 214, 160), 4.0)
			ui.speak("", "%s is unmade. A Major Arcanum is yours to set in your web (press A)." % g.get("herald", "The Herald"), 4.5))

# ------------------------------------------------------------------ landmarks: name and inscription the first time you pass
func _marks() -> void:
	var best = null
	var bd := 1e9
	var marks: Dictionary = Q.state()["marks"]
	for lm in zone.d.get("landmarks", []):
		var key := "%s:%s" % [zone.id, lm.get("id", "")]
		if marks.has(key):
			continue
		var half := minf(10.0, maxf(float(lm.get("fw", 2)), float(lm.get("fh", 2))) / 2.0)
		var c := Vector2(float(lm.get("x0", 0)) + float(lm.get("fw", 2)) / 2.0, float(lm.get("y0", 0)) + float(lm.get("fh", 2)) / 2.0)
		var d := hero.tp.distance_to(c) - half
		if d < 3.4 and d < bd:
			bd = d
			best = lm
	if best == null:
		return
	marks["%s:%s" % [zone.id, best.get("id", "")]] = true
	if ui:
		ui.whisper(String(best.get("name", "")), String(best.get("inscription", "")))
	mark_cool = 22.0

# ------------------------------------------------------------------ waystones
func _open_waystones() -> void:
	if ui == null:
		return
	Q.kindle_wp(zone.id)
	ui.open_waystones(act_n, zone.id, _travel)

func _travel(id: String) -> void:
	if id == zone.id:
		return
	if passage and passage.begin(id):
		return
	# not standing at one: plain travel, to the destination's waystone
	if passage:
		passage.plain(id)
