extends Control
## ui/panel_skills.gd: the skill page (S), after zz_ui.js drawSkills: the grimoire. Three carved tabs (the order's
## trees), a D2 grid of 6 rows x 3 columns (rows open at levels 1/6/12/18/24/30, numerals in the margin), prerequisite
## channels that light when the parent is learned, a 24 px engraved icon per skill (lit, dim, locked), the level plate and
## perk pips. Click learns a point; right-click puts a learned skill on the right button (shift: the left); hover and
## press a key to bind it.

const U := preload("res://ui/uikit.gd")
const PW := 236
const PH := 240
const ROWREQ := [1, 6, 12, 18, 24, 30]

var hud: Node
var tab := 0
var hover := ""          # "close", "tab0".., "more", "skill:<id>"
var more := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():   # tests: --skilltab=N opens that tree
		if a.begins_with("--skilltab="):
			tab = int(a.substr(11))
	offset_right = PW * U.S
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

static func col_x(c: int) -> float:
	return 30.0 + c * 58.0

static func row_y(r: int) -> float:
	return 42.0 + r * 31.0

func _skills() -> SkillBook:
	return hud.hero.skills if hud.hero else null

func _ids(t: int) -> Array:
	var sb := _skills()
	var out: Array = []
	if sb == null:
		return out
	for id in sb.data:
		if int(sb.data[id].get("tab", 0)) == t:
			out.append(id)
	return out

func _cell(s: Dictionary) -> Vector2:
	return Vector2(col_x(int(s.get("col", 1)) - 1), row_y(int(s.get("row", 1)) - 1))

func _process(_dt: float) -> void:
	if visible:
		hover = _at(hud.mouse_in(self) / U.S)
		queue_redraw()

func _at(lp: Vector2) -> String:
	if Rect2(PW - 15, 4, 12, 12).has_point(lp):
		return "close"
	for t in 3:
		if Rect2(182, 44 + t * 46, 44, 42).has_point(lp):
			return "tab%d" % t
	if Rect2(184, 202, 44, 12).has_point(lp):
		return "more"
	var sb := _skills()
	if sb:
		for id in _ids(tab):
			var c := _cell(sb.data[id])
			if Rect2(c.x - 12, c.y - 12, 24, 24).has_point(lp):
				return "skill:" + id
	return ""

func hovered_skill() -> String:
	return hover.substr(6) if hover.begins_with("skill:") else ""

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	accept_event()
	if not ev.pressed:
		return
	var what := _at(ev.position / U.S)
	var sb := _skills()
	if sb == null:
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if what == "close":
			hud.toggle_panel("skills")
		elif what.begins_with("tab"):
			tab = int(what.substr(3))
		elif what == "more":
			more = not more
		elif what.begins_with("skill:"):
			var id := what.substr(6)
			if not hud.learn(id):
				var s: Dictionary = sb.data[id]
				if sb.hard.get(id, 0) >= int(s.get("max_hard_level", 20)):
					pass
				elif hud.hero.st.level < int(s.get("required_level", 1)):
					Bus.say.emit("Not yet. Level %d." % int(s.get("required_level", 1)), 1.4)
				elif not _pre_ok(sb, s):
					Bus.say.emit("It rests on %s." % ", ".join(s.get("prerequisite_names", [])), 1.4)
	elif ev.button_index == MOUSE_BUTTON_RIGHT and what.begins_with("skill:"):
		var id := what.substr(6)
		var k: String = sb.data[id].get("kind", "cast")
		if sb.lvl(id) > 0 and k != "passive":
			if Input.is_key_pressed(KEY_SHIFT):
				sb.left = id
			else:
				sb.right = id
			hud.hero.stats_changed.emit()

func _pre_ok(sb: SkillBook, s: Dictionary) -> bool:
	for p in s.get("prerequisites", []):
		if sb.hard.get(p, 0) <= 0:
			return false
	return true

