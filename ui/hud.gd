extends CanvasLayer
## ui/hud.gd: the interface. main.gd makes one (load("res://ui/hud.gd").new()) and calls bind(hero, zone) on every zone
## entry (the hero node is new each zone; its HeroStats and SkillBook persist).
## - the bar (ui/bar.gd): orbs, skills, poise, XP, belt, menu studs, level-up studs
## - panels: I inventory (ui/panel_inv.gd), C character (ui/panel_char.gd), S skills (ui/panel_skills.gd),
##   Tab automap (ui/automap.gd), Esc pause menu and options (ui/pause.gd)
## - over the world: the hovered creature's name and life (D2), the boss's life and stagger, the zone's name and
##   epigraph on entry, Bus.say lines above the bar
## - the skill picker (click a skill button), tooltips (lore by default, Shift for the numbers), the carried item
## Every panel and control STOPs the mouse, everything decorative IGNOREs it, so the hero never walks under the UI
## (hero.gd checks get_viewport().gui_get_hovered_control()).
## Test args: --open=inventory,char,skills,map,pause   --hudtest (a fed character for captures)   --mouse=x,y

const U := preload("res://ui/uikit.gd")
const BINDABLE := ["q", "w", "e", "r", "t", "y", "u", "f", "o", "z", "x", "b", "n"]

var hero: Hero
var zone: Zone
var root: Control
var over: Control            # world overlays (hover line, boss, banner, messages)
var automap: Control
var bar: Control
var p_inv: Control
var p_char: Control
var p_skills: Control
var picker: Control
var pause: Control
var codex: Control
var top: Control             # tooltip and carried item

var cursor_item: Item = null
var vendor_open := false     # set by a vendor's window: right-click then sells
var stash_open := false      # the Reliquary Chest is open: right-click in the pack puts away
var p_town: Control          # ui/panel_town.gd: vendor, smith, chest, journal
var p_orders: Control        # ui/panel_orders.gd: the choir (V) and the golem (G)
var p_board: Control         # ui/panel_board.gd: the body board (A)
var dial: Control            # ui/sky_dial.gd: the clock, top right (zz_polish.js)
var tip: Array = []
var msgs: Array = []         # [{text, t, max}]
var banner := {}             # {name, line, t, max}
var boss: Monster = null
var picking := ""            # "L" | "R" | ""
var pick_hover := ""
var zone_lines := {}
var args := {}
var _opened := false
var _loot = null
var _t := 0.0

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if ResourceLoader.exists("res://items/loot.gd"):
		_loot = load("res://items/loot.gd")
	var zl := FileAccess.get_file_as_string("res://art/ui/zone_lines.json")
	if zl != "":
		var j = JSON.parse_string(zl)
		if j is Dictionary:
			zone_lines = j
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	over = _layer(_draw_over)
	automap = load("res://ui/automap.gd").new()
	automap.hud = self
	automap.visible = false
	root.add_child(automap)
	dial = load("res://ui/sky_dial.gd").new()
	dial.hud = self
	root.add_child(dial)
	bar = load("res://ui/bar.gd").new()
	bar.hud = self
	root.add_child(bar)
	p_char = _panel("res://ui/panel_char.gd")
	p_skills = _panel("res://ui/panel_skills.gd")
	p_inv = _panel("res://ui/panel_inv.gd")
	p_town = _panel("res://ui/panel_town.gd")
	p_orders = _panel("res://ui/panel_orders.gd")
	p_board = _panel("res://ui/panel_board.gd")
	Bus.panel_requested.connect(_on_panel_requested)
	picker = Control.new()
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.focus_mode = Control.FOCUS_NONE
	picker.visible = false
	picker.draw.connect(_draw_picker)
	picker.gui_input.connect(_picker_input)
	root.add_child(picker)
	pause = load("res://ui/pause.gd").new()
	pause.hud = self
	pause.visible = false
	root.add_child(pause)
	codex = load("res://ui/codex.gd").new()
	codex.visible = false
	root.add_child(codex)
	top = _layer(_draw_top)
	Bus.say.connect(_on_say)
	Bus.boss_woke.connect(func(m): boss = m)
	Bus.boss_felled.connect(func(m): if m == boss: boss = null)

func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn)
	root.add_child(c)
	return c

func _panel(path: String) -> Control:
	var p: Control = load(path).new()
	p.hud = self
	p.visible = false
	root.add_child(p)
	return p

