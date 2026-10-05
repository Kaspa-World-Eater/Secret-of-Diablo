class_name BoneMelee
extends RefCounted
## Secret of Mana style melee for the Bone Melee tree.
##
## Every swing empties the stamina gauge; swinging before it refills does
## reduced damage. Holding a charge skill at full stamina builds charge levels
## (SkillDB.CHARGE_TIME each). Releasing performs the move for that level:
## level 0 is a quick tap, 1-3 are the skill's charge attacks (4 with Ossuary
## Avatar, an empowered level 3).

const BONE := Color(0.95, 0.93, 0.85)


static func perform(p, id: String, charge: int, aim: Vector2) -> bool:
	var dir: Vector2 = aim - p.global_position
	dir = p.facing if dir.length() < 1.0 else dir.normalized()
	p.facing = dir
	var power := 1.0 + (0.5 if charge >= 4 else 0.0)
	var c: int = min(charge, 3)
	Sfx.play("swing", p.global_position, -2.0 + c)
	match id:
		"bone_blade": _blade(p, dir, c, power)
		"bone_lash": _lash(p, dir, c, power)
		"skull_crusher": _crusher(p, dir, c, power)
		"bone_scythe": _scythe(p, dir, c, power)
		"grave_spear": _spear(p, dir, c, power)
		"ribcage_guard": _guard(p, c, power)
		"corpse_splinter": return _splinter(p, dir, c, power, aim)
	return true


# ---------------------------------------------------------------- moves

static func _blade(p, dir: Vector2, c: int, power: float) -> void:
	var id := "bone_blade"
	match c:
		0: arc(p, id, dir, 50.0, 100.0, 1.0 * power, {"knock": 12.0})
		1: arc(p, id, dir, 58.0, 150.0, 1.6 * power, {"knock": 24.0})
		2:
			for i in 3:
				var flip := 1.0 if i % 2 == 0 else -1.0
				p.queue_strike(i * 0.16, func(): arc(p, id, p.facing.rotated(0.25 * flip), 54.0, 120.0, 1.1 * power, {"knock": 10.0, "stun": 0.15}))
		3:
			p.start_dash(dir, 90.0, 0.16, func(): arc(p, id, p.facing, 66.0, 200.0, 2.6 * power, {"knock": 45.0, "stun": 0.4}), "", 0.0)


static func _lash(p, dir: Vector2, c: int, power: float) -> void:
	var id := "bone_lash"
	match c:
		0: line(p, id, dir, 110.0, 18.0, 1.0 * power, {"knock": 8.0})
		1: line(p, id, dir, 150.0, 22.0, 1.5 * power, {"slow": 0.35, "knock": 10.0})
		2, 3:
			var hits := line(p, id, dir, 170.0, 26.0, 1.2 * power, {"pull": true, "stun": 0.8, "max": 1 if c == 2 else 99})
			if c == 3:
				for corpse in Game.corpses:
					var rel: Vector2 = corpse.global_position - p.global_position
					var along := rel.dot(dir)
					if along > 0.0 and along < 190.0 and abs(rel.dot(dir.orthogonal())) < 30.0:
						var dest: Vector2 = p.global_position + dir * 34.0
						var tw = corpse.create_tween()
						tw.tween_property(corpse, "global_position", dest, 0.2)
			if hits == 0 and c == 3:
				Game.fx(p.global_position + dir * 90.0, "line", BONE, 170.0, 0.2, dir)


static func _crusher(p, dir: Vector2, c: int, power: float) -> void:
	var id := "skull_crusher"
	match c:
		0: arc(p, id, dir, 46.0, 90.0, 1.6 * power, {"knock": 30.0, "stun": 0.2})
		1: arc(p, id, dir, 50.0, 100.0, 2.5 * power, {"knock": 70.0, "stun": 0.4})
		2:
			var at: Vector2 = p.global_position + dir * 40.0
			circle(p, id, at, 90.0, 2.2 * power, {"knock": 90.0, "stun": 0.5, "from": at})
			Game.fx(at, "burst", Color(0.85, 0.8, 0.65), 90.0, 0.35)
		3:
			var at: Vector2 = p.global_position + dir * 30.0
			circle(p, id, at, 150.0, 2.0 * power, {"knock": 60.0, "stun": 2.0, "from": at})
			Game.fx(at, "ring", Color(1, 0.95, 0.6), 150.0, 0.5)
			Game.fx(at, "burst", Color(0.85, 0.8, 0.65), 120.0, 0.4)


static func _scythe(p, dir: Vector2, c: int, power: float) -> void:
	var id := "bone_scythe"
	match c:
		0: arc(p, id, dir, 62.0, 160.0, 1.0 * power, {"knock": 14.0})
		1: arc(p, id, dir, 70.0, 210.0, 1.4 * power, {"knock": 20.0})
		2:
			p.queue_strike(0.0, func(): arc(p, id, p.facing, 70.0, 200.0, 1.3 * power, {"knock": 10.0}))
			p.queue_strike(0.22, func(): arc(p, id, p.facing, 70.0, 200.0, 1.3 * power, {"knock": 22.0}))
		3:
			for i in 3:
				p.queue_strike(i * 0.2, func(): circle(p, id, p.global_position, 78.0, 1.2 * power, {"knock": 18.0, "spin": true}))


static func _spear(p, dir: Vector2, c: int, power: float) -> void:
	var id := "grave_spear"
	match c:
		0: line(p, id, dir, 80.0, 20.0, 1.4 * power, {"knock": 16.0})
		1: line(p, id, dir, 115.0, 22.0, 1.8 * power, {"knock": 26.0})
		2:
			p.start_dash(dir, 150.0, 0.18, Callable(), id, 2.0 * power)
		3:
			line(p, id, dir, 115.0, 24.0, 2.5 * power, {"stun": 3.0, "max": 1, "pin": true})


