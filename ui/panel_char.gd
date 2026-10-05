extends Control
## ui/panel_char.gd: the character page (C), after zz_ui.js drawChar: the order's name, the level and experience, the
## three attributes as carved rows with + studs to spend points (Vitality, Essence, Constitution), then the derived
## numbers: life, resource, poise, armour, damage, speeds, resists, magic find, gold.

const U := preload("res://ui/uikit.gd")
const PW := 236
const PH := 240
const ATTR := [["vit", "Vitality", "Life and poise"], ["ess", "Essence", ""], ["con", "Constitution", "Melee, armor, poise"]]

var hud: Node
var hover := ""
var token_armed := 0.0      # the Hollow Token: a second click within 3 s unmakes the pilgrim's choices

func _ready() -> void:
	offset_right = PW * U.S
	offset_bottom = PH * U.S
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _process(_dt: float) -> void:
	if visible:
		hover = _at(hud.mouse_in(self) / U.S)
		queue_redraw()

func _at(lp: Vector2) -> String:
	if Rect2(PW - 15, 4, 12, 12).has_point(lp):
		return "close"
	for i in 3:
		var y := 66 + i * 24
		if Rect2(196, y - 4, 16, 12).has_point(lp):
			return "+" + ATTR[i][0]
		if Rect2(10, y - 9, 216, 22).has_point(lp):
			return "row:" + ATTR[i][0]
	if Rect2(40, 6, PW - 80, 18).has_point(lp):
		return "fate"
	if Rect2(140, 43, 82, 12).has_point(lp):
		return "token"
	if Rect2(8, 26, 220, 18).has_point(lp):
		return "xp"
	return ""

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	accept_event()
	if not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var h: Hero = hud.hero
	var what := _at(ev.position / U.S)
	if what == "close":
		hud.toggle_panel("char")
	elif what == "token" and h and h.st.hollow_tokens > 0:
		var now := Time.get_ticks_msec() / 1000.0
		if now < token_armed:
			token_armed = 0.0
			_respec(h)
		else:
			token_armed = now + 3.0
	elif what.begins_with("+") and h and h.st.attr_points > 0:
		var k := what.substr(1)
		var n := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
		n = mini(n, h.st.attr_points)
		h.st.set(k, int(h.st.get(k)) + n)
		h.st.attr_points -= n
		h.stats_changed.emit()

func _res_desc(cls: String) -> String:
	match cls:
		"hemomancer":
			return "Vitae: pool, refill, power"
		"miasmancer":
			return "Miasma: pool, refill, power"
		"ossumancer":
			return "Marrow: pool, refill, power"
		"monk":
			return "The glass and spell power"
	return "Pool, refill and spell power"

func tip() -> Array:
	var h: Hero = hud.hero
	if h == null:
		return []
	var st := h.st
	match hover:
		"close":
			return [["Close (C)", U.TEXT]]
		"fate":
			if st.fate_picks.is_empty():
				return [["No one read the cards for this pilgrim.", U.MUTED]]
			var out: Array = [["The Reading", U.GOLD_D]]
			for p in st.fate_picks:
				if p.get("step", "") == "sum":
					for ln in p.get("lines", []):
						out.append([String(ln), U.BLUE if not String(ln).begins_with("-") else U.RED])
					if String(p.get("prophecy", "")) != "":
						out.append(["\u201c%s\u201d" % p["prophecy"], U.FAINT])
				else:
					out.append([String(p.get("name", p.get("id", ""))) + (", reversed" if p.get("rev", false) else ""), U.MUTED])
			return out
		"token":
			return [["Hollow Token", U.TEXT], ["Unmake what you chose: every skill point, every attribute point and every", U.MUTED], ["Arcanum comes back to be spent again. The token is used up.", U.MUTED], ["Click twice within three breaths", U.FAINT]]
		"xp":
			return [["Level %d" % st.level, U.GOLD_D], ["Experience %d / %d" % [st.xp, st.xp_to_next()], U.MUTED]]
		"+vit", "row:vit":
			return [["Vitality", U.TEXT], ["+3 life and a little poise for each point", U.MUTED], ["Shift-click spends five", U.FAINT] if hover[0] == "+" else ["%d from items" % int(st.item("vit")), U.BLUE]]
		"+ess", "row:ess":
			return [["Essence", U.TEXT], ["A larger %s, a faster refill, and" % st.res_name().to_lower(), U.MUTED], ["+1.2% skill damage for each point", U.MUTED], ["Shift-click spends five", U.FAINT] if hover[0] == "+" else ["%d from items" % int(st.item("spi") + st.item("ene")), U.BLUE]]
		"+con", "row:con":
			return [["Constitution", U.TEXT], ["+1.5% melee damage, armor and poise for each point", U.MUTED], ["Shift-click spends five", U.FAINT] if hover[0] == "+" else ["%d from items" % int(st.item("con") + st.item("dex")), U.BLUE]]
	return []

