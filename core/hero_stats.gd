class_name HeroStats
extends RefCounted
## The hero's numbers, as the web build derives them (checklist section 3; data/classes.json holds sampled tables).

var cls := "animancer"
var level := 1
var xp := 0
var vit := 15
var ess := 25
var con := 15
var attr_points := 0
var skill_points := 1
var gold := 40
var hp := 0.0
var res := 0.0
var poise := 0.0
var poise_delay := 0.0
var dim_wick := false
var inv: Inventory
var hollow_tokens := 1
var arcana_points := 0
var kept := 0            # what the lantern keeps (deaths, max 3)
var extra := {}          # stat bonuses from shrines, auras, arcana: key -> value
var fate := {}           # what the Reading (ui/reading.gd) made of this pilgrim: key -> value, for the whole walk
var fate_picks: Array = []
var arc = null           # core/arcana.gd: the body board (Minor knots laid, Major cards held)

## what the body board's knots add up to (zz_arcana_web.js sums): 0 for anything not laid
func W(k: String) -> float:
	return arc.sum(k) if arc != null else 0.0

## under an open sky by day (the sun knots) or not (the moon knots)
static func _lit() -> bool:
	var ml := Engine.get_main_loop() as SceneTree
	var m = ml.current_scene if ml else null
	if m and "zone" in m and m.zone:
		return bool(m.zone.d.get("outdoor", false)) and Game.hour_name() != "night"
	return true

## the Reading's words for the stats it touches, where they differ from the gear's (xp -> xpK, gold -> gf)
const FATE_KEY := {"xpK": "xp", "gf": "gold", "xp": "", "gold": ""}

func item(k: String) -> float:
	var v := (inv.total(k) if inv else 0.0) + float(extra.get(k, 0.0)) + float(fate.get(FATE_KEY.get(k, k), 0.0))
	if k == "mf" or k == "lok":
		v += W(k)   # the body board's magic find and life-on-kill knots
	return v

func e_vit() -> float:
	return vit + item("vit") + W("vit")

func e_ess() -> float:
	return ess + item("spi") + item("ene") + W("spi")

func e_con() -> float:
	return con + item("con") + item("dex") + W("con")

func resist(elem: String) -> float:
	var r := item("res_" + elem)
	if elem != "phys":
		r += item("res") * (1.0 if elem == "magic" else 0.5)
	if elem == "magic":
		r += W("res")
	return r

func setup(c: String) -> void:
	cls = c
	inv = Inventory.new()
	var kit: Dictionary = Data.table("classes").get("classes", {}).get(c, {}).get("starting_kit", {})
	inv.setup_kit(kit)
	arc = load("res://core/arcana.gd").new()
	arc.setup(self, c)
	skill_points = int(kit.get("skill_points", 1))
	hollow_tokens = int(kit.get("hollow_tokens", 1))
	hp = life_max()
	res = res_max()
	poise = poise_max()

func life_max() -> float:
	return roundf((28.0 + 3.0 * e_vit() + 3.0 * level + item("life")) * (1.0 + (W("life") + float(fate.get("hpPct", 0.0))) / 100.0) * (arc.life_k() if arc else 1.0))

func res_max() -> float:
	match cls:
		"hemomancer":
			return roundf((20.0 + 2.0 * e_ess() + 2.0 * level + item("mana")) * (1.0 + W("ess") / 100.0))
		"miasmancer":
			return roundf((30.0 + 1.2 * e_ess() + 1.5 * level + item("mana")) * (1.0 + W("ess") / 100.0))
		_:
			return roundf((8.0 + 2.0 * e_ess() + 1.5 * level + item("mana")) * (1.0 + W("ess") / 100.0))

func res_regen() -> float:
	return _res_regen0() * (1.0 + (W("regen") + float(fate.get("regen", 0.0))) / 100.0)

func _res_regen0() -> float:
	match cls:
		"animancer":
			# v103 balance: twice the web's refill, so the Mystic casts more than once a minute (--nobal: the web's)
			return (0.6 + 0.03 * e_ess()) * (1.0 if OS.get_cmdline_user_args().has("--nobal") else 2.0)
		"ossumancer":
			return 1.2 + 0.04 * e_ess()
		"hemomancer":
			return 0.5 + 0.012 * e_ess()
		"miasmancer":
			return (1.5 + 0.03 * e_ess()) * 0.5
		"monk":
			return 0.0
	return 1.0

func res_name() -> String:
	return {"animancer": "Essence", "ossumancer": "Marrow", "hemomancer": "Vitae", "miasmancer": "Miasma", "monk": "Sand"}.get(cls, "Essence")

func armor() -> float:
	return e_con() / 2.0 + (inv.armor() if inv else 0.0) + item("armor") + W("armor") + empty_robe()

