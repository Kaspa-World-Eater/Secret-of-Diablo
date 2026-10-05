extends Node2D
## Large open outdoor zone: procedural tiles, collision grid, pathfinding,
## temporary bone walls and the explored-map image used by the automap.

const TILE := 32
var W := 200
var H := 200
var zone := ""  # "" = procedural wilderness, else an imported zone in assets/zones/
var zone_level := 1
var zone_data := {}
var collision := {"solid_tiles": [], "solid_cells": [], "open_cells": [], "spawn": null}
var zone_layers: Array = []  # per layer PackedInt32Array of atlas indices (-1 empty)

enum T { GRASS0, GRASS1, GRASS2, GRASS3, FLOWERS, DIRT, WATER, TREE, ROCK, BRIDGE, CAMP, FOREST }
const TILE_COUNT := 12
const LPC_TERRAIN := "res://assets/world/terrain.png"
const LPC_PROPS := "res://assets/world/props.json"
# column offsets (in 32px tiles) of each autotile block inside terrain.png
const BLOCK_GRASS := 0
const BLOCK_DIRT := 6
const BLOCK_WATER := 9
const BRIDGE_TILE := Vector2i(12, 0)
const SOLID_TILES := [T.WATER, T.TREE, T.ROCK]
const BLOCK_PROJ_TILES := [T.TREE, T.ROCK]

var tiles := PackedByteArray()
var solid := PackedByteArray()
var explored := PackedByteArray()
var reachable_cells: Array[Vector2i] = []
var spawn_cell := Vector2i(100, 100)
var bone_cells := {}  # Vector2i -> expiry time
var astar := AStarGrid2D.new()
var tilemap: TileMapLayer
var bone_layer: Node2D
var map_image: Image
var map_texture: ImageTexture
var map_dirty := false
var time := 0.0
var _bone_check := 0.0


func generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var terrain := FastNoiseLite.new()
	terrain.seed = seed_value
	terrain.frequency = 0.03
	var forest := FastNoiseLite.new()
	forest.seed = seed_value + 1
	forest.frequency = 0.045
	var detail := FastNoiseLite.new()
	detail.seed = seed_value + 2
	detail.frequency = 0.15
	spawn_cell = Vector2i(W / 2, H / 2)

	tiles.resize(W * H)
	solid.resize(W * H)
	explored.resize(W * H)
	explored.fill(0)

	for y in H:
		for x in W:
			var t: int = T.GRASS0 + rng.randi_range(0, 3)
			var e := terrain.get_noise_2d(x, y)
			var f := forest.get_noise_2d(x, y)
			var d := detail.get_noise_2d(x, y)
			if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
				t = T.TREE
			elif e < -0.33:
				t = T.WATER
			elif f > 0.28:
				t = T.TREE
			elif f > 0.17:
				t = T.ROCK if rng.randf() < 0.06 else T.FOREST
			elif d > 0.45:
				t = T.FLOWERS
			elif d < -0.5:
				t = T.DIRT
			elif rng.randf() < 0.012:
				t = T.TREE
			elif rng.randf() < 0.008:
				t = T.ROCK
			tiles[y * W + x] = t

	# Winding dirt roads from the camp outward keep the zone connected (bridges over water).
	for r in 9:
		var ang := TAU * r / 9.0 + rng.randf_range(-0.25, 0.25)
		var base_dir := Vector2.from_angle(ang)
		var dir := base_dir
		var p := Vector2(spawn_cell)
		for step in 400:
			dir = (dir.rotated(rng.randf_range(-0.35, 0.35)) + base_dir * 0.25).normalized()
			p += dir
			var c := Vector2i(p.round())
			if c.x < 3 or c.y < 3 or c.x >= W - 4 or c.y >= H - 4:
				break
			for oy in 2:
				for ox in 2:
					var i := (c.y + oy) * W + (c.x + ox)
					if tiles[i] == T.WATER:
						tiles[i] = T.BRIDGE
					elif tiles[i] != T.BRIDGE:
						tiles[i] = T.DIRT

	# Camp clearing at the centre.
	for y in range(spawn_cell.y - 9, spawn_cell.y + 10):
		for x in range(spawn_cell.x - 9, spawn_cell.x + 10):
			var dd := Vector2(x - spawn_cell.x, y - spawn_cell.y).length()
			if dd <= 5.5:
				tiles[y * W + x] = T.CAMP
			elif dd <= 9.0 and tiles[y * W + x] in SOLID_TILES:
				tiles[y * W + x] = T.GRASS1

	_erode(T.WATER, [T.WATER, T.BRIDGE], T.GRASS1)
	# bridges only make sense over water
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := y * W + x
			if tiles[i] == T.BRIDGE and not (tiles[i - 1] == T.WATER or tiles[i + 1] == T.WATER \
					or tiles[i - W] == T.WATER or tiles[i + W] == T.WATER):
				tiles[i] = T.DIRT
	_erode(T.DIRT, [T.DIRT, T.BRIDGE, T.CAMP], T.GRASS1)

	for i in W * H:
		solid[i] = 1 if tiles[i] in SOLID_TILES else 0

	_flood_reachable()
	_build_astar()
	if FileAccess.file_exists(LPC_TERRAIN):
		_build_tilemap_lpc(rng)
	else:
		_build_tilemap(rng)
	_build_map_image()
	_make_bone_layer()


