extends "res://skills/skill_book.gd"

## The Shrine Keeper (class id "miasmancer"): Shiori of the House of Eight Million, who breathes the world's distortion
## in and gives it back. Three trees: Miasma (her breath: the cloud about her, the fan, the exhalation, contagion, the
## tide, the vortex), Distortion (traps, the decoy, haze, mirage, the lure, the Mirror-Sister) and Death (claw and heel:
## strikes that build Omens and finishers that spend them).
## Ported from the web build's final behaviour: m_mias.js (the numbers MS, the skills, the cloud, traps, the sister,
## the hooks), o_skills14.js (Rending Arc, Impaling Thrust, Black-Rag Flurry), zz_miasma_breath.js (the cloud grows
## with rank; Inhale a passive trickle; Miasmic Exhalation; the sister has life), zz_tune_batch_d.js (half the base
## regain), k_arcana.js poisonMon (a sickness keeps its strongest dose; some stack).
## Her resource is Miasma (st.res): it seeps back slowly, faster standing in her own miasma, and her breathing draws it
## in. Death skills cost poise ("stamina"). Omens (up to 3) quicken her and strengthen her strikes; they fade after 14 s.
## Sickness is kept on each creature as meta "k_psn" {dps, t, n}; it ticks as "miasma" (x PSN_K, the G1 balance).
## The Arcana (z_*, zm_*, zd_*, zx_* in data/board.json) are read here with aU / aR / aM where each skill acts.
##
## Test args: --learn=all[:L], --autocast[=id,id], --miastrace.

const FxNode = preload("res://skills/miasmancer/fx.gd")
const Ally = preload("res://skills/miasmancer/ally.gd")

## the pose each skill strikes (art/sprites/miasmancer.json: atk, cast, rake, thrust, spin, lunge)
const POSE := {"rarc": "rake", "flurry": "rake", "gstrike": "atk", "thrust": "thrust", "execute": "thrust", "talon": "spin",
	"reap": "spin", "dstep": "lunge", "blur": "lunge", "shuriken": "atk"}
const MELEE := {"gstrike": 1.1, "talon": 1.2, "execute": 1.2, "flurry": 1.3}
const PSN_K := 0.8           # G1 balance (2026-09-30): sickness ticks a fifth softer
const TUNE := 0.8            # G1 balance: all her damage (a whole kit at level 20 dealt twice the Mystic's)
const TRAPS := ["ntrap", "mwake", "bmine"]
const SISTER_SKILLS := ["pnova", "contagion", "rotwall", "shuriken", "haze", "mirage", "lure", "gstrike", "talon", "flurry", "rarc", "thrust", "reap", "execute", "ntrap", "bmine", "mwake"]
const SISTER_MELEE := ["gstrike", "talon", "flurry", "rarc", "thrust", "reap", "execute"]
const VIOLET := Color8(176, 112, 224)
const VIOLET_D := Color8(138, 74, 184)
const PALE := Color8(232, 226, 208)
const WARP := Color8(168, 192, 224)

var zone: Zone
var time := 0.0
var fx_air: Node2D
var fx_floor: Node2D
var trace_t := 5.0
var auto_t := 0.0
var auto_i := 0
var src := ""

var omens := 0
var omen_t := 0.0
var venom_t := 0.0
var venom_n := 0
var blur_ev := 0.0
var breath_cd := 0.0          # (unused: Last Breath is once in each place now)
var breath_used := {}         # place id -> times Last Breath has held her there
var unseen_t := 0.0
var haze_mantle := 0.0
var aura_t := 0.0
var fed_aura := 0
var worn_traps: Array = []
var mstorm_t := 0.0
var mstorm_tick := 0.0
var in_miasma := false
var gcount := 0
var trail_d := 0.0
var inhale_t := 0.0
var last_tp := Vector2.INF
var sister_cast := false
var reap_kept := 0
var pending := {}
var queue: Array = []        # delayed blows: {t, f: Callable}

var clouds: Array = []       # {tp, R, t, max, dps, kind (poison | haze), tick, seed}
var novas: Array = []
var tides: Array = []
var traps: Array = []
var throws: Array = []
var decoys: Array = []       # Ally nodes
var mirages: Array = []
var lures: Array = []
var dash := {}
var scythes: Array = []
var shuris: Array = []
var clawfx: Array = []
var knives: Array = []
var zaps: Array = []
var motes: Array = []
var words: Array = []
var rings: Array = []
var sister = null            # Ally node, kind "sister"

