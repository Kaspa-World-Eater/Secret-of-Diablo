extends CanvasLayer
## ui/reading.gd: the Reading, the Stranger's fire, where a new pilgrim is made (the web build's zp_reading.js).
## It follows "Begin" on an order's page at the title. The god is already chosen there, so the Reading opens with that
## god's card lying face up, and goes on: the face of the order you wear, a card drawn blind (upright or reversed),
## what you fear, what you go down for, the road that brought you, one question, and what you leave with him. Each
## choice gives a little and takes a little (data/reading.json, tools/reading_data.py); the sum, held within the caps,
## is the pilgrim's fate (HeroStats.fate) for the whole walk. Esc lets the Stranger choose the rest.
## The Stranger is the user's own animation (art/reading/stranger_sheet.webp: 121 frames of 320x270, shown x4).

const U := preload("res://ui/uikit.gd")
const BONE := Color("#dcd3c2")
const BONE_D := Color("#a39a8b")
const ASH := Color("#6f685f")
const MARROW := Color("#c9974a")
const MARROW_D := Color("#8c6a37")
const SK := 4.0                   # screen px per Stranger px
const FW := 320
const FH := 270
const FPS := 10.0
var pace = load("res://ui/stranger_pace.gd").new()
var sframe := 0
const CW := 162.0                 # a card on the cloth (54x84 x3)
const CH := 252.0
const STEPS := ["star", "face", "card", "fear", "seek", "road", "ask", "sac", "end"]
## what he asks at each step (one of these, each time)
const PROMPT := {
	"face": ["Your god you chose at the other fire. But a god wears more than one face, and one of them has been wearing you. Which?",
		"Three faces on the one god. Look at them. One of them looked back. Which?"],
	"card": ["Four of the old cards. I will not tell you what is on them. Take one, and we will see which way up you are.",
		"The deck is older than the Hide. Older than me, nearly. Draw. Do not turn it; I will."],
	"fear": ["What do you fear? Say it plainly. Down there it will be asked less kindly.",
		"Everyone brings a fear to my fire. Put yours on the cloth where I can see it."],
	"seek": ["And what do you go down for?", "Nobody goes down for nothing. What is it for you?"],
	"road": ["Which road brought you to my fire?", "You came a long way to sit on this stone. Which way?"],
	"sac": ["A reading is not free. Something stays here with me. What will it be?",
		"And now the price. Not copper. Something of you. Choose, before I do."],
}
const STEP_NAME := {"star": "The God", "face": "The Face", "card": "The Card", "fear": "The Fear", "seek": "The Seeking",
	"road": "The Road", "ask": "The Question", "sac": "The Price", "end": "The Reading"}
## how a fate's sum reads, in the order it is shown
const FX_ORDER := ["skt0", "skt1", "skt2", "vit", "spi", "con", "life", "hpPct", "mana", "armor", "stam", "res", "res_fire", "res_cold", "res_poison",
	"dmg", "dmg_day", "dmg_night", "raised", "fcr", "frw", "regen", "lok", "potion", "lrad", "mf", "gold", "xp"]
const LAB := {"con": " Constitution", "vit": " Vitality", "spi": " Essence", "life": " life", "stam": " poise",
	"lok": " life after each kill", "armor": " armor", "mf": "% magic find", "hpPct": "% life", "dmg": "% damage",
	"dmg_night": "% damage in the dark", "dmg_day": "% damage under an open sky", "raised": "% damage to the raised dead",
	"fcr": "% faster cast rate", "gold": "% gold found", "res": "% magic resist", "res_fire": "% fire resist",
	"res_cold": "% cold resist", "res_poison": "% poison resist", "frw": "% faster movement", "xp": "% experience",
	"lrad": "% lantern reach", "potion": "% from draughts"}