func _erode(kind: int, same: Array, into: int) -> void:
	## Removes 1-tile-wide strips so autotiled edges always have room to blend.
	for pass_i in 3:
		var changed := false
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var i := y * W + x
				if tiles[i] != kind:
					continue
				var n: bool = tiles[i - W] in same
				var s: bool = tiles[i + W] in same
				var w: bool = tiles[i - 1] in same
				var e: bool = tiles[i + 1] in same
				if (not n and not s) or (not w and not e):
					tiles[i] = into
					changed = true
		if not changed:
			break


func _make_bone_layer() -> void:
	bone_layer = Node2D.new()
	bone_layer.draw.connect(_draw_bones)


# ---------------------------------------------------------------- imported zones

static func zone_dir(z: String) -> String:
	return "res://assets/zones/%s/" % z


static func list_zones() -> Array:
	var out := []
	var d := DirAccess.open("res://assets/zones")
	if d:
		for n in d.get_directories():
			if FileAccess.file_exists(zone_dir(n) + "map.json"):
				out.append(n)
	out.sort()
	return out


func load_zone(z: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(zone_dir(z) + "map.json"))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("World: cannot read zone " + z)
		return false
	zone = z
	zone_data = data
	W = int(data["w"])
	H = int(data["h"])
	zone_level = int(data.get("level", 1))
	zone_layers.clear()
	for l in data["layers"]:
		zone_layers.append(PackedInt32Array(l))
	var cpath := zone_dir(z) + "collision.json"
	if FileAccess.file_exists(cpath):
		var c = JSON.parse_string(FileAccess.get_file_as_string(cpath))
		if typeof(c) == TYPE_DICTIONARY:
			collision.merge(c, true)
	# JSON numbers load as floats; keep everything as ints so lookups match
	for k in ["solid_cells", "open_cells"]:
		var fixed := []
		for v in collision[k]:
			fixed.append([int(v[0]), int(v[1])])
		collision[k] = fixed
	var st := []
	for t in collision["solid_tiles"]:
		st.append(int(t))
	collision["solid_tiles"] = st
	tiles.resize(W * H)
	solid.resize(W * H)
	explored.resize(W * H)
	explored.fill(0)
	_recompute_zone_solid()
	var sp = collision.get("spawn")
	spawn_cell = Vector2i(int(sp[0]), int(sp[1])) if sp != null else Vector2i(W / 2, H / 2)
	spawn_cell = nearest_walkable(spawn_cell, max(W, H))
	if spawn_cell.x < 0:
		spawn_cell = Vector2i(W / 2, H / 2)
	_flood_reachable()
	_build_astar()
	_build_zone_tilemaps()
	_build_map_image()
	_make_bone_layer()
	return true


