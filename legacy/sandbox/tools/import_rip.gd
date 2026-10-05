extends SceneTree
## Imports ripped/exported art into the game.
##
##   godot --headless --path . --script res://tools/import_rip.gd
##
## MAPS:    assets/rip/maps/<zone>/*.png  (one PNG per background layer, same size;
##          drawn in filename order, so name them e.g. 1_bg2.png, 2_bg1.png)
##          optional assets/rip/maps/<zone>/zone.json:
##            {"tile": 16, "level": 1, "transparent": [r, g, b]}
##       -> assets/zones/<zone>/atlas.png + map.json
##          (collision.json is created by the in-game painter and never overwritten)
##
## SPRITES: assets/rip/sprites/<key>/*.png  (sprite sheets or emulator screenshots)
##          optional assets/rip/sprites/<key>/sprite.json:
##            {"bg": [r, g, b], "min": 6, "max": 96, "scale": 2}
##       -> assets/sprites/<key>.png + <key>.json (every unique frame, ready to map
##          into animations; see assets/sprites/README.md)

const RIP := "res://assets/rip/"
const ATLAS_COLS := 32


func _init() -> void:
	var n_maps := 0
	var n_sprites := 0
	for zone in _dirs(RIP + "maps"):
		if _import_map(zone):
			n_maps += 1
	for key in _dirs(RIP + "sprites"):
		if _import_sprites(key):
			n_sprites += 1
	print("import_rip: %d zone(s), %d sprite set(s) imported" % [n_maps, n_sprites])
	quit()


func _dirs(path: String) -> Array:
	var out := []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for n in d.get_directories():
		out.append(n)
	out.sort()
	return out


func _pngs(path: String) -> Array:
	var out := []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			out.append(path + "/" + f)
	out.sort()
	return out


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _color_key(cfg: Dictionary, key: String):
	if not cfg.has(key):
		return null
	var c: Array = cfg[key]
	return Color8(int(c[0]), int(c[1]), int(c[2]))


func _knock_out(img: Image, c) -> void:
	## Makes every pixel of colour `c` transparent.
	if c == null:
		return
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0 and abs(p.r - c.r) < 0.01 and abs(p.g - c.g) < 0.01 and abs(p.b - c.b) < 0.01:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


# ---------------------------------------------------------------- maps