var main: Node
var cls := "animancer"
var R: Dictionary = {}
var root: Control
var sheet: Texture2D
var cards_tex := {}
var t := 0.0
var step_i := 0
var offer: Array = []             # what lies on the cloth now: dictionaries from reading.json
var hover := -1
var picked := -1                  # -1: choosing; else the card taken and the Stranger's answer is up
var said := ""
var reversed := false
var flip := 0.0                   # the drawn card turning over (0..1)
var prompt := ""
var picks: Array = []             # {step, id, name, emb, fx, rev}
var fate := {}
var prophecy := ""
var question: Dictionary = {}
var on_done: Callable
var fade := 0.0
var leaving := -1.0
var auto := ""                    # GM_READ_ACT: "all" picks everything, "end" skips to the end

func _init(m: Node = null, c: String = "animancer") -> void:
	main = m
	cls = c

func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/reading.json"))
	R = j if j is Dictionary else {}
	sheet = load("res://art/reading/stranger_sheet.webp")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.draw.connect(_draw_all)
	root.gui_input.connect(_gui)
	add_child(root)
	auto = OS.get_environment("GM_READ_ACT")
	_enter(0)

func _card(emb: String) -> Texture2D:
	if not cards_tex.has(emb):
		var p := "res://art/reading/cards/%s.png" % emb
		cards_tex[emb] = load(p) if ResourceLoader.exists(p) else load("res://art/reading/cards/_back.png")
	return cards_tex[emb]

# ------------------------------------------------------------------ the steps

func _enter(i: int) -> void:
	step_i = i
	picked = -1
	hover = -1
	said = ""
	flip = 0.0
	reversed = false
	var s: String = STEPS[i]
	var aside := ""
	var asides: Dictionary = R.get("asides", {})
	if asides.has(s) and randf() < 0.5:
		var a: Array = asides[s]
		aside = String(a[randi() % a.size()]) + "  "
	match s:
		"star":
			var st: Dictionary = R.get("stars", {}).get(cls, {})
			offer = [st]
			prompt = ""
			picked = 0
			said = String(st.get("say", ""))
			_take(st, false)
		"face":
			offer = R.get("faces", {}).get(cls, []).duplicate()
		"card":
			offer = _some(R.get("cards", []), 4)
		"fear", "seek", "road", "sac":
			var key: String = {"fear": "fears", "seek": "seeks", "road": "roads", "sac": "sacs"}[s]
			offer = _some(R.get(key, []), 3 if s == "road" else 4)
		"ask":
			var qs: Array = R.get("questions", [])
			question = qs[randi() % qs.size()] if not qs.is_empty() else {}
			offer = question.get("a", []).duplicate()
			prompt = aside + " ".join(PackedStringArray(question.get("q", [])))
		"end":
			offer = []
			# a prophecy that answers something he read tonight, if one does; else one of the old ones
			var ids := {}
			for p in picks:
				ids[p["id"]] = true
			var fit: Array = []
			var any: Array = []
			for pr in R.get("prophecies", []):
				if pr is String:
					any.append(pr)
				elif pr.has("when"):
					for w in pr["when"]:
						if ids.has(w):
							fit.append(pr["say"])
							break
				else:
					any.append(pr["say"])
			var pool: Array = fit if not fit.is_empty() and randf() < 0.75 else any
			prophecy = String(pool[randi() % pool.size()]) if not pool.is_empty() else ""
			_sum()
			prompt = "That is as much of you as I can see. Go on, then. The dark is expecting you."
	if PROMPT.has(s):
		var pv: Array = PROMPT[s]
		prompt = aside + String(pv[randi() % pv.size()])
	root.queue_redraw()

func _some(pool: Array, n: int) -> Array:
	var p := pool.duplicate()
	p.shuffle()
	return p.slice(0, mini(n, p.size()))

