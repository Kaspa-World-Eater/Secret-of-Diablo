extends "res://skills/skill_book.gd"

## The Empty Hand (class id "monk"): the last ascetic of the Gilded Peak. Three trees: Radiance (stronger by day),
## Absence (stronger by night) and Destroyer (stone and blunt force, untouched by the sky). He can turn the sky
## himself: a forced noon or a forced night (Game.sky_force).
## Ported from the web build's final behaviour: zw_monk.js (the skills, KS numbers, the hooks), zz_monk_sand.js (the
## hourglass: two sands in one glass, casting pours, the sand runs back; Weight is gone), zz_mech_balance.js and
## zz_zz_empty92.js (names and texts: data/skills.json is the truth for those), zz_mech_trees.js (the tree).
##
## The hourglass: Radiance pours amber sand down into the lower bulb, Absence pours black sand up into the upper one.
## A bulb is half the resource pool (st.res_max() / 2). The fuller a bulb, the weaker that tree:
## strength = 1 - 0.9 f^2.5 (full: a tenth). A cast pours 12% of the bulb for a skill of the common cost (12.8), more
## for dear ones, at most 25%; turning the sky pours three times over. The sand runs back 2% of a bulb a second
## while he casts and 25% once he has been still for 0.9 s; hits run both back 0.3% (at most four times a second),
## every kill 7%. Destroyer costs poise. (G1 balance, 2026-09-30: the glass used to empty faster than he could pour
## it, so it never held him back; it was 5% a cast, 10% / 35% a second, 1.5% a hit every 0.08 s, 12% a kill.)
## He is never refused: a full bulb still casts, at a tenth of the force. st.res is kept as the room left in the glass.
## No cooldowns anywhere (the user's rule): the old waits became dearer pours.
##
## The Arcana (data/board.json cards kr_*, ka_*, kd_*, kh_*) are read here with aU / aR / aM where each skill acts.
##
## Test args: --learn=all[:L] or --learn=id,id[:L], --autocast[=id,id] (casts learned skills at the nearest creature
## in turn), --monktrace (prints the glass and each skill's damage every 5 s).

const FxNode = preload("res://skills/monk/fx.gd")
const BuddhaView = preload("res://skills/monk/buddha.gd")

const TUNE := 0.6         # v0.35: every skill's damage cut by a quarter; G1 (2026-09-30): by two fifths
const POUR := 0.12
const NORM := 12.8
const CAP := 0.25
## the pose each skill strikes (art/sprites/monk.json)
const POSE := {"khands": "flurry", "kfist": "skyfist", "kdawn": "sky", "keclipse": "sky", "ksun": "sky", "kmount": "leap",
	"kclap": "clap", "kpalm": "hungry", "kbelow": "hungry", "kpinch": "pinch", "kgrip": "pinch", "kfinger": "light3",
	"kspade": "light2", "kstep": "heavy", "kpagoda": "heavy", "kthousand": "heavy", "kweep": "heavy", "kbell": "clap"}
## the melee skills walk you in, then strike (reach in yards)
const MELEE := {"khands": 1.4, "kspade": 1.9, "kgrip": 1.4, "kfinger": 1.6}
const HOLD := ["keye", "klotus"]
const RAISED := ["hollow", "drowned", "archer", "ossarcher", "marrow", "knight", "hbone", "hhollow", "calc_knight", "marrow_ghoul", "chalk_wraith"]
## elements (zz_mech_resists.js): Radiance burns as radiance, Absence is void, stone and fists are physical
const ELEM := {"khands": "phys", "kspade": "phys", "kfinger": "phys", "kmirror": "phys", "kbar": "phys", "rubble": "phys"}

var zone: Zone
var time := 0.0
var fx_air: Node2D
var fx_floor: Node2D
var trace_t := 5.0
var auto_t := 0.0
var auto_i := 0

# the glass
var kR := 0.0
var kA := 0.0
var pour_tab := -1
var pour_t := -9.0
var cast_t := -9.0
var last_res := -1.0
var hit_t := -9.0
var src := ""                # the skill whose blow is landing (kills read it)

