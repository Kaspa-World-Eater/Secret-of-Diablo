extends Node2D
## The Mystic's standing things, drawn in the y-sorted layer: a standing mirror (Standing Mirrors, the Hall, the
## Fissure's last shards), the great Falling Mirror, and the Soul Lantern. Polished silver frames and glass that holds
## a pale sky over a dark horizon (zy_anim.js anMirrorFrame / anGreatFrame); cracked glass shows its seams.
## Plain shapes, no glow. The lantern carries a small grave-light (it exposes what stands in it).

const SKY := [Color("#f0f8ff"), Color("#cfe8fa"), Color("#a6ceee"), Color("#7eaede"), Color("#5a8cc4"), Color("#3e6aa0")]
const F0 := Color("#23272f")
const F1 := Color("#5c6474")
const F2 := Color("#9aa2b4")
const F3 := Color("#d4dae4")

var o                        # the Mirror / lantern state (animancer.gd): kind, tp, rise, rise_max, fall, fall_max, cracked, hall, gone, seed
var lamp: PointLight2D

func setup(obj) -> void:
	o = obj
	o.node = self
	position = Iso.to_screen(o.tp)
	if o.kind == "lantern":
		lamp = PointLight2D.new()
		lamp.texture = Lights.radial(512)
		lamp.color = Color8(170, 214, 226)
		lamp.energy = 0.7
		lamp.texture_scale = 4.2 * Iso.HX * 2.0 / 512.0
		lamp.position = Vector2(0, -96)
		add_child(lamp)

func _process(_dt: float) -> void:
	if o == null or o.gone or o.node != self:
		queue_free()
		return
	position = Iso.to_screen(o.tp)
	if lamp:
		lamp.energy = 0.7 * clampf(o.life / 0.6, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if o == null:
		return
	match o.kind:
		"pane":
			var k := 1.0 - clampf(o.rise / maxf(0.01, o.rise_max), 0.0, 1.0)
			_pane(Vector2.ZERO, 34.0, 96.0 * k, o.cracked, o.hall)
		"great":
			var f := clampf(o.fall / maxf(0.01, o.fall_max), 0.0, 1.0)
			var lift := f * f * 760.0
			_great(Vector2(0, -lift), o.cracked and f <= 0.0)
		"lantern":
			_lantern()

func _poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)

## an arched pane in a silver frame on a stepped plinth; h grows from the ground as it rises
func _pane(base: Vector2, w: float, h: float, cracked: bool, hall: bool) -> void:
	if h < w + 12.0:
		draw_rect(Rect2(base.x - w * 0.6, base.y - 3, w * 1.2, 4), F1)
		if h > 6.0:
			draw_rect(Rect2(base.x - w * 0.5, base.y - 3 - h, w, h), F1)
			draw_rect(Rect2(base.x - w * 0.5 + 4, base.y - h, w - 8, h - 6), SKY[2])
		return
	# plinth
	draw_rect(Rect2(base.x - w * 0.62, base.y - 8, w * 1.24, 8), F0)
	draw_rect(Rect2(base.x - w * 0.62, base.y - 8, w * 1.24, 2), F1)
	# frame: a rect with an arched top
	var hw := w * 0.5
	var top := base.y - 8 - h
	var frame := PackedVector2Array()
	frame.append(Vector2(base.x - hw, base.y - 8))
	for i in 9:
		var a := PI + PI * i / 8.0
		frame.append(Vector2(base.x + cos(a) * hw, top + hw + sin(a) * hw))
	frame.append(Vector2(base.x + hw, base.y - 8))
	_poly(frame, F1)
	# the glass inside: sky bands over a dark horizon, ground below
	var iw := hw - 4.0
	var gtop := top + 4.0
	var gbot := base.y - 12.0
	var glass := PackedVector2Array()
	glass.append(Vector2(base.x - iw, gbot))
	for i in 9:
		var a := PI + PI * i / 8.0
		glass.append(Vector2(base.x + cos(a) * iw, gtop + iw + sin(a) * iw))
	glass.append(Vector2(base.x + iw, gbot))
	_poly(glass, SKY[3])
	var hz := gtop + (gbot - gtop) * 0.58
	for b in 5:
		var y0 := gtop + iw * 0.3 + (hz - gtop - iw * 0.3) * b / 5.0
		draw_rect(Rect2(base.x - iw, y0, iw * 2.0, (hz - gtop) / 5.0 + 1.0), SKY[b + 1] if b > 0 else SKY[1])
	draw_rect(Rect2(base.x - iw, hz, iw * 2.0, gbot - hz), Color("#1d2430"))
	draw_rect(Rect2(base.x - iw, hz, iw * 2.0, 2.0), Color("#3e5a80"))
	# two hard specular streaks
	draw_line(Vector2(base.x - iw * 0.5, gtop + iw * 0.6), Vector2(base.x - iw * 0.1, gtop + iw * 0.6 + 26), Color(1, 1, 1, 0.8), 2.0)
	draw_line(Vector2(base.x + iw * 0.2, gtop + iw * 0.8), Vector2(base.x + iw * 0.45, gtop + iw * 0.8 + 16), Color(1, 1, 1, 0.55), 2.0)
	# the frame's lit and shaded edges
	draw_line(Vector2(base.x - hw, base.y - 8), Vector2(base.x - hw, top + hw), F3, 2.0)
	draw_line(Vector2(base.x + hw, base.y - 8), Vector2(base.x + hw, top + hw), F0, 2.0)
	if hall:
		draw_rect(Rect2(base.x - 3, top - 5, 6, 6), F2)
	if cracked:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(o.seed)
		var c := Vector2(base.x + rng.randf_range(-iw * 0.4, iw * 0.4), gtop + (gbot - gtop) * rng.randf_range(0.3, 0.6))
		for i in 5:
			var a := rng.randf() * TAU
			var e := c + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 26.0)
			e.x = clampf(e.x, base.x - iw, base.x + iw)
			e.y = clampf(e.y, gtop, gbot)
			draw_line(c, e, Color("#0e1118"), 1.5)
			draw_line(c + Vector2(-1, -1), e + Vector2(-1, -1), Color(1, 1, 1, 0.35), 1.0)

