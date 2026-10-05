extends Node2D

## The world's interactive objects in one zone (zz_quests.js, zd_world22.js, d_play.js interact, zz_voice.js,
## zz_landmarks55.js, zz_zz_maw95.js): townsfolk, chests, shrines, god altars and their Heralds, toppled statues,
## lantern-stones, waystones, the vows' relics, captives and shrines, landmarks' inscriptions, the town's safe
## circle. Made by world/objects.gd attach(); a child of the zone, so it goes when the zone goes.
## Click a thing to walk up to it and use it (no markers over anyone); walk into a waystone to learn it and travel.

const Q := preload("res://world/quests.gd")
const NPC := preload("res://world/objects/npc.gd")
const WAYSTONE := preload("res://world/objects/waystone.gd")
const GORE := preload("res://world/objects/gore.gd")
const SHRINE_TEXT := {"echo": "Shrine of Echoes: +50% skill damage", "wisp": "Shrine of the Wisp: more wisps, faster",
	"stone": "Shrine of Stone: +100 armor", "refill": "Refilling Shrine"}
const REACH := {"npc": 1.7, "vendor": 1.7, "chest": 1.5, "shrine": 1.5, "altar": 1.2, "lantern": 1.8, "relic": 1.6,
	"captive": 1.9, "qshrine": 1.7, "wp": 1.0}

static var _tex_cache := {}

var main: Node
var zone: Zone
var hero: Hero
var ui: Node
var passage: Node
var things: Array = []        # {type, o, i, tp, node, name, reach, rect: Callable}
var waystone: Node = null
var gore: Node2D
var pending = null
var hovered = null
var wp_near := false
var lantern_latch := {}
var mark_t := 0.0
var mark_cool := 0.0
var sweep_t := 0.0
var wave := {}
var safe_c := Vector2.ZERO
var safe_r := 0.0
var act_n := 1

func setup(m: Node, z: Zone, h: Hero) -> void:
	name = "WorldObjects"
	main = m
	zone = z
	hero = h
	ui = m.get_node_or_null("GodmarrowWorldUI")
	passage = m.get_node_or_null("WaystonePassage")
	act_n = Q.act_of(z.id)
	gore = GORE.new()
	gore.setup(z)
	gore.hero = h
	z.add_child(gore)
	var sc = z.markers.get("safeCircle")
	if sc is Dictionary:
		safe_c = Vector2(sc["x"], sc["y"])
		safe_r = float(sc["r"])
	for o in z.objects:
		_build(o)
	_clear_settled()
	Bus.monster_killed.connect(_on_kill)
	if Bus.has_signal("herald_felled"):
		Bus.connect("herald_felled", _on_herald)
	_on_enter()

func rebind(h: Hero) -> void:
	hero = h
	if gore:
		gore.hero = h
	pending = null

## hooks answered in manager_use.gd: a creature died; a Herald fell
func _on_kill(_m) -> void:
	pass

func _on_herald(_m, _god: String) -> void:
	pass

# ------------------------------------------------------------------ building
func _build(o: Dictionary) -> void:
	var i := int(o.get("i", -1))
	var tp := Vector2(o["x"], o["y"])
	var ty: String = o.get("type", "")
	var mem := Q.obj(zone.id, i)
	match ty:
		"lantern":
			_add("lantern", o, _holder(i), o.get("name", "Lantern"))
		"vendor":
			var n := NPC.new()
			n.setup("vendor", tp)
			zone.sorted.add_child(n)
			_add("vendor", o, n, o.get("name", "Maren the Gravekeeper"))
			_quiet_light(tp, 0.35)
		"chest":
			var h := _holder(i)
			if mem.get("open", false):
				_swap(h, "chest_open")
			_add("chest", o, h, "" if mem.get("open", false) else "Chest", not mem.get("open", false))
		"shrine":
			var h := _holder(i)
			var used: bool = mem.get("used", false) or (o.get("kind", "") == "arcana" and Q.state()["done"].has("shrine:" + zone.id))
			if used:
				_swap(h, "shrine_used")
			_add("shrine", o, h, Q.SHRINE_NAMES.get(o.get("kind", ""), "Shrine"), not used)
		"statue":
			var n := _art_node("statue%d" % (int(o.get("v", 0)) % 3), tp, Vector2(0, 0.3))
			_add("statue", o, n, "", false)
		"altar":
			_build_altar(o, tp, mem)
		"qobj":
			_build_qobj(o, tp, mem)

