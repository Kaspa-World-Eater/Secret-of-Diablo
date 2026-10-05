class_name PFSpriteSet
extends RefCounted
## A PixelForge character export (`pixelforge project export-game`): `<kind>.json` with `sheets`, `meta`, `idx`
## keyed "anim/view/i" -> [sheet, x, y, w, h, dx, dy]. (dx, dy) is the frame's top-left relative to the ground
## point. Views: down front side back up (+ front_l side_l back_l when rendered). Frames face screen-right;
## mirror for the left octants when the _l views are missing.
##
##     var s := PFSpriteSet.new(); s.load_file("res://art/sprites/mystic.json")
##     var f := s.frame("walk", "front", 3)   # {tex: AtlasTexture, offset: Vector2}
##     s.apply(sprite2d, "walk", "front", 3)   # sets texture + offset on a Sprite2D (centered = false)

var kind := ""
var meta := {}
var anims := {}
var frames := {}   # "anim/view" -> [[AtlasTexture, Vector2], ...]
var ok := false
const VIEWS8 := ["down", "front", "side", "back", "up", "front_l", "side_l", "back_l"]

func load_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("PFSpriteSet: cannot open " + path)
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	kind = path.get_file().get_basename()
	meta = d.get("meta", {})
	anims = meta.get("anims", {})
	var base := path.get_base_dir()
	var sheets: Array = []
	for p in d["sheets"]:
		sheets.append(load(base + "/" + p))
	var tmp := {}
	for key in d["idx"]:
		var e: Array = d["idx"][key]
		var parts: PackedStringArray = key.split("/")
		var at := AtlasTexture.new()
		at.atlas = sheets[int(e[0])]
		at.region = Rect2(e[1], e[2], e[3], e[4])
		var k2 := parts[0] + "/" + parts[1]
		if not tmp.has(k2):
			tmp[k2] = []
		tmp[k2].append([int(parts[2]), at, Vector2(e[5], e[6])])
	for k2 in tmp:
		var arr: Array = tmp[k2]
		arr.sort_custom(func(a, b): return a[0] < b[0])
		frames[k2] = arr.map(func(x): return [x[1], x[2]])
	ok = true
	return true

func has(anim: String) -> bool:
	return anims.has(anim)

func has_view(anim: String, view: String) -> bool:
	return frames.has(anim + "/" + view)

func count(anim: String, view: String) -> int:
	return frames.get(anim + "/" + view, []).size()

func fps(anim: String, fallback: float = 8.0) -> float:
	return float(meta.get("fps", {}).get(anim, fallback))

## 8-way direction (0 = screen right, counter-clockwise in screen terms... use dir_to_view for a vector)
static func dir_to_view(dir: Vector2) -> Array:
	## returns [view, flip] for a facing vector in screen space (y down)
	var a := atan2(dir.y, dir.x)   # -PI..PI, 0 = right
	var oct := int(round(a / (PI / 4))) % 8
	if oct < 0:
		oct += 8
	# 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE
	match oct:
		0: return ["side", false]
		1: return ["front", false]
		2: return ["down", false]
		3: return ["front_l", true]
		4: return ["side_l", true]
		5: return ["back_l", true]
		6: return ["up", false]
		_: return ["back", false]

func frame(anim: String, view: String, i: int) -> Dictionary:
	var flip := false
	var key := anim + "/" + view
	if not frames.has(key) and view.ends_with("_l"):
		key = anim + "/" + view.trim_suffix("_l")   # mirror the right-facing view
		flip = true
	var arr: Array = frames.get(key, [])
	if arr.is_empty():
		return {}
	var e: Array = arr[i % arr.size()]
	return {"tex": e[0], "offset": e[1], "flip": flip}

func apply(sp: Sprite2D, anim: String, view: String, i: int) -> void:
	var f := frame(anim, view, i)
	if f.is_empty():
		return
	sp.centered = false
	sp.texture = f["tex"]
	sp.flip_h = f["flip"]
	var off: Vector2 = f["offset"]
	if f["flip"]:
		off.x = -off.x - (f["tex"] as AtlasTexture).region.size.x
	sp.offset = off

func attachments() -> Array:
	## Effects the Forge's effects editor attached to this set: [{name, kind, fx, scale, views: {view: [ox, oy]}}],
	## offsets in sprite pixels from the entity's ground point. Spawn them with PFFx.spawn_attachments().
	return meta.get("attachments", [])

func fx_dir(default: String = "res://art/fx") -> String:
	## Where the attached effects' sheets live (a folder next to the sprites folder, as the editor wrote them).
	if meta.has("fx_dir"):
		return default.get_base_dir() + "/" + str(meta["fx_dir"])
	return default
