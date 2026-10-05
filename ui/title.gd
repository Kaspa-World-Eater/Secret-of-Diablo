extends CanvasLayer
## ui/title.gd: the title. The scene behind the words is a stage (ui/title_stage/*.gd), chosen in Options
## (Settings.title_scene): the Stranger's box (his fire, the orders' cards on the lid of his box), the Seer's bowl
## (the dead god's face weeping blood into a bronze bowl, the cards spilled round it), or the pilgrims' fire.
## Each stage lays out the five orders as something to hover and choose; choose one and that order's page opens over
## the dimmed scene (a large portrait, placeholders until the final paintings come; who they are in the Stranger's
## words; their own pilgrim to continue or begin anew).
## The words stand on the left: Continue (the pilgrim walked most lately) · The Codex · Options · Those Who Lent Their
## Hands · Leave. "Begin" opens the Reading (ui/reading.gd, character creation), the god already chosen here.

const U := preload("res://ui/uikit.gd")
const SaveIO := preload("res://core/save.gd")
const BONE := Color("#dcd3c2")
const BONE_D := Color("#a39a8b")
const ASH := Color("#6f685f")
const MARROW := Color("#c9974a")
const K := 4.0                           # screen px per chapel px
## the pilgrims: the user's paintings cut out and brought down to the chapel's own grain (tools/title_cut.py,
## tools/title_pix.py -> art/ui/pilgrim_*.png, shown x4). The two orders without a painting yet keep an empty place.
const PILGRIMS := [
	# kind, figure png ("" = an empty place), name, line, foot (screen px), fire side, playable, what lies at an empty place
	["hemomancer", "pilgrim_hemo", "The Red Penitent", "Opens the vein, and the vein answers.", Vector2(928, 864), 1, false, ""],
	["animancer", "pilgrim_mystic", "The Hollow Mystic", "Listens at mirrors. Keeps the dead on a thread.", Vector2(1152, 840), 1, true, ""],
	["ossumancer", "pilgrim_ossu", "The Ossuarch", "Counts the dead, and the dead stand up to be counted.", Vector2(1580, 840), -1, true, ""],
	["miasmancer", "", "The Shrine Keeper", "Folds the breath into paper, and the paper walks.", Vector2(1760, 880), -1, true, "charm"],
	["monk", "", "The Empty Hand", "Carries nothing. Strikes with that.", Vector2(1150, 1010), 1, true, "bowl"],
]
## each order's page. Portraits are placeholders: the user's paintings, cut out (art/ui/portrait_*.png); "" = still to paint.
const ORDER := {
	"animancer": {"god": "Of the Soul, the Veiled Crone", "portrait": "portrait_mystic", "draws": "Essence, and a choir of wisps", "ways": "Mirror · Soul · Thread",
		"text": "They listen at mirrors until something listens back. A Mystic keeps a few of the restless dead about her, wisps that dive at whatever comes near and grow back when spent, and ties the rest down with thread and needle. I walked a season beside one. She never once looked where she was going. The mirrors did that for her."},
	"hemomancer": {"god": "Of the Flesh, the Bleeding Maiden", "portrait": "portrait_hemo", "draws": "Vitae; every working costs him life", "ways": "Mortification · Blood · Penance",
		"text": "The Brotherhood of the Precious Wound pays for everything in blood, and their own first. What a Hemomancer opens, he keeps: a brood that crawls out of the cut, a golem of it, pools that drink what falls in them. They are gentle with strangers. I would still not sleep near one."},
	"ossumancer": {"god": "Of the Bone, Old Upright", "portrait": "portrait_ossu", "draws": "Marrow", "ways": "Ossuary · Carapace · Count",
		"text": "The Pale Order counts the dead, and what they count stands up. An Ossuarch sends the bones of the fallen to walk ahead of him, wears the rest as plate, throws the splinters, and cuts a count into whatever he strikes. He does not bend. I once saw one carried home on a door, sitting upright, still counting."},
	"miasmancer": {"god": "Of the Breath, the Myriad", "portrait": "", "draws": "Miasma, breathed in and given back", "ways": "Miasma · Distortion · Death",
		"text": "The House of Eight Million keeps the small gods that ride the last breath out. A Keeper breathes in the spoiled air and gives it back as a violet haze, folds paper that walks, and reads Omens in what the breath leaves behind. She fights with a fan. Do not laugh at the fan."},
	"monk": {"god": "Of the Hush", "portrait": "", "draws": "An hourglass: amber sand by day, black sand by night", "ways": "Radiance · Absence · Destroyer",
		"text": "The Gilded Peak gave everything away, and the Empty Hand is what came down the stair after. He carries a lantern with a black flame and nothing else, and strikes with the sun or with its going. He did not ask my name. I think he would not have kept it."},
}

