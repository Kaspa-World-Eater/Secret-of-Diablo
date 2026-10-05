class_name Inventory
extends RefCounted
## The hero's bag (10x4 grid), equipment (10 slots), belt (4 slots of up to 4 draughts) and gold.
## UI lives in ui/; rolling and drops in items/loot.gd.

signal changed
signal overflow(it)        # (items): an item that had no room (taken off with a full bag); items/ground puts it on the ground

const W := 10
const H := 4
const SLOTS := ["head", "neck", "weapon", "body", "offhand", "hands", "ring1", "ring2", "waist", "feet"]

var bag: Array = []        # [{item, pos Vector2i}]
var equip := {}            # slot -> Item
var belt: Array = [null, null, null, null]   # {kind, n}
var gold := 0

func setup_kit(kit: Dictionary) -> void:
	gold = int(kit.get("gold", 40))
	for s in kit.get("equipment", {}):
		var slot: String = s
		equip[slot] = Item.from_kit(kit["equipment"][s], slot)
	var b: Array = kit.get("belt", [])
	for i in 4:
		belt[i] = b[i].duplicate() if i < b.size() and b[i] != null else null
	changed.emit()

func weapon() -> Item:
	return equip.get("weapon")

func total(stat: String) -> float:
	var t := 0.0
	for s in equip:
		var it: Item = equip[s]
		if it:
			t += it.stat(stat)
	return t

func armor() -> float:
	var t := 0.0
	for s in equip:
		var it: Item = equip[s]
		if it:
			t += it.armor
	return t

func free_spot(g: Vector2i) -> Vector2i:
	for y in H - g.y + 1:
		for x in W - g.x + 1:
			if _fits(Vector2i(x, y), g, null):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _fits(p: Vector2i, g: Vector2i, skip) -> bool:
	if p.x < 0 or p.y < 0 or p.x + g.x > W or p.y + g.y > H:
		return false
	for e in bag:
		if e["item"] == skip:
			continue
		var q: Vector2i = e["pos"]
		var s: Vector2i = (e["item"] as Item).grid
		if p.x < q.x + s.x and q.x < p.x + g.x and p.y < q.y + s.y and q.y < p.y + g.y:
			return false
	return true

func add(it: Item) -> bool:
	if it.potion != "":
		for i in 4:
			var s = belt[i]
			if s != null and s["kind"] == it.potion and int(s["n"]) < 4:
				s["n"] = int(s["n"]) + 1
				changed.emit()
				return true
		for i in 4:
			if belt[i] == null:
				belt[i] = {"kind": it.potion, "n": 1}
				changed.emit()
				return true
	var p := free_spot(it.grid)
	if p.x < 0:
		return false
	bag.append({"item": it, "pos": p})
	changed.emit()
	return true

func remove(it: Item) -> void:
	bag = bag.filter(func(e): return e["item"] != it)
	changed.emit()

## drink from a belt slot; returns the draught kind or ""
func drink(i: int) -> String:
	var s = belt[i]
	if s == null:
		return ""
	var k: String = s["kind"]
	s["n"] = int(s["n"]) - 1
	if int(s["n"]) <= 0:
		belt[i] = null
		# refill from the bag
		for e in bag:
			var it: Item = e["item"]
			if it.potion == k:
				remove(it)
				belt[i] = {"kind": k, "n": 1}
				break
	changed.emit()
	return k

# ------------------------------------------------------------------ API used by the UI (items/*.gd owns the rules)
## can the hero wear it? (slot fits, level, order lock)
func can_equip(it: Item, level: int, cls: String) -> bool:
	if it.slot == "" or it.potion != "" or level < it.req:
		return false
	var lock := it.class_lock()
	return lock == "" or lock == cls

## the slot an item goes to (rings take the first free ring slot)
func slot_for(it: Item) -> String:
	if it.slot == "ring":
		return "ring2" if equip.get("ring1") != null and equip.get("ring2") == null else "ring1"
	return it.slot

## put it on; returns what was taken off (or null)
func equip_item(it: Item) -> Item:
	var s := slot_for(it)
	var old: Item = equip.get(s)
	equip[s] = it
	remove(it)
	if old:
		var p := free_spot(old.grid)
		if p.x >= 0:
			bag.append({"item": old, "pos": p})
		else:
			overflow.emit(old)
	changed.emit()
	return old

func unequip(slot: String) -> bool:
	var it: Item = equip.get(slot)
	if it == null:
		return false
	var p := free_spot(it.grid)
	if p.x < 0:
		return false
	equip.erase(slot)
	bag.append({"item": it, "pos": p})
	changed.emit()
	return true

func move_to(it: Item, p: Vector2i) -> bool:
	if not _fits(p, it.grid, it):
		return false
	for e in bag:
		if e["item"] == it:
			e["pos"] = p
			changed.emit()
			return true
	bag.append({"item": it, "pos": p})
	changed.emit()
	return true

func pos_of(it: Item) -> Vector2i:
	for e in bag:
		if e["item"] == it:
			return e["pos"]
	return Vector2i(-1, -1)

func item_at(p: Vector2i) -> Item:
	for e in bag:
		var q: Vector2i = e["pos"]
		var g: Vector2i = (e["item"] as Item).grid
		if p.x >= q.x and p.y >= q.y and p.x < q.x + g.x and p.y < q.y + g.y:
			return e["item"]
	return null
