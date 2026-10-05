class_name CreatureDB
extends RefCounted
## Monster and mercenary definitions. Values are for monster level 1.

const MONSTERS := {
	"hopper": {"name": "Hopper", "shape": "blob", "color": Color(1.0, 0.82, 0.35), "color2": Color(0.95, 0.5, 0.4),
		"hp": 9.0, "dmg": [1.0, 3.0], "speed": 115.0, "range": 6.0, "cd": 1.0, "radius": 10.0, "xp": 7.0, "res": {}},
	"shroom": {"name": "Shroomling", "shape": "mushroom", "color": Color(0.85, 0.2, 0.2), "color2": Color(0.95, 0.9, 0.75),
		"hp": 18.0, "dmg": [2.0, 5.0], "speed": 55.0, "range": 8.0, "cd": 1.4, "radius": 12.0, "xp": 11.0, "res": {"poison": 50.0}},
	"goblin": {"name": "Goblin Raider", "shape": "goblin", "color": Color(0.5, 0.33, 0.2), "color2": Color(0.45, 0.72, 0.3), "weapon": "club",
		"hp": 15.0, "dmg": [2.0, 6.0], "speed": 90.0, "range": 10.0, "cd": 1.1, "radius": 11.0, "xp": 13.0, "res": {}},
	"goblin_archer": {"name": "Goblin Archer", "shape": "goblin", "color": Color(0.35, 0.4, 0.22), "color2": Color(0.45, 0.72, 0.3), "weapon": "bow",
		"hp": 11.0, "dmg": [2.0, 4.0], "speed": 85.0, "range": 220.0, "cd": 1.6, "radius": 10.0, "xp": 14.0, "res": {},
		"ranged": true, "proj_speed": 380.0, "proj_style": "arrow"},
	"ghoul": {"name": "Grave Ghoul", "shape": "ghoul", "color": Color(0.38, 0.4, 0.45), "color2": Color(0.62, 0.68, 0.55),
		"hp": 28.0, "dmg": [4.0, 8.0], "speed": 72.0, "range": 10.0, "cd": 1.2, "radius": 12.0, "xp": 20.0, "res": {"poison": 50.0, "cold": 25.0}},
	"wisp": {"name": "Fire Wisp", "shape": "wisp", "color": Color(1.0, 0.55, 0.2), "color2": Color(1.0, 0.95, 0.6),
		"hp": 13.0, "dmg": [3.0, 6.0], "dmg_type": "fire", "speed": 95.0, "range": 200.0, "cd": 1.5, "radius": 9.0, "xp": 17.0,
		"res": {"fire": 75.0, "lightning": 25.0}, "ranged": true, "proj_speed": 300.0, "proj_style": "fire"},
}


static func pack_kinds(dist_tiles: float) -> Array:
	if dist_tiles < 35:
		return ["hopper", "hopper", "shroom"]
	if dist_tiles < 60:
		return ["hopper", "goblin", "goblin_archer", "shroom"]
	if dist_tiles < 85:
		return ["goblin", "goblin_archer", "ghoul", "wisp"]
	return ["ghoul", "wisp", "goblin_archer", "ghoul"]


static func monster_stats(kind: String, lvl: int, champion: bool) -> Dictionary:
	var b: Dictionary = MONSTERS[kind]
	var s: Dictionary = b.duplicate(true)
	var hm := 1.0 + 0.45 * (lvl - 1)
	var dm := 1.0 + 0.3 * (lvl - 1)
	s["kind"] = kind
	s["level"] = lvl
	s["role"] = "monster"
	s["hp"] = b["hp"] * hm
	s["dmg_min"] = b["dmg"][0] * dm
	s["dmg_max"] = b["dmg"][1] * dm
	s["xp"] = b["xp"] * (1.0 + 0.6 * (lvl - 1))
	if champion:
		s["hp"] *= 3.0
		s["dmg_min"] *= 1.5
		s["dmg_max"] *= 1.5
		s["xp"] *= 3.0
		s["speed"] *= 1.15
		s["name"] = "Champion " + b["name"]
		s["champion"] = true
	return s


static func merc_stats(lvl: int) -> Dictionary:
	return {
		"name": "Pandoran Guard", "kind": "merc", "role": "merc", "shape": "humanoid", "weapon": "spear",
		"color": Color(0.25, 0.4, 0.78), "color2": Color(0.95, 0.75, 0.6), "color3": Color(0.62, 0.62, 0.68),
		"hp": 70.0 + 18.0 * (lvl - 1), "dmg_min": 4.0 + 2.0 * lvl, "dmg_max": 9.0 + 3.0 * lvl,
		"speed": 125.0, "range": 16.0, "cd": 1.0, "radius": 11.0, "level": lvl,
		"res": {"fire": 20.0, "cold": 20.0, "lightning": 20.0, "poison": 20.0},
	}
