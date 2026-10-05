extends Node2D
## entities/class_lamp.gd: an order's own lamp, as the web draws it. It floats with the Wickbound (entities/lantern_unit.gd,
## unit): every lantern is bound with a soul and follows on its own (the user, 2026-10-01). Without a unit it hangs
## from the hand, as the web carried it:
## - the Ossuarch (zz_tune_v59.js:18-96): a small stained skull in a black iron cage on a short chain, hanging from his
##   hand and drifting like something underwater, trailing a little when he moves; incense-thick bone-white vapour pours
##   from it in a slow ribbon and rises; his light comes from inside the skull.
## - the Shrine Keeper (zd_world22.js:459-476, lampFrame): a paper lantern on a short pole, black ribs, a warm glow inside.
## - the Empty Hand (zw_monk_ui.js:1733-1752): none by day, nor while he holds the sun or the nothing; by night a paper
##   lantern gone grey-dark with a black flame and a thin violet-white edge.
## Its glass (glass_screen) is where world/dark_layer.gd opens the small glow round the lamp.

const PX := 4.0
const SKULL := [
	"iVBORw0KGgoAAAANSUhEUgAAAAsAAAARCAYAAAAL4VbbAAABIUlEQVR4nGNgwAI4OTj/YxPHqZBkDeiACZugpJgIVkNQFHNycP7n5OD8LyctDmcjyzMiK+xtzmFgYGBg6Jm8giEi0IGBgYGBoX/mGobvP74zwk1GVvjkyQsUqwM9rOB+QHEGusIHD5+h8Bk5OTj/mxtqMzx6+hKrp2Dg+as3EJPDghwZXr95w/D6zRu4WyMCHeBiFkZqiNCAWb97y2wME3dvmc3w5NkrRGhwcnD+L0wPYWBgYGCYPHsNg6iICMPrN28YfN2sGJ48e8Vw+tIdhu8/vjPCPfjg4TOGdZv2M+SmhjCwMf9nyE0NYTh38SaKLUwMDAwM3398Z1y/4xhKCMBomKkYQScmKoiVhgcdMoeTg/M/crp4/uoN3FSsAF8SBQAyEHMcaQNGtgAAAABJRU5ErkJggg==",
	"iVBORw0KGgoAAAANSUhEUgAAAAsAAAARCAYAAAAL4VbbAAABIUlEQVR4nGNgwAI4OTj/YxPHqZBkDeiACZugpJgIVkNQFHNycP7n5OD8LyctDmcjyzMiK+xtzmFgYGBg6Jm8giEi0IGBgYGBoX/mGobvP74zwk1GVvjkyQsUqwM9rOB+QHEGusIHD5+h8Bk5OTj/mxtqMzx6+hKrp2Dg+as3EJPDghwZXr95w/D6zRu4WyMCHeBiFkZqiNCAWX/90l4ME69f2svw5NkrRGhwcnD+L0wPYWBgYGCYPHsNg6iICMPrN28YfN2sGJ48e8Vw+tIdhu8/vjPCPfjg4TOGdZv2M+SmhjCwMf9nyE0NYTh38SaKLUwMDAwM3398Z1y/4xhKCMBomKkYQScmKoiVhgcdMoeTg/M/crp4/uoN3FSsAF8SBQADO3PUtXTIwwAAAABJRU5ErkJggg==",
	"iVBORw0KGgoAAAANSUhEUgAAAAsAAAARCAYAAAAL4VbbAAABIUlEQVR4nGNgwAI4OTj/YxPHqZBkDeiACZugpJgIVkNQFHNycP7n5OD8LyctDmcjyzMiK+xtzmFgYGBg6Jm8giEi0IGBgYGBoX/mGobvP74zwk1GVvjkyQsUqwM9rOB+QHEGusIHD5+h8Bk5OTj/mxtqMzx6+hKrp2Dg+as3EJPDghwZXr95w/D6zRu4WyMCHeBiFkZqiNCAWb97y2wME3dvmc3w5NkrRGhwcnD+L0wPYWBgYGCYPHsNg6iICMPrN28YfN2sGJ48e8Vw+tIdhu8/vjPCPfjg4TOGdZv2M+SmhjCwMf9nyE0NYTh38SaKLUwMDAwM3398Z1y/4xhKCMBomKkYQScmKoiVhgcdMoeTg/M/crp4/uoN3FSsAF8SBQAyEHMcaQNGtgAAAABJRU5ErkJggg==",
	"iVBORw0KGgoAAAANSUhEUgAAAAsAAAARCAYAAAAL4VbbAAABIElEQVR4nGNgwAI4OTj/YxPHqZBkDeiACZugpJgIVkNQFHNycP7n5OD8LyctDmcjyzMiK+xtzmFgYGBg6Jm8giEi0IGBgYGBoX/mGobvP74zwk1GVvjkyQsUqwM9rOB+QHEGusIHD5+h8Bk5OTj/mxtqMzx6+hKrp2Dg+as3EJPDghwZXr95w/D6zRu4WyMCHeBiFkZqiNCAWd/ZlI1hYmdTNsOTZ68QocHJwfm/MD2EgYGBgWHy7DUMoiIiDK/fvGHwdbNiePLsFcPpS3cYvv/4zgj34IOHzxjWbdrPkJsawsDG/J8hNzWE4dzFmyi2MDEwMDB8//Gdcf2OYyghAKNhpmIEnZioIFYaHnTIHE4Ozv/I6eL5qzdwU7ECfEkUAOF2cfTkwivTAAAAAElFTkSuQmCC",
]
const SK_W := 11
const SK_H := 17
const HANG_X := 5.0
const CHAIN := 2
const BAYER4 := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const WispView = preload("res://skills/animancer/wisp_view.gd")
static var _frames := {}
static var _discs := {}

