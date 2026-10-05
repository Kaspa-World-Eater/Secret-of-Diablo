extends Control
## ui/panel_board.gd: the body board, the Inverted Triune (A). An engraved plate on old paper: the order's body roads,
## the Minor knots along them, the cards at the hands, the crown and the feet, and (v103) the rungs and the Outer Circle
## that join the Majors. Drag to pan, wheel to zoom, 0 for home. Click a knot to lay the road to it; right-click a laid
## leaf knot to lift it for gold. Click a card to read it in the right-hand column, and lay it there upright or reversed;
## held Majors turn at a lantern. Sums lists everything the laid knots add up to.
## State and rules: core/arcana.gd (hero.st.arc).

const U := preload("res://ui/uikit.gd")
const PW := 400
const PH := 192
const BX := 6.0      # the plate's window, logical px
const BY := 24.0
const BW := 262.0
const BH := 150.0
const INKC := Color("#2b2017")
const INK2C := Color("#6b5a44")
const PAPER := Color("#d9ccad")
const RUB := Color("#9a2a1c")
const GOLDK := Color("#b88a2e")
const STATC := {"life": "#a83240", "lok": "#c05060", "bleed": "#7a1a22", "ess": "#3f6f9c", "regen": "#5f93b8", "fcr": "#6a9ab0",
	"wisp": "#8aa8b8", "dmg": "#7a4a9c", "melee": "#a0582a", "armor": "#7a7258", "poise": "#8a8470", "prec": "#9a9070",
	"shard": "#b0a890", "res": "#6a4a9c", "evade": "#7a68a0", "sick": "#5a7a30", "mf": "#b89a40", "frw": "#6a8a6a",
	"sun": "#c0a040", "moon": "#40506a", "vit": "#a03030", "spi": "#3050a0", "con": "#806040"}

var hud: Node
var cen := Vector2.ZERO        # board units at the window's centre
var zoom := 20.0               # screen px per board unit
var hover := ""                # node id under the mouse
var hover_btn := ""
var sel := ""                  # the card being read
var show_sums := false
var drag_from := Vector2(-1, -1)
var drag_cen := Vector2.ZERO
var dragged := false
var msg := ""
var msg_t := 0.0
var _paper: Texture2D          # (instance cache: static Resources crash Godot at exit)

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -PW * U.S / 2.0
	offset_right = PW * U.S / 2.0
	offset_top = 0
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _arc():
	return hud.hero.st.arc if hud.hero and hud.hero.st else null

func open() -> void:
	visible = true
	home(true)
	zoom = minf(zoom, 26.0)

func win() -> Rect2:
	return U.R(BX, BY, BW, BH)

func to_px(n: Dictionary) -> Vector2:
	var w := win()
	return w.get_center() + (Vector2(float(n["x"]), float(n["y"])) - cen) * zoom

func to_board(p: Vector2) -> Vector2:
	return cen + (p - win().get_center()) / zoom

## home: the whole plate (all = true) or just the part you hold and can reach
func home(mine: bool) -> void:
	var a = _arc()
	if a == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in a.N:
		var n: Dictionary = a.N[id]
		if mine and not (a.laid.has(id) or a.cards.has(id) or n["kind"] == "root" or a.reachable(id)):
			continue
		var p := Vector2(float(n["x"]), float(n["y"]))
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	if lo.x == INF:
		return
	cen = (lo + hi) / 2.0
	var w := win()
	zoom = clampf(minf(w.size.x / maxf(8.0, hi.x - lo.x + 4.0), w.size.y / maxf(8.0, hi.y - lo.y + 4.0)), 6.0, 60.0)

func _say(s: String) -> void:
	msg = s
	msg_t = 2.5

func _at_lantern() -> bool:
	if hud.p_town and hud.p_town.visible and hud.p_town.mode == "lantern":
		return true
	if hud.zone and hud.hero:
		for L in hud.zone.lanterns:
			if hud.hero.tp.distance_to(Vector2(L["x"], L["y"])) < 3.0:
				return true
	return false

# ------------------------------------------------------------------ input
func _process(dt: float) -> void:
	if not visible:
		return
	msg_t = maxf(0.0, msg_t - dt)
	var m: Vector2 = hud.mouse_in(self)
	hover = ""
	hover_btn = _btn_at(m / U.S)
	if win().has_point(m) and not dragged:
		var a = _arc()
		var best := ""
		var bd := 14.0 + zoom * 0.25
		for id in a.N:
			var d := to_px(a.N[id]).distance_to(m)
			if d < bd:
				bd = d
				best = id
		hover = best
	queue_redraw()

