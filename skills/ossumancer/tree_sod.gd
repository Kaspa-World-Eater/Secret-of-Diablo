extends "res://skills/ossumancer/tree_count2.gd"
## The Ossuarch, part 4c (Secret of Diablo): the old Necromancer's spells and summons, folded into the Carapace and the
## Ossuary (data: data/skills_sod.json). Costs are Marrow (and shards for bone spells); his dead and golems are allies
## (entities/ally_sod.gd) whose blows count in his numbers.
##
## Carapace: Teeth, Corpse Explosion, Venom Dagger, Bone Wall, Corpse Bloom (poison), Pall Nova (poison).
## Ossuary: Skeletal Mage, Clay / Blood / Iron / Fire Golem, Golem Mastery, Revive, Summon Resist.

const Ally = preload("res://entities/ally_sod.gd")
const TopDownArt = preload("res://world/topdown.gd")

var sod_mages: Array = []
var sod_golem = null
var sod_revived: Array = []
var walls: Array = []          # Bone Wall: {nodes, posts: [[cell, entry]], t}

# ------------------------------------------------------------------ Carapace
## Teeth: a fan of bone teeth
func cast_teeth(a: Vector2) -> bool:
	var n: int = mini(24, int(L1("teeth")) + 2)
	var dir := (a - from_tp()).normalized() if a.distance_to(from_tp()) > 0.05 else Vector2(1, 0)
	var spread: float = minf(0.09 * (n - 1), 1.3)
	var dmg: float = (3.0 + 2.0 * (L1("teeth") - 1.0)) * power() * syn("teeth")
	for i in n:
		var ang := 0.0 if n == 1 else lerpf(-spread / 2.0, spread / 2.0, float(i) / (n - 1))
		var mi := Missile.fire(zone, from_tp(), from_tp() + dir.rotated(ang) * 8.0, 13.0, dmg, "magic", "hero", "needle")
		mi.col = BONE
		var b = self
		mi.on_hit = func(m, _x): b.hurt(m, dmg, "teeth", {"elem": "magic"})
	Sfx.play("swing", 0.4, 1.6)
	return true

func _corpse_at(a: Vector2, r: float):
	var best = null
	var bd := r
	for c in hero.get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(c) or not c.visible:
			continue
		var d: float = c.tp.distance_to(a)
		if d < bd:
			bd = d
			best = c
	return best

## Corpse Explosion: a corpse bursts for 60-100% of the life it had, fire and bone
func cast_cexplode(a: Vector2) -> bool:
	var c = _corpse_at(a, 2.0)
	if c == null:
		say("No corpse there.", 1.0)
		return false
	var R := 2.2 + 0.25 * L1("cexplode")
	for m in foes(c.tp, R):
		var total: float = float(c.hp_max) * randf_range(0.6, 1.0) * (0.85 + 0.03 * L1("cexplode"))
		hurt(m, total * 0.5, "cexplode", {"elem": "fire"})
		hurt(m, total * 0.5, "cexplode", {})
	spikes_fx.append({"tp": c.tp, "a": 0.0, "len": R, "t": 0.45, "ring": true})
	for i in 10:
		spikes_fx.append({"tp": c.tp, "a": TAU * i / 10.0, "len": R * 0.7, "t": 0.45})
	dust(c.tp, 14)
	Game.shake(3.0)
	Sfx.play("heavy", 0.9, 0.8)
	c.queue_free()
	return true

## Venom Dagger: a stab that poisons (melee: poise)
func cast_vdagger(a: Vector2, target) -> bool:
	begin_swing()
	var reach: float = hero._reach() + 0.4
	var m = target if target != null and is_instance_valid(target) and not target.dead else melee_target(a, reach + 0.3)
	if m != null:
		hurt(m, weapon_avg() * stroke_k(), "vdagger", {"melee": true})
		if is_instance_valid(m) and not m.dead:
			m.add_dot((12.0 + 10.0 * (L1("vdagger") - 1.0)) * power() / 2.0, 2.0, "poison")
		dust(m.tp, 3)
	_after_stroke("atk", 0.32, _dir_to(a), 1 if m else 0, 0)
	return true

