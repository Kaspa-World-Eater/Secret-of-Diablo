class_name Item
extends RefCounted
## One item: a base (data/items.json bases), a rarity, rolled affixes. The stat keys match the web build's
## (life, mana/essence "spi", armor, dmg (+% skill damage), frw, fcr, res, mf, gf, lok, fire, cold, psn, magic,
## wisp, regen, vit, con, skt0-2 (tree skills), skall (all skills), lantern wicks lrad lblue lamber lwhite lgreen lviolet).
## Rolling lives in items/loot.gd, tooltips in items/tooltip.gd.

static var _uid := 1

var uid := 0
var base := ""
var name := ""
var q := "normal"          # normal | magic | rare | unique | potion
var slot := ""             # weapon, offhand, head, body, hands, feet, waist, neck, ring
var grid := Vector2i(1, 1)
var ilvl := 1              # the level of what dropped it
var req := 1               # required level (the web's it.lvl): the base's level, raised by the highest affix level
var dmg := Vector2.ZERO    # weapons
var armor := 0.0
var stats := {}            # stat key -> value (summed affixes)
var lines: Array = []      # affix text lines, as shown (optional; tooltip.gd builds them from stats)
var lore := ""
var potion := ""           # hp | mp for draughts
var icon := ""

func _init() -> void:
	uid = _uid
	_uid += 1

static func base_row(id: String) -> Dictionary:
	return Data.table("items").get("bases", {}).get(id, {})

## a plain base item, as the web's newBaseItem: armour rolled in its range, damage the base's
static func from_base(id: String) -> Item:
	var b := base_row(id)
	var it := Item.new()
	it.base = id
	it.name = b.get("name", id)
	it.slot = b.get("slot", "")
	if b.has("grid"):
		it.grid = Vector2i(int(b["grid"][0]), int(b["grid"][1]))
	it.icon = b.get("icon", id)
	if b.get("armor") != null:
		it.armor = float(randi_range(int(b["armor"][0]), int(b["armor"][1])))
	if b.get("damage") != null:
		it.dmg = Vector2(b["damage"][0], b["damage"][1])
	it.req = 1
	return it

static func make_potion(kind: String) -> Item:
	var it := Item.new()
	it.potion = kind
	it.q = "potion"
	it.base = kind
	it.icon = kind
	it.name = "Healing Draught" if kind == "hp" else "Essence Draught"
	return it

static func from_kit(e: Dictionary, slot_name: String) -> Item:
	var it := Item.new()
	it.base = e.get("base", "")
	it.name = e.get("name", it.base)
	it.q = e.get("q", "normal")
	it.slot = slot_name
	if e.get("dmg") != null:
		var d: Array = e["dmg"]
		it.dmg = Vector2(d[0], d[1])
	if e.get("armor") != null:
		it.armor = float(e["armor"])
	var b: Dictionary = base_row(it.base)
	if b.has("grid"):
		it.grid = Vector2i(b["grid"][0], b["grid"][1])
	it.icon = b.get("icon", "")
	# (items): a kit's key is an equipment slot (ring1/ring2); the item's own slot is its base's
	if b.has("slot"):
		it.slot = b["slot"]
	return it

func stat(k: String) -> float:
	return float(stats.get(k, 0.0))

func color() -> Color:
	return rarity_color(q)

static func rarity_color(rq: String) -> Color:
	match rq:
		"magic":
			return Color("#8b95ff")
		"rare":
			return Color("#f1e05a")
		"unique":
			return Color("#c9a45a")
	return Color("#d6d2c8")

## what a vendor pays (the web's itemValue): potion 8, else by rarity + 4 per (required) level
func sell_value() -> int:
	if potion != "":
		return 8
	return int({"normal": 5, "magic": 25, "rare": 70, "unique": 160}.get(q, 5)) + 4 * maxi(1, req)

func is_ranged() -> bool:
	return base == "wand"

func class_lock() -> String:
	var c = base_row(base).get("class_lock")
	return c if c is String else ""

func base_name() -> String:
	return base_row(base).get("name", base)

# ------------------------------------------------------------------ save / stash
func to_dict() -> Dictionary:
	return {"base": base, "name": name, "q": q, "slot": slot, "grid": [grid.x, grid.y], "ilvl": ilvl, "req": req,
		"dmg": [dmg.x, dmg.y], "armor": armor, "stats": stats.duplicate(), "potion": potion, "icon": icon}

static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.base = d.get("base", "")
	it.name = d.get("name", it.base)
	it.q = d.get("q", "normal")
	it.slot = d.get("slot", "")
	var g: Array = d.get("grid", [1, 1])
	it.grid = Vector2i(int(g[0]), int(g[1]))
	it.ilvl = int(d.get("ilvl", 1))
	it.req = int(d.get("req", 1))
	var dm: Array = d.get("dmg", [0, 0])
	it.dmg = Vector2(float(dm[0]), float(dm[1]))
	it.armor = float(d.get("armor", 0.0))
	var s: Dictionary = d.get("stats", {})
	for k in s:
		it.stats[k] = float(s[k])
	it.potion = d.get("potion", "")
	it.icon = d.get("icon", it.base)
	return it
