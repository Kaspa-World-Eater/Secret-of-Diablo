class_name Player
extends Unit
## The Necromancer.
## Mouse (Diablo 2): left-click move/attack, right-click right skill, F1-F8 hotkeys.
## Controller: left stick move, right stick aim, A left skill, X right skill,
## B cycle right skill, Y plant/recall lantern, LB/RB potions.
## Bone melee skills are held to charge and released to strike (Secret of Mana).

const PAD_DEADZONE := 0.25

var strength := 15
var dexterity := 25
var vitality := 15
var energy := 25
var stat_points := 0
var skill_points := 1
var skills := {"raise_skeleton": 1, "bone_blade": 1}
var xp := 0
var mana := 25.0
var max_mana := 25.0
var left_skill := "attack"
var right_skill := "bone_blade"
var hotkeys := {0: "bone_blade", 1: "raise_skeleton"}
var gold := 0
var hp_potions := 3
var mp_potions := 3
var light_radius := 210.0

# SoM stamina gauge: 0..1, refills after each melee swing
var stamina := 1.0
var stamina_recover := 0.8
var swing_power := 1.0
# charging
var charging := ""
var charge_time := 0.0
var charge_ok := false
var charge_button := ""
var stagger := 0.0
var action_lock := 0.0
var melee_weapon := ""
var melee_weapon_time := 0.0
var _strikes: Array = []  # [delay, Callable]
var _dash := {}
# ribcage guard
var guard_mode := ""
var guard_time := 0.0
var guard_power := 1.0
# ossuary avatar
var avatar_time := 0.0

var cast_timer := 0.0
var swing_timer := 0.0
var attack_target = null
var attack_skill := "attack"
var left_held := false
var right_held := false
var using_pad := false
var _hold := 0.0
var _reveal := 0.0
var respawn_timer := 0.0
var spawn_point := Vector2.ZERO
var lantern = null

var golem = null
var skeletons: Array = []
var mages: Array = []
var revives: Array = []


func _ready() -> void:
	team = 0
	display_name = "Necromancer"
	radius = 11.0
	move_speed = 140.0
	shape = "necro"
	color = Color(0.2, 0.19, 0.25)
	color2 = Color(0.92, 0.9, 0.87)
	color3 = Color(0.96, 0.96, 0.98)
	sprite_key = "necromancer"
	head_y = -40.0
	super._ready()
	recalc()
	hp = max_hp
	mana = max_mana


# ---------------------------------------------------------------- stats

func skill_level(id: String) -> int:
	if id == "attack":
		return 1
	return skills.get(id, 0)


func xp_to_next() -> int:
	return int(100.0 * pow(level, 1.7))


func recalc() -> void:
	max_hp = 45.0 + (vitality - 15) * 2.0 + (level - 1) * 1.5
	max_mana = 25.0 + (energy - 25) * 2.0 + (level - 1) * 2.0
	hp = min(hp, max_hp)
	mana = min(mana, max_mana)


func wand_damage() -> Vector2:
	return Vector2(2, 4) * (1.0 + strength * 0.01)


func gain_xp(amount: int) -> void:
	if dead or level >= 99:
		return
	xp += amount
	while xp >= xp_to_next() and level < 99:
		xp -= xp_to_next()
		level += 1
		stat_points += 5
		skill_points += 1
		recalc()
		hp = max_hp
		mana = max_mana
		Game.float_text(global_position + Vector2(0, -30), "LEVEL UP!", Color(1, 0.85, 0.3), 18)
		Game.fx(global_position, "ring", Color(1, 0.85, 0.3), 60.0, 0.8)
		Game.message("Level %d! You have new stat and skill points." % level)
		Game.refresh_merc_level()


func spend_stat(stat: String) -> void:
	if stat_points <= 0:
		return
	stat_points -= 1
	match stat:
		"str": strength += 1
		"dex": dexterity += 1
		"vit":
			vitality += 1
			hp += 2.0
		"ene":
			energy += 1
			mana += 2.0
	recalc()