func top_tile(c: Vector2i) -> int:
	for li in range(zone_layers.size() - 1, -1, -1):
		var t: int = zone_layers[li][c.y * W + c.x]
		if t >= 0:
			return t
	return -1


func cell_solid_by_rules(c: Vector2i) -> bool:
	var key := [c.x, c.y]
	if collision["open_cells"].has(key):
		return false
	if collision["solid_cells"].has(key):
		return true
	var st: Array = collision["solid_tiles"]
	for l in zone_layers:
		var t: int = l[c.y * W + c.x]
		if t >= 0 and st.has(t):
			return true
	return false


func _recompute_zone_solid() -> void:
	var st := {}
	for t in collision["solid_tiles"]:
		st[int(t)] = true
	var sc := {}
	for c in collision["solid_cells"]:
		sc[Vector2i(int(c[0]), int(c[1]))] = true
	var oc := {}
	for c in collision["open_cells"]:
		oc[Vector2i(int(c[0]), int(c[1]))] = true
	for y in H:
		for x in W:
			var i := y * W + x
			var c := Vector2i(x, y)
			var s := false
			if oc.has(c):
				s = false
			elif sc.has(c):
				s = true
			else:
				for l in zone_layers:
					if st.has(l[i]):
						s = true
						break
			solid[i] = 1 if s else 0
			tiles[i] = T.ROCK if s else T.GRASS0


func set_cell_solid(c: Vector2i, s: bool) -> void:
	## Live edit from the collision painter.
	if not in_bounds(c):
		return
	var i := c.y * W + c.x
	solid[i] = 1 if s else 0
	tiles[i] = T.ROCK if s else T.GRASS0
	astar.set_point_solid(c, s)


func refresh_zone_collision() -> void:
	_recompute_zone_solid()
	for y in H:
		for x in W:
			astar.set_point_solid(Vector2i(x, y), solid[y * W + x] == 1)
	_flood_reachable()


func save_zone_collision() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(zone_dir(zone) + "collision.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(collision, "\t"))
		f.close()


func _build_zone_tilemaps() -> void:
	var tp := int(zone_data["tile"])
	var cols := int(zone_data.get("cols", 32))
	var img := Image.load_from_file(ProjectSettings.globalize_path(zone_dir(zone) + "atlas.png"))
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tp, tp)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tp, tp)
	var count := int(zone_data["count"])
	for i in count:
		src.create_tile(Vector2i(i % cols, i / cols))
	ts.add_source(src, 0)
	for l in zone_layers:
		var tm := TileMapLayer.new()
		tm.tile_set = ts
		tm.scale = Vector2.ONE * (float(TILE) / tp)
		add_child(tm)
		for y in H:
			for x in W:
				var t: int = l[y * W + x]
				if t >= 0:
					tm.set_cell(Vector2i(x, y), 0, Vector2i(t % cols, t / cols))
		if tilemap == null:
			tilemap = tm


func _flood_reachable() -> void:
	var seen := PackedByteArray()
	seen.resize(W * H)
	seen.fill(0)
	var queue: Array[Vector2i] = [spawn_cell]
	seen[spawn_cell.y * W + spawn_cell.x] = 1
	var head := 0
	reachable_cells.clear()
	while head < queue.size():
		var c := queue[head]
		head += 1
		reachable_cells.append(c)
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + n
			if not in_bounds(nc):
				continue
			var i := nc.y * W + nc.x
			if seen[i] == 0 and solid[i] == 0:
				seen[i] = 1
				queue.append(nc)


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			if solid[y * W + x] == 1:
				astar.set_point_solid(Vector2i(x, y), true)