## Bone Wall: a line of bone across the way (24 s); bodies can't pass it
func cast_bwall(a: Vector2) -> bool:
	var dir := _dir_to(a)
	var perp := Vector2(-dir.y, dir.x)
	var n := 5 + int(L1("bwall") / 4.0)
	var w := {"nodes": [], "posts": [], "t": 24.0}
	for i in range(-n / 2, n / 2 + 1):
		var p: Vector2 = a + perp * i * 0.8
		if zone.is_solid(p):
			continue
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		var entry := [p, 0.45]
		if not zone.posts.has(c):
			zone.posts[c] = []
		zone.posts[c].append(entry)
		w["posts"].append([c, entry])
		var node = TopDownArt._prop(zone, "stonepile", p, i * 7 + 3, 1.0)
		if node:
			node.modulate = Color(1.25, 1.2, 1.1)
			w["nodes"].append(node)
		dust(p, 2)
	walls.append(w)
	Sfx.play("break", 0.7, 0.9)
	return true

func tick_walls(dt: float) -> void:
	for w in walls:
		w["t"] -= dt
	for w in walls.filter(func(x): return x["t"] <= 0.0):
		for pe in w["posts"]:
			if zone.posts.has(pe[0]):
				zone.posts[pe[0]].erase(pe[1])
		for nd in w["nodes"]:
			if is_instance_valid(nd):
				nd.queue_free()
	walls = walls.filter(func(x): return x["t"] > 0.0)

## Corpse Bloom: a corpse bursts into a poison cloud
func cast_pexplode(a: Vector2) -> bool:
	var c = _corpse_at(a, 2.0)
	if c == null:
		say("No corpse there.", 1.0)
		return false
	var R := 2.4 + 0.12 * L1("pexplode")
	var total := (40.0 + 18.0 * (L1("pexplode") - 1.0)) * power()
	for m in foes(c.tp, R):
		m.add_dot(total / 2.0, 2.0, "poison")
	spikes_fx.append({"tp": c.tp, "a": 0.0, "len": R, "t": 0.6, "ring": true})
	dust(c.tp, 10)
	c.queue_free()
	return true

## Pall Nova: an expanding ring of poison around him
func cast_pnova() -> bool:
	var total := (50.0 + 22.0 * (L1("pnovasod") - 1.0)) * power()
	for i in 28:
		var d := Vector2.from_angle(TAU * i / 28.0)
		var mi := Missile.fire(zone, from_tp(), from_tp() + d * 6.0, 7.0, 0.0, "poison", "hero", "orb")
		mi.col = Color(0.55, 0.75, 0.45)
		mi.pierce = 99
		mi.life = 0.9
		mi.on_hit = func(m, _x): m.add_dot(total / 2.0, 2.0, "poison")
	Sfx.play("swing", 0.5, 0.7)
	return true

# ------------------------------------------------------------------ Ossuary
func summon_res() -> Dictionary:
	var r := 0.0 if K("sresist") <= 0 else minf(75.0, 20.0 + 5.0 * L1("sresist"))
	return {"fire": r, "cold": r, "poison": r, "magic": r * 0.5}

func _ally(c: Dictionary, at: Vector2) -> Node2D:
	var a := Ally.new()
	a.book = self
	c["res"] = summon_res()
	a.setup(hero, c, at if not zone.is_solid(at) else hero.tp)
	zone.sorted.add_child(a)
	dust(a.tp, 8)
	return a

func _alive(arr: Array) -> Array:
	return arr.filter(func(x): return is_instance_valid(x) and not x.gone)

## Skeletal Mage: a dead mage claws up and casts bolts of a random element (costs shards like a skeleton)
func cast_smage(a: Vector2) -> bool:
	sod_mages = _alive(sod_mages)
	var cap := 1 + int(L1("smage") / 4.0)
	if sod_mages.size() >= cap:
		say("No more mages will rise.", 1.0)
		return false
	var el: String = ["fire", "cold", "poison", "magic"][randi() % 4]
	var cols := {"fire": Color(1, 0.55, 0.25), "cold": Color(0.6, 0.8, 1.0), "poison": Color(0.55, 0.85, 0.4), "magic": Color(0.9, 0.85, 1.0)}
	var L := L1("smage")
	var c := {"id": "smage", "sprite": "lpc_skeleton_mage", "hp": (14.0 + 5.0 * (L - 1.0)) * 0.8, "dmg": Vector2(3.0 + 2.0 * (L - 1.0), 6.0 + 3.0 * (L - 1.0)) * power(),
		"reach": 5.5, "cd": 1.3, "speed": 3.0, "elem": el if el != "poison" else "magic", "ranged": 11.0, "bolt": cols[el],
		"poison": (6.0 + 4.0 * L) if el == "poison" else 0.0, "slow": 0.3 if el == "cold" else 0.0}
	var m := _ally(c, clamp_cast(a, 3.0))
	m.slot = sod_mages.size() + 3
	sod_mages.append(m)
	return true