var main: Node
var root: Control
var stage: Node2D
var stage_kind := ""
var rows: Array = []
var hover := -1
var fig_hover := -1
var mode := "main"                 # main | order | credits
var order_i := -1                  # the order whose page is open
var portraits := {}
var confirm_new := false
var t := 0.0
var leaving := -1.0
var codex: Control
var _test_done := false
var bronze: Node                   # ui/bronze.gd: the title and the choices cast in bronze
var kindle := {}                   # each choice: 0 tarnished .. 1 rubbed bright
var drops: Array = []              # the god's drop falling into the chosen word
var drop_for := ""
var draw_t := -1.0                 # the Stranger drawing a card before the Reading (mode "draw")

const CREDITS := [
	["Sounds", ""],
	["Impact Sounds and RPG Audio", "Kenney (kenney.nl), CC0"],
	["Fire Crackling", "AntumDeluge, CC0 (OpenGameArt)"],
	["Rain (loopable)", "Ylmir, CC0 (OpenGameArt)"],
	["Loopable Dungeon Ambience", "JaggedStone, CC0 (OpenGameArt)"],
	["Wind", "Jonathan Shaw (InspectorJ), freesound.org, CC-BY 3.0; looped by AntumDeluge"],
	["Letters", ""],
	["IM Fell English", "Igino Marini, SIL Open Font License"],
	["Silkscreen", "Jason Kottke, SIL Open Font License"],
	["Engine", ""],
	["Godot Engine", "Juan Linietsky, Ariel Manzur and contributors, MIT"],
]

func _init(m: Node) -> void:
	main = m

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.slot = ""   # the title shows the pilgrims; the Trial is entered from an order's page
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--title_scene="):
			Settings.title_scene = arg.substr(14)
	_set_stage(Settings.title_scene)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(_draw_ui)
	root.gui_input.connect(_gui)
	add_child(root)
	bronze = load("res://ui/bronze.gd").new()
	add_child(bronze)
	codex = load("res://ui/codex.gd").new()
	codex.visible = false
	codex.on_close = func(): root.visible = true
	add_child(codex)
	_build()

func _build() -> void:
	rows.clear()
	match mode:
		"main":
			var last := SaveIO.latest()
			if last != "":
				rows.append(["Continue: " + _order_name(last), "continue"])
			rows.append(["The Codex", "codex"])
			rows.append(["Options", "options"])
			rows.append(["Those Who Lent Their Hands", "credits"])
			rows.append(["Leave", "leave"])
		"order":
			var p: Array = PILGRIMS[order_i]
			if p[6]:
				if SaveIO.exists(p[0]):
					rows.append(["Continue this pilgrim", "order_continue"])
					rows.append(["Forget them, and begin anew?" if confirm_new else "Begin anew", "order_new"])
				else:
					rows.append(["Begin", "order_new"])
				rows.append(["The Trial of Thirty (a test pilgrim, level 30)", "order_trial"])
			rows.append(["Back", "back"])
		_:
			rows.append(["Back", "back"])

func _order_name(kind: String) -> String:
	for p in PILGRIMS:
		if p[0] == kind:
			return p[2]
	return kind

func _row_rect(i: int) -> Rect2:
	if mode == "main":
		# centred, as the web casts them (zz_title54.js:33-41: CX 240, Y0 184, DY 12 on the 480 grid)
		var y := (184.0 - maxf(0.0, rows.size() - 4) * 6.0 + i * 12.0) * K
		var w := _label_w(rows[i][0])
		return Rect2(_menu_cx() - w / 2.0, y - 8.0 * K, w, 11.0 * K)
	var y0 := 820.0 if mode == "order" else 900.0
	return Rect2(150, y0 + i * 58.0, 640, 50)

