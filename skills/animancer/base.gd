extends "res://skills/skill_book.gd"

## The Hollow Mystic (class id "animancer"): Essence, the choir of wisps, the Iron Golem, mirrors and threads.
## Ported from the web build's final behaviour: c_game.js (the WS table, derive), d_play.js (wisps, golem, pillars,
## lance, orb, storm, leash, totem, mark, rebuke, great wisp, hurtPlayer's ward), o_skills14.js (Falling Mirror, Cull,
## Unravelling, synergies, costs), zy_anim.js (Mirror tree, darting wisps, fissure glass), zz_zz_light79.js (wisps are
## fuel; the choir shapes the spell), zz_zz_mystic90.js (one choir: snag, pass on, needle, split; Binding Thread),
## zz_zz_thread93.js (Soul Leash as a burst of threads, Procession, burrowed things ignored), zz_tune_v58.js /
## zz_tune_batch_c.js (costs, regen, mirrors that break), k_arcana.js (kill hooks), zz_movespd_curve.js (Wraith speed).
##
## ------------------------------------------------------------------ API for the UI helper (panels V and G, HUD)
## Choir panel (V):
##   wbeh: {x: 0..4 (close..roam), y: 0..4 (guard..attack), focus: bool ("Attack my target"), hold: bool ("Hold fire")}
##     - write it directly; the choir reads it every frame.
##   chances() -> {thread, pass, needle, split}: the four chances on each wisp strike (0..1), for the rows
##     "Snag a thread", "Pass on", "Needle", "Split" (show "-" when 0).
##   wisps.size() / eff_cap() / wisp_cap() / reserved(): the choir now, the room it has, its full size, and how many
##     are held by the great wisp, the golem's charge and the lantern ("N total · M held by skills").
##   wisp_range(4.6): how far the choir seeks when y >= 2 ("Seek out enemies up to N yd away").
##   choir_k(): the spell multiplier from the choir (0.65 .. 1.20), for a HUD hint if wanted.
## Golem orders panel (G):
##   gbeh: {x: 0..4 (close..roam), y: 0..4 (guard..attack), charge, toss, focus, hold: bool}
##     - when toggling hold call set_golem_hold(on) so the golem remembers where it stands.
##   gweapon: "sword" | "axe" | "flail" (WEAPON_NAMES has the names; ws_weapon(id) -> {mult, dur, reach, ...}).
##   golem: null or the golem (skills/animancer/golem.gd): hp, max_hp, state ("active"/"dormant"/...), rt, rt_max
##     (dormant: time left of its sleep), charge / ws_charge_max(), ramp (rampage time left), infused.
##   golem_orders() -> {leash, aggro, guard}: "Engages foes within N yd", guard: "Only fights what threatens you".
## Allies: the golem's view is in group "allies" (tp, radius, take_hit(dmg, elem, from), is_down()).
##   nearest_target(zone, from) (static) gives the monster AI the nearest of the hero and the standing allies, and
##   honours Dazzling Challenge (monster metas "mys_taunt_until" (Time.get_ticks_msec()/1000 based) and "mys_taunt_by").
## Hooks used elsewhere: phases(elem) (core/combat.gd: Wraith Form lets physical blows through untouched).
## Test args (OS.get_cmdline_user_args()): --learn=all[:L] or --learn=id,id[:L] (hard points, default 10),
##   --ess=N (the Essence attribute, for perks), --autocast[=id,id] (cast learned skills at the nearest creature in
##   turn, holds held for 1.6 s), --mystrace (print the choir and the damage each skill dealt every 5 s).

const GolemL = preload("res://skills/animancer/golem.gd")
const GolemView = preload("res://skills/animancer/golem_view.gd")
const WispView = preload("res://skills/animancer/wisp_view.gd")
const PropView = preload("res://skills/animancer/prop_view.gd")
const FxNode = preload("res://skills/animancer/fx.gd")

const WISP_NERF := 0.65 * 0.65
const OWN := ["swarm", "storm", "condense", "attack"]         # keep their own wisp costs: no fuel burned
const HOLD := ["lance", "condense", "proc", "overcharge"]
const WEAPON_NAMES := {"sword": "Knight Sword", "axe": "Headsman Axe", "flail": "Morning Star"}
## elements (zz_mech_resists.js SKILL_ELEMENT): mirrors and the golem cut, soul-light is magic, the phantom's burst void
const ELEM := {"pillars": "phys", "fissure": "phys", "cage": "phys", "anvil": "phys", "golem": "phys", "toss": "phys",
	"thorns": "phys", "challenge": "phys", "phantom": "magic", "wraith": "void"}
const CHOIR_REBOUND := true   # see _maybe_mirror(): the choir rebounds off mirrors as the Mirror tree promises

class Wisp:
	extends RefCounted
	var tp := Vector2.ZERO
	var z := 14.0
	var v := Vector2.ZERO
	var ang := 0.0
	var rad := 1.0
	var wt := 0.0
	var state := "drift"
	var hits := 0
	var target = null
	var dir := Vector2.RIGHT
	var over := 0.0
	var hit_t := {}
	var cd := 0.5
	var cull_t := 0.0
	var cull_pool: Array = []
	var p_t := 0.0
	var bounces := 0
	var mult := 1.0
	var mirror = null
	var used := {}
	var split_done := false
	var gone := false
	var scale := 1.0
	var alpha := 1.0
	var node = null
	var size := 0            # the great wisp
	var life := 0.0
	var pulse := 0.8
	var beam := {}           # a lantern wisp's line
	var armor_t := 0.0       # The Revenant: armoured in bone, it cannot perish
	var wtt := 0.0

