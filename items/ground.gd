extends CanvasLayer
## Items and gold on the ground of one zone (made on the first drop, a child of the zone named "GroundItems").
##  * the things themselves are items/ground_item.gd nodes on zone.sorted;
##  * name labels are drawn here, on their own canvas layer that follows the camera (so the night does not darken
##    them): all of them while Alt is held (or `show_labels`, the touch LOOT toggle), and the one under the mouse;
##    stacked upward when they overlap, in rarity colours, as the web's e_ui.js draws them;
##  * click a label or an item to walk to it; it is taken within 0.9 yd (d_play.js). Gold is taken by walking over
##    it (0.9 yd), x1.25 with the wick turned down;
##  * the lantern's wicks act on creatures in its light (zz_zw_lantern63): the strongest wick carried decides.
## Items left in a zone wait there for the rest of the run (kept per zone id when the zone is left).

const ITEM_NODE := preload("res://items/ground_item.gd")
const SFX := preload("res://items/item_sfx.gd")
const LOOT_PATH := "res://items/loot.gd"
const PICK_R := 0.9
const LABEL_H := 28.0
const FONT_SIZE := 16

static var show_labels := false          # the touch LOOT toggle; Alt held does the same
static var _kept := {}                   # zone id -> [{entry, tp}] left behind (this run)
static var _kept_seed := -1

var zone: Zone
var items: Array = []
var hovered = null
var pending = null
var labels: Array = []                   # [{rect: Rect2, node}]
var floats: Array = []                   # [{pos, text, col, t}]
var draw_node: Node2D
var font: Font
var _wick_t := 0.0
var _repath_t := 0.0
var _autoloot := false
var _tinted := false
const WICK_RGB := {"lblue": Color8(150, 200, 255), "lamber": Color8(255, 176, 96), "lwhite": Color8(236, 236, 228),
	"lgreen": Color8(170, 230, 150), "lviolet": Color8(200, 160, 255)}

class Drawer extends Node2D:
	var mgr
	func _draw() -> void:
		mgr._draw_labels(self)

class Keeper extends Node:
	## brings back what was left on the ground when a zone is entered again
	func _ready() -> void:
		Bus.zone_entered.connect(_on_zone)
	func _on_zone(zid: String) -> void:
		var main := get_tree().current_scene
		if main == null or not ("zone" in main) or main.zone == null:
			return
		load("res://items/ground.gd").attach(main, main.zone, main.hero)

# ------------------------------------------------------------------ static API
## for main.gd on every zone entry (optional: the first kill or drop also makes it): the zone's ground layer, so
## the wicks act and what was left here comes back
static func attach(_main, z: Zone, _hero) -> void:
	if z == null:
		return
	var had: bool = z.get_node_or_null("GroundItems") != null
	for_zone(z)
	if not had:
		restore(z)

static func for_zone(z: Zone) -> Node:
	var g = z.get_node_or_null("GroundItems")
	if g == null:
		g = load("res://items/ground.gd").new()
		g.name = "GroundItems"
		g.zone = z
		z.add_child(g)
		var tree := z.get_tree()
		if tree and tree.root.get_node_or_null("ItemsKeeper") == null:
			var k := Keeper.new()
			k.name = "ItemsKeeper"
			tree.root.add_child.call_deferred(k)
	return g

## put one drop ({item} or {gold}) on the ground at tp, falling from `from`
static func spawn(z: Zone, entry: Dictionary, at: Vector2, from: Vector2, fall: bool = true) -> Node:
	var mgr = for_zone(z)
	var n = ITEM_NODE.new()
	var icon: Texture2D = null
	if entry.has("item"):
		icon = load(LOOT_PATH).icon_for(entry["item"])
	n.setup(entry, at, from if fall else at, icon)
	if not fall:
		n.t = 0.0
	z.sorted.add_child(n)
	mgr.items.append(n)
	if mgr._autoloot:
		print("drop: ", n.label_text(), " (", n.item.q if n.item else "gold", ") at ", at)
	if entry.has("item") and fall:
		Bus.loot_dropped.emit(entry["item"])
	return n

static func drop_sound(z: Zone, drops: Array) -> void:
	var rank := {"normal": 1, "magic": 2, "rare": 3, "set": 4, "unique": 5, "potion": 1}
	var best := 0
	for d in drops:
		if d.has("item"):
			best = maxi(best, int(rank.get((d["item"] as Item).q, 1)))
	if best > 0:
		SFX.drop(for_zone(z), best)

## the strongest wick the hero carries (lblue lamber lwhite lgreen lviolet), or ""
static func wick(hero) -> String:
	if hero == null or hero.st == null:
		return ""
	var best := ""
	var bv := 0.0
	for k in ["lblue", "lamber", "lwhite", "lgreen", "lviolet"]:
		var v: float = hero.st.item(k)
		if v > bv:
			bv = v
			best = k
	return best

