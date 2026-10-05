extends "res://skills/ossumancer/tree_carapace.gd"
## The Ossuarch, part 4 of 5: the Count tree, his melee techniques and the numerology curses
## (docs/concepts/ossuarch/SKILLS.md, Derek 2026-10-05). Melee costs poise, never Marrow.
##
## Bone Blade, a CHARGED technique: bone grows over the head of whatever weapon he holds.
##   Tap (or a short hold) -> tier 1: a lunging thrust, one notch.
##   Hold past the first mark -> tier 2: the blade grows long and crooked and cleaves a wide arc, two notches.
##   Hold past the second -> tier 3: an overhead cut that splits the ground ahead in a dead-straight line, three notches;
##   at level 10 the split leaves spurs standing in it.
## Charging costs poise as each tier fills; he walks slowly while he holds; a roll cancels it. With charging turned off
## (Settings.charge_melee) holding keeps striking and the string climbs the tiers instead: 1, 2, 3, 1, 2, 3...
##
## Notches: every stroke cuts notches in what it strikes (1, 2 or 3 by tier). Nine closes the count: with Tally, the
## closing blow lands at double force. (The kept curse and the other curses come later.)

const BLADE_T := [0.22, 0.55]          # seconds to reach tier 2 and tier 3 (before the level's speed-up)
const BLADE_POISE := [5.0, 7.0, 9.0]   # poise to fill each tier
const BLADE_K := [1.0, 1.45, 2.1]      # damage of each tier's stroke, times the blade's own multiplier

var bcharge := {}                       # {t, tier, at, goal}
var bstring := 0                        # charging off: the next stroke in the string (0, 1, 2)
var bstring_idle := 0.0

## the Bone Host lengthens his weapon with bone: +0.35 yd and 0.1 a skeleton (eight at most); Long Bone +0.33
func host_reach() -> float:
	var n := int(host.get("n", 0))
	return (0.35 + 0.1 * mini(8, n) if n > 0 else 0.0) + (0.33 if K("bladereach") > 0 else 0.0)

func blade_speed() -> float:          # points in the Blade fill the charge faster: 2% a level, to 30%
	return 1.0 + minf(0.3, 0.02 * (L1("blade") - 1.0))

func blade_reach() -> float:
	return hero._reach() + MELEE["blade"] + host_reach()

func split_len() -> float:             # the tier-3 split's length in yards
	return 4.0 + 0.12 * L1("blade")

## the one press: begin a charge, or (charging off) strike the string's next stroke now
func cast_blade(a: Vector2, target) -> bool:
	if not Settings.charge_melee or bool(origin != null):
		if bstring_idle > 1.1:
			bstring = 0
		var tier := bstring
		bstring = (bstring + 1) % 3
		bstring_idle = 0.0
		return strike_blade_tier(a, target, tier)
	if not bcharge.is_empty():
		return false
	bcharge = {"t": 0.0, "tier": 0, "at": a, "target": target}
	cast_len = 4.0                     # the act is held open while he charges; tick_blade releases it
	return true

## every frame: fill the charge while the button is held; release the stroke when it isn't
func tick_blade(dt: float) -> void:
	bstring_idle += dt
	if bcharge.is_empty():
		return
	if hero.dead or hero.act == "roll" or hero.act == "stun":
		bcharge = {}
		return
	bcharge["t"] += dt * blade_speed()
	if not bcharge.has("goal"):
		bcharge["at"] = aim_point()
	hero._face(bcharge["at"] - hero.tp)
	if hero.act == "cast" or hero.act == "atk":
		hero.act_t = minf(hero.act_t, hero.act_len * 0.3)   # hold the drawn-back pose while it grows
	var tier: int = bcharge["tier"]
	if tier < 2 and bcharge["t"] >= BLADE_T[tier]:
		if hero.st.poise >= BLADE_POISE[tier + 1] * 0.5:
			hero.spend_poise(BLADE_POISE[tier + 1])
			bcharge["tier"] = tier + 1
			dust(hero.tp, 3)
			Sfx.play("break", 0.22, 1.4 - 0.25 * tier)
		else:
			bcharge["t"] = BLADE_T[tier]      # too weary to draw it further
	var goal: int = int(bcharge.get("goal", -1))
	var release: bool = not held("blade") if goal < 0 else int(bcharge["tier"]) >= goal
	if int(bcharge["tier"]) >= 2 and bcharge["t"] > BLADE_T[1] + 0.6:
		release = true                    # a full charge held too long goes on its own
	if release:
		var at: Vector2 = bcharge["at"]
		var tr: int = bcharge["tier"]
		var tg = bcharge.get("target")
		bcharge = {}
		hero.act = ""
		strike_blade_tier(at, tg, tr)