func learn(id: String) -> bool:
	var why := SkillDB.can_learn(self, id)
	if why != "":
		Game.message(why)
		return false
	var first := skill_level(id) == 0
	skills[id] = skill_level(id) + 1
	skill_points -= 1
	if first and not SkillDB.SKILLS[id]["passive"]:
		for i in 8:
			if not hotkeys.has(i):
				hotkeys[i] = id
				break
	return true


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "str": strength, "dex": dexterity, "vit": vitality, "ene": energy,
		"stat_points": stat_points, "skill_points": skill_points, "skills": skills.duplicate(),
		"hotkeys": hotkeys.duplicate(), "left": left_skill, "right": right_skill, "gold": gold,
		"hp_potions": hp_potions, "mp_potions": mp_potions}


func from_dict(d: Dictionary) -> void:
	level = d["level"]
	xp = d["xp"]
	strength = d["str"]
	dexterity = d["dex"]
	vitality = d["vit"]
	energy = d["ene"]
	stat_points = d["stat_points"]
	skill_points = d["skill_points"]
	skills = d["skills"]
	hotkeys = d["hotkeys"]
	left_skill = d["left"]
	right_skill = d["right"]
	gold = d["gold"]
	hp_potions = d["hp_potions"]
	mp_potions = d["mp_potions"]
	recalc()
	hp = max_hp
	mana = max_mana


# ---------------------------------------------------------------- aiming

func aim_point() -> Vector2:
	if not using_pad:
		return get_global_mouse_position()
	var rs := Input.get_vector("pad_aim_left", "pad_aim_right", "pad_aim_up", "pad_aim_down", PAD_DEADZONE)
	if rs != Vector2.ZERO:
		return global_position + rs * 150.0
	var t = pad_target()
	if t != null:
		return t.global_position
	return global_position + facing * 80.0


func pad_target():
	## Auto-target for controller: nearest visible enemy roughly in front.
	var best = null
	var best_score := INF
	for u in Game.units:
		if u.dead or u.team == team or u.invisible:
			continue
		var rel: Vector2 = u.global_position - global_position
		var d := rel.length()
		if d > 320.0:
			continue
		var ang: float = abs(facing.angle_to(rel))
		if ang > 1.2:
			continue
		var score := d * (1.0 + ang)
		if score < best_score:
			best_score = score
			best = u
	return best


func hover_target():
	if using_pad:
		return pad_target()
	return Game.unit_at(get_global_mouse_position(), team)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if dead or Game.editing:
		return
	if event is InputEventMouseButton:
		using_pad = false
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			left_held = mb.pressed
			if mb.pressed:
				_left_click()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			right_held = mb.pressed
			if mb.pressed:
				_press_skill(right_skill, "right")
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		using_pad = false
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton or abs(event.axis_value) > PAD_DEADZONE:
			using_pad = true
	if event.is_action_pressed("pad_left"):
		left_held = true
		_press_skill(left_skill, "left")
	elif event.is_action_released("pad_left"):
		left_held = false
	elif event.is_action_pressed("pad_right"):
		right_held = true
		_press_skill(right_skill, "right")
	elif event.is_action_released("pad_right"):
		right_held = false
	elif event.is_action_pressed("pad_cycle"):
		_cycle_hotkey()
	elif event.is_action_pressed("lantern") and lantern != null:
		lantern.toggle_plant(aim_point())
	elif event.is_action_pressed("potion_1") or event.is_action_pressed("potion_2") or event.is_action_pressed("pad_potion_hp"):
		drink("hp")
	elif event.is_action_pressed("potion_3") or event.is_action_pressed("potion_4") or event.is_action_pressed("pad_potion_mp"):
		drink("mp")
	elif event.is_action_pressed("debug_level"):
		gain_xp(xp_to_next() - xp)
	elif event.is_action_pressed("debug_time"):
		Game.day_night.advance(0.125)
		Game.message(Game.day_night.clock_text())
	else:
		for i in 8:
			if event.is_action_pressed("hotkey_%d" % (i + 1)) and hotkeys.has(i):
				right_skill = hotkeys[i]
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# releases are caught here so a release over the HUD still ends a charge
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_held = false
			if charge_button == "left":
				_release_charge()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_held = false
			if charge_button == "right":
				_release_charge()
	elif event.is_action_released("pad_left") and charge_button == "left":
		_release_charge()
	elif event.is_action_released("pad_right") and charge_button == "right":
		_release_charge()


