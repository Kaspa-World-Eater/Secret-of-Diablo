extends Node2D
## A title stage: "the Seer's Bowl". The old web title's chapel (zp_title.js), captured whole (tools/cap_chapel2.js ->
## art/ui/title_bowl.png, 480x270 shown x4): the dead god's stone face sunk in the wall, weeping blood into a tarnished
## bronze bowl. A drop swells on the chin and falls; rings spread in the blood and bend the reflection of whoever looks
## down into it (shaders/title_blood.gdshader); the god's dying breath spills over the altar (title_breath.gdshader);
## candles gutter, embers rise, ash falls. Round the bowl a spill of tarot cards, five face up: the orders.
## The stage API (ui/title.gd): order_at(p), label_at(i), hint(); T is the title (mode, fig_hover, order_i, t).

const K := 4.0
const MARROW := Color("#c9974a")
const CARDS := [
	# order index (-1 = face down), emblem, at (chapel px), turn
	[-1, "", Vector2(266, 180), 0.62], [-1, "", Vector2(416, 178), -0.5], [-1, "", Vector2(222, 232), 0.25],
	[-1, "", Vector2(460, 232), -0.35], [-1, "", Vector2(308, 256), 0.95], [-1, "", Vector2(378, 257), -0.8],
	[-1, "", Vector2(252, 212), 1.3],
	[0, "drop", Vector2(240, 204), -0.4], [1, "mirror", Vector2(280, 240), -0.18], [2, "skull", Vector2(340, 249), 0.04],
	[3, "breath", Vector2(400, 240), 0.2], [4, "bowl", Vector2(440, 204), 0.42],
]
const SHIFT := -100.0
const CW := 21.0
const CH := 33.0

var T
var fx: Node2D
var fx_back: Node2D
var add_fx: Node2D
var blood: ColorRect
var breath: ColorRect
var cards: Array = []
var rings: Array = []
var drops: Array = []
var sparks: Array = []
var motes: Array = []
var candles: Array = []
var drop_t := 1.4
var chin := Vector2.ZERO
var _glow: Texture2D

func hint() -> String:
	return "Or turn a card beside the bowl."

