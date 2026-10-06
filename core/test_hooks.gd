extends RefCounted
## core/test_hooks.gd: the test and capture hooks (user args after --), kept out of the game scene.
## core/main.gd calls TestHooks.run(main) once the first zone is entered. Nothing here runs in normal play.
##   --lvl=N [--arcana=N]     start at that level (with that many Major points)
##   --cards=u|r              hold every card of the order, upright or reversed
##   --arena=N                balance: N tireless, harmless creatures round the pilgrim; after --arena_t seconds
##                            (default 20) print the HERO line and what each skill dealt (BAL), then quit.
##     --arena_kind=K --arena_lvl=N --arena_rank=normal|champion   what stands in the ring
##     --arena_live           real, hostile creatures instead (a fight test; FELL lines name the killer)
##     --sigils               the Ossuarch's count sigils over them, counting up on their own
##   --boardtest              lay a road to the right hand of the body board and take three cards
##   --panel=ID               open a panel (skills, inv, char, board, journal, choir, golem) or a town window
##   --demo [--trace]         the pilgrim fights the nearest creatures, for captures
##   --fx=NAME[,NAME]         PixelForge effects (art/fx/<NAME>.json) playing at the pilgrim, for a look (the Forge's "Preview in game")
##   --attach                 spawn the effects the Forge's effects editor attached to the pilgrim's sprite set
##   --place=NAME[,NAME]      the Forge's objects (art/objects/objects.json) stood beside the pilgrim for a look, nothing saved
##   --shot=PATH [--shot_t=S] [--shot_n=N]   save the screen to PATH after S seconds (default 4), N frames 0.25 s apart
##                            (PATH_1.png ...), then quit. Needs a window (not --headless). --hour=0..1 sets the hour.
##   --at=X,Y                 stand the pilgrim on that tile (nearest open one)
##   --show=collision         draw what blocks a body: solid tiles (red diamonds) and posts (yellow rings)
##   --hide=dark,atmos,sky    switch those overlays off (the dark and light map, the air, the weather),
##                            to judge a sprite or an effect in its plain paint

const PANELS := ["choir", "golem", "char", "skills", "inv", "journal", "board"]
const SIGIL_KINDS := ["open", "fewer", "weigh", "stair"]

static func run(g) -> void:
	var a: Dictionary = g.args
	if a.has("at"):   # --at=X,Y: stand the pilgrim on that tile (nearest open one), for captures of the wilds
		var xy := String(a["at"]).split(",")
		var c: Vector2i = g.zone._nearest_open(Vector2i(int(xy[0]), int(xy[1])))
		g.hero.tp = Vector2(c) + Vector2(0.5, 0.5)
		g.hero.position = Iso.to_screen(g.hero.tp)
	if a.has("menutest"):
		await _menutest(g, a)
	if a.has("demo"):
		_demo(g)
	if a.has("panel"):
		await g.get_tree().create_timer(1.0).timeout
	if a.has("hide"):
		for n in String(a["hide"]).split(","):
			var layer = g.get(n.strip_edges())
			if layer is CanvasLayer:
				layer.visible = false
	if a.has("nolm") and g.dark != null:   # the dark without its light map (the web's older look), for lighting checks
		g.dark.mat.set_shader_parameter("lm_on", false)
	if a.has("darkflat") and g.dark != null:   # the dark as a plain veil, no shader: tells a shader fault from a draw-order one
		g.dark.rect.material = null
		g.dark.rect.color = Color(0, 0, 0, 0.35)
	if a.has("nolamp") and g.hero != null and g.hero.lamp != null:
		g.hero.lamp.enabled = false
	if a.has("fx") or a.has("attach"):
		_forge_preview(g, a)
	if a.has("place"):
		_forge_place(g, a)
	if a.has("lvl"):
		g.hero.st.level = int(a["lvl"])
		g.hero.st.arcana_points = int(a.get("arcana", "3"))
	if a.has("cards") and g.hero.st.arc:
		var arc = g.hero.st.arc
		for id in arc.N:
			if arc.is_card(id):
				arc.cards[id] = a["cards"]
		arc._changed()
	if a.has("wisps") and g.hero.skills.has_method("spawn_wisp"):
		for i in int(a["wisps"]):
			g.hero.skills.spawn_wisp()
	if a.get("show", "") == "collision":
		_show_collision(g)
	if a.has("shot"):
		_shot(g, a)
	if a.has("brainlog"):   # --brainlog=S: every second for S seconds, each creature near the pilgrim: kind, ai, state
		_brainlog(g, float(a["brainlog"]))
	if a.has("arena"):
		await _arena(g, a)
	if a.has("boardtest") and g.hero.st.arc:
		var arc = g.hero.st.arc
		for l in arc.N["i_quake"]["links"]:
			if arc.is_knot(l):
				arc.lay(l)
		g.hero.st.arcana_points = 6
		for c in ["i_quake", "i_rust", "a_anvil"]:
			arc.take_card(c, "u")
	if a.has("panel"):
		if a["panel"] in PANELS:
			g.hud.toggle_panel(a["panel"])
		else:
			Bus.panel_requested.emit(a["panel"], "Maren the Gravekeeper" if a["panel"] == "vendor" else "Brannoc of the Nail")