# his states
var amber := false
var amber_t := 0.0
var walk := false
var walk_t := 0.3
var obsid := 0.0
var mirror_t := 0.0
var nothing_t := 0.0
var sun_t := 0.0
var sun_tick := 0.0
var bowl := 0
var laugh_t := 3.0
var halo := 0
var halo_t := 0.0
var bar_hold := false
var float_z := 0.0
var bell := {}
var eye := {}
var lotus := {}
var leap := {}
var flurry := {}
var palm := {}
var thousand := {}
var quake := {}
var pending := {}            # a melee skill walking in: {id, m, at, t}
var hold_id := ""            # a held skill waiting for its first frame
var auto_hold := ""          # --autocast: a held skill held for 1.6 s
var buddha = null            # the Weeping One (skills/monk/buddha.gd)
var buddha_mem := {}

# what lies about: drawn by skills/monk/fx.gd
var cones: Array = []
var fists: Array = []
var ofuda: Array = []
var tears: Array = []
var geysers: Array = []
var beams: Array = []
var claps: Array = []
var shades: Array = []
var hands: Array = []
var roots: Array = []
var waves: Array = []
var spikes: Array = []
var stepq: Array = []
var pagodas: Array = []
var slams: Array = []
var remains: Array = []
var marks: Array = []
var rings: Array = []
var motes: Array = []
var words: Array = []
var sky_flash := {}
var seals: Array = []        # The Burning Sutra: burning seals where talismans burst {tp, t, dps, tick}
var shell_t := 0.0           # The Thousand-Armed reversed: the arms close round him
var still_t := 0.0           # how long he has stood still (The Unmoving Door)
var last_tp := Vector2.INF
var sky_bonus := 0.0         # The Black-Flame Lantern: seconds kills have added to the held sky
var clap2 := {}              # The Unstruck Bell: the answering ring

# per creature: faults, stone, silence, shadow
var faults := {}

# ================================================================== levels, perks, the sky, the glass
## the Empty Hand's own test args (the shared ones are read in skill_book.gd)
func _arg(k: String, v: String) -> void:
	match k:
		"monktrace":
			trace = true
		"sand":   # tests: --sand=0.6,0.3 fills the bulbs (they run back as usual)
			var fv := v.split(",")
			set_meta("sand_test", [float(fv[0]), float(fv[1]) if fv.size() > 1 else 0.0])


func tab(id: String) -> int:
	return int(data.get(id, {}).get("tab", 2))

## the sky: 1 at noon, 0 at night, -1 underground (neutral) unless he has turned it
func sky_k() -> float:
	if Game.sky_force != "":
		return 1.0 if Game.sky_force == "noon" else 0.0
	if zone and zone.d.get("outdoor", false):
		return Game.day_k()
	return -1.0

func sky(t: int) -> float:
	var k := sky_k()
	if k < 0.0 or t == 2:
		return 1.0
	return 0.75 + 0.6 * k if t == 0 else 0.75 + 0.6 * (1.0 - k)

func area() -> float:
	var k := sky_k()
	return 1.0 if k < 0.0 else 0.88 + 0.24 * k        # Radiance: bigger by day

func dur() -> float:
	var k := sky_k()
	return 1.0 if k < 0.0 else 0.85 + 0.35 * (1.0 - k)  # Absence: longer by night

func bulb() -> float:
	return maxf(1.0, hero.st.res_max() / 2.0)

func frac(t: int) -> float:
	return clampf((kA if t == 1 else kR) / bulb(), 0.0, 1.0)

func sand(t: int) -> float:
	if t != 0 and t != 1:
		return 1.0
	return 1.0 - 0.9 * pow(frac(t), 2.5)

func power(id: String) -> float:
	var t := tab(id)
	return hero.st.skill_mult() * sky(t) * sand(t) * syn(id)

## a skill's damage: base and per level, the sky, the glass, synergies, the quarter cut
func D(id: String, b: float, per: float) -> float:
	return (b + per * (L1(id) - 1.0)) * power(id) * TUNE