static func in_light(hero, p: Vector2) -> bool:
	# measured from where the light stands: under the lantern (zz_zw_lantern63.js:106)
	var at: Vector2 = hero.lantern.tp if hero != null and hero.lantern != null and is_instance_valid(hero.lantern) else (hero.tp if hero else Vector2.ZERO)
	return hero != null and p.distance_to(at) < hero.light_radius() * 0.7

## the violet wick: a creature dying in the lantern's light gives back a little of the hero's resource
static func wick_kill(_z: Zone, m, hero) -> void:
	if hero == null or hero.st == null or wick(hero) != "lviolet" or not in_light(hero, m.tp):
		return
	hero.st.res = minf(hero.st.res_max(), hero.st.res + hero.st.item("lviolet"))

static func restore(z: Zone) -> void:
	if _kept_seed != Game.seed:
		_kept.clear()
		_kept_seed = Game.seed
		return
	var list: Array = _kept.get(z.id, [])
	_kept.erase(z.id)
	for e in list:
		spawn(z, e["entry"], e["tp"], e["tp"], false)

# ------------------------------------------------------------------ the node
func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	draw_node = Drawer.new()
	draw_node.mgr = self
	add_child(draw_node)
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://ui/uikit.gd"):
		var f = load("res://ui/uikit.gd").font("pixel")
		if f is Font:
			font = f
	# test switches (after "--"): --labels shows every label, --autoloot sends the hero after drops when idle
	var ua := OS.get_cmdline_user_args()
	if ua.has("--labels"):
		show_labels = true
	_autoloot = ua.has("--autoloot")
	if _kept_seed != Game.seed:
		_kept.clear()
		_kept_seed = Game.seed

func _exit_tree() -> void:
	if zone == null:
		return
	var list := []
	for n in items:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			list.append({"entry": {"gold": n.gold} if n.gold > 0 else {"item": n.item}, "tp": n.tp})
	if not list.is_empty():
		_kept[zone.id] = list

func _hero() -> Hero:
	return zone.hero_ref if zone and is_instance_valid(zone.hero_ref) else null

func _process(dt: float) -> void:
	items = items.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())
	var hero := _hero()
	if hero == null or hero.st == null:
		return
	var inv: Inventory = hero.st.inv
	if inv and not inv.overflow.is_connected(_on_overflow):
		inv.overflow.connect(_on_overflow)
	var pool := hero.light_radius() * 0.95
	for n in items:
		n.hero_in_pool = not hero.dead and n.tp.distance_to(hero.tp) < pool
	# gold: walk over it
	if not hero.dead:
		for n in items.duplicate():
			if n.gold > 0 and n.t <= 0.0 and n.tp.distance_to(hero.tp) < PICK_R:
				_pickup(n, hero)
	_labels_and_hover(hero)
	if _autoloot and pending == null and hero.target == null and not hero.dead:
		var best = null
		for n in items:
			if n.gold == 0 and n.t <= 0.0 and n.tp.distance_to(hero.tp) < 14.0 and (best == null or n.tp.distance_to(hero.tp) < best.tp.distance_to(hero.tp)):
				best = n
		if best:
			pending = best
			hero.walk_to(best.tp)
			print("autoloot: going for ", best.label_text())
	_pending(hero, dt)
	_wicks(hero, dt)
	for f in floats:
		f["t"] += dt
	floats = floats.filter(func(f): return f["t"] < 0.9)
	draw_node.queue_redraw()

func _ui_captured() -> bool:
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null

func _labels_and_hover(hero: Hero) -> void:
	labels.clear()
	var show_all := show_labels or Input.is_key_pressed(KEY_ALT)
	var mp := zone.get_global_mouse_position()
	var ct := get_viewport().get_canvas_transform()
	var vr := get_viewport().get_visible_rect().grow(120.0)
	var near := []
	# nearer the camera first, so the front item's label sits lowest
	var order := items.duplicate()
	order.sort_custom(func(a, b): return a.tp.x + a.tp.y > b.tp.x + b.tp.y)
	for n in order:
		var p: Vector2 = n.ground_pos()
		if not vr.has_point(ct * p):
			continue
		var is_near: bool = absf(mp.x - p.x) < 40.0 and absf(mp.y - (p.y - 16.0)) < 40.0
		if is_near:
			near.append(n)
		if not show_all and not is_near:
			continue
		var txt: String = n.label_text()
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 16.0
		var r := Rect2(roundf(p.x - w / 2.0), roundf(p.y - 72.0), w, LABEL_H)
		for k in 8:
			var hit := false
			for l in labels:
				if (l["rect"] as Rect2).intersects(r):
					hit = true
					break
			if not hit:
				break
			r.position.y -= LABEL_H + 2.0
		labels.append({"rect": r, "node": n})
	hovered = null
	for l in labels:
		if (l["rect"] as Rect2).has_point(mp):
			hovered = l["node"]
	if hovered == null and not near.is_empty():
		hovered = near[0]
	if _ui_captured() or hero.dead:
		hovered = null