func _cycle_hotkey() -> void:
	var keys := hotkeys.keys()
	keys.sort()
	if keys.is_empty():
		return
	var idx := 0
	for i in keys.size():
		if hotkeys[keys[i]] == right_skill:
			idx = (i + 1) % keys.size()
	right_skill = hotkeys[keys[idx]]
	Game.message(SkillDB.SKILLS[right_skill]["name"])


func _left_click() -> void:
	var mp := get_global_mouse_position()
	var hover = Game.unit_at(mp, team)
	if hover != null or Input.is_key_pressed(KEY_SHIFT):
		_press_skill(left_skill, "left")
	else:
		attack_target = null
		_walk_to(mp)


func _walk_to(p: Vector2) -> void:
	var w = Game.world
	if w.line_clear(global_position, p) and w.is_walkable_px(p):
		set_path(PackedVector2Array([global_position, p]))
		return
	var np: PackedVector2Array = w.find_path(global_position, p)
	if np.size() > 0:
		if w.is_walkable_px(p) and w.line_clear(np[np.size() - 1], p):
			np.append(p)
		set_path(np)
	else:
		set_path(PackedVector2Array([global_position, p]))


func _press_skill(id: String, button: String) -> void:
	if stagger > 0.0 or action_lock > 0.0:
		return
	var aim := aim_point()
	var hover = hover_target()
	if SkillDB.is_charge(id):
		var reach: float = SkillDB.BONE_WEAPONS[id]["reach"]
		if hover != null and not using_pad and global_position.distance_to(hover.global_position) > reach + hover.radius + 30.0 and id != "ribcage_guard":
			attack_target = hover  # walk into range, then strike
			attack_skill = id
			path = PackedVector2Array()
			return
		_begin_charge(id, button)
		return
	if SkillDB.is_melee(id):
		if hover != null:
			attack_target = hover
			attack_skill = id
			path = PackedVector2Array()
		elif (Input.is_key_pressed(KEY_SHIFT) or using_pad) and swing_timer <= 0.0:
			facing = (aim - global_position).normalized()
			_swing(null, id)
		return
	_cast(id, aim, hover)


func _cast(id: String, aim: Vector2, hover) -> void:
	if cast_timer > 0.0:
		return
	var lvl := skill_level(id)
	if lvl <= 0:
		return
	var cost := SkillDB.mana_cost(id, lvl)
	if mana < cost:
		Game.message("Not enough mana")
		return
	if aim != global_position:
		facing = (aim - global_position).normalized()
	var ok := false
	if id == "ossuary_avatar":
		avatar_time = SkillDB.avatar_duration(lvl)
		Game.fx(global_position + Vector2(0, -16), "burst", Color(0.95, 0.92, 0.8), 40.0, 0.5)
		ok = true
	else:
		ok = Skills.cast(self, id, lvl, aim, hover)
	if ok:
		mana -= cost
		cast_timer = 0.5
		attack_anim = 0.3
		path = PackedVector2Array()
		attack_target = null


# ---------------------------------------------------------------- melee (SoM)

func _begin_charge(id: String, button: String) -> void:
	if skill_level(id) <= 0:
		return
	charging = id
	charge_button = button
	charge_time = 0.0
	charge_ok = stamina >= 1.0
	path = PackedVector2Array()
	attack_target = null


func charge_level() -> int:
	if charging == "" or not charge_ok:
		return 0
	return min(SkillDB.max_charge(self, charging), int(charge_time / SkillDB.CHARGE_TIME))


func _release_charge() -> void:
	if charging == "":
		return
	var id := charging
	var lvl := charge_level()
	charging = ""
	charge_button = ""
	_strike(id, lvl, aim_point())