## the Empty Hand's bearing: blows find less of him than they aim at (10 + 1.5 armour a level), whatever he wears, so
## he can still take what gear gives. (G1 balance: he fights close with half the Mystic's armour. At first this held
## only while nothing covered his body; the user: that would cost him the gear's own gifts.)
func empty_robe() -> float:
	if cls != "monk":
		return 0.0
	return 10.0 + 1.5 * level

func poise_max() -> float:
	return roundf(28.0 + 1.4 * e_con() + 0.08 * e_vit() + 0.25 * (inv.armor() if inv else 0.0) + W("poise") + float(fate.get("stam", 0.0)))

func poise_regen() -> float:
	return (4.0 + 0.35 * e_con()) * (1.0 + W("prec") / 100.0)

func skill_mult() -> float:
	var web := W("dmg") + (W("sun") if _lit() else 0.0)
	return (1.0 + 0.012 * e_ess() + item("dmg") / 100.0) * (1.0 + web / 100.0) * (1.5 if item("echo") > 0.0 else 1.0) * fate_hour()

func melee_mult() -> float:
	var web := W("melee") + (W("moon") if not _lit() else 0.0)
	return (1.0 + 0.015 * e_con()) * (1.0 + web / 100.0) * (1.0 + float(fate.get("dmg", 0.0)) / 100.0) * fate_hour()

## the Reading's damage by the hour: in the dark (night, or under the ground) or under an open sky
func fate_hour() -> float:
	var k := float(fate.get("dmg_day", 0.0)) if _lit() and _open_sky() else float(fate.get("dmg_night", 0.0)) if not _lit() else 0.0
	return 1.0 + k / 100.0

static func _open_sky() -> bool:
	var ml := Engine.get_main_loop() as SceneTree
	var m = ml.current_scene if ml else null
	return m != null and "zone" in m and m.zone != null and bool(m.zone.d.get("outdoor", false))

func cast_speed() -> float:
	# Essence quickens casting a little: 40 Essence = +6% (zz_polish.js:74)
	return 0.72 * (1.0 + (item("fcr") + W("fcr")) / 100.0) * (1.0 + e_ess() * 0.0015)

func move_speed() -> float:
	var f := item("frw") + W("frw")
	if f > 25.0:
		f = 25.0 + (f - 25.0) * 0.6
	f = minf(f, 40.0)
	return 4.15 * (1.0 + f / 100.0) * 0.75

func xp_to_next(L: int = -1) -> int:
	var l := float(level if L < 0 else L)
	var v := 60.0 * pow(l, 1.9) + 40.0 * l
	if l > 30.0:
		v *= 1.0 + pow((l - 30.0) / 25.0, 2.0)
	if l > 85.0:
		v *= 1.0 + 0.35 * (l - 85.0)
	return int(floor(v))

func add_xp(n: int) -> bool:
	xp += n
	var up := false
	while xp >= xp_to_next() and level < 99:
		xp -= xp_to_next()
		level += 1
		attr_points += 5
		skill_points += 1   # (the Minor Arcana point for the level comes from core/arcana.gd earned())
		hp = life_max()
		res = res_max()
		up = true
	return up

var heal_pool := 0.0
var restore_pool := 0.0

func attack_speed() -> float:
	return 1.0 + (e_con() - 15.0) * 0.0015 + 0.0225

func tick(dt: float) -> void:
	res = minf(res_max(), res + res_regen() * dt)
	if heal_pool > 0.0:
		var a := minf(heal_pool, life_max() * 0.3 * dt)
		heal_pool -= a
		hp = minf(life_max(), hp + a)
	if restore_pool > 0.0:
		var b := minf(restore_pool, res_max() * 0.4 * dt)
		restore_pool -= b
		res = minf(res_max(), res + b)
	var lamber := item("lamber")
	if lamber > 0.0:
		hp = minf(life_max(), hp + lamber * dt)
	# Vitality mends: 40 Vitality = +0.4 life a second (zz_polish.js:76)
	hp = minf(life_max(), hp + e_vit() * 0.01 * dt)
	if poise_delay > 0.0:
		poise_delay -= dt
	else:
		poise = minf(poise_max(), poise + poise_regen() * dt)

static func lamp_color(c: String) -> Color:
	match c:
		"animancer":
			return Color8(150, 196, 255)
		"ossumancer":
			return Color8(236, 228, 210)
		"hemomancer":
			return Color8(255, 238, 214)
		"miasmancer":
			return Color8(200, 150, 255)
		"monk":
			return Color8(170, 160, 150)
	return Color8(255, 210, 160)


## the Hollow Token also returns the body board: every knot and every card
func respec_arcana() -> void:
	if arc != null:
		arc.respec()