func _build_qobj(o: Dictionary, tp: Vector2, mem: Dictionary) -> void:
	var i := int(o.get("i", -1))
	match o.get("q", ""):
		"wp":
			waystone = WAYSTONE.new()
			add_child(waystone)
			waystone.setup(zone, o, Q.known_wp(zone.id))
			_add("wp", o, waystone.floor_n, o.get("name", "Waystone"))
			_quiet_light(tp, 0.3, Color(0.55, 0.62, 0.68))
		"npc":
			var role: String = o.get("role", "")
			if role == "stash":
				var h := _holder(i)
				if h == null:
					h = NPC.new()
					h.setup("stash", tp)
					zone.sorted.add_child(h)
				_add("npc", o, h, o.get("name", "The Reliquary Chest"))
			else:
				var n := NPC.new()
				n.setup(role, tp)
				zone.sorted.add_child(n)
				_add("npc", o, n, o.get("name", ""))
				_quiet_light(tp, 0.3)
		"relic":
			var q: String = o.get("qid", "")
			if Q.is_done(q) or mem.get("taken", false):
				return
			var n := _art_node("relic_book", tp)
			_add("relic", o, n, o.get("name", ""))
			_quest_glow(n)
			_quiet_light(tp, 0.55)
		"captive":
			var q: String = o.get("qid", "")
			if Q.is_done(q) or mem.get("freed", false):
				return
			var n := _art_node("captive", tp)
			_add("captive", o, n, o.get("name", ""))
			_quest_glow(n)
			_quiet_light(tp, 0.55)
		"shrine":
			var used: bool = mem.get("used", false) or Q.is_done(o.get("qid", ""))
			var n := _asset_node("shrine_used" if used else "shrine", tp)
			_add("qshrine", o, n, o.get("name", ""), not used)
			if not used:
				_quest_glow(n)
			_quiet_light(tp, 0.5)

func _build_altar(o: Dictionary, tp: Vector2, mem: Dictionary) -> void:
	var god: String = o.get("god", "bone")
	var g: Dictionary = Q.GODS.get(god, Q.GODS["bone"])
	var used: bool = mem.get("used", false) or Q.state()["done"].has("herald:" + god)
	if used:
		o["used"] = true     # AIWorld reads it: a spent altar stays cold
	var n := _asset_node("altar", tp, "decor")
	var beam := Node2D.new()
	beam.set_script(load("res://world/objects/beam.gd"))
	beam.set("col", g["rgb"])
	n.add_child(beam)
	beam.visible = not used and not mem.get("woke", false)
	_add("altar", o, n, "Altar of " + String(g["name"]), not used and not mem.get("woke", false))

func _add(ty: String, o: Dictionary, node: Node2D, nm: String, live: bool = true) -> Dictionary:
	var e := {"type": ty, "o": o, "i": int(o.get("i", -1)), "tp": Vector2(o["x"], o["y"]), "node": node, "name": nm,
		"reach": REACH.get(ty, 1.5), "live": live}
	if ty == "npc" and zone:   # the camp's folk stand their ground (the zone's own objects are posts already)
		zone.add_post(e["tp"], 0.3)
	things.append(e)
	return e

## the sprite the zone already drew for object i
func _holder(i: int) -> Node2D:
	var key := "object:%d" % i
	for c in zone.sorted.get_children():
		if c.has_meta("item") and c.get_meta("item") == key:
			return c
	return null

static func _piece(key: String, cat: String = "") -> Array:
	var e: Dictionary
	var hr := 4.0
	if cat == "decor":
		e = Assets.piece("decor", key)
		hr = 4.0
	else:
		e = Assets.piece("trees", key)
		if e.is_empty():
			e = Assets.piece("world", key)
			hr = 2.0
	if e.is_empty():
		return []
	if e.has("hr"):
		hr = float(e["hr"])
	return [Assets.tex(e["png"]), Vector2(float(e.get("ox", 0)), float(e.get("oy", 0))), hr]