static func _guard(p, c: int, power: float) -> void:
	var modes := ["block", "block", "parry", "reflect"]
	var times := [0.5, 1.2, 1.0, 1.5]
	p.guard_mode = modes[c]
	p.guard_time = times[c] * power
	p.guard_power = power
	Game.fx(p.global_position + Vector2(0, -14), "ring", BONE, 26.0, 0.3)


static func _splinter(p, dir: Vector2, c: int, power: float, aim: Vector2) -> bool:
	var corpse = Game.find_corpse(aim, 80.0)
	if corpse == null or corpse.global_position.distance_to(p.global_position) > 140.0:
		corpse = Game.find_corpse(p.global_position, 90.0)
	if corpse == null:
		Game.message("Strike a corpse near you")
		return false
	var src: Vector2 = corpse.global_position
	var w: Vector2 = SkillDB.bone_weapon_dmg(p, "corpse_splinter")
	var dmg := Vector2(w.x + corpse.max_hp * 0.15, w.y + corpse.max_hp * 0.3) * power
	var shards := []
	match c:
		0:
			for i in 5: shards.append(dir.rotated(lerp(-0.35, 0.35, i / 4.0)))
		1:
			for i in 9: shards.append(dir.rotated(lerp(-0.6, 0.6, i / 8.0)))
		2, 3:
			var n := 16 if c == 2 else 10
			for i in n: shards.append(Vector2.from_angle(TAU * i / n))
	for d in shards:
		Game.spawn_projectile({"pos": src, "vel": d * (320.0 if c == 3 else 460.0), "team": 0, "owner": p,
			"dmg": dmg, "dtype": "magic", "range": 900.0 if c == 3 else 340.0, "style": "spirit" if c == 3 else "teeth",
			"radius": 6.0, "homing": c == 3, "color": BONE})
	Game.fx(src, "burst", BONE, 40.0, 0.35)
	corpse.consume()
	return true


# ---------------------------------------------------------------- hit shapes

static func arc(p, id: String, dir: Vector2, rng: float, arc_deg: float, mult: float, opts := {}) -> int:
	var half := deg_to_rad(arc_deg) * 0.5
	var hits := 0
	for u in _enemies():
		var rel: Vector2 = u.global_position - p.global_position
		if rel.length() > rng + u.radius:
			continue
		if rel.length() > 4.0 and abs(dir.angle_to(rel)) > half:
			continue
		if hit(p, id, u, mult, opts):
			hits += 1
	Game.fx(p.global_position, "arc", BONE, rng, 0.18, dir, arc_deg)
	return hits


static func line(p, id: String, dir: Vector2, length: float, width: float, mult: float, opts := {}) -> int:
	var cands := []
	for u in _enemies():
		var rel: Vector2 = u.global_position - p.global_position
		var along := rel.dot(dir)
		if along < 0.0 or along > length + u.radius:
			continue
		if abs(rel.dot(dir.orthogonal())) > width * 0.5 + u.radius:
			continue
		cands.append([along, u])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var max_hits: int = opts.get("max", 99)
	var hits := 0
	for cu in cands:
		if hits >= max_hits:
			break
		if hit(p, id, cu[1], mult, opts):
			hits += 1
	Game.fx(p.global_position + dir * length * 0.5, "line", BONE, length, 0.18, dir)
	return hits


static func circle(p, id: String, center: Vector2, r: float, mult: float, opts := {}) -> int:
	var hits := 0
	for u in _enemies():
		if u.global_position.distance_to(center) <= r + u.radius:
			if hit(p, id, u, mult, opts):
				hits += 1
	if opts.get("spin", false):
		Game.fx(center, "arc", BONE, r, 0.2, p.facing, 360.0)
	return hits


static func _enemies() -> Array:
	var out := []
	for u in Game.units:
		if not u.dead and u.team != 0 and not u.invisible:
			out.append(u)
	return out


static func hit(p, id: String, u, mult: float, opts := {}) -> bool:
	## One melee hit with attack-rating roll, stamina scaling, knockback, stun and leech.
	if randf() > SkillDB.hit_chance(p, u):
		Game.float_text(u.global_position + Vector2(0, -20), "Miss", Color(0.75, 0.75, 0.75), 11)
		return false
	var w: Vector2 = SkillDB.bone_weapon_dmg(p, id)
	var dmg: float = randf_range(w.x, w.y) * mult * p.swing_power
	var dealt: float = u.take_damage(dmg, "physical", p, true)
	Sfx.play("hit_heavy" if mult >= 2.0 else "hit", u.global_position, -4.0)
	var lc: Vector2 = SkillDB.leech(p)
	if dealt > 0.0 and lc != Vector2.ZERO:
		p.heal(dealt * lc.x)
		p.mana = min(p.max_mana, p.mana + dealt * lc.y)
	if not is_instance_valid(u) or u.dead:
		return true
	var from: Vector2 = opts.get("from", p.global_position)
	if opts.get("pull", false):
		var to_p: Vector2 = p.global_position - u.global_position
		u.apply_knockback(to_p, max(0.0, to_p.length() - (p.radius + u.radius + 6.0)))
	elif opts.has("knock"):
		u.apply_knockback(u.global_position - from, opts["knock"] * p.swing_power)
	if opts.has("stun"):
		u.apply_stun(opts["stun"])
	if opts.has("slow"):
		u.apply_slow(opts["slow"], 2.0)
	if opts.get("pin", false):
		Game.fx(u.global_position, "pin", BONE, 16.0, 3.0)
	Game.fx(u.global_position + Vector2(0, -14), "burst", Color(1, 0.95, 0.8), 10.0, 0.15)
	return true