# ================================================================== levels and numbers (m_mias.js MS)
## the Shrine Keeper's own test args (the shared ones are read in skill_book.gd)
func _arg(k: String, _v: String) -> void:
	if k == "miastrace":
		trace = true


func sister_k() -> float: return 0.35 + 0.015 * L1("sister")
func power() -> float: return TUNE * hero.st.skill_mult() * (1.0 + 0.1 * K("toxic")) * (sister_k() if sister_cast else 1.0)
func frac() -> float: return clampf(hero.st.res / maxf(1.0, hero.st.res_max()), 0.0, 1.0)
## the cloud about her: small at first, it grows with rank; a full breath billows (zz_miasma_breath.js)
func aura_r() -> float:
	var l := K("mcloud")
	return (0.35 + 0.15 * maxf(0, l - 1) + 0.9 * frac() * (0.4 + 0.05 * l)) * (1.2 if aM("zm_thick") else 1.0)
func aura_dps() -> float: return (2.0 + 1.2 * (L1("mcloud") - 1.0)) * power() * (0.35 + 0.65 * frac())
func evade() -> float:
	return minf(0.6, (0.06 + 0.012 * L1("mcloud")) * frac() * (1.0 if K("mcloud") > 0 else 0.0) + (0.1 if K("shroud") > 0 else 0.0) + 0.01 * K("unseen") + (0.3 if blur_ev > 0.0 else 0.0))
func cloud_life() -> float: return (1.0 + 0.05 * K("toxic")) * (1.5 if aM("zm_seep") else 1.0)
func ctrl() -> float: return (1.0 + 0.04 * K("unseen")) * (1.25 if K("unseenlong") > 0 else 1.0)
func fang_dmg() -> float: return (5.0 + 2.5 * (L1("vblade") - 1.0)) * power()
func nova_dmg() -> float: return (8.0 + 4.0 * (L1("pnova") - 1.0)) * power() * syn("pnova")
func nova_psn() -> float: return (4.0 + 2.2 * (L1("pnova") - 1.0)) * power()
func tide_dmg() -> float: return (10.0 + 5.0 * (L1("rotwall") - 1.0)) * power() * syn("rotwall")
func cont_psn() -> float: return (3.0 + 1.5 * (L1("contagion") - 1.0)) * power() * syn("contagion")
func exhale_k() -> float: return (0.9 + 0.05 * L1("exhale")) * power() * syn("exhale")
func blade_psn() -> float: return (_wavg() * 0.5 + 2.0 + 1.2 * (L1("vblade") - 1.0)) * power() * syn("vblade")
func shuri_dmg() -> float: return (6.0 + 3.0 * (L1("shuriken") - 1.0)) * power() * syn("shuriken")
func storm_dmg() -> float: return (5.0 + 2.4 * (L1("mstorm") - 1.0)) * power() * syn("mstorm")
func storm_r() -> float: return 3.2 + (1.0 if K("stormwide") > 0 else 0.0)
func storm_life() -> float: return 8.0 + 0.3 * L1("mstorm")
func trap_k() -> float: return (1.0 + 0.08 * K("unseen")) * power()
func needle_dmg() -> float: return (4.0 + 2.0 * (L1("ntrap") - 1.0)) * trap_k() * syn("ntrap") * 0.5   # G1 balance: four needle traps were half her damage
func wake_dmg() -> float: return (3.5 + 1.75 * (L1("mwake") - 1.0)) * trap_k() * (1.25 if aM("zd_snare") else 1.0) * syn("mwake")   # G1: x0.7
func wake_life() -> float: return 12.0 * (2.0 if K("wakelong") > 0 else 1.0) * (1.5 if aM("zd_snare") else 1.0)
func mine_dmg() -> float: return (18.0 + 8.0 * (L1("bmine") - 1.0)) * trap_k() * syn("bmine")
func sentry_dmg() -> float: return (20.0 + 9.0 * (L1("ntrap") - 1.0)) * trap_k()
func trap_max() -> int:
	var u := K("unseen")
	return 2 + (1 if u >= 1 else 0) + (1 if u >= 5 else 0) + (1 if u >= 10 else 0) + (2 if aU("z_trapq") else 0) + (1 if K("trapmax2") > 0 else 0)