# ---------------------------------------------------------------- queries

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func center_of(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE * 0.5, TILE * 0.5)


func is_walkable_cell(c: Vector2i) -> bool:
	return in_bounds(c) and solid[c.y * W + c.x] == 0 and not bone_cells.has(c)


func is_walkable_px(p: Vector2) -> bool:
	return is_walkable_cell(cell_of(p))


func blocks_projectile_px(p: Vector2) -> bool:
	var c := cell_of(p)
	if not in_bounds(c):
		return true
	return tiles[c.y * W + c.x] in BLOCK_PROJ_TILES or bone_cells.has(c)


func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 12.0)
	for i in range(1, steps + 1):
		if not is_walkable_px(a + d * (float(i) / (steps + 1))):
			return false
	return true


func nearest_walkable(c: Vector2i, max_r: int) -> Vector2i:
	if is_walkable_cell(c):
		return c
	for r in range(1, max_r + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if abs(x) == r or abs(y) == r:
					var n := c + Vector2i(x, y)
					if is_walkable_cell(n):
						return n
	return Vector2i(-1, -1)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := cell_of(from)
	var b := nearest_walkable(cell_of(to), 4)
	if b.x < 0 or not is_walkable_cell(a):
		return PackedVector2Array()
	return astar.get_point_path(a, b)


func dist_tiles_from_spawn(p: Vector2) -> float:
	return Vector2(cell_of(p) - spawn_cell).length()


# ---------------------------------------------------------------- bone walls

func add_bones(cells: Array, duration: float) -> int:
	var placed := 0
	for c in cells:
		if not in_bounds(c) or solid[c.y * W + c.x] == 1:
			continue
		bone_cells[c] = time + duration
		astar.set_point_solid(c, true)
		placed += 1
	bone_layer.queue_redraw()
	return placed


func _process(delta: float) -> void:
	time += delta
	_bone_check -= delta
	if _bone_check <= 0.0 and not bone_cells.is_empty():
		_bone_check = 0.25
		var expired := []
		for c in bone_cells:
			if bone_cells[c] <= time:
				expired.append(c)
		for c in expired:
			bone_cells.erase(c)
			astar.set_point_solid(c, false)
		if not expired.is_empty():
			bone_layer.queue_redraw()


func _draw_bones() -> void:
	var outline := Color(0.25, 0.22, 0.18)
	var bone := Color(0.93, 0.9, 0.8)
	for c in bone_cells:
		var p := center_of(c)
		var h := hash(c)
		for k in 3:
			var o := Vector2(((h >> (k * 4)) & 15) - 7.5, ((h >> (k * 4 + 12)) & 15) - 7.5)
			var a := float((h >> (k * 3)) & 7) * 0.4
			var dvec := Vector2.from_angle(a) * 9.0
			bone_layer.draw_line(p + o - dvec, p + o + dvec, outline, 6.0)
			bone_layer.draw_line(p + o - dvec, p + o + dvec, bone, 3.5)
			bone_layer.draw_circle(p + o - dvec, 3.0, bone)
			bone_layer.draw_circle(p + o + dvec, 3.0, bone)
		bone_layer.draw_circle(p + Vector2(0, -6), 6.0, outline)
		bone_layer.draw_circle(p + Vector2(0, -6), 5.0, bone)
		bone_layer.draw_circle(p + Vector2(-2, -6), 1.3, outline)
		bone_layer.draw_circle(p + Vector2(2, -6), 1.3, outline)


# ---------------------------------------------------------------- automap

func _map_color(t: int) -> Color:
	if zone != "":
		return Color(0, 0, 0)
	match t:
		T.WATER: return Color(0.2, 0.35, 0.75)
		T.TREE: return Color(0.08, 0.25, 0.1)
		T.ROCK: return Color(0.45, 0.45, 0.45)
		T.DIRT, T.BRIDGE: return Color(0.6, 0.48, 0.3)
		T.CAMP: return Color(0.85, 0.8, 0.6)
		T.FOREST: return Color(0.2, 0.38, 0.18)
	return Color(0.28, 0.5, 0.24)


func _zone_map_color(c: Vector2i) -> Color:
	var t := top_tile(c)
	if t < 0:
		return Color(0, 0, 0, 0)
	var col: Array = zone_data["colors"][t]
	var cc := Color(col[0], col[1], col[2])
	return cc.darkened(0.35) if solid[c.y * W + c.x] == 1 else cc


func _build_map_image() -> void:
	map_image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0, 0, 0, 0))
	map_texture = ImageTexture.create_from_image(map_image)


