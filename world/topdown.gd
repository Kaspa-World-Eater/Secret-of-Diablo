extends RefCounted
## Dresses a zone in the top-down Secret of Mana view with free LPC art (assets/world, built by
## tools/build_lpc_world.gd): autotiled ground, cliffs and walls as tiles, and every exported sprite (trees, graves,
## rocks, props) as an LPC prop standing on its tile. The zone data (grid, walls, sprite list) is Godmarrow's own.

const TERRAIN := "res://assets/world/terrain.png"
const TERRAIN_JSON := "res://assets/world/terrain.json"
const PROPS := "res://assets/world/props.png"
const PROPS_JSON := "res://assets/world/props.json"
const PX := 32.0                       # LPC tile size
const SCALE := Iso.S / PX              # LPC px -> screen

# Godmarrow ground keys -> LPC autotile block
const GROUND := {"main": "grass", "dirt": "dirt", "road": "dirt", "mud": "dirt2", "bog": "watergrass",
	"water": "water", "shallow": "watergrass", "flags": "tile:flags", "crypt": "tile:crypt_floor",
	"barrow": "tile:crypt_floor", "bone": "tile:flags", "arena": "tile:crypt_floor"}
# the grimdark grade of each land: the LPC colours pulled toward Godmarrow's muddy palette
const LAND_TINT := {"moor": Color(0.72, 0.74, 0.62), "heath": Color(0.78, 0.7, 0.58), "fen": Color(0.6, 0.7, 0.62),
	"wood": Color(0.66, 0.74, 0.6), "crypt": Color(0.62, 0.62, 0.66), "barrow": Color(0.66, 0.64, 0.6),
	"bone": Color(0.78, 0.74, 0.66), "ridge": Color(0.72, 0.72, 0.7)}
# tree species -> LPC tree tone
const TONE := {"ashoak": "dead", "charpine": "dead", "thorn": "dead", "mourncypress": "pale", "yew": "brown",
	"oldgrowth": "green", "bogcypress": "brown", "willow": "green"}

static var _terrain: Dictionary = {}
static var _props: Dictionary = {}
static var _tex: Dictionary = {}


static func _load() -> void:
	if not _terrain.is_empty():
		return
	_terrain = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN_JSON))
	_props = JSON.parse_string(FileAccess.get_file_as_string(PROPS_JSON))
	_tex["terrain"] = load(TERRAIN)
	_tex["props"] = load(PROPS)


static func tint(z) -> Color:
	return LAND_TINT.get(String(z.d.get("land", "moor")), Color(0.72, 0.72, 0.68))


static var _grades := {}
static var _grade_base := {}   # key -> [desat, tint] at night (the grimdark grade)
static var _day := -1.0


## (Secret of Diablo) the grade by the hour: Secret of Mana's colour by day, Godmarrow's grim grade by night
## (world/dark_layer.gd calls it each frame with the day's weight, 1 noon .. 0 night; dungeons pass 0)
static func daylight(dk: float) -> void:
	if absf(dk - _day) < 0.005:
		return
	_day = dk
	for key in _grades:
		var b: Array = _grade_base[key]
		var m: ShaderMaterial = _grades[key]
		m.set_shader_parameter("desat", lerpf(b[0], b[0] * 0.6, dk))
		m.set_shader_parameter("tint", (b[1] as Color).lerp(Color(0.96, 0.95, 0.9), dk * 0.75))

static func grade(z, desat: float = 0.42, lift: float = 0.0) -> ShaderMaterial:
	## the shared grimdark grade material for this land (one per land and strength, so sprites still batch)
	var key := "%s_%.2f_%.2f" % [z.d.get("land", "moor"), desat, lift]
	if not _grades.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/grade.gdshader")
		m.set_shader_parameter("desat", desat)
		m.set_shader_parameter("tint", tint(z).lightened(lift))
		_grades[key] = m
		_grade_base[key] = [desat, tint(z).lightened(lift)]
		if _day >= 0.0:
			var dk := _day
			_day = -1.0
			daylight(dk)
	return _grades[key]


# ---------------------------------------------------------------- ground

