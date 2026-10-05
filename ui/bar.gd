extends Control
## ui/bar.gd: the bottom bar (zz_hud55.js / zz_hud54.js / zz_ui_hud.js). Left to right: life orb | left skill | poise and
## the class gauge | belt | menu studs | right skill | resource orb. The carved slab, housing, plaque and serpents are the
## web's own baked PNGs (art/ui/h5*_*.png, 2 art px per logical px); the glass is painted live by ui/orb.gdshader.
## Laid out in logical px (x4 = screen px); the control is 1920x216 anchored bottom-centre, its y0 is logical 216.

const U := preload("res://ui/uikit.gd")
const Y0 := 216.0                 # logical y of the control's top
const ORB_L := Vector2(28, 247)
const ORB_R := Vector2(452, 247)
const ORB_RAD := 19.0
const LSKILL := Vector2(60, 249)
const RSKILL := Vector2(404, 249)
const BELT_X := 188.0
const BELT_Y := 250.0
const MENU_X0 := 270.0
const MENU_X1 := 398.0
const MENU_Y := 250.0
const GX := 86.0
const GW := 96.0
const LIQ := {
	"life": [["#1a0306", "#3a070c", "#5e0e14", "#86161c", "#ad2a26", "#d2503c"], "#e8785a"],
	"vitae": [["#140209", "#2c0610", "#4a0b19", "#6a1324", "#8c1f31", "#b03a46"], "#d46070"],
	"marrow": [["#3c3832", "#5e5a50", "#8a8576", "#b3ad9b", "#d6d0bf", "#f1ede1"], "#fffaf0"],
	"essence": [["#060b1a", "#0d1832", "#172c58", "#24457f", "#3764a6", "#6a98d4"], "#a8c8f0"],
	"miasma": [["#0e0518", "#1e0b2e", "#321545", "#4a2163", "#673386", "#8e57b4"], "#c098e0"],
	"sand": [["#3a1c06", "#6a3610", "#9c5a1a", "#cc862c", "#f0b448", "#ffe08a"], "#ffe08a"]}
const MENU := [["inv", "Inventory (I)"], ["char", "Character (C)"], ["skills", "Skills (S)"], ["map", "Map (Tab)"], ["menu", "Menu (Esc)"]]
const MENU_IDS := ["inv", "char", "skills", "map", "arcana", "menu", "blood", "army", "choir", "gbeh"]

var hud: Node
var glass_l: ColorRect
var glass_r: ColorRect
var front: Control
var t := 0.0
var hover := ""                  # what the mouse is over: "orbL", "skillL", "belt2", "menu:inv", "stats", ...

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -960
	offset_right = 960
	offset_top = -216
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	glass_l = _glass(ORB_L, "life")
	glass_r = _glass(ORB_R, "essence")
	front = Control.new()
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.draw.connect(_draw_front)
	add_child(front)

func _glass(c: Vector2, kind: String) -> ColorRect:
	var g := ColorRect.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.position = (c - Vector2(ORB_RAD, ORB_RAD) - Vector2(0, Y0)) * U.S
	g.size = Vector2(ORB_RAD, ORB_RAD) * 2.0 * U.S
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/orb.gdshader")
	m.set_shader_parameter("N", ORB_RAD * 2.0 * U.S)
	g.material = m
	add_child(g)
	_liquid(g, kind)
	return g

func _liquid(g: ColorRect, kind: String) -> void:
	var l: Array = LIQ.get(kind, LIQ["essence"])
	var m: ShaderMaterial = g.material
	for i in 6:
		m.set_shader_parameter("c%d" % i, Color(l[0][i]))
	m.set_shader_parameter("men", Color(l[1]))
	m.set_shader_parameter("pearl", kind == "marrow")

func res_kind(cls: String) -> String:
	return {"animancer": "essence", "ossumancer": "marrow", "hemomancer": "vitae", "miasmancer": "miasma", "monk": "sand"}.get(cls, "essence")

func set_class(cls: String) -> void:
	_liquid(glass_r, res_kind(cls))

# ------------------------------------------------------------------ hit shape: the slab, the orbs, the arch, the level buttons
func _has_point(p: Vector2) -> bool:
	var lp := p / U.S + Vector2(0, Y0)       # logical
	if lp.y >= 236.0:
		return true
	if lp.distance_to(ORB_L) < 24.0 or lp.distance_to(ORB_R) < 24.0:
		return true
	if lp.x > 223 and lp.x < 257 and lp.y > 219:
		return true
	if hud and hud.picking != "":
		return false
	if _lvl_rect("stats").has_point(lp) and _pts("stats") > 0:
		return true
	if _lvl_rect("skills").has_point(lp) and _pts("skills") > 0:
		return true
	return false

