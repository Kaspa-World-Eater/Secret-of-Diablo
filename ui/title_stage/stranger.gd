extends Node2D
## A title stage: "the Stranger's Box". The user's own animation of the Stranger (art/reading/stranger_sheet.webp,
## 121 frames of 320x270, shown x4) crouched in the ruin beside his little fire, the box of cards before him. The five
## orders lie face up across the lid, over the old spill; the fire throws its light across them and sends up embers.
## Hover a card and it rises off the lid and turns to you, and after a breath the Stranger whispers something of that
## order (WHISPERS, a different line each time). Begin a pilgrim and he draws the order's card from the deck at the
## end of the lid, turns it up and holds it out to you (draw_card), and the dark takes the rest.
## The painting's left edge goes down into the dark, where the words stand.
## The stage API (ui/title.gd): order_at(p), label_at(i), hint(); T is the title (mode, fig_hover, order_i, t).

const SK := 4.0
const FW := 320
const FH := 270
const FPS := 10.0
var pace = load("res://ui/stranger_pace.gd").new()
var sframe := 0
const X0 := 640.0                  # where the painting starts on screen
const MARROW := Color("#c9974a")
const DARK := Color(0.01, 0.01, 0.015)
const FIRE := Vector2(1862, 820)   # the fire, on screen
## the five orders across the lid (screen px, the card's centre as it lies; its turn)
const LID := [
	["drop", Vector2(790, 792), -0.22], ["mirror", Vector2(902, 776), -0.08], ["skull", Vector2(1012, 772), 0.03],
	["breath", Vector2(1122, 778), 0.12], ["bowl", Vector2(1230, 794), 0.26],
]
const CW := 84.0
const CH := 132.0
const DECK := Vector2(1334, 806)   # the face-down deck at the end of the lid
const U := preload("res://ui/uikit.gd")
## what he says of each order when you linger on its card (the PILGRIMS order: hemo, mystic, ossu, keeper, hand)
const WHISPERS := [
	["The Brotherhood bleeds first. Then it bleeds you.", "She is still open, the Maiden. She never closed.",
		"A cut is a door. Mind what walks through it.", "Not yet. Her road is still wet."],
	["Look into the glass long enough and it keeps some of you.", "The dead are lonely. They follow whoever listens.",
		"She sews the restless down. Thread holds better than prayer.", "Mirrors remember faces. Pray they forget yours."],
	["The Pale Order counts. Everything is counted, in the end.", "Bone is patient. It waited under your skin all your life.",
		"He does not bend. I have seen what bends him, and it broke.", "Not yet. He is still counting."],
	["Every breath carries something small out of you. She catches them.", "Paper, breath and a fan. You would be surprised what folds.",
		"Eight million small gods, and every one of them hungry.", "Smell that? Spoiled air. She calls it an offering."],
	["He gave away everything. Even the part that would have been afraid.", "The sun, or its going. He does not mind which.",
		"An empty hand can hold anything. Remember that when it closes.", "Sand runs down. Sand runs back. So does he."],
]

var T
var sheet: Texture2D
var paint: Node2D
var fx: Node2D
var add_fx: Node2D
var cards: Array = []
var motes: Array = []
var _glow: Texture2D
var words: Node2D
var w_i := -1                  # the order he is whispering of
var w_line := ""
var w_t := 0.0                 # time on this card
var w_a := 0.0                 # how much of the whisper is still in the air
var w_next := {}               # order -> the next line to say
var drawn := {}                 # the drawn card: {o, t, tex}
var back_tex: Texture2D

func hint() -> String:
	return "Or take a card from the Stranger's box."

func _ready() -> void:
	_glow = Lights.radial(128)
	sheet = load("res://art/reading/stranger_sheet.webp")
	paint = Node2D.new()
	paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paint.draw.connect(_draw_paint)
	add_child(paint)
	for i in LID.size():
		var c: Array = LID[i]
		cards.append({"o": i, "at": c[1], "rot": c[2], "lift": 0.0, "tex": load("res://art/reading/cards/%s.png" % c[0]), "ph": randf() * TAU})
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
	back_tex = load("res://art/reading/cards/_back.png")
	words = Node2D.new()
	words.draw.connect(_draw_words)
	add_child(words)
	for i in WHISPERS.size():
		w_next[i] = randi() % WHISPERS[i].size()

## Begin: he draws the order's card from the deck and holds it out (the title waits DRAW_LEN before it goes on)
const DRAW_LEN := 1.9
func draw_card(o: int) -> void:
	drawn = {"o": o, "t": 0.0, "tex": cards[o]["tex"] if o >= 0 and o < cards.size() else back_tex}
	w_a = 0.0
	Sfx.play("page_open", 0.5, 0.7)