func _strike(id: String, charge: int, aim: Vector2) -> void:
	var cost := SkillDB.mana_cost(id, skill_level(id)) * (1.0 + 0.5 * charge)
	if mana < cost:
		Game.message("Not enough mana")
		return
	swing_power = max(0.25, stamina)
	if BoneMelee.perform(self, id, charge, aim):
		mana -= cost
		stamina = 0.0
		stamina_recover = SkillDB.stamina_recover(self, id)
		attack_anim = 0.3
		action_lock = 0.2 + 0.08 * charge
		melee_weapon = SkillDB.BONE_WEAPONS[id]["weapon"]
		melee_weapon_time = 1.5


func queue_strike(delay: float, f: Callable) -> void:
	_strikes.append([delay, f])
	action_lock = max(action_lock, delay + 0.15)


func start_dash(dir: Vector2, dist: float, duration: float, on_end: Callable, hit_skill: String, hit_mult: float) -> void:
	_dash = {"dir": dir, "speed": dist / duration, "time": duration, "end": on_end, "skill": hit_skill, "mult": hit_mult, "hit": {}}
	action_lock = max(action_lock, duration + 0.1)


func _process_melee(delta: float) -> void:
	if stamina < 1.0:
		stamina = min(1.0, stamina + delta / stamina_recover)
	melee_weapon_time -= delta
	if charging != "":
		if not charge_ok and stamina >= 1.0 and charge_time == 0.0:
			charge_ok = true
		if charge_ok:
			charge_time += delta
		var aim := aim_point()
		if aim.distance_to(global_position) > 2.0:
			facing = (aim - global_position).normalized()
	for i in range(_strikes.size() - 1, -1, -1):
		_strikes[i][0] -= delta
		if _strikes[i][0] <= 0.0:
			var f: Callable = _strikes[i][1]
			_strikes.remove_at(i)
			if not dead:
				f.call()
	if not _dash.is_empty():
		var step: Vector2 = _dash["dir"] * _dash["speed"] * delta
		try_move(step)
		moving = true
		if _dash["skill"] != "":
			for u in BoneMelee._enemies():
				var id: int = u.get_instance_id()
				if not _dash["hit"].has(id) and u.global_position.distance_to(global_position) < 28.0 + u.radius:
					_dash["hit"][id] = true
					BoneMelee.hit(self, _dash["skill"], u, _dash["mult"], {"knock": 30.0, "stun": 0.3})
		_dash["time"] -= delta
		if _dash["time"] <= 0.0:
			var f: Callable = _dash["end"]
			_dash = {}
			if f.is_valid():
				f.call()


func take_damage(amount: float, dtype: String, source = null, melee := false, silent := false) -> float:
	if dead:
		return 0.0
	var src_ok: bool = source != null and is_instance_valid(source) and not source.dead
	if guard_time > 0.0 and melee:
		match guard_mode:
			"block":
				amount *= 0.4 if guard_power <= 1.0 else 0.2
			"parry":
				amount = 0.0
				guard_time = 0.0
				if src_ok:
					swing_power = 1.0
					BoneMelee.hit(self, "ribcage_guard", source, 2.5 * guard_power, {"knock": 40.0, "stun": 0.6})
				Game.float_text(global_position + Vector2(0, -24), "Parry!", Color(1, 0.95, 0.6), 13)
			"reflect":
				amount *= 0.2
				if src_ok:
					var d: Vector2 = (source.global_position - global_position).normalized()
					var w := SkillDB.bone_weapon_dmg(self, "ribcage_guard") * guard_power
					for i in 5:
						Game.spawn_projectile({"pos": global_position, "vel": d.rotated((i - 2) * 0.25) * 420.0, "team": 0,
							"owner": self, "dmg": w, "dtype": "magic", "range": 260.0, "style": "teeth", "radius": 5.0,
							"color": BoneMelee.BONE})
	if avatar_time > 0.0:
		amount *= 0.75
	var dealt := super.take_damage(amount, dtype, source, melee, silent)
	# hit recovery: a solid hit staggers you and breaks a charge
	if dealt > max_hp * 0.08 and not dead:
		stagger = 0.25
		if charging != "":
			charging = ""
			charge_button = ""
	return dealt