func _lvl_rect(which: String) -> Rect2:
	return Rect2(52, 209, 34, 14) if which == "stats" else Rect2(394, 209, 34, 14)

func _pts(which: String) -> int:
	var h: Hero = hud.hero if hud else null
	if h == null or h.st == null:
		return 0
	return h.st.attr_points if which == "stats" else h.st.skill_points

func _menu_items() -> Array:
	return MENU

func _menu_x(i: int) -> float:
	var n := _menu_items().size()
	var total := n * 16 - 2
	return roundf((MENU_X0 + MENU_X1) / 2.0 - total / 2.0) + i * 16

func _at(lp: Vector2) -> String:
	if lp.distance_to(ORB_L) < 22.0:
		return "orbL"
	if lp.distance_to(ORB_R) < 22.0:
		return "orbR"
	if Rect2(LSKILL, Vector2(18, 18)).has_point(lp):
		return "skillL"
	if Rect2(RSKILL, Vector2(18, 18)).has_point(lp):
		return "skillR"
	for i in 4:
		if Rect2(BELT_X + i * 20, BELT_Y, 16, 16).has_point(lp):
			return "belt%d" % i
	var items := _menu_items()
	for i in items.size():
		if Rect2(_menu_x(i), MENU_Y, 14, 14).has_point(lp):
			return "menu:" + items[i][0]
	if Rect2(84, 236, 314, 5).has_point(lp):
		return "xp"
	if Rect2(GX - 2, 244, GW + 4, 24).has_point(lp):
		return "gauge"
	if _pts("stats") > 0 and _lvl_rect("stats").has_point(lp):
		return "lvl:stats"
	if _pts("skills") > 0 and _lvl_rect("skills").has_point(lp):
		return "lvl:skills"
	return ""

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = _at(ev.position / U.S + Vector2(0, Y0))
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	var what := _at(ev.position / U.S + Vector2(0, Y0))
	accept_event()
	var h: Hero = hud.hero
	if h == null:
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if what == "skillL":
			hud.toggle_picker("L")
		elif what == "skillR":
			hud.toggle_picker("R")
		elif what.begins_with("belt"):
			h.drink(int(what.substr(4)))
		elif what.begins_with("menu:"):
			hud.menu_click(what.substr(5))
		elif what == "lvl:stats":
			hud.toggle_panel("char")
		elif what == "lvl:skills":
			hud.toggle_panel("skills")

func tip() -> Array:
	var h: Hero = hud.hero
	if h == null or hover == "":
		return []
	var st := h.st
	match hover:
		"orbL":
			return [["Life", Color("#e05060")], ["%d / %d" % [ceili(st.hp), roundi(st.life_max())], U.TEXT]]
		"orbR":
			if st.cls == "monk" and "kR" in hud.hero.skills:
				var sb = hud.hero.skills
				return [["The Hourglass", U.cls_col(st.cls)], ["Amber sand %d%% · black sand %d%%" % [roundi(sb.frac(0) * 100.0), roundi(sb.frac(1) * 100.0)], U.TEXT],
					["Radiance pours amber sand down, Absence black sand up.", U.MUTED], ["The fuller a bulb, the weaker its way. It runs back when you rest.", U.MUTED],
					["Radiance at %d%% · Absence at %d%%" % [roundi(sb.sand(0) * 100.0), roundi(sb.sand(1) * 100.0)], U.GOLD_D]]
			return [[st.res_name(), U.cls_col(st.cls)], ["%d / %d" % [ceili(st.res), roundi(st.res_max())], U.TEXT], ["Skills spend it. It seeps back over time.", U.MUTED]]
		"skillL", "skillR":
			var id: String = h.skills.left if hover == "skillL" else h.skills.right
			return hud.skill_tip(id) + [[("Left skill" if hover == "skillL" else "Right skill") + " · click to change", U.DIM]]
		"xp":
			var n := st.xp_to_next()
			return [["Level %d" % st.level, U.GOLD_D], ["Experience %d / %d (%d%%)" % [st.xp, n, int(100.0 * st.xp / maxf(1, n))], U.MUTED]]
		"gauge":
			return [["Poise", U.POISE], ["%d / %d" % [floori(st.poise), roundi(st.poise_max())], U.TEXT], ["Rolling and heavy blows spend it. It refills", U.MUTED], ["when you pause. Low poise makes you heavier.", U.MUTED]]
		"lvl:stats":
			return [["%d stat points to spend" % st.attr_points, U.GOLD_D], ["The character page (C)", U.DIM]]
		"lvl:skills":
			return [["%d skill points to spend" % st.skill_points, U.GOLD_D], ["The skill page (S)", U.DIM]]
	if hover.begins_with("belt"):
		var i := int(hover.substr(4))
		var s = st.inv.belt[i]
		if s == null:
			return []
		var nm := "Healing Draught" if s["kind"] == "hp" else ("Essence Draught" if s["kind"] == "mp" else "Draught")
		return [[nm, U.TEXT], ["%d in this column · press %d or click to drink" % [int(s["n"]), i + 1], U.MUTED]]
	if hover.begins_with("menu:"):
		var id := hover.substr(5)
		for it in _menu_items():
			if it[0] == id:
				var out: Array = [[it[1], U.TEXT]]
				if id == "char" and st.attr_points > 0:
					out.append(["%d stat points to spend" % st.attr_points, U.GOLD_D])
				if id == "skills" and st.skill_points > 0:
					out.append(["%d skill points to spend" % st.skill_points, U.GOLD_D])
				return out
	return []

# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	t += dt
	var h: Hero = hud.hero if hud else null
	if h and h.st:
		var ml: ShaderMaterial = glass_l.material
		ml.set_shader_parameter("fill", clampf(h.st.hp / maxf(1.0, h.st.life_max()), 0, 1))
		ml.set_shader_parameter("t", t)
		var mr: ShaderMaterial = glass_r.material
		if h.cls == "monk" and "kR" in h.skills:
			# the Empty Hand's glass is an hourglass: amber sand below, black sand above
			if mr.shader.resource_path != "res://ui/hourglass.gdshader":
				mr = ShaderMaterial.new()
				mr.shader = load("res://ui/hourglass.gdshader")
				mr.set_shader_parameter("N", ORB_RAD * 2.0 * U.S)
				glass_r.material = mr
			var sb = h.skills
			mr.set_shader_parameter("fR", sb.frac(0))
			mr.set_shader_parameter("fA", sb.frac(1))
			mr.set_shader_parameter("pour", sb.pour_tab if sb.time - sb.pour_t < 0.45 else -1)
			mr.set_shader_parameter("run", sb.time - sb.cast_t >= 0.6)
		else:
			mr.set_shader_parameter("fill", clampf(h.st.res / maxf(1.0, h.st.res_max()), 0, 1))
		mr.set_shader_parameter("t", t)
	if not get_global_rect().has_point(hud.mouse):
		hover = ""
	queue_redraw()
	front.queue_redraw()

func _L(x: float, y: float) -> Vector2:
	return Vector2(x, y - Y0) * U.S

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_L(x, y), Vector2(w, h) * U.S), c)

func _draw() -> void:
	var panel := U.tex("res://art/ui/h55_DP_panel.png")
	if panel:
		draw_texture_rect(panel, Rect2(0, 0, 1920, 216), false)
	var hous := U.tex("res://art/ui/h55_DP_housA.png")
	if hous:
		draw_texture_rect(hous, Rect2(_L(425, 216), Vector2(220, 216)), false)
	var plq := U.tex("res://art/ui/h55_DP_plaqR_png.png")
	if plq:
		draw_texture_rect(plq, Rect2(_L(24, 224), Vector2(1604, 92)), false)
	var h: Hero = hud.hero if hud else null
	if h == null or h.st == null:
		return
	var st := h.st
	_xp_bar(st)
	_skill_well(h, h.skills.left, LSKILL, hover == "skillL")
	_skill_well(h, h.skills.right, RSKILL, hover == "skillR")
	_poise(st, h)
	_belt(st)
	_menu(st)
	_level_buttons(st)

