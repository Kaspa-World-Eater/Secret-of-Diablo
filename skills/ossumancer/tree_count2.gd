extends "res://skills/ossumancer/tree_count.gd"
## The Ossuarch, part 4b (Secret of Diablo): the rest of the Count tree, written to its data's descriptions, with the
## old Secret of Diablo Necromancer's held strikes folded in (hold to fill tiers, release to strike), plus the four
## melee techniques that came over from him (Ribcage Guard, Corpse Splinter, Ossuary Avatar, Marrow Drain), and
## Secret of Mana's swing gauge.
##
## The swing gauge: every stroke in close empties it, and it fills again over a moment. A stroke struck before it is full
## lands lighter (never below 30%). It never stops a stroke (Godmarrow's law: no waits), it only weighs it.
##
## Held strikes (Marrow Crush, Scythe Sweep, Spine Lash, Grinding Charge, Corpse Splinter, Ribcage Guard) work as Bone
## Blade does: the press begins the hold, each tier costs poise as it fills, and letting go strikes the tier reached.
## Tiers: 1 a quick stroke, 2 the stronger form, 3 the full form (see each stroke below).

const HELD := ["crush", "bscythe", "lash", "gcharge", "csplinter", "rguard"]
const HOLD_T := [0.3, 0.7]                       # seconds to reach tier 2 and 3
const HOLD_POISE_K := [0.0, 0.5, 0.8]            # extra poise for tiers 2 and 3, times the skill's own cost

var swing := 1.0             # Secret of Mana's gauge, 0..1
var swing_k := 1.0           # the weight of the stroke being struck
var mcharge := {}            # {id, t, tier, at, target, goal}
var guard := {}              # Ribcage Guard: {t, kind}
var avatar_t := 0.0          # Ossuary Avatar
var kills9 := 0              # Count Mastery: every ninth kill crowns one of the dead
var gauge_node: Node2D       # the swing gauge, drawn in the world under his feet (Secret of Mana)

# ------------------------------------------------------------------ numbers
func sample(id: String, key: String, fallback: float) -> float:
	## the value of a skill's formula at its level, from the data's samples (level 1..20)
	var f = data.get(id, {}).get("formulas")
	if f is Dictionary and f.has(key):
		var s: Array = f[key].get("samples_L1_20", [])
		if not s.is_empty():
			var v = s[clampi(maxi(1, K(id)) - 1, 0, s.size() - 1)]
			return float(v[0]) if v is Array else float(v)
	return fallback

func stroke_k() -> float:
	return hero.st.melee_mult() * melee_k() * (1.3 if avatar_t > 0.0 else 1.0)

## a thin bone-coloured bar under his feet while the gauge refills; it lingers a moment when full, then fades
var _full_t := 0.0
func _draw_gauge() -> void:
	if hero.dead:
		return
	_full_t = 0.0 if swing < 1.0 else _full_t + get_process_delta_time_safe()
	var a: float = 1.0 if swing < 1.0 else clampf(1.0 - (_full_t - 0.3) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var w := 46.0
	var y := 14.0
	gauge_node.draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 6), Color(0.05, 0.04, 0.04, 0.75 * a))
	var col := Color(0.93, 0.88, 0.7, a) if swing >= 1.0 else Color(0.6, 0.55, 0.45, a)
	gauge_node.draw_rect(Rect2(-w / 2, y, w * swing, 4), col)

func get_process_delta_time_safe() -> float:
	return hero.get_process_delta_time() if hero else 0.016

func begin_swing() -> void:
	swing_k = maxf(0.3, swing)
	swing = 0.0

func swing_rate() -> float:
	return hero.st.attack_speed() / 0.9

# ------------------------------------------------------------------ the frame
func tick_count2(dt: float) -> void:
	swing = minf(1.0, swing + dt * swing_rate())
	if gauge_node == null or not is_instance_valid(gauge_node):
		gauge_node = Node2D.new()
		gauge_node.z_index = 30
		gauge_node.draw.connect(_draw_gauge)
		hero.add_child(gauge_node)
	gauge_node.queue_redraw()
	avatar_t = maxf(0.0, avatar_t - dt)
	if not guard.is_empty():
		guard["t"] -= dt
		if guard["t"] <= 0.0:
			guard = {}
	_tick_hold(dt)
	_tick_curses()