func arm_t() -> float: return 0.0 if (aU("z_trapq") or K("trapquick") > 0) else 0.8 / (1.0 + 0.05 * K("unseen"))
func claw_on() -> bool:
	var w: Item = hero.st.inv.weapon() if hero.st.inv else null
	return w != null and bool(Item.base_row(w.base).get("claw", false))
func _wavg() -> float:
	var w: Item = hero.st.inv.weapon() if hero.st.inv else null
	return ((w.dmg.x + w.dmg.y) / 2.0) if w else 2.0
func weapon() -> float:
	return _wavg() * hero.st.melee_mult() * (1.0 + 0.06 * K("deathm")) * (1.25 if claw_on() else 1.0) * (1.0 + 0.06 * omens) * (sister_k() if sister_cast else 1.0)
func crit_ch(fin: bool = false) -> float:
	return (minf(0.4, 0.03 + 0.015 * K("dhead")) if K("dhead") > 0 else 0.0) + (0.1 if fin and aM("zx_crit") else 0.0)
func omen_max() -> int: return 2 if aR("z_death") else 3 + (1 if K("omen4") > 0 else 0)
func omen_life() -> float: return 24.0 if aM("zx_omen") else 14.0
func warp_chance() -> float: return (0.04 + 0.004 * L1("warp")) * (2.0 if K("warpmore") > 0 else 1.0) if K("warp") > 0 else 0.0
func sister_cd() -> float: return maxf(1.2, 3.2 - 0.05 * L1("sister")) / (2.0 if K("sisterfast") > 0 else 1.0)

## her cast speed: Omens quicken her, and claws are her own weapon
func cast_k() -> float:
	return (1.0 + 0.05 * omens) * (1.15 if claw_on() else 1.0) * (1.1 if K("deathspd") > 0 else 1.0)

func info(id: String) -> String:
	var r := func(v): return str(int(round(v)))
	var pc := func(v): return str(int(round(v * 100.0))) + "%"
	match id:
		"mcloud": return "Cloud %.1f yd · sickens %s/s · %s of blows miss (full cloud: more)" % [aura_r(), r.call(aura_dps()), pc.call(evade())]
		"vblade": return "40 s · claws sicken %s/s for 4 s and slow" % r.call(blade_psn())
		"pnova": return "%s damage · sickens %s/s for 4 s · 5 yd" % [r.call(nova_dmg()), r.call(nova_psn())]
		"contagion": return "Leaps every 1.5 s · %s/s miasma · 10 s" % r.call(cont_psn())
		"rotwall": return "%s damage · miasma %s/s · %.1f yd wide" % [r.call(tide_dmg()), r.call(tide_dmg() * 0.4), 3.6 if K("wwide") > 0 else 2.4]
		"inhale": return "Breathes in every %.1f s from clouds and the sickened within %.1f yd" % [maxf(0.9, 2.4 - 0.08 * K("inhale")), 5.0 + 0.1 * K("inhale")]
		"exhale": return "%s damage now (x%.2f per Miasma) · 3.5 yd" % [r.call(exhale_k() * maxf(5.0, hero.st.res)), exhale_k()]
		"shuriken": return "%s per cut · spirals out to ~4.5 yd · trails miasma" % r.call(shuri_dmg())
		"mstorm": return "%s/s in %.1f yd · slows · %d s" % [r.call(storm_dmg()), storm_r(), int(storm_life())]
		"toxic": return "+%d%% miasma · clouds +%d%% longer" % [10 * K("toxic"), 5 * K("toxic")]
		"blur": return "Step up to 6 yd · decoy %d s" % (5 if aM("zd_blur") else 3)
		"ntrap": return "%d needles · %s each · miasma" % [18 if K("needlemore") > 0 else 12, r.call(needle_dmg())]
		"mwake": return "Smokes %d s · waves %s and sicken" % [int(wake_life()), r.call(wake_dmg())]
		"haze": return "%d s · 2.2 yd · confuses" % (6 if K("hazelong") > 0 else 4)
		"mirage": return "%d s · 2.6 yd · half speed · missiles veer" % (9 if K("miragelong") > 0 else 6)
		"bmine": return "Bursts for %s · cloud %.1f yd" % [r.call(mine_dmg()), 3.3 if K("minebig") > 0 else 2.2]
		"lure": return "%d s · pulls within %d yd" % [5 if K("lurelong") > 0 else 3, 8 if K("lurewide") > 0 else 5]
		"warp": return "%s per tick per enemy in your miasma" % pc.call(warp_chance())
		"sister": return "Acts every %.1f s · %s of your strength" % [sister_cd(), pc.call(sister_k())]
		"unseen": return "+%d%% control time · +%d%% evasion · %d traps, +%d%% trap damage" % [4 * K("unseen"), K("unseen"), trap_max(), 8 * K("unseen")]
		"rarc": return "%s to each in a half-circle · +10%% per extra enemy" % r.call(weapon() * (0.95 + 0.09 * L1("rarc")) * syn("rarc"))
		"thrust": return "%s to each in a %d yd line" % [r.call(weapon() * (1.25 + 0.11 * L1("thrust")) * syn("thrust")), 4 if K("thrustlong") > 0 else 3]
		"gstrike": return "%s damage · +1 Omen · each Omen +6%% damage, +5%% speed" % r.call(weapon() * (1.4 + 0.12 * L1("gstrike")) * syn("gstrike"))
		"talon": return "%d kicks · %s each · +1 Omen" % [_kicks(), r.call(weapon() * (0.55 + 0.06 * L1("talon")) * syn("talon"))]
		"dstep": return "%s to each · %d yd" % [r.call(weapon() * (0.9 + 0.08 * L1("dstep")) * syn("dstep")), 8 if K("steplong") > 0 else 5]
		"flurry": return "%d strikes · %s each · hops between enemies in reach" % [6 if K("flurrymore") > 0 else 4, r.call(weapon() * (0.5 + 0.05 * L1("flurry")) * syn("flurry"))]
		"reap": return "%s · +70%% and +0.3 yd per Omen" % r.call(weapon() * (1.2 + 0.1 * L1("reap")) * syn("reap"))
		"execute": return "%s · +90%% per Omen · kills below %s +8%% per Omen" % [r.call(weapon() * (1.6 + 0.12 * L1("execute")) * syn("execute")), pc.call(0.15 if K("execthr") > 0 else 0.1)]
		"dhead": return "%s critical chance" % pc.call(crit_ch())
		"deathm": return "+%d%% melee · %d Omens%s" % [6 * K("deathm"), omen_max(), " · claws: +25% strikes, +15% speed" if claw_on() else " · wield claws for more"]
	return ""