var hero: Hero
var unit: Node2D = null      # the Wickbound it floats with (its parent)
var cls := ""
var t := 0.0
var a := 0.0                 # the skull's swing (radians)
var va := 0.0
var last := Vector2.INF
var acc := 0.0
var vap: Array = []          # [tile, sx, sy, ox, oy, vz, vx, t, T, ph, s] (web px from that tile's screen point)
var back := false
var tex: Array = []

## the orders that carry a lamp in hand
static func carries(c: String) -> bool:
	return c in ["ossumancer", "miasmancer", "monk"]

func setup(h: Hero) -> void:
	hero = h
	cls = h.cls
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cls == "ossumancer":
		for b in SKULL:
			var img := Image.new()
			img.load_png_from_buffer(Marshalls.base64_to_raw(b))
			tex.append(ImageTexture.create_from_image(img))
	else:
		tex = [frame(cls)]

func _sky() -> float:
	var sk = hero.skills
	return float(sk.sky_k()) if sk != null and sk.has_method("sky_k") else -1.0

func is_hidden() -> bool:
	return _monk_hidden()

func _monk_hidden() -> bool:
	if cls != "monk" or hero.skills == null:
		return false
	var k := _sky()
	return (0.4 if k < 0.0 else k) > 0.5 or float(hero.skills.get("sun_t")) > 0.0 or float(hero.skills.get("nothing_t")) > 0.0

# ------------------------------------------------------------------ where it hangs
## the hand, in web px from his feet, per view (measured on the sprite: zz_tune_v59.js:28)
func _hand() -> Vector2:
	if unit != null:
		return Vector2(0, -float(unit.z) - 6.0)   # hung from nothing, at the soul's own height
	var v: String = hero.view
	var H := Vector2(5, -19)
	match v:
		"front": H = Vector2(-3, -18)
		"side": H = Vector2(6, -19)
		"down": H = Vector2(7, -18)
		"back": H = Vector2(-4, -19)
	return Vector2(H.x * hero.face, H.y)

## the skull's heart (web px from his feet)
func _heart() -> Vector2:
	var R := CHAIN + SK_H / 3.0 * 0.45
	return _hand() + Vector2(-sin(a) * R, cos(a) * R)

func _sway() -> float:
	return sin(t * 2.4) * 1.2 + (sin(t * 9.0) * 0.8 if hero.walking else 0.0)

## the glass, in screen space (where the light comes from)
func glass_screen() -> Vector2:
	if unit != null:
		return unit.glass_screen()
	if cls == "ossumancer":
		return hero.position + _heart() * PX
	var sw := _sway()
	return hero.position + Vector2(hero.face * 7 + sw, -14 + absf(sw) * 0.3 + 0.8) * PX

func _process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		queue_free()
		return
	t += dt
	visible = not hero.dead and not _monk_hidden()
	if unit == null:
		back = hero.view in ["back", "up"]
		position = hero.position + Vector2(0, -1.0 if back else 1.0)   # behind him when he faces away
	if cls == "ossumancer":
		_tick_skull(minf(dt, 0.05))
	queue_redraw()

