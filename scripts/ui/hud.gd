extends CanvasLayer
## Diablo 2 style HUD: life/mana orbs, skill buttons, skill picker with
## F-key binding, skill tree (T), character screen (A), automap (Tab), help (H).

const GOLD := Color(0.78, 0.65, 0.35)
const PANEL_BG := Color(0.08, 0.07, 0.06, 0.94)
const TEXT := Color(0.9, 0.86, 0.75)

var root: Control
var bar: Control
var left_btn: Button
var right_btn: Button
var char_btn: Button
var tree_btn: Button

var stats_panel: Panel
var stats_label: Label
var stats_points_label: Label
var stat_plus := {}

var tree_panel: Panel
var tree_tab := 0
var tree_tabs: Array = []
var tree_buttons := {}
var tree_lines: Control
var tree_info: Label
var tree_points: Label

var picker: Panel
var picker_grid: GridContainer
var picker_left := false
var picker_hover := ""

var automap: Control
var help: Panel

var _msg := ""
var _msg_time := 0.0
var _refresh := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	automap = Control.new()
	automap.set_anchors_preset(Control.PRESET_FULL_RECT)
	automap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	automap.visible = false
	automap.draw.connect(_draw_automap)
	root.add_child(automap)

	bar = Control.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	root.add_child(bar)

	left_btn = _skill_button()
	left_btn.pressed.connect(_open_picker.bind(true))
	root.add_child(left_btn)
	right_btn = _skill_button()
	right_btn.pressed.connect(_open_picker.bind(false))
	root.add_child(right_btn)

	char_btn = _text_button("Character (A)")
	char_btn.pressed.connect(func(): _toggle(stats_panel))
	root.add_child(char_btn)
	tree_btn = _text_button("Skills (T)")
	tree_btn.pressed.connect(func(): _toggle(tree_panel))
	root.add_child(tree_btn)

	_build_stats_panel()
	_build_tree_panel()
	_build_picker()
	_build_help()
	_layout()


# ---------------------------------------------------------------- widgets

func _style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	return sb


func _panel(size: Vector2) -> Panel:
	var p := Panel.new()
	p.size = size
	p.add_theme_stylebox_override("panel", _style(PANEL_BG, GOLD))
	p.visible = false
	root.add_child(p)
	return p


func _label(parent: Control, text: String, pos: Vector2, size := 14, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _text_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _style(Color(0.15, 0.12, 0.1), GOLD.darkened(0.3)))
	b.add_theme_stylebox_override("hover", _style(Color(0.25, 0.2, 0.14), GOLD))
	b.add_theme_stylebox_override("pressed", _style(Color(0.1, 0.08, 0.06), GOLD))
	b.add_theme_color_override("font_color", TEXT)
	return b


func _skill_button() -> Button:
	var b := _text_button("")
	b.custom_minimum_size = Vector2(52, 52)
	b.size = Vector2(52, 52)
	b.add_theme_font_size_override("font_size", 16)
	return b


func _skill_style(b: Button, id: String) -> void:
	var tree: int = SkillDB.SKILLS[id]["tree"]
	var c: Color = SkillDB.TREE_COLORS[tree] if tree >= 0 else Color(0.5, 0.45, 0.4)
	b.add_theme_stylebox_override("normal", _style(c.darkened(0.45), c))
	b.add_theme_stylebox_override("hover", _style(c.darkened(0.2), Color(1, 0.95, 0.7)))
	b.add_theme_stylebox_override("pressed", _style(c.darkened(0.6), c))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.12, 0.12), Color(0.3, 0.3, 0.3)))


# ---------------------------------------------------------------- stats panel

func _build_stats_panel() -> void:
	stats_panel = _panel(Vector2(320, 420))
	stats_panel.position = Vector2(16, 16)
	_label(stats_panel, "Character", Vector2(12, 8), 18, GOLD)
	stats_points_label = _label(stats_panel, "", Vector2(160, 12), 13, Color(1, 0.85, 0.3))
	stats_label = _label(stats_panel, "", Vector2(14, 40), 14)
	var rows := [["str", 109], ["dex", 132], ["vit", 155], ["ene", 178]]
	for r in rows:
		var b := _text_button("+")
		b.position = Vector2(270, r[1] - 2)
		b.size = Vector2(28, 20)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_stat.bind(r[0]))
		stats_panel.add_child(b)
		stat_plus[r[0]] = b