func _take(o: Dictionary, rev: bool) -> void:
	var fx: Dictionary = o.get("fx", {})
	if rev and o.has("rev"):
		fx = o["rev"].get("fx", {})
	picks.append({"step": STEPS[step_i], "id": o.get("id", ""), "name": o.get("name", ""), "emb": o.get("emb", ""), "fx": fx, "rev": rev})

func _pick(i: int) -> void:
	if picked >= 0 or i < 0 or i >= offer.size():
		return
	var o: Dictionary = offer[i]
	picked = i
	var s: String = STEPS[step_i]
	if s == "card":
		reversed = o.has("rev") and randf() < 0.35
		said = String(o["rev"].get("say", "")) if reversed else String(o.get("say", ""))
		Sfx.play("page_open", 0.9, 0.8)
	else:
		said = String(o.get("say", ""))
		Sfx.play("page_open", 0.7)
	_take(o, reversed)
	root.queue_redraw()

func _next() -> void:
	if STEPS[step_i] == "end":
		_finish()
		return
	Sfx.play("page_close", 0.4, 1.2)
	_enter(step_i + 1)

## let the Stranger choose the rest
func _skip() -> void:
	while STEPS[step_i] != "end":
		if picked < 0 and not offer.is_empty():
			_pick(randi() % offer.size())
		_enter(step_i + 1)

func _sum() -> void:
	fate = {}
	for p in picks:
		var fx: Dictionary = p["fx"]
		for k in fx:
			fate[k] = float(fate.get(k, 0.0)) + float(fx[k])
	var caps: Dictionary = R.get("caps", {})
	for k in fate.keys():
		if caps.has(k):
			fate[k] = clampf(fate[k], -float(caps[k]), float(caps[k]))
		if is_zero_approx(float(fate[k])):
			fate.erase(k)

func _finish() -> void:
	if leaving >= 0.0:
		return
	leaving = 0.0
	Sfx.play("kindle", 0.9)

func result() -> Dictionary:
	var ps: Array = []
	for p in picks:
		ps.append({"step": p["step"], "id": p["id"], "name": p["name"], "rev": p["rev"]})
	var lines: Array = []
	for k in FX_ORDER:
		if fate.has(k):
			lines.append(_fx_line(k, fate[k]))
	ps.append({"step": "sum", "lines": lines, "prophecy": prophecy})
	return {"fx": fate.duplicate(), "picks": ps, "prophecy": prophecy}

# ------------------------------------------------------------------ time and input

func _process(dt: float) -> void:
	t += dt
	sframe = pace.step(dt)   # the Stranger mostly sits still; he gestures at random (ui/stranger_pace.gd)
	fade = minf(1.0, fade + dt / 1.2)
	if picked >= 0 and flip < 1.0:
		flip = minf(1.0, flip + dt / 0.45)
	if leaving >= 0.0:
		leaving += dt
		if leaving >= 1.4:
			if on_done.is_valid():
				on_done.call(result())
			queue_free()
			return
	if auto != "" and leaving < 0.0 and fmod(t, 0.5) < dt:
		if auto == "end":
			if STEPS[step_i] != "end":
				_skip()
		elif auto == "all":
			if STEPS[step_i] == "end":
				if picked < -1:
					_finish()
				picked -= 1
			elif picked < 0:
				_pick(0)
			elif t > 1.0:
				_next()
	root.queue_redraw()

func _slot(i: int) -> Rect2:
	var n := offer.size()
	var gap := 220.0
	var x0 := 960.0 - (n - 1) * gap / 2.0 - CW / 2.0
	return Rect2(x0 + i * gap, 470.0, CW, CH)

