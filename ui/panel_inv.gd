extends Control
## ui/panel_inv.gd: the inventory (I). The web's v0.53 page (zz_ui.js drawInventory): only as wide as the 10x4 grid,
## pinned top right; the paper doll's 10 engraved slots above the grid; gold under it. Items are picked up by a click
## (or dragged) and carried on the cursor; a second click places, swaps or equips. Right-click: equip, drink, or sell at a
## vendor; right-click an equipped item to take it off. Drop outside every panel to leave it on the ground.

const U := preload("res://ui/uikit.gd")
const PW := 148                   # page size, logical
const PH := 196
const CELL := 12.0
const GRID := Vector2(14, 120)
const EQ := {
	"weapon": [14, 28, 24, 48], "head": [62, 28, 24, 24], "neck": [92, 34, 12, 12], "offhand": [110, 28, 24, 48],
	"body": [62, 56, 24, 36], "ring1": [44, 70, 12, 12], "ring2": [92, 70, 12, 12],
	"hands": [14, 82, 24, 24], "waist": [62, 96, 24, 12], "feet": [110, 82, 24, 24]}

var hud: Node
var hover_item: Item = null
var hover_slot := ""
var hover_cell := Vector2i(-1, -1)
var hover_close := false
var press_from := ""               # where the carried item was picked up this press (for drag and drop)

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -PW * U.S
	offset_right = 0
	offset_top = 0
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _inv() -> Inventory:
	return hud.hero.st.inv if hud.hero and hud.hero.st else null

func _lp(p: Vector2) -> Vector2:
	return p / U.S

func _process(_dt: float) -> void:
	if visible:
		_update_hover(_lp(hud.mouse_in(self)))
		queue_redraw()

func _update_hover(lp: Vector2) -> void:
	hover_item = null
	hover_slot = ""
	hover_cell = Vector2i(-1, -1)
	hover_close = Rect2(PW - 15, 4, 12, 12).has_point(lp)
	var inv := _inv()
	if inv == null or not Rect2(Vector2.ZERO, size).has_point(lp * U.S):
		return
	for s in EQ:
		var r: Array = EQ[s]
		if Rect2(r[0], r[1], r[2], r[3]).has_point(lp):
			hover_slot = s
			hover_item = inv.equip.get(s)
			return
	var g := (lp - GRID) / CELL
	if g.x >= 0 and g.y >= 0 and g.x < Inventory.W and g.y < Inventory.H:
		hover_cell = Vector2i(int(g.x), int(g.y))
		hover_item = inv.item_at(hover_cell)

## where a carried item would go if placed now (top-left cell, centred on the cursor like D2)
func _place_cell(it: Item) -> Vector2i:
	var lp := _lp(hud.mouse_in(self))
	var g := (lp - GRID) / CELL - Vector2(it.grid) / 2.0 + Vector2(0.5, 0.5)
	return Vector2i(floori(g.x), floori(g.y))

func _gui_input(ev: InputEvent) -> void:
	var inv := _inv()
	if inv == null:
		return
	if ev is InputEventMouseButton:
		accept_event()
		var lp := _lp(ev.position)
		_update_hover(lp)
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if hover_close:
				hud.toggle_panel("inv")
				return
			press_from = ""
			if hud.cursor_item != null:
				_put_down(inv)
			else:
				_pick_up(inv)
		elif not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			# drag and drop: released somewhere else than it was picked up
			if hud.cursor_item != null and press_from != "" and press_from != _here():
				_put_down(inv)
			press_from = ""
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and hud.cursor_item == null:
			_right(inv)

func _here() -> String:
	if hover_slot != "":
		return "slot:" + hover_slot
	if hover_cell.x >= 0:
		return "cell:%d,%d" % [hover_cell.x, hover_cell.y]
	return "none"

func _pick_up(inv: Inventory) -> void:
	if hover_slot != "" and inv.equip.get(hover_slot) != null:
		hud.cursor_item = inv.equip[hover_slot]
		inv.equip.erase(hover_slot)
		press_from = _here()
		_changed(inv)
	elif hover_item != null:
		hud.cursor_item = hover_item
		inv.remove(hover_item)
		press_from = _here()
		_changed(inv)