func reveal(p: Vector2, r: int) -> void:
	var c := cell_of(p)
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var i := y * W + x
			if explored[i] == 1:
				continue
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) > r * r:
				continue
			explored[i] = 1
			map_image.set_pixel(x, y, _zone_map_color(Vector2i(x, y)) if zone != "" else _map_color(tiles[i]))
			map_dirty = true
	if map_dirty:
		map_texture.update(map_image)
		map_dirty = false


# ---------------------------------------------------------------- LPC art

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


func _is(c: Vector2i, kinds: Array) -> bool:
	if not in_bounds(c):
		return true
	return tiles[c.y * W + c.x] in kinds


func _autotile(c: Vector2i, kinds: Array) -> Vector2i:
	## LPC terrain block layout: rows 0-1 isolated bits + inner corners,
	## rows 2-4 the 3x3 outer edge set, row 5 plain centre variants.
	var n := _is(c + Vector2i(0, -1), kinds)
	var s := _is(c + Vector2i(0, 1), kinds)
	var w := _is(c + Vector2i(-1, 0), kinds)
	var e := _is(c + Vector2i(1, 0), kinds)
	if not n and not w: return Vector2i(0, 2)
	if not n and not e: return Vector2i(2, 2)
	if not s and not w: return Vector2i(0, 4)
	if not s and not e: return Vector2i(2, 4)
	if not n: return Vector2i(1, 2)
	if not s: return Vector2i(1, 4)
	if not w: return Vector2i(0, 3)
	if not e: return Vector2i(2, 3)
	if not _is(c + Vector2i(1, 1), kinds): return Vector2i(1, 0)
	if not _is(c + Vector2i(-1, 1), kinds): return Vector2i(2, 0)
	if not _is(c + Vector2i(1, -1), kinds): return Vector2i(1, 1)
	if not _is(c + Vector2i(-1, -1), kinds): return Vector2i(2, 1)
	var h := hash(c) % 10
	return Vector2i(1, 3) if h < 6 else Vector2i(h % 3, 5)


func _build_tilemap_lpc(rng: RandomNumberGenerator) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = _tex(LPC_TERRAIN)
	src.texture_region_size = Vector2i(TILE, TILE)
	var cols := src.texture.get_width() / TILE
	var rows := src.texture.get_height() / TILE
	for y in rows:
		for x in cols:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	var ground := TileMapLayer.new()
	var dirt := TileMapLayer.new()
	var water := TileMapLayer.new()
	var bridge := TileMapLayer.new()
	for l in [ground, dirt, water, bridge]:
		l.tile_set = ts
		add_child(l)
	tilemap = ground
	var water_kinds := [T.WATER, T.BRIDGE]
	var dirt_kinds := [T.DIRT, T.CAMP, T.BRIDGE]
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var t := tiles[y * W + x]
			var g := rng.randi_range(0, 9)
			ground.set_cell(c, 0, Vector2i(BLOCK_GRASS + (0 if g < 6 else g % 3), 5))
			if t in water_kinds:
				water.set_cell(c, 0, _autotile(c, water_kinds) + Vector2i(BLOCK_WATER, 0))
			if t == T.DIRT or t == T.CAMP:
				dirt.set_cell(c, 0, _autotile(c, dirt_kinds) + Vector2i(BLOCK_DIRT, 0))
			if t == T.BRIDGE:
				bridge.set_cell(c, 0, BRIDGE_TILE)