func _gui(ev: InputEvent) -> void:
	if leaving >= 0.0:
		return
	if ev is InputEventMouseMotion:
		var h := -1
		if picked < 0:
			for i in offer.size():
				if _slot(i).grow(10).has_point(ev.position):
					h = i
		if STEPS[step_i] == "end" and _rise_rect().has_point(ev.position):
			h = 99
		if h != hover:
			hover = h
			if h >= 0:
				Sfx.play("page_close", 0.25, 1.4)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if STEPS[step_i] == "end":
			if _rise_rect().has_point(ev.position):
				_finish()
		elif picked < 0:
			for i in offer.size():
				if _slot(i).grow(10).has_point(ev.position):
					_pick(i)
		else:
			_next()

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or leaving >= 0.0:
		return
	var s: String = STEPS[step_i]
	match ev.keycode:
		KEY_ESCAPE:
			if s == "end":
				_finish()
			else:
				_skip()
		KEY_LEFT:
			if picked < 0 and not offer.is_empty():
				hover = (maxi(hover, 0) - 1 + offer.size()) % offer.size()
		KEY_RIGHT:
			if picked < 0 and not offer.is_empty():
				hover = (hover + 1) % offer.size()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if s == "end":
				_finish()
			elif picked < 0:
				_pick(hover)
			else:
				_next()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if picked < 0:
				_pick(ev.keycode - KEY_1)
		_:
			return
	get_viewport().set_input_as_handled()

var rise_r := Rect2(860, 860, 200, 56)
func _rise_rect() -> Rect2:
	return rise_r

# ------------------------------------------------------------------ drawing