func _draw_front() -> void:
	var fl := U.tex("res://art/ui/h55_DP_frontL_png.png")
	var fr := U.tex("res://art/ui/h55_DP_frontR_png.png")
	if fl:
		front.draw_texture_rect(fl, Rect2(_L(2, 221), Vector2(204, 196)), false)
	if fr:
		front.draw_texture_rect(fr, Rect2(_L(427, 221), Vector2(204, 196)), false)
	var h: Hero = hud.hero if hud else null
	if h == null or h.st == null:
		return
	# the numbers on the carved plaques, in the book face
	_plaque(str(maxi(0, ceili(h.st.hp))), 63.0, h.st.hp / maxf(1, h.st.life_max()) < 0.25 and not h.dead)
	_plaque(str(maxi(0, ceili(h.st.res))), 417.0, false)
	# an orb under a quarter pulses: a ring round the glass and a breath of its colour (zz_polish.js:47-56)
	if not h.dead:
		_crit(ORB_L, h.st.hp / maxf(1.0, h.st.life_max()), "life")
		_crit(ORB_R, h.st.res / maxf(1.0, h.st.res_max()), res_kind(h.cls))

func _crit(c: Vector2, f: float, kind: String) -> void:
	if f >= 0.25:
		return
	var k := 0.55 + 0.45 * sin(t * 7.0)
	var dim := Color((LIQ.get(kind, LIQ["life"]) as Array)[0][3])
	var rr := ORB_RAD + 2.0 + roundf(k * 2.0)
	var p := _L(c.x, c.y)
	front.draw_arc(p, rr * U.S, 0.0, TAU, 48, Color(dim, 0.35 + 0.5 * k), 2.0 * U.S)
	front.draw_circle(p, ORB_RAD * U.S, Color(dim, 0.18 * k))