# ------------------------------------------------------------------ binding
func bind(h: Hero, z: Zone) -> void:
	hero = h
	zone = z
	if boss and (not is_instance_valid(boss) or boss.zone != z):
		boss = null
	bar.set_class(h.st.cls)
	automap.bind(z)
	var nm := str(z.d.get("name", z.id))
	# the zone's line only the first time this pilgrim enters (checklist 20); the name every time
	var line := ""
	var QS: Dictionary = load("res://world/quests.gd").state()
	if not QS.has("seen"):
		QS["seen"] = {}
	if not QS["seen"].has("z:" + z.id):
		QS["seen"]["z:" + z.id] = true
		line = str(zone_lines.get(z.id, ""))
	banner = {"name": nm, "line": line, "t": 0.0, "max": 5.0 if line != "" else 3.0}
	if args.has("hudtest") and not h.st.has_meta("hudtest"):
		_feed(h)
	if not _opened:
		_opened = true
		if args.has("open"):
			for p in str(args["open"]).split(","):
				match p:
					"inventory", "inv", "i":
						p_inv.visible = true
					"char", "character", "c":
						p_char.visible = true
					"skills", "s":
						p_skills.visible = true
						p_char.visible = false
					"map", "tab":
						automap.visible = true
					"codex", "k":
						open_codex()
						if args.has("page"):
							var cp := str(args["page"]).split(".")
							codex.ch = int(cp[0])
							codex.pg = int(cp[1]) if cp.size() > 1 else 0
							codex.open_book()
					"pause", "menu", "options":
						pause.open()
						if p == "options":
							pause.page = "options"
		if args.has("mouse"):
			var m := str(args["mouse"]).split(",")
			if m.size() == 2:
				get_viewport().warp_mouse(Vector2(float(m[0]), float(m[1])))
		if args.has("pick"):
			picking = str(args["pick"]).to_upper()
		if args.has("uitest"):
			var tst: Node = load("res://ui/ui_selftest.gd").new()
			tst.hud = self
			add_child(tst)

## --hudtest: a character with points, some skills and a few things in the pack, for captures
func _feed(h: Hero) -> void:
	var st := h.st
	st.set_meta("hudtest", true)
	st.level = 14
	st.attr_points = 5
	st.skill_points = 6
	st.hp = st.life_max() * 0.72
	st.res = st.res_max() * 0.55
	var n := 0
	for id in h.skills.data:
		var s: Dictionary = h.skills.data[id]
		if int(s.get("required_level", 1)) <= 12 and s.get("prerequisites", []).is_empty() and n < 5:
			h.skills.hard[id] = 1 + n % 3
			n += 1
	for id in h.skills.data:
		var s: Dictionary = h.skills.data[id]
		if int(s.get("required_level", 1)) <= 6 and not s.get("prerequisites", []).is_empty() and h.skills.hard.get(s["prerequisites"][0], 0) > 0:
			h.skills.hard[id] = 2
	var bases: Dictionary = Data.table("items").get("bases", {})
	var mk := func(base: String, q: String, nm: String, lines: Array, stats: Dictionary) -> Item:
		var b: Dictionary = bases.get(base, {})
		var it := Item.new()
		it.base = base
		it.name = nm
		it.q = q
		it.slot = b.get("slot", "")
		it.grid = Vector2i(b.get("grid", [1, 1])[0], b.get("grid", [1, 1])[1])
		it.icon = b.get("icon", base)
		it.ilvl = 9
		it.req = 7
		it.lines = lines
		it.stats = stats
		if b.get("damage") != null:
			it.dmg = Vector2(b["damage"][0], b["damage"][1])
		if b.get("armor") != null:
			it.armor = float(b["armor"][1]) if b["armor"] is Array else float(b["armor"])
		return it
	st.inv.add(mk.call("staff", "rare", "Grim Whisper", ["+12% Skill Damage", "+18 to Life", "+9% Faster Cast Rate", "+14% Magic Resist"], {"dmg": 12, "life": 18, "fcr": 9, "res": 14}))
	st.inv.add(mk.call("mail", "magic", "Sturdy Grave Mail of the Fox", ["+11 to Life", "+4 to Vitality"], {"life": 11, "vit": 4}))
	st.inv.add(mk.call("ring", "unique", "Knot of Sorrows", ["+1 to All Skills", "+10% Magic Resist"], {"skall": 1, "res": 10}))
	st.inv.add(mk.call("boots", "normal", "Grave Boots", [], {}))
	st.inv.add(mk.call("amulet", "magic", "Amulet of the Hearth", ["Hearth wick: regenerate 2 Life a second"], {"lamber": 2}))
	var d := Item.new()
	d.base = "hp"
	d.name = "Healing Draught"
	d.q = "potion"
	d.potion = "hp"
	st.inv.add(d)
	h.stats_changed.emit()

# ------------------------------------------------------------------ panels
func is_open(id: String) -> bool:
	match id:
		"inv":
			return p_inv.visible
		"char":
			return p_char.visible
		"skills":
			return p_skills.visible
		"map":
			return automap.visible
		"menu":
			return pause.visible
	return false

