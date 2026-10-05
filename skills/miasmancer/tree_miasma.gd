extends "res://skills/miasmancer/base.gd"
## The Shrine Keeper, part 2 of 5: the Miasma tree's casts (Venom Claws, Iron War-Fan, Exhalation, Contagion, Tide).
## The cloud itself, breathing and sickness live in the frame (skills/miasmancer.gd).
## Chain: base -> tree_miasma -> tree_distortion -> tree_death -> skills/miasmancer.gd.

# ------------------------------------------------------------------ Miasma
func _shuriken(a: Vector2) -> bool:
	var base := (a - hero.tp).angle()
	var dmg := shuri_dmg()
	for dir in ([1, -1] if K("shuritwo") > 0 else [1]):
		shuris.append({"c": hero.tp, "a0": base - dir * 0.6, "dir": float(dir), "t": 0.0, "life": 2.4, "dmg": dmg, "hitT": {}, "tp": hero.tp, "spin": 0.0, "trail": 0.2})
	Sfx.play("swing", 0.6, 1.8)
	return true

func _nova(a: Vector2) -> bool:
	var c := clamp_cast(a, 8.0) if aR("z_bloom") else hero.tp
	novas.append({"tp": c, "r": 0.3, "max": 5.0, "hit": {}, "dmg": nova_dmg(), "psn": nova_psn()})
	if K("twinnova") > 0:
		var d := nova_dmg()
		var ps := nova_psn()
		later(0.5, func(): novas.append({"tp": c, "r": 0.3, "max": 5.0, "hit": {}, "dmg": d, "psn": ps}))
	return true

func _tide(a: Vector2) -> bool:
	var dv := (a - hero.tp).normalized()
	if dv.length() < 0.1:
		dv = Vector2(1, 0)
	var w := 3.6 if K("wwide") > 0 else 2.4
	if aR("z_tide"):
		tides.append({"spin": true, "c": hero.tp, "follow": not sister_cast, "ang": dv.angle(), "t": 2.0, "w": 1.7, "hitT": {}, "dmg": tide_dmg() * 0.6})
		return true
	var angs := [-0.45, 0.0, 0.45] if aU("z_tide") else [0.0]
	for o: float in angs:
		var e := dv.rotated(o)
		tides.append({"tp": hero.tp + e * 0.4, "d": e, "w": w * 0.7 if o != 0.0 else w, "t": 1.1, "hit": {}, "dmg": tide_dmg() * (0.7 if o != 0.0 else 1.0), "trailT": 0.0, "trail": K("wtrail") > 0})
	return true

func _exhale() -> bool:
	var spent := maxf(5.0, hero.st.res)
	var dmg := exhale_k() * spent
	var R := 3.5
	hero.st.res = spent * ((0.25 if aM("zm_breath") else 0.0) + (0.33 if K("exhalekeep") > 0 else 0.0))
	for m in foes(hero.tp, R):
		hurt(m, dmg, "exhale")
		psn(m, dmg * 0.2, 4.0)
		if K("gasp") > 0:
			confuse(m, 2.0)
		shove(m, hero.tp, 0.8)
	ring(hero.tp, R, 0.45, VIOLET)
	puff(hero.tp, VIOLET, 24, 3.5)
	Game.shake(3.0)
	say_at(hero.tp + Vector2(0, -0.3), "exhale %d" % int(spent), VIOLET)
	return true
