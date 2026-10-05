extends Control
## ui/codex.gd: the Codex of the Hide ("The Ossuary of Words"), the in-world lore book, readable in the game. The web
## build's tome (zz_zz_tome94.js) and the published codex page share its text: lore/gen.py -> codex.json ->
## tools/codex_to_bb.py -> data/codex.json (BBCode pages). A dark reliquary book: the chapters and their works on a rail
## at the left, one page at a time on the right. Opened from the title and from the pause menu; K opens it in play.
## Keys: Up/Down or PageUp/PageDown turn pages, Left/Right chapters, Esc closes. The wheel scrolls the page.

const U := preload("res://ui/uikit.gd")
const INK := Color("#131115")
const INK2 := Color("#1b181d")
const BONE := Color("#dcd3c2")
const BONE_D := Color("#a39a8b")
const ASH := Color("#6f685f")
const RULE := Color("#2e2a31")
const MARROW := Color("#c9974a")
const MARROW_D := Color("#8c6a37")

var book: Array = []
var ch := 0
var pg := 0
var text: RichTextLabel
var head: Label
var by: Label
var epi: Label
var rail_rows: Array = []        # [rect, chapter, page]
var hover := -1
var rail_scroll := 0.0
var on_close: Callable

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/codex.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Array:
			book = j
	head = _label("sc", 46, BONE)
	by = _label("italic", 21, BONE_D)
	by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epi = _label("italic", 23, BONE_D)
	epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = true
	text.selection_enabled = false
	text.add_theme_font_override("normal_font", U.font("book"))
	text.add_theme_font_override("italics_font", U.font("italic"))
	text.add_theme_font_override("bold_font", U.font("sc"))
	text.add_theme_font_override("bold_italics_font", U.font("italic"))
	text.add_theme_font_size_override("normal_font_size", 23)
	text.add_theme_font_size_override("italics_font_size", 23)
	text.add_theme_font_size_override("bold_font_size", 23)
	text.add_theme_font_size_override("bold_italics_font_size", 23)
	text.add_theme_color_override("default_color", BONE)
	text.add_theme_constant_override("line_separation", 6)
	add_child(text)
	resized.connect(_layout)
	_layout()

func _label(kind: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", U.font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func open_book(chapter: int = -1) -> void:
	if chapter >= 0:
		ch = clampi(chapter, 0, book.size() - 1)
		pg = 0
	visible = true
	_show()

func close_book() -> void:
	visible = false
	Sfx.play("page_close", 0.8)
	if on_close.is_valid():
		on_close.call()

func _page_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var w := minf(1500.0, vs.x - 120.0)
	var x0 := (vs.x - w) / 2.0
	return Rect2(x0 + 400.0, 70.0, w - 440.0, vs.y - 140.0)

func _rail_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var w := minf(1500.0, vs.x - 120.0)
	return Rect2((vs.x - w) / 2.0 + 24.0, 70.0, 340.0, vs.y - 140.0)

func _layout() -> void:
	var r := _page_rect()
	head.position = r.position
	head.size = Vector2(r.size.x, 56)
	by.position = r.position + Vector2(0, 60)
	by.size = Vector2(r.size.x * 0.9, 0)
	_show()

func _show() -> void:
	if book.is_empty() or text == null:
		return
	var c: Dictionary = book[ch]
	var p: Dictionary = c["pages"][pg]
	head.text = String(p.get("title", ""))
	by.text = String(p.get("by", ""))
	epi.text = ("“%s”" % p["epi"]) if String(p.get("epi", "")) != "" else ""
	var r := _page_rect()
	by.position = r.position + Vector2(0, 60)
	by.size = Vector2(r.size.x * 0.9, 10)
	await get_tree().process_frame
	var y := r.position.y + 64.0 + by.get_line_count() * by.get_line_height() + 14.0
	epi.position = Vector2(r.position.x, y)
	epi.size = Vector2(r.size.x * 0.9, 10)
	await get_tree().process_frame
	if epi.text != "":
		y += epi.get_line_count() * epi.get_line_height() + 16.0
	y += 10.0
	text.position = Vector2(r.position.x, y)
	text.size = Vector2(r.size.x, r.end.y - y - 44.0)
	text.text = String(p.get("bb", ""))
	text.scroll_to_line(0)
	queue_redraw()

func _turn(d: int) -> void:
	if book.is_empty():
		return
	pg += d
	if pg >= book[ch]["pages"].size():
		if ch < book.size() - 1:
			ch += 1
			pg = 0
		else:
			pg = book[ch]["pages"].size() - 1
			return
	elif pg < 0:
		if ch > 0:
			ch -= 1
			pg = book[ch]["pages"].size() - 1
		else:
			pg = 0
			return
	Sfx.play("page_open", 0.6)
	_show()

func _chapter(d: int) -> void:
	var n := clampi(ch + d, 0, book.size() - 1)
	if n != ch:
		ch = n
		pg = 0
		Sfx.play("page_open", 0.6)
		_show()

func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey) or not ev.pressed:
		return
	match ev.keycode:
		KEY_ESCAPE, KEY_K:
			close_book()
		KEY_DOWN, KEY_PAGEDOWN:
			_turn(1)
		KEY_UP, KEY_PAGEUP:
			_turn(-1)
		KEY_RIGHT:
			_chapter(1)
		KEY_LEFT:
			_chapter(-1)
		_:
			return
	get_viewport().set_input_as_handled()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := -1
		for i in rail_rows.size():
			if (rail_rows[i][0] as Rect2).has_point(ev.position):
				h = i
		if h != hover:
			hover = h
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		accept_event()
		var rr := _rail_rect()
		if rr.has_point(ev.position) and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rail_scroll = maxf(0.0, rail_scroll + (-60.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0))
			queue_redraw()
			return
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		for row in rail_rows:
			if (row[0] as Rect2).has_point(ev.position):
				ch = row[1]
				pg = row[2]
				Sfx.play("page_open", 0.6)
				_show()
				return
		var r := _page_rect()
		var nav_y := r.end.y - 30.0
		if ev.position.y > nav_y - 10.0 and ev.position.y < r.end.y + 10.0:
			if ev.position.x < r.position.x + 260.0:
				_turn(-1)
			elif ev.position.x > r.end.x - 260.0:
				_turn(1)
		var cx := get_viewport_rect().size.x - 60.0
		if Rect2(cx - 30, 20, 60, 44).has_point(ev.position):
			close_book()

