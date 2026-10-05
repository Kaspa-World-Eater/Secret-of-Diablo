extends Control
## ui/panel_town.gd: the town's windows, on the left page (the pack opens on the right beside them):
##   vendor  Maren: two draughts at 30 gold; right-click what you carry to sell it (hud.vendor_open)
##   smith   Brannoc: seven wares, bought with a click (items/shop.gd smith_wares, buy_ware)
##   stash   the Reliquary Chest: 48 places shared by every pilgrim on this machine; click to take, right-click
##           in the pack to put away (hud.stash_open)
##   lantern a touched lantern-stone: rest (done by the stone), and travel to any lantern kindled on this walk
##   journal Esk's vows (J): the act's vows, their state, where, and what they pay (world/quests.gd journal)
## Opened by Bus.panel_requested(panel, who) from the townsfolk (world/objects/manager.gd), and J for the journal.

const U := preload("res://ui/uikit.gd")
const SHOP := preload("res://items/shop.gd")
const PW := 236
const PH := 240
const CELL := 24.0

var hud: Node
var mode := ""              # vendor | smith | stash | journal
var who := ""
var hover := ""             # close | buy:hp | buy:mp | ware:i | chest:i | q:i
var sel_q := 0
var line := ""              # the last thing said (not enough gold, no room)
var line_t := 0.0
var opened_at := Vector2.ZERO

func _ready() -> void:
	offset_right = PW * U.S
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func open(m: String, w: String = "") -> void:
	mode = m
	who = w
	line = ""
	visible = true
	hud.vendor_open = m == "vendor"
	hud.stash_open = m == "stash"
	if m in ["vendor", "smith", "stash"]:
		hud.p_inv.visible = true
	if m == "journal":
		sel_q = 0
	if hud.hero:
		opened_at = hud.hero.tp

func close() -> void:
	visible = false
	hud.vendor_open = false
	hud.stash_open = false
	mode = ""

func _Q():
	return load("res://world/quests.gd")

func _process(dt: float) -> void:
	if not visible:
		return
	line_t = maxf(0.0, line_t - dt)
	hover = _at(hud.mouse_in(self) / U.S)
	# walked away from the townsfolk: the window closes (the journal travels with you)
	if mode == "lantern":
		if hud.hero and hud.hero.tp.distance_to(opened_at) > 3.5:
			close()
	elif mode != "journal" and hud.hero and hud.zone and not load("res://world/quests.gd").is_town(hud.zone.id):
		close()
	queue_redraw()

func _say(s: String) -> void:
	line = s
	line_t = 2.5 if s != "" else 0.0

# ------------------------------------------------------------------ layout
func _ware_rect(i: int) -> Rect2:
	return Rect2(14, 46 + i * 24, PW - 28, 22)

func _chest_rect(i: int) -> Rect2:
	return Rect2(14 + (i % 8) * (CELL + 2), 40 + (i / 8) * (CELL + 2), CELL, CELL)

func _q_rect(i: int) -> Rect2:
	return Rect2(10, 34 + i * 15, PW - 20, 14)

func _at(lp: Vector2) -> String:
	if Rect2(PW - 15, 4, 12, 12).has_point(lp):
		return "close"
	match mode:
		"vendor":
			for i in 2:
				if Rect2(14, 50 + i * 34, PW - 28, 30).has_point(lp):
					return "buy:" + ["hp", "mp"][i]
		"smith":
			var wares: Array = _wares()
			for i in wares.size():
				if _ware_rect(i).has_point(lp):
					return "ware:%d" % i
		"stash":
			for i in SHOP.STASH_MAX:
				if _chest_rect(i).has_point(lp):
					return "chest:%d" % i
		"journal":
			var rows: Array = _Q().journal(1)
			for i in rows.size():
				if _q_rect(i).has_point(lp):
					return "q:%d" % i
		"lantern":
			var ls: Array = _lanterns()
			for i in ls.size():
				if Rect2(14, 76 + i * 16, PW - 28, 14).has_point(lp):
					return "l:%d" % i
	return ""

func _wares() -> Array:
	if hud.hero == null or hud.zone == null:
		return []
	return SHOP.smith_wares(hud.hero, hud.zone.id)

# ------------------------------------------------------------------ input
func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	accept_event()
	var h = hud.hero
	if h == null:
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if hover == "close":
		close()
		return
	if hover.begins_with("buy:"):
		_say(SHOP.buy_draught(h, hover.substr(4)))
	elif hover.begins_with("ware:"):
		var wares: Array = _wares()
		var i := int(hover.substr(5))
		if i < wares.size():
			_say(SHOP.buy_ware(h, hud.zone.id, wares[i]))
	elif hover.begins_with("chest:"):
		var j := int(hover.substr(6))
		if j < SHOP.stash().size():
			_say(SHOP.stash_take(h, j))
	elif hover.begins_with("q:"):
		sel_q = int(hover.substr(2))
	elif hover.begins_with("l:"):
		var ls: Array = _lanterns()
		var li := int(hover.substr(2))
		if li < ls.size() and not _here(ls[li]):
			var main := get_tree().current_scene
			close()
			if main and main.has_method("travel_lantern"):
				main.travel_lantern(ls[li])