func tip() -> Array:
	match hover:
		"close":
			return [["Close (S)", U.TEXT]]
		"more":
			return [["Tooltip detail", U.TEXT], ["Perks, synergies and the next level", U.MUTED], ["Holding shift shows them too", U.DIM]]
	if hover.begins_with("tab"):
		var sb := _skills()
		var t := int(hover.substr(3))
		var n := 0
		for id in _ids(t):
			n += int(sb.hard.get(id, 0))
		return [[_tab_names()[t], U.tab_col(sb.cls, t)], ["%d points spent here" % n, U.MUTED]]
	var id := hovered_skill()
	if id != "":
		return hud.skill_tip(id, more) + [["Click: learn · Right: use · Key: bind", U.FAINT]]
	return []

func _tab_names() -> Array:
	var sb := _skills()
	var tabs: Array = Data.table("classes").get("classes", {}).get(sb.cls, {}).get("tabs", ["I", "II", "III"])
	return tabs

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var sb := _skills()
	if sb == null:
		return
	var st: HeroStats = hud.hero.st
	var ccol := U.cls_col(sb.cls)
	var col := U.tab_col(sb.cls, tab)
	var names := _tab_names()
	U.page(self, 0, 0, PW, PH, ccol)
	U.stud(self, PW - 15, 4, 12, 12, "", true, U.TEXT, hover == "close")
	U.text(self, "x", PW - 9, 13, U.MUTED, 0, "pixel", 8, false)
	U.text(self, names[tab], 20, 19, col, -1, "sc", 16)
	U.rule(self, 20, 23, 156, col)
	# the points plate
	U.stud(self, 182, 8, 44, 28, "", true)
	U.text(self, "POINTS", 204, 17, Color("#8f8a7c"), 0, "pixel", 8, false)
	U.text(self, str(st.skill_points), 204, 33, U.GOLD if st.skill_points > 0 else U.DIM, 0, "sc", 16)
	# the tabs
	for t in 3:
		var y := 44.0 + t * 46
		var on := tab == t
		var tc := U.tab_col(sb.cls, t)
		U.rect(self, 182, y, 44, 42, U.SEAM)
		U.rect(self, 183, y + 1, 42, 40, Color("#2c2632") if on else (Color("#221d25") if hover == "tab%d" % t else Color("#181419")))
		U.rect(self, 183, y + 1, 42, 40, Color(tc, 0.22 if on else 0.08))
		U.rect(self, 183, y + 1, 42, 1, Color("#6a6478") if on else Color("#2e2a36"))
		U.rect(self, 183, y + 1, 1, 40, Color("#6a6478") if on else Color("#2e2a36"))
		U.rect(self, 183, y + 40, 42, 1, Color("#0e0c12"))
		U.rect(self, 224, y + 1, 1, 40, Color("#0e0c12"))
		U.rect(self, 182, y + 4, 2, 34, tc if on else Color(tc, 0.35))
		if on:
			U.rect(self, 178, y + 6, 5, 30, Color("#1a1518"))
			U.rect(self, 178, y + 6, 1, 30, tc)
		var nm: String = names[t]
		var fs := 16.0
		while fs > 7 and U.text_w(nm, "sc", fs) > 39:
			fs -= 1
		U.text(self, nm, 204, y + 21, tc if on else Color("#8f8a7c"), 0, "sc", fs)
		var n := 0
		for id in _ids(t):
			n += int(sb.hard.get(id, 0))
		U.text(self, "%d pts" % n, 204, y + 34, U.GOLD if on else U.DIM, 0, "pixel", 8, false)
	# the tree field, tier numerals in the right margin
	U.recess(self, 8, 27, 170, 193, Color("#161114"))
	for r in 6:
		U.rect(self, 10, row_y(r) + 12, 166, 1, Color(0, 0, 0, 0.18))
		U.rect(self, 163, row_y(r) + 1, 12, 1, Color(col, 0.3))
		U.text(self, str(ROWREQ[r]), 175, row_y(r) - 1, Color(col, 0.55), 1, "pixel", 8, false)
	var ids := _ids(tab)
	for id in ids:
		var s: Dictionary = sb.data[id]
		for p in s.get("prerequisites", []):
			if not sb.data.has(p):
				continue
			var ps: Dictionary = sb.data[p]
			var lit: bool = sb.lvl(p) > 0
			if int(ps.get("tab", 0)) == tab:
				_arrow(ps, s, lit, col)
			else:
				# a prerequisite on another page: a short stub in that page's colour
				var c := _cell(s)
				var pc := U.tab_col(sb.cls, int(ps.get("tab", 0)))
				U.rect(self, c.x - 0.5, c.y - 20, 2, 7, U.SEAM)
				U.rect(self, c.x, c.y - 20, 1, 7, pc if lit else Color(pc, 0.35))
	for id in ids:
		_skill_cell(sb, st, id, col)
	U.text(self, "Click: learn · Right: use · Key: bind", 20, 231, U.DIM, -1, "pixel", 8, false)
	U.stud(self, 184, 202, 44, 12, "LESS" if more else "MORE", true, U.GOLD if more else U.MUTED, hover == "more")