func toggle_panel(id: String) -> void:
	var was := any_panel()
	_toggle_panel(id)
	var now := any_panel()
	if now != was or id == "map":
		Sfx.play("page_open" if now else "page_close", 0.8)

func _toggle_panel(id: String) -> void:
	match id:
		"inv":
			p_inv.visible = not p_inv.visible
		"char":
			p_char.visible = not p_char.visible
			if p_char.visible:
				p_skills.visible = false
				p_town.close()
				p_orders.visible = false
		"board":
			if p_board.visible:
				p_board.visible = false
			else:
				p_inv.visible = false
				p_char.visible = false
				p_skills.visible = false
				p_orders.visible = false
				p_town.close()
				p_board.open()
		"choir", "golem":
			if hero == null or not ("wbeh" in hero.skills):
				return
			if p_orders.visible and p_orders.mode == id:
				p_orders.visible = false
			else:
				p_char.visible = false
				p_skills.visible = false
				p_town.close()
				p_orders.mode = id
				p_orders.visible = true
		"journal":
			if p_town.visible and p_town.mode == "journal":
				p_town.close()
			else:
				p_char.visible = false
				p_skills.visible = false
				p_town.open("journal")
		"skills":
			p_skills.visible = not p_skills.visible
			if p_skills.visible:
				p_char.visible = false
				p_town.close()
				p_orders.visible = false
		"map":
			automap.visible = not automap.visible
			automap.queue_redraw()
	picking = ""

func menu_click(id: String) -> void:
	if id == "menu":
		pause.open()
	else:
		toggle_panel(id)

## the Codex of the Hide (ui/codex.gd), from K or the pause menu
func open_codex() -> void:
	codex.on_close = func(): get_tree().paused = pause.visible
	get_tree().paused = true
	Sfx.play("page_open")
	codex.open_book()

func any_panel() -> bool:
	return p_inv.visible or p_char.visible or p_skills.visible or p_town.visible or p_orders.visible or p_board.visible or picking != ""

func close_panels() -> void:
	p_inv.visible = false
	p_char.visible = false
	p_skills.visible = false
	p_town.close()
	p_orders.visible = false
	p_board.visible = false
	picking = ""
	vendor_open = false
	_return_cursor()

func _return_cursor() -> void:
	if cursor_item and hero:
		if not hero.st.inv.add(cursor_item):
			_drop(cursor_item)
		cursor_item = null

func toggle_picker(which: String) -> void:
	picking = "" if picking == which else which

# ------------------------------------------------------------------ input
var mouse := Vector2(-1, -1)       # the mouse in viewport px (kept from events; synthetic events move it too)

func mouse_in(c: Control) -> Vector2:
	return c.get_global_transform().affine_inverse() * mouse

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		mouse = ev.position
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := ev.keycode as Key
		if codex.visible:
			return          # the book reads its own keys
		if pause.visible:
			if k == KEY_ESCAPE:
				pause.key_back()
				get_viewport().set_input_as_handled()
			return
		# hover a skill (the picker, the skill page) and press a key: bind it
		var hs := _hovered_skill()
		var ks := OS.get_keycode_string(k).to_lower()
		if hs != "" and ks in BINDABLE and hero:
			var sb := hero.skills
			for kk in sb.keys.keys():
				if sb.keys[kk] == hs:
					sb.keys.erase(kk)
			sb.keys[ks] = hs
			Bus.say.emit("%s answers to %s." % [sb.name_of(hs), ks.to_upper()], 1.2)
			get_viewport().set_input_as_handled()
			return
		match k:
			KEY_I:
				toggle_panel("inv")
			KEY_C:
				toggle_panel("char")
			KEY_S:
				toggle_panel("skills")
			KEY_TAB:
				toggle_panel("map")
			KEY_J:
				toggle_panel("journal")
			KEY_A:
				toggle_panel("board")
			KEY_V:
				toggle_panel("choir")
			KEY_G:
				toggle_panel("golem")
			KEY_K:
				open_codex()
			KEY_ESCAPE:
				if any_panel():
					close_panels()
				elif automap.visible:
					automap.visible = false
				else:
					pause.open()
			_:
				return
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		var hov := get_viewport().gui_get_hovered_control()
		if picking != "" and hov != picker and hov != bar:
			picking = ""
		if cursor_item and hov == null and ev.button_index == MOUSE_BUTTON_LEFT:
			_drop(cursor_item)
			cursor_item = null
			get_viewport().set_input_as_handled()