func _draw() -> void:
	if book.is_empty():
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.03, 0.94))
	var w := minf(1500.0, vs.x - 120.0)
	var book_r := Rect2((vs.x - w) / 2.0, 40.0, w, vs.y - 80.0)
	draw_rect(book_r, INK)
	draw_rect(book_r, Color("#050407"), false, 4.0)
	draw_rect(book_r.grow(-8), MARROW_D, false, 1.0)
	# the gutter between the rail and the page
	var rr := _rail_rect()
	draw_line(Vector2(rr.end.x + 18, book_r.position.y + 30), Vector2(rr.end.x + 18, book_r.end.y - 30), RULE, 2.0)
	# the rail: chapters, and the open chapter's works under it
	var sc := U.font("sc")
	var fb := U.font("book")
	var fi := U.font("italic")
	draw_string(sc, Vector2(rr.position.x, rr.position.y + 6), "THE OSSUARY OF WORDS", HORIZONTAL_ALIGNMENT_LEFT, rr.size.x, 16, MARROW)
	rail_rows.clear()
	var y := rr.position.y + 40.0 - rail_scroll
	var ri := 0
	for ci in book.size():
		var c: Dictionary = book[ci]
		var sel := ci == ch
		var rect := Rect2(rr.position.x, y, rr.size.x, 32)
		if y > rr.position.y + 16 and y < rr.end.y - 20:
			rail_rows.append([rect, ci, 0])
			if sel:
				draw_rect(rect, INK2)
				draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), MARROW)
			var num := _roman(ci) if ci > 0 else "❧"
			draw_string(sc, rect.position + Vector2(12, 23), num, HORIZONTAL_ALIGNMENT_LEFT, 44, 15, MARROW_D)
			var col := BONE if sel or hover == ri else BONE_D
			draw_string(fb, rect.position + Vector2(56, 23), String(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 60, 20, col)
		ri += 1
		y += 34.0
		if sel:
			var pages: Array = c["pages"]
			for pi in range(1, pages.size()):
				var r2 := Rect2(rr.position.x + 24, y, rr.size.x - 24, 26)
				if y > rr.position.y + 16 and y < rr.end.y - 20:
					rail_rows.append([r2, ci, pi])
					var on := pi == pg
					if on:
						draw_rect(Rect2(r2.position, Vector2(2, r2.size.y)), MARROW)
					draw_string(fi, r2.position + Vector2(12, 19), String(pages[pi]["title"]), HORIZONTAL_ALIGNMENT_LEFT, r2.size.x - 14, 16, BONE if on or hover == ri else ASH)
				ri += 1
				y += 27.0
			y += 8.0
	# under the title: a short rule
	var pr := _page_rect()
	draw_line(Vector2(pr.position.x, text.position.y - 12), Vector2(pr.position.x + 40, text.position.y - 12), MARROW_D, 1.0)
	# the foot: turn back, where we are, turn on
	var fy := pr.end.y - 8.0
	draw_line(Vector2(pr.position.x, fy - 30), Vector2(pr.end.x, fy - 30), RULE, 1.0)
	var np: int = book[ch]["pages"].size()
	if ch > 0 or pg > 0:
		draw_string(fi, Vector2(pr.position.x, fy), "← the leaf before", HORIZONTAL_ALIGNMENT_LEFT, 260, 19, MARROW)
	if ch < book.size() - 1 or pg < np - 1:
		draw_string(fi, Vector2(pr.end.x - 260, fy), "the leaf after →", HORIZONTAL_ALIGNMENT_RIGHT, 260, 19, MARROW)
	var where := ("%s · %d of %d" % [_roman(ch), pg + 1, np]) if ch > 0 else "❧"
	draw_string(sc, Vector2(pr.get_center().x - 150, fy), where, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, ASH)
	# close
	var cx := vs.x - 60.0
	draw_string(sc, Vector2(cx - 12, 52), "X", HORIZONTAL_ALIGNMENT_LEFT, 30, 22, BONE_D)

func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 10)]
