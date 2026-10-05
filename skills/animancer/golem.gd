extends RefCounted
## The Iron Golem's mind and body (d_play.js newGolem .. updateGolem, hurtGolem, golemStrike, tossShield, updateShield,
## golemBurst, startRampage, updateChallenge; o_skills14.js startPhos/phosTick; k_arcana.js onGolemStrike).
## Permanent: at 0 life it falls dormant and rises after max(8, 22 - 0.7 x level) s (never under 10 s); wisps poured
## into a dormant golem only quicken it. Its view (golem_view.gd) stands in the zone and is what monsters hit.
## State is kept here so the golem survives zone changes (the view is rebuilt).

const MIN_DOWN := 10.0

var book                     # the Mystic's skill book (skills/animancer.gd)
var tp := Vector2.ZERO
var r := 0.62
var hp := 1.0
var max_hp := 1.0
var state := "active"        # active | dormant | chargeWind | charge
var rt := 0.0                # time left before it rises
var rt_max := 1.0
var down_t := 0.0
var boost := 0.0
var cd := 0.0                # the blow's own recovery (not a skill wait: its swing time)
var cc := 2.0                # time until it may shield-charge again (its stride)
var face := 1
var view := "front"
var t := 0.0
var hit_set := {}
var aim := Vector2.RIGHT
var shield := true
var toss_t := 1.0
var atk := {}                # {t, dur, target, done}
var charge := 0.0
var infused := 0
var idle_t := 0.0
var ramp := 0.0
var aura_t := 0.0
var beam_t := 0.0
var phos := {}
var order := {}              # {tp, t}
var hold = null              # Vector2 or null
var leashed := 0.0
var defy_t := 0.0
var ch_t := 1.0
var hurt_t := 0.0
var fly := {}                # the thrown shield: {tp, r, dir, dist, R, state, t, hit, rico, spin, tick}
var path := PackedVector2Array()
var path_i := 0
var repath := 0.0
var moved := 0.0             # yards walked this frame (for the walk cycle)
var node: Node2D             # the view in the zone

func _init(b, at: Vector2) -> void:
	book = b
	tp = at
	var st: Dictionary = book.ws_golem()
	max_hp = st["max"]
	hp = max_hp

# ------------------------------------------------------------------ being struck
## a blow from a creature (or its missile). from: the attacker (Monster) or where the blow came from (Vector2).
func take_hit(dmg: float, elem: String, from) -> void:
	if state == "dormant":
		return
	var st: Dictionary = book.ws_golem()
	var armor: float = st["armor"] * (1.0 if shield else 0.6)
	var d := dmg * (100.0 / (100.0 + armor) if elem == "phys" else 0.8)
	if ramp > 0.0:
		d *= 0.6
	if defy_t > 0.0:
		d *= 0.7
	hp -= d
	hurt_t = 0.1
	# Reflection: melee blows are thrown back; Cutting Glare staggers the striker
	var src = from if from is Monster else book.monster_near(from, 1.6)
	if book.K("thorns") > 0 and src != null and not src.dead and elem == "phys":
		book.hurt(src, d * book.ws_thorns_pct() / 100.0 + 2.0 * book.K("thorns"), "thorns", {"golem": true, "from": tp})
		if book.K("barbiron") > 0 and not src.boss:
			src.stun = maxf(src.stun, 0.3)
	# Anima Overflow: damage taken charges it
	var fr: float = book.ws_flow_rate()
	if fr > 0.0 and hp > 0.0:
		add_charge(d / max_hp * fr)
	if hp <= 0.0:
		hp = 0.0
		go_down(st["recharge"], "Your golem falls still.")

func go_down(secs: float, msg: String = "") -> void:
	state = "dormant"
	rt = secs
	rt_max = secs
	down_t = 0.0
	boost = 0.0
	atk = {}
	ramp = 0.0
	phos = {}
	path = PackedVector2Array()
	if msg != "":
		Bus.say.emit(msg, 1.6)
	book.dust(tp, 16, 1.6)

func rise() -> void:
	state = "active"
	hp = max_hp
	Bus.say.emit("Your golem rises.", 1.2)
	if book.aM("i_rally") and book.hero:
		var st = book.hero.st
		st.hp = minf(st.life_max(), st.hp + st.life_max() * 0.15)

# ------------------------------------------------------------------ Overcharge
func add_charge(n: float) -> void:
	if state == "dormant" or ramp > 0.0:
		return
	charge = minf(book.ws_charge_max(), charge + n)
	idle_t = 0.0
	if charge >= book.ws_charge_max():
		start_rampage()