func _tick_hold(dt: float) -> void:
	if mcharge.is_empty():
		return
	if hero.dead or hero.act == "roll" or hero.act == "stun":
		mcharge = {}
		return
	var id: String = mcharge["id"]
	mcharge["t"] += dt * blade_speed() * (1.4 if avatar_t > 0.0 else 1.0)
	if not mcharge.has("goal"):
		mcharge["at"] = aim_point()
		if auto_on:
			mcharge["goal"] = randi() % 3
	hero._face(mcharge["at"] - hero.tp)
	if hero.act == "cast" or hero.act == "atk":
		hero.act_t = minf(hero.act_t, hero.act_len * 0.3)
	var tier: int = mcharge["tier"]
	if tier < 2 and mcharge["t"] >= HOLD_T[tier]:
		var pc: float = poise_cost(id) * HOLD_POISE_K[tier + 1]
		if hero.st.poise >= pc * 0.5:
			hero.spend_poise(pc)
			mcharge["tier"] = tier + 1
			dust(hero.tp, 3)
			Sfx.play("break", 0.22, 1.4 - 0.25 * tier)
		else:
			mcharge["t"] = HOLD_T[tier]
	var goal: int = int(mcharge.get("goal", -1))
	var release: bool = not held(id) if goal < 0 else int(mcharge["tier"]) >= goal
	if int(mcharge["tier"]) >= 2 and mcharge["t"] > HOLD_T[1] + 0.6:
		release = true
	if release:
		var at: Vector2 = mcharge["at"]
		var tr: int = mcharge["tier"]
		var tg = mcharge.get("target")
		mcharge = {}
		hero.act = ""
		strike_held(id, at, tg, tr)

## the press of a held strike: begin the hold (or, with charging off, strike at once)
func press_held(id: String, a: Vector2, target) -> bool:
	if not Settings.charge_melee or origin != null:
		return strike_held(id, a, target, 0)
	if not mcharge.is_empty() or not bcharge.is_empty():
		return false
	mcharge = {"id": id, "t": 0.0, "tier": 0, "at": a, "target": target}
	cast_len = 4.0
	return true

func strike_held(id: String, a: Vector2, target, tier: int) -> bool:
	match id:
		"crush":
			return strike_crush(a, target, tier)
		"bscythe":
			return strike_scythe(tier)
		"lash":
			return strike_lash(a, tier)
		"gcharge":
			return strike_charge(a, tier)
		"csplinter":
			return strike_splinter(a, tier)
		"rguard":
			return raise_guard(tier)
	return false

## Bone Blade strikes through the swing gauge too
func strike_blade_tier(a: Vector2, target, tier: int) -> bool:
	begin_swing()
	return super.strike_blade_tier(a, target, tier)

func _after_stroke(anim: String, secs: float, dir: Vector2, hits: int, tier: int) -> void:
	hero._face(dir)
	hero._start_act(anim, secs / hero.st.attack_speed())
	hero.act_done = true
	cast_len = -1.0
	Sfx.play("heavy" if tier == 2 else "hit", 0.9, [1.0, 0.85, 0.7][tier])
	if hits > 0 and tier >= 1:
		Game.hitstop(0.04 + 0.03 * tier)