func _btns() -> Array:
	var out := [["sums", "Sums", BX + BW - 150, BY + BH + 4, 48], ["mine", "Mine", BX + BW - 98, BY + BH + 4, 44], ["whole", "Whole", BX + BW - 50, BY + BH + 4, 50]]
	var a = _arc()
	if a and sel != "" and a.is_card(sel):
		var d: Dictionary = a.card_def(sel)
		if a.cards.has(sel):
			if d.has("rev"):
				out.append(["turn", "Turn it", 276, PH - 22, 54])
				if a.cards.get("v_unmade", "") == "u" and d.get("kind", "") in ["major", "hybrid"]:
					out.append(["both", "Both" if a.both != sel else "One way", 332, PH - 22, 54])
		elif a.card_why_not(sel) == "":
			if d.has("rev"):
				out.append(["up", "Lay upright", 276, PH - 22, 54])
				out.append(["rev", "Reversed", 332, PH - 22, 54])
			else:
				out.append(["up", "Lay it", 276, PH - 22, 110])
	out.append(["close", "", PW - 15, 4, 12])
	return out

func _btn_at(lp: Vector2) -> String:
	for b in _btns():
		if Rect2(b[2], b[3], b[4], 12).has_point(lp):
			return b[0]
	return ""

func _gui_input(ev: InputEvent) -> void:
	var a = _arc()
	if a == null:
		return
	if ev is InputEventMouseButton:
		accept_event()
		var mb := ev as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := to_board(mb.position)
			zoom = clampf(zoom * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 6.0, 70.0)
			cen += before - to_board(mb.position)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if hover_btn != "":
					_button(hover_btn)
					return
				if win().has_point(mb.position):
					drag_from = mb.position
					drag_cen = cen
					dragged = false
			else:
				if drag_from.x >= 0 and not dragged and hover != "":
					_click(hover)
				drag_from = Vector2(-1, -1)
				dragged = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and hover != "" and a.is_knot(hover):
			var why: String = a.lift(hover)
			_say(why if why != "" else "Lifted.")
			_changed()
	elif ev is InputEventMouseMotion and drag_from.x >= 0:
		if (ev.position - drag_from).length() > 6.0:
			dragged = true
		if dragged:
			cen = drag_cen - (ev.position - drag_from) / zoom

func _unhandled_key_input(ev: InputEvent) -> void:
	if visible and ev.pressed and not ev.echo and ev.keycode == KEY_0:
		home(false)

func _click(id: String) -> void:
	var a = _arc()
	if a.is_card(id):
		sel = id
		return
	if a.is_knot(id):
		if a.laid.has(id):
			_say("Already laid.")
			return
		var road: Array = a.road_to(id)
		if road.is_empty():
			_say("No road reaches it.")
		elif road.size() > a.minor_avail():
			_say("The road needs %d Minor; you have %d." % [road.size(), a.minor_avail()])
		else:
			a.lay(id)
			_changed()

func _button(b: String) -> void:
	var a = _arc()
	match b:
		"close":
			visible = false
		"sums":
			show_sums = not show_sums
		"mine":
			home(true)
		"whole":
			home(false)
		"up", "rev":
			if a.take_card(sel, "u" if b == "up" else "r"):
				_changed()
			else:
				_say(a.card_why_not(sel))
		"both":
			a.both = "" if a.both == sel else sel
			_say("Unmade: it counts both ways." if a.both == sel else "It counts one way again.")
			_changed()
		"turn":
			if not _at_lantern():
				_say("A Major turns only by a lantern's light.")
			elif a.flip(sel):
				_say("Turned.")
				_changed()

func _changed() -> void:
	var h = hud.hero
	h.st.hp = minf(h.st.hp, h.st.life_max())
	h.stats_changed.emit()

