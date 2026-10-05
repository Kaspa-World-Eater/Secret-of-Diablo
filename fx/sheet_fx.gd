class_name SheetFx
extends RefCounted
## Effect sheets made by PixelForge (art/fx, see tools/make_fx.py). `SheetFx.spawn(parent, "world_hit_flash", pos)`
## adds an AnimatedSprite2D built from the strip, anchored at the effect's ground point or centre (the manifest's
## anchor), at the game's object scale (Iso.WPX / hr). One-shot effects free themselves when done; loops play until
## freed. No glow is added here: the halo, where the law allows one, is already in the frames.

static var _manifest: Dictionary = {}
static var _frames_cache: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open("res://art/fx/fx.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		_manifest = d if d is Dictionary else {}
	return _manifest

static func has(name: String) -> bool:
	return manifest().has(name)

static func frames_for(name: String) -> SpriteFrames:
	if _frames_cache.has(name):
		return _frames_cache[name]
	var e: Dictionary = manifest().get(name, {})
	var sf := SpriteFrames.new()
	if e.is_empty():
		return sf
	var tex: Texture2D = load(e["png"])
	var w := int(e["frame_width"])
	var h := int(e["size"][1])
	sf.add_animation("play")
	sf.set_animation_speed("play", float(e["fps"]) if float(e["fps"]) > 0.0 else 1.0)
	sf.set_animation_loop("play", bool(e["loop"]))
	for i in int(e["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, h)
		sf.add_frame("play", at)
	_frames_cache[name] = sf
	return sf

## `pos` is a screen position (the parent's space). Returns the sprite, or null for an unknown name.
static func spawn(parent: Node, name: String, pos: Vector2, scale_mult: float = 1.0, z: int = 0, modulate: Color = Color.WHITE) -> AnimatedSprite2D:
	var e: Dictionary = manifest().get(name, {})
	if e.is_empty():
		push_warning("SheetFx: no effect named %s" % name)
		return null
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames_for(name)
	sp.animation = "play"
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.offset = -Vector2(float(e["anchor"][0]), float(e["anchor"][1]))
	var sc := Iso.WPX / float(e.get("hr", 2)) * scale_mult
	sp.scale = Vector2(sc, sc)
	sp.position = pos
	sp.z_index = z
	sp.modulate = modulate
	parent.add_child(sp)
	sp.play("play")
	if not bool(e["loop"]):
		sp.animation_finished.connect(sp.queue_free)
	return sp
