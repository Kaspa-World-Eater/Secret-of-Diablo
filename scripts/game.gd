extends Node
## Global game state, unit registry and spawn helpers.

const CreatureScript := preload("res://scripts/creature.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const FloatTextScript := preload("res://scripts/float_text.gd")
const CorpseScript := preload("res://scripts/corpse.gd")
const PickupScript := preload("res://scripts/pickup.gd")

var world = null
var player = null
var hud = null
var units_layer: Node2D
var ground_layer: Node2D
var proj_layer: Node2D
var fx_layer: Node2D

var day_night = null
var light_sources: Array = []  # nodes with light_radius_px() and light_pos()
var units: Array = []
var corpses: Array = []
var merc = null
var merc_respawn := -1.0
var kills := 0


func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	var keys := {
		"skill_tree": [KEY_T], "stats": [KEY_A, KEY_C], "automap": [KEY_TAB], "help": [KEY_H],
		"potion_1": [KEY_1], "potion_2": [KEY_2], "potion_3": [KEY_3], "potion_4": [KEY_4],
		"debug_level": [KEY_EQUAL], "debug_time": [KEY_N], "close_panels": [KEY_ESCAPE], "lantern": [KEY_L],
	}
	var fkeys := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8]
	for i in fkeys.size():
		keys["hotkey_%d" % (i + 1)] = [fkeys[i]]
	for action in keys:
		_add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)
	# controller
	var pad := {
		"pad_left": JOY_BUTTON_A, "pad_right": JOY_BUTTON_X, "pad_cycle": JOY_BUTTON_B, "lantern": JOY_BUTTON_Y,
		"pad_potion_hp": JOY_BUTTON_LEFT_SHOULDER, "pad_potion_mp": JOY_BUTTON_RIGHT_SHOULDER,
		"skill_tree": JOY_BUTTON_START, "stats": JOY_BUTTON_BACK, "automap": JOY_BUTTON_DPAD_UP,
	}
	for action in pad:
		_add_action(action)
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)
	var axes := {
		"pad_move_left": [JOY_AXIS_LEFT_X, -1.0], "pad_move_right": [JOY_AXIS_LEFT_X, 1.0],
		"pad_move_up": [JOY_AXIS_LEFT_Y, -1.0], "pad_move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"pad_aim_left": [JOY_AXIS_RIGHT_X, -1.0], "pad_aim_right": [JOY_AXIS_RIGHT_X, 1.0],
		"pad_aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "pad_aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	for action in axes:
		_add_action(action)
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


func _add_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _process(delta: float) -> void:
	if merc_respawn > 0.0 and player:
		merc_respawn -= delta
		if merc_respawn <= 0.0:
			spawn_merc(player.global_position + Vector2(30, 30))
			message("Your mercenary has returned.")


# ---------------------------------------------------------------- registry

func register(u) -> void:
	units.append(u)


func unregister(u) -> void:
	units.erase(u)


func prune(arr: Array) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if not is_instance_valid(arr[i]) or arr[i].dead:
			arr.remove_at(i)


func unit_at(pos: Vector2, team: int):
	## Hostile (to `team`) unit under the given world position, or null.
	var best = null
	var best_d := INF
	for u in units:
		if u.dead or u.team == team or u.invisible:
			continue
		var c: Vector2 = u.global_position + Vector2(0, -12)
		var d := pos.distance_to(c)
		if d < u.radius + 14.0 and d < best_d:
			best = u
			best_d = d
	return best


func units_in_radius(pos: Vector2, r: float) -> Array:
	var out := []
	for u in units:
		if not u.dead and u.global_position.distance_to(pos) <= r + u.radius:
			out.append(u)
	return out


func nearest_hostile(pos: Vector2, team: int, max_d: float):
	var best = null
	var best_d := max_d
	for u in units:
		if u.dead or u.team == team or u.invisible:
			continue
		var d: float = u.global_position.distance_to(pos)
		if d < best_d:
			best = u
			best_d = d
	return best


func find_corpse(pos: Vector2, r: float):
	var best = null
	var best_d := r
	for c in corpses:
		if c.used:
			continue
		var d: float = c.global_position.distance_to(pos)
		if d < best_d:
			best = c
			best_d = d
	return best


# ---------------------------------------------------------------- light

func daylight() -> float:
	return day_night.daylight if day_night else 1.0


func light_visual() -> float:
	## Visual strength of light sources: invisible at noon, full at night.
	return clamp(1.15 - daylight(), 0.0, 1.0)


func is_night() -> bool:
	return day_night != null and day_night.is_night()


func light_at(pos: Vector2) -> float:
	## 0 = pitch dark, 1 = fully lit (daylight or a nearby light source).
	var l := daylight()
	if l >= 1.0:
		return 1.0
	for s in light_sources:
		l = max(l, Lighting.falloff(pos.distance_to(s.light_pos()), s.light_radius_px()))
	return l


# ---------------------------------------------------------------- spawning

func spawn_creature(stats: Dictionary, team: int, pos: Vector2, leader):
	var c = CreatureScript.new()
	c.position = pos
	c.setup(stats, team, leader)
	units_layer.add_child(c)
	return c


func spawn_merc(pos: Vector2) -> void:
	var lvl: int = player.level if player else 1
	merc = spawn_creature(CreatureDB.merc_stats(lvl), 0, pos, player)
	merc_respawn = -1.0


func refresh_merc_level() -> void:
	if merc and is_instance_valid(merc) and not merc.dead:
		var frac: float = merc.hp / merc.max_hp
		merc.setup(CreatureDB.merc_stats(player.level), 0, player)
		merc.hp = merc.max_hp * frac


func spawn_projectile(p: Dictionary) -> void:
	var pr = ProjectileScript.new()
	pr.position = p["pos"]
	pr.vel = p["vel"]
	pr.speed = pr.vel.length()
	pr.team = p.get("team", 0)
	pr.owner_unit = p.get("owner", null)
	var dmg: Vector2 = p.get("dmg", Vector2.ZERO)
	pr.dmg_min = dmg.x
	pr.dmg_max = dmg.y
	pr.dtype = p.get("dtype", "magic")
	pr.max_dist = p.get("range", 500.0)
	pr.style = p.get("style", "bolt")
	pr.radius = p.get("radius", 6.0)
	pr.color = p.get("color", Color.WHITE)
	pr.pierce = p.get("pierce", false)
	pr.homing = p.get("homing", false)
	pr.target = p.get("target", null)
	pr.poison_total = p.get("poison", 0.0)
	pr.slow = p.get("slow", 0.0)
	proj_layer.add_child(pr)


func fx(pos: Vector2, kind: String, color: Color, radius: float, duration: float, dir := Vector2.RIGHT, arc_deg := 0.0) -> void:
	var f = FxScript.new()
	f.position = pos
	f.dir = dir
	f.arc = deg_to_rad(arc_deg)
	f.kind = kind
	f.color = color
	f.radius = radius
	f.duration = duration
	fx_layer.add_child(f)


func float_text(pos: Vector2, text: String, color: Color, size: int = 13) -> void:
	var f = FloatTextScript.new()
	f.position = pos + Vector2(randf_range(-6, 6), -30)
	f.text = text
	f.color = color
	f.size = size
	fx_layer.add_child(f)


func message(text: String) -> void:
	if hud:
		hud.show_message(text)


# ---------------------------------------------------------------- events

func on_monster_killed(m) -> void:
	kills += 1
	var c = CorpseScript.new()
	c.position = m.global_position
	c.kind = m.kind
	c.level = m.level
	c.max_hp = m.max_hp
	c.color = m.color
	c.size = m.radius
	ground_layer.add_child(c)
	if player:
		player.gain_xp(int(round(m.xp_value)))
	_drop_loot(m.global_position, m.level, m.champion)


func on_merc_died() -> void:
	merc = null
	merc_respawn = 25.0
	message("Your mercenary has fallen. They will return in 25 seconds.")


func _drop_loot(pos: Vector2, lvl: int, champion: bool) -> void:
	var rolls := 3 if champion else 1
	for i in rolls:
		var r := randf() / (1.5 if is_night() else 1.0)  # better drops at night
		var kind := ""
		var amount := 0
		if r < 0.12:
			kind = "hp"
		elif r < 0.22:
			kind = "mp"
		elif r < 0.5:
			kind = "gold"
			amount = lvl * randi_range(2, 9)
		if kind != "":
			var pk = PickupScript.new()
			pk.position = pos + Vector2(randf_range(-14, 14), randf_range(-10, 10))
			pk.kind = kind
			pk.amount = amount
			ground_layer.add_child(pk)