func _fist_weapon() -> bool:
	var w: Item = hero.st.inv.weapon() if hero.st.inv else null
	return w == null or w.base in ["wraps", "iwraps"]

## bare or wrapped fists grow with him
func fist_add() -> Vector2:
	if hero == null or not _fist_weapon():
		return Vector2.ZERO
	var L: int = hero.st.level
	return Vector2(1.0 + L * 0.5, 2.0 + L * 0.8)

func fist() -> float:
	var w: Item = hero.st.inv.weapon() if hero.st.inv else null
	var fa := fist_add()
	var avg := ((w.dmg.x + w.dmg.y) if w else 4.0) / 2.0 + (fa.x + fa.y) / 2.0
	return avg * hero.st.melee_mult() * (1.45 + 0.03 * L1("kobsid") if obsid > 0.0 else 1.0)

func dr() -> float:
	return minf(0.45, 0.15 + 0.015 * L1("kbar")) if K("kbar") > 0 else 0.0

func sync_res() -> void:
	hero.st.res = maxf(0.0, 2.0 * bulb() - kR - kA)
	last_res = hero.st.res

func pour(t: int, amt: float) -> void:
	var h := bulb()
	var a := minf(CAP, POUR * amt / NORM) * h
	if t == 1:
		kA = minf(h, kA + a)
	else:
		kR = minf(h, kR + a)
	pour_tab = t
	pour_t = time
	sync_res()

func run_back(k: float, t: int = 2) -> void:
	var a := k * bulb()
	if t == 0:
		kA = maxf(0.0, kA - a)
	elif t == 1:
		kR = maxf(0.0, kR - a)
	else:
		kR = maxf(0.0, kR - a)
		kA = maxf(0.0, kA - a)
	sync_res()

## what a skill costs: Radiance and Absence pour sand, Destroyer spends poise
func pay(id: String, mult: float = 1.0) -> void:
	var need := cost(id) * mult
	var t := tab(id)
	if t == 2:
		hero.spend_poise(maxf(1.0, roundf(need * (1.2 if id == "kthousand" else 0.6))))
	else:
		pour(t, need * (3.0 if id in ["kdawn", "keclipse"] else 1.0))
	cast_t = time