func _plaque(s: String, cx: float, low: bool) -> void:
	var f := U.font("sc")
	var fs := 30
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := _L(cx, 231.5) - Vector2(w / 2.0, 0)
	front.draw_string(f, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#050403"))
	front.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#f0a080") if low else Color("#e2cfa8"))

func _xp_bar(st: HeroStats) -> void:
	var x0 := 84.0
	var w := 314.0
	var y := 238.5
	var k := clampf(float(st.xp) / maxf(1.0, st.xp_to_next()), 0, 1)
	var fw := roundf(w * k * 2.0) / 2.0
	_r(x0, y, fw, 1.5, Color("#7a5a26"))
	_r(x0, y, fw, 0.5, Color("#d8b060"))
	if fw > 0:
		_r(x0 + fw - 0.5, y, 0.5, 1.5, Color("#f4dc98"))
	for i in range(1, 10):
		_r(x0 + roundf(w * i / 10.0), y, 0.5, 1.5, Color(0.024, 0.02, 0.03, 0.8))

func _skill_well(h: Hero, id: String, at: Vector2, hov: bool) -> void:
	_r(at.x, at.y, 18, 18, Color("#1a1512") if hov else Color("#120f0c"))
	var ic := U.skill_icon(id if id != "" else "attack")
	if ic:
		draw_texture_rect(ic, Rect2(_L(at.x, at.y), Vector2(72, 72)), false)
	# the bound key, top left; the cost, bottom right (dim red when it can't be paid)
	var key := ""
	for k in h.skills.keys:
		if h.skills.keys[k] == id:
			key = str(k).to_upper()
	if key != "" and id != "attack":
		_r(at.x, at.y, U.micro_w(key) + 2, 7, Color(0.024, 0.02, 0.03, 0.85))
		U.micro(self, key, at.x + 1, at.y + 1 - Y0, U.GOLD_D, -1, false)
	if id != "attack" and id != "" and h.skills.data.has(id):
		var c := h.skills.cost(id)
		var pc := h.skills.poise_cost(id)
		var s := ""
		var col := U.cls_col(h.st.cls)
		var ok := true
		if c > 0.0:
			s = str(maxi(1, roundi(c)))
			ok = h.st.res >= c - 0.001 or h.st.cls == "hemomancer"
		elif pc > 0.0:
			s = str(roundi(pc))
			col = U.POISE
		if s != "":
			if not ok:
				_r(at.x, at.y, 18, 18, Color(0.47, 0.04, 0.08, 0.55))
			var w := U.micro_w(s)
			_r(at.x + 16 - w, at.y + 11, w + 2, 7, Color(0.024, 0.02, 0.03, 0.85))
			U.micro(self, s, at.x + 17, at.y + 12 - Y0, col if ok else Color("#ff5a4a"), 1, false)

func _poise(st: HeroStats, h: Hero) -> void:
	var k := clampf(st.poise / maxf(1, st.poise_max()), 0, 1)
	var y := 247.0
	_r(GX - 1, y - 1, GW + 2, 4, Color("#060508"))
	_r(GX, y, GW, 2, Color("#1a2014"))
	_r(GX, y, roundf(GW * k), 2, Color("#b0a040") if k < 0.1 else Color("#6b8a4a"))
	_r(GX, y, roundf(GW * k), 1, U.POISE)
	# the class gauge, if the order's skill book offers one: {text, pips, max, col}
	var g := {}
	if h.skills and h.skills.has_method("hud_gauge"):
		g = h.skills.hud_gauge()
	if not g.is_empty():
		var n := int(g.get("max", 0))
		var on := int(g.get("pips", 0))
		var col: Color = g.get("col", U.cls_col(st.cls))
		for i in mini(n, 16):
			var x := GX + 2 + i * 6
			_r(x - 1, 252, 5, 5, Color("#0a090d"))
			_r(x, 253, 3, 3, col if i < on else Color("#2a2833"))
		U.micro(self, str(g.get("text", "")), GX, 260 - Y0, U.TEXT)
	else:
		# the resource and poise, read plainly
		if st.cls == "monk" and "kR" in hud.hero.skills:
			U.micro(self, "Amber %d%% Black %d%%" % [roundi(hud.hero.skills.frac(0) * 100.0), roundi(hud.hero.skills.frac(1) * 100.0)], GX, 252 - Y0, U.cls_col(st.cls))
		else:
			U.micro(self, "%s %d/%d" % [st.res_name(), ceili(st.res), roundi(st.res_max())], GX, 252 - Y0, U.cls_col(st.cls))
		U.micro(self, "POISE %d" % floori(st.poise), GX, 260 - Y0, U.POISE if st.poise >= 16 else Color("#b0a040"))

func _belt(st: HeroStats) -> void:
	for i in 4:
		var x := BELT_X + i * 20
		var s = st.inv.belt[i]
		if hover == "belt%d" % i:
			_r(x, BELT_Y, 16, 16, Color(1, 1, 1, 0.05))
		if s != null:
			var ic := U.tex("res://art/ui/items/%s.png" % s["kind"])
			if ic:
				draw_texture_rect(ic, Rect2(_L(x + 2, BELT_Y + 2), Vector2(48, 48)), false)
			if int(s["n"]) > 1:
				U.micro(self, str(int(s["n"])), x + 16, BELT_Y + 11 - Y0, U.TEXT, 1)
		U.micro(self, str(i + 1), x + 1, BELT_Y + 1 - Y0, U.DIM, -1, false)

func _menu(st: HeroStats) -> void:
	var tiles := U.tex("res://art/ui/h55_IC_png.png")
	var stud := U.tex("res://art/ui/h55_IC_stud.png")
	var items := _menu_items()
	for i in items.size():
		var id: String = items[i][0]
		var x := _menu_x(i)
		var on: bool = hud.is_open(id)
		var hov := hover == "menu:" + id
		var col := MENU_IDS.find(id)
		var row := 2 if on else (1 if hov else 0)
		if tiles and col >= 0:
			draw_texture_rect_region(tiles, Rect2(_L(x, MENU_Y), Vector2(56, 56)), Rect2(col * 28, row * 28, 28, 28))
		var pts := (id == "char" and st.attr_points > 0) or (id == "skills" and st.skill_points > 0)
		if pts and stud:
			draw_texture_rect(stud, Rect2(_L(x + 10, MENU_Y - 1.5), Vector2(16, 16)), false)

## the D2 level-up buttons: a carved stud above each end of the bar while points wait
func _level_buttons(st: HeroStats) -> void:
	for which in ["stats", "skills"]:
		if _pts(which) <= 0 or hud.picking != "":
			continue
		var r := _lvl_rect(which)
		var hov: bool = hover == "lvl:" + str(which)
		var pulse := 0.6 + 0.4 * sin(t * 4.0)
		U.stud(self, r.position.x, r.position.y - Y0, r.size.x, r.size.y, "", true, U.GOLD, hov)
		U.frame(self, r.position.x - 0.5, r.position.y - Y0 - 0.5, r.size.x + 1, r.size.y + 1, Color(U.GOLD_D, pulse), 0.5)
		U.micro(self, "+ " + ("STATS" if which == "stats" else "SKILL"), r.position.x + r.size.x / 2.0, r.position.y - Y0 + 4.5, U.GOLD, 0)
