class_name Skills
extends RefCounted
## Necromancer skill execution. Formulas live in SkillDB.


static func cast(p, id: String, lvl: int, pos: Vector2, hover) -> bool:
	match id:
		"raise_skeleton":
			return _raise(p, "skeleton", lvl, pos)
		"raise_skeletal_mage":
			return _raise(p, "mage", lvl, pos)
		"revive":
			return _revive(p, lvl, pos)
		"clay_golem", "blood_golem", "iron_golem", "fire_golem":
			return _golem(p, id, lvl, pos)
		"teeth":
			return _teeth(p, lvl, pos)
		"bone_spear":
			var d := _dir(p, pos)
			Game.spawn_projectile({"pos": p.global_position, "vel": d * 650.0, "team": 0, "owner": p,
				"dmg": SkillDB.bone_spear_dmg(lvl, p), "dtype": "magic", "range": 650.0, "style": "spear",
				"radius": 7.0, "pierce": true, "color": Color(0.95, 0.93, 0.85)})
			return true
		"bone_spirit":
			var t = hover if hover != null else Game.nearest_hostile(pos, 0, 250.0)
			Game.spawn_projectile({"pos": p.global_position, "vel": _dir(p, pos) * 300.0, "team": 0, "owner": p,
				"dmg": SkillDB.bone_spirit_dmg(lvl, p), "dtype": "magic", "range": 1400.0, "style": "spirit",
				"radius": 8.0, "homing": true, "target": t, "color": Color(0.85, 0.95, 1.0)})
			return true
		"poison_nova":
			var n := 36
			for i in n:
				Game.spawn_projectile({"pos": p.global_position, "vel": Vector2.from_angle(TAU * i / n) * 260.0,
					"team": 0, "owner": p, "range": 300.0, "style": "nova", "radius": 7.0, "pierce": true,
					"poison": SkillDB.poison_nova_poison(lvl, p), "color": Color(0.4, 1.0, 0.3)})
			return true
		"corpse_explosion":
			return _corpse_explosion(p, lvl, pos)
		"poison_explosion":
			return _poison_explosion(p, lvl, pos)
		"bone_armor":
			p.bone_armor = SkillDB.bone_armor_absorb(lvl, p)
			p.bone_armor_max = p.bone_armor
			Game.fx(p.global_position + Vector2(0, -14), "ring", Color(0.95, 0.92, 0.8), 28.0, 0.5)
			return true
		"bone_wall":
			return _bone_wall(p, lvl, pos)
		"bone_prison":
			return _bone_prison(p, pos, hover)
	return false


static func _dir(p, pos: Vector2) -> Vector2:
	var d: Vector2 = pos - p.global_position
	return p.facing if d.length() < 1.0 else d.normalized()


static func _raise(p, which: String, lvl: int, pos: Vector2) -> bool:
	var c = Game.find_corpse(pos, 110.0)
	if c == null:
		Game.message("There is no corpse there")
		return false
	var list: Array = p.skeletons if which == "skeleton" else p.mages
	Game.prune(list)
	if list.size() >= SkillDB.skeleton_cap(lvl):
		Game.message("You cannot raise any more")
		return false
	var stats: Dictionary
	if which == "skeleton":
		stats = SkillDB.skeleton_stats(lvl, p)
	else:
		stats = SkillDB.mage_stats(lvl, p, ["fire", "cold", "lightning", "poison"].pick_random())
	stats["level"] = lvl
	var m = Game.spawn_creature(stats, 0, c.global_position, p)
	list.append(m)
	Game.fx(c.global_position + Vector2(0, -8), "burst", Color(0.85, 0.85, 0.75), 26.0, 0.4)
	c.consume()
	return true


static func _revive(p, lvl: int, pos: Vector2) -> bool:
	var c = Game.find_corpse(pos, 110.0)
	if c == null:
		Game.message("There is no corpse there")
		return false
	Game.prune(p.revives)
	if p.revives.size() >= lvl:
		Game.message("You cannot revive any more")
		return false
	var stats := CreatureDB.monster_stats(c.kind, c.level, false)
	stats["hp"] *= 2.0
	stats["name"] = "Revived " + stats["name"]
	stats["revived"] = true
	stats["role"] = "revive"
	stats["res"] = SkillDB.summon_res(p)
	var m = Game.spawn_creature(stats, 0, c.global_position, p)
	m.lifetime = SkillDB.revive_lifetime()
	p.revives.append(m)
	Game.fx(c.global_position, "ring", Color(0.5, 0.6, 1.0), 36.0, 0.5)
	c.consume()
	return true


