class_name SpriteSet
extends RefCounted
## One exported atlas: frames by "anim/view", each [AtlasTexture, offset from the foot anchor to the top-left].

var kind := ""
var frames := {}
var meta := {}
var anims := {}
var ok := false

func load_kind(k: String) -> void:
	kind = k
	var f := FileAccess.open("res://art/sprites/%s.json" % k, FileAccess.READ)
	if f == null:
		push_warning("no sprite set " + k)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	meta = d.get("meta", {})
	anims = meta.get("anims", {})
	var sheets: Array = []
	for p in d["sheets"]:
		sheets.append(load("res://art/sprites/" + p))
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

func has(anim: String) -> bool:
	return anims.has(anim)

## true when any anim carries this view (e.g. "side_l": a real left-facing view from an 8-view export)
func has_view(view: String) -> bool:
	for k in frames:
		if (k as String).ends_with("/" + view):
			return true
	return false

## frames of an anim in a view, falling back as the web does (down -> front, up -> back, else any)
func get_frames(anim: String, view: String) -> Array:
	var k := anim + "/" + view
	if frames.has(k):
		return frames[k]
	var alt := {"down": "front", "up": "back", "side": "front", "back": "front", "front": "down"}
	var v2: String = alt.get(view, "front")
	if frames.has(anim + "/" + v2):
		return frames[anim + "/" + v2]
	for v in ["front", "down", "side", "back", "up"]:
		if frames.has(anim + "/" + v):
			return frames[anim + "/" + v]
	return []

func fps(anim: String, fallback: float = 8.0) -> float:
	var f = meta.get("fps", {}).get(anim, fallback)
	return float(f) if (f is float or f is int) else fallback