func _on_stat(stat: String) -> void:
	Game.player.spend_stat(stat)
	_refresh_stats()


func _refresh_stats() -> void:
	var p = Game.player
	stats_points_label.text = "Stat points: %d" % p.stat_points if p.stat_points > 0 else ""
	var wd: Vector2 = p.wand_damage()
	var lines := [
		"Level %d Necromancer" % p.level,
		"Experience: %d / %d" % [p.xp, p.xp_to_next()],
		"",
		"Strength:   %d" % p.strength,
		"Dexterity:  %d" % p.dexterity,
		"Vitality:   %d" % p.vitality,
		"Energy:     %d" % p.energy,
		"",
		"Life:   %d / %d" % [p.hp, p.max_hp],
		"Mana:   %d / %d" % [p.mana, p.max_mana],
		"Wand damage: %d-%d" % [wd.x, wd.y],
		"Bone Armor: %d" % int(p.bone_armor),
		"",
		"Fire %d%%  Cold %d%%  Lightning %d%%  Poison %d%%" % [p.resist["fire"], p.resist["cold"], p.resist["lightning"], p.resist["poison"]],
		"Gold: %d     Kills: %d" % [p.gold, Game.kills],
	]
	stats_label.text = "\n".join(lines)
	for k in stat_plus:
		stat_plus[k].visible = p.stat_points > 0


# ---------------------------------------------------------------- skill tree

func _build_tree_panel() -> void:
	tree_panel = _panel(Vector2(430, 690))
	_label(tree_panel, "Necromancer Skills", Vector2(12, 8), 18, GOLD)
	tree_points = _label(tree_panel, "", Vector2(250, 12), 13, Color(1, 0.85, 0.3))
	for i in 3:
		var b := _text_button(SkillDB.TREES[i])
		b.position = Vector2(12 + i * 137, 38)
		b.size = Vector2(132, 26)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_set_tab.bind(i))
		tree_panel.add_child(b)
		tree_tabs.append(b)
	tree_lines = Control.new()
	tree_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_lines.draw.connect(_draw_tree_lines)
	tree_panel.add_child(tree_lines)
	for id in SkillDB.SKILLS:
		var s: Dictionary = SkillDB.SKILLS[id]
		if s["tree"] < 0:
			continue
		var b := _text_button("")
		b.position = Vector2(20 + s["col"] * 137, 76 + s["row"] * 76)
		b.size = Vector2(122, 58)
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_ALL
		b.focus_entered.connect(_show_skill_info.bind(id))
		b.pressed.connect(_on_learn.bind(id))
		b.mouse_entered.connect(_show_skill_info.bind(id))
		_skill_style(b, id)
		tree_panel.add_child(b)
		tree_buttons[id] = b
	tree_info = _label(tree_panel, "Hover a skill for details. Click to spend a point.", Vector2(14, 534), 11)
	tree_info.size = Vector2(404, 150)
	tree_info.clip_text = true
	tree_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_tab(0)


func _set_tab(i: int) -> void:
	tree_tab = i
	_refresh_tree()


func _refresh_tree() -> void:
	var p = Game.player
	tree_points.text = "Skill points: %d" % p.skill_points
	for i in 3:
		tree_tabs[i].modulate = Color(1, 1, 1) if i == tree_tab else Color(0.6, 0.6, 0.6)
	for id in tree_buttons:
		var b: Button = tree_buttons[id]
		b.visible = SkillDB.SKILLS[id]["tree"] == tree_tab
		if not b.visible:
			continue
		var lvl: int = p.skill_level(id)
		var can := SkillDB.can_learn(p, id) == ""
		b.text = "%s\n%s" % [SkillDB.SKILLS[id]["name"], ("Level %d" % lvl) if lvl > 0 else "Req. lvl %d" % SkillDB.req_level(id)]
		if lvl > 0:
			b.modulate = Color(1.15, 1.15, 1.15) if can else Color(1, 1, 1)
		else:
			b.modulate = Color(1, 1, 1) if can else Color(0.45, 0.45, 0.45)
	tree_lines.queue_redraw()