func _kicks() -> int: return 3 + (1 if K("talonkick") > 0 else 0) + (1 if aM("zx_kiss") else 0)

# ================================================================== creatures and helpers

func stun(m, t: float) -> void:
	if m and not m.dead:
		m.stun = maxf(m.stun, t * 0.3 if m.boss else t)

func root(m, t: float) -> void:
	if m and not m.dead:
		m.root = maxf(m.root, minf(0.4, t) if m.boss else t)

func shove(m, from: Vector2, d: float) -> void:
	if m == null or m.dead or m.boss:
		return
	var v: Vector2 = (m.tp - from).normalized() * d
	m.tp = zone.move(m.tp, v, m.radius * 0.6)

func confuse(m, t: float) -> void:
	if m.dead or m.boss:
		return
	m.confused = maxf(m.confused, t * ctrl())
	wake(m)

func fear(m, t: float) -> void:
	if m.dead or m.boss:
		return
	m.feared = maxf(m.feared, t)

## sicken: a creature keeps its strongest dose; stacking skills add doses up to their stack
func psn(m, dps: float, t: float, stacks: int = 1, linger: bool = true) -> void:
	if m == null or m.dead or dps <= 0.0:
		return
	var q: Dictionary = m.get_meta("k_psn", {})
	if q.is_empty():
		q = {"dps": dps, "t": t, "n": 1, "tick": 0.3}
	elif stacks > 1 and int(q["n"]) < stacks:
		q["dps"] = float(q["dps"]) + dps
		q["n"] = int(q["n"]) + 1
		q["t"] = maxf(q["t"], t)
	else:
		q["dps"] = maxf(q["dps"], dps)
		q["t"] = maxf(q["t"], t)
	m.set_meta("k_psn", q)
	wake(m)
	if linger and randf() < 0.06 and float(m.get_meta("k_linger", -1.0)) < time:
		m.set_meta("k_linger", time + 1.5)
		add_cloud(m.tp, 0.9, 3.0, dps * 0.6)

func sick(m) -> bool:
	return not (m.get_meta("k_psn", {}) as Dictionary).is_empty()

