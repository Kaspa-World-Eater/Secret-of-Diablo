extends RefCounted
## The town's trades, as functions the UI calls (checklist section 14; e_ui.js vendor, zz_quests.js smith, healer,
## Reliquary Chest). Everything returns a short line in the world's voice ("" on success) so the UI can say it.
##   Vendor: buys anything (sell value), sells both draughts at 30 gold.
##   Smith: 7 wares (no uniques) at item level max(hero level, act minimum + 2) with +60 magic find; price
##          sell value x 5 + level x 6; restocked when the hero's level changes.
##   Healer: life, resource and poise restored, poison and burning cured, a spoken line.
##   Reliquary Chest: 48 items shared by every character on this machine, saved to user://stash.json.

const LOOT_PATH := "res://items/loot.gd"
const SFX := preload("res://items/item_sfx.gd")
const DRAUGHT_PRICE := 30
const STASH_MAX := 48
const STASH_FILE := "user://stash.json"
const ACT_MLVL := [[0, 0], [1, 17], [18, 24], [24, 30], [30, 34], [34, 40]]
const HEAL_LINES := [
	"Lie still. The wound remembers being skin; I only remind it.",
	"There. Whole again, for a while. That is all anyone is.",
	"Drink. It tastes of tallow and of mother. It will do.",
	"Hold still. The ash gets into wounds here, and it doesn't want to come out.",
	"There. You'll scar. Scars are how the body remembers it lived.",
]

static var _wares := {}      # town zone id -> {lvl, items}
static var _stash: Array = []
static var _stash_loaded := false

# ------------------------------------------------------------------ vendor
static func sell_value(it: Item) -> int:
	return it.sell_value() if it else 0

## sell an item from the bag (or a draught); returns "" or why not
static func sell(hero, it: Item) -> String:
	var inv: Inventory = hero.st.inv
	if inv.pos_of(it).x < 0:
		return "That is not yours to sell."
	inv.remove(it)
	inv.gold += it.sell_value()
	Bus.gold_changed.emit(inv.gold)
	SFX.buy(hero)
	hero.stats_changed.emit()
	return ""

## buy one draught ("hp" | "mp") for 30 gold: to the belt first, then the bag
static func buy_draught(hero, kind: String) -> String:
	var inv: Inventory = hero.st.inv
	if inv.gold < DRAUGHT_PRICE:
		return "Not enough gold."
	if not inv.add(Item.make_potion(kind)):
		return "No room in your pack."
	inv.gold -= DRAUGHT_PRICE
	Bus.gold_changed.emit(inv.gold)
	SFX.buy(hero)
	hero.stats_changed.emit()
	return ""

# ------------------------------------------------------------------ smith
static func act_of(zone_id: String) -> int:
	return int(Data.table("world").get("zones", {}).get(zone_id, {}).get("act", 1))

## the smith's seven wares for this town; the same until the hero's level changes
static func smith_wares(hero, zone_id: String) -> Array:
	var lvl: int = hero.st.level
	var w: Dictionary = _wares.get(zone_id, {})
	if not w.is_empty() and int(w["lvl"]) == lvl:
		return w["items"]
	var act := clampi(act_of(zone_id), 1, 5)
	var ilvl := maxi(lvl, int(ACT_MLVL[act][0]) + 2)
	var L = load(LOOT_PATH)
	var items := []
	for i in 40:
		if items.size() >= 7:
			break
		var it: Item = L.roll_item(ilvl, 60.0, hero.cls)
		if it and it.potion == "" and it.q != "unique":
			items.append(it)
	_wares[zone_id] = {"lvl": lvl, "items": items}
	return items

static func ware_price(it: Item) -> int:
	return int(round(it.sell_value() * 5 + maxi(1, it.req) * 6))

static func buy_ware(hero, zone_id: String, it: Item) -> String:
	var inv: Inventory = hero.st.inv
	var price := ware_price(it)
	if inv.gold < price:
		return "Not enough gold."
	if not inv.add(it):
		return "No room."
	inv.gold -= price
	var list: Array = _wares.get(zone_id, {}).get("items", [])
	list.erase(it)
	Bus.gold_changed.emit(inv.gold)
	SFX.buy(hero)
	hero.stats_changed.emit()
	return ""

## forget every smith's wares (called on level up; smith_wares also notices the level itself)
static func restock() -> void:
	_wares.clear()

# ------------------------------------------------------------------ healer
static func heal(hero, healer_name: String = "") -> String:
	var st: HeroStats = hero.st
	st.hp = st.life_max()
	st.res = st.res_max()
	st.poise = st.poise_max()
	st.heal_pool = 0.0
	for k in ["poison", "burn", "burning", "poisoned"]:
		if k in hero:
			hero.set(k, null if typeof(hero.get(k)) == TYPE_OBJECT else 0.0)
	SFX.play(hero, [[0.0, 440, 0.5, "sine", 0.05, 220]])
	hero.stats_changed.emit()
	var line: String = HEAL_LINES[randi() % HEAL_LINES.size()]
	return ("%s: \"%s\"" % [healer_name, line]) if healer_name != "" else line

# ------------------------------------------------------------------ the Reliquary Chest (stash)
static func stash() -> Array:
	if not _stash_loaded:
		_stash_loaded = true
		_stash = []
		if FileAccess.file_exists(STASH_FILE):
			var f := FileAccess.open(STASH_FILE, FileAccess.READ)
			var a = JSON.parse_string(f.get_as_text()) if f else null
			if a is Array:
				for d in a:
					if d is Dictionary:
						_stash.append(Item.from_dict(d))
	return _stash

static func stash_save() -> void:
	var a := []
	for it in stash():
		a.append(it.to_dict())
	var f := FileAccess.open(STASH_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(a))

## put an item from the bag into the chest
static func stash_put(hero, it: Item) -> String:
	var s := stash()
	if s.size() >= STASH_MAX:
		return "The chest is full."
	var inv: Inventory = hero.st.inv
	inv.remove(it)
	s.append(it)
	stash_save()
	SFX.play(hero, [[0.0, 300, 0.08, "square", 0.03]])
	return ""

## take the chest's i-th item into the bag
static func stash_take(hero, i: int) -> String:
	var s := stash()
	if i < 0 or i >= s.size():
		return ""
	var it: Item = s[i]
	if not hero.st.inv.add(it):
		return "No room in your pack."
	s.remove_at(i)
	stash_save()
	SFX.play(hero, [[0.0, 500, 0.08, "square", 0.03]])
	return ""