static func _golem(p, id: String, lvl: int, pos: Vector2) -> bool:
	if p.golem != null and is_instance_valid(p.golem) and not p.golem.dead:
		p.golem.die(null)
	var spawn := pos
	if pos.distance_to(p.global_position) > 300.0 or not Game.world.is_walkable_px(pos):
		spawn = p.global_position + p.facing * 40.0
		if not Game.world.is_walkable_px(spawn):
			spawn = p.global_position
	var stats := SkillDB.golem_stats(id, lvl, p)
	stats["level"] = lvl
	p.golem = Game.spawn_creature(stats, 0, spawn, p)
	Game.fx(spawn, "ring", stats["color"], 40.0, 0.5)
	return true


static func _teeth(p, lvl: int, pos: Vector2) -> bool:
	var n := SkillDB.teeth_count(lvl)
	var dmg := SkillDB.teeth_dmg(lvl, p)
	var d := _dir(p, pos)
	var spread: float = min(0.09 * (n - 1), 1.4)
	for i in n:
		var a = 0.0 if n == 1 else lerp(-spread / 2.0, spread / 2.0, float(i) / (n - 1))
		Game.spawn_projectile({"pos": p.global_position, "vel": d.rotated(a) * 480.0, "team": 0, "owner": p,
			"dmg": dmg, "dtype": "magic", "range": 420.0, "style": "teeth", "radius": 5.0,
			"color": Color(0.96, 0.95, 0.88)})
	return true


static func _enemies_near(pos: Vector2, r: float) -> Array:
	var out := []
	for u in Game.units_in_radius(pos, r):
		if u.team != 0:
			out.append(u)
	return out


static func _corpse_explosion(p, lvl: int, pos: Vector2) -> bool:
	var c = Game.find_corpse(pos, 110.0)
	if c == null:
		Game.message("There is no corpse there")
		return false
	var r := SkillDB.ce_radius(lvl)
	for u in _enemies_near(c.global_position, r):
		var total: float = c.max_hp * randf_range(0.6, 1.0)
		u.take_damage(total * 0.5, "fire", p)
		if is_instance_valid(u) and not u.dead:
			u.take_damage(total * 0.5, "physical", p)
	Game.fx(c.global_position, "burst", Color(1.0, 0.5, 0.15), r, 0.45)
	Game.fx(c.global_position, "ring", Color(1.0, 0.8, 0.3), r, 0.45)
	c.consume()
	return true


static func _poison_explosion(p, lvl: int, pos: Vector2) -> bool:
	var c = Game.find_corpse(pos, 110.0)
	if c == null:
		Game.message("There is no corpse there")
		return false
	var r := SkillDB.poison_explosion_radius(lvl)
	for u in _enemies_near(c.global_position, r):
		u.apply_poison(SkillDB.poison_explosion_poison(lvl, p), 2.0, p)
	Game.fx(c.global_position, "cloud", Color(0.4, 1.0, 0.3), r, 0.9)
	c.consume()
	return true


static func _bone_wall(p, lvl: int, pos: Vector2) -> bool:
	var w = Game.world
	var d := _dir(p, pos)
	var perp := Vector2(-d.y, d.x)
	var n := SkillDB.bone_wall_len(lvl)
	var cells := []
	for i in range(-n / 2, n / 2 + 1):
		var c: Vector2i = w.cell_of(pos + perp * i * w.TILE)
		if not cells.has(c) and w.cell_of(p.global_position) != c:
			cells.append(c)
	return w.add_bones(cells, 24.0) > 0


static func _bone_prison(p, pos: Vector2, hover) -> bool:
	var t = hover if hover != null else Game.nearest_hostile(pos, 0, 120.0)
	if t == null:
		Game.message("No target")
		return false
	var w = Game.world
	var tc: Vector2i = w.cell_of(t.global_position)
	var cells := []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var c: Vector2i = tc + Vector2i(x, y)
			if c != tc and c != w.cell_of(p.global_position):
				cells.append(c)
	return w.add_bones(cells, 24.0) > 0