func _tick_skull(dt: float) -> void:
	if dt <= 0.0:
		return
	var vx := 0.0
	if last != Vector2.INF:
		vx = ((_tp().x - last.x) - (_tp().y - last.y)) / dt
	last = _tp()
	var drift := sin(t * 0.55) * 0.035 + sin(t * 0.23 + 1.7) * 0.025       # slow, small, dreamy
	var want := drift - clampf(vx * 0.05, -0.22, 0.22)
	va += ((want - a) * 3.2 - va * 2.6) * dt
	a += va * dt
	if hero.dead:
		return
	# a steady pour (evenly spaced, so it reads as a ribbon), each wisp born at the skull and left in the world
	acc += dt * (12.0 if Settings.fewer_fx else 30.0)
	var L := _heart()
	while acc >= 1.0:
		acc -= 1.0
		vap.append([_tp(), L.x + (randf() - 0.5) * 1.5, L.y - 2.0, 0.0, 0.0, 4.0 + randf() * 2.0, (randf() - 0.5) * 0.8, 0.0, 2.6 + randf() * 1.2, randf() * 6.0, 0.8 + randf() * 0.6])
	for w in vap:
		w[7] += dt
		w[4] -= w[5] * dt
		w[5] *= 1.0 - dt * 0.28
		w[3] += (w[6] + sin(t * 0.7 + w[9] * 0.15) * 1.1 * minf(1.0, w[7])) * dt
	for i in range(vap.size() - 1, -1, -1):
		if w_done(vap[i]):
			vap.remove_at(i)
	if vap.size() > 150:
		vap = vap.slice(vap.size() - 150)

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if tex.is_empty():
		return
	var o := Vector2(0, 1.0 if back else -1.0) if unit == null else Vector2.ZERO    # undo the sorting nudge
	if cls == "ossumancer":
		_draw_skull(o)
		return
	# the paper lanterns, carried at his side with a little sway (zd_world22.js:467-472)
	var sw := _sway()
	var X := roundf(hero.face * 7 - 6 + sw)
	var Y := roundf(-14 - 8 + absf(sw) * 0.3)
	if unit != null:   # floating: the soul is the flame, the glass at its height
		X = -6.0
		Y = roundf(-float(unit.z) - 16 * 0.55)
	draw_texture_rect(tex[0], Rect2(Vector2(X, Y) * PX + o, Vector2(12, 16) * PX), false, Color.WHITE)
	# its glow, a faint swell (the web's LAMP_RGB; the Empty Hand's turns cold by night)
	var rgb := Color8(255, 200, 140)
	if cls == "monk":
		var k := _sky()
		rgb = Color8(255, 214, 140) if k < 0.0 or k > 0.5 else Color8(150, 130, 190)
	var c := Vector2(X + 6, Y + 16 * 0.55)
	draw_texture_rect(WispView.halo(6), Rect2((c - Vector2(6, 6)) * PX + o, Vector2(12, 12) * PX), false, Color(rgb.r, rgb.g, rgb.b, 0.12 + 0.03 * sin(t * 9.0)))

## where it is in the world (tiles)
func _tp() -> Vector2:
	return unit.tp if unit != null else hero.tp

