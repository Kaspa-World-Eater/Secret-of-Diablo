class_name AnimSprite
extends Sprite2D
## Draws one frame of a SpriteSet at the foot anchor, mirrored about the anchor for face -1, as the web does.

var set: SpriteSet
var anim := "idle"
var view := "front"
var face := 1
var fi := 0
var t := 0.0
var fps_override := 0.0
var loop := true
var done := false

func _init(s: SpriteSet = null) -> void:
	set = s
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func play(a: String, restart: bool = false, looping: bool = true) -> void:
	if a == anim and not restart:
		return
	anim = a
	fi = 0
	t = 0.0
	loop = looping
	done = false

func step(dt: float, speed: float = 1.0) -> void:
	if set == null:
		return
	var fr := set.get_frames(anim, view)
	if fr.is_empty():
		return
	var f := fps_override if fps_override > 0.0 else set.fps(anim)
	t += dt * f * speed
	while t >= 1.0:
		t -= 1.0
		fi += 1
		if fi >= fr.size():
			if loop:
				fi = 0
			else:
				fi = fr.size() - 1
				done = true
	apply()

func set_index(i: int) -> void:
	fi = i
	apply()

func frame_count() -> int:
	return set.get_frames(anim, view).size() if set else 0

func apply() -> void:
	if set == null:
		return
	var fr := set.get_frames(anim, view)
	if fr.is_empty():
		return
	var f: Array = fr[clampi(fi, 0, fr.size() - 1)]
	texture = f[0]
	var off: Vector2 = f[1]
	flip_h = face < 0 and view.begins_with("side")   # down / up views are drawn as painted
	if flip_h:
		off.x = -(off.x + (f[0] as AtlasTexture).region.size.x)
	offset = off

## facing in the top-down view: side (mirrored for left), down or up, by the dominant direction.
## The 8-view PixelForge sets ("side_l" etc.) are honoured when a set has them.
static func hero_view(dir: Vector2, last_face: int, s8: SpriteSet = null) -> Array:
	if dir.length() < 0.001:
		return ["", last_face]
	if absf(dir.x) > absf(dir.y) * 0.85:
		if dir.x < 0.0 and s8 != null and s8.has_view("side_l"):
			return ["side_l", 1]
		return ["side", 1 if dir.x > 0.0 else -1]
	return ["down" if dir.y > 0.0 else "up", last_face]

static func mon_view(dir: Vector2, last_face: int) -> Array:
	return hero_view(dir, last_face)
