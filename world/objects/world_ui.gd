extends CanvasLayer
## The world's voice on screen (zz_voice.js drawing, zz_quests.js panels): a speaker's line over the bar (name in
## gold, the line in italic), whispers and inscriptions in the upper third, banners for moments that matter, the
## name of what the mouse is over, the waystone panel, and the black of the passage between waystones.
## One lives under main for the whole run (it is found by name: GodmarrowWorldUI).

const F_ROMAN := "res://art/fonts/IMFeENrm28P.ttf"
const F_ITALIC := "res://art/fonts/IMFeENit28P.ttf"
const F_CAPS := "res://art/fonts/IMFeENsc28P.ttf"
const GOLD := Color8(201, 164, 90)
const INK := Color8(232, 226, 208)
const DIM := Color8(111, 106, 121)

var bark_name: Label
var bark_text: Label
var bark_plate: ColorRect
var wh_name: Label
var wh_text: Label
var wh_plate: ColorRect
var banner_l: Label
var hover_l: Label
var fade_r: ColorRect
var panel: Control
var panel_list: VBoxContainer
var panel_tabs: HBoxContainer
var panel_title: Label
var panel_act: Label
var on_pick: Callable
var panel_act_n := 1
var panel_here := ""
var _bark_t := 0.0
var _bark_max := 1.0
var _wh_t := 0.0
var _wh_max := 1.0
var _ban_t := 0.0
var _ban_max := 1.0
var fade := 0.0

func _ready() -> void:
	name = "GodmarrowWorldUI"
	layer = 30
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	fade_r = ColorRect.new()
	fade_r.color = Color(4 / 255.0, 1 / 255.0, 2 / 255.0, 0.0)
	fade_r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_r)
	bark_plate = _plate(root)
	wh_plate = _plate(root)
	bark_name = _label(root, F_CAPS, 26, GOLD)
	bark_text = _label(root, F_ITALIC, 30, INK)
	wh_name = _label(root, F_CAPS, 24, GOLD)
	wh_text = _label(root, F_ITALIC, 26, Color8(185, 175, 152))
	banner_l = _label(root, F_CAPS, 64, GOLD)
	hover_l = _label(root, F_CAPS, 26, INK)
	for l in [bark_text, wh_text]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(bark_name, 0.5, 1.0, -700, -352, 700, -318)
	_place(bark_text, 0.5, 1.0, -560, -318, 560, -220)
	_place(wh_name, 0.5, 0.0, -600, 300, 600, 334)
	_place(wh_text, 0.5, 0.0, -520, 334, 520, 440)
	_place(banner_l, 0.5, 0.0, -900, 440, 900, 520)
	_place(hover_l, 0.5, 0.0, -600, 24, 600, 60)
	bark_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for l in [bark_name, bark_text, wh_name, wh_text, banner_l, hover_l]:
		l.modulate.a = 0.0
	_build_panel(root)

static var _fonts := {}
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
	elif FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			f = ff
	_fonts[path] = f
	return f