func _ready() -> void:
	_glow = Lights.radial(128)
	var bg := TextureRect.new()
	bg.texture = load("res://art/ui/title_bowl.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# the web moves the chapel so the face stands in the middle (zz_title54.js:11, SHIFT -100) and fills the strip it
	# never painted on the right with its own left side, mirrored about the face, laid in with a stepped cross-fade
	position.x = SHIFT * K
	var mir := Node2D.new()
	mir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mir.draw.connect(_draw_mirror.bind(mir, bg.texture))
	add_child(mir)
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/title_bowl.json"))
	var pal := PackedVector3Array()
	if meta is Dictionary:
		for c in meta.get("candles", []):
			candles.append(Vector2(float(c[0]), float(c[1]) - float(c[2])) * K + Vector2(2, -2))
		var f: Array = meta.get("face", [340, 64, 125])
		chin = Vector2(float(f[0]) - 1.0, float(f[2]))
		for c in meta.get("blood", []):
			pal.append(Vector3(c[0], c[1], c[2]) / 255.0)
	blood = ColorRect.new()
	blood.position = Vector2(340 - 75 - 1, 202 - 32 - 1) * K
	blood.size = Vector2(152, 66) * K
	blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/title_blood.gdshader")
	bm.set_shader_parameter("refl", load("res://art/ui/title_refl.png"))
	bm.set_shader_parameter("pal", pal)
	blood.material = bm
	add_child(blood)
	fx_back = Node2D.new()
	fx_back.draw.connect(_draw_back)
	add_child(fx_back)
	breath = ColorRect.new()
	breath.position = Vector2(210, 94) * K
	breath.size = Vector2(260, 176) * K
	breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var brm := ShaderMaterial.new()
	brm.shader = load("res://shaders/title_breath.gdshader")
	breath.material = brm
	add_child(breath)
	var back: Texture2D = load("res://art/reading/cards/_back.png")
	for c in CARDS:
		var tex: Texture2D = back if c[0] < 0 else load("res://art/reading/cards/%s.png" % c[1])
		cards.append({"o": c[0], "at": (c[2] as Vector2) * K, "rot": c[3], "lift": 0.0, "tex": tex, "ph": randf() * TAU})
	fx = Node2D.new()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	for c in cards:
		var want := 1.0 if c["o"] >= 0 and (T.mode == "main" or T.mode == "order") and (T.fig_hover == c["o"] or T.order_i == c["o"]) else 0.0
		c["lift"] = lerpf(c["lift"], want, minf(1.0, dt * 7.0))
	drop_t -= dt
	if drop_t <= 0.0:
		drop_t = randf_range(1.8, 4.2)
		drops.append({"x": chin.x, "y": chin.y + 1.0, "ty": 202.0 - 4.0 + randf() * 10.0, "v": 10.0})
	for d in drops:
		d["v"] += 380.0 * dt
		d["y"] += d["v"] * dt
		if d["y"] >= d["ty"]:
			d["done"] = true
			rings.append({"x": d["x"], "y": d["ty"], "r": 0.0, "t": 0.0})
			for k in 6:
				sparks.append({"x": d["x"], "y": d["ty"], "vx": randf_range(-17, 17), "vy": -34.0 - randf() * 34.0, "t": 0.0})
			if randf() < 0.7:
				Sfx.play("glass", 0.08, randf_range(2.0, 2.4))
	drops = drops.filter(func(d): return not d.get("done", false))
	for r in rings:
		r["t"] += dt
		r["r"] += dt * 14.0 / (1.0 + r["t"] * 0.6)
	rings = rings.filter(func(r): return r["t"] < 3.4)
	for sp in sparks:
		sp["t"] += dt
		sp["vy"] += 260.0 * dt
		sp["x"] += sp["vx"] * dt
		sp["y"] += sp["vy"] * dt
	sparks = sparks.filter(func(sp): return sp["t"] < 0.35)
	var ra := []
	for i in 8:
		ra.append(Vector4(rings[i]["x"], rings[i]["y"], rings[i]["r"], rings[i]["t"]) if i < rings.size() else Vector4(0, 0, 0, -1))
	(blood.material as ShaderMaterial).set_shader_parameter("rings", ra)
	(blood.material as ShaderMaterial).set_shader_parameter("time", t)
	(breath.material as ShaderMaterial).set_shader_parameter("time", t)
	if motes.size() < 46 and randf() < dt * 9.0:
		if randf() < 0.55 and not candles.is_empty():
			var c: Vector2 = candles[randi() % candles.size()] / K
			motes.append({"x": c.x, "y": c.y - 2.0, "vx": randf_range(-2, 2), "vy": -8.0 - randf() * 10.0, "t": 0.0, "life": 1.4 + randf() * 2.2, "ember": true})
		else:
			motes.append({"x": 290.0 + randf() * 120.0, "y": -2.0, "vx": randf_range(-1, 2), "vy": 3.0 + randf() * 4.0, "t": 0.0, "life": 20.0, "ember": false})
	for m in motes:
		m["t"] += dt
		m["x"] += (m["vx"] + sin(t * 1.3 + m["y"] * 0.1) * (3.0 if m["ember"] else 1.5)) * dt
		m["y"] += m["vy"] * dt
	motes = motes.filter(func(m): return m["t"] < m["life"] and m["y"] < 272.0 and m["y"] > -4.0)
	fx.queue_redraw()
	fx_back.queue_redraw()
	add_fx.queue_redraw()

func _snap(p: Vector2) -> Vector2:
	return Vector2(floorf(p.x / K) * K, floorf(p.y / K) * K)

func _card_xform(c: Dictionary) -> Transform2D:
	var L: float = c["lift"]
	return Transform2D(lerpf(c["rot"], 0.0, L), Vector2(CW * K / 54.0, CH * K * lerpf(0.55, 1.0, L) / 84.0), 0.0, c["at"] + Vector2(0, -70.0 * L))

func _draw_fx() -> void:
	var order := range(cards.size())
	order.sort_custom(func(a, b): return cards[a]["lift"] < cards[b]["lift"] if absf(cards[a]["lift"] - cards[b]["lift"]) > 0.01 else cards[a]["at"].y < cards[b]["at"].y)
	for i in order:
		var c: Dictionary = cards[i]
		var L: float = c["lift"]
		fx.draw_set_transform(c["at"] + Vector2(6, 8), c["rot"], Vector2(CW * K / 54.0, CH * K * 0.55 / 84.0))
		fx.draw_rect(Rect2(-27, -42, 54, 84), Color(0, 0, 0, 0.45 + 0.1 * L))
		fx.draw_set_transform_matrix(_card_xform(c))
		var near_bowl: float = clampf(1.0 - (c["at"] as Vector2).distance_to(Vector2(1360, 800)) / 700.0, 0.0, 1.0)
		var lit: float = (0.5 + 0.25 * near_bowl + 0.08 * T._flick(c["ph"])) + 0.45 * L
		var dim := 0.6 if (T.mode == "main" and T.fig_hover >= 0 and c["o"] != T.fig_hover) else 1.0
		fx.draw_texture_rect(c["tex"], Rect2(-27, -42, 54, 84), false, Color(lit * dim * 1.05, lit * dim * 0.9, lit * dim * 0.75))
		if c["o"] >= 0 and L > 0.05:
			fx.draw_rect(Rect2(-28, -43, 56, 86), Color(MARROW, 0.7 * L), false, 1.0)
	fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in motes:
		var a: float = clampf(1.0 - m["t"] / m["life"], 0.0, 1.0)
		var p := Vector2(floorf(m["x"]), floorf(m["y"])) * K
		fx.draw_rect(Rect2(p, Vector2(K, K)), Color(1.0, 0.62 + 0.3 * a, 0.3, a) if m["ember"] else Color(0.42, 0.4, 0.44, 0.45))

func _draw_back() -> void:
	for i in candles.size():
		var c: Vector2 = candles[i]
		var g: float = T._flick(i * 1.7)
		fx_back.draw_rect(Rect2(_snap(c + Vector2(0, -8)), Vector2(K, 8 + roundf(g) * 4)), Color("#ecc47e"))
		fx_back.draw_rect(Rect2(_snap(c + Vector2(0, -12 - g * 4)), Vector2(K, K)), Color("#fff2c0"))
	var sw := clampf(1.0 - drop_t / 2.4, 0.0, 1.0)
	if sw > 0.3:
		fx_back.draw_rect(Rect2(Vector2(chin.x, chin.y + 1.0) * K, Vector2(K, K * (1.0 if sw < 0.75 else 2.0))), Color("#84181c"))
	for d in drops:
		fx_back.draw_rect(Rect2(Vector2(chin.x, floorf(d["y"])) * K, Vector2(K, K * 2)), Color("#84181c"))
	for sp in sparks:
		fx_back.draw_rect(Rect2(Vector2(floorf(sp["x"]), floorf(sp["y"])) * K, Vector2(K, K)), Color("#b83026"))

func _draw_add() -> void:
	for i in candles.size():
		var c: Vector2 = candles[i]
		var r: float = 36.0 + 10.0 * T._flick(i * 1.7)
		add_fx.draw_texture_rect(_glow, Rect2(c + Vector2(-r, -r - 8), Vector2(r * 2, r * 2)), false, Color(1.0, 0.6, 0.3, 0.2))

## the strip right of the chapel: its own left side, mirrored about the face (x 340)
func _draw_mirror(n: Node2D, tex: Texture2D) -> void:
	for i in 7:
		# a stepped cross-fade (six 2 px slices from 368), then the strip itself from 380 to the edge
		var x0 := 368.0 + i * 2.0 if i < 6 else 380.0
		var w := 2.0 if i < 6 else 100.0
		var a := (i + 1) / 7.0 if i < 6 else 1.0
		# screen x0..x0+w (the web's grid) shows the chapel at 580 - x, flipped (this stage stands at SHIFT)
		var sx := 580.0 - x0 - w
		n.draw_set_transform(Vector2((x0 - SHIFT + w) * K, 0), 0.0, Vector2(-1, 1))
		n.draw_texture_rect_region(tex, Rect2(0, 0, w * K, 270 * K), Rect2(sx, 0, w, 270), Color(1, 1, 1, a))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func order_at(p: Vector2) -> int:
	p -= position
	var best := -1
	var best_y := -INF
	for c in cards:
		if c["o"] < 0:
			continue
		var lp: Vector2 = _card_xform(c).affine_inverse() * p
		if Rect2(-30, -45, 60, 90).has_point(lp) and (c["at"].y + c["lift"] * 1000.0) > best_y:
			best_y = c["at"].y + c["lift"] * 1000.0
			best = c["o"]
	return best

func label_at(i: int) -> Vector2:
	for c in cards:
		if c["o"] == i:
			return c["at"] + Vector2(0, -300) + position
	return Vector2(1360, 500) + position