func start_rampage() -> void:
	ramp = book.ws_ramp_life()
	charge = book.ws_charge_max()
	cc = 0.0
	Bus.say.emit("The golem burns white.", 1.4)

func burst() -> void:
	var R: float = book.ws_det_r()
	var dmg: float = book.ws_det_dmg() * book.ws_det_k()
	for m in book.mons():
		if m.dead:
			continue
		var d: float = m.tp.distance_to(tp)
		if d > R:
			continue
		book.hurt(m, dmg, "overcharge", {"from": tp})
		m.stun = maxf(m.stun, 1.0)
		var away: Vector2 = (m.tp - tp).normalized() if d > 0.01 else Vector2.RIGHT
		for i in 5:
			book.shove(m, away * 0.2)
	# Anima Overflow: a ring of seeking souls
	if book.K("overflow") > 0:
		var n := int(book.ws_flow_n())
		var sd: float = book.ws_flow_dmg()
		for i in n:
			var a := float(i) / n * TAU
			book.new_soul(tp, a, 7.0, sd, 1)
	book.ring(tp, R, 0.5)
	book.glass_burst(tp, 20, 3.0, 20.0)
	Bus.say.emit("The golem bursts.", 1.2)
	book.infusing = false
	var back := infused
	charge = 0.0
	infused = 0
	if book.K("wispreturn") > 0:
		for i in back:
			book.spawn_wisp(tp)
	go_down(3.0)

# ------------------------------------------------------------------ its blows
func strike(tgt: Monster) -> void:
	if tgt == null:
		return
	var st: Dictionary = book.ws_golem()
	var w: Dictionary = book.ws_weapon()
	var rm: float = book.ws_ramp_mult() if ramp > 0.0 else 1.0 + 0.04 * charge
	var o := {"golem": true, "from": tp, "melee": true}
	match w["id"]:
		"sword":
			if tgt.dead or tgt.tp.distance_to(tp) > w["reach"] + tgt.radius + 0.3:
				return
			book.hurt(tgt, randf_range(st["dmg"][0], st["dmg"][1]) * w["mult"] * rm, "golem", o.duplicate())
			if randf() < w["twice"] and not tgt.dead:
				book.hurt(tgt, randf_range(st["dmg"][0], st["dmg"][1]) * w["mult"] * rm, "golem", o.duplicate())
			_on_strike(tgt)
		"axe":
			for m in book.mons():
				var dv: Vector2 = m.tp - tp
				var d := dv.length()
				if d > w["reach"] + m.radius + 0.3:
					continue
				var da := acos(clampf(dv.dot(aim) / maxf(d, 0.001), -1.0, 1.0))
				if da > w["arc"] and d > 0.4:
					continue
				book.hurt(m, randf_range(st["dmg"][0], st["dmg"][1]) * w["mult"] * rm, "golem", o.duplicate())
			_on_strike(tgt)
		_:
			var reach := minf(tgt.tp.distance_to(tp), w["reach"] + 0.2)
			var p := tp + aim * reach
			for m in book.mons():
				if m.tp.distance_to(p) < w["aoe"] + m.radius:
					book.hurt(m, randf_range(st["dmg"][0], st["dmg"][1]) * w["mult"] * rm, "golem", o.duplicate())
					m.stun = maxf(m.stun, w["stun"])
			book.dust(p, 10, 1.6)
			if Settings.screen_shake:
				Game.hitstop(0.04)
			_on_strike(tgt)

## Quicksilver Heart's Sun-Catch: its blows set creatures alight
func _on_strike(tgt: Monster) -> void:
	if book.aU("a_anvil") and tgt:
		book._splinter_ring(tgt.tp, 0.6, 2)   # The Anvil: its blows leave glass on the ground
	if book.K("moltencore") > 0 and tgt and not tgt.dead:
		tgt.add_dot(book.ws_golem()["dmg"][1] * 0.4, 3.0, "fire")

# ------------------------------------------------------------------ orders (the G panel): x ranges 0 close .. 4 roam, y 0 guard .. 4 attack
func orders() -> Dictionary:
	var B: Dictionary = book.gbeh
	return {"leash": 1.8 + B["x"] * 1.7, "aggro": 2.5 + B["y"] * 1.5 + B["x"] * 0.6, "guard": B["y"] <= 1}

func _anchor() -> Vector2:
	var B: Dictionary = book.gbeh
	if not order.is_empty() and tp.distance_to(order["tp"]) < 0.6:
		return order["tp"]
	if B["hold"] and hold != null:
		return hold
	return book.hero.tp

