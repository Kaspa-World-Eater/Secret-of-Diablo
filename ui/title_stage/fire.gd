extends Node2D
## A title stage: "the Pilgrims' Fire". The chapel of the weeping god (captured without the bowl, art/ui/title_chapel.png)
## with a fire on the flagstones where the bowl stood, and the pilgrims of the orders round it: the user's paintings cut
## out and brought to the chapel's grain (art/ui/pilgrim_*.png), lit from the fire's side, their shadows thrown away
## from it. The orders not yet painted keep their place with their tarot card stood up in the joints of the flagstones.
## Hover a pilgrim and they step into the light. Stage API as ui/title_stage/bowl.gd.

const K := 4.0
const MARROW := Color("#c9974a")
const FIRE := Vector2(1360, 954)
const FS := 1.7
## order index -> figure png ("" = a card stands in its place), foot (screen px), card emblem
const FIGS := [
	[0, "pilgrim_hemo", Vector2(928, 864), "drop"],
	[1, "pilgrim_mystic", Vector2(1152, 840), "mirror"],
	[2, "pilgrim_ossu", Vector2(1580, 840), "skull"],
	[3, "", Vector2(1760, 900), "breath"],
	[4, "", Vector2(1120, 1020), "bowl"],
]
const LANTERN_AT := Vector2(-80, -208)

var T
var figs: Array = []
var fx: Node2D
var fx_back: Node2D
var add_fx: Node2D
var candles: Array = []
var embers: Array = []
var drop_t := 2.0
var drop_y := -1.0
var chin := Vector2.ZERO
var _glow: Texture2D

func hint() -> String:
	return "Or choose one of those at the fire."

func _ready() -> void:
	_glow = Lights.radial(128)
	var bg := TextureRect.new()
	bg.texture = load("res://art/ui/title_chapel.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/title_chapel.json"))
	if meta is Dictionary:
		for c in meta.get("candles", []):
			candles.append(Vector2(float(c[0]), float(c[1]) - float(c[2])) * K + Vector2(2, -2))
		var f: Array = meta.get("face", [340, 64, 125])
		chin = Vector2(float(f[0]) - 1.0, float(f[2])) * K
	fx_back = Node2D.new()
	fx_back.draw.connect(_draw_back)
	add_child(fx_back)
	var shadows := Node2D.new()
	add_child(shadows)
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	for p in FIGS:
		var holder := Node2D.new()
		holder.position = p[2]
		world.add_child(holder)
		var spr: Sprite2D = Sprite2D.new()
		var sh: Sprite2D = null
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		if p[1] != "":
			spr.texture = load("res://art/ui/%s.png" % p[1])
			spr.scale = Vector2(K, K)
			spr.position = Vector2(-roundf(spr.texture.get_width() / 2.0) * K, -spr.texture.get_height() * K)
			sh = Sprite2D.new()
			sh.texture = spr.texture
			sh.centered = false
			sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shadows.add_child(sh)
		else:
			# the card stood up in the flagstones, leaning a little toward the fire
			spr.texture = load("res://art/reading/cards/%s.png" % p[3])
			spr.scale = Vector2(2, 2)
			spr.position = Vector2(-54, -168)
			spr.rotation = 0.06 * (1.0 if p[2].x < FIRE.x else -1.0)
		holder.add_child(spr)
		figs.append({"o": p[0], "spr": spr, "holder": holder, "shadow": sh, "base": p[2], "step": 0.0, "ph": randf() * TAU, "card": p[1] == ""})
	fx = Node2D.new()
	fx.draw.connect(_draw_fx)
	add_child(fx)
	add_fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_fx.material = mat
	add_fx.draw.connect(_draw_add)
	add_child(add_fx)

