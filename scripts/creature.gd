class_name Creature
extends Unit
## AI-controlled unit: monsters, the Necromancer's minions and the mercenary.

var kind := ""
var role := "monster"  # monster, skeleton, mage, golem, revive, merc
var leader = null
var target = null
var attack_range := 8.0
var attack_cd := 1.0
var attack_timer := 0.0
var dmg_min := 1.0
var dmg_max := 2.0
var dmg_type := "physical"
var ranged := false
var proj_speed := 300.0
var proj_style := "arrow"
var aggro_range := 280.0
var xp_value := 0.0
var lifetime := -1.0
var champion := false
var revived := false
var leech := 0.0
var slow_on_hit := 0.0
var poison_on_hit := 0.0
var aura_dps := 0.0
var aura_radius := 0.0

var _think := 0.0
var _repath := 0.0
var _aura_tick := 0.0
var _wander := 0.0
var _wander_to := Vector2.ZERO
var home := Vector2.ZERO
var follow_offset := Vector2.ZERO


func setup(s: Dictionary, p_team: int, p_leader) -> void:
	team = p_team
	leader = p_leader
	display_name = s.get("name", "Creature")
	kind = s.get("kind", "")
	role = s.get("role", "monster")
	level = s.get("level", 1)
	shape = s.get("shape", "humanoid")
	weapon = s.get("weapon", "")
	color = s.get("color", Color.WHITE)
	color2 = s.get("color2", color)
	color3 = s.get("color3", Color(0, 0, 0, 0))
	max_hp = float(s.get("hp", 10.0))
	hp = max_hp
	dmg_min = float(s.get("dmg_min", 1.0))
	dmg_max = float(s.get("dmg_max", 2.0))
	dmg_type = s.get("dmg_type", "physical")
	move_speed = float(s.get("speed", 90.0))
	attack_range = float(s.get("range", 8.0))
	attack_cd = float(s.get("cd", 1.0))
	radius = float(s.get("radius", 10.0))
	ranged = s.get("ranged", false)
	proj_speed = float(s.get("proj_speed", 300.0))
	proj_style = s.get("proj_style", "arrow")
	aggro_range = float(s.get("aggro", 280.0))
	xp_value = float(s.get("xp", 0.0))
	champion = s.get("champion", false)
	revived = s.get("revived", false)
	leech = float(s.get("leech", 0.0))
	slow_on_hit = float(s.get("slow_on_hit", 0.0))
	poison_on_hit = float(s.get("poison_on_hit", 0.0))
	aura_dps = float(s.get("aura_dps", 0.0))
	aura_radius = float(s.get("aura_radius", 0.0))
	thorns = float(s.get("thorns", 0.0))
	head_y = float(s.get("head_y", -36.0))
	sprite_key = s.get("sprite", kind)
	for k in s.get("res", {}):
		resist[k] = float(s["res"][k])
	if champion:
		base_modulate = Color(0.75, 0.85, 1.25)
	if revived:
		base_modulate = Color(0.55, 0.6, 0.95)
	home = position
	follow_offset = Vector2.from_angle(randf() * TAU) * randf_range(35.0, 75.0)
	attack_timer = randf() * 0.5


func kind_is_fire() -> bool:
	return kind == "fire_golem"


func _physics_process(delta: float) -> void:
	if dead:
		return
	var p = Game.player
	if role == "monster" and target == null and p != null \
			and global_position.distance_squared_to(p.global_position) > 1500.0 * 1500.0:
		return  # asleep far from the player
	tick_status(delta)
	if dead:
		return
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			die(null)
			return
	attack_timer -= delta
	_think -= delta
	_repath -= delta
	moving = false
	if _think <= 0.0:
		_think = randf_range(0.2, 0.35)
		_choose_target()
	if aura_dps > 0.0:
		_aura_tick -= delta
		if _aura_tick <= 0.0:
			_aura_tick = 0.5
			for u in Game.units_in_radius(global_position, aura_radius):
				if u.team != team:
					u.take_damage(aura_dps * 0.5, "fire", self, false, true)

	if curse_id == "terror" and p != null:
		var away: Vector2 = (global_position - p.global_position).normalized()
		move_towards(global_position + away * 40.0, delta)
	elif target != null and is_instance_valid(target) and not target.dead:
		var tpos: Vector2 = target.global_position
		var d := global_position.distance_to(tpos)
		var reach: float = attack_range + radius + target.radius
		if d <= reach and (not ranged or Game.world.line_clear(global_position, tpos)):
			facing = (tpos - global_position).normalized()
			if attack_timer <= 0.0:
				_attack()
		else:
			_move_to(tpos, delta)
	elif leader != null and is_instance_valid(leader) and not leader.dead:
		var goal: Vector2 = leader.global_position + follow_offset
		var dl := global_position.distance_to(leader.global_position)
		if dl > 800.0:
			var w = Game.world
			global_position = goal if w.is_walkable_px(goal) else leader.global_position
		elif global_position.distance_to(goal) > 30.0 and (dl > 60.0 or global_position.distance_to(goal) > 70.0):
			_move_to(goal, delta)
	else:
		_idle_wander(delta)
	_separate(delta)