func _wrap(s: String, f: Font, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var tt := word if line == "" else line + " " + word
			if f.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = tt
		out.append(line)
	return out

func _draw_all() -> void:
	var a := fade if leaving < 0.0 else fade * (1.0 - clampf(leaving / 1.4, 0.0, 1.0))
	var ci := root
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.01, 0.015))
	# the Stranger at his fire
	if sheet:
		var f := sframe
		var src := Rect2((f % 11) * FW, (f / 11) * FH, FW, FH)
		ci.draw_texture_rect_region(sheet, Rect2(320, 0, FW * SK, FH * SK), src, Color(a, a, a))
		# the painting's edges go down into the dark
		for k in 24:
			var w := 6.0
			var e := Color(0.01, 0.01, 0.015, 1.0 - k / 24.0)
			ci.draw_rect(Rect2(320 + k * w, 0, w, 1080), e)
			ci.draw_rect(Rect2(1600 - (k + 1) * w, 0, w, 1080), e)
	# the cloth: the lower frame darkened so the cards and words read
	for k in 40:
		ci.draw_rect(Rect2(0, 420 + k * 10, 1920, 10), Color(0.01, 0.01, 0.015, clampf(k / 40.0 * 0.85, 0.0, 0.85) * a))
	ci.draw_rect(Rect2(0, 820, 1920, 260), Color(0.01, 0.01, 0.015, 0.85 * a))
	var sc := U.font("sc")
	var fi := U.font("italic")
	var fb := U.font("book")
	var s: String = STEPS[step_i]
	# where we are in the Reading
	ci.draw_string(sc, Vector2(60, 70), "THE READING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(MARROW_D, a))
	ci.draw_string(sc, Vector2(60, 112), String(STEP_NAME[s]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(BONE, a))
	for i in STEPS.size() - 1:
		var on := i <= step_i
		ci.draw_rect(Rect2(62 + i * 22, 132, 14, 3), Color(MARROW if on else Color("#2e2a31"), a))
	_draw_spread(ci, a)
	if s == "end":
		_draw_end(ci, a)
		return
	# the cards
	for i in offer.size():
		_draw_offer(ci, i, a)
	# the words: the question until one is chosen, then his answer
	var words := prompt if picked < 0 else said
	if words != "":
		var lines := _wrap(words, fi, 30, 1100.0)
		var y := 890.0
		for ln in lines:
			ci.draw_string(fi, Vector2(410, y), ln, HORIZONTAL_ALIGNMENT_LEFT, 1100, 30, Color(BONE if picked >= 0 else BONE_D, a))
			y += 40.0
	var hint := "choose a card    ·    Esc lets him choose the rest" if picked < 0 else "click to go on"
	if s == "star":
		hint = "click to go on"
	ci.draw_string(fi, Vector2(0, 1050), hint, HORIZONTAL_ALIGNMENT_CENTER, 1920, 18, Color(ASH, a * (0.6 + 0.2 * sin(t * 2.0))))

func _draw_offer(ci: CanvasItem, i: int, a: float) -> void:
	var o: Dictionary = offer[i]
	var r := _slot(i)
	var s: String = STEPS[step_i]
	var chosen := picked == i
	var faded := picked >= 0 and not chosen
	var ca := a * (0.25 if faded else 1.0)
	if s == "star":
		r = Rect2(960 - CW / 2.0, 470, CW, CH)
	if hover == i and picked < 0:
		r.position.y -= 14.0
	if chosen and s != "star":
		r.position.y -= 24.0
	# the card itself (the blind draw shows its back until taken, then turns over)
	var face: Texture2D = _card(String(o.get("emb", "")))
	var tex := face
	var sx := 1.0
	if s == "card":
		if not chosen:
			tex = _card("_back")
		else:
			sx = absf(cos(flip * PI))
			tex = _card("_back") if flip < 0.5 else face
	ci.draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.5 * ca))
	var w := r.size.x * sx
	var dr := Rect2(r.position.x + (r.size.x - w) / 2.0, r.position.y, w, r.size.y)
	if s == "card" and chosen and reversed and flip >= 0.5:
		# reversed: head down
		ci.draw_set_transform(dr.get_center(), PI, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-dr.size / 2.0, dr.size), false, Color(1, 1, 1, ca))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(tex, dr, false, Color(1, 1, 1, ca))
	if (hover == i and picked < 0) or chosen:
		ci.draw_rect(dr.grow(3), Color(MARROW, 0.7 * ca), false, 2.0)
	# its name and what it does (the blind cards keep theirs until turned)
	var sc := U.font("sc")
	var fb := U.font("book")
	var hidden := s == "card" and not (chosen and flip >= 0.5)
	if hidden:
		return
	var nm := String(o.get("name", ""))
	if s == "star":
		nm = "%s, %s" % [o.get("name", ""), o.get("sub", "")]
	if s == "card" and reversed:
		nm += ", reversed"
	var ny := r.end.y + 34.0
	var nw := 420.0 if s in ["star", "card"] else 214.0
	for ln in _wrap(nm, sc, 22, nw):
		ci.draw_string(sc, Vector2(r.get_center().x - nw / 2.0, ny), ln, HORIZONTAL_ALIGNMENT_CENTER, nw, 22, Color(BONE, ca))
		ny += 26.0
	var txt := String(o.get("txt", ""))
	if s == "card" and reversed:
		txt = String(o["rev"].get("txt", txt))
	ny += 4.0
	for part in txt.split(" · "):
		var good := not part.begins_with("-")
		ci.draw_string(fb, Vector2(r.get_center().x - nw / 2.0, ny), part, HORIZONTAL_ALIGNMENT_CENTER, nw, 20, Color(Color("#9fb08a") if good else Color("#b58a7a"), ca * 0.9))
		ny += 22.0

