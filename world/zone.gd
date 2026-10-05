class_name Zone
extends Node2D

const TopDown := preload("res://world/topdown.gd")
## One zone, rebuilt from the web build's own export (data/zones/<id>_s<seed>.json, see tools/export_zones.js):
## the tile grid (collision, pathing, sight), the painted ground, the wall and cliff blocks, every drawn sprite (trees,
## rocks, props, decor, landmarks, objects), the ground scatter, the lights and the ambient light by hour.

signal built

const SOLID_TYPES := [2, 3, 4, 5, 7, 8, 9, 10, 15]
const SIGHT_TYPES := [2, 5, 7, 8, 9, 10, 15]   # rocks (3) are low: skills and shots pass over them (b_core.js lineClear, d_play.js losPoint)
const WALLISH := [5, 7, 10, 15]

var id := ""
var seed := 0
var d: Dictionary
var w := 0
var h := 0
var types := PackedByteArray()
var solid := PackedByteArray()
var astar := AStarGrid2D.new()
var ground_mat: ShaderMaterial   # the ground shader (the wind reaches its water)
var shadow_layer: Node2D
var sorted: Node2D           # the y-sorted layer: everything that stands up
var floor_layer: Node2D      # ground decals, scatter, corpses' blood
var objects: Array = []
var lanterns: Array = []
var connections: Array = []
var arrive := {}
var markers := {}
var wall_nodes: Array = []
var hero_ref: Hero
## posts: what stands on the ground and blocks a body without filling its tile (graves, chests, statues, braziers,
## the camp's folk...), as circles in tile units, hashed by tile. The user asked for solid objects (2026-10-05): the
## web let bodies walk through every prop. Paths are weighted round them, not walled off, so a grave never closes a road.
var posts := {}               # Vector2i -> Array of [Vector2 centre, float radius]
const POST_R := {
	"grave": 0.32, "cairn": 0.38, "brazier": 0.3, "stump": 0.36, "coffin": 0.42, "pillar": 0.45, "gibbet": 0.34,
	"bell": 0.45, "railing": 0.3, "rubble": 0.3,
	"chest": 0.42, "shrine": 0.45, "lantern": 0.34, "statue": 0.55, "altar": 0.55, "vendor": 0.3,
	"statue_saint": 0.5, "statue_angel": 0.5, "cage": 0.45, "cage2": 0.45, "tent": 0.9, "campfire": 0.42,
	"org_ribs": 0.4, "org_eye": 0.35}

static func rle(a: Array, n: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n)
	var i := 0
	var k := 0
	while k < a.size() - 1:
		var v := int(a[k])
		var c := int(a[k + 1])
		for j in c:
			if i < n:
				out[i] = v
			i += 1
		k += 2
	return out

static func hash2(x: int, y: int) -> float:
	var hh := (x * 374761393 + y * 668265263) & 0xffffffff
	hh = ((hh ^ (hh >> 13)) * 1274126177) & 0xffffffff
	return float((hh ^ (hh >> 16)) & 0xffffffff) / 4294967295.0

func load_zone(zid: String, zseed: int) -> void:
	id = zid
	seed = zseed
	d = Data.zone(zid, zseed)
	w = int(d["grid"]["w"])
	h = int(d["grid"]["h"])
	types = rle(d["grid"]["cells"], w * h)
	solid.resize(w * h)
	for i in w * h:
		solid[i] = 1 if SOLID_TYPES.has(int(types[i])) else 0
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in h:
		for x in w:
			if solid[y * w + x]:
				astar.set_point_solid(Vector2i(x, y), true)
	markers = d.get("markers", {})
	arrive = d.get("arrive", {})
	connections = d.get("connections", [])
	objects = d.get("objects", [])
	lanterns = markers.get("lanterns", [])
	_posts()
	floor_layer = Node2D.new()
	floor_layer.z_index = -50
	add_child(floor_layer)
	shadow_layer = Node2D.new()      # figures' shadows: over the ground and its flat pieces, under everything standing
	shadow_layer.z_index = -20
	add_child(shadow_layer)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	_ground()
	_scatter()
	_walls()
	_sprites()
	_lights()
	built.emit()

# ------------------------------------------------------------------ queries
func type_at(t: Vector2) -> int:
	var x := int(floor(t.x))
	var y := int(floor(t.y))
	if x < 0 or y < 0 or x >= w or y >= h:
		return 7
	return types[y * w + x]

func is_solid(t: Vector2) -> bool:
	var x := int(floor(t.x))
	var y := int(floor(t.y))
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	return solid[y * w + x] == 1

func blocks_sight(t: Vector2) -> bool:
	return SIGHT_TYPES.has(type_at(t))