class Mirror:
	extends RefCounted
	var kind := "pane"       # pane | great | lantern
	var tp := Vector2.ZERO
	var r := 0.3
	var rise := 0.22
	var rise_max := 0.22
	var fall := 0.0
	var fall_max := 0.5
	var life := 10.0
	var max_life := 10.0
	var dmg := 0.0
	var fresh := true
	var cracked := false
	var hall := false
	var hp := 40.0
	var gone := false
	var node = null
	var seed := 0
	var wisps: Array = []    # the lantern's
	var pulse := 0.0
	func standing() -> bool:
		if gone:
			return false
		if kind == "pane":
			return rise <= 0.0
		if kind == "great":
			return fall <= 0.0
		return false

# ------------------------------------------------------------------ orders (the V and G panels)
var wbeh := {"x": 2, "y": 2, "focus": false, "hold": false}
var gbeh := {"x": 2, "y": 2, "charge": true, "toss": true, "focus": false, "hold": false}
var gweapon := "sword"

# ------------------------------------------------------------------ the world
var zone: Zone
var time := 0.0
var wisps: Array = []
var wisp_t := 0.0
var great: Wisp = null
var golem = null
var golem_mem := {}
var mirrors: Array = []
var totems: Array = []
var cages: Array = []
var fissures: Array = []
var cracks: Array = []
var spikes: Array = []
var glass: Array = []
var gshots: Array = []
var rings: Array = []
var fires: Array = []
var souls: Array = []
var sparks: Array = []
var needles: Array = []
var snags: Array = []
var binds: Array = []
var threads: Array = []
var darts: Array = []
var dart_lines: Array = []
var orbs: Array = []
var shards: Array = []
var storms: Array = []
var words: Array = []
var whips: Array = []
var phantoms: Array = []
var totem_beams: Array = []
# the Arcana (v103: core/arcana.gd cards; the effects below)
var splinters: Array = []      # The Anvil: glass on the ground [{tp, t}]
var shell := 0.0               # The Anvil reversed: the golem worn as a shell (its iron left)
var maiden_t := 0.0            # The Maiden's Kiss reversed: the hall closed on you
var storm_t := 0.0             # Storm: the mirrors' splinter cadence
var choir_t := 0.0             # The Choir: the whole choir strikes together every 2 s
var bell_n := 0                # The Bell-Warden: spells cast (every fifth rings)
var bell_lock := 0.0           # The Bell-Warden reversed: no spells until this time
var lantern_blow := 0          # The Lantern-Bearer reversed: every other blow frees a wisp
var drains: Array = []         # The Aether-Sage reversed: Soul Swarm as a draining thread [{m, t, tick}]
var pyre_t := 0.0              # Pyre reversed: the wraith's trail
var crown_q: Array = []        # The Choir Crown: wisps coming back (times)
var silence_zone := ""         # The Last Silence: the place it was spent
var proc := {"on": false, "tp": Vector2.ZERO, "t": 0.0}
var wraith := false
var infusing := false
var inf_t := 0.0
var condensing := false
var cond_t := 0.0
var lance_t := 0.0
var an_hold := 0.0
var rebuke_acc := 0.0
var phantom_t := 0.0
var last_hit = null
var cf := -1.0               # the choir as a fraction of full while a spell is cast (-1: not casting)
var pending_tap := ""
var fx_air: Node2D
var fx_floor: Node2D
var _mons: Array = []
var _mons_t := -1.0
var _was_dead := false
# testing
var hold_force := ""
var auto_stand := false        # the balance arena: stand and cast, never walk in to strike
var auto_i := 0
var auto_t := 1.0
var trace_t := 5.0

# ================================================================== setup
## the Mystic's own test args (the shared ones are read in skill_book.gd)
func _arg(k: String, v: String) -> void:
	match k:
		"ess":
			hero.st.ess = int(v)
			hero.st.res = hero.st.res_max()
		"mystrace":
			trace = true
		"myscheck":
			check_numbers()

## a perk is a virtual skill; the golem's three weapons count at the golem's level
func K(id: String) -> int:
	if id == "sword" or id == "axe" or id == "flail":
		return lvl("golem")
	return super.K(id)