func _process(dt: float) -> void:
	var t: float = T.t
	sframe = pace.step(dt)   # the Stranger mostly sits still; he gestures at random (ui/stranger_pace.gd)
	for c in cards:
		var want := 1.0 if (T.mode == "main" or T.mode == "order") and (T.fig_hover == c["o"] or T.order_i == c["o"]) else 0.0
		c["lift"] = lerpf(c["lift"], want, minf(1.0, dt * 7.0))
	# embers off the fire; dust hanging in the dark of the ruin (screen px, on the painting's grain)
	if motes.size() < 40 and randf() < dt * 8.0:
		if randf() < 0.6:
			motes.append({"x": FIRE.x + randf_range(-20, 16), "y": FIRE.y - 10.0, "vx": randf_range(-18, 6), "vy": -40.0 - randf() * 50.0, "t": 0.0, "life": 1.2 + randf() * 1.8, "ember": true})
		else:
			motes.append({"x": X0 + 100.0 + randf() * 1100.0, "y": -4.0, "vx": randf_range(-3, 5), "vy": 10.0 + randf() * 14.0, "t": 0.0, "life": 60.0, "ember": false})
	for m in motes:
		m["t"] += dt
		m["x"] += (m["vx"] + sin(t * 1.2 + m["y"] * 0.02) * (14.0 if m["ember"] else 5.0)) * dt
		m["y"] += m["vy"] * dt
	motes = motes.filter(func(m): return m["t"] < m["life"] and m["y"] < 1084.0 and m["y"] > -8.0)
	# the whisper: linger on a card and, after a breath, he speaks of that order
	var hov: int = T.fig_hover if T.mode == "main" and drawn.is_empty() else -1
	if hov != w_i:
		if hov >= 0:
			w_i = hov
			w_t = 0.0
			w_line = ""
		elif w_a <= 0.01:
			w_i = -1
	if hov >= 0:
		w_t += dt
		if w_line == "" and w_t > 0.45:
			var n: int = w_next[hov]
			w_line = WHISPERS[hov][n]
			w_next[hov] = (n + 1) % WHISPERS[hov].size()
			Sfx.play("page_close", 0.12, 0.55)
		if w_line != "":
			w_a = minf(1.0, w_a + dt * 2.5)
	else:
		w_a = maxf(0.0, w_a - dt * 1.8)
		if w_a <= 0.0:
			w_line = ""
	if not drawn.is_empty():
		drawn["t"] += dt
		if drawn["t"] > 0.5 and not drawn.get("flipped", false) and drawn["t"] > 0.75:
			drawn["flipped"] = true
			Sfx.play("page_close", 0.4, 1.3)
	words.queue_redraw()
	paint.queue_redraw()
	fx.queue_redraw()
	add_fx.queue_redraw()

func _draw_paint() -> void:
	paint.draw_rect(Rect2(0, 0, 1920, 1080), DARK)
	if sheet == null:
		return
	var f := sframe
	var src := Rect2((f % 11) * FW, (f / 11) * FH, FW, FH)
	paint.draw_texture_rect_region(sheet, Rect2(X0, 0, FW * SK, FH * SK), src)
	# its left edge goes down into the dark
	for k in 40:
		paint.draw_rect(Rect2(X0 + k * 8.0, 0, 8, 1080), Color(DARK, 1.0 - k / 40.0))

func _card_xform(c: Dictionary) -> Transform2D:
	var L: float = c["lift"]
	return Transform2D(lerpf(c["rot"], 0.0, L), Vector2(CW * lerpf(1.0, 1.5, L) / 54.0, CH * lerpf(0.5, 1.5, L) / 84.0), 0.0, c["at"] + Vector2(0, -170.0 * L))

func _draw_fx() -> void:
	var order := range(cards.size())
	order.sort_custom(func(a, b): return cards[a]["lift"] < cards[b]["lift"])
	for i in order:
		var c: Dictionary = cards[i]
		var L: float = c["lift"]
		fx.draw_set_transform(c["at"] + Vector2(-6, 8), c["rot"], Vector2(CW / 54.0, CH * 0.5 / 84.0))
		fx.draw_rect(Rect2(-27, -42, 54, 84), Color(0, 0, 0, 0.5 + 0.1 * L))
		fx.draw_set_transform_matrix(_card_xform(c))
		# lit from the fire at the right, more the nearer it lies
		var near: float = clampf(1.0 - (c["at"] as Vector2).distance_to(FIRE) / 1300.0, 0.0, 1.0)
		var lit: float = 0.42 + 0.3 * near + 0.1 * near * T._flick(c["ph"]) + 0.45 * L
		var dim := 0.6 if (T.mode == "main" and T.fig_hover >= 0 and c["o"] != T.fig_hover) else 1.0
		fx.draw_texture_rect(c["tex"], Rect2(-27, -42, 54, 84), false, Color(lit * dim * 1.05, lit * dim * 0.88, lit * dim * 0.72))
		if L > 0.05:
			fx.draw_rect(Rect2(-28, -43, 56, 86), Color(MARROW, 0.7 * L), false, 1.0)
	# the deck at the end of the lid, face down
	var near_d: float = clampf(1.0 - DECK.distance_to(FIRE) / 1300.0, 0.0, 1.0)
	var dl: float = 0.42 + 0.3 * near_d
	for k in 6:
		fx.draw_set_transform(DECK + Vector2(-k * 1.0, -k * 4.0), 0.34, Vector2(CW / 54.0, CH * 0.5 / 84.0))
		if k == 0:
			fx.draw_rect(Rect2(-27, -42, 54, 84), Color(0, 0, 0, 0.5))
		fx.draw_texture_rect(back_tex, Rect2(-27, -42, 54, 84), false, Color(dl * 0.8 * 1.05, dl * 0.8 * 0.88, dl * 0.8 * 0.72) * (0.85 + 0.03 * k))
	_draw_drawn()
	fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in motes:
		var a: float = clampf(1.0 - m["t"] / m["life"], 0.0, 1.0)
		var p := Vector2(floorf(m["x"] / SK), floorf(m["y"] / SK)) * SK
		fx.draw_rect(Rect2(p, Vector2(SK, SK)), Color(1.0, 0.6 + 0.3 * a, 0.28, a) if m["ember"] else Color(0.4, 0.4, 0.46, 0.35))