func _label(parent: Control, font_path: String, size: int, col: Color) -> Label:
	var l := Label.new()
	if font(font_path):
		l.add_theme_font_override("font", font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _plate(parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(6 / 255.0, 5 / 255.0, 8 / 255.0, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b

# ------------------------------------------------------------------ speech
static func _dur(text: String) -> float:
	return clampf(2.2 + text.split(" ").size() * 0.28, 4.0, 9.0)

## a spoken line over the bar; inscr = an inscription (paler)
func speak(who: String, text: String, secs: float = -1.0, inscr: bool = false) -> void:
	if text == "":
		return
	bark_name.text = who
	bark_text.text = text
	bark_text.add_theme_color_override("font_color", Color8(207, 197, 173) if inscr else INK)
	_bark_max = secs if secs > 0.0 else _dur(text)
	_bark_t = _bark_max

## "Name: 'line'" becomes a named line
func speak_line(text: String, secs: float = -1.0) -> void:
	var sp: Array = load("res://world/quests.gd").split_speech(text)
	speak(sp[0], sp[1], secs)

## a whisper or an inscription in the upper third (landmarks)
func whisper(who: String, text: String, secs: float = -1.0) -> void:
	wh_name.text = who
	wh_text.text = text
	_wh_max = secs if secs > 0.0 else _dur(text)
	_wh_t = _wh_max

func banner(text: String, col: Color = GOLD, secs: float = 3.0) -> void:
	banner_l.text = text
	banner_l.add_theme_color_override("font_color", col)
	_ban_max = secs
	_ban_t = secs

func banner_later(text: String, col: Color, secs: float, delay: float, zone_id: String = "") -> void:
	await get_tree().create_timer(delay).timeout
	var m := get_parent()
	if zone_id != "" and m and "zone" in m and m.zone and m.zone.id != zone_id:
		return
	banner(text, col, secs)

func hover(text: String) -> void:
	if hover_l.text != text:
		hover_l.text = text
	hover_l.modulate.a = 1.0 if text != "" else 0.0

func set_fade(a: float) -> void:
	fade = clampf(a, 0.0, 1.0)
	fade_r.color.a = fade

static func _alpha(t: float, mx: float) -> float:
	return clampf(minf((mx - t) / 0.9, t / 1.3), 0.0, 1.0)

## The hour turning, as the browser announced it (zv_time24.js HOUR_TXT): a banner and a line, outdoors only.
const HOUR_TXT := {
	"day": ["DAY", "The sun is on the Hide. The pyres burn hot.", Color8(232, 216, 168)],
	"dusk": ["DUSK", "The Hide bleeds. Everything hunts faster; the Hands come out.", Color8(224, 96, 64)],
	"night": ["NIGHT", "Keep to the light. The breath walks.", Color8(142, 160, 216)],
	"dawn": ["DAWN", "The long shadows. Bone stands straighter; the mourners weep.", Color8(224, 184, 120)],
}
var _hour := "-"   # "-" until the first look: entering a zone never announces, only the hour turning does
var _hour_due := ""   # an hour turned while other words were up: said once the screen is clear

func _hours() -> void:
	var m := get_parent()
	var z = m.get("zone") if m else null
	var h := ""
	if z and is_instance_valid(z) and z.d.get("outdoor", false):
		h = Game.hour_name()
	if h != _hour and h != "" and _hour != "-" and _hour != "":
		_hour_due = h
	if h == "":
		_hour_due = ""   # gone under: the hour is not told there
	_hour = h
	if _hour_due != "" and _ban_t <= 0.0 and _wh_t <= 0.0:
		var t: Array = HOUR_TXT.get(_hour_due, [])
		_hour_due = ""
		if not t.is_empty():
			banner(t[0], t[2], 2.4)
			whisper("", t[1], 3.0)

func _process(dt: float) -> void:
	# the title and the Reading stand over the world: its words wait (their clocks held) until the pilgrim rises
	var cs := get_tree().current_scene
	var held: bool = cs != null and cs.get("title_open") == true
	visible = not held
	if held:
		return
	_hours()
	_bark_t = maxf(0.0, _bark_t - dt)
	_wh_t = maxf(0.0, _wh_t - dt)
	_ban_t = maxf(0.0, _ban_t - dt)
	var a := _alpha(_bark_t, _bark_max)
	bark_name.modulate.a = a
	bark_text.modulate.a = a
	_fit_plate(bark_plate, bark_text, a, bark_name.text != "")
	var b := _alpha(_wh_t, _wh_max) * 0.9
	wh_name.modulate.a = b
	wh_text.modulate.a = b
	_fit_plate(wh_plate, wh_text, b, wh_name.text != "")
	banner_l.modulate.a = clampf(minf((_ban_max - _ban_t) / 0.4, _ban_t / 0.8), 0.0, 1.0)

func _fit_plate(p: ColorRect, l: Label, a: float, named: bool) -> void:
	if a <= 0.0:
		p.color.a = 0.0
		return
	var lines := maxi(1, l.get_line_count())
	var h := lines * 34.0 + (40.0 if named else 12.0)
	var vp := get_viewport().get_visible_rect().size
	var gp := l.get_global_rect()
	p.position = Vector2(vp.x * 0.5 - 620, gp.position.y - (36.0 if named else 6.0))
	p.size = Vector2(1240, h)
	p.color.a = 0.55 * a

# ------------------------------------------------------------------ the waystone panel
func _build_panel(root: Control) -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.047, 0.066, 0.94)
	sb.border_color = Color(0.23, 0.2, 0.27)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	_place(panel, 0.0, 0.0, 24, 90, 560, 900)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	panel_title = _panel_label(top, F_CAPS, 34, GOLD)
	panel_title.text = "Waystones"
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var x := _button("×", 26)
	x.pressed.connect(close_panel)
	top.add_child(x)
	panel_tabs = HBoxContainer.new()
	v.add_child(panel_tabs)
	panel_act = _panel_label(v, F_CAPS, 26, GOLD)
	panel_list = VBoxContainer.new()
	panel_list.add_theme_constant_override("separation", 6)
	panel_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(panel_list)
	var hint := _panel_label(v, F_ITALIC, 22, DIM)
	hint.text = "Stand in a waystone and it will learn you."
	panel.visible = false

func _panel_label(parent: Control, font_path: String, size: int, col: Color) -> Label:
	var l := Label.new()
	if font(font_path):
		l.add_theme_font_override("font", font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _button(t: String, size: int) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	if font(F_ROMAN):
		b.add_theme_font_override("font", font(F_ROMAN))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	return b

func panel_open() -> bool:
	return panel.visible

func open_waystones(act: int, here: String, pick: Callable) -> void:
	on_pick = pick
	panel_act_n = act
	panel_here = here
	panel.visible = true
	_fill_panel()

func close_panel() -> void:
	panel.visible = false

func _fill_panel() -> void:
	var Q = load("res://world/quests.gd")
	for c in panel_tabs.get_children():
		c.queue_free()
	for c in panel_list.get_children():
		c.queue_free()
	for n in range(1, Q.max_act() + 1):
		var t := _button(("> " if n == panel_act_n else "") + "Act " + Q.ROMAN[n], 24)
		var nn := n
		t.pressed.connect(func():
			panel_act_n = nn
			_fill_panel())
		panel_tabs.add_child(t)
	panel_act.text = Q.act_name(panel_act_n)
	var ws: Array = Q.waystones(panel_act_n, panel_here)
	if ws.is_empty():
		var l := _panel_label(panel_list, F_ITALIC, 24, DIM)
		l.text = "No waystone knows you in this act yet."
		return
	for w in ws:
		var b := _button(("* " if w["town"] else "") + String(w["name"]), 28)
		b.disabled = w["here"]
		var id: String = w["id"]
		b.pressed.connect(func():
			close_panel()
			if on_pick.is_valid():
				on_pick.call(id))
		panel_list.add_child(b)