## prints this port's numbers next to the web's sampled tooltip numbers (skills.json levels) at L1, L10, L20, for a
## fresh hero (the export's reference: Essence 25, skill multiplier x1.30). Marks rows that differ by over 6%.
func check_numbers() -> void:
	var keep := hard.duplicate()
	var rows := {
		"pillars": func(): return [ws_pillar_n(), ws_pillar_dmg(), ws_pillar_life()],
		"golem": func(): return [ws_golem()["max"], ws_golem()["dmg"][0], ws_golem()["dmg"][1], ws_aura_dps(), ws_golem()["recharge"]],
		"fissure": func(): return [ws_fissure_dmg(), ws_fissure_len(), ws_crack_life(), ws_fissure_keep()],
		"toss": func(): return [ws_toss_dmg(), ws_toss_hover()],
		"challenge": func(): return [ws_challenge_r(), ws_challenge_cd()],
		"cage": func(): return [ws_cage_n(), ws_cage_dmg(), ws_cage_life()],
		"thorns": func(): return [ws_thorns_pct()],
		"overcharge": func(): return [ws_charge_max(), ws_ramp_life(), ws_ramp_mult(), ws_det_dmg() * ws_det_k()],
		"anvil": func(): return [ws_anvil_dmg(), 16 if K("anvilquake") > 0 else 8, ws_anvil_dmg() * (0.4 if K("anvilquake") > 0 else 0.22), 16 if K("anvilstay") > 0 else 8],
		"forge": func(): return [8 * K("forge"), 4 * K("forge")],
		"wisps": func(): return [wisp_cap(), ws_rev_dmg(), ch_thread() * 100.0],
		"restless": func(): return [ws_hits(), ch_pass() * 100.0],
		"beam": func(): return [ch_needle() * 100.0, needle_dmg(), needle_len()],
		"prism": func(): return [ch_split() * 100.0, spark_n(), spark_dmg()],
		"condense": func(): return [1, ws_cond_rate(), ws_cond_max(), ws_cond_dmg(), 35],
		"proc": func(): return [ws_rev_dmg() * 0.6, proc_r(), float(data["proc"]["cost"]["base"])],
		"totem": func(): return [ws_totem_n(), ws_totem_dps(), ws_totem_life()],
		"choir": func(): return [8 * K("choir"), 4 * K("choir")],
		"animam": func(): return [10 * K("animam"), 8 * K("animam")],
		"swarm": func(): return [ws_soul_dmg(), ws_souls_per_wisp() - 1],
		"ward": func(): return [ws_ward_pct() * 100.0, 1, ws_ward_eff()],
		"lance": func(): return [ws_lance_dps() * 0.42, ws_lance_pierce() + 1, ws_lance_range(), -18],
		"wraith": func(): return [ws_wraith_drain(), ws_wraith_spd()],
		"storm": func(): return [ws_storm_life(), ws_storm_rate()],
		"mark": func(): return [ws_mark_pct() * 100.0, ws_mark_r(), ws_mark_life()],
		"orb": func(): return [ws_orb_dmg(), 8],
		"leash": func(): return [ws_leash_dps(), ws_leash_dur(), 2 if K("twin") > 0 else 1],
		"chain": func(): return [maxi(0, ws_chain_n() - 1) + (2 if K("chainfork") > 0 else 0), ws_chain_dmg(), 5.5],
		"nmastery": func(): return [10 * K("nmastery"), 5 * K("nmastery")],
	}
	for id in rows:
		for L in [1, 10, 20]:
			hard.clear()
			hard[id] = L
			var mine: Array = rows[id].call()
			var web: Array = []
			for part in data[id].get("levels", {}).get(str(L), {}).get("values", []):
				web.append_array(part)
			var bad := false
			for i in mini(mine.size(), web.size()):
				var a := float(mine[i])
				var b := float(web[i])
				if absf(a - b) > maxf(0.6, absf(b) * 0.06):
					bad = true
			print("%s L%d %s port %s web %s" % ["  " if not bad else "!!", L, id, str(mine.map(func(x): return snappedf(float(x), 0.01))), str(web)])
	hard = keep

# ================================================================== levels, perks, synergies

## D2 synergies: only hard points; syn = 1 + sum(table_pc x hard[from]) / 200 (o_skills14.js)
func syn_bonus(id: String) -> float:
	var b := 0.0
	for y in data.get(id, {}).get("synergies", []):
		b += float(y.get("table_pc", 0)) * int(hard.get(y.get("from", ""), 0))
	return b / 200.0

func syn(id: String) -> float:
	return 1.0 + syn_bonus(id)

func dm() -> float:
	return hero.st.skill_mult()

## the choir shapes the spell (v81): counts +1 at a full choir, -1 at a thin one; durations and sizes follow it
func _cnt(v: float) -> int:
	if cf < 0.0:
		return int(round(v))
	return maxi(1, int(round(v)) + (1 if cf >= 0.8 else 0) - (1 if cf < 0.2 else 0))

func _life(v: float) -> float:
	return v if cf < 0.0 else v * (0.75 + 0.4 * cf)

func _size(v: float) -> float:
	return v if cf < 0.0 else v * (0.8 + 0.3 * cf)

## costs: the data's base (already x1.6 and x1.2), +5% a level; Word of Power: Thread spells cost 10% less
## v103 balance (tools/balance: the arena runs, wiki/15): the Mirror tree's and the dear spells' costs come down, the
## weak ones hit harder, Soul Leash a little softer. --nobal turns it off (for comparisons).
const BAL_COST := {"word": 0.75, "storm": 0.85, "cage": 0.82, "fissure": 0.8, "orb": 0.8, "anvil": 0.9, "pillars": 0.9}
const BAL_DMG := {"fissure": 2.0, "orb": 1.6, "word": 1.3, "chain": 1.2, "anvil": 1.2, "cage": 1.3, "leash": 0.7}
static var _bal_on := -1
static func bal_on() -> bool:
	if _bal_on < 0:
		_bal_on = 0 if OS.get_cmdline_user_args().has("--nobal") else 1
	return _bal_on == 1

func cost(id: String) -> float:
	var c: float = super.cost(id)
	if bal_on():
		c *= float(BAL_COST.get(id, 1.0))
	if K("wordpower") > 0 and int(data.get(id, {}).get("tab", 0)) == 2:
		c *= 0.9
	return c