## the tooltip line (data/skills.json level texts are the web's; this is the live one)
func info(id: String) -> String:
	var r := func(v): return str(int(round(v)))
	var skt := (" · sky x%.2f" % sky(tab(id))) if tab(id) < 2 else ""
	match id:
		"kdawn", "keclipse": return "%d s · turning the sky pours three times the sand" % int(sky_len(id))
		"kamber": return "%s/s within %.1f yd · eats 1%% life a second%s" % [r.call(D("kamber", 6.5, 3)), amber_r(), skt]
		"khands": return "100 palms · %s in all%s" % [r.call(fist() * (0.07 + 0.008 * L1("khands")) * sky(0) * sand(0) * syn("khands") * 100.0), skt]
		"klaugh": return "%s within %.1f yd every %.1f s%s" % [r.call(D("klaugh", 5.6, 2.8)), laugh_r(), laugh_every(), skt]
		"kstar": return "%s in a %.1f yd cone · x1.5 on the raised dead%s" % [r.call(D("kstar", 12, 5.5)), 4.6 * area(), skt]
		"kfist": return "%s to the one beneath · ring %s%s" % [r.call(D("kfist", 42, 18)), r.call(D("kfist", 42, 18) * 0.35), skt]
		"ksutra": return "%d talismans · %s each · one regrows every 1.4 s%s" % [halo_max(), r.call(D("ksutra", 9, 4)), skt]
		"ktears": return "%d tears · geysers %s · lie 15 s%s" % [tears_n(), r.call(D("ktears", 16, 7)), skt]
		"keye": return "%s/s along 7.5 yd, through walls%s" % [r.call(D("keye", 24, 9)), skt]
		"kbell": return "%.1f s · waves %s · blows on the bell lose 70%%%s" % [5.0 + 0.15 * L1("kbell"), r.call(D("kbell", 10, 4.5)), skt]
		"klotus": return "%s/s at full size · grows to %.1f yd%s" % [r.call(D("klotus", 14, 6)), 3.6 * area(), skt]
		"ksun": return "%d s · beams %s at %d enemies%s" % [sun_len(), r.call(D("ksun", 20, 7)), sun_n(), skt]
		"kpalm": return "Drags within %d yd · %s/s%s" % [palm_r(), r.call(D("kpalm", 3.5, 1.7) * 5.0), skt]
		"kclap": return "%s · stuns %.1f s within %.1f yd%s" % [r.call(D("kclap", 6, 2.6)), clap_stun(), clap_r(), skt]
		"kbowl": return "%d%% of frontal missiles swallowed · full at 6 · holds %d" % [int(bowl_chance() * 100.0), bowl]
		"kspade": return "%s in an arc · shadowless: rooted %.1f s, %s/s%s" % [r.call(spade_dmg()), 2.5 * dur(), r.call(D("kspade", 7, 3)), skt]
		"kpinch": return "Lesser raised dead collapse · the living: silenced 3 s, %s damage%s" % [r.call(D("kpinch", 14, 6)), skt]
		"kbelow": return "Holds %.1f s · crushes %s/s%s" % [3.0 * dur(), r.call(D("kbelow", 12, 5)), skt]
		"kspit": return "Roots %.1f yd · %s/s for %.1f s · a fifth comes back as life%s" % [spit_r(), r.call(D("kspit", 7, 3.2)), 3.0 * dur(), skt]
		"kwalk": return "Waves %s every 1.2 s within 2.8 yd%s" % [r.call(D("kwalk", 7, 3.2)), skt]
		"kmirror": return "%.1f s · blows come back x%d%s" % [3.0 + 0.1 * L1("kmirror"), 3 if K("kmirror2") > 0 else 2, skt]
		"knothing": return "8 s unseen · each mark collapses for %s%s" % [r.call(D("knothing", 34, 13)), skt]
		"kbar": return "%d%% less from blows · holds doorways" % int(dr() * 100.0)
		"kgrip": return "Stone 4 s · the shattering blow +%s" % r.call(D("kgrip", 26, 11))
		"kfinger": return "%s through any armour · x2.5 on stone" % r.call(fist() * (1.7 + 0.16 * L1("kfinger")) * syn("kfinger"))
		"kobsid": return "%d s · fists x%.2f · %d faults shatter" % [int(10.0 + 0.5 * L1("kobsid")), 1.45 + 0.03 * L1("kobsid"), fault_n()]
		"kmount": return "Leap 5 yd · %s in %.1f yd" % [r.call(D("kmount", 20, 8) * 1.25), 2.3]
		"kstep": return "%s per spear · 6.5 yd · x2 on flagstones" % r.call(D("kstep", 15, 6.5))
		"kpagoda": return "%s when it falls" % r.call(D("kpagoda", 34, 13))
		"kweep":
			var b := buddha_stats()
			return "Life %d · slams %s · draws enemies within 5 yd" % [int(b["max"]), r.call(b["dmg"])]
		"kthousand": return "%d waves · %s each in a 5.5 yd cone · halves armour" % [18 if K("kthous2") > 0 else 12, r.call(D("kthousand", 9, 3.5))]
	return ""

func sky_len(id: String) -> float:
	var outdoor: bool = zone != null and zone.d.get("outdoor", false)
	return (20.0 + (8.0 if K("kdawn2" if id == "kdawn" else "kecl2") > 0 else 0.0)) * (1.0 if outdoor else 0.5)
