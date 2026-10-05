class_name SkillBook
extends RefCounted
## A hero's skills: points bought (hard), effective levels (+items), the left and right slots, hotkeys, and the class's
## casting code. Each order extends this in skills/<cls>.gd and implements cast() for its skill ids (data/skills.json).
## Rules (checklist 0 and 9): no cooldowns; three trees; rows open at 1/6/12/18/24/30; max 20 hard points;
## every level past the first counts 60% (SKILL_GROWTH); costs rise 5% a level.

var hero: Hero
var cls := ""
var hard := {}             # skill id -> points bought
var left := "attack"
var right := "attack"
var keys := {}             # "q".."f" -> skill id
var data := {}             # id -> row from skills.json
var busy := false
var cast_anim := "cast"     # the pose the hero strikes for the skill just used (an order may pick its own)
var cast_len := -1.0        # and how long it holds (-1: the usual 0.55 s over cast speed)
var _virt := {}             # perk id -> [its skill id, the perk's row]: a perk counts as a skill of its own
# tests (user args): --learn, --autocast, the trace, and what each skill dealt (core/main.gd's arena prints it)
var trace := false
var dmg_log := {}
var auto_on := false
var auto_ids: Array = []
var demo_at = null          # where a test aims instead of the mouse

static func for_class(h: Hero, c: String) -> SkillBook:
	var path := "res://skills/%s.gd" % c
	var b: SkillBook = load(path).new() if ResourceLoader.exists(path) else SkillBook.new()
	b.hero = h
	b.cls = c
	b._load()
	return b

func _load() -> void:
	for s in Data.table("skills").get("skills", []):
		if s.get("class", "") == cls:
			data[s["id"]] = s
	var cd: Dictionary = Data.table("classes").get("classes", {}).get(cls, {})
	keys = cd.get("default_keys", {}).duplicate()
	var kit: Dictionary = cd.get("starting_kit", {})
	left = kit.get("left_skill", "attack")
	right = kit.get("right_skill", "attack")
	for id in data:
		for p in data[id].get("perks", []):
			_virt[p["id"]] = [id, p]
	if not Bus.monster_killed.is_connected(_on_kill):
		Bus.monster_killed.connect(_on_kill)
	_read_args()

## a creature died anywhere (Bus.monster_killed); an order answers it by overriding this
func _on_kill(_m) -> void:
	pass

## test args shared by every order: --learn=all[:L] or --learn=id,id[:L] (hard points, default 10), --autocast[=id,id],
## --right=id / --left=id (bind a skill to a mouse button)
func _read_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		var k: String = kv[0]
		var v: String = kv[1] if kv.size() > 1 else ""
		match k:
			"learn":
				var L := 10
				var spec := v
				if ":" in v:
					spec = v.split(":")[0]
					L = int(v.split(":")[1])
				var ids: Array = data.keys() if spec == "all" or spec == "" else Array(spec.split(","))
				for id in ids:
					if data.has(id):
						hard[id] = clampi(L, 1, 20)
			"right":                       # bind a skill to a mouse button at the start (tests, the playtest launchers)
				right = v
			"left":
				left = v
			"autocast":
				auto_on = true
				if v != "":
					auto_ids = Array(v.split(","))
			_:
				_arg(k, v)

## an order's own test args
func _arg(_k: String, _v: String) -> void:
	pass

func name_of(id: String) -> String:
	if id == "attack":
		return "Attack"
	return data.get(id, {}).get("name", id)

## the effective level: hard points plus item bonuses (all skills, the tree's skills)
func lvl(id: String) -> int:
	var h: int = hard.get(id, 0)
	if h <= 0:
		return 0
	var s: Dictionary = data.get(id, {})
	var bonus: int = int(hero.st.item("skall")) + int(hero.st.item("skt%d" % int(s.get("tab", 0)))) + (hero.st.arc.skill_bonus() if hero.st.arc else 0)
	return h + bonus

## a skill's level for its numbers: a perk is a virtual skill at its skill's level once it is on (its skill level
## reached, and its attribute when it asks one); 0 when off
func K(id: String) -> int:
	if _virt.has(id):
		var vv: Array = _virt[id]
		var p: Dictionary = vv[1]
		var L := lvl(vv[0])
		if L < int(p.get("skill_level", 99)):
			return 0
		var rs = p.get("requires_stat")
		if rs is Dictionary and _stat(rs.get("stat", "")) < float(rs.get("value", 0)):
			return 0
		return L
	if not data.has(id):
		return 0
	return lvl(id)

## the SKILL_GROWTH curve on K: level 1 counts fully, every level after it 60%
func L1(id: String) -> float:
	return 1.0 + (maxi(1, K(id)) - 1) * 0.6

## D2 synergies: each hard point in a feeding skill adds its table percent (halved, as the web build does)
func syn(id: String) -> float:
	var b := 0.0
	for y in data.get(id, {}).get("synergies", []):
		b += float(y.get("table_pc", 0)) * int(hard.get(y.get("from", ""), 0))
	return 1.0 + b / 200.0

func _stat(s: String) -> float:
	match s:
		"spi":
			return hero.st.e_ess()
		"vit":
			return hero.st.e_vit()
		"con":
			return hero.st.e_con()
	return 0.0

# ------------------------------------------------------------------ helpers every order uses
func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## where the pilgrim aims: the mouse's tile, or a test's point
func aim_point() -> Vector2:
	if demo_at != null:
		return demo_at
	return hero.mouse_tile()

## a point no farther than maxd from the pilgrim
func clamp_cast(a: Vector2, maxd: float) -> Vector2:
	var d := a - hero.tp
	return hero.tp + d.normalized() * maxd if d.length() > maxd else a