# ---------------------------------------------------------------- D2 wand / dagger

func _swing(t, id: String) -> void:
	swing_timer = 0.6
	attack_anim = 0.3
	var lvl := skill_level(id)
	if id != "attack":
		var cost := SkillDB.mana_cost(id, lvl)
		if mana < cost:
			Game.message("Not enough mana")
			id = "attack"
		else:
			mana -= cost
	if t == null:
		return
	if randf() > SkillDB.hit_chance(self, t):
		Game.float_text(t.global_position + Vector2(0, -20), "Miss", Color(0.75, 0.75, 0.75), 11)
	else:
		var d := wand_damage()
		t.take_damage(randf_range(d.x, d.y), "physical", self, true)
		if id == "poison_dagger" and is_instance_valid(t) and not t.dead:
			t.apply_poison(SkillDB.poison_dagger_poison(lvl, self), 2.0, self)
			Game.fx(t.global_position + Vector2(0, -12), "burst", Color(0.4, 1, 0.3), 14.0, 0.3)
	if t.dead or not (left_held or right_held):
		attack_target = null


func drink(kind: String) -> void:
	if dead:
		return
	if kind == "hp" and hp_potions > 0 and hp < max_hp:
		hp_potions -= 1
		heal(max_hp * 0.4)
		Game.fx(global_position, "burst", Color(1, 0.2, 0.2), 22.0, 0.4)
	elif kind == "mp" and mp_potions > 0 and mana < max_mana:
		mp_potions -= 1
		mana = min(max_mana, mana + max_mana * 0.5)
		Game.fx(global_position, "burst", Color(0.3, 0.4, 1), 22.0, 0.4)


func pick_up(item) -> bool:
	match item.kind:
		"gold":
			gold += item.amount
			Game.float_text(global_position, "+%d gold" % item.amount, Color(1, 0.85, 0.3), 11)
			return true
		"hp":
			if hp_potions >= 8:
				return false
			hp_potions += 1
			return true
		"mp":
			if mp_potions >= 8:
				return false
			mp_potions += 1
			return true
	return false


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_reveal -= delta
	if _reveal <= 0.0:
		_reveal = 0.2
		Game.world.reveal(global_position, 14)
	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return
	tick_status(delta)
	if dead:
		return
	mana = min(max_mana, mana + max_mana / 45.0 * delta)
	cast_timer -= delta
	swing_timer -= delta
	stagger -= delta
	action_lock -= delta
	guard_time -= delta
	if avatar_time > 0.0:
		avatar_time -= delta
	dmg_reduction = 0.0
	moving = false
	_process_melee(delta)

	if stagger > 0.0 or charging != "" or not _dash.is_empty() or action_lock > 0.0:
		return

	# controller movement
	var ls := Input.get_vector("pad_move_left", "pad_move_right", "pad_move_up", "pad_move_down", PAD_DEADZONE)
	if ls != Vector2.ZERO and not (Game.hud != null and Game.hud.pad_menu_open()):
		using_pad = true
		path = PackedVector2Array()
		attack_target = null
		facing = ls.normalized()
		moving = true
		try_move(ls * move_speed * speed_mult() * delta)
		return

	if left_held and not using_pad and (attack_target == null or not is_instance_valid(attack_target)):
		_hold -= delta
		if _hold <= 0.0:
			_hold = 0.15
			var mp := get_global_mouse_position()
			if Input.is_key_pressed(KEY_SHIFT) or (left_skill != "attack" and Game.unit_at(mp, team) != null):
				if not SkillDB.is_charge(left_skill):
					_press_skill(left_skill, "left")
			elif mp.distance_to(global_position) > 8.0:
				_walk_to(mp)
	if right_held and cast_timer <= 0.0 and not SkillDB.is_melee(right_skill) and not SkillDB.is_charge(right_skill):
		_press_skill(right_skill, "right")

	if cast_timer > 0.2:
		return
	if attack_target != null and is_instance_valid(attack_target) and not attack_target.dead:
		var tpos: Vector2 = attack_target.global_position
		var reach := 14.0
		if SkillDB.is_charge(attack_skill):
			reach = SkillDB.BONE_WEAPONS[attack_skill]["reach"]
		if global_position.distance_to(tpos) <= radius + attack_target.radius + reach:
			facing = (tpos - global_position).normalized()
			if SkillDB.is_charge(attack_skill):
				var id := attack_skill
				attack_target = null
				_strike(id, 0, tpos)
			elif swing_timer <= 0.0:
				_swing(attack_target, attack_skill)
		elif Game.world.line_clear(global_position, tpos):
			move_towards(tpos, delta)
		else:
			if path_index >= path.size():
				set_path(Game.world.find_path(global_position, tpos))
			follow_path(delta)
	else:
		attack_target = null
		if path_index < path.size():
			follow_path(delta)