## change the picture of a zone-drawn object (a chest opened, a shrine spent)
func _swap(h: Node2D, key: String) -> void:
	if h == null:
		return
	var p := _piece(key)
	if p.is_empty():
		return
	for c in h.get_children():
		if c is Sprite2D:
			var sp: Sprite2D = c
			sp.texture = p[0]
			var sc := Iso.WPX / float(p[2])
			sp.scale = Vector2(sc, sc)
			sp.offset = Vector2(-(p[0].get_width() - p[1].x) if sp.flip_h else -p[1].x, -p[1].y)
			return

func _asset_node(key: String, tp: Vector2, cat: String = "") -> Node2D:
	var n := Node2D.new()
	n.position = Iso.to_screen(tp)
	var p := _piece(key, cat)
	if not p.is_empty():
		var sp := Sprite2D.new()
		sp.texture = p[0]
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc := Iso.WPX / float(p[2])
		sp.scale = Vector2(sc, sc)
		sp.offset = -p[1]
		n.add_child(sp)
	zone.sorted.add_child(n)
	return n

## art painted for this port (art/objects, see paint_objects.py)
func _art_node(key: String, tp: Vector2, depth_off: Vector2 = Vector2.ZERO) -> Node2D:
	var meta := _art_meta()
	var e: Dictionary = meta.get(key, {})
	var n := Node2D.new()
	n.position = Iso.to_screen(tp)
	var tex := _art_tex(e.get("png", ""))
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc := Iso.WPX / float(e.get("hr", 2))
		sp.scale = Vector2(sc, sc)
		sp.offset = -Vector2(float(e.get("ox", 0)), float(e.get("oy", 0)))
		n.add_child(sp)
	zone.sorted.add_child(n)
	return n

static func _art_meta() -> Dictionary:
	if _tex_cache.has("__meta"):
		return _tex_cache["__meta"]
	var f := FileAccess.open("res://art/objects/objects.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else {}
	_tex_cache["__meta"] = d if d is Dictionary else {}
	return _tex_cache["__meta"]

static func _art_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if FileAccess.file_exists(path + ".import"):
		t = load(path)
	else:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

## a faint neutral light so a thing can be found in the dark (the web's light holes); never red
func _quiet_light(tp: Vector2, energy: float, col: Color = Color(0.82, 0.76, 0.66)) -> void:
	var l := PointLight2D.new()
	l.texture = Lights.radial(256)
	l.color = col
	l.energy = energy
	l.texture_scale = 1.3
	l.position = Iso.to_screen(tp) + Vector2(0, -40)
	l.set_meta("dark_dy", 40.0)   # the dark layer lays its pool on the ground
	zone.sorted.add_child(l)

## the faint gold breath under an vow's object (zz_quests qGroundDraw)
func _quest_glow(n: Node2D) -> void:
	var g := Node2D.new()
	g.set_script(load("res://world/objects/beam.gd"))
	g.set("mode", 1)
	g.set("col", Color8(217, 164, 65))
	g.show_behind_parent = true   # on the ground under the thing, never over its body
	n.add_child(g)
	n.move_child(g, 0)

# ------------------------------------------------------------------ zone entry
func _on_enter() -> void:
	var zid := zone.id
	var s := Q.state()
	if act_n > int(s["act"]) and not zid.begins_with("qvault_"):
		s["act"] = act_n
	var fresh := Q.activate(act_n)
	if fresh > 0:
		_later(2.6, func(): Bus.say.emit("New grave vows are written in your journal (J)", 4.0))
	if Q.is_town(zid):
		if Q.kindle_wp(zid) and waystone:
			waystone.open = 1.0
		if not s["seen"].has("t%d" % act_n):
			s["seen"]["t%d" % act_n] = true
			var tw: Dictionary = Q.TOWN.get(act_n, {})
			if tw.has("greet"):
				_later(2.4, func(): if ui: ui.speak_line(tw["greet"], 6.0))
	# arriving through a waystone
	if passage and passage.on and passage.phase == "wait":
		passage.arrive(zone, hero)

func _later(secs: float, f: Callable) -> void:
	var tm := get_tree().create_timer(secs)
	tm.timeout.connect(func(): if is_instance_valid(self): f.call())

## what the world already settled: fulfilled vows' creatures, a felled boss, a spent Herald
func _clear_settled() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.zone != zone:
			continue
		var pk: String = m.pack
		var gone := false
		if pk.begins_with("q") and Q.is_done(pk.substr(1)):
			gone = true
		if m.boss and Q.felled(zone.id):
			gone = true
		if gone:
			m.remove_from_group("monsters")
			m.queue_free()