static func ground(z, classes: PackedByteArray, tex_keys: Dictionary) -> void:
	_load()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	var tex: Texture2D = _tex["terrain"]
	src.texture = tex
	src.texture_region_size = Vector2i(32, 32)
	for y in tex.get_height() / 32:
		for x in tex.get_width() / 32:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	var keys := PackedStringArray()
	keys.resize(z.w * z.h)
	for i in z.w * z.h:
		keys[i] = GROUND.get(String(tex_keys.get(str(classes[i]), "main")), "grass")
	var blocks: Dictionary = _terrain["block"]
	var holder := Node2D.new()
	holder.z_index = -100
	z.add_child(holder)
	# base grass everywhere, then each other ground kind autotiled over it, in this order
	var order := ["grass", "tile:flags", "tile:crypt_floor", "dirt", "dirt2", "watergrass", "water"]
	var singles: Dictionary = _terrain["tile"]
	for kind in order:
		var layer := TileMapLayer.new()
		layer.tile_set = ts
		layer.scale = Vector2(SCALE, SCALE)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.material = grade(z)
		holder.add_child(layer)
		var bx: int = blocks.get(kind, 0)
		for y in z.h:
			for x in z.w:
				var c := Vector2i(x, y)
				if kind == "grass":
					var hv := Zone.hash2(x, y)
					layer.set_cell(c, 0, Vector2i(bx + (0 if hv < 0.6 else int(hv * 7.0) % 3), 5))
				elif kind.begins_with("tile:") and keys[y * z.w + x] == kind:
					var at: Array = singles.get(kind.substr(5), [0, 0])
					layer.set_cell(c, 0, Vector2i(at[0], at[1]))
				elif keys[y * z.w + x] == kind:
					var at := _autotile(keys, z.w, z.h, c, kind)
					if at.x >= 0:
						layer.set_cell(c, 0, at + Vector2i(bx, 0))


static func _same(keys: PackedStringArray, w: int, h: int, c: Vector2i, kind: String) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	return keys[c.y * w + c.x] == kind


static func _autotile(keys: PackedStringArray, w: int, h: int, c: Vector2i, kind: String) -> Vector2i:
	## LPC terrain block: rows 0-1 inner corners, rows 2-4 the 3x3 edge set, row 5 plain fill.
	var n := _same(keys, w, h, c + Vector2i(0, -1), kind)
	var s := _same(keys, w, h, c + Vector2i(0, 1), kind)
	var wv := _same(keys, w, h, c + Vector2i(-1, 0), kind)
	var e := _same(keys, w, h, c + Vector2i(1, 0), kind)
	if (not n and not s) or (not wv and not e):
		return Vector2i(-1, -1)   # a one-tile sliver: left as the ground beneath (LPC edges need two tiles)
	if not n and not wv: return Vector2i(0, 2)
	if not n and not e: return Vector2i(2, 2)
	if not s and not wv: return Vector2i(0, 4)
	if not s and not e: return Vector2i(2, 4)
	if not n: return Vector2i(1, 2)
	if not s: return Vector2i(1, 4)
	if not wv: return Vector2i(0, 3)
	if not e: return Vector2i(2, 3)
	if not _same(keys, w, h, c + Vector2i(1, 1), kind): return Vector2i(1, 0)
	if not _same(keys, w, h, c + Vector2i(-1, 1), kind): return Vector2i(2, 0)
	if not _same(keys, w, h, c + Vector2i(1, -1), kind): return Vector2i(1, 1)
	if not _same(keys, w, h, c + Vector2i(-1, -1), kind): return Vector2i(2, 1)
	var hv := Zone.hash2(c.x * 3, c.y * 7)
	return Vector2i(1, 3) if hv < 0.6 else Vector2i(int(hv * 9.0) % 3, 5)


# ---------------------------------------------------------------- walls

