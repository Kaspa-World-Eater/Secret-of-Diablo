extends "res://skills/skill_book.gd"
## The Ossuarch (class id "ossumancer"), part 1 of 5: his state, his numbers and the helpers every tree uses.
## A warden of the Pale Order who walked out along the Pale: he counts the dead, and the dead stand up to be counted.
## Three trees (tools/skill_trees.py is the source of their data): the Ossuary (his dead), the Carapace (bone spells,
## plate and the Mantle) and the Count (melee strikes and the numerology curses).
## Chain: base -> tree_ossuary -> tree_carapace -> tree_count -> skills/ossumancer.gd.
## Ported from the web build's final behaviour: f_bone.js (BS numbers, the shards, the skeletons, the lance),
## zz_ossu_active_melee.js (Bone Blade is a strike), zz_bone_melee_shard_costs.js (melee costs poise, never Marrow).
##
## The Mantle's shards: he is always pulling bone out of the earth. Shards tear up from the ground near him (from
## behind a creature when one is near, so they cut it on the way in) and fly to him, then hang about him. They are
## his armour (each turns 0.6% of a blow, at most 45%), his dead (each standing skeleton holds 5) and his spells'
## fuel (bone spells cost shards, and weaken as the Mantle thins: power runs from 55% on an empty Mantle to full).
## Marrow is his resource (it works as mana). Melee strikes cost poise.
##
## Test args: --learn=all[:L], --autocast[=id,id], --ossutrace (prints the Mantle and each skill's damage every 5 s).

const FxNode = preload("res://skills/ossumancer/fx.gd")
const Skeleton = preload("res://skills/ossumancer/skeleton.gd")

const BONE := Color8(232, 226, 208)
const BONE_D := Color8(176, 166, 140)
const GRIT := Color8(111, 106, 92)
const SKEL_COST := 5          # shards each standing skeleton holds
const DR_PER := 0.006         # of a blow turned per shard
const DR_CAP := 0.45
## the pose each skill strikes (art/sprites/ossumancer.json has idle, walk, atk, cast, hit, death)
const POSE := {"blade": "atk", "aura": "cast", "spear": "cast"}
## the melee strikes walk you in, then strike (reach added to the weapon's)
const MELEE := {"blade": 0.45}
## the loadouts the dead rise with, in turn (f_bone.js SL: life, damage, reach, time between blows, damage turned)
const LOADS := {
	"shield": {"hp": 1.45, "dmg": 0.7, "reach": 0.85, "cd": 0.8, "dr": 0.25, "taunt": 2.5},
	"greatsword": {"hp": 1.0, "dmg": 1.15, "reach": 0.95, "cd": 1.1, "arc": 1.2},
	"halberd": {"hp": 0.95, "dmg": 1.0, "reach": 1.55, "cd": 1.0, "knock": 0.35},
}
const LOAD_ORDER := ["shield", "greatsword", "halberd", "shield", "greatsword", "halberd", "shield", "greatsword"]

var zone: Zone
var time := 0.0
var fx_air: Node2D
var fx_floor: Node2D
var trace_t := 5.0
var auto_t := 0.0
var auto_i := 0
var src := ""                 # the skill whose blow is landing

# the Mantle
var shards := 0.0             # held about him
var shard_t := 0.0            # progress to the next shard torn up
var pull_hold := 0.0          # > 0 while he holds the Mantle (feet planted, four times the pull)
var motes: Array = []         # shards in flight: {tp, z, rise, spd, t, dmg, hit: {}}
var grit: Array = []          # dust where bone tears out of the ground: {tp, t}
# the dead
var skels: Array = []         # Skeleton nodes
var rise_t := 0.5             # until the next one may claw up
var colossus = null           # the Ossuary Colossus (skills/ossumancer/colossus.gd), or null
var host := {}                # the Bone Host on him: {n, pool}
# spells in flight
var spear_hits: Array = []   # {at (tile), dir (screen), t}: where a Bone Spear pierced something, for its burst (fx.gd)
var spear_casts: Array = []  # {at (tile), t}: a spear just thrown, for the flash at the hand
var spears: Array = []        # {tp, v, t, dmg, hit: {}, splint, main, small}
var words: Array = []         # small words over the world: {tp, s, t, col}
var cages: Array = []         # Charnel Cages: {tp, R, t, max, dps, tick, drain}
var blade_fx: Array = []      # the Bone Blade's strokes for the eye: {kind, tp, dir, reach|len, t, tier}
var spikes_fx: Array = []     # spurs bursting from a wound: {tp, a, len, t}
var rains: Array = []         # Bone Rain: {tp, R, t, dmg, spawn, drops: [{tp, z}]}
var siph_fx: Array = []       # Marrow Siphon's cone and the marrow drawn home: {tp, dir, R, t} / {from, t}
var plates := 0.0             # Bone Armor still on him
var plates_max := 0.0
var lords: Array = []         # Pale Lords: {node, tp}
# an echo (Pale Lord) casts the same spell from its stone, at a share of the force
var force := 1.0
var origin = null             # where a spell is cast from (null: from him)
## the options an echo's blows carry (its force), so hurt() knows them; {} for his own