func _draw_tree_lines() -> void:
	for id in tree_buttons:
		var s: Dictionary = SkillDB.SKILLS[id]
		if s["tree"] != tree_tab:
			continue
		var b: Button = tree_buttons[id]
		for pre in s["pre"]:
			var pb: Button = tree_buttons[pre]
			var a := pb.position + Vector2(pb.size.x / 2, pb.size.y)
			var c := b.position + Vector2(b.size.x / 2, 0)
			var col := GOLD if Game.player.skill_level(pre) > 0 else Color(0.35, 0.32, 0.28)
			tree_lines.draw_line(a, c, col, 2.0)
			tree_lines.draw_circle(c, 3.0, col)


func _on_learn(id: String) -> void:
	if Game.player.learn(id):
		_refresh_tree()
		_show_skill_info(id)


func _show_skill_info(id: String) -> void:
	var p = Game.player
	var s: Dictionary = SkillDB.SKILLS[id]
	var lvl: int = p.skill_level(id)
	var t := "%s  (Level %d)\n%s" % [s["name"], lvl, s["desc"]]
	var reqs := []
	for pre in s["pre"]:
		reqs.append(SkillDB.SKILLS[pre]["name"])
	t += "\nRequired level: %d" % SkillDB.req_level(id)
	if not reqs.is_empty():
		t += "   Requires: " + ", ".join(reqs)
	if not s["passive"]:
		t += "\nMana cost: %.1f" % SkillDB.mana_cost(id, max(1, lvl))
	if lvl > 0:
		t += "\nCurrent: " + SkillDB.describe(id, lvl, p).replace("\n", ", ")
	if lvl < SkillDB.MAX_LEVEL:
		t += "\nNext level: " + SkillDB.describe(id, lvl + 1, p).replace("\n", ", ")
	tree_info.text = t


# ---------------------------------------------------------------- skill picker

func _build_picker() -> void:
	picker = _panel(Vector2(300, 100))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 18)
	picker.add_child(margin)
	picker_grid = GridContainer.new()
	picker_grid.columns = 5
	picker_grid.add_theme_constant_override("h_separation", 6)
	picker_grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(picker_grid)
	_label(picker, "Hover + F1-F8 to bind", Vector2(8, 0), 10, GOLD).name = "Hint"


func _open_picker(left: bool) -> void:
	if picker.visible and picker_left == left:
		picker.visible = false
		return
	picker_left = left
	for c in picker_grid.get_children():
		c.queue_free()
	var p = Game.player
	var ids := ["attack"]
	for id in SkillDB.SKILLS:
		if id != "attack" and p.skill_level(id) > 0 and not SkillDB.SKILLS[id]["passive"]:
			ids.append(id)
	for id in ids:
		var b := _skill_button()
		b.text = _icon_text(id)
		b.tooltip_text = SkillDB.SKILLS[id]["name"]
		b.add_theme_font_size_override("font_size", 13)
		_skill_style(b, id)
		b.pressed.connect(_pick.bind(id))
		b.mouse_entered.connect(func(): picker_hover = id)
		b.mouse_exited.connect(func(): if picker_hover == id: picker_hover = "")
		picker_grid.add_child(b)
	var rows := int(ceil(ids.size() / 5.0))
	picker.size = Vector2(5 * 58 + 12, rows * 58 + 30)
	var vs := root.size
	if left:
		picker.position = Vector2(140, vs.y - 96 - picker.size.y)
	else:
		picker.position = Vector2(vs.x - 140 - picker.size.x, vs.y - 96 - picker.size.y)
	picker_hover = ""
	picker.visible = true


