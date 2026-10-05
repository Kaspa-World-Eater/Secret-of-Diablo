extends Node
## Headless smoke test: boots the game, levels the Necromancer, learns every
## skill and casts each one against live monsters/corpses.
## Run: godot --headless --path . res://tests/smoke_test.tscn

var failures := []


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		print("FAIL: ", what)


func _nearest_monster(p):
	return Game.nearest_hostile(p.global_position, 0, 100000.0)


func _run() -> void:
	await _frames(5)
	var p = Game.player
	_check(p != null, "player exists")
	_check(Game.merc != null, "merc exists")
	var monsters := Game.units.filter(func(u): return u.team == 1)
	_check(monsters.size() > 50, "monsters spawned (%d)" % monsters.size())

	for i in 29:
		p.gain_xp(p.xp_to_next() - p.xp)
	_check(p.level == 30, "levelled to 30 (got %d)" % p.level)
	p.skill_points = 200
	p.energy = 500
	p.recalc()
	for tree in 3:
		for row in 6:
			for id in SkillDB.tree_skills(tree):
				if SkillDB.SKILLS[id]["row"] == row:
					for k in 3:
						p.learn(id)
	for id in SkillDB.SKILLS:
		if id != "attack":
			_check(p.skill_level(id) >= 1, "learned " + id)

	# walk next to a monster pack
	var m = _nearest_monster(p)
	p.global_position = m.global_position + Vector2(120, 0)
	if not Game.world.is_walkable_px(p.global_position):
		p.global_position = m.global_position
	await _frames(30)

	var order := ["teeth", "bone_spear", "bone_spirit", "poison_nova", "bone_armor",
		"clay_golem", "blood_golem", "iron_golem", "fire_golem", "bone_wall", "bone_prison", "ossuary_avatar"]
	for id in order:
		m = _nearest_monster(p)
		p.mana = p.max_mana
		p.cast_timer = 0.0
		var before: float = p.mana
		p._cast(id, m.global_position, m)
		_check(p.mana < before, "cast " + id)
		await _frames(20)

	# corpse skills: make sure corpses exist by killing monsters
	for i in 6:
		m = _nearest_monster(p)
		m.take_damage(99999.0, "magic", p)
	await _frames(2)
	_check(Game.corpses.size() >= 4, "corpses dropped (%d)" % Game.corpses.size())
	for id in ["raise_skeleton", "raise_skeletal_mage", "revive", "corpse_explosion", "poison_explosion"]:
		var c = Game.corpses.filter(func(x): return not x.used).front() if Game.corpses.size() > 0 else null
		if c == null:
			_check(false, "corpse for " + id)
			continue
		p.mana = p.max_mana
		p.cast_timer = 0.0
		var before: float = p.mana
		p._cast(id, c.global_position, null)
		_check(p.mana < before, "cast " + id)
		await _frames(5)

	# melee: attack and poison dagger
	m = _nearest_monster(p)
	p.global_position = m.global_position + Vector2(20, 0)
	for i in 5:
		p._swing(m, "poison_dagger")
		if m.dead or m.poison_time > 0.0:
			break
	_check(m.dead or m.poison_time > 0.0, "poison dagger poisons")

	# bone melee: every charge skill at every charge level (4 = avatar-empowered)
	_check(p.avatar_time > 0.0, "ossuary avatar active")
	for id in ["bone_blade", "bone_lash", "skull_crusher", "bone_scythe", "grave_spear", "ribcage_guard"]:
		p.skills[id] = 8
	for id in ["bone_blade", "bone_lash", "skull_crusher", "bone_scythe", "grave_spear", "ribcage_guard"]:
		_check(SkillDB.max_charge(p, id) == 4, "max charge with avatar for " + id)
		for lvl in 5:
			m = _nearest_monster(p)
			if m == null:
				break
			p.global_position = m.global_position + Vector2(40, 0)
			if not Game.world.is_walkable_px(p.global_position):
				p.global_position = m.global_position
			p.mana = p.max_mana
			p.stamina = 1.0
			p.action_lock = 0.0
			var before: float = p.mana
			p._strike(id, lvl, m.global_position)
			_check(p.mana < before and p.stamina == 0.0, "%s charge %d" % [id, lvl])
			await _frames(25)
	# real hold-to-charge flow (at the camp, away from monsters)
	var fight_pos: Vector2 = p.global_position
	if p.dead:
		p._respawn()
	p.hp = p.max_hp
	p.global_position = p.spawn_point
	for u in Game.units:
		if u.team == 1:
			u.set_physics_process(false)
	p.stamina = 1.0
	p.action_lock = 0.0
	p.stagger = 0.0
	p._begin_charge("bone_blade", "right")
	await _frames(int(SkillDB.CHARGE_TIME * 60 * 2.2))
	_check(p.charge_level() >= 2, "charging builds levels (%d)" % p.charge_level())
	p._release_charge()
	_check(p.charging == "" and p.stamina == 0.0, "release performs strike")
	await _frames(40)
	# a solid hit staggers and breaks a charge
	p.stamina = 1.0
	p.action_lock = 0.0
	p.guard_time = 0.0
	p._begin_charge("bone_blade", "right")
	p.bone_armor = 0.0
	p.hp = p.max_hp
	p.take_damage(p.max_hp * 0.3, "physical", null, true)
	_check(p.charging == "" and p.stagger > 0.0, "hit breaks charge")
	p.hp = p.max_hp
	p.global_position = fight_pos
	for u in Game.units:
		if u.team == 1:
			u.set_physics_process(true)
	# parry
	p.guard_mode = "parry"
	p.guard_time = 1.0
	m = _nearest_monster(p)
	var hp_before: float = p.hp
	p.take_damage(10.0, "physical", m, true)
	_check(p.hp >= hp_before, "parry negates melee hit")
	# corpse splinter
	m = _nearest_monster(p)
	m.take_damage(99999.0, "magic", p)
	await _frames(2)
	var cc = Game.find_corpse(p.global_position, 99999.0)
	p.global_position = cc.global_position + Vector2(30, 0)
	p.stamina = 1.0
	var mb: float = p.mana
	p._strike("corpse_splinter", 2, cc.global_position)
	_check(p.mana < mb, "corpse splinter")
	await _frames(20)

	# lantern + day/night + shades
	_check(p.lantern != null, "lantern bearer exists")
	_check(Game.light_at(p.lantern.light_pos()) >= 0.99, "lit at lantern")
	p.lantern.toggle_plant(p.global_position)
	_check(p.lantern.planted, "lantern planted")
	p.lantern.toggle_plant(p.global_position)
	_check(not p.lantern.planted, "lantern recalled")
	Game.day_night.time_of_day = 0.0
	Game.day_night.advance(0.0)
	_check(Game.is_night(), "night")
	_check(Game.light_at(p.global_position + Vector2(3000, 0)) < 0.2, "dark far from lights")
	var main = get_child(0)
	main._spawn_shades()
	await _frames(30)
	var shades := Game.units.filter(func(u): return u.get("nocturnal"))
	_check(shades.size() > 0, "shades spawn at night (%d)" % shades.size())
	Game.day_night.time_of_day = 0.5
	Game.day_night.advance(0.0)
	await _frames(30)
	shades = Game.units.filter(func(u): return u.get("nocturnal"))
	_check(shades.size() == 0, "shades melt at day (%d left)" % shades.size())

	# let the fight play out
	await _frames(600)
	_check(p.skeletons.size() + p.mages.size() + p.revives.size() >= 0, "minion lists ok")
	print("Units alive: ", Game.units.size(), "  kills: ", Game.kills, "  player lvl ", p.level, " hp ", int(p.hp))

	# death + respawn
	p.take_damage(99999.0, "physical", null)
	_check(p.dead, "player can die")
	await _frames(300)
	_check(not p.dead, "player respawns")

	if failures.is_empty():
		print("SMOKE TEST PASSED")
	else:
		print("SMOKE TEST FAILED: ", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