func tip() -> Array:
	var a = _arc()
	if a == null or hover == "" or not a.N.has(hover):
		return []
	var n: Dictionary = a.N[hover]
	var out: Array = []
	if a.is_card(hover):
		var d: Dictionary = a.card_def(hover)
		out.append([str(d.get("name", n["name"])), Color("#e8d6a0") if d.get("kind", "") in ["major", "hybrid", "void"] else U.TEXT])
		out.append([_kind_name(d.get("kind", "")), U.MUTED])
		out.append(["Click to read it", U.FAINT])
		return out
	out.append([str(n["name"]), GOLDK if n["kind"] == "notable" else U.TEXT])
	out.append([str(n.get("area", "")), U.DIM])
	for k in n.get("fx", {}):
		out.append([fx_text(k, float(n["fx"][k])), U.BLUE])
	if str(n.get("lore", "")) != "":
		out.append([str(n["lore"]), U.MUTED])
	if a.is_knot(hover):
		if a.laid.has(hover):
			out.append(["Right-click to lift it (%d gold)" % a.lift_cost() if a.can_lift(hover) else "Something you hold rests on it", U.FAINT])
		else:
			var r: Array = a.road_to(hover)
			if r.is_empty():
				out.append(["No road reaches it yet", U.FAINT])
			else:
				out.append(["Click to lay: %d Minor" % r.size(), U.GOLD_D if r.size() <= a.minor_avail() else U.RED])
	return out

static func _kind_name(k: String) -> String:
	return {"major": "Major Arcanum", "minor": "Minor Arcanum", "hybrid": "A borrowed god's card", "void": "The Void", "hollow": "A hollow step"}.get(k, "Arcanum")

func fx_text(k: String, v: float) -> String:
	var rn: String = hud.hero.st.res_name() if hud.hero else "Essence"
	var s := ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)
	var T := {"life": "+%s%% maximum life", "ess": "+%s%% maximum " + rn, "regen": "+%s%% " + rn + " regained", "armor": "+%s armor",
		"poise": "+%s poise", "prec": "+%s%% poise recovery", "shard": "+%s bone shard held", "dmg": "+%s%% skill damage",
		"melee": "+%s%% melee damage", "fcr": "+%s%% faster casting", "wisp": "+%s%% faster wisp regrowth", "res": "+%s%% magic resist",
		"mf": "+%s%% magic find", "frw": "+%s%% faster walking", "lok": "+%s life on kill", "bleed": "+%s%% bleeding damage",
		"sick": "+%s%% sickness damage", "evade": "+%s%% chance a blow misses you", "sun": "+%s%% skill damage under an open sky by day",
		"moon": "+%s%% melee damage in the dark", "vit": "+%s Vitality", "spi": "+%s Essence", "con": "+%s Constitution"}
	return str(T.get(k, "+%s " + k)) % s

# ------------------------------------------------------------------ drawing
func paper_tex() -> Texture2D:
	if _paper:
		return _paper
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.03
	var nz2 := FastNoiseLite.new()
	nz2.frequency = 0.25
	for y in 256:
		for x in 256:
			var v := 0.5 + 0.5 * nz.get_noise_2d(x, y) * 0.9 + nz2.get_noise_2d(x, y) * 0.12
			var c := PAPER.darkened(0.16 * (1.0 - v)).lightened(0.05 * v)
			img.set_pixel(x, y, c)
	_paper = ImageTexture.create_from_image(img)
	return _paper

func _draw() -> void:
	var a = _arc()
	if a == null:
		return
	var col := U.cls_col(hud.hero.st.cls)
	U.page(self, 0, 0, PW, PH, col)
	U.text(self, "The Inverted Triune", 10, 17, U.TEXT, -1, "sc", 14)
	U.text(self, "Major %d   Minor %d" % [a.major_avail(), a.minor_avail()], 180, 16, U.GOLD, -1, "pixel", 8)
	U.text(self, "%d laid · %d held" % [a.minor_spent(), a.cards.size()], 300, 16, U.MUTED, -1, "pixel", 7)
	# the plate's window
	var w := win()
	draw_rect(w.grow(4), Color("#050407"))
	draw_texture_rect(paper_tex(), w, true)
	_plate(a, w)
	_roads(a, w)
	_nodes(a, w)
	# the buttons
	for b in _btns():
		if b[0] == "close":
			U.stud(self, b[2], b[3], b[4], 12, "", true, U.TEXT, hover_btn == "close")
			U.text(self, "x", b[2] + 6, b[3] + 9, U.MUTED, 0, "pixel", 8, false)
		else:
			var on: bool = (b[0] != "sums") or show_sums
			U.stud(self, b[2], b[3], b[4], 12, b[1], true, U.TEXT if on else U.MUTED, hover_btn == b[0])
	_reader(a)
	if msg_t > 0.0:
		U.text(self, msg, BX + BW / 2.0, BY + 10, RUB, 0, "book", 8)