## the menu's middle: on the blood in the bowl (the web's chapel); on the other stages, in the dark to the left of the scene
func _menu_cx() -> float:
	return 960.0 if stage_kind == "bowl" else 520.0

## a choice's width on screen (the web: the word in 8 px IM Fell SC x1.12, plus 18)
func _label_w(s: String) -> float:
	return ceilf(U.font("sc").get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x * 1.12) + 18.0 * K

# ------------------------------------------------------------------ living

func _flick(s: float) -> float:
	return 0.5 + 0.5 * sin(t * 9.0 + s) * sin(t * 5.3 + s * 2.0)

func _process(dt: float) -> void:
	t += dt
	if OS.has_environment("GM_TITLE_ACT") and t > 1.0 and not _test_done:
		_test_done = true
		for a in OS.get_environment("GM_TITLE_ACT").split(","):
			_act(a)
	if leaving >= 0.0:
		leaving += dt
		if leaving >= 1.2:
			main.title_done()
			queue_free()
			return
	if draw_t >= 0.0:
		draw_t += dt
	_tick_main(dt)
	if stage_kind != Settings.title_scene and mode != "draw":
		_set_stage(Settings.title_scene)
	root.queue_redraw()

## raise the chosen stage behind the words (and put away the old one)
func _set_stage(kind: String) -> void:
	var path := "res://ui/title_stage/%s.gd" % kind
	if not ResourceLoader.exists(path):
		kind = "stranger"
		path = "res://ui/title_stage/stranger.gd"
	if stage:
		stage.queue_free()
	stage = load(path).new()
	stage.T = self
	stage_kind = kind
	add_child(stage)
	move_child(stage, 0)

## the order under a screen point, as the stage lays them out
func _fig_at(p: Vector2) -> int:
	return stage.order_at(p) if stage else -1

func _gui(ev: InputEvent) -> void:
	if leaving >= 0.0 or mode == "draw":
		return
	if ev is InputEventMouseMotion:
		var h := -1
		for i in rows.size():
			if _row_rect(i).has_point(ev.position):
				h = i
		if h != hover and h >= 0:
			Sfx.play("page_close", 0.25, 1.4)
		hover = h
		var fh := _fig_at(ev.position) if mode == "main" and h < 0 else -1
		if fh >= 0 and fh != fig_hover:
			Sfx.play("roll", 0.35, 1.2)
		fig_hover = fh
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if mode == "credits":
			_act("back")
			return
		for i in rows.size():
			if _row_rect(i).has_point(ev.position):
				_act(rows[i][1])
				return
		if mode == "main":
			var f := _fig_at(ev.position)
			if f >= 0:
				_open_order(f)

func _unhandled_key_input(ev: InputEvent) -> void:
	if leaving >= 0.0 or mode == "draw" or not root.visible or not (ev is InputEventKey) or not ev.pressed:
		return
	if ev.keycode == KEY_ESCAPE and mode != "main":
		_act("back")
	elif ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE:
		if mode == "main" and fig_hover >= 0 and hover < 0:
			_open_order(fig_hover)
		else:
			_act(rows[maxi(0, hover)][1])
	elif ev.keycode == KEY_DOWN:
		hover = (hover + 1) % rows.size()
	elif ev.keycode == KEY_UP:
		hover = (hover - 1 + rows.size()) % rows.size()
	elif mode == "main" and (ev.keycode == KEY_LEFT or ev.keycode == KEY_RIGHT):
		fig_hover = (maxi(fig_hover, 0) + (1 if ev.keycode == KEY_RIGHT else -1) + PILGRIMS.size()) % PILGRIMS.size()
	get_viewport().set_input_as_handled()