func _process(dt: float) -> void:
	var t: float = T.t
	var fire_k: float = 0.86 + 0.14 * T._flick(0.3)
	for f in figs:
		var i: int = f["o"]
		var want := 1.0 if ((T.mode == "main" or T.mode == "order") and (T.fig_hover == i or T.order_i == i)) else 0.0
		f["step"] = lerpf(f["step"], want, minf(1.0, dt * 5.0))
		var base: Vector2 = f["base"]
		var h: Node2D = f["holder"]
		var stepv: Vector2 = (FIRE - base).normalized() * 28.0 * float(f["step"])
		h.position = Vector2(roundf((base.x + stepv.x) / K) * K, roundf((base.y + stepv.y) / K) * K)
		var spr: Sprite2D = f["spr"]
		var d := h.position.distance_to(FIRE)
		var lit: float = clampf(1.3 - d / 700.0, 0.5, 1.1) * fire_k + 0.3 * float(f["step"])
		var dim := 0.55 if (T.mode == "main" and T.fig_hover >= 0 and T.fig_hover != i) else 1.0
		spr.modulate = Color(lit * dim * 1.05, lit * dim * 0.92, lit * dim * 0.8)
		if f["card"]:
			spr.position.y = -168.0 - 24.0 * float(f["step"])
			continue
		var breath := 1.0 if sin(t * 0.9 + float(f["ph"])) > 0.55 else 0.0
		spr.position.y = -spr.texture.get_height() * K - breath * K
		var sh: Sprite2D = f["shadow"]
		var away := h.position - FIRE
		var dir := Vector2(away.x, away.y * 0.6).normalized()
		var ya := -dir * 0.5 * K
		sh.transform = Transform2D(Vector2(K, 0), ya, h.position - Vector2(spr.texture.get_width() / 2.0 * K, 0) - ya * spr.texture.get_height())
		sh.modulate = Color(0, 0, 0, 0.55 * clampf(1.4 - d / 600.0, 0.2, 1.0))
	if randf() < dt * 9.0:
		embers.append({"p": FIRE + Vector2(randf_range(-50, 50), -90), "v": Vector2(randf_range(-14, 14), randf_range(-70, -40)), "t": 0.0, "life": randf_range(1.2, 2.6)})
	for e in embers:
		e["t"] += dt
		e["v"].x += sin(t * 2.0 + e["life"] * 7.0) * 12.0 * dt
		e["p"] += e["v"] * dt
	embers = embers.filter(func(e): return e["t"] < e["life"])
	drop_t -= dt
	if drop_t <= 0.0 and drop_y < 0.0:
		drop_y = 0.0
	if drop_y >= 0.0:
		drop_y += dt * (60.0 + drop_y * 4.0)
		if drop_y > 56.0:
			drop_y = -1.0
			drop_t = randf_range(3.0, 7.0)
	fx.queue_redraw()
	fx_back.queue_redraw()
	add_fx.queue_redraw()

func _snap(p: Vector2) -> Vector2:
	return Vector2(floorf(p.x / K) * K, floorf(p.y / K) * K)

func _draw_fx() -> void:
	var t: float = T.t
	fx.draw_set_transform(FIRE * (1.0 - FS), 0.0, Vector2(FS, FS))
	fx.draw_rect(Rect2(_snap(FIRE + Vector2(-44, -8)), Vector2(88, 12)), Color("#0f0905"))
	for l in [[-40, -14, 64, 8], [-20, -20, 60, 8], [-30, -4, 70, 8]]:
		fx.draw_rect(Rect2(_snap(FIRE + Vector2(l[0], l[1])), Vector2(l[2], l[3])), Color("#1b1008"))
		fx.draw_rect(Rect2(_snap(FIRE + Vector2(l[0], l[1])), Vector2(l[2], 4)), Color("#3d2512"))
	for i in 14:
		var g: float = T._flick(i * 1.3)
		fx.draw_rect(Rect2(_snap(FIRE + Vector2(-36.0 + i * 6.0, -8)), Vector2(4, 4)), Color("#b83026").lerp(Color("#ecc47e"), g * 0.6))
	var cols := 13
	for c in cols:
		var u := (float(c) / (cols - 1)) * 2.0 - 1.0
		var hgt: float = (1.0 - u * u) * (70.0 + 30.0 * T._flick(c * 2.1)) + 10.0
		var sway := sin(t * 3.0 + c * 0.7) * 6.0 + sin(t * 7.3 + c) * 3.0
		var y := 0.0
		while y < hgt:
			var k := y / hgt
			var col := Color("#fff2c0").lerp(Color("#ecc47e"), minf(1.0, k * 2.0)).lerp(Color("#e8704e"), clampf(k * 2.0 - 0.6, 0.0, 1.0)).lerp(Color("#84181c"), clampf(k * 2.0 - 1.3, 0.0, 1.0))
			if absf(u) > 0.6:
				col = col.lerp(Color("#e8704e"), 0.5)
			if k < 0.85 or fmod(t * 11.0 + c, 1.0) < 0.6:
				fx.draw_rect(Rect2(_snap(FIRE + Vector2(u * 34.0 + sway * k, -14.0 - y)), Vector2(K, K)), col)
			y += K
	fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in embers:
		var a: float = 1.0 - e["t"] / e["life"]
		fx.draw_rect(Rect2(_snap(e["p"]), Vector2(K, K)), Color(1.0, 0.55 + 0.35 * a, 0.25, a))