func _import_map(zone: String) -> bool:
	var src := RIP + "maps/" + zone
	var files := _pngs(src)
	if files.is_empty():
		return false
	var cfg := _json(src + "/zone.json")
	var tp := int(cfg.get("tile", 16))
	var transparent = _color_key(cfg, "transparent")
	var layers_img := []
	var w := 0
	var h := 0
	for f in files:
		var img := _load(f)
		if img == null:
			push_warning("import_rip: cannot read " + f)
			continue
		_knock_out(img, transparent)
		if w == 0:
			w = img.get_width() / tp
			h = img.get_height() / tp
		layers_img.append(img)
	if layers_img.is_empty():
		return false

	var index := {}      # tile pixel hash -> atlas index
	var tiles := []      # Image per atlas index
	var colors := []     # average colour per atlas index
	var layers := []
	for img in layers_img:
		var cells := PackedInt32Array()
		cells.resize(w * h)
		for ty in h:
			for tx in w:
				var reg: Image = img.get_region(Rect2i(tx * tp, ty * tp, tp, tp))
				if reg.is_invisible():
					cells[ty * w + tx] = -1
					continue
				var data := reg.get_data()
				var key := str(hash(data)) + ":" + str(data.size())
				if not index.has(key):
					index[key] = tiles.size()
					tiles.append(reg)
					colors.append(_avg(reg))
				cells[ty * w + tx] = index[key]
		layers.append(Array(cells))

	var rows := int(ceil(tiles.size() / float(ATLAS_COLS)))
	var atlas := Image.create(ATLAS_COLS * tp, max(1, rows) * tp, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in tiles.size():
		atlas.blit_rect(tiles[i], Rect2i(0, 0, tp, tp), Vector2i((i % ATLAS_COLS) * tp, (i / ATLAS_COLS) * tp))
	var out := "res://assets/zones/" + zone
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	atlas.save_png(ProjectSettings.globalize_path(out + "/atlas.png"))
	var col_out := []
	for c in colors:
		col_out.append([snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01)])
	var map := {"tile": tp, "w": w, "h": h, "cols": ATLAS_COLS, "count": tiles.size(),
		"level": int(cfg.get("level", 1)), "layers": layers, "colors": col_out}
	var f := FileAccess.open(ProjectSettings.globalize_path(out + "/map.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(map))
	f.close()
	print("  zone '%s': %dx%d tiles, %d layer(s), %d unique tiles" % [zone, w, h, layers.size(), tiles.size()])
	return true


func _avg(img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a > 0.5:
				r += p.r
				g += p.g
				b += p.b
				n += 1
	if n == 0:
		return Color(0, 0, 0)
	return Color(r / n, g / n, b / n)


# ---------------------------------------------------------------- sprites

func _import_sprites(key: String) -> bool:
	var src := RIP + "sprites/" + key
	var files := _pngs(src)
	if files.is_empty():
		return false
	var cfg := _json(src + "/sprite.json")
	var min_px := int(cfg.get("min", 6))
	var max_px := int(cfg.get("max", 96))
	var frames := []
	var seen := {}
	for f in files:
		var img := _load(f)
		if img == null:
			continue
		var bg = _color_key(cfg, "bg")
		if bg == null:
			bg = _guess_bg(img)
		_knock_out(img, bg)
		for r in _components(img):
			if r.size.x < min_px or r.size.y < min_px or r.size.x > max_px or r.size.y > max_px:
				continue
			var fr: Image = img.get_region(r)
			var hk := str(hash(fr.get_data())) + str(r.size)
			if seen.has(hk):
				continue
			seen[hk] = true
			frames.append(fr)
	if frames.is_empty():
		push_warning("import_rip: no sprite frames found for " + key)
		return false
	# uniform cells, frames bottom-centre aligned so feet line up
	var cw := 0
	var ch := 0
	for fr in frames:
		cw = max(cw, fr.get_width())
		ch = max(ch, fr.get_height())
	var cols: int = min(16, frames.size())
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(cols * cw, rows * ch, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var all := []
	for i in frames.size():
		var fr: Image = frames[i]
		var cx := (i % cols) * cw + (cw - fr.get_width()) / 2
		var cy := (i / cols) * ch + (ch - fr.get_height())
		sheet.blit_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), Vector2i(cx, cy))
		all.append([i % cols, i / cols])
	var out := "res://assets/sprites/"
	sheet.save_png(ProjectSettings.globalize_path(out + key + ".png"))
	var cfg_out := out + key + ".json"
	var existing := _json(cfg_out)
	var anims: Dictionary = existing.get("animations", {})
	if anims.is_empty():
		anims = {"idle_down": {"frames": [all[0]], "fps": 1}, "walk_down": {"frames": all.slice(0, min(4, all.size())), "fps": 8}}
	var spr := {"sheet": key + ".png", "frame_size": [cw, ch], "scale": float(cfg.get("scale", 2.0)),
		"offset": [0, -ch / 2], "animations": anims, "all_frames": all}
	var f := FileAccess.open(ProjectSettings.globalize_path(cfg_out), FileAccess.WRITE)
	f.store_string(JSON.stringify(spr, "\t"))
	f.close()
	print("  sprites '%s': %d unique frames (cell %dx%d)" % [key, frames.size(), cw, ch])
	return true


func _guess_bg(img: Image):
	## Most common colour along the image border (emulator backdrop / sheet background).
	var counts := {}
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		for y in [0, h - 1]:
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				counts[c.to_html(false)] = counts.get(c.to_html(false), 0) + 1
	for y in h:
		for x in [0, w - 1]:
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				counts[c.to_html(false)] = counts.get(c.to_html(false), 0) + 1
	var best := ""
	var best_n := 0
	for k in counts:
		if counts[k] > best_n:
			best = k
			best_n = counts[k]
	return null if best == "" else Color.html(best)


func _components(img: Image) -> Array:
	## Bounding boxes of opaque pixel islands; islands 2px apart are merged.
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes := []
	for y in h:
		for x in w:
			if seen[y * w + x] == 1 or img.get_pixel(x, y).a < 0.5:
				continue
			var r := Rect2i(x, y, 0, 0)
			var stack := [Vector2i(x, y)]
			seen[y * w + x] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				r = r.expand(p)
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var nx := p.x + dx
						var ny := p.y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var i := ny * w + nx
						if seen[i] == 0 and img.get_pixel(nx, ny).a >= 0.5:
							seen[i] = 1
							stack.append(Vector2i(nx, ny))
			r.size += Vector2i(1, 1)
			boxes.append(r)
	boxes.sort_custom(func(a, b): return a.position.y < b.position.y if abs(a.position.y - b.position.y) > 8 else a.position.x < b.position.x)
	return boxes