func _draw_skull(o: Vector2) -> void:
	var me := Iso.to_screen(_tp())
	var s := PX / 3.0
	var h := (_hand() * PX).round() + o
	var seq := [0, 1, 2, 3, 2, 1]
	var fi: int = seq[int(t * 2.2) % seq.size()]
	draw_set_transform(h, a, Vector2.ONE)
	for i in CHAIN:   # the chain: two links
		draw_rect(Rect2(Vector2(-s, i * PX), Vector2(s * 2.0, PX * (0.67 if i % 2 else 1.0))), Color("#16131a"))
	draw_set_transform(h, a, Vector2(-1.0 if hero.face < 0 else 1.0, 1.0))
	draw_texture_rect(tex[fi], Rect2(Vector2(-HANG_X * s, CHAIN * PX), Vector2(SK_W, SK_H) * s), false)
	draw_set_transform(o, 0.0, Vector2.ONE)
	# the vapour: soft bone-white wisps, dense and small as they leave the skull, widening and thinning as they climb
	for w in vap:
		var k: float = w[7] / w[8]
		var al := k / 0.1 if k < 0.1 else pow(1.0 - (k - 0.1) / 0.9, 1.4)
		var p: Vector2 = Iso.to_screen(w[0]) - me + Vector2(w[1] + w[3], w[2] + w[4]) * PX
		_puff(p, (0.45 + k * 2.4) * w[10], Color(226 / 255.0, 220 / 255.0, 204 / 255.0, al * (0.34 - k * 0.2)))
		if k < 0.45:
			draw_rect(Rect2((p / s).round() * s - Vector2(s, 0), Vector2(s, s) * 2.0), Color(242 / 255.0, 238 / 255.0, 226 / 255.0, al * 0.22 * (1.0 - k / 0.45)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## a soft round puff: a filled ellipse on the hero's grain (the web's canvas ellipse)
func _puff(c: Vector2, r_web: float, col: Color) -> void:
	var rr := maxi(1, int(round(r_web * 3.0)))
	var s := PX / 3.0
	draw_texture_rect(_disc(rr), Rect2(((c / s).round() - Vector2(rr, rr * 0.8)) * s, Vector2(rr * 2, rr * 1.6) * s), false, col)

static func _disc(r: int) -> Texture2D:
	if _discs.has(r):
		return _discs[r]
	var n := r * 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			if Vector2(x + 0.5 - r, y + 0.5 - r).length() <= r:
				img.set_pixel(x, y, Color.WHITE)
	var tx := ImageTexture.create_from_image(img)
	_discs[r] = tx
	return tx

# ------------------------------------------------------------------ the painted paper lanterns (zh_hires22.js painter2)
static func _ramp(dark: Color, mid: Color, light: Color, n: int) -> Array:
	var out := []
	for i in n:
		var u := i / float(n - 1)
		out.append(dark.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(light, (u - 0.5) * 2.0))
	return out

class Painter:
	var img: Image
	var ox := 6.0
	var oy := 14.0
	func _init(w: int, h: int) -> void:
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	func fill(X: int, Y: int, w: int, h: int, col: Color) -> void:
		for yy in range(Y, Y + h):
			for xx in range(X, X + w):
				if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
					img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(col) if col.a < 1.0 else col)
	func hx(v: float) -> int:
		return int(round((ox + v) * 2.0))
	func hy(v: float) -> int:
		return int(round((oy + v) * 2.0))
	func R(a0: float, b0: float, w: float, h: float, col: Color) -> void:
		fill(hx(a0), hy(b0), maxi(1, int(round(w * 2))), maxi(1, int(round(h * 2))), col)
	func P(a0: float, b0: float, col: Color) -> void:
		fill(hx(a0), hy(b0), 1, 1, col)
	func L(a0: float, b0: float, a1: float, b1: float, col: Color) -> void:
		var n := maxi(1, int(ceil(maxf(absf(a1 - a0), absf(b1 - b0)) * 2)))
		for i in n + 1:
			var u := i / float(n)
			fill(int(round((ox + a0 + (a1 - a0) * u) * 2)), int(round((oy + b0 + (b1 - b0) * u) * 2)), 1, 1, col)
	func E(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
		var RX := rx * 2
		var RY := ry * 2
		var CX := (ox + cx) * 2
		var CY := (oy + cy) * 2
		for yy in range(-int(ceil(RY)), int(ceil(RY)) + 1):
			var v := (yy + 0.5) / RY
			if absf(v) > 1.0:
				continue
			var hw := RX * sqrt(1.0 - v * v)
			var l := int(round(CX - hw))
			var r := int(round(CX + hw))
			if r > l:
				fill(l, int(round(CY + yy)), r - l, 1, col)
	func ball(cx: float, cy: float, rx: float, ry: float, ramp: Array, lit: float) -> void:
		var L3 := Vector3(-0.5, -0.62, 0.6).normalized()
		var RX := rx * 2
		var RY := ry * 2
		var CX := (ox + cx) * 2
		var CY := (oy + cy) * 2
		var ext := int(ceil(maxf(RX, RY)))
		for Y in range(int(floor(CY - ext)), int(ceil(CY + ext)) + 1):
			for X in range(int(floor(CX - ext)), int(ceil(CX + ext)) + 1):
				var u := (X + 0.5 - CX) / RX
				var v := (Y + 0.5 - CY) / RY
				var q := u * u + v * v
				if q > 1.0:
					continue
				var tt := 0.5 + 0.5 * (u * L3.x + v * L3.y + sqrt(1.0 - q) * L3.z) + lit
				var b := (float(BAYER4[(Y & 3) * 4 + (X & 3)]) + 0.5) / 16.0
				var i := clampi(int(floor(clampf(tt, 0.0, 1.0) * (ramp.size() - 1) + 0.5 + (b - 0.5) * 0.45)), 0, ramp.size() - 1)
				fill(X, Y, 1, 1, ramp[i])

static func frame(c: String) -> Texture2D:
	if _frames.has(c):
		return _frames[c]
	var A := Painter.new(24, 32)
	if c == "monk":
		A.L(0, -15, 0, -12.5, Color("#1a1210"))
		A.R(-1.4, -12.6, 2.8, 0.6, Color("#0a0808"))
		A.ball(0, -9, 2.5, 3.3, _ramp(Color("#060408"), Color("#2a2430"), Color("#6a6070"), 5), 0.05)
		for i in 4:
			A.L(-2.4, -11 + i * 1.4, 2.4, -11 + i * 1.4, Color(0, 0, 0, 0.6))
		A.E(0, -8.6, 1.1, 1.6, Color("#e8d8ff"))
		A.E(0, -8.4, 0.8, 1.3, Color("#000000"))
		A.P(0, -10.2, Color("#000000"))
		A.R(-1.4, -5.8, 2.8, 0.6, Color("#0a0808"))
		A.L(0, -5.2, 0, -3.6, Color("#6a5a8a"))
	else:
		# a paper lantern on a short pole. The web's paper is red (#5a1010 > #d8402a > #ffd6a0); by the user's rule there
		# is no red light, so here the paper is old oiled parchment.
		A.L(0, -15, 0, -12.5, Color("#3a2a1a"))
		A.R(-1.2, -12.6, 2.4, 0.6, Color("#1a1210"))
		A.ball(0, -9, 2.4, 3.2, _ramp(Color("#3a2614"), Color("#b0844a"), Color("#ffe2b0"), 5), 0.15)
		for i in 4:
			A.L(-2.3, -11 + i * 1.4, 2.3, -11 + i * 1.4, Color(20 / 255.0, 10 / 255.0, 10 / 255.0, 0.5))
		A.R(-1.2, -5.8, 2.4, 0.6, Color("#1a1210"))
		A.L(0, -5.2, 0, -3.6, Color("#c8a040"))
	_finish(A.img)
	var tx := ImageTexture.create_from_image(A.img)
	_frames[c] = tx
	return tx

## finishFrameHR (zh_hires22.js:72-92): lit top-left edges, darker bottom-right, a dark outline round it all
static func _finish(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var s := img.duplicate() as Image
	var on := func(i: int, j: int) -> bool: return i >= 0 and j >= 0 and i < w and j < h and s.get_pixel(i, j).a > 0.0
	for j in h:
		for i in w:
			var c := s.get_pixel(i, j)
			if c.a > 0.0:
				if not on.call(i, j - 1) or not on.call(i - 1, j):
					img.set_pixel(i, j, Color(minf(1.0, c.r * 1.14 + 12 / 255.0), minf(1.0, c.g * 1.1 + 9 / 255.0), minf(1.0, c.b * 1.02 + 4 / 255.0), c.a))
				elif not on.call(i + 1, j) or not on.call(i, j + 1):
					img.set_pixel(i, j, Color(c.r * 0.82, c.g * 0.78, minf(1.0, c.b * 0.88 + 6 / 255.0), c.a))
				continue
			var n := Vector2i(-1, -1)
			var lit := false
			if on.call(i + 1, j):
				n = Vector2i(i + 1, j)
				lit = true
			elif on.call(i, j + 1):
				n = Vector2i(i, j + 1)
				lit = true
			elif on.call(i - 1, j):
				n = Vector2i(i - 1, j)
			elif on.call(i, j - 1):
				n = Vector2i(i, j - 1)
			elif on.call(i + 1, j + 1):
				n = Vector2i(i + 1, j + 1)
			elif on.call(i - 1, j - 1):
				n = Vector2i(i - 1, j - 1)
			if n.x < 0:
				continue
			var k := 0.26 if lit else 0.12
			var nc := s.get_pixel(n.x, n.y)
			img.set_pixel(i, j, Color(nc.r * k + 7 / 255.0, nc.g * k + 5 / 255.0, nc.b * k + 11 / 255.0, 1.0))

func w_done(w: Array) -> bool:
	return w[7] >= w[8]