# ================================================================== numbers (f_bone.js BS)
func power() -> float:
	return force * hero.st.skill_mult() * (1.0 + 0.1 * K("marrowm")) * (bone_floor() + (1.0 - bone_floor()) * mantle_frac())
func bone_floor() -> float: return minf(0.95, 0.55 + 0.02 * K("marrowm") + (0.2 if K("marrowfloor") > 0 else 0.0))
func mantle_cap() -> int:
	return int(round((20 + 2 * K("aura") + floorf(hero.st.e_ess() / 5.0)) * (1.5 if K("shardskin") > 0 and int(host.get("n", 0)) > 0 else 1.0)))
## the dead that hold shards: standing skeletons (not the Unearthed), those fused into the Colossus and into the Host
func standing() -> int:
	return skels.filter(func(e): return is_instance_valid(e) and e.temp <= 0.0).size() + (colossus.n if colossus != null and is_instance_valid(colossus) else 0) + int(host.get("n", 0))
func mantle_frac() -> float: return clampf(shards / maxf(1.0, mantle_cap()), 0.0, 1.0)
## the shards not held by the standing dead
func free_cap() -> float: return maxf(0.0, mantle_cap() - SKEL_COST * standing())
func pull_rate() -> float:
	return minf(2.4, (0.22 + 0.014 * K("aura") + 0.0016 * hero.st.e_ess()) * (4.0 if pull_hold > 0.0 else 1.0) * (1.15 if K("carapregen") > 0 else 1.0))
func pull_r() -> float: return (3.0 + 0.25 * L1("aura")) * (1.5 if K("deeppull") > 0 else 1.0)
func mote_dmg() -> float: return (2.0 + (L1("aura") - 1.0)) * hero.st.skill_mult()
func turned() -> float: return minf(DR_CAP, shards * DR_PER)
func spurs_dmg() -> float: return (3.0 + 2.0 * L1("aura")) * (0.3 + mantle_frac())
func spear_dmg() -> float: return (9.0 + 4.5 * (L1("spear") - 1.0)) * power() * syn("spear")
func skel_max() -> int: return 2 + int(floorf((L1("raise") - 1.0) / 3.0)) + (1 if K("legion") >= 1 else 0) + (1 if K("legion") >= 10 else 0)
func skel_hp() -> float: return (18.0 + 7.0 * (L1("raise") - 1.0)) * (1.0 + 0.08 * K("legion")) * 0.5
func skel_dmg() -> Vector2:
	var L := L1("raise")
	var k := 1.0 + 0.1 * K("legion")
	return Vector2(1.6 + 0.8 * (L - 1.0), 3.0 + 1.3 * (L - 1.0)) * k