func _arrow(pa: Dictionary, ch: Dictionary, lit: bool, col: Color) -> void:
	var sb := _skills()
	var pcol := int(pa.get("col", 1)) - 1
	var prow := int(pa.get("row", 1)) - 1
	var ccol := int(ch.get("col", 1)) - 1
	var crow := int(ch.get("row", 1)) - 1
	var px := col_x(pcol)
	var py := row_y(prow)
	var cx := col_x(ccol)
	var cy := row_y(crow)
	var between := false
	for id in _ids(tab):
		var s: Dictionary = sb.data[id]
		if int(s.get("col", 1)) - 1 == ccol and int(s.get("row", 1)) - 1 > prow and int(s.get("row", 1)) - 1 < crow:
			between = true
	var pts: PackedVector2Array
	var head: PackedVector2Array
	if pcol == ccol and not between:
		pts = PackedVector2Array([Vector2(px + .5, py + 13), Vector2(cx + .5, cy - 14)])
		head = PackedVector2Array([Vector2(cx - 2.5, cy - 15), Vector2(cx + 3.5, cy - 15), Vector2(cx + .5, cy - 12)])
	else:
		var gy := py + 15.5
		var gx := cx + (-20.5 if ccol >= pcol else 20.5)
		if gx < cx:
			pts = PackedVector2Array([Vector2(px + .5, py + 13), Vector2(px + .5, gy), Vector2(gx, gy), Vector2(gx, cy + .5), Vector2(cx - 14, cy + .5)])
			head = PackedVector2Array([Vector2(cx - 15, cy - 2.5), Vector2(cx - 15, cy + 3.5), Vector2(cx - 12, cy + .5)])
		else:
			pts = PackedVector2Array([Vector2(px + .5, py + 13), Vector2(px + .5, gy), Vector2(gx, gy), Vector2(gx, cy + .5), Vector2(cx + 14, cy + .5)])
			head = PackedVector2Array([Vector2(cx + 15, cy - 2.5), Vector2(cx + 15, cy + 3.5), Vector2(cx + 12, cy + .5)])
	var S := U.S
	var sp := PackedVector2Array()
	var sp1 := PackedVector2Array()
	for p in pts:
		sp.append(p * S)
		sp1.append((p + Vector2(0, 1)) * S)
	draw_polyline(sp, U.SEAM, 3 * S)
	draw_polyline(sp1, Color("#3a322e"), 1 * S)
	if lit:
		draw_polyline(sp, Color(col, 0.28), 3 * S)
		draw_polyline(sp, col, 1 * S)
	else:
		draw_polyline(sp, Color("#1c1618"), 1 * S)
	var hp := PackedVector2Array()
	var c := head[2]
	var hb := PackedVector2Array()
	for q in head:
		hp.append(q * S)
		hb.append((q + Vector2(signf(q.x - c.x) if absf(q.x - c.x) > 0.1 else 0.0, signf(q.y - c.y) if absf(q.y - c.y) > 0.1 else 0.0)) * S)
	draw_colored_polygon(hb, U.SEAM)
	draw_colored_polygon(hp, col if lit else Color("#2a2426"))

