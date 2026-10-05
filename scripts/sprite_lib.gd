extends Node
## Optional sprite-sheet loader.
##
## Drop `<key>.json` + its sheet PNG into res://assets/sprites/ and any unit whose
## sprite_key matches will use it instead of the built-in placeholder drawing.
## See assets/sprites/README.md for the config format.

const DIR := "res://assets/sprites/"

var _cache := {}


func get_frames(key: String) -> SpriteFrames:
	if key == "":
		return null
	if _cache.has(key):
		return _cache[key]
	var frames: SpriteFrames = null
	var cfg_path := DIR + key + ".json"
	if FileAccess.file_exists(cfg_path):
		frames = _build(cfg_path)
	_cache[key] = frames
	return frames


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _build(cfg_path: String) -> SpriteFrames:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	if typeof(cfg) != TYPE_DICTIONARY:
		push_warning("SpriteLib: bad JSON in " + cfg_path)
		return null
	var tex := _load_texture(DIR + str(cfg.get("sheet", "")))
	if tex == null:
		push_warning("SpriteLib: missing sheet for " + cfg_path)
		return null
	var fs: Array = cfg.get("frame_size", [32, 32])
	var fw := int(fs[0])
	var fh := int(fs[1])
	var frames := SpriteFrames.new()
	var anims: Dictionary = cfg.get("animations", {})
	for anim_name in anims:
		var a: Dictionary = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(a.get("fps", 8)))
		frames.set_animation_loop(anim_name, bool(a.get("loop", true)))
		for f in a.get("frames", []):
			var at := AtlasTexture.new()
			at.atlas = tex
			if f.size() >= 4:
				at.region = Rect2(f[0], f[1], f[2], f[3])
			else:
				at.region = Rect2(int(f[0]) * fw, int(f[1]) * fh, fw, fh)
			frames.add_frame(anim_name, at)
	var off: Array = cfg.get("offset", [0, -fh / 2])
	frames.set_meta("offset", Vector2(off[0], off[1]))
	frames.set_meta("scale", float(cfg.get("scale", 1.0)))
	return frames


func pick(frames: SpriteFrames, state: String, dir: String) -> Array:
	## Returns [animation_name, flip_h] for the best match.
	var flip_dir := {"left": "right", "right": "left"}
	var tries := [[state + "_" + dir, false]]
	if flip_dir.has(dir):
		tries.append([state + "_" + flip_dir[dir], true])
	tries.append([state, false])
	tries.append(["walk_" + dir, false])
	tries.append(["idle_" + dir, false])
	tries.append(["idle_down", false])
	tries.append(["idle", false])
	for t in tries:
		if frames.has_animation(t[0]):
			return t
	return ["default", false]
