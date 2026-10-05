extends "res://skills/ossumancer/base.gd"
## The Ossuarch, part 2 of 5: the Ossuary tree, his dead. The dead are asked, not forced.
##  Raise Skeleton: the dead claw up out of his Mantle on their own whenever there is room (each holds 5 of its shards
##    while it stands; one rises every 1.2 s, and a fallen one leaves six before the next). They rise armed in turn
##    with shield, greatsword and halberd. The skeletons themselves are skills/ossumancer/skeleton.gd.
##  Bone Offering: the skeleton nearest the cursor bursts outward in a thicket of piercing shards; its shards come home.
##  Grave Tithe: what was bone in the slain comes to him as grit (a shard now and then; always two from the great).
##  Unearth: the corpses near the cursor come up through the ground, spurred and fused, for 15 s (they hold no shards).
##  Ossuary Colossus (hold): his dead march into one giant at the cursor, one by one; tap to direct it (on a creature:
##    it goes for it and the dead follow; on the ground: it marches there). It leaps onto prey 2.6-7.5 yd off.
##    skills/ossumancer/colossus.gd.
##  Death March: the dead step in time, strike faster and harder; the living near him falter and drag their feet.
##  Bone Host (hold): his dead march onto him and fuse into a carapace (larger, faster, harder-hitting, a longer
##    reach); blows break it down skeleton by skeleton; a tap sheds it and they stand up again round him.
##  Reassemble: a fallen skeleton may pull itself back together; the Colossus reforms from its rubble.
##  Pale Legion (level 30): the dead stand harder and cut deeper, and one more may stand.

const Colossus = preload("res://skills/ossumancer/colossus.gd")

var col_rebuild := {}        # {tp, t, n}: Reassemble raising it again
var reasm_q: Array = []      # {tp, t}: fallen dead pulling themselves back together
var cmd := {}                # the Colossus's order the dead follow: {prey} or {pt}, and {t}
var march_t := 0.0           # Death March
var fuse_t := 0.0            # feeding the dead into the Colossus or the Host, one every 0.4 s
var fuse_msg := false
var last_chan := -9.0        # when a channel last ran (a held button repeats the press; that is not a new press)

# ------------------------------------------------------------------ numbers (f_bone.js BS, o_skills14.js)
func skel_speed() -> float: return (1.15 if K("legionspd") > 0 else 1.0) * (1.25 if march_t > 0.0 else 1.0)
func skel_haste() -> float: return 1.4 if march_t > 0.0 else 1.0
func march_dmg() -> float: return 1.2 if march_t > 0.0 else 1.0
func march_life() -> float: return 6.0 + (4.0 if K("hornlong") > 0 else 0.0)
## G2 balance (2026-09-30): the web's numbers let an offering go every 1.2 s at 145 dps; cut to 70%, and the next dead
## rise 2 s after an offering
func offer_dmg() -> float: return (8.0 + 4.0 * (L1("offering") - 1.0)) * power() * syn("offering") * 0.7
func unearth_n() -> int: return 3 + int(floorf(L1("unearth") / 4.0))
func col_max() -> int: return 4 + int(floorf(L1("colossus") / 2.0))
func col_hp(n: int) -> float:
	return (80.0 + 32.0 * (L1("colossus") - 1.0)) * (0.6 + 0.4 * n) * (1.0 + 0.1 * K("legion")) * (1.25 if K("colgiant") > 0 else 1.0)
func col_dmg(n: int) -> float:
	return (12.0 + 6.0 * (L1("colossus") - 1.0)) * (0.8 + 0.25 * n) * (1.0 + 0.1 * K("legion")) * hero.st.skill_mult() * march_dmg()
func host_max() -> int: return 3 + int(floorf(L1("host") / 3.0))
func host_per() -> float: return (18.0 + 7.0 * (L1("raise") - 1.0)) * (1.0 + 0.08 * K("legion")) * 0.9
func host_melee() -> float: return 0.25 + 0.02 * K("host")
func reasm_pct() -> float: return minf(0.4, 0.15 + 0.01 * L1("reasm"))

## where the dead form up: round the Colossus's marching point while it has one, else round him
func anchor() -> Vector2:
	if cmd.has("pt"):
		return cmd["pt"]
	return hero.tp

func commanded_prey():
	var p = cmd.get("prey")
	return p if p != null and is_instance_valid(p) and not p.dead else null

