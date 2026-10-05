extends Node
## Test scenarios for the world objects (only with the user arg --objtest=<name>; see world/objects.gd):
##  wp (walk into the camp's waystone and pass to the fen), chest, npcs, altar, relic, captive, qshrine, kill, matron.

const Q := preload("res://world/quests.gd")
var main: Node
var which := ""

func _ready() -> void:
	name = "ObjTest"
	_run()

func _mgr() -> Node:
	return main.zone.get_node_or_null("WorldObjects") if main.zone else null

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _thing(ty: String) -> Dictionary:
	var m := _mgr()
	var best := {}
	var bd := 1e9
	for e in m.things:
		if e["type"] == ty and e["live"]:
			var d: float = main.hero.tp.distance_to(e["tp"])
			if d < bd:
				bd = d
				best = e
	return best

func _to(p: Vector2) -> void:
	var h = main.hero
	h.tp = p
	h._sync()
	main.cam.position = h.position
	main.cam.reset_smoothing()

func _use(e: Dictionary) -> void:
	var m := _mgr()
	m.pending = e
	main.hero.walk_to(m._approach(e))

func _kill_pack(pk: String) -> void:
	for mon in get_tree().get_nodes_in_group("monsters"):
		if mon.zone == main.zone and mon.pack == pk and not mon.dead:
			Combat.hit_monster(mon, 1e6, "phys", main.hero.tp)

func _journal() -> void:
	for r in Q.journal(1):
		print("  J ", r["name"], " | ", r["state"], " | ", r["where"], " | ", r["reward"])
	print("  act ", Q.state()["act"], " open ", Q.state()["act_open"], " wp ", Q.state()["wp"].keys())

func _run() -> void:
	await _wait(1.5)
	print("OBJTEST ", which, " zone ", main.zone.id)
	match which:
		"wp":
			Q.kindle_all()
			var ws = _mgr().waystone
			_to(ws.tp + Vector2(0, 3.2))
			await _wait(0.6)
			main.hero.walk_to(ws.tp)
			await _wait(2.5)
			var ui = main.get_node("GodmarrowWorldUI")
			print("  panel open ", ui.panel_open(), " near ", _mgr().wp_near)
			_mgr()._travel("fen")
			for i in 12:
				await _wait(0.5)
				var p = main.get_node("WaystonePassage")
				print("  t", i, " phase ", p.phase, " on ", p.on, " zone ", main.zone.id, " hero ", main.hero.tp, " sink ", p.sink, " fade ", ui.fade)
		"chest":
			var e := _thing("chest")
			_to(e["tp"] + Vector2(1.5, 1.5))
			await _wait(0.5)
			_use(e)
			await _wait(2.0)
			print("  chest open ", Q.obj(main.zone.id, e["i"]), " ground items ", main.zone.sorted.get_children().filter(func(c): return c.get_script() and String(c.get_script().resource_path).contains("ground")).size())
		"npcs":
			var m := _mgr()
			for e in m.things:
				if e["type"] in ["npc", "vendor"]:
					_to(e["tp"] + Vector2(1.2, 1.2))
					await _wait(0.2)
					_use(e)
					await _wait(1.6)
					var ui = main.get_node("GodmarrowWorldUI")
					print("  ", e["name"], " -> ", ui.bark_name.text, ": ", ui.bark_text.text)
		"altar":
			var e := _thing("altar")
			if e.is_empty():
				print("  no altar here")
				return
			_to(e["tp"] + Vector2(3, 3))
			await _wait(0.5)
			_use(e)
			await _wait(4.0)
			print("  altar woke ", e["o"].get("woke", false), " heralds ", get_tree().get_nodes_in_group("monsters").filter(func(x): return x.pack == "herald").map(func(x): return x.name_shown))
		"relic":
			var e := _thing("relic")
			_kill_pack("q" + String(e["o"]["qid"]))
			_to(e["tp"] + Vector2(2, 2))
			await _wait(0.5)
			_use(e)
			await _wait(2.0)
			_journal()
		"captive":
			var e := _thing("captive")
			_to(e["tp"] + Vector2(2, 2))
			await _wait(0.5)
			_use(e)
			await _wait(1.5)
			_kill_pack("q" + String(e["o"]["qid"]))
			await _wait(1.0)
			_to(e["tp"] + Vector2(1, 1))
			_use(e)
			await _wait(2.0)
			_journal()
		"qshrine":
			var e := _thing("qshrine")
			_to(e["tp"] + Vector2(2, 2))
			await _wait(0.5)
			_use(e)
			await _wait(2.0)
			for k in 2:
				_kill_pack("qwave_" + String(e["o"]["qid"]))
				await _wait(2.0)
			await _wait(1.0)
			_journal()
		"kill":
			for mon in get_tree().get_nodes_in_group("monsters"):
				if mon.rank == "unique" and mon.pack.begins_with("qa1"):
					_to(mon.tp + Vector2(2, 2))
					await _wait(0.5)
					Combat.hit_monster(mon, 1e6, "phys", main.hero.tp)
					break
			await _wait(2.0)
			_journal()
		"safe":
			var m := _mgr()
			var mon: Monster = Brain.spawn(main.zone, "hollow", m.safe_c + Vector2(1, 1), 3, "normal", "t")
			await _wait(1.0)
			print("  creature in the safe circle still there: ", is_instance_valid(mon) and mon.is_inside_tree(), " hero invuln ", main.hero.invuln)
		"mark":
			var lm: Dictionary = main.zone.d.get("landmarks", [{}])[0]
			_to(Vector2(lm["x0"] + lm["fw"] / 2.0 + 3.0, lm["y0"] + lm["fh"] / 2.0 + 3.0))
			await _wait(1.5)
			var ui = main.get_node("GodmarrowWorldUI")
			print("  whisper: ", ui.wh_name.text, " / ", ui.wh_text.text)
		"lantern":
			var e := _thing("lantern")
			main.hero.st.hp = 5.0
			_to(e["tp"] + Vector2(2.5, 2.5))
			await _wait(0.3)
			_use(e)
			await _wait(2.0)
			var ui = main.get_node("GodmarrowWorldUI")
			print("  hp ", main.hero.st.hp, " last ", main.last_lantern, " said ", ui.bark_name.text, ": ", ui.bark_text.text)
		"click":
			var e := _thing("npc")
			_to(e["tp"] + Vector2(3, 3))
			await _wait(1.0)
			var r: Rect2 = _mgr()._rect_of(e["node"])
			var sp: Vector2 = main.get_viewport().get_canvas_transform() * r.get_center()
			main.get_viewport().warp_mouse(sp)
			await _wait(0.3)
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = sp
			Input.parse_input_event(ev)
			await _wait(0.05)
			var ev2 := ev.duplicate()
			ev2.pressed = false
			Input.parse_input_event(ev2)
			await _wait(3.0)
			var ui = main.get_node("GodmarrowWorldUI")
			print("  clicked ", e["name"], " hover ", ui.hover_l.text, " hero ", main.hero.tp, " said ", ui.bark_name.text, ": ", ui.bark_text.text)
		"matron":
			for mon in get_tree().get_nodes_in_group("monsters"):
				if mon.boss:
					_to(mon.tp + Vector2(3, 3))
					await _wait(0.5)
					Combat.hit_monster(mon, 1e7, "phys", main.hero.tp)
					break
			await _wait(4.5)
			_journal()
