extends RefCounted
## ui/uikit.gd: the shared look of the interface (the web build's zz_ui.js / zz_ui_hud.js, drawn at 4 screen px per logical
## px on the 1920x1080 view). Fonts (IM Fell English, IM Fell English SC, Silkscreen), colours, the carved page, rules,
## studs, recesses, the 3x5 micro numerals, textures loaded with or without an import, and small text helpers.
## Everything takes LOGICAL coordinates (the web's 480x270 grid) unless the name ends in _px.

const S := 4.0                       # screen px per logical px

# ---- colours (web: zz_ui.js CLSCOL / TABCOL, e_ui.js text colours)
const INK := Color("#0a090d")
const SEAM := Color("#050407")
const TEXT := Color("#e8e2d0")
const MUTED := Color("#a39d8c")
const DIM := Color("#6f6a79")
const FAINT := Color("#5a5563")
const GOLD := Color("#f0d080")
const GOLD_D := Color("#d9a441")
const RED := Color("#c8553d")
const BLUE := Color("#8b95ff")
const POISE := Color("#9ac070")
const CLSCOL := {"animancer": "#8ecbff", "ossumancer": "#e8e2d0", "hemomancer": "#e05060", "miasmancer": "#b070e0", "monk": "#f0c040"}
const TABCOL := {
	"animancer": ["#b8ccf0", "#8ecbff", "#f4f0ff"], "ossumancer": ["#e8e2d0", "#f0c8a0", "#b8ae94"],
	"hemomancer": ["#e05060", "#ff8090", "#d09a88"], "miasmancer": ["#b070e0", "#8ab8ff", "#d8c8e8"],
	"monk": ["#ffc040", "#8a80c0", "#c8c0b4"]}
const RANKCOL := {"champion": "#8b95ff", "unique": "#c9a45a", "boss": "#c8553d", "minion": "#e8e2d0", "normal": "#e8e2d0"}

static var _fonts := {}
static var _tex := {}

static func cls_col(cls: String) -> Color:
	return Color(CLSCOL.get(cls, "#c9a45a"))

static func tab_col(cls: String, t: int) -> Color:
	var a: Array = TABCOL.get(cls, TABCOL["animancer"])
	return Color(a[t]) if t >= 0 and t < a.size() else cls_col(cls)

# ------------------------------------------------------------------ fonts
## "pixel" Silkscreen (the web's 8px FONT), "book" IM Fell English, "italic", "sc" IM Fell English SC (titles, numbers)
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var file: String = {"pixel": "Silkscreen-Regular.ttf", "book": "IMFeENrm28P.ttf", "italic": "IMFeENit28P.ttf", "sc": "IMFeENsc28P.ttf"}.get(kind, "IMFeENrm28P.ttf")
	var path := "res://art/fonts/" + file
	var f: FontFile = null
	if ResourceLoader.exists(path):
		f = load(path)
	if f == null:
		f = FontFile.new()
		if f.load_dynamic_font(ProjectSettings.globalize_path(path)) != OK:
			f = null
	if f == null:
		_fonts[kind] = ThemeDB.fallback_font
		return _fonts[kind]
	if kind == "pixel":
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonts[kind] = f
	return f

# ------------------------------------------------------------------ textures (imported or straight from the PNG)
static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			t = ImageTexture.create_from_image(img)
	_tex[path] = t
	return t

static func skill_icon(id: String, state: String = "lit") -> Texture2D:
	var p := "res://art/icons/%s%s.png" % [id, "" if state == "lit" else "@" + state]
	var t := tex(p)
	if t == null and state != "lit":
		t = tex("res://art/icons/%s.png" % id)
	return t

# ------------------------------------------------------------------ drawing primitives (logical coords)
static func R(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * S, y * S, w * S, h * S)

static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(R(x, y, w, h), c)

static func frame(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color, t: float = 1.0) -> void:
	rect(ci, x, y, w, t, c)
	rect(ci, x, y + h - t, w, t, c)
	rect(ci, x, y, t, h, c)
	rect(ci, x + w - t, y, t, h, c)