func _dir_to(a: Vector2) -> Vector2:
	return (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.05 else Vector2(1, 1).normalized()

func _throw(m, from: Vector2, dist: float) -> void:
	if m.rank == "boss":
		return
	var dv: Vector2 = m.tp - from
	if dv.length() > 0.001:
		m.tp = zone.move(m.tp, dv.normalized() * dist, m.radius)

func _melee(m, dmg: float, id: String, notches: int = 1) -> void:
	_blade_hit_as(m, dmg, notches, id)

func _blade_hit_as(m, dmg: float, notches: int, id: String) -> void:
	var n: int = int(m.get_meta("notch", 0)) + notches
	var d: float = dmg
	if n >= 9:
		n -= 9
		if K("tally") > 0:
			d *= 2.0
		blade_fx.append({"kind": "close", "tp": m.tp, "t": 0.0})
		_count_closed(m)
	m.set_meta("notch", n)
	hurt(m, d, id, {"melee": true})
	dust(m.tp, 2 + notches)

# ------------------------------------------------------------------ Marrow Crush
## A heavy two-handed blow that cracks bone: +25% damage taken for 5 s, two shards knocked loose, +11% a notch (and the
## count wiped). Held: 2 the blow cracks the ground round it, 3 a shockwave that staggers all near.
func strike_crush(a: Vector2, target, tier: int) -> bool:
	begin_swing()
	var reach: float = hero._reach() + 0.5 + host_reach()
	var dir := _dir_to(a)
	var m = target if target != null and is_instance_valid(target) and not target.dead else melee_target(a, reach + 0.4)
	var base: float = sample("crush", "BS.crushDmg", 11.0) * stroke_k() * [1.0, 1.35, 1.7][tier]
	var hits := 0
	if m != null:
		var notch := int(m.get_meta("notch", 0))
		m.set_meta("notch", 0)
		hurt(m, base * (1.0 + 0.11 * notch), "crush", {"melee": true, "heavy": true})
		m.set_meta("o_crushed", Time.get_ticks_msec() / 1000.0 + 5.0)
		say_at(m.tp, "cracked")
		for i in 2:
			motes.append({"tp": m.tp, "z": 8.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
		hits += 1
		var c: Vector2 = m.tp
		if tier >= 1:
			for o in foes(c, 1.8 if tier == 1 else 3.2):
				if o != m:
					hurt(o, base * (0.55 if tier == 1 else 0.5), "crush", {"melee": true})
					_throw(o, c, 0.5 if tier == 1 else 0.9)
					if tier == 2 and o.rank != "boss":
						o.stun = maxf(o.stun, 0.8)
					hits += 1
			spikes_fx.append({"tp": c, "a": 0.0, "len": 1.8 if tier == 1 else 3.2, "t": 0.4, "ring": true})
			Game.shake(1.5 + tier)
		dust(c, 6 + 4 * tier)
	_after_stroke("atk", [0.45, 0.55, 0.65][tier], dir, hits, tier)
	return true

# ------------------------------------------------------------------ Scythe Sweep
## A scythe of vertebrae cuts a full ring around him; everything in reach is opened, then thrown clear. Held: 2 two
## rings, 3 three rings, wider.
func strike_scythe(tier: int) -> bool:
	begin_swing()
	var R: float = hero._reach() + 1.1 + host_reach() + 0.4 * tier
	var dmg: float = sample("bscythe", "BS.sweepDmg", 9.5) * stroke_k()
	var hits := 0
	for ring in tier + 1:
		for m in foes(hero.tp, R):
			_melee(m, dmg * (1.0 if ring == 0 else 0.7), "bscythe", 1)
			_throw(m, hero.tp, 0.7)
			hits += 1
		spikes_fx.append({"tp": hero.tp, "a": 0.0, "len": R, "t": 0.35 + 0.1 * ring, "ring": true})
	blade_fx.append({"kind": "cleave", "tp": hero.tp, "dir": Vector2(1, 0), "reach": R, "t": 0.0, "tier": tier})
	_after_stroke("atk2", [0.4, 0.55, 0.7][tier], hero_dir(), hits, tier)
	return true

func hero_dir() -> Vector2:
	return Brain.hero_front(hero)

# ------------------------------------------------------------------ Spine Lash
## A whip of vertebrae cracks in a long straight line: it cuts everything along it and yanks the farthest it catches to
## his feet. Held: 2 longer and it yanks everything it caught, 3 it drags the corpses along the line to him as well.
func strike_lash(a: Vector2, tier: int) -> bool:
	begin_swing()
	var dir := _dir_to(a)
	var L: float = 5.0 + 1.0 * tier + host_reach()
	var dmg: float = sample("lash", "BS.lashDmg", 7.5) * stroke_k() * [1.0, 1.15, 1.3][tier]
	var caught: Array = []
	for m in foes(hero.tp + dir * L * 0.5, L * 0.6 + 1.0):
		var rel: Vector2 = m.tp - hero.tp
		var along: float = rel.dot(dir)
		if along > 0.0 and along < L + m.radius and absf(rel.cross(dir)) < 0.5 + m.radius:
			_melee(m, dmg, "lash", 1)
			caught.append(m)
	caught.sort_custom(func(x, y): return x.tp.distance_to(hero.tp) > y.tp.distance_to(hero.tp))
	var pull: Array = caught if tier >= 1 else caught.slice(0, 1)
	for m in pull:
		if is_instance_valid(m) and not m.dead and m.rank != "boss":
			m.tp = zone.move(m.tp, (hero.tp + dir * (hero.radius + m.radius + 0.3)) - m.tp, m.radius)
			m.stun = maxf(m.stun, 0.4)
	if tier == 2:
		for c in hero.get_tree().get_nodes_in_group("corpses"):
			if not is_instance_valid(c) or not "tp" in c:
				continue
			var rc: Vector2 = c.tp - hero.tp
			var al: float = rc.dot(dir)
			if al > 0.0 and al < L + 0.5 and absf(rc.cross(dir)) < 0.8:
				c.tp = hero.tp + dir * 0.9
				c.position = Iso.to_screen(c.tp)
	blade_fx.append({"kind": "split_flash", "tp": hero.tp, "dir": dir, "len": L, "t": 0.0, "tier": tier})
	_after_stroke("atk2", [0.38, 0.46, 0.55][tier], dir, caught.size(), tier)
	return true

# ------------------------------------------------------------------ Grinding Charge
## Lower the shoulder and drive to the cursor: everything in the path is ground down and flung aside. Held: 2 farther and
## harder, 3 it ends in a slam that throws all around clear.
func strike_charge(a: Vector2, tier: int) -> bool:
	begin_swing()
	var dir := _dir_to(a)
	var maxd: float = [5.0, 6.5, 8.0][tier]
	var dist: float = minf(maxd, a.distance_to(hero.tp))
	var dmg: float = sample("gcharge", "BS.chargeDmg", 8.0) * stroke_k() * [1.0, 1.3, 1.6][tier]
	var start := hero.tp
	var hits := 0
	var n := int(ceil(dist / 0.25))
	var hitset := {}
	for i in n:
		var next: Vector2 = zone.move(hero.tp, dir * 0.25, hero.radius)
		if next.distance_to(hero.tp) < 0.05:
			break
		hero.tp = next
		for m in foes(hero.tp, hero.radius + 0.6):
			if hitset.has(m):
				continue
			hitset[m] = true
			_melee(m, dmg, "gcharge", 1)
			var side: Vector2 = Vector2(-dir.y, dir.x) * (1.0 if (m.tp - hero.tp).cross(dir) < 0.0 else -1.0)
			if m.rank != "boss":
				m.tp = zone.move(m.tp, side * 1.0, m.radius)
			hits += 1
	hero.position = Iso.to_screen(hero.tp)
	dust(start, 4)
	if tier == 2:
		for m in foes(hero.tp, 2.2):
			hurt(m, dmg * 0.8, "gcharge", {"melee": true, "heavy": true})
			_throw(m, hero.tp, 1.0)
			hits += 1
		spikes_fx.append({"tp": hero.tp, "a": 0.0, "len": 2.2, "t": 0.4, "ring": true})
		Game.shake(3.0)
	_after_stroke("atk2", 0.35, dir, hits, tier)
	return true

# ------------------------------------------------------------------ Grave Leap (no hold)
## Kick free of the earth and come down on the cursor in driven spikes: the living are thrown clear, the dying stapled.
func cast_leap(a: Vector2) -> bool:
	begin_swing()
	var to: Vector2 = clamp_cast(a, 7.0)
	if zone.is_solid(to):
		return false
	var from := hero.tp
	hero.tp = to
	hero.position = Iso.to_screen(to)
	var R := 2.0 + 0.05 * L1("leap")
	var dmg: float = sample("leap", "BS.leapDmg", 18.0) * stroke_k()
	for m in foes(to, R):
		_melee(m, dmg, "leap", 2)
		if is_instance_valid(m) and not m.dead:
			if m.hp < m.hp_max * 0.3:
				m.root = maxf(m.root, 2.0)
			else:
				_throw(m, to, 1.0)
	spikes_fx.append({"tp": to, "a": 0.0, "len": R, "t": 0.45, "ring": true})
	for i in 6:
		spikes_fx.append({"tp": to + Vector2.from_angle(TAU * i / 6.0) * R * 0.6, "a": TAU * i / 6.0, "len": 0.6, "t": 0.5})
	dust(from, 5)
	Game.shake(3.0)
	_after_stroke("atk", 0.5, _dir_to(to + (to - from)), 1, 2)
	return true

# ------------------------------------------------------------------ Corpse Splinter
## Strike a corpse near him: it bursts into bone shrapnel. Held: 1 a cone ahead, 2 a ring, 3 splinters that find marks.
func strike_splinter(a: Vector2, tier: int) -> bool:
	var corpse = _corpse_near(a, 1.6)
	if corpse == null:
		corpse = _corpse_near(hero.tp, 2.0)
	if corpse == null:
		say("No corpse in reach.", 1.0)
		return false
	begin_swing()
	var c: Vector2 = corpse.tp
	var life: float = float(corpse.hp_max) if "hp_max" in corpse else 30.0
	var dmg: float = (weapon_avg() * 1.2 + life * 0.15) * stroke_k()
	var dir := _dir_to(a)
	var hits := 0
	match tier:
		0:
			for m in foes(c, 4.0):
				if (m.tp - c).normalized().dot(dir) > 0.5:
					hurt(m, dmg, "csplinter", {"melee": true})
					hits += 1
		1:
			for m in foes(c, 3.5):
				hurt(m, dmg * 0.9, "csplinter", {"melee": true})
				hits += 1
		2:
			var ms: Array = foes(c, 7.0)
			ms.sort_custom(func(x, y): return x.tp.distance_to(c) < y.tp.distance_to(c))
			for m in ms.slice(0, 6):
				hurt(m, dmg * 1.1, "csplinter", {"melee": true})
				spikes_fx.append({"tp": m.tp, "a": randf() * TAU, "len": 0.5, "t": 0.4})
				hits += 1
	for i in 8:
		spikes_fx.append({"tp": c, "a": TAU * i / 8.0, "len": 0.8 + 0.3 * tier, "t": 0.4})
	dust(c, 10)
	corpse.queue_free()
	_after_stroke("atk", 0.42, dir, hits, tier)
	return true

func _corpse_near(p: Vector2, r: float):
	var best = null
	var bd := r
	for c in hero.get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(c) or not "tp" in c:
			continue
		var d: float = c.tp.distance_to(p)
		if d < bd:
			bd = d
			best = c
	return best

# ------------------------------------------------------------------ Ribcage Guard
## A cage of ribs raised before him. Held: 1 a short guard (turns 60%), 2 a long guard (80%), 3 a parry (turns all of the
## next blow and answers the striker).
func raise_guard(tier: int) -> bool:
	guard = {"t": [0.6, 1.3, 1.0][tier], "kind": ["guard", "guard2", "parry"][tier]}
	dust(hero.tp, 3)
	hero._start_act("cast", 0.25)
	cast_len = -1.0
	return true

## (called from the hero's damage hook) the guard's share of a blow
func guard_blow(d: float, by) -> float:
	if guard.is_empty():
		return d
	match guard["kind"]:
		"guard":
			return d * 0.4
		"guard2":
			return d * 0.2
		"parry":
			guard = {}
			say_at(hero.tp, "parried")
			Sfx.play("block", 0.9)
			if by != null and is_instance_valid(by) and not by.dead:
				begin_swing()
				hurt(by, weapon_avg() * 2.5 * stroke_k(), "rguard", {"melee": true, "heavy": true})
			return 0.0
	return d

# ------------------------------------------------------------------ Ossuary Avatar
func cast_avatar() -> bool:
	avatar_t = 20.0 + 2.0 * L1("avatar")
	say_at(hero.tp, "the frame closes")
	dust(hero.tp, 12)
	return true

# ------------------------------------------------------------------ the curses of the Count
## Open Count: up to nine around the target; every hit they take cuts a notch; a closed count shatters them for a ninth
## of their life (far less for bosses).
func cast_open_count(a: Vector2) -> bool:
	var ms: Array = foes(a, 3.0)
	ms.sort_custom(func(x, y): return x.tp.distance_to(a) < y.tp.distance_to(a))
	for m in ms.slice(0, 9):
		m.set_meta("o_count", true)
		say_at(m.tp, "counted")
	spikes_fx.append({"tp": a, "a": 0.0, "len": 3.0, "t": 0.5, "ring": true})
	return true

## The Fewer: the enemies near the target take more from his blows the fewer of their kind stand near them
func cast_fewer(a: Vector2) -> bool:
	var until := time + 8.0 + 0.5 * L1("fewer")
	for m in foes(a, 3.5):
		m.set_meta("o_fewer", until)
	spikes_fx.append({"tp": a, "a": 0.0, "len": 3.5, "t": 0.5, "ring": true})
	return true

## The Weighing: every notch makes them slower and their blows lighter (up to nine notches)
func cast_weighing(a: Vector2) -> bool:
	var until := Time.get_ticks_msec() / 1000.0 + 8.0 + 0.5 * L1("weighing")
	for m in foes(a, 3.5):
		m.set_meta("o_weigh", until)
	spikes_fx.append({"tp": a, "a": 0.0, "len": 3.5, "t": 0.5, "ring": true})
	return true

## The Ninth Stair: one enemy goes down a step with each of his next nine blows (+9% a step); on the ninth, if its life is
## low enough, it is finished
func cast_stair(a: Vector2, target) -> bool:
	var m = target if target != null and is_instance_valid(target) else near(a, 1.6)
	if m == null:
		say("No one to take down the stair.", 1.0)
		return false
	m.set_meta("o_stair", 0)
	say_at(m.tp, "the stair")
	return true

func _tick_curses() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for m in mons():
		if float(m.get_meta("o_weigh", -1.0)) > now:
			m.slow = maxf(m.slow, minf(0.45, 0.05 * int(m.get_meta("notch", 0))))

## his blows and his dead's blows pass through here (hurt): the count, the Fewer, the Stair, Marrow Drain, the gauge
func hurt(m, dmg: float, id: String, o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead:
		return 0.0
	if o.get("melee", false):
		dmg *= swing_k
	if float(m.get_meta("o_fewer", -1.0)) > time:
		var n := 0
		for x in foes(m.tp, 4.0):
			if x != m and x.kind == m.kind:
				n += 1
		dmg *= 1.0 + 0.45 / (1.0 + n)
	if m.has_meta("o_stair"):
		var step := int(m.get_meta("o_stair")) + 1
		dmg *= 1.0 + 0.09 * step
		if step >= 9:
			m.remove_meta("o_stair")
			if m.hp - dmg < m.hp_max * (0.12 if m.rank == "boss" else 0.3):
				dmg = m.hp + 1.0
				say_at(m.tp, "the ninth stair")
		else:
			m.set_meta("o_stair", step)
	var dealt: float = super.hurt(m, dmg, id, o)
	if dealt > 0.0 and o.get("melee", false) and K("mdrain") > 0:
		var L := L1("mdrain")
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dealt * (0.02 + 0.005 * L))
		hero.st.res = minf(hero.st.res_max(), hero.st.res + dealt * (0.01 + 0.003 * L))
	if is_instance_valid(m) and bool(m.get_meta("o_count", false)) and id != "blade" and not o.get("melee", false):
		var n2: int = int(m.get_meta("notch", 0)) + 1
		if n2 >= 9:
			m.set_meta("notch", 0)
			_count_closed(m)
		else:
			m.set_meta("notch", n2)
	return dealt

func _count_closed(m) -> void:
	if K("countm") > 0:
		hero.st.poise = minf(hero.st.poise_max(), hero.st.poise + hero.st.poise_max() / 9.0)
	if bool(m.get_meta("o_count", false)) and is_instance_valid(m) and not m.dead:
		m.remove_meta("o_count")
		var share: float = m.hp_max / (27.0 if m.rank == "boss" else 9.0)
		super.hurt(m, share, "opencount", {})
		say_at(m.tp, "shattered")
		for i in 6:
			spikes_fx.append({"tp": m.tp, "a": TAU * i / 6.0, "len": 0.7, "t": 0.4})

func on_count_kill(_m) -> void:
	if K("countm") <= 0:
		return
	kills9 += 1
	if kills9 % 9 == 0:
		for e in skels:
			if is_instance_valid(e) and not e.has_meta("crowned"):
				e.set_meta("crowned", true)
				e.max_hp *= 1.5
				e.hp = e.max_hp
				e.scale = Vector2(1.15, 1.15)
				say_at(e.tp, "crowned")
				break