func amber_r() -> float: return (2.1 + (1.0 if K("kamberw") > 0 else 0.0)) * area()
func laugh_r() -> float: return 3.2 * area() * (1.25 if K("klaughw") > 0 else 1.0) * (1.2 if aM("kr_belly") else 1.0)
func laugh_every() -> float: return maxf(2.0, 3.8 - 0.05 * L1("klaugh"))
func halo_max() -> int: return 3 + K("ksutra") / 4 + (2 if K("ksmore") > 0 else 0)
func tears_n() -> int: return 5 + K("ktears") / 5 + (3 if K("ktmore") > 0 else 0) + (2 if aM("kr_tears") else 0)
func sun_len() -> int: return 10 + (4 if K("ksunlong") > 0 else 0)
func sun_n() -> int: return 3 + int(L1("ksun") / 6.0) + (1 if K("ksunlong") > 0 else 0)
func palm_r() -> int: return 10 if K("kpalmw") > 0 else 7
func clap_r() -> float: return 3.4 + (1.5 if K("kclapw") > 0 else 0.0)
func clap_stun() -> float: return 0.7 * dur() * (2.0 if K("kclapw") > 0 else 1.0)
func bowl_chance() -> float: return minf(0.85, 0.3 + 0.025 * L1("kbowl"))
func spade_dmg() -> float: return fist() * (1.1 + 0.08 * L1("kspade")) * sky(1) * syn("kspade")
func spit_r() -> float: return 2.2 * (1.5 if K("kspitw") > 0 else 1.0)
func fault_n() -> int: return 4 if K("kobsid2") > 0 else 5
func buddha_stats() -> Dictionary:
	var l := L1("kweep")
	return {"max": roundf((90.0 + 40.0 * l + hero.st.level * 6) * (1.5 if K("kweep3") > 0 else 1.0)), "dmg": (10.0 + 6.0 * l) * hero.st.skill_mult()}

# ================================================================== creatures

func raised(m) -> bool:
	if m.kind in RAISED:
		return true
	var n: String = str(m.name_shown).to_lower()
	for w in ["husk", "ossuary", "weeper", "bone", "marrow"]:
		if n.contains(w):
			return true
	return false

func stun(m, t: float) -> void:
	if m == null or m.dead:
		return
	m.stun = maxf(m.stun, t * 0.3 if m.boss else t)

func root(m, t: float) -> void:
	if m == null or m.dead:
		return
	m.root = maxf(m.root, minf(0.6, t) if m.boss else t)

func shove(m, from: Vector2, d: float) -> void:
	if m == null or m.dead or m.boss:
		return
	var v: Vector2 = (m.tp - from).normalized() * d
	for i in 4:
		m.tp = zone.move(m.tp, v / 4.0, m.radius * 0.6)

func burn(m, dps: float, secs: float) -> void:
	if m and not m.dead:
		m.add_dot(dps, secs, "radiance")

func is_stone(m) -> bool:
	return float(m.get_meta("k_stone", -1.0)) > now()