# ------------------------------------------------------------------ the dead rise
func tick_dead(dt: float) -> void:
	skels = skels.filter(func(e): return is_instance_valid(e) and not e.gone)
	march_t = maxf(0.0, march_t - dt)
	rise_t -= dt
	if not cmd.is_empty():
		cmd["t"] -= dt
		if cmd["t"] <= 0.0 or (cmd.has("prey") and commanded_prey() == null):
			cmd = {}
	for q in reasm_q:
		q["t"] -= dt
	for q in reasm_q.filter(func(q): return q["t"] <= 0.0):
		if standing() < skel_max() and SKEL_COST * (standing() + 1) <= mantle_cap():
			var e = raise_at(q["tp"], false)
			e.hp = e.max_hp * 0.6
			say_at(q["tp"], "reassembles")
	reasm_q = reasm_q.filter(func(q): return q["t"] > 0.0)
	if not col_rebuild.is_empty():
		col_rebuild["t"] -= dt
		if col_rebuild["t"] <= 0.0 and colossus == null:
			_make_colossus(col_rebuild["tp"], col_rebuild["n"])
			say_at(col_rebuild["tp"], "the Colossus stands again")
			col_rebuild = {}
	if K("raise") <= 0 or hero.dead or fuse_t > 0.0:
		return
	if standing() < skel_max() and rise_t <= 0.0 and SKEL_COST * (standing() + 1) <= mantle_cap() and shards >= SKEL_COST:
		rise_t = 1.2
		var a := randf() * TAU
		var p := clamp_cast(hero.tp + Vector2(cos(a), sin(a)) * 1.3, 2.0)
		if zone.is_solid(p):
			p = hero.tp
		raise_at(p)

func raise_at(p: Vector2, pay: bool = true):
	if pay:
		shards = maxf(0.0, shards - SKEL_COST)
	var e = Skeleton.new()
	e.book = self
	e.tp = p
	e.load_id = _next_load()
	e.setup_numbers()
	zone.sorted.add_child(e)
	skels.append(e)
	dust(p, 10)
	Sfx.play("break", 0.35, 1.3)
	return e

func _next_load() -> String:
	var have := {}
	for e in skels:
		have[e.load_id] = int(have.get(e.load_id, 0)) + 1
	for i in LOAD_ORDER.size():
		var l: String = LOAD_ORDER[i]
		var want := LOAD_ORDER.slice(0, i + 1).count(l)
		if int(have.get(l, 0)) < want:
			return l
	return "shield"

## a skeleton fell: the next waits a while (its shards are gone with it); it may reassemble; Bone Burst
func skel_fell(e) -> void:
	skels.erase(e)
	dust(e.tp, 12)
	if e.temp > 0.0 or e.get_meta("quiet", false):
		return
	rise_t = maxf(rise_t, 6.0)
	Sfx.play("break", 0.45, 1.5)
	if K("reasm") > 0 and randf() < reasm_pct():
		reasm_q.append({"tp": e.tp, "t": 3.5})
	if K("bburst") > 0:
		for i in 6:
			var a := i / 6.0 * TAU + randf() * 0.5
			motes.append({"tp": e.tp, "z": 4.0, "rise": 0.0, "out": 0.3, "v": Vector2(cos(a), sin(a)) * 8.0, "spd": 4.0, "t": 0.0,
				"dmg": (5.0 + 2.5 * (L1("raise") - 1.0)) * hero.st.skill_mult(), "hit": {}, "val": 0.25})

## a skeleton taken apart on purpose (fused, offered): no wait, no reassembling
func unmake(e) -> void:
	e.set_meta("quiet", true)
	e.take_hit(1e9, "true")

func clear_dead() -> void:
	for e in skels:
		if is_instance_valid(e):
			e.queue_free()
	skels.clear()
	if colossus != null and is_instance_valid(colossus):
		colossus.queue_free()
	colossus = null
	reasm_q.clear()
	col_rebuild = {}
	cmd = {}

# ------------------------------------------------------------------ Bone Offering
func cast_offering(a: Vector2) -> bool:
	var best = null
	var bd := 4.0
	for e in skels:
		if e.rise <= 0.0 and e.tp.distance_to(a) < bd:
			bd = e.tp.distance_to(a)
			best = e
	if best == null:
		say("No skeleton near the cursor to offer.", 1.2)
		return false
	var p: Vector2 = best.tp
	var wide := K("offerwide") > 0
	var n := 12 if wide else 8
	var base := (a - hero.tp).angle()
	var held_shards: bool = best.temp <= 0.0
	unmake(best)
	rise_t = maxf(rise_t, 2.0)
	if held_shards:
		shards = minf(free_cap(), shards + SKEL_COST)
	for i in n:
		var ang := i / float(n) * TAU if wide else base + (i / float(n - 1) - 0.5) * 1.3
		spears.append({"tp": p, "v": Vector2(cos(ang), sin(ang)) * 12.0, "t": 0.5, "dmg": offer_dmg(), "hit": {}, "splint": false, "main": false, "small": true, "pierce": 4 if wide else 2, "id": "offering", "opt": {}})
	if K("offerheal") > 0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.08)
	dust(p, 20)
	Game.shake(2.0)
	Sfx.play("break", 0.7, 1.0)
	return true