func _draw_labels(c: Node2D) -> void:
	for l in labels:
		var r: Rect2 = l["rect"]
		var n = l["node"]
		if not is_instance_valid(n):
			continue
		c.draw_rect(r, Color(40 / 255.0, 36 / 255.0, 50 / 255.0, 0.95) if n == hovered else Color(10 / 255.0, 9 / 255.0, 13 / 255.0, 0.85))
		c.draw_string(font, Vector2(r.position.x + 8.0, r.position.y + LABEL_H - 8.0), n.label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, n.label_color())
	for f in floats:
		var k: float = f["t"] / 0.9
		var col: Color = f["col"]
		col.a = 1.0 - maxf(0.0, (k - 0.3) / 0.7)
		var p: Vector2 = f["pos"] + Vector2(0, -50.0 * k)
		c.draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, FONT_SIZE, 5, Color(0, 0, 0, col.a))
		c.draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, FONT_SIZE, col)

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var hero := _hero()
	if hero == null or hero.dead:
		return
	if hovered != null and is_instance_valid(hovered) and not _ui_captured():
		pending = hovered
		hero.target = null
		hero.walk_to(pending.tp)
		_repath_t = 0.3
		get_viewport().set_input_as_handled()
	else:
		pending = null

## walk to a clicked item and take it within reach (the hold-to-walk poll is held off while we steer)
func _pending(hero: Hero, dt: float) -> void:
	if pending == null:
		return
	if not is_instance_valid(pending) or pending.is_queued_for_deletion() or hero.dead or hero.target != null:
		pending = null
		return
	if pending.tp.distance_to(hero.tp) < PICK_R:
		_pickup(pending, hero)
		pending = null
		return
	if hero.act != "":
		return
	_repath_t -= dt
	if not hero.walking and _repath_t <= 0.0:
		hero.walk_to(pending.tp)
		_repath_t = 0.3
	hero.repath = 0.18

func _pickup(n, hero: Hero) -> void:
	var inv: Inventory = hero.st.inv
	if n.gold > 0:
		var amt := maxi(1, int(round(n.gold * load(LOOT_PATH).gold_k(hero))))
		inv.gold += amt
		if _autoloot:
			print("picked gold +", amt, " total ", inv.gold)
		Bus.gold_changed.emit(inv.gold)
		floats.append({"pos": n.ground_pos() + Vector2(0, -30), "text": "+%d gold" % amt, "col": Color("#d9a441"), "t": 0.0})
		SFX.pickup_gold(self)
		_remove(n)
		hero.stats_changed.emit()
		return
	var it: Item = n.item
	if inv.add(it):
		if _autoloot:
			print("picked ", it.name, " bag ", inv.bag.size(), " belt ", inv.belt)
		SFX.pickup_item(self)
		if it.q == "unique" or it.q == "rare":
			Bus.say.emit(it.name, 1.5)
		_remove(n)
		hero.stats_changed.emit()
	else:
		Bus.say.emit("No room in your pack.", 1.4)

func _remove(n) -> void:
	items.erase(n)
	if hovered == n:
		hovered = null
	n.queue_free()

func _on_overflow(it: Item) -> void:
	var hero := _hero()
	if hero:
		load(LOOT_PATH).drop_item(zone, hero.tp, it)

## the wicks on creatures in the light, every quarter second (zz_zw_lantern63); the hearth wick's life is in
## HeroStats.tick, the violet wick's on each kill (wick_kill)
func _wicks(hero: Hero, dt: float) -> void:
	_wick_t += dt
	if _wick_t < 0.25 or hero.dead:
		return
	var T := _wick_t
	_wick_t = 0.0
	var w := wick(hero)
	# the strongest wick tints the lantern's light (the class colour otherwise)
	if hero.lamp:
		if w != "":
			hero.lamp.color = WICK_RGB[w]
			_tinted = true
		elif _tinted:
			hero.lamp.color = HeroStats.lamp_color(hero.cls)
			_tinted = false
	if w == "":
		return
	var st := hero.st
	if w == "lgreen":
		st.res = minf(st.res_max(), st.res + st.item("lgreen") * T)
		return
	if w != "lwhite" and w != "lblue":
		return
	var v := st.item(w)
	var R := hero.light_radius() * 0.7
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.dead or m.zone != zone or m.tp.distance_to(hero.tp) >= R:
			continue
		if w == "lwhite":
			m.slow = maxf(m.slow, v / 100.0)
		elif not m.boss and m.feared <= 0.0 and randf() < v / 100.0 * T:
			m.feared = 0.8 + randf() * 0.6