## the strokes
func strike_blade_tier(a: Vector2, target, tier: int) -> bool:
	var reach: float = blade_reach()
	var dir: Vector2 = (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.05 else Vector2(1, 1).normalized()
	var dmg: float = weapon_avg() * hero.st.melee_mult() * blade_k() * BLADE_K[tier] * melee_k()
	var hit := 0
	match tier:
		0:   # the thrust: a short lunge, then the point through what stands in line
			hero.tp = zone.move(hero.tp, dir * 0.45, hero.radius)
			for m in foes(hero.tp + dir * reach * 0.6, reach):
				var rel: Vector2 = m.tp - hero.tp
				var along: float = rel.dot(dir)
				if along > -0.2 and along < reach + 0.6 + m.radius and absf(rel.cross(dir)) < 0.45 + m.radius:
					_blade_hit(m, dmg, 1)
					hit += 1
		1:   # the cleave: a wide arc in front
			for m in foes(hero.tp, reach + 1.0):
				var rel2: Vector2 = m.tp - hero.tp
				if rel2.length() < reach + 0.9 + m.radius and rel2.normalized().dot(dir) > cos(deg_to_rad(68.0)):
					_blade_hit(m, dmg, 2)
					hit += 1
		2:   # the split: the ground opens in a dead-straight line ahead; everything in it is struck and staggered
			var L: float = split_len()
			for m in foes(hero.tp + dir * L * 0.5, L * 0.6 + 1.0):
				var rel3: Vector2 = m.tp - hero.tp
				var along3: float = rel3.dot(dir)
				if along3 > 0.0 and along3 < L + m.radius and absf(rel3.cross(dir)) < 0.55 + m.radius:
					_blade_hit(m, dmg, 3)
					if m.rank != "boss":
						m.stun = maxf(m.stun, 0.5)
					hit += 1
			blade_fx.append({"kind": "split", "tp": hero.tp, "dir": dir, "len": L, "t": 0.0, "spurs": K("blade") >= 10})
			if K("blade") >= 10:
				for i in 5:
					var p: Vector2 = hero.tp + dir * L * (0.2 + 0.18 * i)
					spikes_fx.append({"tp": p, "a": randf() * TAU, "len": 0.5 + randf() * 0.3, "t": 0.6})
			Game.shake(2.0)
	blade_fx.append({"kind": ["thrust", "cleave", "split_flash"][tier], "tp": hero.tp, "dir": dir, "reach": reach, "t": 0.0, "tier": tier})
	hero._face(dir)
	hero._start_act(["atk", "atk2", "atk"][tier], [0.34, 0.42, 0.55][tier] / hero.st.attack_speed())
	hero.act_done = true                  # the stroke has landed already; the act is the motion
	cast_len = -1.0
	Sfx.play("heavy" if tier == 2 else "hit", 0.9, [1.0, 0.85, 0.7][tier])
	if hit > 0 and tier >= 1:
		Game.hitstop(0.04 + 0.03 * tier)
	return true

func _blade_hit(m, dmg: float, notches: int) -> void:
	var n: int = int(m.get_meta("notch", 0)) + notches
	var closed := n >= 9
	var d: float = dmg
	if closed:
		n -= 9
		if K("tally") > 0:
			d *= 2.0
		blade_fx.append({"kind": "close", "tp": m.tp, "t": 0.0})
	m.set_meta("notch", n)
	hurt(m, d, "blade", {"melee": true})
	dust(m.tp, 2 + notches)

## (the old one-press Bone Blade, kept for the Pale Lords' echo and tests)
func strike_blade(a: Vector2, target) -> bool:
	return strike_blade_tier(a, target, 1)
