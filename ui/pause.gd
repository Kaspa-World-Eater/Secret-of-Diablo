extends Control
## ui/pause.gd: the pause menu (Esc), after the web's: a dark plate with bronze corners, PAUSED, the hero's line, a column
## of carved rows (Resume, Options, Controls, Quit). Options: damage numbers, hit flash, screen shake, auto attack, hold to
## charge heavy attacks, music and sound volume (Settings, saved at once). The tree is paused while it is open.

const U := preload("res://ui/uikit.gd")
const W := 640.0

var hud: Node
var page := "main"           # main | options | controls
var hover := -1
var rows: Array = []         # [[label, action]]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS

var saved := false

func open() -> void:
	page = "main"
	saved = false
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	Settings.save()

func _build() -> void:
	match page:
		"main":
			rows = [["Resume", "resume"], ["Written." if saved else "Save the pilgrim", "save"], ["The Codex", "codex"], ["Controls", "controls"], ["Full screen: " + _on(_full()), "fullscreen"], ["Options", "options"], ["Save and quit", "quit"]]
		"options":
			rows = [
				["Damage numbers: " + _on(Settings.damage_numbers), "t:damage_numbers"],
				["Hit flash: " + _on(Settings.hit_flash), "t:hit_flash"],
				["Screen shake: " + _on(Settings.screen_shake), "t:screen_shake"],
				["Auto attack: " + _on(Settings.auto_attack), "t:auto_attack"],
				["Hold to charge heavy attacks: " + _on(Settings.hold_heavy), "t:hold_heavy"],
				["Charge melee techniques: " + _on(Settings.charge_melee), "t:charge_melee"],
				["Music: %d%%" % roundi(Settings.music_vol * 100), "v:music_vol"],
				["Sound: %d%%" % roundi(Settings.sfx_vol * 100), "v:sfx_vol"],
				["The title: " + String(Settings.TITLE_NAMES[Settings.title_scene]), "title_scene"],
				["Fewer effects (a slower machine): " + _on(Settings.fewer_fx), "t:fewer_fx"],
				["Back", "back"]]
		"controls":
			rows = [["Back", "back"]]

func _full() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func _on(b: bool) -> String:
	return "on" if b else "off"

func _box() -> Rect2:
	var vs := get_viewport_rect().size
	var h := 214.0 + rows.size() * 49.0 + (330.0 if page == "controls" else 0.0)
	return Rect2(vs.x / 2 - W / 2, vs.y / 2 - h / 2 - 40, W, h)

func _row_rect(i: int) -> Rect2:
	var b := _box()
	var y0 := b.position.y + 150.0 + (330.0 if page == "controls" else 0.0)
	return Rect2(b.position.x + 30, y0 + i * 49.0, W - 60, 40)

func _process(_dt: float) -> void:
	if not visible:
		return
	_build()
	hover = -1
	var m: Vector2 = hud.mouse_in(self)
	for i in rows.size():
		if _row_rect(i).has_point(m):
			hover = i
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	accept_event()
	_build()
	for i in rows.size():
		if _row_rect(i).has_point(ev.position):
			_act(rows[i][1], ev.button_index == MOUSE_BUTTON_RIGHT or (ev.position.x < _row_rect(i).get_center().x - 120 and str(rows[i][1]).begins_with("v:")))

func _act(a: String, down: bool) -> void:
	if a == "resume":
		close()
	elif a == "codex":
		hud.open_codex()
	elif a == "options" or a == "controls":
		page = a
	elif a == "back":
		page = "main"
		Settings.save()
	elif a == "save":
		_main_save()
		saved = true
	elif a == "quit":
		Settings.save()
		_main_save()
		get_tree().quit()
	elif a == "fullscreen":   # the web's pause menu has it (a_head.html:281-304)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _full() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif a == "title_scene":
		var ts: Array = Settings.TITLE_SCENES
		Settings.title_scene = ts[(ts.find(Settings.title_scene) + (ts.size() - 1 if down else 1)) % ts.size()]
		Settings.save()
	elif a.begins_with("t:"):
		var k := a.substr(2)
		Settings.set(k, not bool(Settings.get(k)))
		Settings.save()
	elif a.begins_with("v:"):
		var k := a.substr(2)
		var v := float(Settings.get(k))
		v = v - 0.1 if down else v + 0.1
		if v > 1.001:
			v = 0.0
		Settings.set(k, clampf(snappedf(v, 0.1), 0.0, 1.0))
		Settings.save()