func _hovered_skill() -> String:
	if picking != "" and pick_hover != "":
		return pick_hover
	if p_skills.visible:
		var id: String = p_skills.hovered_skill()
		if id != "" and hero and hero.skills.lvl(id) > 0 and hero.skills.data[id].get("kind", "cast") != "passive":
			return id
	return ""

## leave an item on the ground (items/loot.gd owns ground items: drop_item(zone, at, item) if it has one)
func _drop(it: Item) -> void:
	if _loot and _loot.has_method("drop_item") and zone and hero:
		_loot.drop_item(zone, hero.tp, it)
	elif hero and not hero.st.inv.add(it):
		Bus.say.emit("There is no room for it.", 1.2)

# ------------------------------------------------------------------ skills: learning, perks, tooltips
func learn(id: String) -> bool:
	if hero == null:
		return false
	var sb := hero.skills
	var first: bool = sb.hard.get(id, 0) == 0
	if not sb.learn(id):
		return false
	var k: String = sb.data[id].get("kind", "cast")
	if first and (k == "cast" or k == "hold"):
		sb.right = id
	return true

func perk_on(id: String, pk: Dictionary) -> bool:
	var sb := hero.skills
	if sb.lvl(id) < int(pk.get("skill_level", 1)):
		return false
	var rs = pk.get("requires_stat")
	if rs is Dictionary:
		var v := 0.0
		match str(rs.get("stat", "")):
			"spi", "ene", "ess":
				v = hero.st.e_ess()
			"vit":
				v = hero.st.e_vit()
			"con", "dex":
				v = hero.st.e_con()
		return v >= float(rs.get("value", 0))
	return true

func _stat_name(k: String) -> String:
	return {"spi": "Essence", "ene": "Essence", "vit": "Vitality", "con": "Constitution", "dex": "Constitution"}.get(k, k)

func skill_tip(id: String, more: bool = false) -> Array:
	if hero == null:
		return []
	if id == "attack" or id == "":
		return [["Attack", U.TEXT], ["Strike with what you hold.", U.MUTED]]
	var sb := hero.skills
	var s: Dictionary = sb.data.get(id, {})
	if s.is_empty():
		return [[id, U.TEXT]]
	var full := more or Input.is_key_pressed(KEY_SHIFT)
	var L := sb.lvl(id)
	var hl := int(sb.hard.get(id, 0))
	var col := U.tab_col(sb.cls, int(s.get("tab", 0)))
	var passive: bool = s.get("kind", "cast") == "passive"
	var lines: Array = [[str(s.get("name", id)) + (" · level %d" % L if L > 0 else ""), col]]
	if passive:
		lines.append(["[Passive]", U.DIM])
	var ready := hero.st.level >= int(s.get("required_level", 1))
	for p in s.get("prerequisites", []):
		if sb.hard.get(p, 0) <= 0:
			ready = false
	if not full:
		for l in U.wrap(str(s.get("lore", s.get("description", ""))), 150, "book", 7.5).slice(0, 4):
			lines.append([l, U.MUTED])
	else:
		for l in U.wrap(str(s.get("description", "")), 150, "book", 7.5).slice(0, 4):
			lines.append([l, U.MUTED])
	var c := sb.cost(id)
	var pc := sb.poise_cost(id)
	var ctext := ""
	if sb.cls == "monk":
		# the hourglass: Radiance pours amber sand, Absence black sand (a share of the bulb); Destroyer spends poise
		var tb := int(s.get("tab", 0))
		if tb == 2 and c > 0.0:
			pc = roundf(c * (1.2 if id == "kthousand" else 0.6))
		elif c > 0.0:
			ctext = "Pours %s sand · %d%% of the bulb" % ["amber" if tb == 0 else "black", roundi(minf(25.0, 5.0 * c * (3.0 if id in ["kdawn", "keclipse"] else 1.0) / 12.8))]
			if s.get("kind", "") == "hold":
				ctext += " a second"
	elif c > 0.0:
		ctext = "%s %.1f" % [hero.st.res_name(), c]
		if s.get("kind", "") == "hold":
			ctext += " a second"
	if pc > 0.0:
		ctext += (" · " if ctext != "" else "") + "Poise %d" % roundi(pc)
	if ctext != "":
		lines.append([ctext, U.GOLD_D])
	var lv: Dictionary = s.get("levels", {})
	var now: Dictionary = lv.get(str(clampi(maxi(L, 1), 1, 20)), {})
	if L > 0 and sb.has_method("info"):
		var live: String = sb.info(id)
		if live != "":
			now = {"text": live}   # the order's own live numbers (the sky, the glass) over the web's samples
	if full:
		lines.append([str(s.get("kind_text", "")), U.DIM])
		if now.has("text"):
			lines.append([("Now: " if L > 0 else "Level 1: ") + str(now["text"]), U.BLUE])
		if L > 0 and hl < int(s.get("max_hard_level", 20)):
			var nx: Dictionary = lv.get(str(clampi(L + 1, 1, 20)), {})
			if nx.has("text") and L + 1 <= 20:
				lines.append(["Next: " + str(nx["text"]), Color("#6f7bd8")])
		if L > hl:
			lines.append(["%d points + %d from what you carry" % [hl, L - hl], U.BLUE])
		for pk in s.get("perks", []):
			var on := perk_on(id, pk)
			var need := "lv %d" % int(pk.get("skill_level", 1))
			var rs = pk.get("requires_stat")
			if rs is Dictionary:
				need += " + %d %s" % [int(rs.get("value", 0)), _stat_name(str(rs.get("stat", "")))]
			lines.append([("+ " if on else "- ") + str(pk.get("name", "")) + ("" if on else " (%s)" % need), U.GOLD_D if on else U.DIM])
			for l in U.wrap(str(pk.get("text", "")), 140, "book", 7.5).slice(0, 2):
				lines.append(["   " + l, U.MUTED if on else U.FAINT])
		for sy in s.get("synergies", []):
			var pts := int(sb.hard.get(sy.get("from", ""), 0))
			lines.append(["+%d%% per point in %s (%d)" % [int(sy.get("per_hard_point_pct", 0)), str(sy.get("from_name", "")), pts], Color("#b48ad9") if pts > 0 else U.DIM])
	else:
		if now.has("text"):
			lines.append([("Now: " if L > 0 else "Level 1: ") + str(now["text"]), U.BLUE])
	if not ready:
		if hero.st.level < int(s.get("required_level", 1)):
			lines.append(["Requires level %d" % int(s.get("required_level", 1)), U.RED])
		else:
			lines.append(["Requires " + ", ".join(s.get("prerequisite_names", [])), U.RED])
	if not full:
		lines.append(["shift: the numbers, perks and synergies", U.FAINT])
	return lines