func _act(a: String) -> void:
	match a:
		"continue":
			_wake(SaveIO.latest())
		"order_continue":
			_wake(PILGRIMS[order_i][0])
		"order_new":
			var kind: String = PILGRIMS[order_i][0]
			if SaveIO.exists(kind) and not confirm_new:
				confirm_new = true
				_build()
				return
			Sfx.play("kindle", 0.9)
			SaveIO.forget(kind)
			Game.skip_title = true
			Game.force_new = true
			Game.read_new = true
			Game.cls = kind
			if stage and stage.has_method("draw_card"):
				# the Stranger draws that order's card from his deck first, and the dark follows it
				mode = "draw"
				rows.clear()
				hover = -1
				draw_t = 0.0
				stage.draw_card(order_i)
				get_tree().create_timer(stage.DRAW_LEN + 0.6).timeout.connect(func(): get_tree().reload_current_scene())
				return
			get_tree().reload_current_scene()
		"order_trial":
			# a test pilgrim at level 30, in its own slot: the real pilgrim of the order is never touched
			var tk: String = PILGRIMS[order_i][0]
			Sfx.play("kindle", 0.9)
			Game.slot = "_trial"
			Game.skip_title = true
			Game.cls = tk
			if SaveIO.exists(tk):
				Game.load_cls = tk
			else:
				Game.force_new = true
				Game.trial_new = true
			get_tree().reload_current_scene()
		"back":
			if mode == "order":
				Sfx.play("page_close", 0.6)
			mode = "main"
			confirm_new = false
			order_i = -1
			_build()
		"codex":
			Sfx.play("page_open")
			root.visible = false
			codex.open_book(0)
		"options":
			if main.hud and main.hud.pause:
				main.hud.pause.open()
				main.hud.pause.page = "options"
		"credits":
			Sfx.play("page_open", 0.7)
			mode = "credits"
			_build()
		"leave":
			get_tree().quit()
		_:
			if a.begins_with("hover"):
				fig_hover = int(a.substr(5))
			elif a.begins_with("order"):
				_open_order(int(a.substr(5)))

func _open_order(i: int) -> void:
	Sfx.play("page_open", 0.8)
	mode = "order"
	order_i = i
	confirm_new = false
	fig_hover = -1
	_build()
	hover = 0

## wake a saved pilgrim: the one already loaded behind the title simply walks on; another order's reloads the scene
func _wake(kind: String) -> void:
	if kind == "":
		return
	Sfx.play("kindle", 0.8)
	if kind == main.hero.cls:
		leaving = 0.0
		return
	Game.load_cls = kind
	Game.skip_title = true
	get_tree().reload_current_scene()

func _portrait(name: String) -> Texture2D:
	if name == "":
		return null
	if not portraits.has(name):
		portraits[name] = load("res://art/ui/%s.png" % name)
	return portraits[name]

# ------------------------------------------------------------------ the words

