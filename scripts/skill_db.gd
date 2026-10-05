extends Node
## Necromancer skill data and formulas, modelled on Diablo 2.
## All numbers live here so balance can be tuned without touching gameplay code.

const TREES := ["Summoning", "Poison & Bone", "Curses"]
const TREE_COLORS := [Color(0.32, 0.55, 0.3), Color(0.72, 0.68, 0.5), Color(0.55, 0.28, 0.62)]
const MAX_LEVEL := 20

# tree: -1 = not in a tree. row 0..5 maps to required level 1/6/12/18/24/30.
const SKILLS := {
	"attack": {"name": "Attack", "tree": -1, "row": 0, "col": 0, "pre": [], "passive": false, "melee": true, "mana": [0, 0], "icon": "At",
		"desc": "Strike with your wand."},

	# --- Summoning ---
	"skeleton_mastery": {"name": "Skeleton Mastery", "tree": 0, "row": 0, "col": 0, "pre": [], "passive": true, "mana": [0, 0], "icon": "SM",
		"desc": "Passive: raised skeletons and skeletal mages gain life and damage."},
	"raise_skeleton": {"name": "Raise Skeleton", "tree": 0, "row": 0, "col": 2, "pre": [], "passive": false, "mana": [6, 1], "icon": "RS",
		"desc": "Raise a skeleton warrior from a corpse."},
	"clay_golem": {"name": "Clay Golem", "tree": 0, "row": 1, "col": 1, "pre": [], "passive": false, "mana": [15, 3], "icon": "CG",
		"desc": "Create a golem of earth that slows the enemies it strikes."},
	"golem_mastery": {"name": "Golem Mastery", "tree": 0, "row": 2, "col": 0, "pre": ["clay_golem"], "passive": true, "mana": [0, 0], "icon": "GM",
		"desc": "Passive: golems gain life and speed."},
	"raise_skeletal_mage": {"name": "Raise Skeletal Mage", "tree": 0, "row": 2, "col": 2, "pre": ["raise_skeleton"], "passive": false, "mana": [8, 1], "icon": "Ma",
		"desc": "Raise an elemental skeletal mage from a corpse."},
	"blood_golem": {"name": "Blood Golem", "tree": 0, "row": 3, "col": 1, "pre": ["clay_golem"], "passive": false, "mana": [25, 4], "icon": "BG",
		"desc": "Create a golem whose blows heal it and you."},
	"summon_resist": {"name": "Summon Resist", "tree": 0, "row": 4, "col": 0, "pre": ["raise_skeletal_mage"], "passive": true, "mana": [0, 0], "icon": "SR",
		"desc": "Passive: all summons gain elemental resistances."},
	"iron_golem": {"name": "Iron Golem", "tree": 0, "row": 4, "col": 1, "pre": ["blood_golem"], "passive": false, "mana": [35, 0], "icon": "IG",
		"desc": "Create a golem of iron with Thorns: melee attackers take damage back."},
	"fire_golem": {"name": "Fire Golem", "tree": 0, "row": 5, "col": 1, "pre": ["iron_golem"], "passive": false, "mana": [50, 4], "icon": "FG",
		"desc": "Create a golem of flame with a burning Holy Fire aura."},
	"revive": {"name": "Revive", "tree": 0, "row": 5, "col": 2, "pre": ["summon_resist", "iron_golem"], "passive": false, "mana": [45, 0], "icon": "Rv",
		"desc": "Return a monster from its corpse to fight for you for a time."},

	# --- Poison & Bone ---
	"teeth": {"name": "Teeth", "tree": 1, "row": 0, "col": 1, "pre": [], "passive": false, "mana": [3, 0.5], "icon": "Te",
		"desc": "Fire a fan of magic bone teeth."},
	"bone_armor": {"name": "Bone Armor", "tree": 1, "row": 0, "col": 2, "pre": [], "passive": false, "self": true, "mana": [11, 1], "icon": "BA",
		"desc": "A shield of bone that absorbs physical damage."},
	"poison_dagger": {"name": "Poison Dagger", "tree": 1, "row": 1, "col": 0, "pre": [], "passive": false, "melee": true, "mana": [3, 0.25], "icon": "PD",
		"desc": "A melee strike that poisons the target."},
	"corpse_explosion": {"name": "Corpse Explosion", "tree": 1, "row": 1, "col": 1, "pre": ["teeth"], "passive": false, "mana": [15, 1], "icon": "CE",
		"desc": "Detonate a corpse, dealing 60-100% of its life as fire and physical damage."},
	"bone_wall": {"name": "Bone Wall", "tree": 1, "row": 2, "col": 2, "pre": ["bone_armor"], "passive": false, "mana": [17, 0], "icon": "BW",
		"desc": "Raise an impassable wall of bone."},
	"poison_explosion": {"name": "Poison Explosion", "tree": 1, "row": 3, "col": 0, "pre": ["poison_dagger", "corpse_explosion"], "passive": false, "mana": [8, 1], "icon": "PE",
		"desc": "Burst a corpse into a cloud of poison."},
	"bone_spear": {"name": "Bone Spear", "tree": 1, "row": 3, "col": 1, "pre": ["corpse_explosion"], "passive": false, "mana": [7, 0.25], "icon": "BS",
		"desc": "A piercing spear of bone that deals magic damage."},
	"bone_prison": {"name": "Bone Prison", "tree": 1, "row": 4, "col": 2, "pre": ["bone_spear", "bone_wall"], "passive": false, "mana": [27, -1], "icon": "BP",
		"desc": "Trap a monster inside a ring of bone."},
	"poison_nova": {"name": "Poison Nova", "tree": 1, "row": 5, "col": 0, "pre": ["poison_explosion"], "passive": false, "self": true, "mana": [20, 2], "icon": "PN",
		"desc": "An expanding ring of poison around you."},
	"bone_spirit": {"name": "Bone Spirit", "tree": 1, "row": 5, "col": 1, "pre": ["bone_spear"], "passive": false, "mana": [12, 0.5], "icon": "Sp",
		"desc": "A spirit that hunts down its target and deals magic damage."},

	# --- Curses ---
	"amplify_damage": {"name": "Amplify Damage", "tree": 2, "row": 0, "col": 1, "pre": [], "passive": false, "mana": [4, 1], "icon": "AD",
		"desc": "Cursed monsters take double physical damage."},
	"dim_vision": {"name": "Dim Vision", "tree": 2, "row": 1, "col": 0, "pre": ["amplify_damage"], "passive": false, "mana": [9, 0], "icon": "DV",
		"desc": "Cursed monsters can barely see."},
	"weaken": {"name": "Weaken", "tree": 2, "row": 1, "col": 2, "pre": ["amplify_damage"], "passive": false, "mana": [4, 0.5], "icon": "We",
		"desc": "Cursed monsters deal 33% less damage."},
	"iron_maiden": {"name": "Iron Maiden", "tree": 2, "row": 2, "col": 1, "pre": ["amplify_damage"], "passive": false, "mana": [5, 0.5], "icon": "IM",
		"desc": "Cursed monsters take their own melee damage back."},
	"terror": {"name": "Terror", "tree": 2, "row": 2, "col": 2, "pre": ["weaken"], "passive": false, "mana": [7, 0], "icon": "Tr",
		"desc": "Cursed monsters flee in fear."},
	"confuse": {"name": "Confuse", "tree": 2, "row": 3, "col": 0, "pre": ["dim_vision"], "passive": false, "mana": [13, 0], "icon": "Cf",
		"desc": "Cursed monsters attack anything nearby, including each other."},
	"life_tap": {"name": "Life Tap", "tree": 2, "row": 3, "col": 1, "pre": ["iron_maiden"], "passive": false, "mana": [9, 0], "icon": "LT",
		"desc": "Attacks on cursed monsters heal the attacker for 50% of damage."},
	"attract": {"name": "Attract", "tree": 2, "row": 4, "col": 0, "pre": ["confuse"], "passive": false, "mana": [17, 0], "icon": "At",
		"desc": "Other monsters turn on the cursed target."},
	"decrepify": {"name": "Decrepify", "tree": 2, "row": 4, "col": 2, "pre": ["terror"], "passive": false, "mana": [11, 0], "icon": "De",
		"desc": "Cursed monsters are slowed, weakened and take more physical damage."},
	"lower_resist": {"name": "Lower Resist", "tree": 2, "row": 5, "col": 1, "pre": ["life_tap", "decrepify"], "passive": false, "mana": [11, 0], "icon": "LR",
		"desc": "Lowers the elemental and poison resistances of cursed monsters."},
}