## the right-hand column: what has been laid down so far, small
func _draw_spread(ci: CanvasItem, a: float) -> void:
	var sc := U.font("sc")
	var fi := U.font("italic")
	var y := 190.0
	for p in picks:
		var tex := _card(String(p["emb"]))
		var r := Rect2(1640, y, 36, 56)
		if p["rev"]:
			ci.draw_set_transform(r.get_center(), PI, Vector2.ONE)
			ci.draw_texture_rect(tex, Rect2(-r.size / 2.0, r.size), false, Color(1, 1, 1, a * 0.9))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(tex, r, false, Color(1, 1, 1, a * 0.9))
		ci.draw_string(sc, Vector2(1690, y + 20), String(STEP_NAME[p["step"]]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color(ASH, a))
		ci.draw_string(fi, Vector2(1690, y + 44), String(p["name"]) + (", reversed" if p["rev"] else ""), HORIZONTAL_ALIGNMENT_LEFT, 220, 20, Color(BONE_D, a))
		y += 68.0

func _fx_line(k: String, v: float) -> String:
	var sgn := "+" if v > 0 else "-"
	var n := str(int(absf(v)))
	match k:
		"skt0", "skt1", "skt2":
			var f: Dictionary = {}
			for o in R.get("faces", {}).get(cls, []):
				if o.get("fx", {}).has(k):
					f = o
			var tn := String(f.get("txt", "")).get_slice(" · ", 0).trim_prefix("+1 to ").trim_suffix(" skills")
			return "%s%s to %s skills" % [sgn, n, tn if tn != "" else "one way's"]
		"mana": return "%s%s to your %s" % [sgn, n, _res_word()]
		"regen": return "%s%s%% %s regained" % [sgn, n, _res_word()]
	if LAB.has(k):
		return sgn + n + String(LAB[k])
	return "%s%s %s" % [sgn, n, k]

func _res_word() -> String:
	return {"animancer": "Essence", "ossumancer": "Marrow", "hemomancer": "Vitae", "miasmancer": "Miasma", "monk": "Sand"}.get(cls, "Essence")

func _draw_end(ci: CanvasItem, a: float) -> void:
	var sc := U.font("sc")
	var fi := U.font("italic")
	var fb := U.font("book")
	# the prophecy, over the cloth
	var y := 520.0
	for ln in _wrap("“%s”" % prophecy, fi, 40, 1000.0):
		ci.draw_string(fi, Vector2(460, y), ln, HORIZONTAL_ALIGNMENT_CENTER, 1000, 40, Color(BONE, a))
		y += 50.0
	# what the Reading made of you
	y += 20.0
	# what it gave on the left, what it took on the right
	var gave: Array = []
	var took: Array = []
	for k in FX_ORDER:
		if fate.has(k):
			(gave if float(fate[k]) > 0.0 else took).append(k)
	var col_w := 380.0
	ci.draw_string(sc, Vector2(960.0 - col_w - 20.0, y), "IT GAVE", HORIZONTAL_ALIGNMENT_CENTER, col_w, 14, Color(ASH, a))
	ci.draw_string(sc, Vector2(980.0, y), "IT TOOK", HORIZONTAL_ALIGNMENT_CENTER, col_w, 14, Color(ASH, a))
	y += 28.0
	for i in gave.size():
		ci.draw_string(fb, Vector2(960.0 - col_w - 20.0, y + i * 26.0), _fx_line(gave[i], fate[gave[i]]), HORIZONTAL_ALIGNMENT_CENTER, col_w, 20, Color(Color("#9fb08a"), a))
	for i in took.size():
		ci.draw_string(fb, Vector2(980.0, y + i * 26.0), _fx_line(took[i], fate[took[i]]), HORIZONTAL_ALIGNMENT_CENTER, col_w, 20, Color(Color("#b58a7a"), a))
	var per := maxi(gave.size(), took.size())
	per = int(per * 26.0 / 28.0) + 1
	# Rise
	var rr := Rect2(860, maxf(860.0, y + per * 28.0 + 10.0), 200, 56)
	rise_r = rr
	var on := hover == 99
	ci.draw_rect(rr, Color(0.05, 0.04, 0.05, 0.9 * a))
	ci.draw_rect(rr, Color(MARROW if on else MARROW_D, a), false, 1.5)
	ci.draw_string(sc, rr.position + Vector2(0, 38), "Rise", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 30, Color(BONE if on else BONE_D, a))
	ci.draw_string(fi, Vector2(410, maxf(1010.0, rr.end.y + 40.0)), prompt, HORIZONTAL_ALIGNMENT_CENTER, 1100, 24, Color(BONE_D, a))