func _put_down(inv: Inventory) -> void:
	var it: Item = hud.cursor_item
	var h: Hero = hud.hero
	if hover_slot != "":
		if not _fits_slot(it, hover_slot):
			Bus.say.emit("It will not go there.", 1.2)
			return
		if not inv.can_equip(it, h.st.level, h.st.cls):
			Bus.say.emit("You are not ready to wear that. Level %d." % it.req, 1.4)
			return
		var old: Item = inv.equip.get(hover_slot)
		inv.equip[hover_slot] = it
		hud.cursor_item = old
		_changed(inv)
		return
	if hover_cell.x < 0 and not Rect2(Vector2(GRID) - Vector2(6, 6), Vector2(Inventory.W * CELL + 12, Inventory.H * CELL + 12)).has_point(_lp(hud.mouse_in(self))):
		return
	var at := _place_cell(it)
	at.x = clampi(at.x, 0, Inventory.W - it.grid.x)
	at.y = clampi(at.y, 0, Inventory.H - it.grid.y)
	# D2: dropping over exactly one item swaps it onto the cursor
	var under: Array = []
	for e in inv.bag:
		var q: Vector2i = e["pos"]
		var g: Vector2i = (e["item"] as Item).grid
		if at.x < q.x + g.x and q.x < at.x + it.grid.x and at.y < q.y + g.y and q.y < at.y + it.grid.y:
			under.append(e["item"])
	if under.size() > 1:
		return
	if under.size() == 1:
		var back := inv.pos_of(under[0])
		inv.remove(under[0])
		if inv.move_to(it, at):
			hud.cursor_item = under[0]
		else:
			inv.move_to(under[0], back)
		_changed(inv)
		return
	if inv.move_to(it, at):
		hud.cursor_item = null
		_changed(inv)

func _fits_slot(it: Item, s: String) -> bool:
	if it.slot == "ring":
		return s == "ring1" or s == "ring2"
	return it.slot == s

func _right(inv: Inventory) -> void:
	var h: Hero = hud.hero
	if hover_slot != "":
		if inv.equip.get(hover_slot) != null and not inv.unequip(hover_slot):
			Bus.say.emit("No room in the pack.", 1.2)
		_changed(inv)
		return
	var it := hover_item
	if it == null:
		return
	if hud.vendor_open:
		inv.gold += it.sell_value()
		inv.remove(it)
		Bus.gold_changed.emit(inv.gold)
		_changed(inv)
		return
	if hud.stash_open:
		var why: String = load("res://items/shop.gd").stash_put(h, it)
		if why != "":
			Bus.say.emit(why, 1.4)
		_changed(inv)
		return
	if it.potion != "":
		inv.remove(it)
		if it.potion == "hp":
			h.st.heal_pool += h.st.life_max() * 0.4
		else:
			h.st.restore_pool += h.st.res_max() * 0.5
		_changed(inv)
		return
	if it.slot != "":
		if not inv.can_equip(it, h.st.level, h.st.cls):
			Bus.say.emit("You are not ready to wear that. Level %d." % it.req, 1.4)
			return
		inv.equip_item(it)
		_changed(inv)

func _changed(inv: Inventory) -> void:
	inv.changed.emit()
	if hud.hero:
		hud.hero.stats_changed.emit()