## the great mirror: a tall oval of glass in a heavy frame with a crest and clawed feet
func _great(off: Vector2, cracked: bool) -> void:
	var c := off + Vector2(0, -86)
	var rx := 34.0
	var ry := 72.0
	var frame := PackedVector2Array()
	var glass := PackedVector2Array()
	for i in 28:
		var a := i / 28.0 * TAU
		frame.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		glass.append(c + Vector2(cos(a) * (rx - 6), sin(a) * (ry - 7)))
	_poly(frame, F1)
	_poly(glass, SKY[2])
	for b in 4:
		var y0 := c.y - ry * 0.6 + b * ry * 0.22
		var half := sqrt(maxf(0.0, 1.0 - pow((y0 + ry * 0.11 - c.y) / (ry - 7), 2))) * (rx - 6)
		draw_rect(Rect2(c.x - half, y0, half * 2.0, ry * 0.22), SKY[b + 2])
	var hz := c.y + ry * 0.28
	var gh := sqrt(maxf(0.0, 1.0 - pow((hz - c.y) / (ry - 7), 2))) * (rx - 6)
	var lower := PackedVector2Array([Vector2(c.x - gh, hz)])
	for i in 13:
		var a := asin(clampf((hz - c.y) / (ry - 7), -1, 1))
		var aa := lerpf(a, PI - a, i / 12.0)
		lower.append(c + Vector2(cos(aa) * (rx - 6), sin(aa) * (ry - 7)))
	_poly(lower, Color("#1d2430"))
	draw_polyline(frame + PackedVector2Array([frame[0]]), F3, 2.0)
	draw_rect(Rect2(c.x - 6, c.y - ry - 12, 12, 12), F2)
	draw_rect(Rect2(c.x - rx * 0.7, off.y - 10, 10, 10), F0)
	draw_rect(Rect2(c.x + rx * 0.7 - 10, off.y - 10, 10, 10), F0)
	draw_line(c + Vector2(-rx * 0.5, -ry * 0.4), c + Vector2(-rx * 0.1, -ry * 0.05), Color(1, 1, 1, 0.8), 2.0)
	if cracked:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(o.seed)
		for i in 7:
			var a := rng.randf() * TAU
			var e := c + Vector2(cos(a) * (rx - 8), sin(a) * (ry - 9)) * rng.randf_range(0.5, 1.0)
			draw_line(c, e, Color("#0e1118"), 1.5)
			draw_line(c + Vector2(-1, -1), e + Vector2(-1, -1), Color(1, 1, 1, 0.35), 1.0)

## the Soul Lantern: an iron post with a caged grave-light
func _lantern() -> void:
	var k := clampf(o.life / 0.6, 0.0, 1.0)
	draw_rect(Rect2(-12, -8, 24, 8), F0)
	draw_rect(Rect2(-3, -100, 6, 94), Color("#1a1d24"))
	draw_rect(Rect2(-2, -100, 2, 94), F1)
	draw_line(Vector2(0, -100), Vector2(14, -104), Color("#1a1d24"), 3.0)
	var cage := Rect2(6, -102, 16, 22)
	draw_rect(cage, Color(0.62, 0.8, 0.86, 0.55 * k))
	draw_rect(cage, F0, false, 2.0)
	draw_line(Vector2(14, -102), Vector2(14, -80), F0, 1.5)