func build_props(parent: Node2D) -> void:
	## Trees and rocks as y-sorted sprites so units walk behind canopies.
	if zone != "" or not FileAccess.file_exists(LPC_PROPS):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(LPC_PROPS))
	var trees := []
	var rocks := []
	for p in data["props"]:
		var r: Array = p["rect"]
		if p["kind"] == "tree" and r[2] <= 130:
			trees.append(p)
		elif p["kind"] == "rock":
			rocks.append(p)
	var tree_tex := _tex("res://assets/world/trees.png")
	var rock_tex := _tex("res://assets/world/rocks.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spawn_cell)
	var taken := PackedByteArray()
	taken.resize(W * H)
	for y in H:
		for x in W:
			var i := y * W + x
			var t := tiles[i]
			if t == T.TREE and taken[i] == 0:
				var p: Dictionary = trees[rng.randi() % trees.size()]
				var s := _prop_sprite(tree_tex, p["rect"], rng.randf_range(0.8, 1.0))
				s.position = center_of(Vector2i(x, y)) + Vector2(rng.randf_range(-6, 6) + 16, rng.randf_range(-4, 4) + 16)
				s.modulate = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.15))
				parent.add_child(s)
				for oy in 2:
					for ox in 2:
						if x + ox < W and y + oy < H:
							taken[(y + oy) * W + x + ox] = 1
			elif t == T.ROCK:
				var p: Dictionary = rocks[rng.randi() % rocks.size()]
				var s := _prop_sprite(rock_tex, p["rect"], 1.0)
				s.position = center_of(Vector2i(x, y)) + Vector2(0, 10)
				parent.add_child(s)


func _prop_sprite(tex: Texture2D, r: Array, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.offset = Vector2(0, -r[3] / 2.0 + 10.0)
	s.scale = Vector2(sc, sc)
	return s


# ---------------------------------------------------------------- tile art

func _build_tilemap(rng: RandomNumberGenerator) -> void:
	var img := Image.create(TILE * TILE_COUNT, TILE, false, Image.FORMAT_RGBA8)
	for k in TILE_COUNT:
		_paint_tile(img, k, rng)
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for k in TILE_COUNT:
		src.create_tile(Vector2i(k, 0))
	ts.add_source(src, 0)
	tilemap = TileMapLayer.new()
	tilemap.tile_set = ts
	add_child(tilemap)
	for y in H:
		for x in W:
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(tiles[y * W + x], 0))


func _px(img: Image, k: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < TILE and y < TILE:
		img.set_pixel(k * TILE + x, y, c)


func _fill(img: Image, k: int, c: Color) -> void:
	for y in TILE:
		for x in TILE:
			_px(img, k, x, y, c)


func _speckle(img: Image, k: int, rng: RandomNumberGenerator, cols: Array, n: int) -> void:
	for i in n:
		_px(img, k, rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), cols[rng.randi_range(0, cols.size() - 1)])


func _disc(img: Image, k: int, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in TILE:
		for x in TILE:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, k, x, y, c)


func _grass(img: Image, k: int, rng: RandomNumberGenerator, base: Color) -> void:
	_fill(img, k, base)
	_speckle(img, k, rng, [base.darkened(0.12), base.lightened(0.1), base.darkened(0.06)], 90)
	for i in 7:
		var x := rng.randi_range(1, TILE - 2)
		var y := rng.randi_range(2, TILE - 2)
		_px(img, k, x, y, base.darkened(0.25))
		_px(img, k, x, y - 1, base.darkened(0.15))
		_px(img, k, x + 1, y - 2, base.lightened(0.15))