# ================================================================== the WS table (c_game.js, o_skills14.js, zz_*)
func ws_iron() -> float: return 1.0 + 0.08 * K("forge")
func ws_choir() -> float: return (1.0 + 0.08 * K("choir")) * WISP_NERF
func ws_anima() -> float: return 1.0 + 0.1 * K("animam")
func ws_nether() -> float: return 1.0 + 0.1 * K("nmastery")
func ws_rev_dmg() -> float: return (3.0 + (L1("wisps") - 1.0)) * dm() * ws_choir() * syn("wisps")
func ws_hits() -> int: return 3 + K("restless") / 3
func ws_fly_spd() -> float: return 7.0 * (1.0 + 0.05 * K("restless"))
func ws_burst_dmg() -> float: return (5.0 + 3.0 * (L1("burst") - 1.0)) * dm() * ws_choir()
func ws_burst_r() -> float: return _size(1.2 + 0.05 * K("burst"))
func ws_leech() -> float: return 0.06 + 0.015 * K("leech") if K("leech") > 0 else 0.0
func ws_bounce_mult() -> float: return 1.25 + (0.1 + 0.03 * K("resonance") if K("resonance") > 0 else 0.0)
func ws_max_bounce() -> int: return 3 + (1 if K("resonance") > 0 else 0) + K("resonance") / 8
func ws_golem() -> Dictionary:
	var l := L1("golem")
	var im := K("ironm")
	var b := syn_bonus("golem")
	var mx := roundf((60.0 + 35.0 * l + hero.st.level * 6.0) * (1.0 + 0.1 * im))
	return {"max": roundf(mx * (1.0 + b * 0.6)), "dmg": [(4.0 + 3.0 * l) * (1.0 + 0.08 * im) * (1.0 + b), (8.0 + 4.0 * l) * (1.0 + 0.08 * im) * (1.0 + b)],
		"armor": 40.0 + 8.0 * l + 6.0 * im, "spd": 4.2, "recharge": maxf(8.0, 22.0 - 0.7 * l)}
func ws_weapon(id: String = "") -> Dictionary:
	if id == "":
		id = gweapon
	var l := float(K(id))
	if id == "axe":
		return {"id": id, "dur": 1.05, "reach": 1.15, "mult": 1.2 + 0.12 * l, "arc": 0.9 + 0.02 * l}
	if id == "flail":
		return {"id": id, "dur": 1.35, "reach": 1.7, "mult": 1.4 + 0.18 * l, "aoe": 1.0 + 0.03 * l, "stun": 0.5 + 0.02 * l}
	return {"id": "sword", "dur": 0.75 / (1.0 + 0.03 * l), "reach": 1.05, "mult": 1.0 + 0.15 * l, "twice": 0.2 + 0.01 * l}
