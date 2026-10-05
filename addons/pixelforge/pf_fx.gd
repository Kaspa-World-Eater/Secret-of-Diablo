class_name PFFx
extends RefCounted
## Effect strips made by `pixelforge vfx` (a manifest `fx.json` next to the PNGs, as `make_fx.py` writes it,
## or a single `<name>.json`). `PFFx.spawn(parent, "res://art/fx", "lantern_flame", pos, 2.0)` adds an
## AnimatedSprite2D anchored at the effect's ground point / centre. One-shots free themselves.

static var _cache := {}

static func _meta(dir: String, name: String) -> Dictionary:
	var key := dir + "/" + name
	if _cache.has(key):
		return _cache[key]
	var e := {}
	var mf := FileAccess.open(dir + "/fx.json", FileAccess.READ)
	if mf:
		var d = JSON.parse_string(mf.get_as_text())
		if d is Dictionary and d.has(name):
			e = d[name]
	if e.is_empty():
		var f := FileAccess.open(dir + "/" + name + ".json", FileAccess.READ)
		if f:
			var d2 = JSON.parse_string(f.get_as_text())
			if d2 is Dictionary:
				e = d2
				e["png"] = dir + "/" + name + ".png"
	_cache[key] = e
	return e

static func frames_for(dir: String, name: String, heading: float = 0.0) -> SpriteFrames:
	## `heading` in degrees (anticlockwise from flying right) picks the nearest row of a rotation sheet
	## (`rotations` > 1 in the json: missiles made with `pixelforge vfx ... --rotations N`).
	var e := _meta(dir, name)
	var sf := SpriteFrames.new()
	if e.is_empty():
		return sf
	var tex: Texture2D = load(e["png"])
	var w := int(e["frame_width"])
	var h := int(e.get("frame_height", e["size"][1]))
	var rots := int(e.get("rotations", 1))
	var row := 0
	if rots > 1:
		row = int(round(fposmod(heading, 360.0) / (360.0 / rots))) % rots
	sf.add_animation("play")
	sf.set_animation_speed("play", maxf(float(e.get("fps", 8)), 0.01))
	sf.set_animation_loop("play", bool(e.get("loop", true)))
	for i in int(e["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, row * h, w, h)
		sf.add_frame("play", at)
	return sf

static func spawn_missile(parent: Node, dir: String, name: String, pos: Vector2, heading: float, scale: float = 1.0, z: int = 0) -> AnimatedSprite2D:
	## A projectile facing `heading` degrees: the nearest pre-turned row of a rotation sheet, or the sprite rotated.
	var sp := spawn(parent, dir, name, pos, scale, z)
	if sp == null:
		return null
	var e := _meta(dir, name)
	if int(e.get("rotations", 1)) > 1:
		sp.sprite_frames = frames_for(dir, name, heading)
	else:
		sp.rotation = -deg_to_rad(heading)
	return sp

static func spawn(parent: Node, dir: String, name: String, pos: Vector2, scale: float = 1.0, z: int = 0) -> AnimatedSprite2D:
	var e := _meta(dir, name)
	if e.is_empty():
		push_warning("PFFx: no effect " + name + " in " + dir)
		return null
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames_for(dir, name)
	sp.animation = "play"
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.offset = -Vector2(float(e["anchor"][0]), float(e["anchor"][1]))
	sp.scale = Vector2(scale, scale)
	sp.position = pos
	sp.z_index = z
	parent.add_child(sp)
	sp.play("play")
	if not bool(e.get("loop", true)):
		sp.animation_finished.connect(sp.queue_free)
	return sp

static func attachment_offset(att: Dictionary, view: String) -> Vector2:
	## The attachment's offset for a view, in sprite pixels from the ground point (Vector2.INF when not placed there).
	var views: Dictionary = att.get("views", {})
	if views.has(view):
		var o: Array = views[view]
		return Vector2(float(o[0]), float(o[1]))
	return Vector2.INF

static func spawn_attachments(parent: Node, fx_dir: String, set: PFSpriteSet, view: String, scale: float = 1.0, z: int = 1) -> Array:
	## One AnimatedSprite2D per attachment placed on `view`, as children of `parent` (the entity at its ground
	## point). Keep the returned nodes and call update_attachments() when the entity's view changes.
	var out: Array = []
	for att in set.attachments():
		var off := attachment_offset(att, view)
		if off == Vector2.INF:
			continue
		var zz: int = z if str(att.get("z", "front")) != "behind" else -abs(z) - 1   # behind the body: under its sprite
		var sp := spawn(parent, fx_dir, str(att["fx"]), off * scale, float(att.get("scale", 1.0)) * scale, zz)
		if sp == null:
			continue
		sp.set_meta("pf_attachment", att)
		sp.set_meta("pf_scale", scale)
		out.append(sp)
	return out

static func update_attachments(nodes: Array, view: String) -> void:
	## Move (or hide) each attached effect for the entity's current view.
	for sp in nodes:
		if not is_instance_valid(sp) or not sp.has_meta("pf_attachment"):
			continue
		var off := attachment_offset(sp.get_meta("pf_attachment"), view)
		sp.visible = off != Vector2.INF
		if sp.visible:
			sp.position = off * float(sp.get_meta("pf_scale", 1.0))
