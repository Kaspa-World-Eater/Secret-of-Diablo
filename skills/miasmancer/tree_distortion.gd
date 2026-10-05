extends "res://skills/miasmancer/tree_miasma.gd"
## The Shrine Keeper, part 3 of 5: the Distortion (Trap) tree: sentries, censers, bladders, Blur, Haze, Mirage, the Lure.

# ------------------------------------------------------------------ Distortion
func _blur(a: Vector2) -> bool:
	var p := clamp_cast(a, 6.0)
	var o := hero.tp
	if zone.is_solid(p):
		p = o.lerp(p, 0.5)
		if zone.is_solid(p):
			return false
	if aR("z_mirror"):
		var m := near(a, 3.0)
		if m:
			var d: float = m.tp.distance_to(hero.tp)
			hero.tp = hero.tp.lerp(m.tp, maxf(0.0, (d - m.radius - 0.4) / maxf(d, 0.01)))
			hurt(m, crit(weapon() * 1.5), "blur", {"melee": true, "elem": "phys"})
			add_omen()
		else:
			hero.tp = p
	else:
		hero.tp = p
	var life := 5.0 if aM("zd_blur") else 3.0
	_decoy(o, life, hero.face)
	if aU("z_mirror"):
		_decoy(o + Vector2(0.8, 0.4), life, -hero.face)
	for m in mons():
		if m.tp.distance_to(hero.tp) < 12.0 and m.brain and m.brain.state != "sleep":
			m.set_meta("mys_taunt_by", decoys.back() if not decoys.is_empty() else null)
			m.set_meta("mys_taunt_until", now() + 1.5)
	if K("smear") > 0:
		blur_ev = 2.0
	if K("unseenstep") > 0:
		unseen_t = maxf(unseen_t, 1.0)
	hero.invuln = maxf(hero.invuln, 0.15)
	hero.walking = false
	puff(o, WARP, 12, 2.0)
	puff(hero.tp, WARP, 10, 1.8)
	cast_len = 0.2
	return true

func _decoy(p: Vector2, life: float, face: int) -> void:
	var d = Ally.new()
	d.book = self
	d.kind = "decoy"
	d.tp = p
	d.life = life
	d.hp = hero.st.life_max() * 0.3
	d.max_hp = d.hp
	d.face = face
	zone.sorted.add_child(d)
	decoys.append(d)

func decoy_gone(d) -> void:
	decoys.erase(d)
	puff(d.tp, WARP, 12, 2.0)
	if K("rotdouble") > 0:
		add_cloud(d.tp, 1.6, 4.0, aura_dps() * 1.5)

func _throw_trap(kind: String, a: Vector2) -> bool:
	if aR("z_trapq") and not sister_cast:
		if worn_traps.size() >= trap_max():
			worn_traps.pop_front()
		worn_traps.append(kind)
		say_at(hero.tp + Vector2(0, -0.3), "trap worn", Color8(201, 166, 107))
		return true
	var p := clamp_cast(a, 8.0)
	throws.append({"kind": kind, "from": hero.tp, "to": p, "t": 0.0, "dur": 0.3, "k": sister_k() if sister_cast else 1.0})
	return true

func _place_trap(kind: String, p: Vector2, armed: bool, k: float) -> void:
	var mine := traps.filter(func(t): return not t.get("done", false))
	while mine.size() >= trap_max():
		var o: Dictionary = mine.pop_front()
		o["done"] = true
		puff(o["tp"], Color8(111, 106, 121), 6)
	var life := wake_life() if kind == "mwake" else 40.0
	traps.append({"kind": kind, "tp": p, "arm": 0.0 if armed else arm_t(), "charges": (18 if K("needlemore") > 0 else 12) if kind == "ntrap" else 1,
		"cd": 0.0, "t": life, "max": life, "k": k, "leakT": 0.0, "waveT": 0.4, "burstT": 1.0})

func _trap_trigger(t: Dictionary) -> void:
	if t["kind"] != "bmine":
		return
	t["done"] = true
	var R := 2.4 if K("minebig") > 0 else 1.6
	var boom := func(k: float):
		for o in foes(t["tp"], R):
			hurt(o, mine_dmg() * k * t["k"], "bmine")
			psn(o, mine_dmg() * 0.15 * k * t["k"], 4.0)
			if K("minefear") > 0:
				fear(o, 1.5)
		add_cloud(t["tp"], R * 1.35, 6.0, mine_dmg() * 0.15 * t["k"])
		puff(t["tp"], VIOLET, 24, 3.0)
		Game.shake(2.5)
		Sfx.play("heavy", 0.6, 0.6)
	boom.call(1.0)
	if aM("zd_mine"):
		later(0.7, func(): boom.call(0.6))