func siphon_dmg() -> float: return (7.0 + 3.5 * (L1("siphon") - 1.0)) * power() * syn("siphon")
func cage_dps() -> float: return (5.0 + 2.5 * (L1("ribcage") - 1.0)) * power() * syn("ribcage")
func cage_life() -> float: return 2.4 + 0.12 * L1("ribcage")
func ossify_r() -> float: return (1.8 + 0.03 * L1("ossify")) * (1.5 if K("ossifywide") > 0 else 1.0)
func spike_dmg() -> float: return (14.0 + 6.0 * (L1("spikes") - 1.0)) * power() * syn("spikes")
func spike_r() -> float: return (1.7 + 0.05 * L1("spikes")) * (1.5 if K("spikewide") > 0 else 1.0)
func storm_max() -> int: return 6 + int(floorf(L1("sstorm") / 2.0))
func storm_dmg() -> float: return (7.0 + 3.2 * (L1("sstorm") - 1.0)) * power() * syn("sstorm")
func rain_dmg() -> float: return (6.0 + 3.0 * (L1("bonerain") - 1.0)) * power() * syn("bonerain")
func armor_max() -> float: return (30.0 + 12.0 * (L1("barmor") - 1.0)) * syn("barmor")
## the share of a blow meant for him that the nearest of his dead takes, while one stands within 4 yd (Bone Armor)
func ward_share() -> float: return minf(0.4, 0.15 + 0.01 * L1("barmor")) if K("barmor") > 0 else 0.0
func echo_k() -> float: return minf(0.85, 0.4 + 0.03 * K("spirit"))
func from_tp() -> Vector2: return origin if origin != null else hero.tp
func echo_opt() -> Dictionary: return {"echo": force} if origin != null else {}
func blade_k() -> float: return 1.3 + 0.1 * maxf(1.0, K("blade"))
func cleave_k() -> float: return 0.5 + 0.02 * K("blade")
func cleave_n() -> int: return 3 if K("bladecleave") > 0 else 1

func weapon_avg() -> float:
	var w: Item = hero.st.inv.weapon() if hero.st.inv else null
	return ((w.dmg.x + w.dmg.y) / 2.0) if w else 2.0

# ================================================================== helpers
func hurt(m, dmg: float, id: String, o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead or m.buried or dmg <= 0.0:
		return 0.0
	if float(m.get_meta("o_oss", -1.0)) > time:   # ossified: +20%
		dmg *= 1.2
	if o.has("echo"):
		# The Unfallen: an echo lands at full force on what his own spell missed
		if K("spiritchain") > 0 and float(m.get_meta("o_struck", -9.0)) < time - 0.6:
			dmg /= maxf(0.01, float(o["echo"]))
	else:
		m.set_meta("o_struck", time)
	var opts := {}
	if o.get("melee", false):
		opts["melee"] = true
	if o.has("poise"):
		opts["poise"] = o["poise"]
	var was := src
	src = id
	var dealt: float = Combat.hit_monster(m, dmg, o.get("elem", "phys"), o.get("from", hero.tp), opts)
	src = was
	if trace:
		dmg_log[id] = float(dmg_log.get(id, 0.0)) + dealt
	return dealt

## pay a spell's shards (bone spells cost them; Lean Marrow takes one off)
func pay_shards(id: String) -> bool:
	var n := shard_cost(id)
	if n <= 0:
		return true
	if shards < n:
		say("Not enough bone shards.", 1.1)
		return false
	shards -= n
	return true

func shard_cost(id: String) -> int:
	var n := int(data.get(id, {}).get("cost", {}).get("shards", 0))
	if n > 0 and K("marrowcost") > 0 and int(data.get(id, {}).get("tab", 0)) == 1:
		n -= 1
	return maxi(0, n)

func say_at(p: Vector2, t: String, col: Color = BONE) -> void:
	words.append({"tp": p, "s": t, "t": 1.0, "col": col})
	if words.size() > 24:
		words.pop_front()

func dust(p: Vector2, n: int = 3) -> void:
	for i in n:
		grit.append({"tp": p + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)), "t": randf_range(0.35, 0.7)})
	if grit.size() > 200:
		grit = grit.slice(grit.size() - 200)

## the creature a melee strike aims at: near the cursor, and near him
func melee_target(a: Vector2, reach: float) -> Monster:
	var best: Monster = null
	var bd := 1e9
	for m in mons():
		var dp: float = m.tp.distance_to(hero.tp)
		if dp > reach + m.radius + 0.1:
			continue
		var d: float = m.tp.distance_to(a) + dp * 0.3
		if d < bd:
			bd = d
			best = m
	return best

var auto_hold := ""            # --autocast: a held skill held for a while
var auto_hold_t := 0.0

func held(id: String) -> bool:
	if hero == null or hero.dead:
		return false
	if auto_hold == id and auto_hold_t > 0.0:
		return true
	if hero.skills.right == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return true
	return hero.skills.left == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _los_point(a: Vector2) -> Vector2:
	var d := a.distance_to(hero.tp)
	if d < 0.3:
		return a
	var n := int(ceil(d / 0.2))
	var last := hero.tp
	for i in range(1, n + 1):
		var p := hero.tp.lerp(a, float(i) / n)
		if zone.blocks_sight(p):
			return last
		last = p
	return a