func pick() -> Monster:
	var B: Dictionary = book.gbeh
	var O := orders()
	var anchor := _anchor()
	var aggro: float = maxf(O["aggro"], 7.0) if ramp > 0.0 else O["aggro"]
	var lh = book.last_hit
	if B["focus"] and lh != null and is_instance_valid(lh) and not lh.dead and lh.tp.distance_to(anchor) < aggro + 3.0:
		return lh
	var best: Monster = null
	var bd := 1e9
	var hp_tp: Vector2 = book.hero.tp
	for m in book.mons():
		var dA: float = m.tp.distance_to(anchor)
		if dA > aggro:
			continue
		if book.is_idle(m) and m.tp.distance_to(hp_tp) > 6.0:
			continue
		if O["guard"] and ramp <= 0.0 and m.tp.distance_to(hp_tp) > 3.2 and not book.threatens(m):
			continue
		var d: float = m.tp.distance_to(tp) + dA * 0.3
		if d < bd:
			bd = d
			best = m
	return best

# ------------------------------------------------------------------ the frame
func tick(dt: float) -> void:
	var st: Dictionary = book.ws_golem()
	max_hp = st["max"]
	hp = minf(hp, max_hp)
	hurt_t = maxf(0.0, hurt_t - dt)
	t += dt
	toss_t -= dt
	moved = 0.0
	_update_shield(dt)
	if state == "dormant":
		down_t += dt
		boost = maxf(0.0, boost - 0.06 * dt)
		rt -= dt * (1.0 + boost)
		if rt <= 0.0 and down_t >= MIN_DOWN:
			rise()
		return
	# a partial charge left alone bleeds its wisps back, one at a time
	if ramp <= 0.0 and charge > 0.0 and not book.infusing:
		idle_t += dt
		if idle_t > 12.0:
			idle_t = 11.0
			charge = maxf(0.0, charge - 1.0)
			if infused > 0:
				infused -= 1
	# rampage: white fire about it, then the burst
	if ramp > 0.0:
		ramp -= dt
		aura_t -= dt
		if aura_t <= 0.0:
			aura_t = 0.25
			var R: float = book.ws_aura_r()
			var ad: float = book.ws_aura_dps() * 0.25
			for m in book.mons():
				if m.tp.distance_to(tp) < R + m.radius:
					book.hurt(m, ad, "overcharge", {"from": tp, "poise": ad * 0.5})
		beam_t -= dt
		if phos.is_empty() and beam_t <= 0.0:
			phos = _start_phos()
			beam_t = ((2.2 if book.K("ghostfire") > 0 else 3.5) if not phos.is_empty() else 0.3)
		if ramp <= 0.0:
			phos = {}
			burst()
			return
		if not phos.is_empty():
			atk = {}
			if state == "charge" or state == "chargeWind":
				state = "active"
			if _phos_tick(dt):
				phos = {}
			return
	cd -= dt
	cc -= dt
	if defy_t > 0.0:
		defy_t -= dt
	var spd: float = st["spd"] * (1.4 if ramp > 0.0 else 1.0 + 0.03 * charge) * (1.25 if leashed > 0.0 else 1.0) * (1.25 if book.aM("i_stride") else 1.0)
	if leashed > 0.0:
		leashed -= dt
	if state == "chargeWind":
		if t > 0.35:
			state = "charge"
			t = 0.0
			hit_set = {}
		return
	if state == "charge":
		var o := tp
		var kb: float = 0.2 + 0.02 * book.K("bulwark")
		_move_by(aim * 11.0 * dt)
		for m in book.mons():
			if hit_set.has(m.get_instance_id()) or m.tp.distance_to(tp) > r + m.radius + 0.15:
				continue
			hit_set[m.get_instance_id()] = true
			book.hurt(m, randf_range(st["dmg"][0], st["dmg"][1]) * 1.5, "golem", {"golem": true, "from": tp, "heavy": true})
			m.stun = maxf(m.stun, 1.2)
			for i in 6:
				book.shove(m, aim * kb)
		if t > 0.5 or o.distance_to(tp) < 0.0001:
			state = "active"
			cd = 0.3
			cc = randf_range(5.0, 8.0)
		return
	if not atk.is_empty():
		atk["t"] += dt
		if not atk["done"] and atk["t"] >= atk["dur"] * 0.55:
			atk["done"] = true
			var tg = atk["target"]
			if is_instance_valid(tg):
				strike(tg)
		if atk["t"] >= atk["dur"]:
			atk = {}
		return
	var B: Dictionary = book.gbeh
	var O := orders()
	var hero_tp: Vector2 = book.hero.tp
	var anchor: Vector2 = hold if (B["hold"] and hold != null) else hero_tp
	_challenge(dt)
	if not order.is_empty():
		var od: float = tp.distance_to(order["tp"])
		if od > 0.5:
			_walk_to(order["tp"], spd * 1.25, dt)
			return
		order["t"] -= dt
		if order["t"] <= 0.0:
			order = {}
	if tp.distance_to(hero_tp) > 16.0:
		tp = book.walkable_near(hero_tp + Vector2(1, 0))
		path = PackedVector2Array()
	var tgt := pick()
	if tgt:
		var d: float = tgt.tp.distance_to(tp)
		var w: Dictionary = book.ws_weapon()
		aim = (tgt.tp - tp).normalized() if d > 0.001 else aim
		_look(tgt.tp - tp)
		var z = book.zone
		if B["toss"] and book.K("toss") > 0 and shield and d > 2.4 and d < 7.0 and toss_t <= 0.0 and z.sight_clear(tp, tgt.tp):
			_toss(tgt)
			cd = 0.5
			return
		if B["charge"] and shield and d > 2.5 and d < 5.5 and cc <= 0.0 and z.line_clear(tp, tgt.tp):
			state = "chargeWind"
			t = 0.0
			return
		if d > w["reach"] + tgt.radius - 0.05:
			_walk_to(tgt.tp, spd, dt)
		elif cd <= 0.0:
			var dur: float = w["dur"] / (1.35 if ramp > 0.0 else 1.0) / (1.25 if leashed > 0.0 else 1.0)
			atk = {"t": 0.0, "dur": dur, "target": tgt, "done": false}
			cd = dur
	elif not order.is_empty():
		pass
	elif tp.distance_to(anchor) > (minf(1.8, O["leash"]) if anchor == hero_tp else 0.4):
		_walk_to(anchor, spd * 1.1, dt)

