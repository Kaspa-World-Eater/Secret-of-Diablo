class_name Affixes
extends RefCounted
## What marks a champion pack or a unique beyond its numbers: one "deed" each, shared by the whole pack (a pack is
## one kind of wrongness), a second for uniques from level 8. The old stat marks (Extra Strong, Extra Fast, Stone
## Skin) stay as they were in the data; they are only shown in the Stranger's words.
## Hooks: Monster.setup -> roll(); Monster._physics_process -> tick(); Monster.die -> on_death();
## Combat.hit_hero -> strike_poise() / on_strike(); Combat.hit_monster -> on_struck(); Hero.light_radius -> lantern_k().
## Test: --affix=Name forces a deed on every champion and unique that is made.
## The user's rules (2026-09-30): nothing a creature leaves on the ground when it dies may hurt (it is no fun if you do
## not see it), and no Diablo III / IV style marks (beams, orbiting fire, trails of burning ground): D2's kind only.
## Refined the same day: what the user means is Diablo IV's deaths to things you cannot see (lingering ground effects
## lost in the clutter, detonations after death, blows from off screen). Anything here that hurts must read plainly.
## Warded (D2's Magic Resistant) came in beside the rest.

const SHOWN := {"Extra Strong": "Heavy-Handed", "Extra Fast": "Quick", "Stone Skin": "Stone-Skinned"}
## deed -> what the Stranger would say of it (the Codex and tooltips may use these)
const DEEDS := {
	"Ash-Trailing": "Hot ash falls from it where it walks. Do not stand where it has been.",
	"Grave-Called": "When it falls, the ground under it gives up others.",
	"Thirsting": "Its blows drink what you draw on.",
	"Nail-Fisted": "Its blows break your footing, whatever you wear.",
	"Thorned": "Strike it close and some of the blow comes back.",
	"Candle-Eater": "Near it, your lantern shrinks, as if something breathed on it.",
	"Warded": "Workings slide off it. Steel does not.",
	"Bursting": "It does not lie still when it dies. Step away from the body.",
	"Unquiet": "It does not walk to you. It is simply nearer.",
}
const ORDER := ["Ash-Trailing", "Grave-Called", "Thirsting", "Nail-Fisted", "Thorned", "Candle-Eater", "Warded", "Bursting", "Unquiet"]
const WARD_ELEMS := ["magic", "miasma", "blood", "void", "radiance", "fire", "cold", "poison"]

static var trace := OS.get_cmdline_user_args().has("--afftrace")
static func say(s: String) -> void:
	if trace:
		print("AFF ", s)

static func shown(md: String) -> String:
	return String(SHOWN.get(md, md))

static func has(m, deed: String) -> bool:
	return m != null and is_instance_valid(m) and deed in m.mods

## at setup: the pack's deed (the same for every member, from the pack's name), and a second for grown uniques
static func roll(m) -> void:
	if m.boss or not (m.rank == "champion" or m.rank == "unique"):
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--affix="):
			var forced := a.substr(8)
			if not forced in m.mods:
				m.mods = m.mods + [forced]
			apply(m)
			return
	var h := absi(hash(str(m.pack) + ":" + str(m.level)))
	var d1: String = ORDER[h % ORDER.size()]
	var add := [d1]
	if m.rank == "unique" and m.level >= 8:
		var d2: String = ORDER[(h / 7 + 3) % ORDER.size()]
		if d2 != d1:
			add.append(d2)
	m.mods = m.mods + add
	m.set_meta("aff_t", randf() * 2.0)
	apply(m)

## the deeds that are only numbers, set once
static func apply(m) -> void:
	if "Warded" in m.mods:
		for e in WARD_ELEMS:
			m.resists[e] = float(m.resists.get(e, 0.0)) + 40.0

## every frame, for the few that carry a deed that acts on its own
static func tick(m, dt: float) -> void:
	if m.mods.is_empty() or not m.awake:
		return
	var h = m.hero()
	if "Ash-Trailing" in m.mods:
		var last: Vector2 = m.get_meta("ash_at", Vector2.INF)
		if last == Vector2.INF or last.distance_to(m.tp) > 0.7:
			m.set_meta("ash_at", m.tp)
			say("ash at %s" % str(m.tp))
			AffixFx.ash(m.zone, m.tp, (m.dmg.x + m.dmg.y) * 0.5 * 0.22, Combat.who(m))
	if "Unquiet" in m.mods and h and m.can_act():
		var t: float = float(m.get_meta("aff_t", 0.0)) - dt
		var d: float = m.tp.distance_to(h.tp)
		if t <= 0.0 and d > 4.5 and d < 14.0:
			t = randf_range(5.0, 7.0)
			say("slip from %.1f" % d)
			AffixFx.slip(m, h)
		m.set_meta("aff_t", t)

static func on_death(m) -> void:
	say("death %s %s" % [m.name_shown, str(m.mods)])
	if "Grave-Called" in m.mods:
		AffixFx.graves(m, 2 if m.rank == "unique" else 1)
	if "Bursting" in m.mods:
		AffixFx.burst(m)

## a creature's blow lands on the hero: how much harder it breaks the hero's footing
static func strike_poise(by) -> float:
	if has(by, "Nail-Fisted"):
		say("nail")
		return 2.2
	return 1.0

## after a creature's blow has landed
static func on_strike(by, h, d: float) -> void:
	if has(by, "Thirsting") and d > 0.0 and h.st:
		if h.cls == "monk" and h.skills and h.skills.has_method("pour"):
			h.skills.pour(0, 4.0)   # the Empty Hand's pool is the room left in his glass: it fills it instead
			h.skills.pour(1, 4.0)
		else:
			h.st.res = maxf(0.0, h.st.res - h.st.res_max() * 0.07)
		say("thirst res %.0f" % h.st.res)

## the hero struck a creature: what comes back
static var _in_thorns := false
static func on_struck(m, d: float, opts: Dictionary) -> void:
	if _in_thorns or d <= 0.0 or opts.get("dot", false) or not opts.get("melee", false) or not ("Thorned" in m.mods):
		return
	var h = m.hero()
	if h and h.st:
		say("thorns %.1f" % minf(d * 0.08, h.st.life_max() * 0.04))
		_in_thorns = true   # what comes back cannot itself be answered (a counter-blow striking it again)
		Combat.hit_hero(h, minf(d * 0.08, h.st.life_max() * 0.04), "phys", m.tp, {"poise": 0.0, "thorns": true})
		_in_thorns = false

## the lantern: a quarter less reach within 5 yards of a Candle-Eater (looked up a few times a second)
static func lantern_k(h) -> float:
	var now := Time.get_ticks_msec()
	if now < int(h.get_meta("cand_next", 0)):
		return float(h.get_meta("cand_k", 1.0))
	h.set_meta("cand_next", now + 250)
	var k := 1.0
	for m in h.get_tree().get_nodes_in_group("monsters"):
		if not m.dead and "Candle-Eater" in m.mods and m.tp.distance_to(h.tp) < 5.0:
			k = 0.75
			break
	var was: float = float(h.get_meta("cand_k", 1.0))
	h.set_meta("cand_k", lerpf(was, k, 0.5))
	return float(h.get_meta("cand_k", 1.0))