func ws_charge_max() -> float: return float(maxi(2, mini(3 + int(0.5 * K("overcharge")), wisp_cap())))
func ws_flow_rate() -> float: return 3.0 + 0.3 * K("overflow") if K("overflow") > 0 else 0.0
func ws_ramp_life() -> float: return minf(30.0, 10.0 + 0.6 * K("overcharge") + 0.75 * K("jugg"))
func ws_ramp_mult() -> float: return 1.3 + 0.03 * K("overcharge") + 0.05 * K("jugg")
func ws_det_dmg() -> float: return (25.0 + 6.0 * L1("golem") + 12.0 * K("overcharge")) * ws_iron()
func ws_det_r() -> float: return (2.4 + 0.05 * K("overcharge")) * (1.5 if K("overload") > 0 else 1.0)
func ws_det_k() -> float: return 2.0 if K("overload") > 0 else 1.0
func ws_flow_n() -> int: return 8 + K("overflow")
func ws_flow_dmg() -> float: return (6.0 + 3.0 * (L1("overflow") - 1.0)) * dm()
func ws_toss_dmg() -> float: return (0.8 + 0.1 * L1("toss")) * syn("toss")
func ws_toss_hover() -> float: return 0.8 + 0.05 * K("toss")
## the web keys the shield's ricochet on the golem's Bulwark; Mirror Shield's own Ricochet perk counts too (else it did nothing)
func ws_ricochet() -> int: return 1 + maxi(K("bulwark"), K("rico")) / 4 if maxi(K("bulwark"), K("rico")) > 0 else 0
func ws_thorns_pct() -> float: return 60.0 + 25.0 * K("thorns")
func ws_fissure_dmg() -> float: return (16.0 + 8.0 * (L1("fissure") - 1.0)) * dm() * ws_iron() * 1.2 * syn("fissure")
func ws_fissure_len() -> float: return _size(5.0 + 0.2 * K("fissure"))
func ws_fissure_keep() -> int: return 1 + K("fissure") / 6
func ws_crack_life() -> float: return 5.0 + 0.25 * K("fissure")
func ws_aura_dps() -> float: return (8.0 + 3.0 * L1("golem") + 4.0 * K("overcharge")) * ws_iron() * (1.0 + 0.05 * K("jugg"))
func ws_aura_r() -> float: return 2.0 + 0.05 * K("jugg")
func ws_pillar_dmg() -> float: return (14.0 + 7.0 * (L1("pillars") - 1.0)) * dm() * ws_iron() * 1.2 * syn("pillars")
func ws_pillar_n() -> int: return _cnt(3 + K("pillars") / 5)
func ws_pillar_life() -> float: return _life((10.0 + 0.5 * K("pillars")) * (1.0 + 0.04 * K("forge")) * (1.5 if K("temper") > 0 else 1.0))
func ws_cage_n() -> int: return _cnt(7 + K("cage") / 5)
func ws_cage_dmg() -> float: return (10.0 + 5.0 * (L1("cage") - 1.0)) * dm() * ws_iron() * 1.2 * syn("cage")
func ws_cage_life() -> float: return _life(6.0 + 0.3 * K("cage"))
func ws_anvil_dmg() -> float: return (22.0 + 11.0 * (L1("anvil") - 1.0)) * dm() * ws_iron() * 1.2 * syn("anvil")
func ws_magnet_r() -> float: return 2.5 + 0.1 * K("magnet")
func ws_magnet_pull() -> float: return 0.7 + 0.04 * K("magnet")
func ws_challenge_r() -> float: return 3.5 + 0.1 * K("challenge")
func ws_challenge_cd() -> float: return maxf(3.0, 6.0 - 0.15 * K("challenge"))
func ws_harvest() -> float: return 0.04 + 0.02 * K("harvest") if K("harvest") > 0 else 0.0
func ws_cond_rate() -> float: return maxf(0.14, 0.32 - 0.009 * K("condense"))
func ws_cond_max() -> int: return int(round((6 + K("condense") + (3 if aM("w_host") else 0)) * (1.2 if K("greatsoul") > 0 else 1.0)))
func ws_cond_dmg() -> float: return (5.0 + 2.5 * (L1("condense") - 1.0)) * dm() * ws_anima() * syn("condense")
func ws_cond_life() -> float: return _life(5.0 + 0.3 * K("condense"))
func ws_rad_dmg() -> float: return (4.0 + 2.0 * (L1("radiance") - 1.0)) * dm() * ws_anima()
func ws_nova_dmg() -> float: return (15.0 + 8.0 * (L1("nova") - 1.0)) * dm() * ws_anima()
func ws_leash_dps() -> float: return (9.0 + 4.0 * (L1("leash") - 1.0)) * dm() * ws_anima() * (1.3 if K("barbs") > 0 else 1.0) * syn("leash")
## the thread's hold (zz_zz_thread93.js leashDur); Stronger Bindings and the choir's shaping ride on it too
func ws_leash_dur() -> float: return _life((3.0 + 0.1 * K("leash")) * (1.5 if K("bindings") > 0 else 1.0))
func ws_totem_n() -> int: return _cnt(3 + K("totem") / 5)
func ws_totem_life() -> float: return _life(14.0 + 0.8 * K("totem")) * (1.5 if aM("w_vigil") else 1.0)
func ws_totem_dps() -> float: return (8.0 + 4.0 * (L1("totem") - 1.0)) * dm() * ws_anima() * syn("totem")
func ws_soul_dmg() -> float: return (7.0 + 3.5 * (L1("swarm") - 1.0)) * dm() * ws_nether() * (1.0 + 0.05 * K("hunger")) * syn("swarm")
func ws_soul_hits() -> int: return (2 + K("hunger") / 5 if K("hunger") > 0 else 1) + (1 if aM("g_swarm") else 0)
func ws_souls_per_wisp() -> int: return 3 + K("soullegion") / 3
func ws_storm_life() -> float: return (3.0 + 0.2 * K("storm")) * (1.5 if K("eye") > 0 else 1.0)
func ws_storm_rate() -> float: return maxf(0.08, 0.2 - 0.005 * K("storm"))
func ws_lance_dps() -> float: return (26.0 + 10.0 * (L1("lance") - 1.0)) * dm() * ws_nether() * syn("lance")
func ws_lance_range() -> float: return 6.0 + 0.2 * L1("lance")
func ws_lance_pierce() -> int: return 2 + K("lance") / 5
func ws_focus_max() -> float: return 0.4 + 0.08 * K("focus") if K("focus") > 0 else 0.0
func ws_prism_ln() -> int: return 1 + K("prismL") / 5
func ws_prism_lpct() -> float: return 0.4 + 0.03 * K("prismL")
func ws_siphon() -> float: return 0.02 + 0.005 * K("lsiphon") if K("lsiphon") > 0 else 0.0
func ws_orb_dmg() -> float: return (5.0 + 2.5 * (L1("orb") - 1.0)) * dm() * ws_nether() * syn("orb")
func ws_orb_rate() -> float: return maxf(0.035, 0.07 - 0.0015 * K("shards"))
func ws_shard_pierce() -> int: return 2 + K("shards") / 6 if K("shards") > 0 else 1
func ws_cascade_n() -> int: return _cnt(2 + K("cascade") / 8) if K("cascade") > 0 else 0
func ws_cascade_pct() -> float: return 0.45 + 0.025 * K("cascade")
func ws_phantom_dmg() -> float: return (8.0 + 4.0 * (L1("phantom") - 1.0)) * dm() * ws_nether()
func ws_rebuke_dmg() -> float: return (10.0 + 5.0 * (L1("rebuke") - 1.0)) * dm() * ws_nether()
func ws_rebuke_need() -> float: return maxf(10.0, 30.0 - 0.8 * K("rebuke"))
func ws_wraith_drain() -> float: return maxf(2.0, 7.0 - 0.25 * K("wraith"))
func ws_wraith_spd() -> float: return minf(1.35, 1.2 + 0.008 * K("wraith") + (0.1 if K("wraithhaste") > 0 else 0.0))
func ws_mark_r() -> float: return _size((2.2 + 0.08 * K("mark")) * (1.5 if K("markwide") > 0 else 1.0))
func ws_mark_pct() -> float: return 0.2 + 0.02 * K("mark")
func ws_mark_life() -> float: return _life(8.0 + 0.4 * K("mark"))
func ws_word_dmg() -> float: return (30.0 + 14.0 * (L1("word") - 1.0)) * dm() * ws_nether() * syn("word")
func ws_chain_dmg() -> float: return (12.0 + 6.0 * (L1("chain") - 1.0)) * dm() * ws_nether() * syn("chain")
func ws_chain_n() -> int: return _cnt(4 + int(L1("chain") / 4.0))
func ws_ward_pct() -> float: return minf(0.97, (0.05 if aM("g_ward") else 0.0) + minf(0.95, 0.68 + 0.015 * K("ward") + (0.04 if K("wardfast") > 0 else 0.0))) if K("ward") > 0 else 0.0
func ws_ward_eff() -> float: return 1.0 + 0.06 * K("ward")
# the one choir's chances on each wisp strike (zz_zz_mystic90.js CH)
func ch_thread() -> float: return minf(0.20, 0.04 + 0.01 * K("wisps")) if K("wisps") > 0 else 0.0
func ch_pass() -> float: return minf(0.45, 0.10 + 0.03 * K("restless")) if K("restless") > 0 else 0.0
func ch_needle() -> float: return minf(0.40, 0.08 + 0.025 * K("beam")) if K("beam") > 0 else 0.0
func ch_split() -> float: return minf(0.40, 0.08 + 0.025 * K("prism")) if K("prism") > 0 else 0.0
func chances() -> Dictionary: return {"thread": ch_thread(), "pass": ch_pass(), "needle": ch_needle(), "split": ch_split()}
func needle_dmg() -> float: return ws_rev_dmg() * (0.6 + 0.04 * K("beam"))
func needle_len() -> float: return (4.5 if K("sweep") > 0 else 2.6) * (1.3 if aM("w_ember") else 1.0)
func spark_dmg() -> float: return ws_rev_dmg() * (0.5 + 0.04 * K("prism")) * (1.3 if K("prismchain") > 0 else 1.0)
func spark_n() -> int: return (2 if K("prismex") > 0 else 1) + (1 if aM("w_ember") else 0)
func proc_r() -> float: return 1.7 + (0.9 if K("procwide") > 0 else 0.0)
func golem_orders() -> Dictionary:
	return {"leash": 1.8 + gbeh["x"] * 1.7, "aggro": 2.5 + gbeh["y"] * 1.5 + gbeh["x"] * 0.6, "guard": gbeh["y"] <= 1}