## text at a logical baseline; size in logical px (8 = the web's pixel face); align -1 left, 0 centre, 1 right
static func text(ci: CanvasItem, s: String, x: float, y: float, c: Color, align: int = -1, kind: String = "pixel", size: float = 8.0, shadow: bool = true) -> float:
	var f := font(kind)
	var fs := int(roundf(size * S))
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var px := x * S - (w * 0.5 if align == 0 else (w if align > 0 else 0.0))
	var py := y * S
	if shadow:
		ci.draw_string(f, Vector2(px + S * 0.5, py + S * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.02, 0.02, 0.03, c.a * 0.9))
	ci.draw_string(f, Vector2(px, py), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return w / S

static func text_w(s: String, kind: String = "pixel", size: float = 8.0) -> float:
	return font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(roundf(size * S))).x / S

## word-wrap to a logical width
static func wrap(s: String, width: float, kind: String = "book", size: float = 8.0) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var t := word if line == "" else line + " " + word
			if text_w(t, kind, size) > width and line != "":
				out.append(line)
				line = word
			else:
				line = t
		out.append(line)
	return out

## smart quotes for the book faces (zz_fix_ui53.js)
static func smart(s: String) -> String:
	if s.find("\"") < 0 and s.find("'") < 0:
		return s
	var out := ""
	var dq := false
	for i in s.length():
		var ch := s[i]
		var prev := s[i - 1] if i > 0 else " "
		if ch == "\"":
			var open := not dq and (prev in [" ", "(", "[", "-", "—"] or i == 0)
			out += "“" if open else "”"
			dq = open
		elif ch == "'":
			out += "‘" if (prev in [" ", "(", "[", "\"", "“"] or i == 0) else "’"
		else:
			out += ch
	return out

# ------------------------------------------------------------------ the carved page (zz_ui.js pageBg), cached per size+tint
static func _hash(x: int, y: int) -> float:
	var s := sin(x * 127.1 + y * 311.7) * 43758.5453
	return s - floor(s)