const CURSE_COLORS := {
	"amplify_damage": Color(1.0, 0.35, 0.2), "dim_vision": Color(0.3, 0.3, 0.45), "weaken": Color(0.7, 0.7, 0.3),
	"iron_maiden": Color(0.75, 0.75, 0.8), "terror": Color(0.9, 0.9, 1.0), "confuse": Color(0.9, 0.4, 0.9),
	"life_tap": Color(0.9, 0.1, 0.2), "attract": Color(0.3, 0.9, 0.9), "decrepify": Color(0.5, 0.35, 0.2),
	"lower_resist": Color(0.6, 0.2, 0.9),
}


func is_melee(id: String) -> bool:
	return SKILLS[id].get("melee", false)


func is_curse(id: String) -> bool:
	return SKILLS[id]["tree"] == 2


func req_level(id: String) -> int:
	var r: int = SKILLS[id]["row"]
	return 1 if r == 0 else r * 6


func mana_cost(id: String, lvl: int) -> float:
	var m: Array = SKILLS[id]["mana"]
	if m[0] == 0 and m[1] == 0:
		return 0.0
	return max(1.0, m[0] + m[1] * (lvl - 1))


func tree_skills(tree: int) -> Array:
	var out := []
	for id in SKILLS:
		if SKILLS[id]["tree"] == tree:
			out.append(id)
	return out


