extends "res://skills/ossumancer/tree_ossuary.gd"
## The Ossuarch, part 3 of 5: the Carapace tree, bone spells and plate. His own bone grows straight and ordered;
## bone in his enemies and the ground grows wild (lumps, spurs). No glow: bone is matter.
##  Mantle: the shards he pulls out of the ground hang about him as armour, army and fuel; hold to pull four times as fast.
##  Bone Lance: a spear grows out of the ground in a dead-straight line, piercing everything in it.
##  Bone Armor: plates lock over him and drink blows until they crack; while his dead stand within 4 yd, the nearest
##    takes a share of every blow meant for him (Shield of Bones folded in).
##  Marrow Siphon: a cone before him; the struck wither, and a shard flies home from each (four at most).
##  Charnel Cage: ribs and arms grow up round the target and close: they hold what is inside and cut it.
##  Ossify: their own bones overgrow and fuse (8 s: 30% slower, +20% taken); an ossified thing bursts into shards.
##  Bone Spurs: spurs erupt from the wounded thing nearest the cursor and gore everything within a step of it.
##  Shard Storm: the Mantle driven outward in a fan of straight splinters (his armour goes with them).
##  Bone Rain: shards of star-bone fall straight out of the dark over the target for 2 s.
##  Pale Lord: a warden of old bone on a white waymark; every bone spell he casts is cast again from it.
##  Bone Mastery: bone spells strike harder, and a thin Mantle weakens them less.

# ------------------------------------------------------------------ the Mantle
func tick_mantle(dt: float) -> void:
	pull_hold = maxf(0.0, pull_hold - dt)
	if pull_hold > 0.0:
		hero.walking = false
		if randf() < dt * 8.0:
			var a := randf() * TAU
			dust(hero.tp + Vector2(cos(a), sin(a)) * randf_range(0.6, 2.2), 1)
	var free := free_cap()
	shards = minf(shards, free)
	var in_flight := 0.0
	for b in motes:
		in_flight += float(b.get("val", 1.0))
	if shards + in_flight < free and not hero.dead:
		shard_t += dt * pull_rate()
		while shard_t >= 1.0:
			shard_t -= 1.0
			_tear_shard()
	else:
		shard_t = minf(shard_t, 0.9)
	_fly_shards(dt)