func say(t: String, secs: float = 1.0) -> void:
	Bus.say.emit(t, secs)

## the living creatures (not dead, not under the ground)
func mons() -> Array:
	var out: Array = []
	if hero == null:
		return out
	for m in hero.get_tree().get_nodes_in_group("monsters"):
		if not m.dead and not m.buried:
			out.append(m)
	return out

## the nearest creature within R of p that passes filt
func near(p: Vector2, R: float, filt: Callable = Callable()) -> Monster:
	var best: Monster = null
	var bd := R
	for m in mons():
		if filt.is_valid() and not filt.call(m):
			continue
		var d: float = m.tp.distance_to(p)
		if d < bd:
			bd = d
			best = m
	return best

## every creature whose body is within R of c
func foes(c: Vector2, R: float) -> Array:
	var out: Array = []
	for m in mons():
		if m.tp.distance_to(c) < R + m.radius:
			out.append(m)
	return out

func wake(m) -> void:
	m.awake = true
	if m.brain and m.brain.state == "sleep":
		m.brain.wake(m)

## a creature loses the pilgrim: back to sleep, its attack turn given up
func _lose(m) -> void:
	if m.brain and m.brain.state != "sleep":
		m.brain._release_token(m)
		m.brain.state = "sleep"
		m.brain.wake_delay = -1.0

func can_learn(id: String) -> bool:
	var s: Dictionary = data.get(id, {})
	if s.is_empty() or hero.st.skill_points <= 0:
		return false
	if hard.get(id, 0) >= int(s.get("max_hard_level", 20)):
		return false
	if hero.st.level < int(s.get("required_level", 1)):
		return false
	for p in s.get("prerequisites", []):
		if hard.get(p, 0) <= 0:
			return false
	return true

func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	hard[id] = int(hard.get(id, 0)) + 1
	hero.st.skill_points -= 1
	hero.stats_changed.emit()
	return true

## the cost at the current level, in the class's resource (5% more per level past the first)
func cost(id: String) -> float:
	var s: Dictionary = data.get(id, {})
	var c: Dictionary = s.get("cost", {})
	var base := float(c.get("base", 0.0))
	var L := maxi(1, lvl(id))
	return base * (1.0 + 0.05 * (L - 1))

func poise_cost(id: String) -> float:
	return float(data.get(id, {}).get("cost", {}).get("poise", 0.0))

func is_passive(id: String) -> bool:
	return data.get(id, {}).get("kind", "cast") == "passive"

## a sampled tooltip number at the current level: part i, number j of skillInfo (skills.json levels)
func num(id: String, part: int, j: int = 0, fallback: float = 0.0) -> float:
	var L := clampi(lvl(id), 1, 20)
	var lv: Dictionary = data.get(id, {}).get("levels", {}).get(str(L), {})
	var vals: Array = lv.get("values", [])
	if part < vals.size() and j < (vals[part] as Array).size():
		return float(vals[part][j])
	return fallback

## try to use a skill at a tile (and a creature if one was clicked). Class files override _cast().
func use(id: String, at: Vector2, target: Monster) -> bool:
	if id == "attack" or id == "":
		return false
	if lvl(id) <= 0 or is_passive(id):
		return false
	var c := cost(id)
	if hero.st.res < c and cls != "hemomancer":
		Bus.say.emit("Not enough %s." % hero.st.res_name(), 1.0)
		return false
	var pc := poise_cost(id)
	# poise is stamina, never a lockout (zz_bone_melee_shard_costs:30-40): a swing on empty poise still happens
	if not _cast(id, at, target):
		return false
	hero.st.res -= c
	if pc > 0.0:
		hero.spend_poise(pc)
	hero.stats_changed.emit()
	return true

## override: do the skill. Return false if it could not be used here.
func _cast(id: String, at: Vector2, target: Monster) -> bool:
	return false

## override: per-frame upkeep (auras, minions, wisps, toggles)
func tick(dt: float) -> void:
	pass

## override: extra damage absorption (wards, shields); returns the damage left
func absorb(d: float, elem: String) -> float:
	return d

## override: the hero struck with a weapon (hooks for on-hit skills)
func on_weapon_hit(m: Monster, d: float) -> void:
	pass

## override: the hero touched a lantern-stone (refill wisps and shards, wake and mend minions)
func on_lantern() -> void:
	pass

## override: the hero died (every summoned thing is cleared; states reset)
func on_death() -> void:
	pass


## override: a blow is about to land on the hero (before armour): return what is left of it (0 = nothing lands)
func before_hit(d: float, elem: String, from: Vector2, opts: Dictionary) -> float:
	return d

## override: a creature's missile reaches the hero: true if the order caught it (a bell, a bowl)
func catch_missile(mi) -> bool:
	return false

## override: flat weapon damage the order adds to its blows (bare fists that grow with the pilgrim)
func fist_add() -> Vector2:
	return Vector2.ZERO

## override: the lantern's reach (multiplier and yards added)
func light_mod(r: float) -> float:
	return r

## override: a creature cannot see the hero (sleeping creatures stay asleep, awake ones lose him)
func unseen(m) -> bool:
	return false

## override: a card or state that makes the hero's weapon heavier (multiplier)
func melee_k() -> float:
	return 1.0

## override: a card or state that slows or quickens the hero's walk (multiplier)
func move_k() -> float:
	return 1.0

## the order's Arcana held (core/arcana.gd); every order's book can ask
func aU(id: String) -> bool:
	return hero != null and hero.st.arc != null and hero.st.arc.aU(id)

func aR(id: String) -> bool:
	return hero != null and hero.st.arc != null and hero.st.arc.aR(id)

func aM(id: String) -> bool:
	return hero != null and hero.st.arc != null and hero.st.arc.aM(id)