func tip() -> Array:
	var h = hud.hero
	if hover == "close":
		return [["Close (Esc)", U.TEXT]]
	if hover.begins_with("ware:"):
		var wares: Array = _wares()
		var i := int(hover.substr(5))
		if i < wares.size():
			var l: Array = hud.item_tip(wares[i])
			l.append(["Price: %d gold (click to buy)" % SHOP.ware_price(wares[i]), U.GOLD_D])
			return l
	if hover.begins_with("chest:"):
		var j := int(hover.substr(6))
		var s: Array = SHOP.stash()
		if j < s.size():
			var l2: Array = hud.item_tip(s[j])
			l2.append(["Click to take it", U.FAINT])
			return l2
	if hover.begins_with("buy:"):
		var k := hover.substr(4)
		return [["Draught of Life" if k == "hp" else "Draught of " + (h.st.res_name() if h else "Essence"), U.TEXT],
			[("Mends 40% of your life over a few breaths" if k == "hp" else "Restores half your %s" % (h.st.res_name() if h else "Essence")), U.MUTED],
			["%d gold (click to buy)" % SHOP.DRAUGHT_PRICE, U.GOLD_D]]
	return []

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var h = hud.hero
	if h == null:
		return
	var col := Color("#c9a45a")
	U.page(self, 0, 0, PW, PH, col)
	var title: String = {"vendor": who if who != "" else "The Vendor", "smith": who if who != "" else "The Smith",
		"stash": "The Reliquary Chest", "journal": "The Grave Vows", "lantern": who if who != "" else "The Lantern"}.get(mode, "")
	U.title(self, title, PW / 2.0, 19, col, 150)
	U.stud(self, PW - 15, 4, 12, 12, "", true, U.TEXT, hover == "close")
	U.text(self, "x", PW - 9, 13, U.MUTED, 0, "pixel", 8, false)
	match mode:
		"vendor":
			_draw_vendor(h)
		"smith":
			_draw_smith(h)
		"stash":
			_draw_stash(h)
		"journal":
			_draw_journal(h)
		"lantern":
			_draw_lantern(h)
	if mode != "journal" and mode != "lantern":
		U.text(self, "Gold: %d" % h.st.inv.gold, PW / 2.0, PH - 12, U.GOLD, 0, "pixel", 8)
	if line_t > 0.0 and line != "":
		U.text(self, line, PW / 2.0, PH - 24, U.RED, 0, "book", 8)

func _draw_vendor(h) -> void:
	U.text(self, U.smart("\"Gold's no use to the dead. They sell cheap. I don't.\""), PW / 2.0, 38, U.MUTED, 0, "book", 7)
	for i in 2:
		var k: String = ["hp", "mp"][i]
		var y := 50 + i * 34
		U.recess(self, 14, y, PW - 28, 30)
		if hover == "buy:" + k:
			U.frame(self, 14, y, PW - 28, 30, Color(U.GOLD_D, 0.7), 0.5)
		var it := Item.make_potion(k)
		hud.draw_item(self, it, U.R(20, y + 3, 12, 24))
		U.text(self, "Draught of Life" if k == "hp" else "Draught of " + h.st.res_name(), 40, y + 13, U.TEXT, -1, "book", 8)
		U.text(self, "%d gold" % SHOP.DRAUGHT_PRICE, PW - 22, y + 13, U.GOLD_D, 1, "pixel", 8)
		U.text(self, "to the belt first, then the pack", 40, y + 24, U.DIM, -1, "pixel", 6)
	U.text(self, "Right-click what you carry to sell it.", PW / 2.0, 132, U.FAINT, 0, "pixel", 7)

func _draw_smith(h) -> void:
	U.text(self, U.smart("\"Iron's honest. It rusts where you can see it.\""), PW / 2.0, 38, U.MUTED, 0, "book", 7)
	var wares: Array = _wares()
	for i in wares.size():
		var it: Item = wares[i]
		var r := _ware_rect(i)
		U.recess(self, r.position.x, r.position.y, r.size.x, r.size.y)
		if hover == "ware:%d" % i:
			U.frame(self, r.position.x, r.position.y, r.size.x, r.size.y, Color(U.GOLD_D, 0.7), 0.5)
		var sc := minf(1.0, 18.0 / (maxf(it.grid.x, it.grid.y) * 12.0))
		hud.draw_item(self, it, U.R(r.position.x + 3, r.position.y + 2, it.grid.x * 12.0 * sc, it.grid.y * 12.0 * sc))
		U.text(self, it.name, r.position.x + 26, r.position.y + 14, it.color(), -1, "book", 7)
		var price := SHOP.ware_price(it)
		U.text(self, "%d" % price, r.end.x - 6, r.position.y + 14, U.GOLD_D if h.st.inv.gold >= price else U.RED, 1, "pixel", 8)
	if wares.is_empty():
		U.text(self, "The rack is bare. Come back when you have grown.", PW / 2.0, 80, U.DIM, 0, "book", 8)

