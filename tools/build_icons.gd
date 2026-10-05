extends SceneTree
## Skill and item icons from game-icons.net (CC-BY 3.0, see CREDITS.md), chosen in tools/icon_map.json.
##   ICONS_SRC=/path/to/game-icons/png godot --headless --path . --script res://tools/build_icons.gd
## ICONS_SRC is the unzipped "icons/ffffff/transparent/1x1" folder (one sub-folder per artist).
## Writes art/icons/<id>.png (+ @dim, @lock), 24 px, and art/items/<base>.png (+ @1x) sized to the item's grid.

const CLASS_TINT := {"ossumancer": Color(0.93, 0.9, 0.8), "animancer": Color(0.72, 0.86, 1.0), "hemomancer": Color(0.82, 0.55, 0.5),
	"miasmancer": Color(0.7, 0.85, 0.55), "monk": Color(0.95, 0.8, 0.5), "": Color(0.85, 0.85, 0.85)}

var files := {}   # icon name -> path


func _init() -> void:
	var root := OS.get_environment("ICONS_SRC")
	if root == "" or not DirAccess.dir_exists_absolute(root):
		push_error("Set ICONS_SRC")
		quit(1)
		return
	for artist in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root + "/" + artist):
			if f.ends_with(".png"):
				files[f.get_basename()] = root + "/" + artist + "/" + f
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/icon_map.json"))
	var cls := {}
	for s in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))["skills"]:
		cls[s["id"]] = s.get("class", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/icons"))
	var n := 0
	for id in m["skills"]:
		var src := _pick(m["skills"][id])
		if src == null:
			continue
		var tint: Color = CLASS_TINT.get(cls.get(id, ""), CLASS_TINT[""])
		_skill(id, src, tint)
		n += 1
	var grids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/items/icons.json"))["icons"]
	var ni := 0
	for id in m["items"]:
		var src := _pick(m["items"][id])
		if src == null:
			continue
		var g: Array = grids.get(id, {}).get("grid", [1, 1])
		_item(id, src, int(g[0]), int(g[1]))
		ni += 1
	print("build_icons: %d skills, %d items" % [n, ni])
	quit()


func _pick(cands: Array) -> Image:
	for c in cands:
		if files.has(c):
			var img := Image.load_from_file(files[c])
			img.convert(Image.FORMAT_RGBA8)
			return img
	return null


func _glyph(src: Image, size: int, tint: Color) -> Image:
	var g := src.duplicate()
	g.resize(size, size, Image.INTERPOLATE_LANCZOS)
	for y in size:
		for x in size:
			var p: Color = g.get_pixel(x, y)
			g.set_pixel(x, y, Color(tint.r, tint.g, tint.b, p.a))
	return g


func _skill(id: String, src: Image, tint: Color) -> void:
	for state in ["lit", "dim", "lock"]:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		var bg := Color(0.09, 0.08, 0.08) if state == "lit" else Color(0.06, 0.06, 0.06)
		img.fill(bg)
		var edge := tint.darkened(0.45) if state == "lit" else Color(0.18, 0.18, 0.18)
		for i in 24:
			for p in [Vector2i(i, 0), Vector2i(i, 23), Vector2i(0, i), Vector2i(23, i)]:
				img.set_pixelv(p, edge)
		var t := tint if state == "lit" else (tint.darkened(0.55) if state == "dim" else Color(0.32, 0.32, 0.32))
		img.blend_rect(_glyph(src, 20, t), Rect2i(0, 0, 20, 20), Vector2i(2, 2))
		var path := "res://art/icons/%s%s.png" % [id, "" if state == "lit" else "@" + state]
		img.save_png(ProjectSettings.globalize_path(path))


func _item(id: String, src: Image, gw: int, gh: int) -> void:
	for scale in [48, 12]:
		var w: int = gw * scale
		var h: int = gh * scale
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var s: int = mini(w, h) - (6 if scale == 48 else 2)
		var col := Color(0.86, 0.82, 0.72)
		if id == "hp":
			col = Color(0.75, 0.22, 0.2)
		elif id == "mp":
			col = Color(0.35, 0.5, 0.85)
		var g := _glyph(src, s, col)
		img.blend_rect(g, Rect2i(0, 0, s, s), Vector2i((w - s) / 2, (h - s) / 2))
		var path := "res://art/items/%s%s.png" % [id, "" if scale == 48 else "@1x"]
		img.save_png(ProjectSettings.globalize_path(path))
