extends Node2D
## One thing lying on the ground: an item or a pile of gold, on zone.sorted at iso(tp). It falls from the corpse
## in a small arc (0.4 s, as the web's t = 0.4 bounce), then lies still. Drawn as the web draws it: the inventory
## icon at half size (24 px a cell), gold as a small bright bar. Items in the lantern's pool glint now and then:
## one pale pixel and its four neighbours for 0.3 s every few seconds (zz_zz_cine76), no glow.

const FALL := 0.4

var item: Item = null
var gold := 0
var tp := Vector2.ZERO
var from_tp := Vector2.ZERO
var t := FALL
var tex: Texture2D
var hero_in_pool := false
var _glint_at := 0.0
var _glint := 0.0
var _clock := 0.0

func setup(entry: Dictionary, at: Vector2, from: Vector2, icon: Texture2D) -> void:
	if entry.has("gold"):
		gold = int(entry["gold"])
	else:
		item = entry["item"]
	tp = at
	from_tp = from
	tex = icon
	position = Iso.to_screen(from)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glint_at = randf() * 3.0

func label_text() -> String:
	return "%d Gold" % gold if gold > 0 else item.name

func label_color() -> Color:
	return Color("#d9a441") if gold > 0 else item.color()

## where it is on screen when it has landed (feet)
func ground_pos() -> Vector2:
	return Iso.to_screen(tp)

func _process(dt: float) -> void:
	_clock += dt
	if t > 0.0:
		t = maxf(0.0, t - dt)
		var k := 1.0 - t / FALL
		position = Iso.to_screen(from_tp.lerp(tp, k))
		queue_redraw()
	# the glint: only in the lantern's pool
	if hero_in_pool and t <= 0.0:
		var a := _clock - _glint_at
		if a > 3.2:
			_glint_at = _clock + randf() * 1.5
		var g := 0.0
		if a >= 0.0 and a <= 0.3:
			g = sin(a / 0.3 * PI)
		if g != _glint:
			_glint = g
			queue_redraw()
	elif _glint != 0.0:
		_glint = 0.0
		queue_redraw()

func _draw() -> void:
	var bounce := sin(t / FALL * PI) * 20.0 if t > 0.0 else 0.0
	if gold > 0:
		var n := clampi(1 + int(log(float(gold)) / log(4.0)), 1, 4)
		for i in n:
			var o := Vector2([0, -10, 9, -3][i], [0, 3, 4, -3][i])
			draw_rect(Rect2(Vector2(-8, -8 - bounce) + o, Vector2(16, 8)), Color("#d9a441"))
			draw_rect(Rect2(Vector2(-4, -12 - bounce) + o, Vector2(8, 4)), Color("#ffe3a0"))
	elif tex:
		var s := Vector2(item.grid) * 24.0
		draw_texture_rect(tex, Rect2(Vector2(-s.x / 2.0, -s.y + 8.0 - bounce), s), false)
	else:
		draw_rect(Rect2(Vector2(-10, -18 - bounce), Vector2(20, 18)), Color("#8f8a7c"))
	if _glint > 0.0:
		var c := Color("#fff6e0")
		var y := -8.0
		c.a = 0.9 * _glint
		draw_rect(Rect2(Vector2(-2, y - 2), Vector2(4, 4)), c)
		c.a = 0.45 * _glint
		for o in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			draw_rect(Rect2(Vector2(-2, y - 2) + o, Vector2(4, 4)), c)