func _draw() -> void:
	var h: Hero = hud.hero
	if h == null:
		return
	var st := h.st
	var col := U.cls_col(st.cls)
	U.page(self, 0, 0, PW, PH, col)
	var cname: String = Data.table("classes").get("classes", {}).get(st.cls, {}).get("display_name", st.cls.capitalize())
	U.title(self, cname, PW / 2.0, 19, col, 150)
	U.stud(self, PW - 15, 4, 12, 12, "", true, U.TEXT, hover == "close")
	U.text(self, "x", PW - 9, 13, U.MUTED, 0, "pixel", 8, false)
	var y := 36.0
	U.text(self, "Level %d" % st.level, 14, y, U.GOLD)
	U.text(self, "%d / %d" % [st.xp, st.xp_to_next()], 222, y, U.MUTED, 1)
	U.rect(self, 14, 38, 208, 3, U.SEAM)
	U.rect(self, 15, 39, roundf(206 * clampf(float(st.xp) / maxf(1, st.xp_to_next()), 0, 1)), 1, Color("#8a6a2a"))
	y += 16
	U.text(self, "Stat points: %d" % st.attr_points, 14, y, U.GOLD if st.attr_points > 0 else U.DIM)
	var armed := Time.get_ticks_msec() / 1000.0 < token_armed
	U.stud(self, 140, y - 9, 82, 12, ("Again to unmake" if armed else "Hollow Token: %d" % st.hollow_tokens), st.hollow_tokens > 0, U.RED if armed else U.TEXT, hover == "token")
	y += 14
	for a in ATTR:
		var k: String = a[0]
		U.recess(self, 10, y - 9, 216, 22, Color("#1a1418"))
		U.rect(self, 13, y - 6, 16, 16, U.SEAM)
		U.rect(self, 14, y - 5, 14, 14, Color("#100d12"))
		_sigil(k, 15, y - 4, st.cls)
		U.text(self, a[1], 33, y, U.TEXT)
		U.text(self, a[2] if a[2] != "" else _res_desc(st.cls), 33, y + 10, U.DIM, -1, "pixel", 8, false)
		var base := int(st.get(k))
		var eff := int({"vit": st.e_vit(), "ess": st.e_ess(), "con": st.e_con()}[k])
		U.text(self, str(eff), 186, y + 4, U.BLUE if eff != base else U.TEXT, 1)
		if st.attr_points > 0:
			U.stud(self, 196, y - 4, 16, 12, "+", true, U.GOLD, hover == "+" + k)
		y += 24
	y += 2
	U.rule(self, 14, y - 10, 208, col)
	var arm := st.armor()
	var rows := [
		["Life", "%d / %d" % [ceili(st.hp), roundi(st.life_max())]],
		[st.res_name(), "%d / %d  (+%.1f/s)" % [ceili(st.res), roundi(st.res_max()), st.res_regen()]],
		["Poise", "%d / %d" % [ceili(st.poise), roundi(st.poise_max())]],
		["Armor", "%d  (-%d%% physical)" % [roundi(arm), roundi(100.0 - 10000.0 / (100.0 + arm))]],
		["Damage", "skills +%d%%  melee +%d%%" % [roundi((st.skill_mult() - 1.0) * 100.0), roundi((st.melee_mult() - 1.0) * 100.0)]],
		["Speed", "cast +%d%%  walk %.1f yd/s" % [roundi(st.item("fcr")), st.move_speed()]],
		["Resists", "fire %d  cold %d  miasma %d" % [roundi(st.resist("fire")), roundi(st.resist("cold")), roundi(st.resist("poison"))]],
		["Magic resist", "%d%%" % roundi(st.resist("magic"))],
		["Magic find", "%d%%" % roundi(st.item("mf"))],
		["Gold", str(st.inv.gold if st.inv else 0)]]
	for i in rows.size():
		if i % 2:
			U.rect(self, 12, y - 7, 212, 9, Color(0, 0, 0, 0.14))
		U.text(self, rows[i][0], 14, y, U.MUTED)
		U.text(self, rows[i][1], 222, y, U.GOLD if i == rows.size() - 1 else U.TEXT, 1)
		y += 9.5