func tip() -> Array:
	if hover_close:
		return [["Close (I)", U.TEXT]]
	if hover_item == null or hud.cursor_item != null:
		return []
	var lines: Array = hud.item_tip(hover_item)
	if hud.vendor_open:
		lines.append(["Sell value: %d gold (right-click)" % hover_item.sell_value(), U.GOLD_D])
	elif hud.stash_open and hover_slot == "":
		lines.append(["Right-click to put it in the chest", U.FAINT])
	elif hover_slot != "":
		lines.append(["Right-click to take it off", U.FAINT])
	elif hover_item.potion != "":
		lines.append(["Right-click to drink", U.FAINT])
	elif hover_item.slot != "":
		lines.append(["Right-click to wear it", U.FAINT])
	return lines

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var inv := _inv()
	if inv == null:
		return
	var h: Hero = hud.hero
	var col := U.cls_col(h.st.cls)
	U.page(self, 0, 0, PW, PH, col)
	U.title(self, "Inventory", PW / 2.0, 19, col, 110)
	U.stud(self, PW - 15, 4, 12, 12, "", true, U.TEXT, hover_close)
	U.text(self, "x", PW - 9, 13, U.MUTED, 0, "pixel", 8, false)
	for s in EQ:
		var r: Array = EQ[s]
		var x: float = r[0]
		var y: float = r[1]
		var w: float = r[2]
		var hh: float = r[3]
		U.rect(self, x - 2, y - 2, w + 4, hh + 4, U.SEAM)
		U.rect(self, x - 1, y - 1, w + 2, 1, Color("#3a3446"))
		U.rect(self, x - 1, y - 1, 1, hh + 2, Color("#3a3446"))
		U.rect(self, x - 1, y + hh, w + 2, 1, Color("#221e2a"))
		U.rect(self, x + w, y - 1, 1, hh + 2, Color("#221e2a"))
		U.rect(self, x, y, w, hh, Color("#100d12"))
		U.rect(self, x, y, w, 1, Color("#08070a"))
		U.rect(self, x, y, 1, hh, Color("#08070a"))
		var it: Item = inv.equip.get(s)
		var carried: Item = hud.cursor_item
		if carried and _fits_slot(carried, s):
			U.rect(self, x, y, w, hh, Color(0.3, 0.5, 0.3, 0.12) if inv.can_equip(carried, h.st.level, h.st.cls) else Color(0.6, 0.1, 0.1, 0.15))
		if it:
			U.rect(self, x, y, w, hh, _qtint(it))
			var iw := minf(w, it.grid.x * CELL)
			var ih := minf(hh, it.grid.y * CELL)
			hud.draw_item(self, it, U.R(roundf(x + (w - iw) / 2.0), roundf(y + (hh - ih) / 2.0), iw, ih))
		else:
			_sigil(s, x, y, w, hh)
		if hover_slot == s:
			U.frame(self, x - 1, y - 1, w + 2, hh + 2, Color(col, 0.6), 0.5)
	# the grid
	var gx := GRID.x
	var gy := GRID.y
	U.rect(self, gx - 2, gy - 2, Inventory.W * CELL + 4, Inventory.H * CELL + 4, U.SEAM)
	U.rect(self, gx - 1, gy - 1, Inventory.W * CELL + 2, 1, Color("#3a3446"))
	U.rect(self, gx - 1, gy - 1, 1, Inventory.H * CELL + 2, Color("#3a3446"))
	for y in Inventory.H:
		for x in Inventory.W:
			var cx := gx + x * CELL
			var cy := gy + y * CELL
			U.rect(self, cx, cy, CELL, CELL, Color("#141117") if (x + y) % 2 else Color("#171319"))
			U.rect(self, cx, cy, CELL, 0.5, U.INK)
			U.rect(self, cx, cy, 0.5, CELL, U.INK)
	# where the carried item would land
	if hud.cursor_item != null and hover_cell.x >= 0:
		var it: Item = hud.cursor_item
		var at := _place_cell(it)
		at.x = clampi(at.x, 0, Inventory.W - it.grid.x)
		at.y = clampi(at.y, 0, Inventory.H - it.grid.y)
		U.rect(self, gx + at.x * CELL, gy + at.y * CELL, it.grid.x * CELL, it.grid.y * CELL, Color(0.55, 0.6, 0.9, 0.14))
	for e in inv.bag:
		var it: Item = e["item"]
		var p: Vector2i = e["pos"]
		var x := gx + p.x * CELL
		var y := gy + p.y * CELL
		U.rect(self, x, y, it.grid.x * CELL, it.grid.y * CELL, _qtint(it))
		if it == hover_item:
			U.rect(self, x, y, it.grid.x * CELL, it.grid.y * CELL, Color(1, 1, 1, 0.06))
		hud.draw_item(self, it, U.R(x, y, it.grid.x * CELL, it.grid.y * CELL))
		if it.req > h.st.level:
			U.rect(self, x, y, it.grid.x * CELL, it.grid.y * CELL, Color(0.78, 0.16, 0.16, 0.25))
	var ry := gy + Inventory.H * CELL + 5
	U.rule(self, 12, ry, PW - 24, col)
	U.text(self, "Gold %d" % inv.gold, PW / 2.0, ry + 13, U.GOLD, 0)

func _qtint(it: Item) -> Color:
	match it.q:
		"unique":
			return Color(0.79, 0.64, 0.35, 0.18)
		"rare":
			return Color(0.95, 0.88, 0.35, 0.14)
		"magic":
			return Color(0.55, 0.58, 1.0, 0.15)
	return Color(0, 0, 0, 0)

## a faint engraved sign of what goes in an empty slot
func _sigil(s: String, x: float, y: float, w: float, h: float) -> void:
	var c := Color("#2a2430")
	var c2 := Color("#332c3a")
	var ox := roundf(x + w / 2.0 - 6)
	var oy := roundf(y + h / 2.0 - 6)
	match s:
		"head":
			U.rect(self, ox + 3, oy + 3, 6, 6, c)
			U.rect(self, ox + 3, oy + 8, 6, 2, c)
			U.rect(self, ox + 5, oy + 5, 2, 5, c2)
		"neck":
			U.frame(self, ox + 3, oy + 1, 6, 6, c)
			U.rect(self, ox + 5, oy + 8, 2, 3, c2)
		"weapon":
			for i in 8:
				U.rect(self, ox + 3 + i, oy + 10 - i, 2, 1, c)
			U.rect(self, ox + 2, oy + 8, 4, 1, c2)
		"body":
			U.rect(self, ox + 2, oy + 2, 8, 9, c)
			U.rect(self, ox + 5, oy + 3, 2, 8, c2)
		"offhand":
			U.rect(self, ox + 2, oy + 2, 8, 7, c)
			U.rect(self, ox + 4, oy + 9, 4, 2, c)
			U.rect(self, ox + 5, oy + 3, 2, 6, c2)
		"hands":
			U.rect(self, ox + 3, oy + 5, 6, 6, c)
			for i in 4:
				U.rect(self, ox + 3 + i * 2, oy + 2 + (i % 2), 1, 3, c)
		"ring1", "ring2":
			U.frame(self, ox + 3, oy + 3, 6, 6, c)
			U.rect(self, ox + 5, oy + 1, 2, 2, c2)
		"waist":
			U.rect(self, ox + 1, oy + 4, 10, 3, c)
			U.rect(self, ox + 5, oy + 3, 3, 5, c2)
		"feet":
			U.rect(self, ox + 3, oy + 1, 4, 6, c)
			U.rect(self, ox + 3, oy + 7, 7, 3, c)
