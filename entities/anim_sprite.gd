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
## (Secret of Diablo) the motion layer: weight the free art's few frames can't carry on their own. A breath at rest,
## a crouch through the wind-up, a lunge on the blow, a squash and recoil when struck, a slump on falling. It scales
## about the feet and nudges the drawing; whatever scale the owner sets is kept underneath it.
var juice := true
var since := 0.0             # seconds in the current anim
var breath := randf() * TAU
var _ext := Vector2.ONE      # the owner's own scale
var _set := Vector2.ONE      # the scale last written here
var _jo := Vector2.ZERO      # this frame's nudge (art px)

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
	since = 0.0
	loop = looping
	done = false

func step(dt: float, speed: float = 1.0) -> void:
	if set == null:
		return
	var fr := set.get_frames(anim, view)
	if fr.is_empty():
		return
	var f := fps_override if fps_override > 0.0 else set.fps(anim)
	since += dt
	if juice:
		_motion(dt)
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
	offset = off + _jo

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


func _facing() -> Vector2:
	if view.begins_with("side"):
		return Vector2(face if view == "side" else -1, 0)
	return Vector2(0, -1) if view == "up" else Vector2(0, 1)


func _motion(dt: float) -> void:
	if scale != _set:
		_ext = scale            # the owner changed it: that is the new ground
	breath += dt * 2.4
	var sq := Vector2.ONE      # x wide, y tall
	var nudge := Vector2.ZERO
	var fw := _facing()
	var few := frame_count() <= 2
	match anim:
		"idle":
			var b := sin(breath) * 0.022
			sq = Vector2(1.0 - b * 0.5, 1.0 + b)
		"walk", "run":
			nudge.y = -absf(sin(since * 9.0)) * (2.5 if few else 0.0)
		"wind":
			# gather: low and drawn back, deepening through the wind-up, with a tremble at the end
			var k := minf(1.0, since / 0.4)
			sq = Vector2(1.0 + 0.08 * k, 1.0 - 0.1 * k)
			nudge = -fw * 5.0 * k + Vector2(sin(since * 60.0), 0.0) * (1.2 if k >= 1.0 else 0.0)
		"atk", "heavy", "atk2":
			# the blow: a quick stretch and step into it, settling back
			var k := maxf(0.0, 1.0 - since / 0.22)
			var hk := 1.6 if anim == "heavy" else 1.0
			sq = Vector2(1.0 - 0.07 * k * hk, 1.0 + 0.1 * k * hk)
			nudge = fw * 10.0 * hk * sin(minf(1.0, since / 0.22) * PI)
		"hit", "stun":
			# struck: squashed and knocked back, a shiver that dies away
			var k := maxf(0.0, 1.0 - since / 0.2)
			sq = Vector2(1.0 + 0.16 * k, 1.0 - 0.14 * k)
			nudge = -fw * 7.0 * k + Vector2(sin(since * 80.0) * 3.0 * k, 0.0)
		"cast":
			var k := sin(minf(1.0, since / 0.35) * PI)
			sq = Vector2(1.0 - 0.04 * k, 1.0 + 0.06 * k)
		"dodge", "roll":
			var k := maxf(0.0, 1.0 - since / 0.25)
			sq = Vector2(1.0 + 0.1 * k, 1.0 - 0.12 * k)
		"death", "death_back":
			# a creature with no fall of its own slumps flat; one with a fall only gives at the knees
			var k := minf(1.0, since / 0.35)
			sq = Vector2(1.0 + 0.15 * k, 1.0 - 0.55 * k) if few else Vector2(1.0, 1.0 - 0.05 * k)
	_jo = nudge
	_set = _ext * sq
	scale = _set