static func page_tex(w: int, h: int, tint: Color) -> Texture2D:
	var key := "page%dx%d%s" % [w, h, tint.to_html()]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		for i in w:
			var n := _hash(i * 7 + 3, j * 11 + 5)
			var m := _hash(i >> 3, j >> 3)
			var s := _hash((i + 9) >> 5, (j + 4) >> 5)
			var e := mini(mini(i, j), mini(w - 1 - i, h - 1 - j))
			var vig := 0.62 + e * 0.0127 if e < 30 else 1.0
			var fib := 1.14 if _hash(i, j >> 1) > 0.965 else 1.0
			var k := (0.9 + (m - 0.5) * 0.18 + (-0.11 if s > 0.78 else 0.0) + (0.08 if n > 0.94 else (-0.08 if n < 0.05 else 0.0))) * vig * fib
			img.set_pixel(i, j, Color8(int(clampf(48 * k, 0, 255)), int(clampf(41 * k, 0, 255)), int(clampf(35 * k, 0, 255))))
	var band := func(i: int, c: Color) -> void:
		img.fill_rect(Rect2i(i, i, w - 2 * i, 1), c)
		img.fill_rect(Rect2i(i, h - 1 - i, w - 2 * i, 1), c)
		img.fill_rect(Rect2i(i, i, 1, h - 2 * i), c)
		img.fill_rect(Rect2i(w - 1 - i, i, 1, h - 2 * i), c)
	band.call(0, Color("#050407"))
	band.call(1, Color("#3a3544"))
	for i in [2, 3, 4]:
		band.call(i, Color("#2e2a38"))
	band.call(5, Color("#221e2a"))
	band.call(6, Color("#0a090d"))
	img.fill_rect(Rect2i(1, 1, w - 2, 1), Color("#5a5468"))
	img.fill_rect(Rect2i(1, 1, 1, h - 2), Color("#5a5468"))
	var tc := Color("#2e2a38").lerp(tint, 0.55)
	img.fill_rect(Rect2i(3, 3, w - 6, 1), tc)
	img.fill_rect(Rect2i(3, h - 4, w - 6, 1), tc)
	img.fill_rect(Rect2i(3, 3, 1, h - 6), tc)
	img.fill_rect(Rect2i(w - 4, 3, 1, h - 6), tc)
	# rivets along the band
	var rivet := func(x: int, y: int) -> void:
		img.fill_rect(Rect2i(x, y, 3, 3), Color("#0a090d"))
		img.fill_rect(Rect2i(x, y, 2, 2), Color("#7a7688"))
		img.set_pixel(x, y, Color("#b8b4c4"))
	for i in range(22, w - 22, 24):
		rivet.call(i, 2)
		rivet.call(i, h - 5)
	for j in range(22, h - 22, 24):
		rivet.call(2, j)
		rivet.call(w - 5, j)
	# corner rosettes: a carved plate, a diamond of the order's colour, a bone stud
	for c in [Vector2i(0, 0), Vector2i(w - 15, 0), Vector2i(0, h - 15), Vector2i(w - 15, h - 15)]:
		var cx: int = c.x
		var cy: int = c.y
		img.fill_rect(Rect2i(cx, cy, 15, 15), Color("#050407"))
		img.fill_rect(Rect2i(cx + 1, cy + 1, 13, 13), Color("#3a3544"))
		img.fill_rect(Rect2i(cx + 1, cy + 1, 13, 1), Color("#5a5468"))
		img.fill_rect(Rect2i(cx + 1, cy + 1, 1, 13), Color("#5a5468"))
		img.fill_rect(Rect2i(cx + 1, cy + 13, 13, 1), Color("#221e2a"))
		img.fill_rect(Rect2i(cx + 13, cy + 1, 1, 13), Color("#221e2a"))
		for k in 6:
			img.fill_rect(Rect2i(cx + 7 - k, cy + 2 + k, 1 + 2 * k, 1), Color("#0a090d"))
			img.fill_rect(Rect2i(cx + 7 - k, cy + 12 - k, 1 + 2 * k, 1), Color("#0a090d"))
		var dc := tint.darkened(0.15)
		for k in 4:
			img.fill_rect(Rect2i(cx + 7 - k, cy + 4 + k, 1 + 2 * k, 1), dc)
			img.fill_rect(Rect2i(cx + 7 - k, cy + 10 - k, 1 + 2 * k, 1), dc)
		img.fill_rect(Rect2i(cx + 6, cy + 6, 3, 3), Color("#e8e2d0"))
		img.set_pixel(cx + 6, cy + 6, Color.WHITE)
		img.set_pixel(cx + 8, cy + 8, Color("#0a090d"))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func page(ci: CanvasItem, x: float, y: float, w: int, h: int, tint: Color) -> void:
	ci.draw_texture_rect(page_tex(w, h, tint), R(x, y, w, h), false)

## an engraved rule with a diamond at each end
static func rule(ci: CanvasItem, x: float, y: float, w: float, c: Color) -> void:
	rect(ci, x, y, w, 1, INK)
	rect(ci, x, y + 1, w, 1, Color(c, 0.5))
	rect(ci, x - 2, y - 1, 3, 3, c)
	rect(ci, x + w - 1, y - 1, 3, 3, c)
	rect(ci, x - 1, y, 1, 1, INK)
	rect(ci, x + w, y, 1, 1, INK)

## an inset field: dark seam top-left, lit bottom-right
static func recess(ci: CanvasItem, x: float, y: float, w: float, h: float, fill: Color = Color("#1a1518")) -> void:
	rect(ci, x - 1, y - 1, w + 2, h + 2, SEAM)
	rect(ci, x, y, w, h, fill)
	rect(ci, x, y, w, 1, Color("#0c0a0e"))
	rect(ci, x, y, 1, h, Color("#0c0a0e"))
	rect(ci, x, y + h - 1, w, 1, Color("#332c34"))
	rect(ci, x + w - 1, y, 1, h, Color("#332c34"))