static func walls(z) -> void:
	_load()
	var info: Dictionary = z.d["walls"]["info"]
	var layer := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	var tex: Texture2D = _tex["terrain"]
	src.texture = tex
	src.texture_region_size = Vector2i(32, 32)
	for y in tex.get_height() / 32:
		for x in tex.get_width() / 32:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	layer.tile_set = ts
	layer.scale = Vector2(SCALE, SCALE)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = -40
	layer.material = grade(z)
	z.add_child(layer)
	var tiles: Dictionary = _terrain["tile"]
	for c in z.d["walls"]["cells"]:
		if int(c[3]) != 1:
			continue
		var x := int(c[0])
		var y := int(c[1])
		var t := int(c[2])
		var builder: String = String(info.get(str(t), {}).get("builder", "cliff"))
		var tp := Vector2(x + 0.5, y + 0.5)
		match t:
			3:
				_prop(z, "rock", tp, hash(Vector2i(x, y)), 1.0)
			9:
				_prop(z, "statue", tp, hash(Vector2i(x, y)), 1.0)
			10:
				_prop(z, "palisade", tp, hash(Vector2i(x, y)), 1.0)
			15:
				_prop(z, "ruin" if Zone.hash2(x, y) < 0.5 else "stonepile", tp, hash(Vector2i(x, y)), 1.0)
			8:
				pass   # fog: the dark layer and atmosphere carry it
			_:
				# cliffs and dungeon walls: a face where the wall drops toward the viewer, a top elsewhere
				var below: int = z.type_at(Vector2(x + 0.5, y + 1.5))
				var face: bool = not (below in [5, 7])
				var dungeon := builder.begins_with("dungeon_wall")
				var key := ("wall_" if dungeon else "cliff_") + ("face" if face else "top")
				var at: Array = tiles.get(key, [0, 0])
				layer.set_cell(Vector2i(x, y), 0, Vector2i(at[0], at[1]))


# ---------------------------------------------------------------- sprites

static func category(key: String) -> Array:
	## [category, scale]: the LPC prop that stands in for an exported sprite key
	if key.begins_with("sp_"):
		var parts := key.split("_")
		var species: String = parts[1] if parts.size() > 1 else "ashoak"
		var stage: String = parts[2] if parts.size() > 2 else "mature"
		var tone: String = TONE.get(species, "dead")
		match stage:
			"mature", "ancient", "dying", "widow":
				return ["tree_%s_big" % tone, 1.0 if stage != "ancient" else 1.25]
			"young", "dead":
				return ["tree_%s_mid" % tone, 1.0]
			_:
				return ["tree_%s_small" % tone, 0.9]
	var rules := [["grave", "grave"], ["coffin", "grave"], ["cairn", "stonepile"], ["rubble", "stonepile"], ["rkf", "stonepile"],
		["rk", "rock"], ["skull", "stonepile"], ["bones", "stonepile"], ["shrub", "tree_dead_small"], ["stump", "tree_dead_small"],
		["railing", "fence"], ["candle", "lantern"], ["offering", "lantern"], ["crows", "lantern"], ["sconce", "lantern"],
		["brazier", "lantern"], ["lantern", "lantern"], ["campfire", "campfire"], ["tent", "tent"], ["gibbet", "gallows"],
		["cage", "gallows"], ["statue", "statue"], ["pillar", "statue"], ["plo", "statue"], ["plc", "statue"], ["plw", "statue"],
		["arch", "ruin"], ["gate", "fence"], ["bell", "gallows"], ["shrine", "fountain"], ["chest", "chest"], ["well", "well"],
		["lm_", "statue"]]
	for r in rules:
		if key.contains(r[0]):
			return [r[1], 1.0]
	return ["", 1.0]   # cloth, cobwebs, chains, fungus, flesh: not drawn yet


static func sprites(z) -> void:
	_load()
	for s in z.d.get("sprites", []):
		var key: String = s["key"]
		var cat: Array = category(key)
		if cat[0] == "":
			continue
		var tp := Vector2(float(s["x"]), float(s["y"]))
		var node := _prop(z, cat[0], tp, hash(key + str(tp)), float(cat[1]) * float(s.get("scale", 1.0)))
		if node:
			node.set_meta("item", s.get("item", ""))
			if bool(s.get("flip", false)):
				(node.get_child(0) as Sprite2D).flip_h = true


static func _prop(z, cat: String, tp: Vector2, h: int, sc: float) -> Node2D:
	var list: Array = _props.get(cat, [])
	if list.is_empty():
		return null
	var e: Dictionary = list[absi(h) % list.size()]
	var r: Array = e["r"]
	var foot: Array = e["foot"]
	var holder := Node2D.new()
	holder.position = Iso.to_screen(tp)
	var sp := Sprite2D.new()
	sp.texture = _tex["props"]
	sp.region_enabled = true
	sp.region_rect = Rect2(r[0], r[1], r[2], r[3])
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.offset = Vector2(-float(foot[0]), -float(foot[1]))
	sp.scale = Vector2(SCALE * sc, SCALE * sc)
	sp.material = grade(z, 0.35, 0.12)
	holder.add_child(sp)
	z.sorted.add_child(holder)
	return holder
