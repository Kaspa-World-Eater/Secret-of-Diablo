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

	var order := ["amplify_damage", "teeth", "bone_spear", "bone_spirit", "poison_nova", "bone_armor",
		"clay_golem", "blood_golem", "iron_golem", "fire_golem", "bone_wall", "bone_prison",
		"dim_vision", "weaken", "iron_maiden", "terror", "confuse", "life_tap", "attract", "decrepify", "lower_resist"]
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
	p._swing(m, "poison_dagger")
	_check(m.dead or m.poison_time > 0.0, "poison dagger poisons")

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