## a blow from his side. Weeping stone shatters under the next blow that is not the grip's own.
func hurt(m, dmg: float, id: String, o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead or m.buried or dmg <= 0.0:
		return 0.0
	var d := dmg
	var elem: String = ELEM.get(id, "radiance" if tab(id) == 0 else ("void" if tab(id) == 1 else "phys"))
	if o.has("elem"):
		elem = o["elem"]
	if m.kind == "pyre" and tab(id) == 0:
		d *= 0.5   # the Pyre-Saint is a burning martyr too
	if aM("kh_unraised") and raised(m):
		d *= 1.2
	var was := src
	src = id
	if is_stone(m) and id != "kgrip":
		m.set_meta("k_stone", -1.0)
		m.stun = minf(m.stun, 0.05)
		m.root = 0.0
		src = "rubble"
		d += D("kgrip", 26, 11)
		dust(m.tp, Color(0.55, 0.53, 0.49), 16)
		say_at(m.tp, "shattered")
		Sfx.play("break", 0.9, 0.8)
		Game.shake(3.0)
	var opts := {}
	if o.has("poise"):
		opts["poise"] = o["poise"]
	if o.get("heavy", false):
		opts["heavy"] = true
	if o.get("melee", false):
		opts["melee"] = true
	var dealt: float = Combat.hit_monster(m, d, elem, o.get("from", hero.tp), opts)
	src = was
	if trace:
		dmg_log[id] = float(dmg_log.get(id, 0.0)) + dealt
	if dealt > 0.0:
		if not m.dead and time - hit_t > 0.25:
			hit_t = time
			run_back(0.003)
	return dealt

## Mantra-Of-Obsidian: a punch leaves a fault; at five it shatters
func fault(m) -> void:
	if m == null or m.dead or obsid <= 0.0:
		return
	var k: int = m.get_instance_id()
	faults[k] = int(faults.get(k, 0)) + 1
	say_at(m.tp, "fault %d" % faults[k])
	if faults[k] >= fault_n():
		faults[k] = 0
		dust(m.tp, Color(0.11, 0.09, 0.15), 18)
		ring(m.tp, 1.4, 0.35, Color(0.54, 0.53, 0.63))
		Sfx.play("break", 0.8, 0.7)
		hurt(m, fist() * 3.0 + D("kobsid", 20, 8), "rubble")
		Game.shake(3.0)

# ================================================================== little things to draw
func ring(p: Vector2, R: float, secs: float, col: Color, r0: float = 0.2) -> void:
	rings.append({"tp": p, "R": R, "R0": r0, "t": secs, "max": secs, "col": col})

func dust(p: Vector2, col: Color, n: int, spd: float = 2.0) -> void:
	for i in mini(n, 24):
		var a := randf() * TAU
		var v := spd * randf_range(0.3, 1.1)
		motes.append({"tp": p, "z": randf_range(2.0, 14.0), "v": Vector2(cos(a), sin(a)) * v, "vz": randf_range(8.0, 30.0), "t": randf_range(0.4, 0.9), "col": col})
	if motes.size() > 500:
		motes = motes.slice(motes.size() - 500)

func say_at(p: Vector2, t: String, col: Color = Color(0.86, 0.83, 0.76)) -> void:
	words.append({"tp": p, "s": t, "t": 1.0, "col": col})
	if words.size() > 24:
		words.pop_front()

func banner(t: String, col: Color) -> void:
	var ui = hero.get_tree().root.find_child("GodmarrowWorldUI", true, false)
	if ui and ui.has_method("banner"):
		ui.banner(t, col, 2.0)

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

func ground_key(t: Vector2) -> String:
	var x := int(floor(t.x))
	var y := int(floor(t.y))
	if zone.ground_cls == null or x < 0 or y < 0 or x >= zone.w or y >= zone.h:
		return ""
	return str(zone.ground_keys.get(str(zone.ground_cls[y * zone.w + x]), "main"))

## lit: by an open day, in his lantern, or near a flame
func lit(m) -> bool:
	if m.kind == "pyre":
		return true
	if zone.d.get("outdoor", false) and Game.day_k() > 0.5:
		return true
	if m.tp.distance_to(hero.tp) < hero.light_radius() * 0.8:
		return true
	for L in zone.d.get("lights", []):
		if L is Dictionary and Vector2(float(L.get("x", -99)), float(L.get("y", -99))).distance_to(m.tp) < 3.0:
			return true
	return false


func held(id: String) -> bool:
	if hold_id == id or auto_hold == id:
		return true
	if hero == null or hero.dead:
		return false
	if hero.skills.right == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return true
	if hero.skills.left == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return false


func _after(id: String, at: Vector2) -> void:
	cast_anim = POSE.get(id, "cast")
	var t := tab(id)
	Sfx.play(["cast_soul", "cast_thread", "heavy"][t], 0.7, [1.25, 0.7, 0.8][t])
	if t == 0 and not id in ["kdawn", "kfist", "kbell"]:
		for i in 6:
			motes.append({"tp": hero.tp + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), "z": randf_range(20, 40), "v": Vector2.ZERO, "vz": randf_range(10, 30), "t": 0.6, "col": Color(1.0, 0.94, 0.63)})
	if hero:
		hero._face(at - hero.tp)

func _melee_target(at: Vector2, target, reach: float) -> Monster:
	var m: Monster = target if target != null and is_instance_valid(target) and not target.dead else near(at, 3.6)
	if m == null or m.tp.distance_to(hero.tp) > reach + m.radius + 0.3:
		return null
	return m