## a shard tears up out of the ground: behind a creature when one is near (so it cuts it on the way in)
func _tear_shard() -> void:
	var R := pull_r()
	var p: Vector2
	var near_foes: Array = foes(hero.tp, R - 0.3).filter(func(m): return m.awake)
	if not near_foes.is_empty() and randf() < 0.65:
		var m = near_foes.pick_random()
		var d: float = maxf(0.01, m.tp.distance_to(hero.tp))
		var dir: Vector2 = (m.tp - hero.tp) / d
		p = hero.tp + dir * minf(R, d + randf_range(0.6, 1.8)) + dir.orthogonal() * randf_range(-0.4, 0.4)
	else:
		var a := randf() * TAU
		p = hero.tp + Vector2(cos(a), sin(a)) * randf_range(R * 0.45, R)
	if zone.is_solid(p):
		p = hero.tp + (p - hero.tp) * 0.5
	motes.append({"tp": p, "z": 0.0, "rise": 0.22, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": mote_dmg(), "hit": {}, "val": 1.0})
	dust(p, 2)

func _fly_shards(dt: float) -> void:
	for b in motes:
		b["t"] += dt
		if b["rise"] > 0.0:
			b["rise"] -= dt
			b["z"] = 7.0 * (1.0 - maxf(0.0, b["rise"]) / 0.22)
			continue
		if b["out"] > 0.0:
			b["out"] -= dt
			b["tp"] += b["v"] * dt
			b["z"] = 6.0
		else:
			var to: Vector2 = hero.tp - b["tp"]
			var d := to.length()
			b["spd"] = minf(15.0, b["spd"] + 22.0 * dt)
			b["tp"] += to / maxf(d, 0.001) * minf(d, b["spd"] * dt)
			b["z"] = 6.0 + sin(b["t"] * 10.0) * 1.2
			if d < 0.35 or hero.dead:
				b["done"] = true
				if not hero.dead:
					shards = minf(free_cap(), shards + b["val"])
					plates_on_shard()
					if K("reforge") > 0:
						hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.015 * b["val"])
				continue
		if b["dmg"] > 0.0:
			for m in mons():
				if b["hit"].has(m) or m.tp.distance_to(b["tp"]) > m.radius + 0.15:
					continue
				b["hit"][m] = true
				hurt(m, b["dmg"], "aura", {"poise": 0.0})
		if b["t"] > 4.0:
			b["done"] = true
	motes = motes.filter(func(b): return not b.get("done", false))

## what reaches him: the plates drink first, then the nearest of his dead takes a share, then the Mantle turns part
## of what is left, and now and then a shard is knocked loose
func absorb(d: float, _elem: String) -> float:
	d = host_absorb(d)
	if plates > 0.0:
		var soak := minf(plates, d)
		plates -= soak
		d -= soak
		if plates <= 0.0:
			plates = 0.0
			say_at(hero.tp, "the plates crack")
			dust(hero.tp, 10)
			Sfx.play("break", 0.5, 1.2)
	if d > 0.0 and ward_share() > 0.0:
		var near_dead = null
		var bd := 4.0
		for e in skels:
			if is_instance_valid(e) and not e.gone and e.rise <= 0.0 and e.tp.distance_to(hero.tp) < bd:
				bd = e.tp.distance_to(hero.tp)
				near_dead = e
		if near_dead != null:
			var share := d * ward_share()
			near_dead.take_hit(share, "phys")
			d -= share
	d *= 1.0 - turned()
	if shards >= 1.0 and d > 1.0 and randf() < 0.25:
		shards -= 1.0
		dust(hero.tp, 2)
	return d

# ------------------------------------------------------------------ Bone Lance
## Hold to charge (the user, 2026-09-30: "charge tiers ... grow bigger, with more subtle glow each time", D2's Bone
## Spear but solid bone in our colours). A tap throws the plain lance. Held, a lance grows out of the ground at his
## side, drawing a shard from the Mantle at each tier: 0.35 s, 0.8 s, 1.3 s. Release (or a full charge held 0.3 s)
## and it flies: bigger, harder and farther with each tier, a faint warmth of marrow in the bone that deepens.
##   tier 0: x1        tier 1: x1.5 wider        tier 2: x2.2, splinters        tier 3: x3.2, impales and shoves
const LANCE_T := [0.35, 0.8, 1.3]
const LANCE_K := [1.0, 1.5, 2.2, 3.2]
var charging := {}            # {t, tier, at, goal (autocast)}

func cast_lance(a: Vector2, tier: int = -1) -> bool:
	if tier < 0 and origin == null:
		# his own cast: begin the charge (a tap is a tier-0 lance, thrown on release)
		charging = {"t": 0.0, "tier": 0, "at": a}
		cast_len = 4.0
		return true
	_throw_lance(a, maxi(0, tier))
	return true

func _throw_lance(a: Vector2, tier: int) -> void:
	var o := from_tp()
	var dir := (a - o).normalized() if a.distance_to(o) > 0.05 else Vector2(1, 1).normalized()
	spears.append({"tp": o + dir * 0.3, "v": dir * (13.0 + tier), "t": 0.75 + 0.12 * tier, "dmg": spear_dmg() * LANCE_K[tier], "hit": {},
		"splint": K("splinter") > 0 or tier >= 2, "main": true, "small": false, "pierce": 0, "tier": tier, "R": 0.2 + 0.08 * tier, "opt": echo_opt()})
	Sfx.play("cast_mirror", 0.6 + 0.1 * tier, 0.75 - 0.08 * tier)
	spear_casts.append({"at": o + dir * 0.3, "t": 0.0, "tier": tier})
	if tier >= 2:
		Game.shake(1.0 + tier)

## the charge grows while the button is held; released (or full), the lance flies, and the Pale Lords throw theirs
func tick_charge(dt: float) -> void:
	if charging.is_empty():
		return
	if hero.dead or hero.act == "roll" or hero.act == "stun":
		charging = {}
		return
	charging["t"] += dt
	if not charging.has("goal"):
		charging["at"] = aim_point()   # he turns the growing lance to follow the cursor (a test's aim stays put)
	hero.walking = false
	hero._face(charging["at"] - hero.tp)
	if hero.act == "cast":
		hero.act_t = minf(hero.act_t, hero.act_len * 0.45)   # hold the raised pose while it grows
	var tier: int = charging["tier"]
	if tier < 3 and charging["t"] >= LANCE_T[tier]:
		if shards >= 1.0:
			shards -= 1.0
			charging["tier"] = tier + 1
			dust(hero.tp, 4)
			Sfx.play("break", 0.25, 1.6 - 0.2 * tier)
		else:
			charging["t"] = LANCE_T[tier]   # no bone left to grow it with
	var goal: int = int(charging.get("goal", -1))
	var release: bool = not held("spear") if goal < 0 else charging["tier"] >= goal
	if charging["tier"] >= 3 and charging["t"] > LANCE_T[2] + 0.3:
		release = true
	if release:
		var at: Vector2 = charging["at"]
		var tr: int = charging["tier"]
		charging = {}
		_throw_lance(at, tr)
		for l in lords:
			if is_instance_valid(l["node"]):
				origin = l["tp"]
				force = echo_k()
				_throw_lance(at, tr)
				origin = null
				force = 1.0
		if hero.act == "cast":
			hero.act_t = maxf(hero.act_t, hero.act_len - 0.15)

## lances, splinters and the Storm's shards in flight: straight, piercing, stopped by walls
func tick_spears(dt: float) -> void:
	for s in spears:
		s["t"] -= dt
		for k in 3:
			if s["t"] <= 0.0:
				break
			var nxt: Vector2 = s["tp"] + s["v"] * dt / 3.0
			if zone.blocks_sight(nxt):
				s["t"] = 0.0
				dust(s["tp"], 6)
				break
			s["tp"] = nxt
			for m in mons():
				if s["hit"].has(m) or m.tp.distance_to(s["tp"]) > m.radius + float(s.get("R", 0.2)):
					continue
				s["hit"][m] = true
				var opt: Dictionary = s["opt"].duplicate()
				opt["from"] = s["tp"] - s["v"].normalized()
				hurt(m, s["dmg"], s.get("id", "spear"), opt)
				dust(m.tp, 3)
				if s["main"]:
					spear_hits.append({"at": m.tp, "v": s["v"], "t": 0.0, "tier": int(s.get("tier", 0))})
				var tier: int = int(s.get("tier", 0))
				if s["main"] and (K("impale") > 0 or tier >= 3) and m.rank != "boss":
					m.stun = maxf(m.stun, 0.6 + 0.2 * tier)
				if tier >= 3 and m.rank != "boss":
					m.tp = zone.move(m.tp, s["v"].normalized() * 0.6, m.radius)
				if s["splint"]:
					s["splint"] = false
					var ang: float = s["v"].angle()
					for off in [1.1, -1.1]:
						spears.append({"tp": m.tp, "v": Vector2(cos(ang + off), sin(ang + off)) * 10.0, "t": 0.35, "dmg": s["dmg"] * 0.5, "hit": {m: true}, "splint": false, "main": false, "small": true, "pierce": 0, "opt": s["opt"]})
				if s["pierce"] > 0 and s["hit"].size() >= s["pierce"]:
					s["t"] = 0.0
					if s.get("back", false):
						motes.append({"tp": s["tp"], "z": 6.0, "rise": 0.0, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
					break
	spears = spears.filter(func(s): return s["t"] > 0.0)

# ------------------------------------------------------------------ Bone Armor
func cast_armor() -> bool:
	plates_max = armor_max()
	plates = plates_max
	say_at(hero.tp, "bone armor")
	dust(hero.tp, 12)
	Sfx.play("break", 0.5, 0.8)
	return true

## Shard Plates (Bone Armor at 10): every shard the Mantle gathers rebuilds the plates a little
func plates_on_shard() -> void:
	if K("barmorshard") > 0 and plates_max > 0.0:
		plates = minf(plates_max, plates + plates_max * 0.04)

# ------------------------------------------------------------------ Marrow Siphon
func cast_siphon(a: Vector2) -> bool:
	var o := from_tp()
	var dir := (a - o).normalized() if a.distance_to(o) > 0.05 else Vector2(1, 1).normalized()
	var R := 3.5
	var n := 0
	for m in mons():
		var dv: Vector2 = m.tp - o
		if dv.length() > R + m.radius or (dv.length() > 0.2 and dv.normalized().dot(dir) < cos(0.75)):
			continue
		hurt(m, siphon_dmg(), "siphon", echo_opt())
		if K("siphonslow") > 0:
			m.slow = maxf(m.slow, 0.6)
		if n < 4 and origin == null:
			n += 1
			motes.append({"tp": m.tp, "z": 4.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
			if K("siphonheal") > 0:
				hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.01)
	siph_fx.append({"tp": o, "dir": dir, "R": R, "t": 0.3})
	Sfx.play("cast_soul", 0.5, 0.6)
	return true

# ------------------------------------------------------------------ Charnel Cage
func cast_cage(a: Vector2) -> bool:
	var p := clamp_cast(a, 9.0)
	var c := {"tp": p, "R": 1.25, "t": cage_life(), "max": cage_life(), "dps": cage_dps(), "tick": 0.0, "drain": 1.0, "opt": echo_opt(), "seed": randf() * 9.0}
	cages.append(c)
	for m in foes(p, c["R"]):
		m.root = maxf(m.root, c["t"] * (0.5 if m.rank == "boss" else 1.0))
		hurt(m, c["dps"] * 0.6, "ribcage", c["opt"])
		wake(m)
	dust(p, 16)
	Game.shake(2.0)
	Sfx.play("break", 0.6, 0.55)
	return true

func tick_cages(dt: float) -> void:
	for c in cages:
		c["t"] -= dt
		c["tick"] -= dt
		c["drain"] -= dt
		var inside: Array = foes(c["tp"], c["R"])
		if c["tick"] <= 0.0:
			c["tick"] = 0.25
			for m in inside:
				hurt(m, c["dps"] * 0.25, "ribcage", c["opt"].merged({"poise": 0.0}))
				if m.rank != "boss":
					m.root = maxf(m.root, 0.3)
				m.slow = maxf(m.slow, 0.45)   # the arms drag at them
		if c["drain"] <= 0.0:
			c["drain"] = 2.0
			if K("mdrain") > 0:
				for m in inside:
					motes.append({"tp": m.tp, "z": 4.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
		if c["t"] <= 0.0 and K("ribspike") > 0:
			spike_burst(c["tp"], cage_dps() * 2.0, c["R"] + 0.4, null, c["opt"])
	cages = cages.filter(func(c): return c["t"] > 0.0)

# ------------------------------------------------------------------ Ossify
func cast_ossify(a: Vector2) -> bool:
	var p := clamp_cast(a, 9.0)
	var R := ossify_r()
	for m in foes(p, R):
		m.set_meta("o_oss", time + 8.0)
		if K("ossifylock") > 0:
			m.root = maxf(m.root, 0.5 if m.rank == "boss" else 1.5)
		wake(m)
		say_at(m.tp, "ossified", BONE_D)
	spikes_fx.append({"tp": p, "a": 0.0, "len": R, "t": 0.5, "ring": true})
	dust(p, 14)
	Sfx.play("glass", 0.4, 0.6)
	return true

## the ossified: slowed while it lasts; one that dies bursts into shards that cut what is near
func tick_ossified() -> void:
	for m in mons():
		if float(m.get_meta("o_oss", -1.0)) > time:
			m.slow = maxf(m.slow, 0.3)

func ossified_death(m) -> void:
	if float(m.get_meta("o_oss", -1.0)) <= time:
		return
	for i in 6:
		var ang := i / 6.0 * TAU + randf() * 0.5
		motes.append({"tp": m.tp, "z": 4.0, "rise": 0.0, "out": 0.3, "v": Vector2(cos(ang), sin(ang)) * 8.0, "spd": 4.0, "t": 0.0, "dmg": mote_dmg() * 2.0, "hit": {}, "val": 0.5})

# ------------------------------------------------------------------ Bone Spurs
func cast_spurs(a: Vector2) -> bool:
	var best: Monster = null
	var bd := 2.2
	for m in mons():
		var d: float = m.tp.distance_to(a)
		if d < bd and m.tp.distance_to(hero.tp) < 12.0:
			bd = d
			best = m
	if best == null:
		spike_burst(clamp_cast(a, 8.0), spike_dmg() * 0.6, spike_r() * 0.7, null, echo_opt())
	else:
		spike_burst(best.tp, spike_dmg(), spike_r(), best, echo_opt())
	return true

func spike_burst(p: Vector2, dmg: float, R: float, src_m, opt: Dictionary) -> void:
	for i in 10:
		spikes_fx.append({"tp": p, "a": i / 10.0 * TAU + randf() * 0.3, "len": R * randf_range(0.6, 1.0), "t": 0.5})
	for m in foes(p, R):
		m.set_meta("o_spiked", time + 0.6)
		m.set_meta("o_spike_dmg", dmg)
		hurt(m, dmg if m == src_m else dmg * 0.8, "spikes", opt)
		wake(m)
	dust(p, 12)
	Sfx.play("break", 0.5, 1.4)

## Ossuary Bloom (Bone Spurs at 5): a thing the spurs killed bursts into spurs again
func spiked_death(m) -> void:
	if K("bloom") > 0 and float(m.get_meta("o_spiked", -1.0)) > time:
		spike_burst(m.tp, float(m.get_meta("o_spike_dmg", 0.0)) * 0.7, spike_r() * 0.8, null, {})

# ------------------------------------------------------------------ Shard Storm
func cast_storm(a: Vector2) -> bool:
	var n := mini(int(shards), storm_max()) if origin == null else storm_max() / 2
	if n <= 0:
		say("No shards to fire.", 1.0)
		return false
	if origin == null:
		shards -= n
	var o := from_tp()
	var base := (a - o).angle()
	var spread := minf(1.1, 0.12 * n)
	for i in n:
		var ang := base + ((float(i) / (n - 1) - 0.5) * spread if n > 1 else 0.0) + randf_range(-0.03, 0.03)
		spears.append({"tp": o + Vector2(cos(ang), sin(ang)) * 0.3, "v": Vector2(cos(ang), sin(ang)) * randf_range(11.0, 13.0), "t": 0.6, "dmg": storm_dmg(), "hit": {}, "splint": false, "main": false, "small": true,
			"pierce": 2 + (2 if K("stormpierce") > 0 else 0), "back": K("stormback") > 0 and i % 3 == 0 and origin == null, "id": "sstorm", "opt": echo_opt()})
	Sfx.play("cast_mirror", 0.7, 1.1)
	return true

# ------------------------------------------------------------------ Bone Rain
func cast_rain(a: Vector2) -> bool:
	var p := clamp_cast(a, 9.0)
	rains.append({"tp": p, "R": 2.2, "t": 2.0 + (1.0 if K("rainlong") > 0 else 0.0), "dmg": rain_dmg(), "spawn": 0.0, "drops": [], "opt": echo_opt()})
	for i in 8:
		var ang := randf() * TAU
		dust(hero.tp + Vector2(cos(ang), sin(ang)) * randf() * 2.0, 1)
	Sfx.play("glass", 0.3, 1.4)
	return true

func tick_rains(dt: float) -> void:
	for r in rains:
		r["t"] -= dt
		r["spawn"] -= dt
		while r["spawn"] <= 0.0 and r["t"] > 0.0:
			r["spawn"] += 0.07
			var ang := randf() * TAU
			r["drops"].append({"tp": r["tp"] + Vector2(cos(ang), sin(ang)) * sqrt(randf()) * r["R"], "z": 60.0})
		for d in r["drops"]:
			d["z"] -= 160.0 * dt
			if d["z"] <= 0.0:
				d["done"] = true
				dust(d["tp"], 1)
				for m in foes(d["tp"], 0.35):
					hurt(m, r["dmg"], "bonerain", r["opt"].merged({"poise": r["dmg"] * 0.5}))
					if K("rainpin") > 0 and m.rank != "boss":
						m.stun = maxf(m.stun, 0.3)
		r["drops"] = r["drops"].filter(func(d): return not d.get("done", false))
	rains = rains.filter(func(r): return r["t"] > 0.0 or not r["drops"].is_empty())

# ------------------------------------------------------------------ Pale Lord
func cast_lord(a: Vector2) -> bool:
	var p := clamp_cast(a, 8.0)
	if zone.is_solid(p):
		return false
	var room := 2 if K("spirittwin") > 0 else 1
	while lords.size() >= room:
		var old = lords.pop_front()
		if is_instance_valid(old["node"]):
			old["node"].queue_free()
		dust(old["tp"], 8)
	var node := AnimSprite.new(Data.sprite_set("skeleton_mage"))
	node.play("idle")
	node.position = Iso.to_screen(p) + Vector2(0, -10)   # it stands on the stone
	node.modulate = Color(0.92, 0.92, 0.9)
	zone.sorted.add_child(node)
	lords.append({"node": node, "tp": p})
	dust(p, 14)
	Sfx.play("break", 0.5, 0.5)
	return true

const ECHOED := ["siphon", "ribcage", "ossify", "spikes", "sstorm", "bonerain"]

## each Pale Lord casts the bone spell again, from its stone, at the same point, at a share of the force
func echo(id: String, a: Vector2) -> void:
	if not id in ECHOED or lords.is_empty():
		return
	for l in lords:
		if not is_instance_valid(l["node"]):
			continue
		origin = l["tp"]
		force = echo_k()
		l["node"].play("atk", true, false)
		_cast_bone(id, a)
		origin = null
		force = 1.0

func tick_lords(dt: float) -> void:
	lords = lords.filter(func(l): return is_instance_valid(l["node"]))
	for l in lords:
		l["node"].step(dt)
		if l["node"].anim != "idle" and l["node"].done:
			l["node"].play("idle")

## the bone spells by id (casting and echoes share it)
func _cast_bone(id: String, a: Vector2) -> bool:
	match id:
		"spear": return cast_lance(a, 0 if origin != null else -1)
		"siphon": return cast_siphon(a)
		"ribcage": return cast_cage(a)
		"ossify": return cast_ossify(a)
		"spikes": return cast_spurs(a)
		"sstorm": return cast_storm(a)
		"bonerain": return cast_rain(a)
	return false

func clear_spells() -> void:
	charging = {}
	spears.clear()
	cages.clear()
	rains.clear()
	spikes_fx.clear()
	siph_fx.clear()
	for l in lords:
		if is_instance_valid(l["node"]):
			l["node"].queue_free()
	lords.clear()