func _icon_text(id: String) -> String:
	var t: String = SkillDB.SKILLS[id]["icon"]
	var p = Game.player
	for k in p.hotkeys:
		if p.hotkeys[k] == id:
			t += "\nF%d" % (k + 1)
	return t


func _pick(id: String) -> void:
	if picker_left:
		Game.player.left_skill = id
	else:
		Game.player.right_skill = id
	picker.visible = false


func _input(event: InputEvent) -> void:
	if not picker.visible or picker_hover == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in 8:
			if event.is_action("hotkey_%d" % (i + 1)):
				var p = Game.player
				for k in p.hotkeys.keys():
					if p.hotkeys[k] == picker_hover:
						p.hotkeys.erase(k)
				p.hotkeys[i] = picker_hover
				show_message("%s bound to F%d" % [SkillDB.SKILLS[picker_hover]["name"], i + 1])
				var keep := picker_left
				picker.visible = false
				_open_picker(keep)
				get_viewport().set_input_as_handled()
				return


# ---------------------------------------------------------------- help / toggles

func _build_help() -> void:
	help = _panel(Vector2(560, 440))
	help.visible = true
	var t := "\n".join([
		"SECRET OF DIABLO  -  Necromancer sandbox",
		"",
		"Left-click: move / attack        Shift + Left-click: attack in place",
		"Right-click: use your right skill (hold to keep casting)",
		"Click the skill icons by the orbs to choose left / right skills.",
		"   While choosing, hover a skill and press F1-F8 to bind it.",
		"F1-F8: switch right skill     1-2: Healing potion     3-4: Mana potion",
		"T: Skill tree   A: Character   Tab: Automap   L: Plant/recall lantern   H: Help",
		"Debug:  = gain a level    N: skip 3 hours",
		"",
		"BONE MELEE (Secret of Mana style): each swing empties the stamina bar",
		"under your feet - wait for it to refill for full damage. At full stamina,",
		"HOLD the skill button to charge (pips fill), RELEASE to unleash.",
		"",
		"LIGHT: night falls every 20 minutes. Monsters hit harder in darkness,",
		"Shades only appear at night and are hidden outside your light.",
		"Your lantern bearer carries your light - plant it to hold ground.",
		"",
		"Controller: L-stick move, R-stick aim, A left skill, X right skill (hold),",
		"B cycle skills, Y lantern, LB/RB potions, Start skills, Back character.",
	])
	var l := _label(help, t, Vector2(16, 12), 13)
	l.size = Vector2(530, 420)


func _focus_first_tree_button() -> void:
	for id in tree_buttons:
		var b: Button = tree_buttons[id]
		if b.visible:
			b.grab_focus()
			return


func pad_menu_open() -> bool:
	return tree_panel.visible or stats_panel.visible


func _toggle(c: Control) -> void:
	c.visible = not c.visible
	if c == stats_panel and c.visible:
		_refresh_stats()
	if c == tree_panel and c.visible:
		_refresh_tree()
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("skill_tree"):
		_toggle(tree_panel)
		if tree_panel.visible and event is InputEventJoypadButton:
			_focus_first_tree_button()
	elif event.is_action_pressed("stats"):
		_toggle(stats_panel)
	elif event.is_action_pressed("automap"):
		automap.visible = not automap.visible
	elif event.is_action_pressed("help"):
		_toggle(help)
	elif event.is_action_pressed("close_panels"):
		for c in [stats_panel, tree_panel, picker, help]:
			c.visible = false
	else:
		return
	get_viewport().set_input_as_handled()


func show_message(text: String) -> void:
	_msg = text
	_msg_time = 3.0


# ---------------------------------------------------------------- per frame