# ------------------------------------------------------------------ items: icons and tooltips (items/loot.gd if it has them)
func item_tip(it: Item) -> Array:
	if _loot and _loot.has_method("tooltip_lines"):
		var l = _loot.tooltip_lines(it, hero)
		if l is Array and not l.is_empty():
			return l.duplicate()
	var lines: Array = [[it.name, it.color()]]
	if it.potion != "":
		lines.append(["Restores %s over a few breaths" % ("life" if it.potion == "hp" else hero.st.res_name().to_lower()), U.MUTED])
		return lines
	var b: Dictionary = Data.table("items").get("bases", {}).get(it.base, {})
	if (it.q == "rare" or it.q == "unique") and b.has("name"):
		lines.append([str(b["name"]), U.MUTED])
	if it.dmg != Vector2.ZERO:
		lines.append(["Damage %d to %d" % [it.dmg.x, it.dmg.y], U.TEXT])
	if it.armor > 0.0:
		lines.append(["Armor %d" % roundi(it.armor), U.TEXT])
	if it.req > 1:
		lines.append(["Required level %d" % it.req, U.RED if hero and it.req > hero.st.level else U.TEXT])
	for l in it.lines:
		lines.append([str(l), U.BLUE])
	if it.lore != "":
		for l in U.wrap(it.lore, 140, "italic", 7.5):
			lines.append([l, Color("#c9a45a")])
	return lines

func item_icon(it: Item) -> Texture2D:
	if _loot and _loot.has_method("icon_for"):
		var t = _loot.icon_for(it)
		if t is Texture2D:
			return t
	var key := it.potion if it.potion != "" else (it.icon if it.icon != "" else str(Data.table("items").get("bases", {}).get(it.base, {}).get("icon", it.base)))
	return U.tex("res://art/ui/items/%s.png" % key)

func draw_item(ci: CanvasItem, it: Item, r: Rect2) -> void:
	var t := item_icon(it)
	if t:
		# whole pixels: the icon's own grid scaled to fit
		var k := maxf(1.0, floor(minf(r.size.x / t.get_width(), r.size.y / t.get_height())))
		var sz := Vector2(t.get_width(), t.get_height()) * k
		ci.draw_texture_rect(t, Rect2(r.position + (r.size - sz) / 2.0, sz), false)
	else:
		var f := U.font("book")
		var s := it.name
		ci.draw_string(f, r.position + Vector2(4, r.size.y / 2 + 8), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 20, it.color())