func _paint_tile(img: Image, k: int, rng: RandomNumberGenerator) -> void:
	var grass := Color(0.36, 0.66, 0.28)
	match k:
		T.GRASS0, T.GRASS1, T.GRASS2, T.GRASS3:
			_grass(img, k, rng, grass.lightened(0.02 * (k - 1)))
		T.FLOWERS:
			_grass(img, k, rng, grass)
			for i in 6:
				var x := rng.randi_range(2, TILE - 3)
				var y := rng.randi_range(2, TILE - 3)
				var fc: Color = [Color(1, 1, 1), Color(1, 0.6, 0.75), Color(1, 0.9, 0.3)][i % 3]
				_px(img, k, x, y, fc)
				_px(img, k, x + 1, y, fc)
				_px(img, k, x, y + 1, fc)
				_px(img, k, x + 1, y + 1, fc.darkened(0.2))
		T.DIRT:
			var dirt := Color(0.68, 0.53, 0.34)
			_fill(img, k, dirt)
			_speckle(img, k, rng, [dirt.darkened(0.12), dirt.lightened(0.1), dirt.darkened(0.25)], 140)
		T.WATER:
			var water := Color(0.22, 0.47, 0.8)
			_fill(img, k, water)
			_speckle(img, k, rng, [water.darkened(0.08), water.lightened(0.06)], 60)
			for i in 3:
				var y := 6 + i * 10
				var x0 := rng.randi_range(2, 14)
				for x in range(x0, x0 + 9):
					_px(img, k, x, y + int(sin(x * 0.7) * 1.2), Color(0.55, 0.78, 0.95))
		T.TREE:
			var floor_c := Color(0.2, 0.42, 0.2)
			_fill(img, k, floor_c)
			_speckle(img, k, rng, [floor_c.darkened(0.15)], 60)
			_disc(img, k, 16, 29, 4, 3, Color(0.1, 0.18, 0.08))
			for y in range(22, 30):
				for x in range(14, 19):
					_px(img, k, x, y, Color(0.42, 0.27, 0.15) if x < 18 else Color(0.3, 0.18, 0.1))
			_disc(img, k, 16, 13, 15.5, 12.5, Color(0.06, 0.2, 0.08))
			_disc(img, k, 16, 13, 14, 11, Color(0.14, 0.46, 0.18))
			_disc(img, k, 13, 10, 9, 7, Color(0.2, 0.56, 0.22))
			_disc(img, k, 11, 7, 4, 3, Color(0.35, 0.7, 0.3))
			_speckle(img, k, rng, [Color(0.1, 0.38, 0.14)], 25)
		T.ROCK:
			_grass(img, k, rng, grass)
			_disc(img, k, 16, 19, 12, 9, Color(0.2, 0.2, 0.22))
			_disc(img, k, 16, 18, 11, 8, Color(0.55, 0.55, 0.58))
			_disc(img, k, 13, 15, 6, 4, Color(0.72, 0.72, 0.75))
		T.BRIDGE:
			var wood := Color(0.6, 0.42, 0.22)
			_fill(img, k, wood)
			for y in TILE:
				if y % 8 == 7:
					for x in TILE:
						_px(img, k, x, y, wood.darkened(0.4))
			_speckle(img, k, rng, [wood.darkened(0.15), wood.lightened(0.1)], 50)
		T.CAMP:
			var stone := Color(0.74, 0.7, 0.58)
			_fill(img, k, stone)
			_speckle(img, k, rng, [stone.darkened(0.1), stone.lightened(0.08)], 80)
			for i in TILE:
				_px(img, k, i, 0, stone.darkened(0.3))
				_px(img, k, 0, i, stone.darkened(0.3))
				_px(img, k, i, 16, stone.darkened(0.2))
				_px(img, k, 16, (i + 8) % TILE, stone.darkened(0.2))
		T.FOREST:
			var fc := Color(0.25, 0.5, 0.22)
			_grass(img, k, rng, fc)
			_speckle(img, k, rng, [Color(0.5, 0.4, 0.2), Color(0.18, 0.36, 0.15)], 30)