func can_learn(p, id: String) -> String:
	## Returns "" when the skill can be learned, otherwise the reason it cannot.
	if p.skill_points <= 0:
		return "No skill points"
	if p.skill_level(id) >= MAX_LEVEL:
		return "Maximum level"
	if p.level < req_level(id):
		return "Requires level %d" % req_level(id)
	for pre in SKILLS[id]["pre"]:
		if p.skill_level(pre) <= 0:
			return "Requires %s" % SKILLS[pre]["name"]
	return ""


func syn(p, ids: Array, pct: float) -> float:
	var total := 0
	for id in ids:
		total += p.skill_level(id)
	return 1.0 + total * pct


# ---------------------------------------------------------------- Poison & Bone

func teeth_count(l: int) -> int:
	return min(24, l + 1)


func teeth_dmg(l: int, p) -> Vector2:
	var s := syn(p, ["bone_armor", "bone_wall", "bone_prison", "bone_spear", "bone_spirit", "corpse_explosion"], 0.15)
	return Vector2(2 + 2 * (l - 1), 4 + 2 * (l - 1)) * s


func bone_spear_dmg(l: int, p) -> Vector2:
	var s := syn(p, ["teeth", "bone_wall", "bone_prison", "bone_spirit"], 0.08)
	return Vector2(16 + 8 * (l - 1), 24 + 8 * (l - 1)) * s


func bone_spirit_dmg(l: int, p) -> Vector2:
	var s := syn(p, ["teeth", "bone_wall", "bone_prison", "bone_spear"], 0.06)
	return Vector2(20 + 14 * (l - 1), 30 + 14 * (l - 1)) * s


func bone_armor_absorb(l: int, p) -> float:
	return 20.0 + 10.0 * (l - 1) + 15.0 * (p.skill_level("bone_wall") + p.skill_level("bone_prison"))


func bone_wall_len(l: int) -> int:
	return 5 + int(l / 4)


func ce_radius(l: int) -> float:
	return 70.0 + 8.0 * l


func poison_dagger_poison(l: int, p) -> float:
	return (12.0 + 10.0 * (l - 1)) * syn(p, ["poison_explosion", "poison_nova"], 0.2)


func poison_explosion_poison(l: int, p) -> float:
	return (40.0 + 18.0 * (l - 1)) * syn(p, ["poison_dagger", "poison_nova"], 0.1)


func poison_explosion_radius(l: int) -> float:
	return 80.0 + 4.0 * l


func poison_nova_poison(l: int, p) -> float:
	return (50.0 + 22.0 * (l - 1)) * syn(p, ["poison_dagger", "poison_explosion"], 0.1)


# ---------------------------------------------------------------- Curses

func curse_radius(id: String, l: int) -> float:
	match id:
		"attract": return 40.0
		"amplify_damage", "lower_resist", "dim_vision": return 70.0 + 12.0 * l
	return 65.0 + 10.0 * l


