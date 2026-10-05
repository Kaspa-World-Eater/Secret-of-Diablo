class_name PFObjects
extends RefCounted
## Props from `pixelforge prop --game-objects objects.json`: {key: {png, ox, oy, hr, frames?, frame_width?, fps?}}.
## `PFObjects.place(parent, "res://art/objects/objects.json", "dead_tree", pos, px_per_world_unit)` adds a
## Sprite2D (or an AnimatedSprite2D for a swaying prop) anchored at its foot point.

static var _manifests := {}

static func manifest(path: String) -> Dictionary:
	if not _manifests.has(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		_manifests[path] = d if d is Dictionary else {}
	return _manifests[path]

static func place(parent: Node, manifest_path: String, key: String, pos: Vector2, px_per_unit: float = 1.0) -> Node2D:
	var e: Dictionary = manifest(manifest_path).get(key, {})
	if e.is_empty():
		push_warning("PFObjects: no object " + key)
		return null
	var tex: Texture2D = load(e["png"])
	var sc := px_per_unit / float(e.get("hr", 1))
	var n: Node2D
	if int(e.get("frames", 1)) > 1:
		var sp := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("sway")
		sf.set_animation_speed("sway", float(e.get("fps", 6)))
		var w := int(e["frame_width"])
		for i in int(e["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * w, 0, w, tex.get_height())
			sf.add_frame("sway", at)
		sp.sprite_frames = sf
		sp.centered = false
		sp.offset = -Vector2(float(e["ox"]), float(e["oy"]))
		sp.play("sway")
		n = sp
	else:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.offset = -Vector2(float(e["ox"]), float(e["oy"]))
		n = sp
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.scale = Vector2(sc, sc)
	n.position = pos
	parent.add_child(n)
	return n