## small pixel sigils: a heart for Vitality, a spiral in the order's colour for Essence, a gauntlet for Constitution
func _sigil(k: String, x: float, y: float, cls: String) -> void:
	match k:
		"vit":
			var B := [Color("#2a0810"), Color("#6a1622"), Color("#b8303f"), Color("#e05060"), Color("#ffb0b8")]
			for p in [[1, 3, 4, 4], [7, 3, 4, 4], [2, 6, 8, 2], [3, 8, 6, 1], [4, 9, 4, 1], [5, 10, 2, 1]]:
				U.rect(self, x + p[0], y + p[1], p[2], p[3], B[0])
			for p in [[2, 4, 2, 3], [8, 4, 2, 3], [3, 6, 6, 2], [4, 8, 4, 1], [5, 9, 2, 1], [4, 4, 1, 2], [7, 4, 1, 2]]:
				U.rect(self, x + p[0], y + p[1], p[2], p[3], B[2])
			U.rect(self, x + 3, y + 3, 1, 1, B[4])
			U.rect(self, x + 3, y + 4, 1, 1, B[3])
		"ess":
			var c := U.cls_col(cls)
			for i in 22:
				var a := i * 0.55
				var r := 0.6 + i * 0.22
				U.rect(self, x + roundf(6 + cos(a) * r), y + roundf(6 + sin(a) * r), 1, 1, c if i % 3 == 0 else c.darkened(0.35))
			U.rect(self, x + 6, y + 6, 1, 1, Color.WHITE)
		_:
			var G := [Color("#2a1c08"), Color("#8a5c1a"), Color("#d9a441"), Color("#f0d080"), Color("#fff6d0")]
			U.rect(self, x + 2, y + 4, 9, 7, G[0])
			U.rect(self, x + 3, y + 5, 7, 5, G[2])
			for i in 4:
				U.rect(self, x + 3 + i * 2, y + 5, 1, 2, G[3])
			U.rect(self, x + 3, y + 8, 7, 1, G[1])
			U.rect(self, x + 1, y + 6, 2, 4, G[0])
			U.rect(self, x + 3, y + 6, 1, 1, G[4])


## the Hollow Token (k_arcana.js fullRespec): skills, attributes and Arcana back to be spent again
func _respec(h: Hero) -> void:
	var st := h.st
	st.hollow_tokens -= 1
	var back := (st.vit - 15) + (st.ess - 25) + (st.con - 15)
	st.vit = 15
	st.ess = 25
	st.con = 15
	st.attr_points += maxi(0, back)
	var sk = h.skills
	var pts := 0
	for id in sk.hard:
		pts += int(sk.hard[id])
	sk.hard.clear()
	sk.left = "attack"
	sk.right = "attack"
	st.skill_points += pts
	if sk.has_method("on_death"):
		sk.on_death()   # what the unlearned skills held up falls away (the choir regrows)
	if st.has_method("respec_arcana"):
		st.respec_arcana()
	st.hp = minf(st.hp, st.life_max())
	st.res = minf(st.res, st.res_max())
	Bus.say.emit("The token hollows out in your palm. You are unmade, and may be made again.", 3.5)
	h.stats_changed.emit()