func curse_duration(id: String, l: int) -> float:
	match id:
		"amplify_damage": return 8.0 + 3.0 * l
		"dim_vision": return 7.0 + 2.0 * l
		"weaken": return 14.0 + 2.0 * l
		"iron_maiden": return 12.0 + 2.4 * l
		"terror": return 8.0 + 1.0 * l
		"confuse": return 10.0 + 1.0 * l
		"life_tap": return 13.0 + 2.6 * l
		"attract": return 12.0 + 3.6 * l
		"decrepify": return 4.0 + 0.6 * l
		"lower_resist": return 20.0 + 2.0 * l
	return 10.0


func iron_maiden_mult(l: int) -> float:
	return 2.0 + 0.25 * (l - 1)


func lower_resist_amount(l: int) -> float:
	return min(70.0, 25.0 + 3.0 * (l - 1))


# ---------------------------------------------------------------- Summoning

func skeleton_cap(l: int) -> int:
	if l <= 0:
		return 0
	return l if l < 4 else 2 + int(l / 3)


func summon_res(p) -> Dictionary:
	var l: int = p.skill_level("summon_resist")
	var r = 0.0 if l == 0 else min(75.0, 20.0 + 5.0 * l)
	return {"fire": r, "cold": r, "lightning": r, "poison": r}


func skeleton_stats(l: int, p) -> Dictionary:
	var sm: int = p.skill_level("skeleton_mastery")
	return {
		"name": "Skeleton", "kind": "skeleton", "role": "skeleton", "shape": "skeleton",
		"hp": 21.0 + 7.0 * (l - 1) + 7.0 * sm, "dmg_min": 1.0 + 1.0 * (l - 1) + 2.0 * sm, "dmg_max": 3.0 + 1.5 * (l - 1) + 2.0 * sm,
		"speed": 115.0, "range": 8.0, "cd": 0.9, "radius": 10.0, "color": Color(0.92, 0.9, 0.82), "weapon": "sword",
		"res": summon_res(p),
	}


func mage_stats(l: int, p, element: String) -> Dictionary:
	var sm: int = p.skill_level("skeleton_mastery")
	var lo := 3.0 + 2.0 * (l - 1) + sm
	var hi := 6.0 + 3.0 * (l - 1) + sm
	var colors := {"fire": Color(1, 0.45, 0.15), "cold": Color(0.45, 0.75, 1), "lightning": Color(1, 1, 0.4), "poison": Color(0.4, 0.95, 0.3)}
	var s := {
		"name": "Skeletal Mage (%s)" % element.capitalize(), "kind": "skel_mage", "role": "mage", "shape": "skeleton",
		"hp": 15.0 + 5.0 * (l - 1) + 7.0 * sm, "dmg_min": lo, "dmg_max": hi, "dmg_type": element,
		"speed": 105.0, "range": 230.0, "cd": 1.3, "radius": 10.0, "ranged": true, "proj_speed": 340.0, "proj_style": "bolt",
		"color": Color(0.85, 0.85, 0.78), "color2": colors[element], "weapon": "staff", "res": summon_res(p),
	}
	if element == "poison":
		s["dmg_min"] = 0.0
		s["dmg_max"] = 0.0
		s["poison_on_hit"] = (lo + hi) * 1.5
	elif element == "cold":
		s["slow_on_hit"] = 0.35
	return s


func golem_stats(id: String, l: int, p) -> Dictionary:
	var gm: int = p.skill_level("golem_mastery")
	var hp_mult := 1.0 + 0.2 * gm
	var spd := 85.0 * (1.0 + 0.06 * gm)
	var s := {"kind": id, "role": "golem", "shape": "golem", "speed": spd, "range": 10.0, "cd": 1.1, "radius": 15.0, "res": summon_res(p), "head_y": -44.0}
	match id:
		"clay_golem":
			s.merge({"name": "Clay Golem", "hp": (100.0 + 35.0 * (l - 1)) * hp_mult, "dmg_min": 2.0 + 2.0 * (l - 1), "dmg_max": 5.0 + 3.0 * (l - 1),
				"slow_on_hit": min(0.75, 0.15 + 0.05 * (l - 1)), "color": Color(0.62, 0.45, 0.3)})
		"blood_golem":
			s.merge({"name": "Blood Golem", "hp": (200.0 + 40.0 * (l - 1)) * hp_mult, "dmg_min": 6.0 + 3.0 * (l - 1), "dmg_max": 16.0 + 5.0 * (l - 1),
				"leech": 0.5, "color": Color(0.7, 0.08, 0.12)})
		"iron_golem":
			s.merge({"name": "Iron Golem", "hp": (300.0 + 50.0 * (l - 1)) * hp_mult, "dmg_min": 7.0 + 3.0 * (l - 1), "dmg_max": 19.0 + 5.0 * (l - 1),
				"thorns": 1.5 + 0.15 * (l - 1), "color": Color(0.6, 0.62, 0.68)})
		"fire_golem":
			var res: Dictionary = s["res"].duplicate()
			res["fire"] = 95.0
			s.merge({"name": "Fire Golem", "hp": (400.0 + 60.0 * (l - 1)) * hp_mult, "dmg_min": 10.0 + 6.0 * (l - 1), "dmg_max": 27.0 + 8.0 * (l - 1),
				"dmg_type": "fire", "aura_dps": 6.0 + 4.0 * (l - 1), "aura_radius": 110.0, "color": Color(1.0, 0.45, 0.1), "res": res}, true)
	return s