func die(_killer) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	respawn_timer = 4.0
	path = PackedVector2Array()
	attack_target = null
	left_held = false
	right_held = false
	charging = ""
	_strikes.clear()
	_dash = {}
	var lost := int(gold * 0.1)
	gold -= lost
	Game.message("You have died. Lost %d gold. Returning to camp..." % lost)
	queue_redraw()


func _respawn() -> void:
	dead = false
	hp = max_hp
	mana = max_mana
	stamina = 1.0
	poison_time = 0.0
	slow_time = 0.0
	stun_time = 0.0
	avatar_time = 0.0
	global_position = spawn_point
	for list in [skeletons, mages, revives]:
		for m in list:
			if is_instance_valid(m) and not m.dead:
				m.global_position = spawn_point + m.follow_offset


# ---------------------------------------------------------------- drawing

func draw_figure() -> void:
	var saved := weapon
	weapon = melee_weapon if melee_weapon_time > 0.0 or charging != "" else "wand"
	if charging != "":
		weapon = SkillDB.BONE_WEAPONS[charging]["weapon"]
	if avatar_time > 0.0:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1.25, 1.25))
		_draw_humanoid(Color(0.85, 0.82, 0.72), color2, color3, weapon, true, 1.0, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_draw_humanoid(color, color2, color3, weapon, true, 1.0)
	weapon = saved


func _draw_overlays() -> void:
	super._draw_overlays()
	# SoM stamina gauge under the feet
	var w := 30.0
	var y := 7.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
	var full := stamina >= 1.0
	draw_rect(Rect2(-w / 2, y, w * stamina, 3), Color(1, 0.9, 0.35) if full else Color(0.75, 0.6, 0.3))
	# charge pips
	if charging != "":
		var mx := SkillDB.max_charge(self, charging)
		var cl := charge_level()
		var frac: float = fmod(charge_time, SkillDB.CHARGE_TIME) / SkillDB.CHARGE_TIME if cl < mx else 1.0
		for i in mx:
			var c := Vector2(-((mx - 1) * 9.0) / 2.0 + i * 9.0, y + 10)
			draw_circle(c, 3.6, Color(0, 0, 0, 0.7))
			if i < cl:
				draw_circle(c, 2.8, Color(1, 0.95, 0.5))
			elif i == cl and charge_ok:
				draw_arc(c, 2.8, -PI / 2, -PI / 2 + TAU * frac, 12, Color(1, 0.95, 0.5), 1.5)
		if charge_ok:
			draw_arc(Vector2(0, -16), 18.0 + cl * 3.0, 0, TAU, 32, Color(1, 0.95, 0.6, 0.25 + 0.15 * cl), 2.0)
	if guard_time > 0.0:
		var gc := Color(1, 0.95, 0.6, 0.6) if guard_mode == "parry" else Color(0.95, 0.92, 0.8, 0.5)
		draw_arc(Vector2(0, -14), radius + 9.0, facing.angle() - 1.0, facing.angle() + 1.0, 16, gc, 3.0)


func _draw() -> void:
	if dead:
		_ellipse(Vector2(0, -4), 14, 6, Color(0.4, 0.05, 0.05, 0.8))
		_ellipse(Vector2(0, -6), 11, 5, color)
		return
	super._draw()
