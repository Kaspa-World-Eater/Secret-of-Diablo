extends RefCounted
## What falls when something dies or a chest is opened, and how an item is rolled (checklist sections 13-14).
## Faithful to the web build's final chain:
##   rollItem   = c_game rollItem (quality tiers x magic find, affixes by item level and slot, rare names, uniques)
##                -> zz_pace_and_density (magic filled to 2 affixes, rare to 6, no stat twice)
##                -> zz_tune_batch_c (half of magic and rare drops fall back to normal)
##                -> zz_tune_batch_e (a rare or unique is re-rolled into something lesser 30% of the time)
##   dropLoot   = zz_pace_and_density rank gate -> zz_mech_loot per-rank rolls, guaranteed floors, gold, potion
##                -> zz_zz_chest91 (chests: one more 25% roll, coins when empty, spilled toward the camera)
##                -> zz_zz_study82 (the sound of a drop by its best rarity; gold falls silent)
## Loaded by path (no class_name): main.gd calls load("res://items/loot.gd").on_kill(zone, m, hero).

const GROUND := preload("res://items/ground.gd")
const TOOLTIP := preload("res://items/tooltip.gd")

const QORDER := {"normal": 0, "magic": 1, "rare": 2, "unique": 3}

static var _icons := {}

# ------------------------------------------------------------------ tables
static func _items() -> Dictionary:
	return Data.table("items")

static func _cfg(kind: String) -> Dictionary:
	var c: Dictionary = _items().get("drops", {}).get("per_rank_cfg", {})
	return c.get(kind, c.get("normal", {}))

static func _gate(kind: String) -> float:
	return float(_items().get("drops", {}).get("rank_gate", {}).get(kind, 0.22))

## the drop kind of a creature: boss | unique | champion | minion | normal
static func kind_of(m) -> String:
	if m.boss:
		return "boss"
	if m.rank in ["unique", "champion", "minion"]:
		return m.rank
	return "normal"

# ------------------------------------------------------------------ the hero's luck
## magic find: items, +40 with the wick turned down, -10 per light the lantern keeps (zz_zz_study82)
static func magic_find(hero) -> float:
	if hero == null or hero.st == null:
		return 0.0
	var st: HeroStats = hero.st
	var mf := st.item("mf")
	if st.dim_wick:
		mf += 40.0
	mf -= 10.0 * st.kept
	return mf

## gold find multiplier: x1.25 with the wick down, -10% per kept light, and any "gf" on gear or blessings
static func gold_k(hero) -> float:
	if hero == null or hero.st == null:
		return 1.0
	var st: HeroStats = hero.st
	var k := 1.0
	if st.dim_wick:
		k *= 1.25
	if st.kept > 0:
		k *= 1.0 - 0.1 * st.kept
	k *= 1.0 + st.item("gf") / 100.0
	return k

static func _cls(hero) -> String:
	if hero != null and "cls" in hero and hero.cls != "":
		return hero.cls
	return Game.cls

# ------------------------------------------------------------------ rolling one item
static func _affix_pool(slot: String, ilvl: int, pre: bool, rare: bool) -> Array:
	var out := []
	for a in _items().get("affixes", []):
		if bool(a["prefix"]) != pre or int(a["item_level"]) > ilvl + 1:
			continue
		if a.get("slots") != null and not (slot in a["slots"]):
			continue
		if bool(a.get("rare_only", false)) and not rare:
			continue
		out.append(a)
	return out