## a carved stud (a raised stone button)
static func stud(ci: CanvasItem, x: float, y: float, w: float, h: float, label: String = "", on: bool = true, col: Color = TEXT, hover: bool = false) -> void:
	rect(ci, x, y, w, h, SEAM)
	rect(ci, x + 1, y + 1, w - 2, h - 2, Color("#4a4258") if hover else (Color("#3a3446") if on else Color("#1f1c24")))
	rect(ci, x + 1, y + 1, w - 2, 1, Color("#6a6478") if on else Color("#2e2a36"))
	rect(ci, x + 1, y + 1, 1, h - 2, Color("#6a6478") if on else Color("#2e2a36"))
	rect(ci, x + 1, y + h - 2, w - 2, 1, Color("#15121a") if on else Color("#0e0c12"))
	rect(ci, x + w - 2, y + 1, 1, h - 2, Color("#15121a") if on else Color("#0e0c12"))
	if label != "":
		text(ci, label, x + w / 2.0, y + h - 3, col if on else FAINT, 0, "pixel", 8, false)

## the page title: IM Fell SC and a rule under it
static func title(ci: CanvasItem, s: String, cx: float, y: float, c: Color, rule_w: float = -1.0) -> void:
	text(ci, s, cx, y, c, 0, "sc", 16)
	var tw := minf(rule_w if rule_w > 0 else 400.0, text_w(s, "sc", 16) + 16)
	rule(ci, roundf(cx - tw / 2), y + 5, roundf(tw), c)

# ------------------------------------------------------------------ the 3x5 micro face (zz_ui_hud.js MF), 1 logical px per dot
const MF := {
	"0": "### #.# #.# #.# ###", "1": ".#. ##. .#. .#. ###", "2": "### ..# ### #.. ###", "3": "### ..# .## ..# ###",
	"4": "#.# #.# ### ..# ..#", "5": "### #.. ### ..# ###", "6": "### #.. ### #.# ###", "7": "### ..# ..# .#. .#.",
	"8": "### #.# ### #.# ###", "9": "### #.# ### ..# ###", "/": "..# ..# .#. #.. #..", "%": "##..# ##.#. ..#.. .#.## #..##",
	"+": "... .#. ### .#. ...", "-": "... ... ### ... ...", ".": "... ... ... ... .#.", ":": "... .#. ... .#. ...",
	"(": ".#. #.. #.. #.. .#.", ")": ".#. ..# ..# ..# .#.",
	"A": ".#. #.# ### #.# #.#", "B": "##. #.# ##. #.# ##.", "C": ".## #.. #.. #.. .##", "D": "##. #.# #.# #.# ##.",
	"E": "### #.. ##. #.. ###", "F": "### #.. ##. #.. #..", "G": ".## #.. #.# #.# .##", "H": "#.# #.# ### #.# #.#",
	"I": "### .#. .#. .#. ###", "J": "..# ..# ..# #.# .#.", "K": "#.# #.# ##. #.# #.#", "L": "#.. #.. #.. #.. ###",
	"M": "#.# ### ### #.# #.#", "N": "##. #.# #.# #.# #.#", "O": ".#. #.# #.# #.# .#.", "P": "##. #.# ##. #.. #..",
	"Q": ".#. #.# #.# ##. .##", "R": "##. #.# ##. #.# #.#", "S": ".## #.. .#. ..# ##.", "T": "### .#. .#. .#. .#.",
	"U": "#.# #.# #.# #.# ###", "V": "#.# #.# #.# #.# .#.", "W": "#.# #.# ### ### #.#", "X": "#.# #.# .#. #.# #.#",
	"Y": "#.# #.# .#. .#. .#.", "Z": "### ..# .#. #.. ###"}

static func _gw(ch: String) -> int:
	if ch == " ":
		return 2
	return (MF[ch] as String).split(" ")[0].length() if MF.has(ch) else 3

static func micro_w(s: String) -> float:
	var w := 0
	for ch in s.to_upper():
		w += _gw(ch) + 1
	return maxf(0, w - 1)