# ================================================================== the choir's size
## 4 + Wisps/3 + Bright Choir + items (at most 3) + the Shrine of the Wisp (c_game.js derive)
func wisp_cap() -> int:
	return 4 + K("wisps") / 3 + (1 if K("bright") > 0 else 0) + mini(3, int(hero.st.item("wisp"))) + (2 if hero.st.item("shrine_wisp") > 0.0 else 0)

func ws_wisp_regen() -> float:
	var r := maxf(0.4, 2.6 - 0.1 * K("wisps"))
	r /= 1.0 + (hero.st.item("regen") + hero.st.W("wisp") + (20.0 if aM("w_swift") else 0.0) + 4.0 * K("choir") + (100.0 if hero.st.item("shrine_wisp") > 0.0 else 0.0)) / 100.0
	return r / (1.2 if K("swiftw") > 0 else 1.0)

## wisps held by the great wisp, the golem's charge and the lantern stay out of the choir
func reserved() -> int:
	var n := 0
	if great != null:
		n += great.size
	if golem != null and golem.infused > 0:
		n += golem.infused
	for t in totems:
		n += t.wisps.size()
	return n

func eff_cap() -> int:
	return maxi(0, wisp_cap() - reserved())

## wisps are fuel (v80): his spells strike at x(0.65 + 0.55 x the choir's fullness)
func choir_k() -> float:
	var cap := maxi(1, eff_cap())
	return 0.65 + 0.55 * minf(1.0, float(wisps.size()) / cap)

func wisp_range(base: float) -> float:
	return base + (wbeh["x"] - 2) * 1.1

func set_golem_hold(on: bool) -> void:
	gbeh["hold"] = on
	if golem != null:
		golem.hold = golem.tp if on else null

# ================================================================== small helpers
func mons() -> Array:
	if _mons_t != time:
		# once a frame: the creatures within 26 yd (everything the Mystic does happens nearer than that)
		_mons_t = time
		_mons = []
		var c: Vector2 = hero.tp
		for m in hero.get_tree().get_nodes_in_group("monsters"):
			if absf(m.tp.x - c.x) < 26.0 and absf(m.tp.y - c.y) < 26.0:
				_mons.append(m)
	var out: Array = []
	for m in _mons:
		if is_instance_valid(m) and not m.dead and not m.buried:
			out.append(m)
	return out

func is_idle(m) -> bool:
	return m.brain == null or m.brain.state == "sleep"

## a creature coming for the hero (the web's m.tgt === P)
func threatens(m) -> bool:
	return m.awake and m.brain != null and m.brain.state in ["chase", "wind", "strike", "recover", "gap"] and m.tp.distance_to(hero.tp) < 6.0

func taunt(m, by, secs: float) -> void:
	m.set_meta("mys_taunt_until", Time.get_ticks_msec() / 1000.0 + secs)
	m.set_meta("mys_taunt_by", by)
	wake(m)

func shove(m, v: Vector2) -> void:
	if m.flying:
		m.tp += v
	else:
		m.tp = zone.move(m.tp, v, m.radius * 0.6)

func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 1e-6)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func monster_near(p, r: float) -> Variant:
	if not (p is Vector2) or p == Vector2.INF:
		return null
	var best = null
	var bd := r
	for m in mons():
		var d: float = m.tp.distance_to(p)
		if d < bd:
			bd = d
			best = m
	return best

func walkable_near(p: Vector2) -> Vector2:
	if not zone.is_solid(p):
		return p
	var c := Vector2i(int(p.x), int(p.y))
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := Vector2(c.x + dx + 0.5, c.y + dy + 0.5)
				if not zone.is_solid(q):
					return q
	return hero.tp

## the pale look of a thing breaking: glass that falls and lies a moment
func glass_burst(p: Vector2, n: int, spd: float, z0: float) -> void:
	for i in n:
		var a := randf() * TAU
		var v := spd * randf_range(0.4, 1.2)
		glass.append({"tp": p, "z": z0 * randf_range(0.5, 1.0), "v": Vector2(cos(a), sin(a)) * v, "vz": randf_range(10.0, 40.0), "t": randf_range(0.8, 1.6), "s": 2.0 if randf() < 0.35 else 1.0})
	if glass.size() > 400:
		glass = glass.slice(glass.size() - 400)