# ------------------------------------------------------------------ Unearth
func cast_unearth(a: Vector2) -> bool:
	var corpses: Array = []
	for m in hero.get_tree().get_nodes_in_group("monsters"):
		if m.dead and m.corpse_t > 0.0 and m.rank != "boss" and not m.has_meta("o_unearthed") and m.tp.distance_to(a) < 3.5:
			corpses.append(m)
	if corpses.is_empty():
		say("No fresh corpses near the cursor.", 1.2)
		return false
	corpses.sort_custom(func(x, y): return x.tp.distance_to(a) < y.tp.distance_to(a))
	for c in corpses.slice(0, unearth_n()):
		c.set_meta("o_unearthed", true)
		c.corpse_t = minf(c.corpse_t, 0.5)
		var e = raise_at(c.tp, false)
		e.temp = 15.0 + (10.0 if K("unearthlong") > 0 else 0.0)
	say_at(a, "%d unearthed" % mini(corpses.size(), unearth_n()))
	Sfx.play("break", 0.6, 0.6)
	return true

# ------------------------------------------------------------------ Death March
func cast_march() -> bool:
	march_t = march_life()
	if K("hornheal") > 0:
		for e in skels:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.25)
		if colossus != null:
			colossus.hp = minf(colossus.max_hp, colossus.hp + colossus.max_hp * 0.25)
	for m in foes(hero.tp, 5.0):
		m.slow = maxf(m.slow, 0.6)
		if m.rank != "boss":
			m.stun = maxf(m.stun, 0.3)
	spikes_fx.append({"tp": hero.tp, "a": 0.0, "len": 5.0, "t": 0.6, "ring": true})
	say_at(hero.tp, "the dead march")
	Sfx.play("bell_far", 0.8, 0.7)
	return true

# ------------------------------------------------------------------ Ossuary Colossus
## a press: direct the Colossus (a creature under the cursor: go for it; the ground: march there); holding feeds it
func press_colossus(a: Vector2) -> bool:
	if time - last_chan < 0.25:
		return true
	if colossus != null:
		var prey = near(a, 1.6)
		if prey != null:
			cmd = {"prey": prey, "t": 8.0}
			colossus.prey = prey
			colossus.order = {}
			wake(prey)
			say_at(prey.tp, "the Colossus comes")
		else:
			var p := clamp_cast(a, 14.0)
			cmd = {"pt": p, "t": 5.0}
			colossus.order = {"tp": p, "t": 5.0}
			colossus.prey = null
	elif skels.is_empty():
		say("Raise skeletons first: the Colossus is built from them.", 1.4)
	fuse_t = 0.3
	fuse_msg = false
	return true

func _make_colossus(p: Vector2, n: int) -> void:
	if zone.is_solid(p):   # never stand it inside a wall or a cliff (the cursor may rest on one)
		p = Vector2(zone._nearest_open(Vector2i(int(floor(p.x)), int(floor(p.y))))) + Vector2(0.5, 0.5)
	colossus = Colossus.new()
	colossus.book = self
	colossus.tp = p
	colossus.n = n
	colossus.max_hp = col_hp(n)
	colossus.hp = colossus.max_hp
	zone.sorted.add_child(colossus)
	dust(p, 24)
	Game.shake(2.0)

func fuse_colossus() -> void:
	if colossus != null and colossus.n >= col_max():
		if not fuse_msg:
			say("The Colossus holds %d skeletons at most." % col_max(), 1.2)
			fuse_msg = true
		return
	var ref: Vector2 = colossus.tp if colossus != null else aim_point()
	var cand: Array = skels.filter(func(e): return e.rise <= 0.0 and e.temp <= 0.0)
	if cand.is_empty():
		if not fuse_msg:
			say("No skeletons left to fuse.", 1.0)
			fuse_msg = true
		return
	var c := cost("colossus")
	if hero.st.res < c:
		say("Not enough Marrow.", 1.0)
		return
	hero.st.res -= c
	cand.sort_custom(func(x, y): return x.tp.distance_to(ref) < y.tp.distance_to(ref))
	var e = cand[0]
	var from: Vector2 = e.tp
	unmake(e)
	if colossus == null:
		_make_colossus(clamp_cast(aim_point(), 6.0), 0)
	var f: float = colossus.hp / maxf(1.0, colossus.max_hp)
	colossus.n += 1
	colossus.max_hp = col_hp(colossus.n)
	colossus.hp = minf(colossus.max_hp, maxf(colossus.hp, colossus.max_hp * f) + colossus.max_hp * 0.15)
	colossus.grow = 0.35
	for i in 4:
		motes.append({"tp": from, "z": 4.0, "rise": 0.0, "out": 0.25, "v": (colossus.tp - from) * 4.0, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 0.0, "vis": true})
	say_at(colossus.tp, "%d bones" % colossus.n)
	Sfx.play("break", 0.5, 0.9 - 0.04 * colossus.n)