func _plate(a, w: Rect2) -> void:
	# the circle of the old plates and its degree marks, faint
	var c := w.get_center() + (Vector2(0, -1.2 * 1.6) - cen) * zoom
	for r in [16.9 * 1.6, 17.35 * 1.6]:
		draw_arc(c, r * zoom, 0, TAU, 128, Color(INK2C, 0.35), 1.0, true)
	for i in 72:
		var ang := i / 72.0 * TAU
		var r0 := 17.35 * 1.6 if i % 6 == 0 else 17.1 * 1.6
		draw_line(c + Vector2(cos(ang), sin(ang)) * 16.9 * 1.6 * zoom, c + Vector2(cos(ang), sin(ang)) * r0 * zoom, Color(INK2C, 0.35), 1.0)
	# the body's roads as the plate's own engraving (a pale double line under the roads)
	var P: Dictionary = a.plate()
	for p in P.get("paths", []):
		var pts := PackedVector2Array()
		for q in p["pts"]:
			pts.append(w.get_center() + (Vector2(q[0], q[1]) * 1.6 - cen) * zoom)
		if p.get("closed", false) and pts.size() > 0:
			pts.append(pts[0])
		if pts.size() > 1:
			# the body's mass first (a broad pale wash), then the engraved line along it
			var mass := 1.1 if str(p.get("name", "")).find("Circle") < 0 else 0.0
			if mass > 0.0:
				draw_polyline(pts, Color(INK2C, 0.07), zoom * mass * 1.6, true)
			draw_polyline(pts, Color(INK2C, 0.22), maxf(2.0, zoom * 0.3), true)

func _roads(a, w: Rect2) -> void:
	var road: Array = a.road_to(hover) if hover != "" and a.is_knot(hover) else []
	var onroad := {}
	for k in road:
		onroad[k] = true
	var A: Dictionary = a.anchors()
	for id in a.N:
		var n: Dictionary = a.N[id]
		var p := to_px(n)
		for l in n["links"]:
			if l < id or not a.N.has(l):
				continue
			var q := to_px(a.N[l])
			if not w.grow(40).has_point(p) and not w.grow(40).has_point(q):
				continue
			var held: bool = (a.laid.has(id) or A.has(id)) and (a.laid.has(l) or A.has(l))
			var pre: bool = (onroad.has(id) or a.laid.has(id) or A.has(id)) and (onroad.has(l) or a.laid.has(l) or A.has(l)) and (onroad.has(id) or onroad.has(l))
			var circ: bool = str(n.get("area", "")) == "The Outer Circle" or str(a.N[l].get("area", "")) == "The Outer Circle"
			var c := GOLDK if held else (RUB if pre else Color(INKC, 0.55 if circ else 0.75))
			draw_line(_clip(p, w), _clip(q, w), c, maxf(1.5, zoom * (0.16 if held else 0.09)), true)

func _clip(p: Vector2, w: Rect2) -> Vector2:
	return Vector2(clampf(p.x, w.position.x, w.end.x), clampf(p.y, w.position.y, w.end.y))