## what blocks: a node in the zone's ground layer, redrawn as the camera moves
static func _show_collision(g) -> void:
	var z: Zone = g.zone
	var n := Node2D.new()
	n.z_index = 4000
	n.z_as_relative = false
	z.add_child(n)
	n.draw.connect(func():
		var c: Vector2 = g.hero.tp
		for y in range(int(c.y) - 14, int(c.y) + 15):
			for x in range(int(c.x) - 14, int(c.x) + 15):
				if z.is_solid(Vector2(x + 0.5, y + 0.5)):
					var pts := PackedVector2Array([Iso.to_screen(Vector2(x, y)), Iso.to_screen(Vector2(x + 1, y)), Iso.to_screen(Vector2(x + 1, y + 1)), Iso.to_screen(Vector2(x, y + 1)), Iso.to_screen(Vector2(x, y))])
					n.draw_polyline(pts, Color(1, 0.2, 0.2, 0.8), 2.0)
		for k in z.posts:
			if (Vector2(k) - c).length() > 16.0:
				continue
			for po in z.posts[k]:
				var ring := PackedVector2Array()
				for i in 25:
					var a2 := TAU * i / 24.0
					ring.append(Iso.to_screen((po[0] as Vector2) + Vector2(cos(a2), sin(a2)) * float(po[1])))
				n.draw_polyline(ring, Color(1, 0.9, 0.2, 0.95), 2.0)
		var hr := PackedVector2Array()
		for i in 25:
			var a3 := TAU * i / 24.0
			hr.append(Iso.to_screen(c + Vector2(cos(a3), sin(a3)) * float(g.hero.radius)))
		n.draw_polyline(hr, Color(0.3, 1, 0.5, 0.95), 2.0))
	g.get_tree().process_frame.connect(func(): if is_instance_valid(n): n.queue_redraw())

## the balance arena: a ring of creatures, every order's skills logging what they dealt
static func _arena(g, a: Dictionary) -> void:
	var hero = g.hero   # the pilgrim at the start (after a fall, g.hero is the one who returned)
	var tree: SceneTree = g.get_tree()
	for m in tree.get_nodes_in_group("monsters"):
		m.queue_free()
	await tree.process_frame
	var n := int(a["arena"])
	var live := a.has("arena_live")
	for i in n:
		var ang := float(i) / n * TAU
		var at: Vector2 = hero.tp + Vector2(cos(ang), sin(ang)) * (3.0 + (i % 3))
		var m = Brain.spawn(g.zone, a.get("arena_kind", "husk"), at, int(a.get("arena_lvl", "12")), String(a.get("arena_rank", "normal")), "arena", -1.0 if live else 1e7)
		if m and live:
			m.brain.wake(m)
		elif m:
			m.dmg = Vector2.ZERO
			m.speed = 0.0
	hero.st.hp = hero.st.life_max()
	if a.has("sigils"):
		var j := 0
		for m in tree.get_nodes_in_group("monsters"):
			CountSigil.on(m, SIGIL_KINDS[j % 4]).set_meta("demo", j * 2)
			j += 1
	var book = hero.skills
	if "auto_stand" in book:
		book.auto_stand = true
	book.trace = true
	book.dmg_log.clear()
	hero.target = null
	var T := float(a.get("arena_t", "20"))
	var tally := {"falls": 0, "lost": 0.0, "kills": 0}
	Bus.hero_died.connect(func():
		tally["falls"] += 1
		print("FELL slain by ", g.hero.last_blow))
	Bus.hero_hit.connect(func(v): tally["lost"] += float(v))
	Bus.monster_killed.connect(func(_m): tally["kills"] += 1)
	await tree.create_timer(T).timeout
	hero = g.hero   # a fall and return makes a new pilgrim
	var dl: Dictionary = hero.skills.dmg_log
	var tot := 0.0
	for k in dl:
		if k != "_spent":
			tot += float(dl[k])
	var left: int = tree.get_nodes_in_group("monsters").filter(func(x): return not x.dead).size()
	print("HERO %s lvl %d life %.0f armor %.0f res %.0f poise %.0f | now hp %.0f dead %s | creatures left %d | falls %d, life lost %.0f, kills %d" % [hero.cls, hero.st.level, hero.st.life_max(), hero.st.armor(), hero.st.res_max(), hero.st.poise_max(), hero.st.hp, str(hero.dead), left, tally["falls"], tally["lost"], tally["kills"]])
	var spent := float(dl.get("_spent", 0.0))
	print("BAL %s dps %.1f spent %.0f per_ess %.2f parts %s" % [a.get("autocast", "-"), tot / T, spent, tot / maxf(1.0, spent), str(dl)])
	tree.quit()