func _skill_cell(sb: SkillBook, st: HeroStats, id: String, col: Color) -> void:
	var s: Dictionary = sb.data[id]
	var c := _cell(s)
	var L := sb.lvl(id)
	var hl := int(sb.hard.get(id, 0))
	var ready := st.level >= int(s.get("required_level", 1)) and _pre_ok(sb, s)
	var state := "lit" if L > 0 else ("dim" if ready else "lock")
	var can_add := st.skill_points > 0 and ready and hl < int(s.get("max_hard_level", 20))
	var x := c.x - 12
	var y := c.y - 12
	U.rect(self, x - 1, y - 1, 26, 26, U.SEAM)
	U.rect(self, x, y, 24, 24, Color("#0c0a0e") if state == "lock" else Color("#120f14"))
	U.rect(self, x, y, 24, 1, Color("#08070a"))
	U.rect(self, x, y, 1, 24, Color("#08070a"))
	U.rect(self, x, y + 23, 24, 1, Color("#1c1820") if state == "lock" else Color("#2a2530"))
	U.rect(self, x + 23, y, 1, 24, Color("#1c1820") if state == "lock" else Color("#2a2530"))
	if state == "lit":
		for i in 4:
			U.rect(self, x + 1 + i * 2, y + 1 + i * 2, 22 - i * 4, 22 - i * 4, Color(col, 0.05))
	var ic := U.skill_icon(id, state)
	if ic:
		draw_texture_rect(ic, U.R(x, y, 24, 24), false)
	if hover == "skill:" + id:
		U.rect(self, x, y, 24, 24, Color(1, 1, 1, 0.07))
	if can_add:
		var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		U.frame(self, x - 1, y - 1, 26, 26, Color(U.GOLD_D, k), 0.75)
		for p in [Vector2(x - 1, y - 1), Vector2(x + 23, y - 1), Vector2(x - 1, y + 23), Vector2(x + 23, y + 23)]:
			U.rect(self, p.x, p.y, 2, 2, U.GOLD)
	elif state == "lit":
		U.frame(self, x - 1, y - 1, 26, 26, Color(col, 0.45), 0.5)
	# the bound key
	var key := ""
	for kk in sb.keys:
		if sb.keys[kk] == id:
			key = str(kk).to_upper()
	if key != "" and L > 0:
		U.rect(self, x, y, U.micro_w(key) + 2, 7, Color(0.02, 0.016, 0.027, 0.8))
		U.micro(self, key, x + 1, y + 1, U.GOLD, -1, false)
	# perk pips
	var perks: Array = s.get("perks", [])
	for pi in perks.size():
		var on: bool = hud.perk_on(id, perks[pi])
		U.rect(self, x + 25, y + 1 + pi * 4, 3, 3, U.SEAM)
		U.rect(self, x + 25.5, y + 1.5 + pi * 4, 2, 2, U.GOLD if on else Color("#2a2530"))
	if sb.right == id:
		U.micro(self, "R", x + 1, y + 17, Color("#d8f3ff"))
	elif sb.left == id:
		U.micro(self, "L", x + 1, y + 17, Color("#d8f3ff"))
	# the level plate
	U.rect(self, x + 15, y + 16, 11, 9, U.SEAM)
	U.rect(self, x + 16, y + 17, 9, 7, Color("#1e1a22"))
	U.rect(self, x + 16, y + 17, 9, 1, Color("#3a3446"))
	U.micro(self, str(L), x + 20.5, y + 18, U.BLUE if L > hl else (col if L > 0 else U.FAINT), 0, false)