func _nodes(a, w: Rect2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var blink := sin(t * 4.0) > 0.0
	var road: Array = a.road_to(hover) if hover != "" and a.is_knot(hover) else []
	var ma: int = a.minor_avail()
	for id in a.N:
		var n: Dictionary = a.N[id]
		var p := to_px(n)
		if not w.has_point(p):
			continue
		var k: String = n["kind"]
		if k == "card":
			_card(a, id, p, blink)
			continue
		var r := maxf(3.0, zoom * (0.42 if k == "root" else (0.34 if k == "notable" else 0.22)))
		var held: bool = a.laid.has(id)
		var fx: Dictionary = n.get("fx", {})
		var st: String = str(fx.keys()[0]) if not fx.is_empty() else ""
		var tint := Color(STATC.get(st, "#6b5a44"))
		if a.reachable(id) and ma > 0:
			draw_arc(p, r + 3.0, 0, TAU, 20, RUB if blink else Color("#c0503a"), 1.5, true)
		if road.has(id):
			draw_arc(p, r + 4.0, 0, TAU, 20, RUB, 2.0, true)
		draw_circle(p, r + 1.0, INKC)
		if k == "root":
			draw_circle(p, r, Color("#20305a"))
			draw_circle(p, r * 0.55, Color("#6a8ac0"))
		else:
			draw_circle(p, r, GOLDK if held else Color("#cbbb96"))
			draw_circle(p, maxf(1.0, r * 0.45), tint if not held else Color("#5a1a10"))
		if id == hover:
			draw_arc(p, r + 5.0, 0, TAU, 24, INKC, 1.5, true)

func _card(a, id: String, p: Vector2, blink: bool) -> void:
	var d: Dictionary = a.card_def(id)
	var kind: String = d.get("kind", "minor")
	var big: bool = kind in ["major", "hybrid", "void"]
	var sz := Vector2(0.55, 0.8) * zoom * (1.25 if big else 0.85)
	sz = Vector2(maxf(sz.x, 6.0), maxf(sz.y, 9.0))
	var r := Rect2(p - sz / 2.0, sz)
	var held: bool = a.cards.has(id)
	if a.card_why_not(id) == "" and not held:
		draw_rect(r.grow(3), RUB if blink else Color("#c0503a"), false, 1.5)
	draw_rect(r.grow(1), INKC)
	var face := Color("#2a1c2e") if kind == "void" else (Color("#5a1a14") if big else Color("#23324a"))
	draw_rect(r, face if held else Color("#e2d5b4"))
	if held:
		# the card's sign: a small triangle, point up upright, down reversed
		var up: bool = a.cards[id] != "r"
		var c := r.get_center()
		var s := sz.x * 0.28
		var tri := PackedVector2Array([c + Vector2(0, -s if up else s), c + Vector2(-s, s if up else -s), c + Vector2(s, s if up else -s)])
		draw_colored_polygon(tri, Color("#e8d6a0"))
	else:
		draw_rect(r.grow(-2), Color(INK2C, 0.6), false, 1.0)
	if id == sel:
		draw_rect(r.grow(4), INKC, false, 2.0)
	if id == hover:
		draw_rect(r.grow(5), Color("#fff4d8"), false, 1.5)

func _reader(a) -> void:
	var x := 272.0
	var y := 32.0
	var wd := PW - x - 8.0
	U.recess(self, x - 4, BY, wd + 4, BH + 16, Color("#141016"))
	if show_sums:
		U.text(self, "What the laid knots give", x, y + 4, U.GOLD_D, -1, "book", 8)
		y += 16
		var S: Dictionary = a.sums()
		if S.is_empty():
			U.text(self, "Nothing yet.", x, y, U.DIM, -1, "book", 8)
		for k in S:
			U.text(self, fx_text(k, float(S[k])), x, y, U.BLUE, -1, "book", 7)
			y += 10
		return
	if sel != "" and a.is_card(sel):
		var d: Dictionary = a.card_def(sel)
		var held: bool = a.cards.has(sel)
		U.text(self, str(d.get("name", sel)), x, y + 4, Color("#e8d6a0"), -1, "sc", 10)
		y += 14
		U.text(self, _kind_name(d.get("kind", "")) + (" · held " + ("reversed" if a.cards[sel] == "r" else "upright") if held else ""), x, y, U.MUTED, -1, "book", 7)
		y += 12
		for part in [["Upright", "up"], ["Reversed", "rev"]]:
			if not d.has(part[1]):
				continue
			var on: bool = not held or (a.cards[sel] == ("r" if part[1] == "rev" else "u"))
			if d.has("rev"):
				U.text(self, part[0], x, y, U.GOLD_D if on else U.DIM, -1, "pixel", 7)
				y += 9
			for ln in U.wrap(str(d[part[1]]), wd - 4, "book", 7):
				U.text(self, ln, x, y, U.TEXT if on else U.DIM, -1, "book", 7)
				y += 9
			y += 4
		if not held:
			var why: String = a.card_why_not(sel)
			if why != "":
				U.text(self, why, x, PH - 14, RUB, -1, "book", 7)
		elif d.has("rev") and not _at_lantern():
			U.text(self, "It turns by a lantern's light.", x, PH - 26, U.DIM, -1, "book", 7)
		return
	var lines := [
		"One board: your body. The Minor and Major Arcana lie on the same roads, out from the gate at your order's seat.",
		"Each level gives one Minor Arcanum to lay. A Major Arcanum is won from bosses, guardians and hidden shrines. Either can be laid once a road reaches it.",
		"A Major you hold is a place a road may carry on from: its rungs lead to its sisters, and the Outer Circle to the other pages.",
		"Click a knot to lay the road to it. Right-click a laid knot to lift it for gold. Drag to look about; the wheel draws near."]
	for para in lines:
		for ln in U.wrap(para, wd - 4, "book", 7):
			U.text(self, ln, x, y, U.MUTED, -1, "book", 7)
			y += 9
		y += 5