## an order's page: over the dimmed chapel, a portrait on the right and the Stranger's words on the left
func _draw_order(a: float) -> void:
	var vs := root.get_viewport_rect().size
	var p: Array = PILGRIMS[order_i]
	var info: Dictionary = ORDER.get(p[0], {})
	var sc := U.font("sc")
	var fi := U.font("italic")
	var fb := U.font("book")
	# the portrait, and the dark it stands in
	var pr := Rect2(1060, 110, 760, 900)
	var tex := _portrait(String(info.get("portrait", "")))
	var g := 0.9 + 0.1 * _flick(0.3)
	if tex:
		var sz: Vector2 = tex.get_size()
		var k := minf(pr.size.y / sz.y, pr.size.x / sz.x)
		var r := Rect2(pr.position + Vector2((pr.size.x - sz.x * k) / 2.0, pr.size.y - sz.y * k), sz * k)
		root.draw_texture_rect(tex, r, false, Color(1.0 * g, 0.9 * g, 0.8 * g, a))
	else:
		# no painting yet: the pilgrim as he walks the Hide, drawn large, in the candles' light
		root.draw_rect(pr.grow(-40), Color(0.05, 0.04, 0.05, 0.97 * a))
		root.draw_rect(pr.grow(-40), Color(MARROW, 0.35 * a), false, 1.0)
		var fr: Array = Data.sprite_set(p[0]).get_frames("idle", "front")
		if not fr.is_empty():
			var at: AtlasTexture = fr[int(t * 4.0) % fr.size()][0]
			var sz2: Vector2 = at.get_size()
			var k2 := minf(minf((pr.size.y - 180.0) / sz2.y, (pr.size.x - 160.0) / sz2.x), 5.0)
			root.draw_texture_rect(at, Rect2(pr.get_center() + Vector2(-sz2.x * k2 / 2.0, -sz2.y * k2 / 2.0 - 10.0), sz2 * k2), false, Color(0.95 * g, 0.85 * g, 0.75 * g, a))
		root.draw_string(fi, Vector2(pr.position.x, pr.end.y - 60), "[a portrait is still being painted]", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 20, Color(ASH, a))
	# the words
	var x := 150.0
	root.draw_string(sc, Vector2(x, 450), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color(BONE, a))
	root.draw_string(fi, Vector2(x + 2, 490), String(info.get("god", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(MARROW, a))
	root.draw_multiline_string(fb, Vector2(x, 540), String(info.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, 780, 22, -1, Color(BONE_D, a))
	root.draw_string(sc, Vector2(x, 730), "DRAWS ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ASH, a))
	root.draw_string(fb, Vector2(x + 130, 730), String(info.get("draws", "")), HORIZONTAL_ALIGNMENT_LEFT, 650, 20, Color(BONE, a))
	root.draw_string(sc, Vector2(x, 764), "THREE WAYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ASH, a))
	root.draw_string(fb, Vector2(x + 130, 764), String(info.get("ways", "")), HORIZONTAL_ALIGNMENT_LEFT, 650, 20, Color(BONE, a))
	if not p[6]:
		root.draw_string(fi, Vector2(x, 800), "This road is not yet open.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ASH, a))
	elif SaveIO.exists(p[0]):
		var d := SaveIO.read(p[0])
		root.draw_string(fi, Vector2(x, 800), "Your pilgrim of this order: level %d, carrying %d gold." % [int(d.get("level", 1)), int(d.get("gold", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(MARROW, a))

func _draw_ui() -> void:
	var vs := root.get_viewport_rect().size
	var fade_in := clampf(t / 2.5, 0.0, 1.0)
	var out := clampf(leaving / 1.2, 0.0, 1.0) if leaving >= 0.0 else 0.0
	var a := 1.0 - out
	if mode == "main":
		_draw_main(a)
		_draw_veils(vs, fade_in, out)
		return
	for i in 30:
		var k := float(i) / 30.0
		root.draw_rect(Rect2(k * vs.x * 0.6, 0, vs.x * 0.6 / 30.0 + 1.0, vs.y), Color(0, 0, 0, 0.78 * pow(1.0 - k, 1.4)))
	if mode == "order":
		root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72 * a))
	root.draw_rect(Rect2(0, 0, vs.x, 70), Color(0, 0, 0, 0.5))
	root.draw_rect(Rect2(0, vs.y - 50, vs.x, 50), Color(0, 0, 0, 0.5))
	var sc := U.font("sc")
	var fi := U.font("italic")
	var fb := U.font("book")
	var x := 150.0
	var y := 300.0
	for c in "GODMARROW":
		var cw := sc.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, 112).x
		root.draw_string(sc, Vector2(x + 4, y + 5), c, HORIZONTAL_ALIGNMENT_LEFT, -1, 112, Color(0, 0, 0, 0.8 * a))
		root.draw_string(sc, Vector2(x, y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, 112, Color(Color("#e0b86e"), a))
		root.draw_string(sc, Vector2(x, y - 3), c, HORIZONTAL_ALIGNMENT_LEFT, -1, 112, Color(Color("#f3dca0"), 0.35 * a))
		x += cw + 14.0
	root.draw_line(Vector2(152, y + 30), Vector2(152 + 90, y + 30), Color(MARROW, 0.8 * a), 2.0)
	root.draw_string(fi, Vector2(152, y + 74), "The god is dead, and has not finished dying.", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(BONE_D, a))
	if mode == "credits":
		var cy := 470.0
		for e in CREDITS:
			if e[1] == "":
				cy += 14.0
				root.draw_string(sc, Vector2(150, cy + 26), String(e[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(MARROW, a))
				cy += 34.0
			else:
				root.draw_string(fb, Vector2(150, cy + 22), e[0], HORIZONTAL_ALIGNMENT_LEFT, 330, 21, Color(BONE, a))
				root.draw_string(fi, Vector2(490, cy + 22), e[1], HORIZONTAL_ALIGNMENT_LEFT, 560, 19, Color(BONE_D, a))
				cy += 30.0
		root.draw_string(fi, Vector2(150, cy + 40), "Click to go back.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ASH, a))
	else:
		if mode == "main":
			root.draw_string(fi, Vector2(152, 486), stage.hint() if stage else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(ASH, a))
			if fig_hover >= 0:
				var p: Array = PILGRIMS[fig_hover]
				var ca: Vector2 = stage.label_at(fig_hover) if stage else Vector2(1360, 500)
				var ly := ca.y
				ca.x = clampf(ca.x, 250.0, 1920.0 - 250.0)
				root.draw_rect(Rect2(ca.x - 230, ly - 34, 460, 76), Color(0, 0, 0, 0.55 * a))
				root.draw_string(sc, Vector2(ca.x - 230, ly), p[2], HORIZONTAL_ALIGNMENT_CENTER, 460, 26, Color(BONE, 0.95 * a))
				root.draw_string(fi, Vector2(ca.x - 230, ly + 30), p[3], HORIZONTAL_ALIGNMENT_CENTER, 460, 18, Color(BONE_D, 0.9 * a))
		elif mode == "order":
			_draw_order(a)
		for i in rows.size():
			var r := _row_rect(i)
			var on := i == hover
			var col := BONE if on else BONE_D
			if rows[i][1] == "new" and confirm_new:
				col = MARROW
			if on:
				root.draw_string(sc, r.position + Vector2(-34, 36), "❧", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(MARROW, a))
			root.draw_string(sc, r.position + Vector2(0, 36), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(col, a))
	root.draw_string(fi, Vector2(152, vs.y - 18), "Act I · the Ashen Moor and what lies under it", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ASH, a))
	_draw_veils(vs, fade_in, out)

func _draw_veils(vs: Vector2, fade_in: float, out: float) -> void:
	if draw_t >= 0.0:
		root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, clampf((draw_t - 1.6) / 0.8, 0.0, 1.0)))
	if fade_in < 1.0:
		root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 1.0 - fade_in))
	if out > 0.0:
		root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, out))

# ------------------------------------------------------------------ the web's title (zz_title54.js)

func _tick_main(dt: float) -> void:
	if mode != "main":
		return
	var sel := maxi(hover, 0)
	for i in rows.size():
		var id: String = rows[i][1]
		kindle[id] = clampf(float(kindle.get(id, 0.0)) + (0.08 if i == sel else -0.05) * dt * 60.0, 0.0, 1.0)
	# the god's drop answers the choice: it falls into the chosen word
	if sel < rows.size() and rows[sel][1] != drop_for:
		drop_for = rows[sel][1]
		var r := _row_rect(sel)
		drops.append({"x": r.get_center().x, "y": 128.0 * K, "ty": r.position.y + 5.0 * K, "v": 30.0 * K})
	for d in drops:
		d["v"] += 380.0 * K * dt
		d["y"] += d["v"] * dt
	drops = drops.filter(func(d): return d["y"] < d["ty"])

## GODMARROW cut across the top in stepped bronze, the rule with its eye, the lede, and the choices cast in bronze in
## the middle, floating on the blood; side veils stepped, not smooth
func _draw_main(a: float) -> void:
	var vs := root.get_viewport_rect().size
	for i in 12:
		var al := (0.07 + i * 0.045) * a
		root.draw_rect(Rect2(vs.x - (12 - i) * 10.0 * K, 0, 10.0 * K, vs.y), Color(3 / 255.0, 2 / 255.0, 4 / 255.0, al))
		root.draw_rect(Rect2((12 - i - 1) * 10.0 * K, 0, 10.0 * K, vs.y), Color(3 / 255.0, 2 / 255.0, 4 / 255.0, al))
	# a dark band behind the title
	for y in 50:
		root.draw_rect(Rect2(0, y * K, vs.x, K), Color(4 / 255.0, 3 / 255.0, 6 / 255.0, 0.55 * (1.0 - y / 50.0) * a))
	var sc := U.font("sc")
	var tt: Texture2D = bronze.cast("title", "GODMARROW", sc, int(22 * K), int(2 * K), "title", int(300 * K), int(34 * K), int(25 * K))
	if tt:
		root.draw_texture(tt, Vector2(960.0 - 150.0 * K, 1.0 * K), Color(1, 1, 1, a))
	# the rule under it, with an eye in the middle that opens and shuts
	var R := func(x: float, y: float, w: float, h: float, c: String) -> void:
		root.draw_rect(Rect2(x * K, y * K, w * K, h * K), Color(Color(c), a))
	R.call(150, 36, 76, 1, "#3d2512"); R.call(254, 36, 76, 1, "#3d2512")
	R.call(170, 36, 50, 1, "#704622"); R.call(260, 36, 50, 1, "#704622")
	R.call(150, 35, 1, 3, "#945e2e"); R.call(329, 35, 1, 3, "#945e2e")
	R.call(233, 36, 14, 1, "#945e2e")
	if fmod(t, 6.5) <= 6.25:
		R.call(235, 34, 10, 5, "#1b1008")
		R.call(234, 35, 1, 3, "#c08644"); R.call(245, 35, 1, 3, "#c08644"); R.call(236, 33, 8, 1, "#c08644"); R.call(236, 39, 8, 1, "#c08644")
		R.call(237, 35, 6, 3, "#e8d8b0"); R.call(239, 35, 2, 3, "#84181c")
		R.call(239 + roundf(sin(t * 0.7)), 36, 1, 1, "#050303")
	else:
		R.call(235, 36, 10, 1, "#c08644")
	var fi := U.font("italic")
	var lede := "The god is dead, and has not finished dying."
	root.draw_string(fi, Vector2(2, 49.5 * K), lede, HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(7 * K), Color(5 / 255.0, 3 / 255.0, 4 / 255.0, a))
	root.draw_string(fi, Vector2(0, 49 * K), lede, HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(7 * K), Color(Color("#8f7a5c"), a))
	# the choices, cast in old pitted bronze; the chosen one rubbed bright, a sigil turning on either side
	var sel := maxi(hover, 0)
	for i in rows.size():
		var r := _row_rect(i)
		var label: String = rows[i][0]
		var bright: bool = float(kindle.get(rows[i][1], 0.0)) > 0.5
		var lw := int(ceilf(sc.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * K)).x + label.length() * K) + 6 * K)
		var lt: Texture2D = bronze.cast(label + ("|1" if bright else "|0"), label, sc, int(10 * K), int(K), "label_bright" if bright else "label", lw, int(14 * K), int(10 * K))
		var cx := r.get_center().x
		var y := r.position.y + 8.0 * K
		if lt:
			root.draw_texture(lt, Vector2(roundf((cx - lw / 2.0) / K) * K, y - 10.0 * K), Color(1, 1, 1, a))
		if i == sel:
			for side in [-1, 1]:
				var sx := roundf(cx / K + side * (r.size.x / K / 2.0 + 2.0))
				var sy := y / K - 3.0
				var an: float = t * 1.6 * side
				for q in 6:
					var aa := an + q * 1.047
					R.call(roundf(sx + cos(aa) * 3.0), roundf(sy + sin(aa) * 3.0), 1, 1, "#553418" if q % 2 else "#945e2e")
				R.call(sx, sy, 1, 1, "#2a4735")
	for d in drops:
		var dx := roundf(float(d["x"]) / K)
		var dy := roundf(float(d["y"]) / K)
		R.call(dx, dy - 2, 1, 3, "#84181c")
		R.call(dx, dy, 1, 1, "#e8704e")
	# what the stage offers, under the choices
	if stage:
		root.draw_string(fi, Vector2(0, vs.y - 16), stage.hint(), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 21, Color(ASH, a))
	if fig_hover >= 0:
		var p: Array = PILGRIMS[fig_hover]
		var ca: Vector2 = stage.label_at(fig_hover) if stage else Vector2(1360, 500)
		ca.x = clampf(ca.x, 250.0, 1920.0 - 250.0)
		root.draw_rect(Rect2(ca.x - 230, ca.y - 34, 460, 76), Color(0, 0, 0, 0.55 * a))
		root.draw_string(sc, Vector2(ca.x - 230, ca.y), p[2], HORIZONTAL_ALIGNMENT_CENTER, 460, 26, Color(BONE, 0.95 * a))
		root.draw_string(fi, Vector2(ca.x - 230, ca.y + 30), p[3], HORIZONTAL_ALIGNMENT_CENTER, 460, 18, Color(BONE_D, 0.9 * a))