## a body of radius r moving from p by v, sliding along solid tiles (the web moves x and y separately) and round posts
func move(p: Vector2, v: Vector2, r: float = 0.25) -> Vector2:
	var q := p
	var nx := Vector2(p.x + v.x, p.y)
	if not _blocked(nx, r, q):
		q.x = nx.x
	var ny := Vector2(q.x, q.y + v.y)
	if not _blocked(ny, r, q):
		q.y = ny.y
	if q == p and v.length_squared() > 1e-8:
		# stopped dead against a post: slide along its edge instead
		var hit = _post_hit(p + v, r, p)
		if hit != null:
			var n: Vector2 = (p - (hit[0] as Vector2)).normalized()
			var tv := v - n * v.dot(n)
			if tv.length_squared() > 1e-8 and not _blocked(p + tv, r, p):
				q = p + tv
	return q

## the circle's edge, eight points round it (four let a body cut a corner), and the posts
func _blocked(p: Vector2, r: float, from: Vector2 = Vector2.INF) -> bool:
	if is_solid(p):
		return true
	var k := r * 0.7071
	for o in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(k, k), Vector2(-k, k), Vector2(k, -k), Vector2(-k, -k)]:
		if is_solid(p + o):
			return true
	return _post_hit(p, r, from) != null

## the post a body of radius r at p would stand in; one it already stands in only stops it coming nearer
func _post_hit(p: Vector2, r: float, from: Vector2 = Vector2.INF):
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var a = posts.get(c + Vector2i(dx, dy))
			if a == null:
				continue
			for po in a:
				var rr: float = po[1] + r
				var d := p.distance_to(po[0])
				if d < rr and (from == Vector2.INF or d < from.distance_to(po[0]) - 0.0001):
					return po
	return null

func add_post(tp: Vector2, r: float) -> void:
	var c := Vector2i(int(floor(tp.x)), int(floor(tp.y)))
	if not posts.has(c):
		posts[c] = []
	posts[c].append([tp, r])
	if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and not astar.is_point_solid(c):
		astar.set_point_weight_scale(c, 6.0)

func _posts() -> void:
	posts.clear()
	for o in d.get("props", []):
		if POST_R.has(o.get("kind", "")):
			add_post(Vector2(o["x"], o["y"]), POST_R[o["kind"]])
	for o in d.get("objects", []):
		if POST_R.has(o.get("type", "")):
			add_post(Vector2(o["x"], o["y"]), POST_R[o["type"]])
	for o in d.get("decor", []):
		if POST_R.has(o.get("key", "")):
			add_post(Vector2(o["x"], o["y"]), POST_R[o["key"]])

## is there room for a body of radius r at p (tiles and posts)
func room_at(p: Vector2, r: float = 0.25) -> bool:
	return not _blocked(p, r)

func line_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) * 3.0))
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		if is_solid(q) or _post_hit(q, 0.15) != null:
			return false
	return true

func sight_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) * 3.0))
	for i in range(1, n):
		if blocks_sight(a.lerp(b, float(i) / n)):
			return false
	return true

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ai := Vector2i(clampi(int(a.x), 0, w - 1), clampi(int(a.y), 0, h - 1))
	var bi := Vector2i(clampi(int(b.x), 0, w - 1), clampi(int(b.y), 0, h - 1))
	if astar.is_point_solid(bi):
		bi = _nearest_open(bi)
	if astar.is_point_solid(ai):
		ai = _nearest_open(ai)
	var ids := astar.get_id_path(ai, bi, true)
	var out := PackedVector2Array()
	for c in ids:
		out.append(Vector2(c.x + 0.5, c.y + 0.5))
	if out.size() > 0 and not is_solid(b):
		out[out.size() - 1] = b
	return out

func _nearest_open(c: Vector2i) -> Vector2i:
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not astar.is_point_solid(q):
					return q
	return c

# ------------------------------------------------------------------ the ground
func _ground() -> void:
	# top-down LPC ground (world/topdown.gd); the class grid is kept for footstep sounds and the monk's ground reads
	var classes := rle(d["ground"]["classes"], w * h)
	ground_cls = classes
	ground_keys = d["ground"]["texKeys"]
	TopDown.ground(self, classes, ground_keys)

# ------------------------------------------------------------------ scatter
func _scatter() -> void:
	pass   # Godmarrow's scatter is its own painted art; the LPC props carry the litter for now

# ------------------------------------------------------------------ walls and cliffs
func _walls() -> void:
	TopDown.walls(self)

# ------------------------------------------------------------------ every drawn sprite (trees, rocks, props, decor)
func _sprites() -> void:
	TopDown.sprites(self)

