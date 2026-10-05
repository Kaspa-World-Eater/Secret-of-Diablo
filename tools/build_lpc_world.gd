extends SceneTree
## Builds the top-down world art from free LPC packs:
##   assets/world/terrain.png   32 px tiles: LPC autotile blocks + wall / floor tiles (layout in terrain.json)
##   assets/world/props.png     every prop cut out of the source sheets, packed
##   assets/world/props.json    {category: [{r: [x,y,w,h], foot: [x,y]}]}
##
##   LPC_SRC=/path/to/packs godot --headless --path . --script res://tools/build_lpc_world.gd
## Sources and credits: CREDITS.md.

var src := ""
var props := {}       # category -> [Image]


func _init() -> void:
	src = OS.get_environment("LPC_SRC")
	if src == "" or not DirAccess.dir_exists_absolute(src):
		push_error("Set LPC_SRC")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world"))
	_terrain()
	_trees()
	_decorations()
	_pack()
	quit()


func _img(path: String) -> Image:
	var img := Image.load_from_file(path)
	if img:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _tiles(n: String) -> Image:
	return _img(src + "/lpc_base_assets/LPC Base Assets/tiles/" + n)


# ---------------------------------------------------------------- terrain

func _terrain() -> void:
	# autotile blocks (96x192, LPC layout) side by side, then single tiles in the last column
	var blocks := ["grass.png", "dirt.png", "dirt2.png", "water.png", "watergrass.png"]
	var atlas := Image.create(96 * blocks.size() + 64, 192, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var layout := {"block": {}, "tile": {}}
	for i in blocks.size():
		var b := _tiles(blocks[i])
		if b == null:
			continue
		atlas.blit_rect(b, Rect2i(0, 0, mini(96, b.get_width()), mini(192, b.get_height())), Vector2i(i * 96, 0))
		layout["block"][blocks[i].get_basename()] = i * 3
	var col := blocks.size() * 3
	var mountains := _tiles("mountains.png")
	var fence := _img(src + "/deco/decoration_medieval/fence_medieval.png")
	var bridges := _tiles("bridges.png")
	var floors := _tiles("castlefloors_outside.png")
	var singles := {
		"cliff_face": [mountains, Rect2i(200, 70, 32, 32)],
		"cliff_top": [mountains, Rect2i(200, 20, 32, 32)],
		"wall_face": [fence, Rect2i(16, 660, 32, 32)],
		"wall_top": [fence, Rect2i(100, 650, 32, 32)],
		"bridge": [bridges, Rect2i(112, 140, 32, 32)],
		"flags": [floors, Rect2i(40, 8, 32, 32)],
		"crypt_floor": [floors, Rect2i(40, 104, 32, 32)],
	}
	var r := 0
	for k in singles:
		var e: Array = singles[k]
		if e[0] == null:
			continue
		var x := col + (r % 2)
		var y := r / 2
		atlas.blit_rect(e[0], e[1], Vector2i(x * 32, y * 32))
		layout["tile"][k] = [x, y]
		r += 1
	atlas.save_png(ProjectSettings.globalize_path("res://assets/world/terrain.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://assets/world/terrain.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(layout, "\t"))
	f.close()
	print("  terrain: ", layout)


# ---------------------------------------------------------------- props

func _add(cat: String, img: Image) -> void:
	if not props.has(cat):
		props[cat] = []
	props[cat].append(img)


func _trees() -> void:
	var sheets := {"dead": "trees-dead.png", "brown": "trees-brown.png", "pale": "trees-pale.png", "green": "trees-green.png"}
	for tone in sheets:
		var img := _img(src + "/lpc-trees/lpc-trees/" + sheets[tone])
		if img == null:
			continue
		for r in _components(img, Rect2i(0, 0, img.get_width(), img.get_height()), 1):
			var h: int = r.size.y
			if r.size.x > 160 or h > 200 or r.size.x < 8:
				continue
			var size := "big" if h >= 110 else ("mid" if h >= 56 else "small")
			if size == "small" and (h < 14 or _boxy(img, r)):
				continue
			_add("tree_%s_%s" % [tone, size], img.get_region(r))


func _boxy(img: Image, r: Rect2i) -> bool:
	## the trunk-segment pieces on the tree sheets: narrow solid rectangles, not stumps
	var solid := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a > 0.5:
				solid += 1
	return float(solid) / float(r.size.x * r.size.y) > 0.82


func _decorations() -> void:
	var deco := _img(src + "/deco/decoration_medieval/decorations-medieval.png")
	var fence := _img(src + "/deco/decoration_medieval/fence_medieval.png")
	# regions of the decorations sheet, in its own pixels
	var regions := {
		"grave": Rect2i(0, 0, 170, 285), "statue": Rect2i(0, 285, 170, 75), "lantern": Rect2i(380, 0, 132, 300),
		"fountain": Rect2i(0, 500, 200, 135), "well": Rect2i(0, 415, 100, 75), "gallows": Rect2i(0, 1300, 135, 170),
		"campfire": Rect2i(255, 1490, 130, 55), "tent": Rect2i(0, 1600, 512, 240), "cart": Rect2i(190, 520, 100, 70),
	}
	for cat in regions:
		for r in _components(deco, regions[cat], 2):
			if r.size.x >= 10 and r.size.y >= 10:
				_add(cat, deco.get_region(r))
	var fregions := {"fence": Rect2i(0, 0, 380, 160), "palisade": Rect2i(0, 390, 512, 250), "ruin": Rect2i(255, 672, 257, 70),
		"stonepile": Rect2i(190, 350, 100, 30)}
	for cat in fregions:
		for r in _components(fence, fregions[cat], 1):
			if r.size.x >= 8 and r.size.y >= 12:
				_add(cat, fence.get_region(r))
	var rock := _tiles("rock.png")
	_add("rock", rock.get_region(Rect2i(0, 0, 32, 32)))
	_add("rock", rock.get_region(Rect2i(32, 0, 32, 32)))
	var chests := _tiles("chests.png")
	if chests:
		_add("chest", chests.get_region(Rect2i(0, 0, 32, 32)))
	var barrel := _tiles("barrel.png")
	if barrel:
		_add("barrel", barrel.get_region(Rect2i(0, 0, barrel.get_width(), barrel.get_height())))


func _pack() -> void:
	# simple shelf packing into a 2048-wide sheet
	var W := 2048
	var x := 0
	var y := 0
	var shelf := 0
	var placed := []
	var cats := props.keys()
	cats.sort()
	for cat in cats:
		for img in props[cat]:
			var w: int = img.get_width()
			var h: int = img.get_height()
			if x + w > W:
				x = 0
				y += shelf + 1
				shelf = 0
			placed.append([cat, img, Vector2i(x, y)])
			x += w + 1
			shelf = maxi(shelf, h)
	var H := y + shelf + 1
	var sheet := Image.create(W, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var out := {}
	for p in placed:
		var img: Image = p[1]
		var at: Vector2i = p[2]
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		if not out.has(p[0]):
			out[p[0]] = []
		# foot: bottom centre, nudged up past the soft ground shadow some pieces carry
		out[p[0]].append({"r": [at.x, at.y, img.get_width(), img.get_height()],
			"foot": [img.get_width() / 2, img.get_height() - _shadow_rows(img)]})
	sheet.save_png(ProjectSettings.globalize_path("res://assets/world/props.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://assets/world/props.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	var counts := {}
	for c in out:
		counts[c] = out[c].size()
	print("  props: ", counts)


func _shadow_rows(img: Image) -> int:
	## rows at the bottom that are only the pale grey ground shadow (not part of the trunk)
	var n := 0
	for yy in range(img.get_height() - 1, max(0, img.get_height() - 30), -1):
		var solid := 0
		for xx in img.get_width():
			var p := img.get_pixel(xx, yy)
			if p.a > 0.5 and not (absf(p.r - p.g) < 0.05 and absf(p.g - p.b) < 0.05 and p.r > 0.6):
				solid += 1
		if solid > 2:
			break
		n += 1
	return n


func _components(img: Image, area: Rect2i, gap: int) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes := []
	for y in range(area.position.y, mini(h, area.end.y)):
		for x in range(area.position.x, mini(w, area.end.x)):
			if seen[y * w + x] == 1 or img.get_pixel(x, y).a < 0.1 or _is_bg(img.get_pixel(x, y)):
				continue
			var r := Rect2i(x, y, 0, 0)
			var stack := [Vector2i(x, y)]
			seen[y * w + x] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				r = r.expand(p)
				for dy in range(-gap, gap + 1):
					for dx in range(-gap, gap + 1):
						var q := Vector2i(p.x + dx, p.y + dy)
						if q.x < area.position.x or q.y < area.position.y or q.x >= mini(w, area.end.x) or q.y >= mini(h, area.end.y):
							continue
						var i := q.y * w + q.x
						if seen[i] == 0:
							var c := img.get_pixel(q.x, q.y)
							if c.a >= 0.1 and not _is_bg(c):
								seen[i] = 1
								stack.append(q)
			r.size += Vector2i(1, 1)
			boxes.append(r)
	return boxes


func _is_bg(c: Color) -> bool:
	# the decorations sheet's lime-green filler blocks are not props
	return c.g > 0.55 and c.r > 0.45 and c.r < 0.7 and c.b < 0.2