func _idle_wander(delta: float) -> void:
	_wander -= delta
	if _wander <= 0.0:
		_wander = randf_range(2.0, 5.0)
		_wander_to = home + Vector2(randf_range(-80, 80), randf_range(-80, 80))
	if global_position.distance_to(_wander_to) > 4.0 and Game.world.line_clear(global_position, _wander_to):
		var saved := move_speed
		move_speed *= 0.4
		move_towards(_wander_to, delta)
		move_speed = saved


func _move_to(goal: Vector2, delta: float) -> void:
	var w = Game.world
	if w.line_clear(global_position, goal):
		path = PackedVector2Array()
		move_towards(goal, delta)
		return
	if _repath <= 0.0 or path_index >= path.size():
		_repath = randf_range(0.5, 0.8)
		if global_position.distance_to(goal) < 900.0:
			set_path(w.find_path(global_position, goal))
		else:
			path = PackedVector2Array()
	if path_index < path.size():
		follow_path(delta)
	else:
		move_towards(goal, delta)


func _separate(delta: float) -> void:
	var push := Vector2.ZERO
	for u in Game.units:
		if u == self or u.dead:
			continue
		var d: Vector2 = global_position - u.global_position
		var min_d: float = (radius + u.radius) * 0.8
		var l2 := d.length_squared()
		if l2 < min_d * min_d:
			if l2 < 0.01:
				d = Vector2.from_angle(randf() * TAU)
				l2 = 1.0
			var l := sqrt(l2)
			push += d / l * (min_d - l)
	if push != Vector2.ZERO:
		try_move(push * min(1.0, 8.0 * delta))


func _choose_target() -> void:
	if curse_id == "confuse":
		var best = null
		var best_d := 350.0
		for u in Game.units:
			if u == self or u.dead:
				continue
			var d: float = u.global_position.distance_to(global_position)
			if d < best_d:
				best = u
				best_d = d
		target = best
		return
	if role == "monster" and not revived:
		for u in Game.units:
			if u != self and not u.dead and u.team == team and u.curse_id == "attract" \
					and u.global_position.distance_to(global_position) < 450.0:
				target = u
				return
		var rng := aggro_range * (0.12 if curse_id == "dim_vision" else 1.0)
		if target != null and is_instance_valid(target) and not target.dead and target.team != team \
				and target.global_position.distance_to(global_position) < rng * 1.6:
			return
		target = Game.nearest_hostile(global_position, team, rng)
		return
	# allies: stay near the leader, fight what threatens them
	var anchor := global_position
	if leader != null and is_instance_valid(leader) and not leader.dead:
		anchor = leader.global_position
		if global_position.distance_to(anchor) > 520.0:
			target = null
			return
	if target != null and is_instance_valid(target) and not target.dead and target.team != team \
			and target.global_position.distance_to(anchor) < 420.0:
		return
	target = null
	var best_d := INF
	for u in Game.units:
		if u.dead or u.team == team:
			continue
		if u.global_position.distance_to(anchor) > 320.0:
			continue
		var d: float = u.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			target = u


func _attack() -> void:
	attack_timer = attack_cd
	attack_anim = 0.3
	var dmg := randf_range(dmg_min, dmg_max) * damage_mult_out()
	if ranged:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		var pcol := color2
		if proj_style == "arrow":
			pcol = Color(0.85, 0.75, 0.55)
		Game.spawn_projectile({
			"pos": global_position, "vel": dir * proj_speed, "team": -1 if curse_id == "confuse" else team,
			"owner": self, "only_target": target, "dmg": Vector2(dmg, dmg), "dtype": dmg_type,
			"range": attack_range + 120.0, "style": proj_style, "radius": 5.0, "color": pcol,
			"poison": poison_on_hit, "slow": slow_on_hit,
		})
		return
	var dealt: float = target.take_damage(dmg, dmg_type, self, true)
	if slow_on_hit > 0.0:
		target.apply_slow(slow_on_hit, 2.0)
	if poison_on_hit > 0.0:
		target.apply_poison(poison_on_hit, 2.0, self)
	if leech > 0.0 and dealt > 0.0:
		heal(dealt * leech)
		if leader != null and is_instance_valid(leader):
			leader.heal(dealt * leech * 0.5)
	if curse_id == "iron_maiden" and dealt > 0.0:
		take_damage(dealt * SkillDB.iron_maiden_mult(curse_level), "physical", null)


func _on_death(_killer) -> void:
	if role == "monster" and not revived:
		Game.on_monster_killed(self)
	elif role == "merc":
		Game.on_merc_died()
	elif role in ["skeleton", "mage"]:
		Game.fx(global_position + Vector2(0, -10), "burst", Color(0.9, 0.88, 0.8), 18.0, 0.35)


func _draw_overlays() -> void:
	if champion:
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 24, Color(0.4, 0.6, 1.0, 0.7), 2.0)
	if aura_dps > 0.0:
		var a := 0.15 + 0.05 * sin(anim_time * 5.0)
		draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 48, Color(1, 0.5, 0.1, a * 2.0), 2.0)
	super._draw_overlays()