## pixel numerals and capitals, the top-left of the glyphs at (x, y); dot = logical px * scale
static func micro(ci: CanvasItem, s: String, x: float, y: float, c: Color, align: int = -1, shadow: bool = true, dot: float = 1.0) -> void:
	s = s.to_upper()
	var w := micro_w(s) * dot
	var x0: float = roundf(x - w / 2.0) if align == 0 else (roundf(x - w) if align > 0 else roundf(x))
	var passes := [[Color("#060508"), dot, dot], [c, 0.0, 0.0]] if shadow else [[c, 0.0, 0.0]]
	for p in passes:
		var px: float = x0 + p[1]
		for ch in s:
			if ch == " ":
				px += 3 * dot
				continue
			if MF.has(ch):
				var rows: PackedStringArray = (MF[ch] as String).split(" ")
				for j in rows.size():
					for i in rows[j].length():
						if rows[j][i] == "#":
							rect(ci, px + i * dot, y + p[2] + j * dot, dot, dot, p[0])
			px += (_gw(ch) + 1) * dot

# ------------------------------------------------------------------ the tooltip box (zz_ui.js drawTooltip), in screen px
## lines: Array of [text, Color] (or plain strings); returns nothing; draws near the mouse, kept on screen and off the bar
static func tooltip(ci: CanvasItem, lines: Array, mouse: Vector2, view: Vector2, bar_top: float = 944.0) -> void:
	if lines.is_empty():
		return
	var norm: Array = []
	for l in lines:
		if l is Array:
			norm.append([str(l[0]), l[1] if l.size() > 1 and l[1] is Color else (Color(l[1]) if l.size() > 1 and l[1] is String else TEXT)])
		else:
			norm.append([str(l), TEXT])
	var fs := 30
	var ft := font("book")
	var fsc := font("sc")
	var lh := 34.0
	var w := 0.0
	for i in norm.size():
		var f := fsc if i == 0 else ft
		w = maxf(w, f.get_string_size(norm[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs + (4 if i == 0 else 0)).x)
	w += 48.0
	var h := norm.size() * lh + 30.0
	var x := mouse.x + 28.0
	var y := mouse.y + 28.0
	if x + w > view.x:
		x = mouse.x - w - 16.0
	if y + h > bar_top:
		y = bar_top - h - 8.0
	x = maxf(0, x)
	y = maxf(0, y)
	var qc: Color = norm[0][1]
	ci.draw_rect(Rect2(x, y, w, h), Color(0.024, 0.02, 0.035, 0.96))
	ci.draw_rect(Rect2(x + 2, y + 2, w - 4, h - 4), Color("#050407"), false, 4.0)
	ci.draw_rect(Rect2(x + 6, y + 6, w - 12, h - 12), Color("#4a4458"), false, 2.0)
	ci.draw_rect(Rect2(x + 16, y + 48, w - 32, 3), Color(qc, 0.6))
	ci.draw_rect(Rect2(x + 16, y + 48, 12, 3), qc)
	ci.draw_rect(Rect2(x + w - 28, y + 48, 12, 3), qc)
	for c in [Vector2(x + 8, y + 8), Vector2(x + w - 16, y + 8), Vector2(x + 8, y + h - 16), Vector2(x + w - 16, y + h - 16)]:
		ci.draw_rect(Rect2(c, Vector2(8, 8)), Color("#8a8698"))
		ci.draw_rect(Rect2(c, Vector2(4, 4)), Color("#d0ccdc"))
	for i in norm.size():
		var f := fsc if i == 0 else ft
		var sz := fs + (4 if i == 0 else 0)
		var s: String = smart(norm[i][0])
		var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var by := y + 38.0 + i * lh + (10.0 if i > 0 else 0.0)
		ci.draw_string(f, Vector2(x + w / 2 - tw / 2 + 2, by + 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.9))
		ci.draw_string(f, Vector2(x + w / 2 - tw / 2, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, norm[i][1])
