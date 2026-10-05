class_name Assets
extends RefCounted
## Art from the web build, unpacked by tools/extract_assets.py into res://assets, catalogued in assets.json.
## World pieces were painted at twice the world grain; the heroes at three times. The world is laid out in grain units.

static var meta: Dictionary = {}
static var _cache: Dictionary = {}

static func load_meta() -> void:
	if not meta.is_empty():
		return
	var f := FileAccess.open("res://assets/assets.json", FileAccess.READ)
	if f == null:   # Godmarrow's painted world art is not part of this game (free LPC art instead)
		meta = {"wtex": {}, "world": {}, "trees": {}, "decor": {}, "ground": []}
		return
	meta = JSON.parse_string(f.get_as_text())

static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load("res://assets/" + path) if ResourceLoader.exists("res://assets/" + path) else null
	_cache[path] = t
	return t

## a world piece: {png, ox, oy} from the "world" or "trees" or "decor" catalogues
static func piece(cat: String, id: String) -> Dictionary:
	var c: Dictionary = meta.get(cat, {})
	var v = c.get(id)
	return v if v is Dictionary else {}

## the ground textures of a land: {main: [..], dirt: [..], road: [..], ...}
static func ground(land: String) -> Dictionary:
	for s in meta.get("ground", []):
		if s is Dictionary and s.has(land) and s[land] is Dictionary:
			return s[land]
	return {}