func revive_lifetime() -> float:
	return 180.0


# ---------------------------------------------------------------- Descriptions

func describe(id: String, l: int, p) -> String:
	if l <= 0:
		return ""
	match id:
		"attack":
			return "Wand damage: 2-4"
		"skeleton_mastery":
			return "Skeleton life +%d, damage +%d" % [7 * l, 2 * l]
		"raise_skeleton":
			var s := skeleton_stats(l, p)
			return "Max skeletons: %d\nLife: %d  Damage: %d-%d" % [skeleton_cap(l), s["hp"], s["dmg_min"], s["dmg_max"]]
		"raise_skeletal_mage":
			var s := mage_stats(l, p, "fire")
			return "Max mages: %d\nLife: %d  Damage: %d-%d (random element)" % [skeleton_cap(l), s["hp"], s["dmg_min"], s["dmg_max"]]
		"clay_golem", "blood_golem", "iron_golem", "fire_golem":
			var s := golem_stats(id, l, p)
			var extra := ""
			if s.has("slow_on_hit"): extra = "\nSlows target %d%%" % int(s["slow_on_hit"] * 100)
			if s.has("leech"): extra = "\nHeals itself and you on hit"
			if s.has("thorns"): extra = "\nThorns: %d%% melee damage returned" % int(s["thorns"] * 100)
			if s.has("aura_dps"): extra = "\nHoly Fire: %d fire damage per second" % int(s["aura_dps"])
			return "Life: %d  Damage: %d-%d%s" % [s["hp"], s["dmg_min"], s["dmg_max"], extra]
		"golem_mastery":
			return "Golem life +%d%%, speed +%d%%" % [20 * l, 6 * l]
		"summon_resist":
			return "Summon resistances: +%d%%" % int(min(75.0, 20.0 + 5.0 * l))
		"revive":
			return "Max revived: %d\nDuration: %d seconds, double life" % [l, int(revive_lifetime())]
		"teeth":
			var d := teeth_dmg(l, p)
			return "Teeth: %d\nMagic damage: %d-%d each" % [teeth_count(l), d.x, d.y]
		"bone_armor":
			return "Absorbs %d physical damage" % int(bone_armor_absorb(l, p))
		"poison_dagger":
			return "Poison damage: %d over 2 seconds" % int(poison_dagger_poison(l, p))
		"corpse_explosion":
			return "Radius: %.1f yards\n60-100%% of corpse life as damage" % (ce_radius(l) / 32.0)
		"bone_wall":
			return "Wall length: %d, lasts 24 seconds" % bone_wall_len(l)
		"poison_explosion":
			return "Poison damage: %d over 2 seconds" % int(poison_explosion_poison(l, p))
		"bone_spear":
			var d := bone_spear_dmg(l, p)
			return "Magic damage: %d-%d (pierces)" % [d.x, d.y]
		"bone_prison":
			return "Traps a monster for 24 seconds"
		"poison_nova":
			return "Poison damage: %d over 2 seconds" % int(poison_nova_poison(l, p))
		"bone_spirit":
			var d := bone_spirit_dmg(l, p)
			return "Magic damage: %d-%d (seeks target)" % [d.x, d.y]
	if is_curse(id):
		var t := "Radius: %.1f yards  Duration: %d s" % [curse_radius(id, l) / 32.0, int(curse_duration(id, l))]
		if id == "iron_maiden":
			t += "\nReturns %d%% melee damage" % int(iron_maiden_mult(l) * 100)
		if id == "lower_resist":
			t += "\nResistances -%d%%" % int(lower_resist_amount(l))
		return t
	return ""
