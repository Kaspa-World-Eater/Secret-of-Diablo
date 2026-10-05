class_name Player
extends Unit
## The Necromancer. Diablo 2 controls: left-click to move/attack,
## right-click to cast the right skill, F1-F8 skill hotkeys.

var strength := 15
var dexterity := 25
var vitality := 15
var energy := 25
var stat_points := 0
var skill_points := 1
var skills := {"raise_skeleton": 1}
var xp := 0
var mana := 25.0
var max_mana := 25.0
var left_skill := "attack"
var right_skill := "raise_skeleton"
var hotkeys := {0: "raise_skeleton"}
var gold := 0
var hp_potions := 3
var mp_potions := 3

var cast_timer := 0.0
var swing_timer := 0.0
var attack_target = null
var attack_skill := "attack"
var left_held := false
var right_held := false
var _hold := 0.0
var _reveal := 0.0
var respawn_timer := 0.0
var spawn_point := Vector2.ZERO

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
	var m := 1.0 + strength * 0.01
	return Vector2(2, 4) * m


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
		if right_skill == "attack":
			right_skill = id
	return true


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			left_held = mb.pressed
			if mb.pressed:
				_left_click()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			right_held = mb.pressed
			if mb.pressed:
				_use_skill(right_skill)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		for i in 8:
			if event.is_action("hotkey_%d" % (i + 1)) and hotkeys.has(i):
				right_skill = hotkeys[i]
				get_viewport().set_input_as_handled()
				return
		if event.is_action("potion_1") or event.is_action("potion_2"):
			drink("hp")
		elif event.is_action("potion_3") or event.is_action("potion_4"):
			drink("mp")
		elif event.is_action("debug_level"):
			gain_xp(xp_to_next() - xp)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_held = false


func _left_click() -> void:
	var mp := get_global_mouse_position()
	var hover = Game.unit_at(mp, team)
	if hover != null or Input.is_key_pressed(KEY_SHIFT):
		_use_skill(left_skill)
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


func _use_skill(id: String) -> void:
	var mp := get_global_mouse_position()
	var hover = Game.unit_at(mp, team)
	if SkillDB.is_melee(id):
		if hover != null:
			attack_target = hover
			attack_skill = id
			path = PackedVector2Array()
		elif Input.is_key_pressed(KEY_SHIFT) and swing_timer <= 0.0:
			facing = (mp - global_position).normalized()
			_swing(null, id)
		return
	_cast(id, mp, hover)


func _cast(id: String, mp: Vector2, hover) -> void:
	if cast_timer > 0.0:
		return
	var lvl := skill_level(id)
	if lvl <= 0:
		return
	var cost := SkillDB.mana_cost(id, lvl)
	if mana < cost:
		Game.message("Not enough mana")
		return
	if mp != global_position:
		facing = (mp - global_position).normalized()
	if Skills.cast(self, id, lvl, mp, hover):
		mana -= cost
		cast_timer = 0.5
		attack_anim = 0.3
		path = PackedVector2Array()
		attack_target = null


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
	var d := wand_damage()
	t.take_damage(randf_range(d.x, d.y) * damage_mult_out(), "physical", self, true)
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
	moving = false

	if left_held and (attack_target == null or not is_instance_valid(attack_target)):
		_hold -= delta
		if _hold <= 0.0:
			_hold = 0.15
			var mp := get_global_mouse_position()
			if Input.is_key_pressed(KEY_SHIFT) or (left_skill != "attack" and Game.unit_at(mp, team) != null):
				_use_skill(left_skill)
			elif mp.distance_to(global_position) > 8.0:
				_walk_to(mp)
	if right_held and cast_timer <= 0.0 and not SkillDB.is_melee(right_skill):
		_use_skill(right_skill)

	if cast_timer > 0.2:
		return
	if attack_target != null and is_instance_valid(attack_target) and not attack_target.dead:
		var tpos: Vector2 = attack_target.global_position
		if global_position.distance_to(tpos) <= radius + attack_target.radius + 14.0:
			facing = (tpos - global_position).normalized()
			if swing_timer <= 0.0:
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
	var lost := int(gold * 0.1)
	gold -= lost
	Game.message("You have died. Lost %d gold. Returning to camp..." % lost)
	queue_redraw()


func _respawn() -> void:
	dead = false
	hp = max_hp
	mana = max_mana
	curse_id = ""
	poison_time = 0.0
	slow_time = 0.0
	global_position = spawn_point
	for list in [skeletons, mages, revives]:
		for m in list:
			if is_instance_valid(m) and not m.dead:
				m.global_position = spawn_point + m.follow_offset


func _draw() -> void:
	if dead:
		_ellipse(Vector2(0, -4), 14, 6, Color(0.4, 0.05, 0.05, 0.8))
		_ellipse(Vector2(0, -6), 11, 5, color)
		return
	super._draw()