## the card he draws: up off the deck, turned over, then held out to you, larger, in the fire's light
func _draw_drawn() -> void:
	if drawn.is_empty():
		return
	var t: float = drawn["t"]
	var up := clampf(t / 0.45, 0.0, 1.0)            # lifted off the deck
	var flip := clampf((t - 0.45) / 0.4, 0.0, 1.0)  # turned over
	var out := clampf((t - 0.85) / 0.6, 0.0, 1.0)   # held out to you
	var e := 1.0 - pow(1.0 - out, 3.0)
	var at := DECK + Vector2(0, -150.0 * up)
	at = at.lerp(Vector2(1130, 520), e)
	var k := lerpf(1.0, 2.6, e)
	var sx := absf(cos(flip * PI))
	var face: bool = flip >= 0.5
	var rot := lerpf(0.34, 0.0, up)
	var sy := lerpf(0.5, 1.0, up)
	fx.draw_set_transform(at + Vector2(-8, 10) * k, rot, Vector2(CW * k * sx / 54.0, CH * k * sy / 84.0))
	fx.draw_rect(Rect2(-27, -42, 54, 84), Color(0, 0, 0, 0.45))
	fx.draw_set_transform(at, rot, Vector2(CW * k * maxf(0.04, sx) / 54.0, CH * k * sy / 84.0))
	var lit: float = 0.75 + 0.25 * e + 0.05 * T._flick(1.3)
	fx.draw_texture_rect(drawn["tex"] if face else back_tex, Rect2(-27, -42, 54, 84), false, Color(lit * 1.05, lit * 0.9, lit * 0.76))
	if face:
		fx.draw_rect(Rect2(-28, -43, 56, 86), Color(MARROW, 0.8), false, 1.0)

## his whisper, in the dark above the fire's reach
func _draw_words() -> void:
	if w_line == "" or w_a <= 0.0:
		return
	var f := U.font("italic")
	var n := int(clampf((w_t - 0.45) * 38.0, 0.0, float(w_line.length())))
	var shown := w_line.substr(0, n) if w_i == T.fig_hover else w_line
	var fw := f.get_string_size(w_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var p := Vector2(clampf(1290.0 - fw / 2.0, 700.0, 1880.0 - fw), 176)   # typed out from a fixed start, so it does not slide
	words.draw_string(f, p + Vector2(2, 2), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.8 * w_a))
	words.draw_string(f, p, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.86, 0.81, 0.72, 0.9 * w_a))

func _draw_add() -> void:
	# the fire's light, breathing
	var g: float = T._flick(0.7)
	var r := 260.0 + 40.0 * g
	add_fx.draw_texture_rect(_glow, Rect2(FIRE - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.55, 0.25, 0.12 + 0.05 * g))
	# and what of it falls on the lifted card
	for c in cards:
		if c["lift"] > 0.05:
			var at: Vector2 = c["at"] + Vector2(0, -170.0 * c["lift"])
			add_fx.draw_texture_rect(_glow, Rect2(at - Vector2(110, 110), Vector2(220, 220)), false, Color(1.0, 0.6, 0.3, 0.08 * c["lift"]))

func order_at(p: Vector2) -> int:
	var best := -1
	var best_k := -INF
	for c in cards:
		var lp: Vector2 = _card_xform(c).affine_inverse() * p
		if Rect2(-30, -45, 60, 90).has_point(lp) and c["lift"] * 10.0 + c["o"] * 0.01 > best_k:
			best_k = c["lift"] * 10.0 + c["o"] * 0.01
			best = c["o"]
	return best

func label_at(i: int) -> Vector2:
	return (LID[i][1] as Vector2) + Vector2(0, -390)
