extends Control
## ui/panel_orders.gd: the Hollow Mystic's two order pages (e_ui.js, zz_zz_mystic90.js), on the left page:
##   choir (V)  the four chances of a wisp strike, and the wisps' orders: a grid from Close to Roam (how far they range)
##              and from Guard to Attack (how readily they dive), with Attack my target and Hold fire
##   golem (G)  the golem's orders grid, charge / shield toss / focus / hold, and the weapon it carries
## Reads and writes the order's skill book (skills/animancer.gd wbeh, gbeh, gweapon, chances()).

const U := preload("res://ui/uikit.gd")
const PW := 236
const PH := 240
const GX := 34.0
const GY := 40.0
const GC := 18.0

var hud: Node
var mode := "choir"
var hover := ""

func _ready() -> void:
	offset_right = PW * U.S
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _book():
	return hud.hero.skills if hud.hero and hud.hero.skills and "wbeh" in hud.hero.skills else null

func _beh() -> Dictionary:
	var b = _book()
	if b == null:
		return {}
	return b.wbeh if mode == "choir" else b.gbeh

func _process(_dt: float) -> void:
	if visible:
		hover = _at(hud.mouse_in(self) / U.S)
		queue_redraw()

func _toggles() -> Array:
	if mode == "choir":
		return [["focus", "Mark my foe"], ["hold", "Hold fire"]]
	return [["charge", "Shield charge"], ["toss", "Shield toss"], ["focus", "Mark my foe"], ["hold", "Hold ground"]]

func _at(lp: Vector2) -> String:
	if Rect2(PW - 15, 4, 12, 12).has_point(lp):
		return "close"
	for x in 5:
		for y in 5:
			if Rect2(GX + x * GC, GY + (4 - y) * GC, GC - 2, GC - 2).has_point(lp):
				return "g:%d,%d" % [x, y]
	var tg := _toggles()
	for i in tg.size():
		if Rect2(136, 40 + i * 18, 90, 14).has_point(lp):
			return "t:" + tg[i][0]
	if mode == "golem":
		var ks := ["sword", "axe", "flail"]
		for i in 3:
			if Rect2(136, 130 + i * 18, 90, 14).has_point(lp):
				return "w:" + ks[i]
	return ""

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var b = _book()
	if b == null:
		return
	var beh := _beh()
	if hover == "close":
		visible = false
	elif hover.begins_with("g:"):
		var p := hover.substr(2).split(",")
		beh["x"] = int(p[0])
		beh["y"] = int(p[1])
	elif hover.begins_with("t:"):
		var k := hover.substr(2)
		if mode == "golem" and k == "hold":
			b.set_golem_hold(not beh["hold"])
		else:
			beh[k] = not beh.get(k, false)
	elif hover.begins_with("w:"):
		b.gweapon = hover.substr(2)
		Bus.say.emit("The golem takes up the %s." % b.WEAPON_NAMES[b.gweapon], 1.6)

func tip() -> Array:
	var b = _book()
	if b == null:
		return []
	if hover.begins_with("g:"):
		var p := hover.substr(2).split(",")
		var x := int(p[0])
		var y := int(p[1])
		var reach: String = ["close by you", "near you", "a little way off", "well away", "far out"][x]
		var how: String = ["only what threatens you", "what comes near", "what they can reach", "readily", "anything in sight"][y]
		return [[("Wisps" if mode == "choir" else "The golem") + " range " + reach + " and fight " + how + ".", U.TEXT]]
	if hover.begins_with("w:"):
		var k := hover.substr(2)
		var tx := {"sword": "Fast; may strike twice.", "axe": "A cleaving arc through everything in front.", "flail": "Long reach; the blow splashes and staggers."}
		return [[b.WEAPON_NAMES[k], U.TEXT], [tx[k], U.MUTED]]
	return []

func _draw() -> void:
	var b = _book()
	if b == null:
		return
	var col := U.cls_col("animancer")
	U.page(self, 0, 0, PW, PH, col)
	U.title(self, "The Choir" if mode == "choir" else "The Golem", PW / 2.0, 19, col, 110)
	U.stud(self, PW - 15, 4, 12, 12, "", true, U.TEXT, hover == "close")
	U.text(self, "x", PW - 9, 13, U.MUTED, 0, "pixel", 8, false)
	var beh := _beh()
	# the grid: Close..Roam across, Guard..Attack up
	U.text(self, "Attack", GX - 4, GY + 8, U.MUTED, 1, "pixel", 6)
	U.text(self, "Guard", GX - 4, GY + 4 * GC + 12, U.MUTED, 1, "pixel", 6)
	U.text(self, "Close", GX, GY + 5 * GC + 8, U.MUTED, -1, "pixel", 6)
	U.text(self, "Roam", GX + 5 * GC - 2, GY + 5 * GC + 8, U.MUTED, 1, "pixel", 6)
	for x in 5:
		for y in 5:
			var r := Rect2(GX + x * GC, GY + (4 - y) * GC, GC - 2, GC - 2)
			var on: bool = int(beh.get("x", 2)) == x and int(beh.get("y", 2)) == y
			U.recess(self, r.position.x, r.position.y, r.size.x, r.size.y, Color("#1a1518") if not on else Color(col, 0.35))
			if hover == "g:%d,%d" % [x, y]:
				U.frame(self, r.position.x, r.position.y, r.size.x, r.size.y, Color(U.GOLD_D, 0.7), 0.5)
	var tg := _toggles()
	for i in tg.size():
		var k: String = tg[i][0]
		U.stud(self, 136, 40 + i * 18, 90, 14, tg[i][1], bool(beh.get(k, false)), U.TEXT, hover == "t:" + k)
	if mode == "choir":
		var ch: Dictionary = b.chances()
		var y := 164.0
		U.rule(self, 14, y - 10, PW - 28, Color(U.GOLD_D, 0.4))
		var names := {"thread": "A thread snagged", "pass": "Passes on untired", "needle": "A needle through", "split": "A spark splits off"}
		var i := 0
		for k in ["thread", "pass", "needle", "split"]:
			var xx := 16.0 + (i % 2) * 108.0
			var yy := y + (i / 2) * 14.0
			U.text(self, names[k], xx, yy, U.MUTED if ch[k] > 0.0 else U.DIM, -1, "book", 7)
			U.text(self, "%d%%" % roundi(ch[k] * 100.0), xx + 100, yy, U.TEXT if ch[k] > 0.0 else U.DIM, 1, "pixel", 7)
			i += 1
		U.text(self, "Wisps %d of %d" % [b.wisps.size(), b.wisp_cap()], PW / 2.0, 224, U.FAINT, 0, "pixel", 7)
	else:
		var g = b.golem
		var st: String = "Not called" if g == null else ("Dormant, rising in %d s" % ceili(g.rt) if g.state == "dormant" else "Standing, %d of %d life" % [roundi(g.hp), roundi(g.max_hp)])
		U.text(self, "Carries:", 136, 124, U.DIM, -1, "pixel", 6)
		U.text(self, st, PW / 2.0, 200, U.MUTED, 0, "book", 8)
		var ks := ["sword", "axe", "flail"]
		for i2 in 3:
			var k2: String = ks[i2]
			U.stud(self, 136, 130 + i2 * 18, 90, 14, b.WEAPON_NAMES[k2], b.gweapon == k2, U.TEXT, hover == "w:" + k2)