# ------------------------------------------------------------------ the frame
func _process(dt: float) -> void:
	_t += dt
	if DisplayServer.get_name() != "headless":
		mouse = root.get_viewport().get_mouse_position()
	for m in msgs:
		m["t"] += dt
	msgs = msgs.filter(func(m): return m["t"] < m["max"])
	if not banner.is_empty():
		banner["t"] += dt
		if banner["t"] > banner["max"]:
			banner = {}
	if boss and (not is_instance_valid(boss) or boss.dead):
		boss = null
	if hero and not is_instance_valid(hero):
		hero = null
	automap.step(dt)
	_layout_picker()
	# the tooltip: the topmost thing under the mouse that has one
	tip = []
	var hov := _hovered()
	if cursor_item == null or hov == picker:
		if picking != "" and hov == picker and pick_hover != "":
			tip = skill_tip(pick_hover) + [["Click to choose · a key binds it", U.FAINT]]
		elif hov == p_inv or (hov and hov == p_inv):
			tip = p_inv.tip()
		elif hov == p_skills:
			tip = p_skills.tip()
		elif hov == p_char:
			tip = p_char.tip()
		elif hov == p_town:
			tip = p_town.tip()
		elif hov == p_orders:
			tip = p_orders.tip()
		elif hov == dial:
			tip = dial.tip()
		elif hov == p_board:
			tip = p_board.tip()
		elif hov == bar:
			tip = bar.tip()
	over.queue_redraw()
	top.queue_redraw()
	if picker.visible:
		picker.queue_redraw()

## the control under the mouse (the GUI's own answer, or by geometry when no motion has reached it yet)
func _hovered() -> Control:
	var hov := get_viewport().gui_get_hovered_control()
	if hov:
		return hov
	var mp := mouse
	for c in [picker, p_inv, p_skills, p_char]:
		if c.visible and c.get_global_rect().has_point(mp):
			return c
	if bar.get_global_rect().has_point(mp) and bar._has_point(mp - bar.get_global_rect().position):
		return bar
	return null

func _on_say(text, secs) -> void:
	var s := str(text)
	if zone and s == str(zone.d.get("name", "")):
		return            # the zone's name gets the banner instead
	msgs.append({"text": s, "t": 0.0, "max": float(secs) if secs != null else 2.5})
	if msgs.size() > 3:
		msgs.pop_front()

# ------------------------------------------------------------------ the skill picker (D2: a row of learned skills above the button)
func _pick_ids() -> Array:
	var out: Array = ["attack"]
	if hero == null:
		return out
	var sb := hero.skills
	var ids: Array = sb.data.keys()
	ids.sort_custom(func(a, b): return [int(sb.data[a].get("tab", 0)), int(sb.data[a].get("row", 0)), int(sb.data[a].get("col", 0))] < [int(sb.data[b].get("tab", 0)), int(sb.data[b].get("row", 0)), int(sb.data[b].get("col", 0))])
	for id in ids:
		if sb.lvl(id) > 0 and sb.data[id].get("kind", "cast") != "passive":
			out.append(id)
	return out

const PCELL := 20.0          # logical: an 18 px well and a 2 px seam
const PCOLS := 8

func _layout_picker() -> void:
	picker.visible = picking != "" and hero != null and not pause.visible
	if not picker.visible:
		pick_hover = ""
		return
	var n := _pick_ids().size()
	var cols := mini(n, PCOLS)
	var rows := ceili(float(n) / PCOLS)
	var w := cols * PCELL + 6
	var h := rows * PCELL + 6
	var vs := root.get_viewport_rect().size
	var bar_x: float = bar.get_global_rect().position.x
	var x := bar_x + (56.0 * U.S if picking == "L" else 426.0 * U.S - w * U.S)
	var y := vs.y - 64.0 * U.S - h * U.S
	picker.position = Vector2(x, y)
	picker.size = Vector2(w, h) * U.S
	var lp := mouse_in(picker) / U.S
	pick_hover = ""
	var ids := _pick_ids()
	for i in ids.size():
		var r := Rect2(3 + (i % PCOLS) * PCELL, 3 + (i / PCOLS) * PCELL, 18, 18)
		if r.has_point(lp):
			pick_hover = ids[i]

func _picker_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		picker.accept_event()
		if pick_hover != "" and hero:
			if picking == "L":
				hero.skills.left = pick_hover
			else:
				hero.skills.right = pick_hover
			hero.stats_changed.emit()
			picking = ""