## --demo: fight the nearest creatures, for captures (--trace prints the state every 1.5 s)
static func _demo(g) -> void:
	for i in 300:
		await g.get_tree().create_timer(0.3).timeout
		var hero = g.hero
		if hero == null or hero.dead:
			continue
		var m := Combat.nearest_monster(g.zone, hero.tp, 40.0)
		if m:
			hero.target = m
		if g.args.has("trace") and i % 5 == 0:
			print("T ", i, " hero ", hero.tp, " act ", hero.act, " walk ", hero.walking, " path ", hero.path.size(), " tgt ", (m.kind + " " + str(m.tp)) if m else "none", " hp ", hero.st.hp, " mons ", g.get_tree().get_nodes_in_group("monsters").size(), " thp ", (m.hp if m else -1.0), " missiles ", g.zone.sorted.get_children().filter(func(c): return c is Missile).size())


## --menutest=pause|title[=row]: clicks a menu row the way a mouse does (window pixels through Input), prints MENU lines
static func _click_at(g, w: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = w
	m.global_position = w
	Input.parse_input_event(m)
	await g.get_tree().process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = w
		e.global_position = w
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		await g.get_tree().process_frame

static func _menutest(g, a: Dictionary) -> void:
	await g.get_tree().create_timer(2.0).timeout
	var what: String = a["menutest"]
	print("MENU window ", DisplayServer.window_get_size(), " viewport ", g.get_viewport().get_visible_rect().size)
	if what == "quitdirect":
		print("MENU calling _act(quit) directly")
		g.hud.pause.open()
		g.hud.pause._act("quit", false)
		await g.get_tree().create_timer(2.0).timeout
		print("MENU STILL RUNNING after direct quit")
		return
	if what == "pause":
		g.hud.pause.open()
		await g.get_tree().create_timer(0.5).timeout
		var P = g.hud.pause
		P._build()
		for i in P.rows.size():
			if P.rows[i][1] == "quit":
				var w: Vector2 = g.get_viewport().get_screen_transform() * P.get_global_transform_with_canvas() * P._row_rect(i).get_center()
				print("MENU clicking Save and quit at ", w)
				var mm := InputEventMouseMotion.new()
				mm.position = w
				Input.parse_input_event(mm)
				await g.get_tree().process_frame
				await g.get_tree().process_frame
				var hc = g.get_viewport().gui_get_hovered_control()
				print("MENU hovered control: ", hc, " ", hc.get_path() if hc else "", " filter ", hc.mouse_filter if hc else -1, " pause visible ", P.visible, " pause path ", P.get_path(), " rect ", P.get_global_rect(), " parent ", P.get_parent().get_global_rect(), " pfilter ", P.get_parent().mouse_filter, " layer vis ", P.get_parent().get_parent().visible, " row ", P._row_rect(0))
				await _click_at(g, w)
		await g.get_tree().create_timer(2.0).timeout
		print("MENU STILL RUNNING after Save and quit")
	elif what.begins_with("title"):
		var T = null
		for c in g.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("ui/title.gd"):
				T = c
		if T == null:
			print("MENU no title")
			return
		await g.get_tree().create_timer(3.0).timeout
		print("MENU title rows ", T.rows.map(func(r): return r[1] if r.size() > 1 else r))
		var k := int(a.get("row", "0"))
		var w2: Vector2 = g.get_viewport().get_screen_transform() * T.root.get_global_transform_with_canvas() * T._row_rect(k).get_center()
		print("MENU clicking row ", k, " at ", w2, " mode ", T.mode)
		await _click_at(g, w2)
		await g.get_tree().create_timer(1.5).timeout
		print("MENU after click: mode ", T.mode if is_instance_valid(T) else "(title gone)", " leaving ", T.leaving if is_instance_valid(T) else -1.0)

## the screen, saved (--shot): for side-by-side checks against the browser build
static func _shot(g, a: Dictionary) -> void:
	var tree: SceneTree = g.get_tree()
	await tree.create_timer(float(a.get("shot_t", "4"))).timeout
	var n := int(a.get("shot_n", "1"))
	var path := String(a["shot"])
	for i in n:
		await RenderingServer.frame_post_draw
		var p := path if n == 1 else path.get_basename() + "_%d.png" % i
		g.get_viewport().get_texture().get_image().save_png(p)
		if i < n - 1:
			await tree.create_timer(0.25).timeout
	tree.quit()

## PixelForge's "See it in the game" for an object (--place=a,b): each stands a few tiles from the pilgrim, drawn
## the way the world draws its painted objects (world/objects/manager_build.gd), a swaying one through the addon
static func _forge_place(g, a: Dictionary) -> void:
	var manifest := "res://art/objects/objects.json"
	var meta: Dictionary = PFObjects.manifest(manifest)
	var mgr = g.zone.get_node_or_null("WorldObjects")
	var i := 0
	for name in String(a["place"]).split(","):
		name = name.strip_edges()
		if name == "":
			continue
		var e: Dictionary = meta.get(name, {})
		if e.is_empty():
			print("FORGE object missing: ", name)
			continue
		var tp: Vector2 = g.hero.tp + Vector2(2.0 + 1.5 * float(i % 3), -1.0 + 1.5 * floorf(float(i) / 3.0))
		if int(e.get("frames", 1)) <= 1 and mgr != null and mgr.has_method("_art_node"):
			mgr._art_node(name, tp)
		else:
			PFObjects.place(g.zone.sorted, manifest, name, Iso.to_screen(tp), Iso.WPX)
		print("FORGE placed: ", name, " at ", tp)
		i += 1

## a look at an effect (--fx): a looping one plays on; a one-shot (a nova, a burst) plays again every 1.5 s for
## twenty seconds, so it is on screen for a --shot and for a person's glance, not gone in a blink
static func _forge_fx_look(g, fx_dir: String, names: PackedStringArray) -> void:
	var again: Array = []
	for name in names:
		if name == "":
			continue
		var sp = PFFx.spawn(g.hero, fx_dir, name, Vector2(0, -60), 1.0, 2)
		if sp == null:
			print("FORGE fx missing: ", name)
		elif not sp.sprite_frames.get_animation_loop("play"):
			again.append(name)
	for i in 13:
		if again.is_empty():
			return
		await g.get_tree().create_timer(1.5).timeout
		if g.hero == null or not is_instance_valid(g.hero):
			return
		for name in again:
			PFFx.spawn(g.hero, fx_dir, name, Vector2(0, -60), 1.0, 2)

static func _forge_preview(g, a: Dictionary) -> void:
	## PixelForge's "Preview in game": effects at the pilgrim (--fx=a,b) and the sprite set's attached effects (--attach).
	var fx_dir := "res://art/fx"
	if a.has("fx"):
		_forge_fx_look(g, fx_dir, String(a["fx"]).split(","))
	if a.has("attach"):
		var kind := String(a.get("skin", g.hero.cls))
		var set := PFSpriteSet.new()
		if set.load_file("res://art/sprites/%s.json" % kind):
			var nodes := PFFx.spawn_attachments(g.hero, set.fx_dir(fx_dir), set, "down", 1.0, 2)
			g.hero.set_meta("forge_attachments", nodes)
			print("FORGE attachments: ", nodes.size())


## what every creature within 14 yards is doing, once a second (behaviour checks)
static func _brainlog(g, secs: float) -> void:
	var tree: SceneTree = g.get_tree()
	for i in int(secs):
		await tree.create_timer(1.0).timeout
		if not is_instance_valid(g) or g.hero == null:
			return
		var row := []
		for m in tree.get_nodes_in_group("monsters"):
			if m.dead or m.tp.distance_to(g.hero.tp) > 14.0:
				continue
			row.append("%s/%s:%s" % [m.kind, m.ai, m.brain.state if m.brain else "-"])
		print("BRAIN t=%d hero_hp=%d %s" % [i + 1, int(g.hero.st.hp), " ".join(row)])