func _layout() -> void:
	var vs := root.size
	left_btn.position = Vector2(140, vs.y - 70)
	right_btn.position = Vector2(vs.x - 192, vs.y - 70)
	char_btn.position = Vector2(200, vs.y - 70)
	char_btn.size = Vector2(110, 24)
	tree_btn.position = Vector2(vs.x - 310, vs.y - 70)
	tree_btn.size = Vector2(110, 24)
	tree_panel.position = Vector2(vs.x - tree_panel.size.x - 16, 10)
	help.position = Vector2((vs.x - help.size.x) / 2, 60)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	_layout()
	_msg_time -= delta
	left_btn.text = SkillDB.SKILLS[p.left_skill]["icon"]
	right_btn.text = SkillDB.SKILLS[p.right_skill]["icon"]
	_skill_style(left_btn, p.left_skill)
	_skill_style(right_btn, p.right_skill)
	left_btn.tooltip_text = "Left skill: " + SkillDB.SKILLS[p.left_skill]["name"]
	right_btn.tooltip_text = "Right skill: " + SkillDB.SKILLS[p.right_skill]["name"]
	char_btn.text = "Character (A)" + (" +" if p.stat_points > 0 else "")
	tree_btn.text = "Skills (T)" + (" +" if p.skill_points > 0 else "")
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		if stats_panel.visible:
			_refresh_stats()
		if tree_panel.visible:
			tree_points.text = "Skill points: %d" % p.skill_points
	bar.queue_redraw()
	if automap.visible:
		automap.queue_redraw()


func _draw_orb(c: Vector2, r: float, frac: float, col: Color) -> void:
	bar.draw_circle(c, r + 4, Color(0.05, 0.04, 0.03))
	bar.draw_circle(c, r, Color(0.12, 0.08, 0.08))
	var level_y = c.y + r - 2.0 * r * clamp(frac, 0.0, 1.0)
	var y := c.y + r
	while y > level_y:
		var dy := y - c.y
		var hw = sqrt(max(0.0, r * r - dy * dy))
		bar.draw_line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), col.darkened(0.2 * (dy + r) / (2 * r)), 1.0)
		y -= 1.0
	bar.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.12))
	bar.draw_arc(c, r + 2, 0, TAU, 48, GOLD, 3.0)