static func _pick_w(list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var t := 0.0
	for a in list:
		t += float(a.get("weight", 1.0))
	var r := randf() * t
	for a in list:
		r -= float(a.get("weight", 1.0))
		if r <= 0.0:
			return a
	return list[list.size() - 1]

static func _add_affix(it: Item, a: Dictionary) -> void:
	var v := randi_range(int(a["range"][0]), int(a["range"][1]))
	it.stats[a["stat"]] = float(it.stats.get(a["stat"], 0.0)) + v
	it.req = maxi(it.req, int(a["item_level"]))

## c_game.js rollItem
static func _roll_base(ilvl: int, mf: float, cls: String) -> Item:
	var bases: Dictionary = _items().get("bases", {})
	var pool := []
	for k in bases:
		var b: Dictionary = bases[k]
		var lock = b.get("class_lock")
		if int(b.get("item_level", 1)) <= ilvl + 1 and (lock == null or lock == cls):
			pool.append(k)
	var base_id: String = pool[randi() % pool.size()]
	var m := 1.0 + mf / 100.0
	var r := randf()
	var q := "normal"
	if r < 0.012 * m:
		q = "unique"
	elif r < 0.075 * m:
		q = "rare"
	elif r < 0.36 * m:
		q = "magic"
	if q == "unique":
		var us := []
		for u in _items().get("uniques", []):
			if int(u["lvl"]) <= ilvl + 2:
				us.append(u)
		if not us.is_empty():
			var u: Dictionary = us[randi() % us.size()]
			var ui := Item.from_base(u["base"])
			ui.q = "unique"
			ui.name = u["name"]
			for k in u["stats"]:
				ui.stats[k] = float(u["stats"][k])
			ui.req = int(u["lvl"])
			ui.ilvl = ilvl
			if ui.armor > 0.0:
				ui.armor = roundf(ui.armor * float(_items().get("rarities", {}).get("unique_armor_x", 1.3)))
			return ui
		q = "rare"
	var it := Item.from_base(base_id)
	var brow: Dictionary = bases[base_id]
	it.q = q
	it.ilvl = ilvl
	it.req = maxi(1, int(brow.get("item_level", 1)))
	if q == "magic":
		var pre := {}
		var suf := {}
		if randf() < 0.7:
			pre = _pick_w(_affix_pool(it.slot, ilvl, true, false))
			if not pre.is_empty():
				_add_affix(it, pre)
		if pre.is_empty() or randf() < 0.6:
			suf = _pick_w(_affix_pool(it.slot, ilvl, false, false))
			if not suf.is_empty():
				_add_affix(it, suf)
		it.name = ((pre["name"] + " ") if not pre.is_empty() else "") + it.base_name() + ((" " + suf["name"]) if not suf.is_empty() else "")
	elif q == "rare":
		var n := randi_range(3, mini(6, 3 + int(ilvl / 3)))
		var pres := _affix_pool(it.slot, ilvl, true, true)
		var sufs := _affix_pool(it.slot, ilvl, false, true)
		var used := {}
		for i in n:
			var src: Array = sufs if i % 2 == 1 else pres
			var cands := src.filter(func(a): return not used.has(a["stat"]))
			if cands.is_empty():
				continue
			var a := _pick_w(cands)
			used[a["stat"]] = true
			_add_affix(it, a)
		it.name = rare_name(it.slot)
		if it.stat("dmg") > 15.0:
			it.stats["dmg"] = 15.0
		if it.armor > 0.0:
			it.armor = roundf(it.armor * 1.15)
	return it

static func rare_name(slot: String) -> String:
	var rn: Dictionary = _items().get("rarities", {}).get("rare_names", {})
	var a: Array = rn.get("A", ["Grim"])
	var b: Array = rn.get("B", {}).get(slot, ["Relic"])
	return "%s %s" % [a[randi() % a.size()], b[randi() % b.size()]]

## + zz_pace_and_density: magic filled to 2 affixes, rare to 6 (uniform from the eligible pool, no stat twice)
static func _roll_dense(ilvl: int, mf: float, cls: String) -> Item:
	var it := _roll_base(ilvl, mf, cls)
	var want := {"magic": 2, "rare": 6}
	if not want.has(it.q):
		return it
	var need: int = want[it.q] - it.stats.size()
	if need <= 0:
		return it
	var pool := []
	for a in _items().get("affixes", []):
		if a.get("slots") != null and not (it.slot in a["slots"]):
			continue
		if int(a["item_level"]) > ilvl + 1:
			continue
		if bool(a.get("rare_only", false)) and it.q != "rare":
			continue
		pool.append(a)
	for i in need:
		var cand := pool.filter(func(a): return not it.stats.has(a["stat"]))
		if cand.is_empty():
			break
		var a: Dictionary = cand[randi() % cand.size()]
		it.stats[a["stat"]] = float(randi_range(int(a["range"][0]), int(a["range"][1])))
	return it

## + zz_tune_batch_c: half of magic and rare drops fall back to normal
static func _roll_c(ilvl: int, mf: float, cls: String) -> Item:
	var it := _roll_dense(ilvl, mf, cls)
	if (it.q == "magic" or it.q == "rare") and randf() < 0.5:
		it.q = "normal"
		it.name = it.base_name()
		it.stats = {}
		# the web keeps the lost affixes' required level; a plain item asks only its base's level here
		it.req = maxi(1, int(Item.base_row(it.base).get("item_level", 1)))
	return it

## the final rollItem (+ zz_tune_batch_e: a rare or unique is re-rolled into something lesser 30% of the time)
static func roll_item(ilvl: int, mf: float = 0.0, cls: String = "") -> Item:
	if cls == "":
		cls = Game.cls
	ilvl = maxi(1, ilvl)
	var it := _roll_c(ilvl, mf, cls)
	if (it.q == "rare" or it.q == "unique") and randf() < 0.30:
		for k in 10:
			var r := _roll_c(ilvl, mf, cls)
			if r.q != "rare" and r.q != "unique":
				it = r
				break
	return it

## zz_mech_loot rollItemMin: roll until the floor is met (40 tries), else the best seen
static func roll_min(ilvl: int, mf: float, min_q: String, cls: String = "", tries: int = 40) -> Item:
	var floor_q: int = QORDER.get(min_q, 0)
	var best: Item = null
	var best_q := -1
	for i in tries:
		var it := roll_item(ilvl, mf, cls)
		var q: int = QORDER.get(it.q, 0)
		if q > best_q:
			best = it
			best_q = q
		if q >= floor_q:
			return it
	return best

# ------------------------------------------------------------------ what falls
## the drops of one kill or chest, before they are placed: [{item} | {gold}]
static func roll_drops(ilvl: int, kind: String, hero) -> Array:
	var cfg := _cfg(kind)
	var mf := magic_find(hero) + float(cfg.get("mfBonus", 0))
	var il := maxi(1, ilvl)
	var cls := _cls(hero)
	var out := []
	var guaranteed := int(cfg.get("guar", 0))
	for i in int(cfg.get("rolls", 1)):
		if guaranteed > 0:
			var g := roll_min(il, mf, str(cfg.get("minQ", "normal")), cls)
			if g:
				out.append({"item": g})
				guaranteed -= 1
				continue
		if randf() < float(cfg.get("chance", 0.3)):
			out.append({"item": roll_item(il, mf, cls)})
	var gc: Array = cfg.get("gold", [0.45, [2, 6], 1.0])
	if randf() < float(gc[0]):
		out.append({"gold": maxi(1, int(round(randf_range(float(gc[1][0]), float(gc[1][1])) * il * float(gc[2]))))})
	if randf() < float(cfg.get("potChance", 0.2)):
		out.append({"item": Item.make_potion("hp" if randf() < 0.55 else "mp")})
	return out

## called by main.gd on every kill
static func on_kill(zone, m, hero) -> void:
	if zone == null or m == null:
		return
	GROUND.for_zone(zone)
	GROUND.wick_kill(zone, m, hero)
	var kind := kind_of(m)
	if randf() > _gate(kind):
		return            # nothing drops, and nothing is heard
	var ilvl: int = int(m.level) + (1 if m.rank == "unique" else 0)
	var drops := roll_drops(ilvl, kind, hero)
	if drops.is_empty():
		return
	var n := drops.size()
	for d in drops:
		var a := randf() * TAU
		var r := 0.3 + randf() * (1.3 if n > 3 else 0.7)
		var p: Vector2 = m.tp + Vector2(cos(a), sin(a)) * r
		if zone.is_solid(p):
			p = m.tp
		GROUND.spawn(zone, d, p, m.tp)
	GROUND.drop_sound(zone, drops)

## a chest opened (the world-objects helper calls this): two 60% rolls and one 25%, gold 85%, potion 25%,
## coins half the time when nothing else came; everything spills 1-1.8 tiles toward the camera, fanned
static func open_chest(zone, tp: Vector2, ilvl: int, hero) -> Array:
	var il := maxi(1, ilvl)
	var drops := roll_drops(il, "chest", hero)
	if randf() < 0.25:
		drops.append({"item": roll_item(il, magic_find(hero), _cls(hero))})
	if drops.is_empty() and randf() < 0.5:
		drops.append({"gold": maxi(1, int(round((2.0 + randf() * 4.0) * il)))})
	var n := drops.size()
	var c := Vector2(tp.x, tp.y - 0.5)
	for i in n:
		var a := PI / 4.0 + ((float(i) / (n - 1) - 0.5) * 1.9 if n > 1 else 0.0) + (randf() - 0.5) * 0.25
		var dd := 1.05 + randf() * 0.7
		var p := c + Vector2(cos(a), sin(a)) * dd
		if zone.is_solid(p):
			p = c + Vector2(cos(a), sin(a)) * 0.9
		if zone.is_solid(p):
			p = tp
		GROUND.spawn(zone, drops[i], p, tp)
	GROUND.drop_sound(zone, drops)
	return drops

## put one item on the ground at a spot (a bag with no room, an item dragged out of the inventory)
static func drop_item(zone, tp: Vector2, it: Item) -> void:
	var p := tp + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
	if zone.is_solid(p):
		p = tp
	GROUND.spawn(zone, {"item": it}, p, tp)
	GROUND.drop_sound(zone, [{"item": it}])

# ------------------------------------------------------------------ icons and tooltips (for the UI helper)
## the item's icon at the web's inventory scale: 48 px per grid cell (12 art px x 4)
static func icon_for(it) -> Texture2D:
	var id := ""
	if it is Item:
		id = it.potion if it.potion != "" else (it.icon if it.icon != "" else it.base)
	elif it is String:
		id = it
	if id == "":
		return null
	if _icons.has(id):
		return _icons[id]
	var path := "res://art/items/%s.png" % id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			tex = ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex

const CELL_PX := 48

## [text, Color] lines; the sell value line only with at_vendor (the inventory panel adds its own at a vendor)
static func tooltip_lines(it: Item, hero, at_vendor: bool = false) -> Array:
	return TOOLTIP.lines(it, hero, at_vendor)
