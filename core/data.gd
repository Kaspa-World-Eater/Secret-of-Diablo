extends Node
## Autoload "Data": the tables exported from the web build (tools/export_data.js), loaded on first use,
## and the sprite atlases (tools/export_sprites.js).

var _json := {}
var _sets := {}

func table(name: String) -> Variant:
	if not _json.has(name):
		var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
		_json[name] = JSON.parse_string(f.get_as_text()) if f else {}
	return _json[name]

func zone_index() -> Dictionary:
	if not _json.has("zones_index"):
		var f := FileAccess.open("res://data/zones/index.json", FileAccess.READ)
		_json["zones_index"] = JSON.parse_string(f.get_as_text()) if f else {}
	return _json["zones_index"]

## a zone as tools/zone_export wrote it: data/zones/<id>_s<seed>.json.gz (gzip), or a plain .json
func zone(id: String, seed: int) -> Dictionary:
	var base := "res://data/zones/%s_s%d.json" % [id, seed]
	if FileAccess.file_exists(base + ".gz"):
		var raw := FileAccess.get_file_as_bytes(base + ".gz")
		var txt := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
		var j = JSON.parse_string(txt)
		return j if j is Dictionary else {}
	var f := FileAccess.open(base, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}

func zone_seeds(id: String) -> Array:
	var z: Dictionary = zone_index().get("zones", {}).get(id, {})
	return z.get("seeds", [12345, 777, 4242])

## a sprite atlas: {anim/view -> [[AtlasTexture, Vector2 offset], ...]}, plus meta
var _skins := {}
var _skins_loaded := false

func skin_for(kind: String) -> String:
	## art/sprites/skins.json maps a kind to the set that should stand in for it ({"animancer": "mystic"}): the
	## PixelForge builds of the heroes replace the old painter sets without renaming files. "<kind>_unclipped" follows
	## its base kind. --skin=NAME on the command line still wins (entities/hero.gd).
	if not _skins_loaded:
		_skins_loaded = true
		var f := FileAccess.open("res://art/sprites/skins.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_skins = d
	if _skins.has(kind):
		return str(_skins[kind])
	var base := kind.trim_suffix("_unclipped")
	if base != kind and _skins.has(base):
		return str(_skins[base])
	return kind

var _pf_sets := {}

func is_pixelforge_set(kind: String) -> bool:
	## whether art/sprites/<kind>.json is a PixelForge build (its meta says "source": "pixelforge"): the hero loader
	## prefers such a set over the old "<kind>_unclipped" painter variant, so a new build is used as soon as it lands.
	if _pf_sets.has(kind):
		return _pf_sets[kind]
	var ok := false
	var path := "res://art/sprites/%s.json" % kind
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				var meta = d.get("meta", {})
				if meta is Dictionary:
					ok = str(meta.get("source", "")) == "pixelforge"
	_pf_sets[kind] = ok
	return ok

func sprite_set(kind: String) -> SpriteSet:
	kind = skin_for(kind)
	if _sets.has(kind):
		return _sets[kind]
	var s := SpriteSet.new()
	s.load_kind(kind)
	_sets[kind] = s
	return s