func add_cloud(p: Vector2, R: float, t: float, dps: float, kind: String = "poison") -> Dictionary:
	if zone == null or zone.is_solid(p):
		return {}
	var c := {"tp": p, "R": R, "t": t * cloud_life(), "max": t * cloud_life(), "dps": dps, "kind": kind, "tick": 0.0, "seed": randf() * 99.0}
	clouds.append(c)
	while clouds.size() > 70:
		clouds.pop_front()
	return c

func hurt(m, dmg: float, id: String, o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead or m.buried or dmg <= 0.0:
		return 0.0
	var d := dmg
	if m.confused > 0.0 and K("madness") > 0:
		d *= 1.2
	if m.feared > 0.0 and K("knelldmg") > 0:
		d *= 1.2
	if float(m.get_meta("k_grave", -1.0)) > time:
		d *= 1.15
	if float(m.get_meta("k_frail", -1.0)) > time:
		d *= 1.15
	var elem: String = o.get("elem", "phys" if int(data.get(id, {}).get("tab", 0)) == 2 or id in ["knife", "claw"] else "miasma")
	var was := src
	src = id
	var opts := {}
	if o.get("melee", false):
		opts["melee"] = true
	if o.has("poise"):
		opts["poise"] = o["poise"]
	var dealt: float = Combat.hit_monster(m, d, elem, o.get("from", hero.tp), opts)
	src = was
	if trace:
		dmg_log[id] = float(dmg_log.get(id, 0.0)) + dealt
	return dealt

func crit(dmg: float, fin: bool = false) -> float:
	if sister_cast:
		return dmg
	if randf() < crit_ch(fin):
		say_at(hero.tp + Vector2(0, -0.3), "critical", Color.WHITE)
		if K("critomen") > 0:
			add_omen()
		return dmg * (3.0 if K("critdmg") > 0 else 2.0)
	return dmg

func add_omen() -> void:
	if sister_cast:
		return
	if omens < omen_max():
		omens += 1
		say_at(hero.tp + Vector2(0, -0.3), "omen %d" % omens, PALE)
		Sfx.play("glass", 0.3, 0.8 + omens * 0.15)
	omen_t = omen_life()

func spend_omens() -> int:
	var n := omens
	omens = 0
	return n

func claw(m) -> void:
	clawfx.append({"tp": m.tp, "a": (m.tp - hero.tp).angle() + randf_range(-0.4, 0.4), "t": 0.2})

func knife(from: Vector2, ang: float, dmg: float, pierce: int = 1, friendly_psn: bool = true) -> void:
	knives.append({"tp": from, "v": Vector2(cos(ang), sin(ang)) * 12.0, "t": 0.55, "dmg": dmg, "hit": {}, "pierce": pierce})

func ring(p: Vector2, R: float, secs: float, col: Color, r0: float = 0.2) -> void:
	rings.append({"tp": p, "R": R, "R0": r0, "t": secs, "max": secs, "col": col})

func puff(p: Vector2, col: Color, n: int, spd: float = 1.6) -> void:
	for i in mini(n, 24):
		var a := randf() * TAU
		motes.append({"tp": p + Vector2(cos(a), sin(a)) * randf() * 0.3, "z": randf_range(2.0, 12.0), "v": Vector2(cos(a), sin(a)) * spd * randf_range(0.2, 1.0), "vz": randf_range(2.0, 8.0), "t": randf_range(0.6, 1.3), "col": col})
	if motes.size() > 600:
		motes = motes.slice(motes.size() - 600)

func say_at(p: Vector2, t: String, col: Color = PALE) -> void:
	if sister_cast:
		return
	words.append({"tp": p, "s": t, "t": 1.0, "col": col})
	if words.size() > 24:
		words.pop_front()

func say(t: String, secs: float = 1.0) -> void:
	if not sister_cast:
		Bus.say.emit(t, secs)

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

func later(t: float, f: Callable) -> void:
	queue.append({"t": t, "f": f})

## the melee skills reach for the enemy nearest the cursor
func melee_target(a: Vector2, reach: float) -> Monster:
	reach += 0.15 if claw_on() else 0.0
	var best: Monster = null
	var bd := 1e9
	for m in mons():
		var dp: float = m.tp.distance_to(hero.tp)
		if dp > 3.6 + m.radius:
			continue
		var d: float = m.tp.distance_to(a) + dp * 0.3
		if d < bd and zone.sight_clear(hero.tp, m.tp):
			bd = d
			best = m
	if best == null or best.tp.distance_to(hero.tp) > reach + best.radius + 0.3:
		return null
	hero._face(best.tp - hero.tp)
	return best