var _lm_meta := {}
func _landmark_meta(key: String) -> Dictionary:
	if _lm_meta.is_empty():
		var f := FileAccess.open("res://art/landmarks/landmarks.json", FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				for k in j:
					_lm_meta[k] = j[k]
			elif j is Array:
				for e in j:
					_lm_meta[e.get("key", "")] = e
	var v = _lm_meta.get(key, _lm_meta.get(key.trim_prefix("lm_"), {}))
	return v if v is Dictionary else {}

# ------------------------------------------------------------------ lights
func _lights() -> void:
	for L in d.get("lights", []):
		var rgb: Array = String(L.get("rgb", "255,180,110")).split(",")
		var col := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
		var p: Vector2
		var rad := 3.0
		if L["type"] == "fire":
			p = Iso.to_screen(Vector2(L["x"], L["y"])) + Vector2(float(L.get("dxPx", 0)) * Iso.WPX, -float(L.get("heightPx", 0)) * Iso.WPX)
			rad = float(L.get("radius", 4.0))
		elif L["type"] == "raw":
			p = Iso.to_screen(Vector2(L["x"], L["y"]))
			rad = float(L.get("radiusPx", 40.0)) / 36.0
		else:
			p = Iso.to_screen(Vector2(L["x"], L["y"]))
			rad = float(L.get("radiusPx", 36.0)) / 36.0
		var a := float(L.get("a", 1.0))
		var fl := Lights.flicker(sorted, p, col, clampf(a * 0.45, 0.2, 1.3), rad * Iso.HX * 2.0 / 512.0 * 1.2, L["type"] == "fire")
		fl.set_meta("dark_skip", true)   # the dark layer draws these pools itself, from the data
		fl.enabled = false

func ambient_at(phase: float) -> Color:
	var arr: Array = d.get("ambient", {}).get("byPhase", [])
	if arr.is_empty():
		return Color(0.4, 0.42, 0.46)
	# the web blends the sky smoothly through the hour (ambient37: smoothstep of dayK); the export samples it every
	# 1/24 of the day, so blend between the two rows either side
	var i0 := 0
	for i in arr.size():
		if float(arr[i]["phase"]) <= phase:
			i0 = i
	var a0: Dictionary = arr[i0]
	var a1: Dictionary = arr[(i0 + 1) % arr.size()]
	var p0 := float(a0["phase"])
	var p1 := float(a1["phase"]) if i0 + 1 < arr.size() else 1.0 + float(arr[0]["phase"])
	var k := clampf((phase - p0) / maxf(0.0001, p1 - p0), 0.0, 1.0)
	var c0: Array = a0["rgb"]
	var c1: Array = a1["rgb"]
	return Color8(int(c0[0]), int(c0[1]), int(c0[2])).lerp(Color8(int(c1[0]), int(c1[1]), int(c1[2])), k)


## the wind's materials (shaders/sway.gdshader): young trees lean a little, cloth and cobwebs more, chains swing
var sway_mats := {}
var ground_cls = null        # the ground class per tile (for footsteps)
var ground_keys := {}

## what the ground is made of under a tile, as the feet hear it: wet | stone | leaf | ash
func surface_at(t: Vector2) -> String:
	var x := int(floor(t.x))
	var y := int(floor(t.y))
	if ground_cls == null or x < 0 or y < 0 or x >= w or y >= h:
		return "stone"
	var key: String = ground_keys.get(str(ground_cls[y * w + x]), "main")
	if key in ["water", "shallow", "bog", "mud"]:
		return "wet"
	if key in ["flags", "road", "crypt", "barrow", "bone", "arena"] or not d.get("outdoor", false):
		return "stone"
	var th: String = str(d.get("theme", ""))
	if th.contains("wood") or th.contains("root") or th.contains("fen"):
		return "leaf"
	return "ash"
func _sway_mat(key: String) -> ShaderMaterial:
	var kind := ""
	if key.contains("_sapling") or key.contains("_young"):
		kind = "tree"
	elif key.begins_with("p_cloth") or key.begins_with("p_cobweb") or key.begins_with("p_banner"):
		kind = "cloth"
	elif key.begins_with("p_chains") or key.begins_with("p_wallchain") or key.begins_with("p_gibbet") or key.begins_with("p_cage"):
		kind = "chain"
	if kind == "":
		return null
	if not sway_mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/sway.gdshader")
		m.set_shader_parameter("amp", {"tree": 5.0, "cloth": 9.0, "chain": 4.0}[kind])
		m.set_shader_parameter("speed", {"tree": 1.1, "cloth": 2.2, "chain": 1.6}[kind])
		sway_mats[kind] = m
	return sway_mats[kind]