func _look(dir: Vector2) -> void:
	var rr := AnimSprite.mon_view(dir, face)
	if rr[0] != "":
		view = rr[0]
		face = rr[1]

func _move_by(v: Vector2) -> void:
	var z = book.zone
	var o := tp
	tp = z.move(tp, v, r * 0.6)
	moved += o.distance_to(tp)

## walk toward a point: straight when the line is clear, else along a path (repathed now and then)
func _walk_to(p: Vector2, spd: float, dt: float) -> void:
	var z = book.zone
	_look(p - tp)
	var step := spd * dt
	if z.line_clear(tp, p):
		path = PackedVector2Array()
		var to := p - tp
		_move_by(to.normalized() * minf(step, to.length()))
		return
	repath -= dt
	if path.is_empty() or repath <= 0.0:
		path = z.path(tp, p)
		path_i = 1 if path.size() > 1 else 0
		repath = 0.5
	if path_i >= path.size():
		return
	var wp: Vector2 = path[path_i]
	var to2 := wp - tp
	if to2.length() <= step:
		path_i += 1
	_move_by(to2.normalized() * minf(step, to2.length()))

# ------------------------------------------------------------------ Dazzling Challenge: its polished face
func _challenge(dt: float) -> void:
	if book.K("challenge") <= 0 or state == "dormant":
		return
	ch_t -= dt
	if ch_t > 0.0:
		return
	ch_t = book.ws_challenge_cd()
	var R: float = book.ws_challenge_r()
	var n := 0
	for m in book.mons():
		if m.boss or m.tp.distance_to(tp) >= R:
			continue
		book.taunt(m, node, 3.0)
		n += 1
		if book.K("warcry") > 0:
			m.slow = maxf(m.slow, 0.6)
	if n > 0 and book.K("defy") > 0:
		defy_t = 3.0

# ------------------------------------------------------------------ Mirror Shield
func _toss(tgt: Monster) -> void:
	var d := maxf(0.01, tgt.tp.distance_to(tp))
	shield = false
	fly = {"tp": tp, "r": 0.42, "dir": (tgt.tp - tp) / d, "dist": 0.0, "R": minf(7.0, d + 1.0) * (1.5 if book.aM("i_shield") else 1.0), "state": "out", "t": 0.0,
		"hit": {}, "rico": book.ws_ricochet(), "spin": 0.0, "tick": 0.0}