const GOLEMS := {
	"cgolem": {"name": "Clay Golem", "hp": 90.0, "hp_l": 30.0, "dmg": Vector2(3, 7), "dmg_l": 2.5, "tint": Color(0.75, 0.6, 0.45), "slow": 0.3},
	"bgolem": {"name": "Blood Golem", "hp": 160.0, "hp_l": 36.0, "dmg": Vector2(6, 14), "dmg_l": 4.0, "tint": Color(0.75, 0.4, 0.38), "leech": 0.5},
	"igolem": {"name": "Iron Golem", "hp": 240.0, "hp_l": 45.0, "dmg": Vector2(7, 18), "dmg_l": 4.5, "tint": Color(0.7, 0.72, 0.8), "thorns": 1.5, "dr": 0.25},
	"fgolem2": {"name": "Fire Golem", "hp": 300.0, "hp_l": 55.0, "dmg": Vector2(10, 25), "dmg_l": 6.0, "tint": Color(1.0, 0.7, 0.45), "aura": 6.0, "elem": "fire"},
}

## a golem of clay, blood, iron or fire: one at a time
func cast_golem(id: String, a: Vector2) -> bool:
	if sod_golem != null and is_instance_valid(sod_golem) and not sod_golem.gone:
		sod_golem._fall()
	var g: Dictionary = GOLEMS[id]
	var L := L1(id)
	var gm := 1.0 + 0.2 * K("gmastery")
	var c := {"id": id, "sprite": "lpc_knight", "scale": 1.3, "radius": 0.45, "hp": (g["hp"] + g["hp_l"] * (L - 1.0)) * gm,
		"dmg": (g["dmg"] + Vector2(g["dmg_l"], g["dmg_l"] * 1.6) * (L - 1.0)) * power(), "reach": 1.0, "cd": 1.1,
		"speed": 2.8 * (1.0 + 0.06 * K("gmastery")), "tint": g["tint"], "slow": g.get("slow", 0.0), "leech": g.get("leech", 0.0),
		"thorns": g.get("thorns", 0.0) + 0.15 * (L - 1.0) * (1.0 if g.has("thorns") else 0.0), "dr": g.get("dr", 0.0),
		"aura": (g.get("aura", 0.0) + 4.0 * (L - 1.0)) if g.has("aura") else 0.0, "aura_r": 2.0, "elem": g.get("elem", "phys")}
	sod_golem = _ally(c, clamp_cast(a, 3.0))
	sod_golem.slot = 0
	say_at(sod_golem.tp, String(g["name"]).to_lower())
	Game.shake(1.5)
	return true

## Revive: a corpse stands back up to fight for him, twice as hardy, for three minutes
func cast_revive(a: Vector2) -> bool:
	var c = _corpse_at(a, 2.0)
	if c == null:
		say("No corpse there.", 1.0)
		return false
	sod_revived = _alive(sod_revived)
	if sod_revived.size() >= int(L1("revive")):
		say("No more will answer.", 1.0)
		return false
	var dm: Vector2 = c.dmg if "dmg" in c else Vector2(3, 6)
	var cfg := {"id": "revive", "sprite": String(c.kind), "hp": float(c.hp_max) * 2.0, "dmg": dm, "reach": 0.9, "cd": 1.0,
		"speed": 3.0, "life": 180.0, "tint": Color(0.65, 0.72, 1.0), "radius": float(c.radius)}
	var r := _ally(cfg, c.tp)
	r.slot = sod_revived.size() + 6
	sod_revived.append(r)
	c.queue_free()
	return true

func tick_sod(dt: float) -> void:
	tick_walls(dt)

func clear_sod() -> void:
	for x in sod_mages + sod_revived + ([sod_golem] if sod_golem != null else []):
		if is_instance_valid(x):
			x.queue_free()
	sod_mages.clear()
	sod_revived.clear()
	sod_golem = null
	walls.clear()

## the spells and summons above, for _cast
func cast_sod(id: String, a: Vector2, target) -> int:
	match id:
		"teeth": return 1 if cast_teeth(a) else 0
		"cexplode": return 1 if cast_cexplode(a) else 0
		"vdagger": return 1 if cast_vdagger(a, target) else 0
		"bwall": return 1 if cast_bwall(a) else 0
		"pexplode": return 1 if cast_pexplode(a) else 0
		"pnovasod": return 1 if cast_pnova() else 0
		"smage": return 1 if cast_smage(a) else 0
		"cgolem", "bgolem", "igolem", "fgolem2": return 1 if cast_golem(id, a) else 0
		"revive": return 1 if cast_revive(a) else 0
	return -1