func dust(p: Vector2, n: int, spd: float) -> void:
	glass_burst(p, mini(n, 6), spd * 0.5, 4.0)

func ring(p: Vector2, R: float, secs: float, r0: float = 0.3) -> void:
	rings.append({"tp": p, "R": R, "R0": r0, "t": secs, "max": secs})

func ground_fire(p: Vector2, R: float, dps: float, secs: float) -> void:
	if zone.is_solid(p):
		return
	fires.append({"tp": p, "R": R, "dps": dps, "t": secs, "max": secs, "tick": 0.0})
	while fires.size() > 40:
		fires.pop_front()

func new_soul(at: Vector2, ang: float, spd: float, dmg: float, hits: int = -1) -> Dictionary:
	var s := {"tp": at, "v": Vector2(cos(ang), sin(ang)) * spd, "t": 2.2, "target": null, "retarget": randf() * 0.15, "wob": randf() * 6.0,
		"dmg": dmg, "hits": hits if hits > 0 else ws_soul_hits(), "hit": {}}
	souls.append(s)
	return s

## a hit from the Mystic's side. The choir multiplies everything but his golem's blows (light79); Needle's Mark
## brands for its own share (the body gives x1.3 for any mark: corrected here), the lantern exposes (+15%), Cull marks.
func hurt(m, dmg: float, id: String = "", o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead or m.buried or dmg <= 0.0:
		return 0.0
	var d := dmg
	if bal_on():
		d *= float(BAL_DMG.get(id, 1.0))
	if not o.get("golem", false) and not o.get("nochoir", false):
		d *= choir_k()
	if m.marked > 0.0:
		d *= (1.0 + ws_mark_pct()) / 1.3
	if float(m.get_meta("mys_frail", -1.0)) > time:
		d *= 1.15
	if float(m.get_meta("mys_cull", -1.0)) > time:
		d *= 1.15
	if aM("i_rust"):
		for mo in mirrors:
			if mo.kind == "pane" and mo.standing() and mo.tp.distance_to(m.tp) < 1.3 + m.radius:
				d *= 1.15
				break
	var from: Vector2 = o.get("from", hero.tp)
	var opts := {}
	if o.has("poise"):
		opts["poise"] = o["poise"]
	if o.get("heavy", false):
		opts["heavy"] = true
	var dealt: float = Combat.hit_monster(m, d, ELEM.get(id, "magic"), from, opts)
	if trace:
		dmg_log[id] = float(dmg_log.get(id, 0.0)) + dealt
	if id in ["lance", "orb"] and aR("a_sage"):
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dealt * 0.2)
	return dealt

# ================================================================== wisps as fuel
func take_wisp() -> Wisp:
	if wisps.is_empty():
		return null
	var w: Wisp = wisps.pop_back()
	w.gone = true
	glass_burst(w.tp, 2, 1.0, w.z)
	_wisp_lost()
	return w

func spawn_wisp(at = null) -> void:
	if wisps.size() >= eff_cap():
		return
	var w := Wisp.new()
	var a := randf() * TAU
	w.tp = (at if at is Vector2 else hero.tp + Vector2(cos(a), sin(a)) * 0.7)
	w.ang = a
	w.rad = 0.8 + randf() * 0.9
	w.wt = randf() * 10.0
	w.cd = 0.3 + randf()
	wisps.append(w)

## pay for a spell: its Essence, and (v80) a wisp burned as fuel, two for the dearest (cost >= 40). Never refused
## for lack of wisps.
func spend(id: String, amt: float = -1.0) -> bool:
	var need := cost(id) if amt < 0.0 else amt
	if hero.st.res < need:
		say("Not enough %s." % hero.st.res_name(), 1.0)
		return false
	hero.st.res -= need
	dmg_log["_spent"] = float(dmg_log.get("_spent", 0.0)) + need
	if amt < 0.0 and not (id in OWN):
		var n := 2 if cost(id) >= 40.0 else 1
		for i in n:
			take_wisp()
	return true

func end_wraith() -> void:
	if wraith:
		wraith = false
		if aM("g_wraith") and hero:
			for i in 6:
				new_soul(hero.tp, i / 6.0 * TAU, 5.0, ws_soul_dmg())
		if hero and hero.spr:
			hero.spr.modulate = Color.WHITE


func _wisp_allowed(m) -> bool:
	if wbeh["hold"]:
		return false
	if wbeh["y"] <= 1:
		if m.tp.distance_to(hero.tp) < 2.6 + wbeh["y"] * 0.8 or threatens(m):
			return true
		return golem != null and golem.state != "dormant" and m.get_meta("mys_taunt_by", null) == golem.node and m.tp.distance_to(golem.tp) < 2.5
	return true


# ================================================================== the Arcana (v103): what the Mystic's cards change
func arc():
	return hero.st.arc if hero and hero.st else null

func aU(id: String) -> bool:
	var a = arc()
	return a != null and a.aU(id)

func aR(id: String) -> bool:
	var a = arc()
	return a != null and a.aR(id)

func aM(id: String) -> bool:
	var a = arc()
	return a != null and a.aM(id)

## the hero's weapon, when a card makes it heavier (The Anvil reversed, the golem worn as a shell)
func melee_k() -> float:
	return 1.5 if shell > 0.0 else 1.0

## the hero's walk (The Maiden's Kiss reversed: the hall closed on him)
func move_k() -> float:
	return 0.8 if maiden_t > 0.0 else 1.0