func _draw_back() -> void:
	for i in candles.size():
		var c: Vector2 = candles[i]
		var g: float = T._flick(i * 1.7)
		fx_back.draw_rect(Rect2(_snap(c + Vector2(0, -8)), Vector2(K, 8 + roundf(g) * 4)), Color("#ecc47e"))
		fx_back.draw_rect(Rect2(_snap(c + Vector2(0, -12 - g * 4)), Vector2(K, K)), Color("#fff2c0"))
	if drop_y >= 0.0:
		fx_back.draw_rect(Rect2(_snap(chin + Vector2(0, drop_y)), Vector2(K, K * 2)), Color("#84181c"))
	elif drop_t < 1.2:
		fx_back.draw_rect(Rect2(_snap(chin), Vector2(K, K * (1.0 if drop_t > 0.5 else 2.0))), Color("#5e1016"))

func _draw_add() -> void:
	var t: float = T.t
	var g: float = T._flick(0.3)
	var fr := 520.0 + 40.0 * g
	add_fx.draw_texture_rect(_glow, Rect2(FIRE + Vector2(-fr, -fr * 0.62 - 40), Vector2(fr * 2, fr * 1.24)), false, Color(1.0, 0.55, 0.25, 0.30 + 0.08 * g))
	var cr := 140.0 + 16.0 * g
	add_fx.draw_texture_rect(_glow, Rect2(FIRE + Vector2(-cr, -cr - 50), Vector2(cr * 2, cr * 2)), false, Color(1.0, 0.7, 0.35, 0.35))
	for i in candles.size():
		var c: Vector2 = candles[i]
		var r: float = 36.0 + 10.0 * T._flick(i * 1.7)
		add_fx.draw_texture_rect(_glow, Rect2(c + Vector2(-r, -r - 8), Vector2(r * 2, r * 2)), false, Color(1.0, 0.6, 0.3, 0.22))
	for e in embers:
		var a: float = 1.0 - e["t"] / e["life"]
		add_fx.draw_texture_rect(_glow, Rect2(e["p"] - Vector2(10, 10), Vector2(20, 20)), false, Color(1.0, 0.5, 0.2, 0.3 * a))
	for f in figs:
		if f["o"] == 1:
			var lp: Vector2 = (f["holder"] as Node2D).position + LANTERN_AT
			var lr := 60.0 + 8.0 * sin(t * 2.3)
			add_fx.draw_texture_rect(_glow, Rect2(lp - Vector2(lr, lr), Vector2(lr * 2, lr * 2)), false, Color(0.45, 0.75, 0.8, 0.28))

func order_at(p: Vector2) -> int:
	var best := -1
	for f in figs:
		var h: Node2D = f["holder"]
		var r := Rect2(h.position + Vector2(-70, -200), Vector2(140, 210)) if f["card"] else Rect2(h.position + Vector2(-110, -500), Vector2(220, 510))
		if r.has_point(p):
			if best < 0 or h.position.y > (figs[best]["holder"] as Node2D).position.y:
				best = figs.find(f)
	return -1 if best < 0 else figs[best]["o"]

func label_at(i: int) -> Vector2:
	for f in figs:
		if f["o"] == i:
			return (f["holder"] as Node2D).position + Vector2(0, -250.0 if f["card"] else -560.0)
	return Vector2(1360, 900)