## the Colossus fell: it gives back shards; Reassemble raises it again from its rubble
func colossus_fell(c) -> void:
	for i in mini(8, c.n * 2):
		motes.append({"tp": c.tp, "z": 4.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
	dust(c.tp, 30)
	Game.shake(4.0)
	say("The Colossus collapses.", 1.6)
	if K("reasm") > 0:
		col_rebuild = {"tp": c.tp, "t": 3.0 if K("reasmfast") > 0 else 6.0, "n": c.n if K("reasmfull") > 0 else maxi(1, c.n / 2)}
	colossus = null

# ------------------------------------------------------------------ Bone Host
func press_host() -> bool:
	if time - last_chan < 0.25:
		return true
	host["pressed"] = time
	host["fused_now"] = false
	fuse_t = 0.3
	fuse_msg = false
	if int(host.get("n", 0)) <= 0 and skels.is_empty():
		say("No skeletons standing to fuse onto you.", 1.3)
	return true

func fuse_host() -> void:
	var n := int(host.get("n", 0))
	if n >= host_max():
		if not fuse_msg:
			say("Your carapace holds %d skeletons at most." % host_max(), 1.2)
			fuse_msg = true
		return
	var cand: Array = skels.filter(func(e): return e.rise <= 0.0 and e.temp <= 0.0 and e.tp.distance_to(hero.tp) < 8.0)
	if cand.is_empty():
		if not fuse_msg:
			say("No skeletons near enough to fuse.", 1.0)
			fuse_msg = true
		return
	var c := cost("host")
	if hero.st.res < c:
		say("Not enough Marrow.", 1.0)
		return
	hero.st.res -= c
	cand.sort_custom(func(x, y): return x.tp.distance_to(hero.tp) < y.tp.distance_to(hero.tp))
	unmake(cand[0])
	if n == 0:
		say_at(hero.tp, "BONE HOST")
		Game.shake(2.0)
	host["n"] = n + 1
	host["pool"] = float(host.get("pool", 0.0)) + host_per()
	host["fused_now"] = true
	dust(hero.tp, 12)
	Sfx.play("break", 0.5, 0.8 - 0.05 * n)
	hero.stats_changed.emit()

## a tap sheds the carapace: the dead stand up again round him
func shed_host() -> void:
	var n := int(host.get("n", 0))
	host = {}
	for i in n:
		if skels.size() >= skel_max():
			shards = minf(free_cap(), shards + SKEL_COST)
			continue
		var a := i / float(maxi(1, n)) * TAU
		var e = raise_at(clamp_cast(hero.tp + Vector2(cos(a), sin(a)) * 1.2, 2.0), false)
		e.rise = 0.2
	dust(hero.tp, 24)
	say("Released %d skeleton%s." % [n, "" if n == 1 else "s"], 1.2)
	hero.stats_changed.emit()

## blows on him break the carapace down: it soaks half, and each skeleton's worth lost falls away
func host_absorb(d: float) -> float:
	var n := int(host.get("n", 0))
	if n <= 0:
		return d
	if K("everst") > 0:
		d *= 0.8
	var soak := d * 0.5
	host["pool"] = float(host["pool"]) - soak
	d -= soak
	while n > 0 and float(host["pool"]) <= (n - 1) * host_per():
		n -= 1
		host["n"] = n
		dust(hero.tp, 10)
		say_at(hero.tp, "the carapace cracks")
		Sfx.play("break", 0.5, 1.1)
	if n <= 0:
		host = {}
		say("Your Bone Host is broken.", 1.4)
	hero.stats_changed.emit()
	return d

## the channels: holding the Colossus or the Host feeds one skeleton in every 0.4 s; a quick tap of the Host sheds it
func tick_fusing(dt: float) -> void:
	var chan := ""
	if not hero.dead and hero.act != "roll":
		if K("colossus") > 0 and held("colossus"):
			chan = "colossus"
		elif K("host") > 0 and held("host"):
			chan = "host"
	if chan != "":
		last_chan = time
		hero.walking = false
		fuse_t -= dt
		if fuse_t <= 0.0:
			fuse_t = 0.4
			if chan == "colossus":
				fuse_colossus()
			else:
				fuse_host()
	else:
		if host.has("pressed") and not host.get("fused_now", true) and time - float(host["pressed"]) < 0.35:
			if int(host.get("n", 0)) > 0:
				shed_host()
			host.erase("pressed")
		fuse_t = 0.0