func _arcana_tick(dt: float) -> void:
	# The Anvil: glass on the ground cuts what walks through it
	for s in splinters:
		s["t"] -= dt
		s["tick"] -= dt
		if s["tick"] <= 0.0:
			s["tick"] = 0.5
			for m in mons():
				if m.tp.distance_to(s["tp"]) < 0.55 + m.radius and not m.flying:
					hurt(m, ws_anvil_dmg() * 0.06, "anvil", {"from": s["tp"], "poise": 0.0})
	splinters = splinters.filter(func(s): return s["t"] > 0.0)
	maiden_t = maxf(0.0, maiden_t - dt)
	# Storm: every standing mirror sheds a splinter at the nearest creature within 5 yd each second
	if aU("a_storm"):
		storm_t -= dt
		if storm_t <= 0.0:
			storm_t = 1.0
			var n := 0
			for o in mirrors:
				if o.kind != "pane" or not o.standing() or n >= 8:
					continue
				var best = null
				var bd := 5.0
				for m in mons():
					var d: float = m.tp.distance_to(o.tp)
					if d < bd and not is_idle(m) and zone.sight_clear(o.tp, m.tp):
						bd = d
						best = m
				if best != null:
					n += 1
					var dv: Vector2 = (best.tp - o.tp).normalized()
					gshots.append({"tp": o.tp + dv * 0.3, "v": dv * 11.0, "dmg": ws_pillar_dmg() * 0.5, "t": 0.6, "hit": {}, "id": "pillars"})
	# The Choir: the whole choir dives together every 2 s
	if aU("a_choir"):
		choir_t -= dt
		if choir_t <= 0.0:
			choir_t = 2.0
			var t = null
			var bd2 := 6.0
			for m in mons():
				var d2: float = m.tp.distance_to(hero.tp)
				if d2 < bd2 and _wisp_allowed(m) and not is_idle(m):
					bd2 = d2
					t = m
			if t != null:
				for w in wisps:
					if w.state == "drift":
						w.state = "dive"
						w.target = t
	# The Aether-Sage reversed: the draining thread
	for d3 in drains:
		d3["t"] -= dt
		d3["tick"] -= dt
		var m3 = d3["m"]
		if not is_instance_valid(m3) or m3.dead or m3.tp.distance_to(hero.tp) > 7.5:
			d3["t"] = 0.0
			continue
		if d3["tick"] <= 0.0:
			d3["tick"] = 0.25
			var got := hurt(m3, ws_soul_dmg() * 0.35, "swarm", {"from": hero.tp})
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + got)
	drains = drains.filter(func(d4): return d4["t"] > 0.0)
	# Pyre reversed: the wraith leaves pale fire where it walks
	if aR("a_pyre") and wraith and hero.walking:
		pyre_t -= dt
		if pyre_t <= 0.0:
			pyre_t = 0.3
			ground_fire(hero.tp, 0.6, ws_soul_dmg() * 0.8, 2.5)
	# Silver Tether: near the golem it mends
	if aM("w_tether") and golem != null and golem.state != "dormant" and golem.tp.distance_to(hero.tp) < 3.0:
		golem.hp = minf(golem.max_hp, golem.hp + golem.max_hp * 0.02 * dt)
	# The Choir Crown: upright, wisps come back and drain; reversed, they mend
	if aM("v_crown"):
		var k := 0.003 * wisps.size() * hero.st.life_max() * dt
		if aU("v_crown"):
			hero.st.hp = maxf(1.0, hero.st.hp - k)
		else:
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + k)
	if not crown_q.is_empty():
		var keep: Array = []
		for tq in crown_q:
			if time >= tq:
				spawn_wisp()
			else:
				keep.append(tq)
		crown_q = keep
	# The Bell-Warden reversed: nothing near casts or shoots (entities/missile.gd hush)
	if aR("a_bell"):
		Missile.hush = {"tp": hero.tp, "r": 5.0, "until": Time.get_ticks_msec() / 1000.0 + 0.2}

## a wisp lost or spent: the Crown may call it back
func _wisp_lost() -> void:
	if aU("v_crown") and hero.st.hp > hero.st.life_max() * 0.5:
		crown_q.append(time + 3.0)


## The Anvil: a ring of glass splinters on the ground (cut what walks through; drawn as cracked glass)
func _splinter_ring(c: Vector2, R: float, n: int) -> void:
	for i in n:
		var ang := float(i) / n * TAU + randf() * 0.4
		var p := c + Vector2(cos(ang), sin(ang)) * R * randf_range(0.4, 1.0)
		if zone.is_solid(p):
			continue
		splinters.append({"tp": p, "t": 4.0, "tick": 0.0})
		cracks.append({"tp": p, "t": 4.0, "max": 4.0, "v": randi()})
	while splinters.size() > 40:
		splinters.pop_front()

## The Hollow Blade reversed: Needle and Thread swung as a spirit sword in wide arcs (melee: it costs poise)
func _spirit_sword(a: Vector2) -> void:
	var dir := (a - hero.tp).normalized() if a.distance_to(hero.tp) > 0.01 else Vector2(1, 1).normalized()
	hero.spend_poise(4.0)
	hero._start_act("atk", 0.3)
	for m in mons():
		var dv: Vector2 = m.tp - hero.tp
		if dv.length() > 2.1 + m.radius:
			continue
		if dv.length() > 0.2 and dv.normalized().dot(dir) < 0.35:
			continue
		hurt(m, ws_lance_dps() * 0.55, "lance", {"from": hero.tp, "poise": ws_lance_dps() * 0.4})