func key_back() -> void:
	if page != "main":
		page = "main"
	else:
		close()

const CONTROLS := [
	["Left click", "walk, strike, take"], ["Shift + left", "strike where you stand"], ["Hold the strike", "a heavy blow"],
	["Right click", "the right skill (hold to repeat)"], ["Space", "roll"], ["1 - 4", "drink from the belt"],
	["Q W E R T Y U F", "choose the right skill (shift: left)"], ["I  C  S  Tab  K", "pack, self, skills, map, the Codex"], ["L", "the wick down or up"]]

func _draw() -> void:
	if not visible:
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	_build()
	var b := _box()
	draw_rect(b, Color("#0b0a0c"))
	draw_rect(b.grow(-6), Color("#141115"))
	draw_rect(b, Color("#050407"), false, 4.0)
	draw_rect(b.grow(-6), Color("#8a6a3a"), false, 2.0)
	draw_rect(b.grow(-11), Color("#2a2018"), false, 2.0)
	for c in [b.position, Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), b.end]:
		var d := 10.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color("#c89a58"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color("#3a1a10"))
	var cx := b.position.x + W / 2
	var title := {"main": "PAUSED", "options": "OPTIONS", "controls": "CONTROLS"}[page] as String
	var f := U.font("sc")
	var spaced := " ".join(title.split(""))
	var tw := f.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	draw_string(f, Vector2(cx - tw / 2 + 3, b.position.y + 78), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("#050407"))
	draw_string(f, Vector2(cx - tw / 2, b.position.y + 75), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("#d8b878"))
	draw_line(Vector2(cx - 150, b.position.y + 92), Vector2(cx + 150, b.position.y + 92), Color("#8a6a3a"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, b.position.y + 84), Vector2(cx + 8, b.position.y + 92), Vector2(cx, b.position.y + 100), Vector2(cx - 8, b.position.y + 92)]), Color("#c8553d"))
	var h: Hero = hud.hero
	if h:
		var cname: String = Data.table("classes").get("classes", {}).get(h.st.cls, {}).get("display_name", h.st.cls)
		var line := "Level %d %s · %s" % [h.st.level, cname, str(hud.zone.d.get("name", "")) if hud.zone else ""]
		var fi := U.font("italic")
		var lw := fi.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(fi, Vector2(cx - lw / 2, b.position.y + 122), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#c8bca0"))
	if page == "controls":
		var fb := U.font("book")
		for i in CONTROLS.size():
			var y := b.position.y + 180 + i * 34
			draw_string(fb, Vector2(b.position.x + 36, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#d8b878"))
			draw_string(fb, Vector2(b.position.x + 260, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, U.MUTED)
	var fr := U.font("sc")
	for i in rows.size():
		var r := _row_rect(i)
		var on := hover == i
		draw_rect(r, Color("#2a1810") if on else Color("#0e0c0e"))
		draw_rect(r, Color("#c89a58") if on else Color("#3a3028"), false, 2.0)
		var dm := r.position + Vector2(22, r.size.y / 2)
		draw_colored_polygon(PackedVector2Array([dm + Vector2(0, -5), dm + Vector2(5, 0), dm + Vector2(0, 5), dm + Vector2(-5, 0)]), Color("#e87a3a") if on else Color("#6a5238"))
		var s: String = rows[i][0]
		draw_string(fr, r.position + Vector2(44, 28), s.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#f0e0c0") if on else Color("#b8ab94"))
	var fi2 := U.font("italic")
	var hint := "Esc opens and closes this menu when no panel is open." if page == "main" else ("Click a volume to raise it; right-click to lower it." if page == "options" else "")
	if hint != "":
		var hw := fi2.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(fi2, Vector2(cx - hw / 2, b.end.y - 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8a8070"))


func _main_save() -> void:
	var m := get_tree().current_scene
	if m and m.has_method("save_game"):
		m.save_game()