func _draw_picker() -> void:
	var sz := picker.size / U.S
	U.rect(picker, 0, 0, sz.x, sz.y, Color("#050407"))
	U.rect(picker, 1, 1, sz.x - 2, sz.y - 2, Color("#2e2a38"))
	U.rect(picker, 2, 2, sz.x - 4, sz.y - 4, Color("#0e0c10"))
	var ids := _pick_ids()
	var cur: String = hero.skills.left if picking == "L" else hero.skills.right
	for i in ids.size():
		var id: String = ids[i]
		var x := 3 + (i % PCOLS) * PCELL
		var y := 3 + (i / PCOLS) * PCELL
		U.rect(picker, x - 0.5, y - 0.5, 19, 19, Color("#050407"))
		U.rect(picker, x, y, 18, 18, Color("#1a1512"))
		var ic := U.skill_icon(id)
		if ic:
			picker.draw_texture_rect(ic, U.R(x, y, 18, 18), false)
		if id == cur:
			U.frame(picker, x - 0.5, y - 0.5, 19, 19, U.GOLD_D, 0.75)
		elif id == pick_hover:
			U.frame(picker, x - 0.5, y - 0.5, 19, 19, Color(1, 1, 1, 0.5), 0.5)
		for kk in hero.skills.keys:
			if hero.skills.keys[kk] == id:
				U.rect(picker, x, y, U.micro_w(str(kk)) + 2, 7, Color(0.02, 0.016, 0.027, 0.85))
				U.micro(picker, str(kk).to_upper(), x + 1, y + 1, U.GOLD_D, -1, false)

# ------------------------------------------------------------------ over the world
func _draw_over() -> void:
	var vs := over.get_viewport_rect().size
	var cx := vs.x / 2.0
	# the hovered creature: name in its rank's colour on a crimson life bar, its gifts under it (D2)
	var m: Monster = null
	if hero and is_instance_valid(hero) and not pause.visible and get_viewport().gui_get_hovered_control() == null:
		m = hero.monster_at_mouse()
	if args.has("hovermon") and hero and is_instance_valid(hero):
		m = Combat.nearest_monster(zone, hero.tp, 60.0)
	if args.has("bosstest") and boss == null and hero and is_instance_valid(hero):
		for mm in get_tree().get_nodes_in_group("monsters"):
			if mm.rank in ["boss", "unique"] and not mm.dead:
				boss = mm
				break
	if m and m != boss:
		_mon_line(m, cx, 14.0)
	# the boss awake: its name, its life, and the bone line of its stagger
	if boss and is_instance_valid(boss) and not boss.dead:
		_boss_bar(boss, cx, 120.0 if m else 40.0)
	# the zone's name and its line, in the upper third
	if not banner.is_empty() and not pause.visible:
		var t: float = banner["t"]
		var a := clampf(minf(minf(t * 1.2, 1.0), (banner["max"] - t) * 0.8), 0.0, 1.0)
		var y := 184.0 + (150.0 if boss else 0.0)
		_band(Rect2(0, y - 62, vs.x, 86), 0.55 * a)
		var f := U.font("sc")
		var s := str(banner["name"]).to_upper()
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		over.draw_string(f, Vector2(cx - w / 2 + 3, y + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.04, 0.035, 0.05, a))
		over.draw_string(f, Vector2(cx - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.93, 0.89, 0.8, a))
		var line := U.smart(str(banner["line"]))
		if line != "":
			var fi := U.font("italic")
			var lw := fi.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
			_band(Rect2(0, y + 38, vs.x, 56), 0.35 * a)
			over.draw_string(fi, Vector2(cx - lw / 2 + 2, y + 78), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, 0.8 * a))
			over.draw_string(fi, Vector2(cx - lw / 2, y + 76), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.78, 0.74, 0.66, 0.85 * a))
	# said lines, above the bar
	var my := vs.y - 56.0 * U.S
	for i in range(msgs.size() - 1, -1, -1):
		var mm: Dictionary = msgs[i]
		var a := clampf(minf(mm["t"] * 4.0, (mm["max"] - mm["t"]) * 2.0), 0.0, 1.0)
		var s := str(mm["text"])
		var f := U.font("pixel")
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		over.draw_rect(Rect2(cx - w / 2 - 24, my - 34, w + 48, 46), Color(0.024, 0.02, 0.03, 0.7 * a))
		over.draw_string(f, Vector2(cx - w / 2 + 3, my + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0, 0, 0, a))
		over.draw_string(f, Vector2(cx - w / 2, my), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.91, 0.89, 0.82, a))
		my -= 54.0
	if hero and hero.dead:
		var fi := U.font("italic")
		var s := "The lantern carries you back."
		var w := fi.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		over.draw_string(fi, Vector2(cx - w / 2, vs.y / 2 + 60), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("#a39d8c"))

## a dark band fading out at both ends (the web's banner gradient), in stripes
func _band(r: Rect2, a: float) -> void:
	var n := 24
	for i in n:
		var u := (i + 0.5) / n
		var k := clampf(minf(u, 1.0 - u) * 4.0, 0.0, 1.0)
		over.draw_rect(Rect2(r.position.x + r.size.x * i / n, r.position.y, r.size.x / n + 1, r.size.y), Color(0, 0, 0, a * k))

