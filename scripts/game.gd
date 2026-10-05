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
		"debug_level": [KEY_EQUAL], "close_panels": [KEY_ESCAPE],
	}
	var fkeys := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8]
	for i in fkeys.size():
		keys["hotkey_%d" % (i + 1)] = [fkeys[i]]
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)


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
		if u.dead or u.team == team:
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
		if u.dead or u.team == team:
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
	pr.only_target = p.get("only_target", null)
	pr.poison_total = p.get("poison", 0.0)
	pr.slow = p.get("slow", 0.0)
	proj_layer.add_child(pr)


func fx(pos: Vector2, kind: String, color: Color, radius: float, duration: float) -> void:
	var f = FxScript.new()
	f.position = pos
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
		var r := randf()
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