func _text(pos: Vector2, s: String, size := 13, col := TEXT, center := false) -> void:
	var f := ThemeDB.fallback_font
	var x := pos.x
	if center:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	bar.draw_string_outline(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.9))
	bar.draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_bar() -> void:
	var p = Game.player
	if p == null:
		return
	var s := bar.size
	var h := s.y
	bar.draw_rect(Rect2(0, h - 80, s.x, 80), Color(0.07, 0.06, 0.05, 0.9))
	bar.draw_line(Vector2(0, h - 80), Vector2(s.x, h - 80), GOLD.darkened(0.2), 2.0)
	_draw_orb(Vector2(70, h - 66), 54, p.hp / p.max_hp, Color(0.85, 0.08, 0.08))
	_draw_orb(Vector2(s.x - 70, h - 66), 54, p.mana / p.max_mana, Color(0.15, 0.25, 0.9))
	_text(Vector2(70, h - 128), "Life: %d / %d" % [p.hp, p.max_hp], 12, TEXT, true)
	_text(Vector2(s.x - 70, h - 128), "Mana: %d / %d" % [p.mana, p.max_mana], 12, TEXT, true)

	# experience bar
	var xr := Rect2(200, h - 14, s.x - 400, 7)
	bar.draw_rect(xr, Color(0.15, 0.13, 0.1))
	bar.draw_rect(Rect2(xr.position, Vector2(xr.size.x * float(p.xp) / p.xp_to_next(), xr.size.y)), Color(0.85, 0.75, 0.3))
	bar.draw_rect(xr, GOLD.darkened(0.3), false, 1.0)

	var cx := s.x / 2.0
	_text(Vector2(cx, h - 56), "Level %d Necromancer      Gold %d" % [p.level, p.gold], 14, TEXT, true)
	_text(Vector2(cx, h - 37), "[1-2] Healing x%d     [3-4] Mana x%d" % [p.hp_potions, p.mp_potions], 12, Color(0.85, 0.8, 0.7), true)
	Game.prune(p.skeletons)
	Game.prune(p.mages)
	Game.prune(p.revives)
	var golem := "-"
	if p.golem != null and is_instance_valid(p.golem) and not p.golem.dead:
		golem = p.golem.display_name
	var merc = "alive" if Game.merc != null and is_instance_valid(Game.merc) and not Game.merc.dead else "returning in %ds" % int(max(0.0, Game.merc_respawn))
	_text(Vector2(cx, h - 21), "Skeletons %d/%d   Mages %d/%d   Revived %d   Golem: %s   Merc: %s" % [
		p.skeletons.size(), SkillDB.skeleton_cap(p.skill_level("raise_skeleton")),
		p.mages.size(), SkillDB.skeleton_cap(p.skill_level("raise_skeletal_mage")),
		p.revives.size(), golem, merc], 11, Color(0.7, 0.85, 0.7), true)

	# hovered monster
	var hv = p.hover_target()
	if hv != null:
		var name_col := Color(0.5, 0.65, 1.0) if hv.champion else TEXT
		var w := 220.0
		bar.draw_rect(Rect2(cx - w / 2, 8, w, 22), Color(0.4, 0.04, 0.04, 0.85))
		bar.draw_rect(Rect2(cx - w / 2, 8, w * clamp(hv.hp / hv.max_hp, 0.0, 1.0), 22), Color(0.75, 0.1, 0.1, 0.9))
		bar.draw_rect(Rect2(cx - w / 2, 8, w, 22), GOLD.darkened(0.3), false, 1.0)
		var label: String = hv.display_name
		if hv.stun_time > 0.0:
			label += "  (Stunned)"
		_text(Vector2(cx, 24), label, 13, name_col, true)
		_text(Vector2(cx, 44), "Level %d" % hv.level, 11, Color(0.8, 0.8, 0.8), true)

	# clock
	if Game.day_night:
		var dn = Game.day_night
		var clock: String = dn.clock_text()
		var cxr := s.x - 110.0
		var sun_a: float = dn.time_of_day * TAU + PI / 2
		bar.draw_circle(Vector2(cxr - 70, 22), 9, Color(0, 0, 0, 0.6))
		var icon_col := Color(1, 0.85, 0.3) if dn.daylight > 0.5 else Color(0.75, 0.8, 1.0)
		bar.draw_circle(Vector2(cxr - 70, 22) + Vector2.from_angle(sun_a) * 4.0, 4.0, icon_col)
		_text(Vector2(cxr, 27), clock, 13, TEXT, true)
		var lan := "Lantern: planted" if p.lantern != null and p.lantern.planted else ""
		if lan != "":
			_text(Vector2(cxr, 45), lan, 11, Color(1, 0.85, 0.5), true)

	if _msg_time > 0.0:
		_text(Vector2(cx, h * 0.3), _msg, 16, Color(1, 0.9, 0.6, min(1.0, _msg_time)), true)
	if p.dead:
		_text(Vector2(cx, h * 0.42), "YOU HAVE DIED", 30, Color(0.9, 0.15, 0.1), true)


func _draw_automap() -> void:
	var w = Game.world
	var p = Game.player
	if w == null or p == null:
		return
	var sc := 4.0
	var s := automap.size
	var pc: Vector2i = w.cell_of(p.global_position)
	var origin := s / 2.0 - (Vector2(pc) + Vector2(0.5, 0.5)) * sc
	automap.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
	automap.draw_texture_rect(w.map_texture, Rect2(origin, Vector2(w.W, w.H) * sc), false, Color(1, 1, 1, 0.8))
	var camp: Vector2 = origin + (Vector2(w.spawn_cell) + Vector2(0.5, 0.5)) * sc
	automap.draw_circle(camp, 5, Color(1, 0.85, 0.3))
	for u in Game.units:
		if u.team == 0 and u != p:
			var up: Vector2 = origin + u.global_position / w.TILE * sc
			automap.draw_circle(up, 2.5, Color(0.3, 1, 0.3))
	var pp: Vector2 = origin + p.global_position / w.TILE * sc
	automap.draw_circle(pp, 4, Color(1, 1, 1))
	automap.draw_arc(pp, 6, 0, TAU, 16, Color(0, 0, 0), 1.5)