func _mon_line(m: Monster, cx: float, y: float) -> void:
	var f := U.font("sc")
	var nm := m.name_shown if m.name_shown != "" else m.kind.capitalize()
	var col := Color(U.RANKCOL.get(m.rank, "#e8e2d0"))
	var w := maxf(360.0, f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 64)
	var mods := ", ".join(m.mods.map(func(x): return Affixes.shown(str(x))))
	var h := 56.0
	over.draw_rect(Rect2(cx - w / 2 - 4, y - 4, w + 8, h + 8 + (40.0 if mods != "" else 0.0)), Color(0.02, 0.016, 0.027, 0.88))
	over.draw_rect(Rect2(cx - w / 2 - 4, y - 4, w + 8, h + 8 + (40.0 if mods != "" else 0.0)), Color("#3a3446"), false, 2.0)
	over.draw_rect(Rect2(cx - w / 2, y, w * clampf(m.hp / maxf(1.0, m.hp_max), 0, 1), h), Color("#5a1a20"))
	over.draw_rect(Rect2(cx - w / 2, y, w * clampf(m.hp / maxf(1.0, m.hp_max), 0, 1), 3), Color("#7a2a2e"))
	var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	over.draw_string(f, Vector2(cx - nw / 2 + 2, y + 42), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, 0.9))
	over.draw_string(f, Vector2(cx - nw / 2, y + 40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
	# champions and uniques show the bone line of their stagger along the bar's foot (checklist 6)
	if m.rank in ["champion", "unique"]:
		var sk := 1.0 if m.reeling > 0.0 else clampf(1.0 - m.poise / maxf(1.0, m.poise_max), 0, 1)
		over.draw_rect(Rect2(cx - w / 2, y + h - 4, w, 4), Color("#0a090d"))
		over.draw_rect(Rect2(cx - w / 2, y + h - 4, w * sk, 4), Color("#f4efe2") if m.reeling > 0.0 else Color("#b8ae94"))
	if mods != "":
		var fb := U.font("book")
		var mw := fb.get_string_size(mods, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		over.draw_string(fb, Vector2(cx - mw / 2, y + h + 32), mods, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, U.BLUE)

func _boss_bar(b: Monster, cx: float, y: float) -> void:
	var f := U.font("sc")
	var nm := b.name_shown if b.name_shown != "" else b.kind.capitalize()
	var w := 960.0
	var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	over.draw_string(f, Vector2(cx - nw / 2 + 3, y + 43), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0, 0, 0, 0.9))
	over.draw_string(f, Vector2(cx - nw / 2, y + 40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("#d8cdb4"))
	var by := y + 56
	over.draw_rect(Rect2(cx - w / 2 - 6, by - 6, w + 12, 36), Color("#050407"))
	over.draw_rect(Rect2(cx - w / 2 - 4, by - 4, w + 8, 32), Color("#4a3a26"), false, 2.0)
	over.draw_rect(Rect2(cx - w / 2, by, w, 24), Color("#160a0c"))
	var k := clampf(b.hp / maxf(1.0, b.hp_max), 0, 1)
	over.draw_rect(Rect2(cx - w / 2, by, w * k, 24), Color("#6a1a22"))
	over.draw_rect(Rect2(cx - w / 2, by, w * k, 4), Color("#8e2630"))
	for i in range(1, 10):
		over.draw_rect(Rect2(cx - w / 2 + w * i / 10.0, by, 2, 24), Color(0, 0, 0, 0.35))
	# the stagger: a bone line that fills as its poise breaks; full while it reels
	var sk := 1.0 if b.reeling > 0.0 else clampf(1.0 - b.poise / maxf(1.0, b.poise_max), 0, 1)
	var sy := by + 34
	over.draw_rect(Rect2(cx - w / 2, sy, w, 6), Color("#0a090d"))
	over.draw_rect(Rect2(cx - w / 2, sy, w * sk, 6), Color("#f4efe2") if b.reeling > 0.0 else Color("#b8ae94"))

# ------------------------------------------------------------------ top: the carried item and the tooltip
func _draw_top() -> void:
	var mp := mouse
	if cursor_item:
		var sz := Vector2(cursor_item.grid) * 48.0
		draw_item(top, cursor_item, Rect2(mp - sz / 2.0, sz))
	if not tip.is_empty():
		U.tooltip(top, tip, mp, top.get_viewport_rect().size, top.get_viewport_rect().size.y - 136.0)


## a townsfolk opens a window (world/objects/manager.gd): vendor | smith | stash | journal
func _on_panel_requested(panel: String, who: String) -> void:
	p_orders.visible = false
	p_char.visible = false
	p_skills.visible = false
	p_town.open(panel, who)