func _draw_stash(h) -> void:
	var s: Array = SHOP.stash()
	for i in SHOP.STASH_MAX:
		var r := _chest_rect(i)
		U.recess(self, r.position.x, r.position.y, r.size.x, r.size.y, Color("#120e10"))
		if i < s.size():
			var it: Item = s[i]
			var sc := minf(1.0, CELL / (maxf(it.grid.x, it.grid.y) * 12.0))
			var w := it.grid.x * 12.0 * sc
			var hh := it.grid.y * 12.0 * sc
			hud.draw_item(self, it, U.R(r.position.x + (CELL - w) / 2.0, r.position.y + (CELL - hh) / 2.0, w, hh))
		if hover == "chest:%d" % i:
			U.frame(self, r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, Color(U.GOLD_D, 0.7), 0.5)
	U.text(self, "%d of %d kept. Right-click what you carry to put it away." % [s.size(), SHOP.STASH_MAX], PW / 2.0, 206, U.FAINT, 0, "pixel", 6)

func _draw_journal(_h) -> void:
	var Q = _Q()
	var rows: Array = Q.journal(1)
	U.text(self, Q.act_name(1), PW / 2.0, 30, U.MUTED, 0, "book", 7)
	for i in rows.size():
		var r := _q_rect(i)
		var e: Dictionary = rows[i]
		var c := U.DIM if e["state"] == "unheard" else (U.FAINT if e["fulfilled"] else U.TEXT)
		if i == sel_q:
			U.rect(self, r.position.x, r.position.y, r.size.x, r.size.y, Color(1, 1, 1, 0.05))
		if hover == "q:%d" % i:
			U.frame(self, r.position.x, r.position.y, r.size.x, r.size.y, Color(U.GOLD_D, 0.5), 0.5)
		U.text(self, ("✠ " if e["fulfilled"] else "· ") + str(e["name"]), r.position.x + 4, r.position.y + 10, c, -1, "book", 8)
		var stt: String = {"unheard": "", "open": "", "opened": "opened", "fulfilled": "fulfilled"}.get(e["state"], "")
		if stt != "":
			U.text(self, stt, r.end.x - 4, r.position.y + 10, U.DIM, 1, "pixel", 6)
	if sel_q < rows.size():
		var e2: Dictionary = rows[sel_q]
		var y := 34 + rows.size() * 15 + 8
		U.rule(self, 14, y - 4, PW - 28, Color(U.GOLD_D, 0.4))
		for ln in U.wrap(U.smart(str(e2["desc"])), PW - 32, "book", 8):
			U.text(self, ln, 16, y + 8, U.TEXT, -1, "book", 8)
			y += 11
		if str(e2["where"]) != "":
			y += 4
			U.text(self, "Where: " + str(e2["where"]), 16, y + 8, U.MUTED, -1, "book", 7)
			y += 11
		if str(e2["progress"]) != "":
			U.text(self, str(e2["progress"]), 16, y + 8, U.MUTED, -1, "book", 7)
			y += 11
		if e2["state"] != "unheard":
			U.text(self, str(e2["reward"]), 16, y + 8, U.GOLD_D, -1, "book", 7)


# ------------------------------------------------------------------ the lantern
func _lanterns() -> Array:
	var d: Dictionary = _Q().state().get("lanterns", {})
	var out := []
	for k in d:
		out.append(d[k])
	return out

func _here(e: Dictionary) -> bool:
	return hud.zone != null and e.get("zone", "") == hud.zone.id and hud.hero and hud.hero.tp.distance_to(Vector2(e["x"], e["y"])) < 4.0

func _draw_lantern(h) -> void:
	var what: String = ("Life, %s and the choir are restored." if "wbeh" in h.skills else "Life and %s are restored.") % h.st.res_name()
	U.text(self, "You rest. " + what, PW / 2.0, 38, U.MUTED, 0, "book", 7)
	U.text(self, "This lantern is where you return if you fall.", PW / 2.0, 50, U.DIM, 0, "book", 7)
	U.text(self, "Travel to:", 14, 68, U.TEXT, -1, "book", 8)
	var ls: Array = _lanterns()
	var Q = _Q()
	for i in ls.size():
		var e: Dictionary = ls[i]
		var here := _here(e)
		var r := Rect2(14, 76 + i * 16, PW - 28, 14)
		U.stud(self, r.position.x, r.position.y, r.size.x, r.size.y, "", not here, U.TEXT, hover == "l:%d" % i)
		U.text(self, "%s · %s" % [str(e.get("name", "A lantern")), Q.zone_name(str(e.get("zone", "")))], r.position.x + 6, r.position.y + 10, U.TEXT if not here else U.DIM, -1, "book", 7)