func _shield_hits() -> void:
	var st: Dictionary = book.ws_golem()
	var s := fly
	for m in book.mons():
		var k: int = m.get_instance_id()
		if s["hit"].has(k) or m.tp.distance_to(s["tp"]) > s["r"] + m.radius:
			continue
		s["hit"][k] = true
		var tdm: float = randf_range(st["dmg"][0], st["dmg"][1]) * book.ws_toss_dmg() * (book.ws_ramp_mult() if ramp > 0.0 else 1.0)
		book.hurt(m, tdm, "toss", {"from": s["tp"]})
		if book.aR("a_storm") and int(s.get("storm_x", 0)) < 4:
			s["storm_x"] = int(s.get("storm_x", 0)) + 1
			s["rico"] += 1   # Storm reversed: one more rebound for each creature it cuts, up to four
		m.stun = maxf(m.stun, 1.0 if book.K("tossstun") > 0 else 0.4)
		if s["state"] == "out" and s["rico"] > 0:
			var nt: Monster = null
			var bd := 4.0
			for o in book.mons():
				if s["hit"].has(o.get_instance_id()):
					continue
				var dd: float = o.tp.distance_to(s["tp"])
				if dd < bd:
					bd = dd
					nt = o
			if nt:
				s["rico"] -= 1
				s["dir"] = (nt.tp - s["tp"]) / maxf(bd, 0.01)
				s["dist"] = 0.0
				s["R"] = bd + 0.6

func _update_shield(dt: float) -> void:
	if fly.is_empty():
		return
	var s := fly
	s["spin"] += dt * 18.0
	s["t"] += dt
	var z = book.zone
	if s["state"] == "out":
		var step := 9.0 * dt
		var n: Vector2 = s["tp"] + s["dir"] * step
		if z.blocks_sight(n):
			s["state"] = "hover"
			s["t"] = 0.0
		else:
			s["tp"] = n
			s["dist"] += step
			if s["dist"] >= s["R"]:
				s["state"] = "hover"
				s["t"] = 0.0
		_shield_hits()
	elif s["state"] == "hover":
		s["tick"] -= dt
		if s["tick"] <= 0.0:
			s["tick"] = 0.5
			s["hit"] = {}
		_shield_hits()
		if s["t"] >= book.ws_toss_hover():
			s["state"] = "back"
			s["hit"] = {}
	else:
		var d: float = s["tp"].distance_to(tp)
		if d < 0.6:
			shield = true
			toss_t = 2.5
			fly = {}
			return
		var sp := minf(d, 11.0 * dt)
		s["tp"] += (tp - s["tp"]) / d * sp
		_shield_hits()

# ------------------------------------------------------------------ the berserk golem's beam (a thin pale line, no glow)
func _start_phos() -> Dictionary:
	var best: Monster = null
	var bd := 7.0
	var z = book.zone
	for m in book.mons():
		var d: float = m.tp.distance_to(tp)
		if d < bd and z.sight_clear(tp, m.tp):
			bd = d
			best = m
	if best == null:
		return {}
	var a := atan2(best.tp.y - tp.y, best.tp.x - tp.x)
	var dir := 1.0 if randf() < 0.5 else -1.0
	return {"t": 0.0, "dur": 1.3, "a0": a - dir * 0.85, "a1": a + dir * 0.85, "len": 6.5, "hit": {}, "fire_t": 0.0, "ang": a - dir * 0.85, "end": tp}

func _phos_tick(dt: float) -> bool:
	var ph := phos
	ph["t"] += dt
	var k := minf(1.0, ph["t"] / ph["dur"])
	var ease := k * k * (3.0 - 2.0 * k)
	ph["ang"] = ph["a0"] + (ph["a1"] - ph["a0"]) * ease
	var dv := Vector2(cos(ph["ang"]), sin(ph["ang"]))
	var L: float = ph["len"]
	var s := 0.3
	var z = book.zone
	while s < ph["len"]:
		if z.blocks_sight(tp + dv * s):
			L = s
			break
		s += 0.2
	ph["end"] = tp + dv * L
	_look(dv)
	var dps: float = book.ws_aura_dps() * 1.6
	for m in book.mons():
		if book.seg_dist(m.tp, tp, ph["end"]) > m.radius + 0.3:
			continue
		var key: int = m.get_instance_id()
		if book.time - float(ph["hit"].get(key, -9.0)) < 0.2:
			continue
		ph["hit"][key] = book.time
		book.hurt(m, dps * 0.2, "overcharge", {"from": tp, "poise": dps * 0.1})
		if not m.dead:
			m.add_dot(dps * 0.15, 2.0, "fire")
	ph["fire_t"] -= dt
	if ph["fire_t"] <= 0.0:
		ph["fire_t"] = 0.12
		book.ground_fire(ph["end"], 0.5, dps * 0.1, 2.2)
	return ph["t"] >= ph["dur"]
