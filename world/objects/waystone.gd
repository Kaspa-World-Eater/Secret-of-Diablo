extends Node2D
## A waystone (zz_zz_maw95.js): a ruined ring of eight fang-shaped standing stones round a sunken dais; steps go down
## into a pit. At the bottom, under a crust of old ash, something dark and wet lies and breathes. Ancient stone with
## traces of biology: stains seep from the plinths, a pale fibre runs into the earth. Not a mouth. Nothing glows.
## A waystone that does not know you is crusted shut; one that knows you has its crust fallen in.
## Three layers, drawn in the web's world px (x4): the dais and pit on the floor, the stones behind the hero, the stones
## in front of the hero (so he stands inside the ring).

const RX := 24.0
const RY := 12.0
const STONE := [Color8(0x12, 0x10, 0x16), Color8(0x1c, 0x19, 0x1e), Color8(0x28, 0x23, 0x28), Color8(0x35, 0x30, 0x33), Color8(0x45, 0x3e, 0x3d), Color8(0x58, 0x50, 0x49)]
const MOSS := Color8(0x27, 0x33, 0x2a)
const CRUST := [Color8(0x2a, 0x26, 0x22), Color8(0x3a, 0x34, 0x2e), Color8(0x4a, 0x43, 0x3a)]
const FLESH := [Color8(0x0c, 0x05, 0x06), Color8(0x17, 0x0a, 0x0b), Color8(0x22, 0x10, 0x11), Color8(0x2e, 0x16, 0x16)]
const VEIN := Color8(0x3e, 0x24, 0x22)
const SHEEN := Color(170 / 255.0, 140 / 255.0, 130 / 255.0, 0.28)

var o: Dictionary
var tp := Vector2.ZERO
var zid := ""
var open := 0.0      # 0 crusted shut .. 1 the crust fallen in
var t := 0.0
var widen := 0.0     # the throat widening while someone passes
var held := false    # the passage drives open/widen
var floor_n: Node2D
var back_n: Node2D
var front_n: Node2D

class Layer extends Node2D:
	var ws
	var part := 0    # 0 floor, 1 back stones, 2 front stones
	var off := Vector2.ZERO
	func _draw() -> void:
		draw_set_transform(off, 0.0, Vector2(Iso.WPX, Iso.WPX))
		if part == 0:
			ws._draw_base(self)
		else:
			ws._draw_stones(self, part == 2)

func setup(zone: Zone, obj: Dictionary, known: bool) -> void:
	o = obj
	zid = zone.id
	tp = Vector2(obj["x"], obj["y"])
	t = randf() * 10.0
	open = 1.0 if known else 0.0
	var p := Iso.to_screen(tp)
	floor_n = _layer(0, p, Vector2.ZERO)
	zone.floor_layer.add_child(floor_n)
	floor_n.z_index = 2
	back_n = _layer(1, p + Vector2(0, -0.95 * Iso.HY), Vector2(0, 0.95 * Iso.HY))
	zone.sorted.add_child(back_n)
	front_n = _layer(2, p + Vector2(0, 0.95 * Iso.HY), Vector2(0, -0.95 * Iso.HY))
	zone.sorted.add_child(front_n)

func _layer(part: int, pos: Vector2, off: Vector2) -> Node2D:
	var l := Layer.new()
	l.ws = self
	l.part = part
	l.off = off
	l.position = pos
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l

func tick(dt: float, known: bool) -> void:
	t += dt
	if not held:
		open += ((1.0 if known else 0.0) - open) * minf(1.0, dt * 1.2)
	for n in [floor_n, back_n, front_n]:
		if is_instance_valid(n):
			n.queue_redraw()

func _exit_tree() -> void:
	for n in [floor_n, back_n, front_n]:
		if is_instance_valid(n):
			n.queue_free()

static func H(a: int, b: int) -> float:
	return Zone.hash2(a * 13 + 7, b * 29 + 3)

# ------------------------------------------------------------------ drawing helpers (world px)
static func _ell(c: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, n: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / n * TAU
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	c.draw_colored_polygon(pts, col)

static func _ell_line(c: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, n: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := float(i) / n * TAU
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	c.draw_polyline(pts, col, 1.0)

static func _quad(a: Vector2, ctrl: Vector2, b: Vector2, n: int, out: PackedVector2Array) -> void:
	for i in range(1, n + 1):
		var k := float(i) / n
		out.append(a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k))

static func _rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(roundf(x), roundf(y), w, h), col)

# ------------------------------------------------------------------ the dais and the pit
func _draw_base(c: CanvasItem) -> void:
	var cx := 0.0
	var cy := 0.0
	var ox := int(o["x"])
	var oy := int(o["y"])
	# the dais: a ring of flagstones
	for i in 16:
		var a0 := float(i) / 16.0 * TAU
		var a1 := float(i + 1) / 16.0 * TAU
		var h := H(i, ox)
		var q := PackedVector2Array([
			Vector2(cx + cos(a0) * (RX + 4), cy + sin(a0) * (RY + 2)), Vector2(cx + cos(a1) * (RX + 4), cy + sin(a1) * (RY + 2)),
			Vector2(cx + cos(a1) * (RX - 3), cy + sin(a1) * (RY - 1.5)), Vector2(cx + cos(a0) * (RX - 3), cy + sin(a0) * (RY - 1.5))])
		c.draw_colored_polygon(q, STONE[1 + int(h * 3.0)])
		_rect(c, cx + cos(a0) * (RX + 1), cy + sin(a0) * (RY + 0.5), 1, 1, STONE[0])
	# steps down: two darker rings
	_ell(c, cx, cy + 1, RX - 4, RY - 2, STONE[1])
	_ell(c, cx, cy + 2, RX - 8, RY - 4, STONE[0])
	# the bottom: dark and wet; it swells and settles very slowly
	var br := 0.5 + 0.5 * sin(t * 0.5)
	var rx := RX - 10 + widen
	var ry := (RY - 5) + widen * 0.5
	_ell(c, cx, cy + 2, rx, ry, FLESH[1])
	var sw := 0.6 + br * 0.9
	_ell(c, cx, cy + 2 - sw * 0.4, maxf(1, rx - 3 + sw), maxf(1, ry - 1.5 + sw * 0.4), FLESH[2])
	# thin dark veins running in from the edge
	for i in 4:
		var a := i * 1.7 + 0.6
		var p0 := Vector2(roundf(cx + cos(a) * rx) + 0.5, roundf(cy + 2 + sin(a) * ry) + 0.5)
		var pts := PackedVector2Array([p0])
		_quad(p0, Vector2(cx + cos(a + 0.6) * rx * 0.4, cy + 2 + sin(a + 0.6) * ry * 0.4), Vector2(cx + 0.5, cy + 2.5), 8, pts)
		c.draw_polyline(pts, VEIN, 1.0)
	# one slow ridge travelling inward
	var f := fmod(t * 0.18, 1.0)
	var rr := 1.0 - f
	_ell_line(c, cx, cy + 2, maxf(0.5, rx * rr), maxf(0.5, ry * rr), FLESH[3])
	# a wet sheen that comes and goes
	if br > 0.55:
		_rect(c, cx - rx * 0.4, cy + 2 - ry * 0.45, maxf(2, roundf(rx * 0.5)), 1, SHEEN)
	# the ash crust: whole when it does not know you, broken open when it does
	var crust := 1.0 - open
	if crust > 0.02:
		for i in 18:
			var a := float(i) / 18.0 * TAU
			var h := H(i, 55 + oy)
			var r2 := 0.25 + h * 0.75
			if h > crust + 0.15:
				continue
			_rect(c, cx + cos(a) * rx * r2 - 2, cy + 2 + sin(a) * ry * r2 - 1, 4 + int(h * 3), 2, CRUST[int(h * 3.0)])
		if crust > 0.6:
			_ell(c, cx, cy + 2, maxf(1, rx - 2), maxf(1, ry - 1), CRUST[1])
			_rect(c, cx - 3, cy + 2, 5, 1, FLESH[1])   # one dark crack in the crust
			_rect(c, cx + 1, cy + 3, 1, 2, FLESH[1])

# ------------------------------------------------------------------ the ring: eight shrine-stones cut like fangs
func _draw_stones(c: CanvasItem, front: bool) -> void:
	var cx := 0.0
	var cy := 0.0
	var n := 8
	for i in n:
		var a := float(i) / n * TAU + 0.2
		var sn := sin(a)
		if (sn > 0.0) != front:
			continue
		var h := H(i, int(o["x"]) + int(o["y"]))
		var bx := roundf(cx + cos(a) * (RX + 6))
		var by := roundf(cy + sin(a) * (RY + 3))
		# the plinth: a squared block, lit on top
		_rect(c, bx - 5, by - 3, 10, 4, STONE[0])
		_rect(c, bx - 5, by - 3, 10, 1, STONE[3])
		_rect(c, bx - 4, by - 2, 8, 2, STONE[2])
		# a stain seeping from the plinth into the ground
		if h > 0.45:
			_rect(c, bx - 2, by + 1, 3 + int(h * 3), 1, Color(46 / 255.0, 14 / 255.0, 16 / 255.0, 0.75))
			_rect(c, bx - 1, by + 2, 2, 1, Color(46 / 255.0, 14 / 255.0, 16 / 255.0, 0.75))
			_rect(c, bx + 1, by + 3, 2, 1, Color(46 / 255.0, 14 / 255.0, 16 / 255.0, 0.45))
		if h > 0.7:   # a pale fibre into the earth
			_rect(c, bx + 4, by, 1, 1, Color(150 / 255.0, 130 / 255.0, 112 / 255.0, 0.5))
			_rect(c, bx + 5, by + 1, 2, 1, Color(150 / 255.0, 130 / 255.0, 112 / 255.0, 0.5))
		if i == 5:   # the fallen one: its fang lies across the dais edge
			_rect(c, bx - 11, by - 4, 13, 4, STONE[0])
			_rect(c, bx - 11, by - 4, 11, 1, STONE[3])
			_rect(c, bx - 10, by - 3, 10, 2, STONE[2])
			_rect(c, bx - 7, by - 3, 1, 2, STONE[1])
			_rect(c, bx - 4, by - 3, 1, 2, STONE[1])
			continue
		# the fang: tapering, curved in toward the pit
		var ht := roundf(12 + h * 9)
		var w := 3.5 + (0.8 if h > 0.5 else 0.0)
		var dx := (cx - bx) / (RX + 6)
		var lean := 3 + h * 2
		var tipx := bx + dx * lean
		var tipy := by - 3 - ht
		var mx := bx + dx * lean * 0.3
		var my := by - 3 - ht * 0.55
		var p := PackedVector2Array([Vector2(bx - w - 1, by - 2)])
		_quad(Vector2(bx - w - 1, by - 2), Vector2(mx - w, my), Vector2(tipx - 0.8, tipy - 1), 6, p)
		p.append(Vector2(tipx + 0.8, tipy - 1))
		_quad(Vector2(tipx + 0.8, tipy - 1), Vector2(mx + w + 1, my), Vector2(bx + w + 1, by - 2), 6, p)
		c.draw_colored_polygon(p, STONE[0])
		p = PackedVector2Array([Vector2(bx - w, by - 3)])
		_quad(Vector2(bx - w, by - 3), Vector2(mx - w + 0.5, my), Vector2(tipx - 0.4, tipy), 6, p)
		p.append(Vector2(tipx + 0.4, tipy))
		_quad(Vector2(tipx + 0.4, tipy), Vector2(mx + w, my), Vector2(bx + w, by - 3), 6, p)
		c.draw_colored_polygon(p, STONE[2])
		# the lit face, a little paler than stone should be
		p = PackedVector2Array([Vector2(bx - w + 0.6, by - 3)])
		_quad(Vector2(bx - w + 0.6, by - 3), Vector2(mx - w + 1, my), Vector2(tipx - 0.3, tipy + 0.5), 6, p)
		p.append(Vector2(bx - 0.5, by - 3))
		c.draw_colored_polygon(p, Color8(0x6f, 0x67, 0x5b) if h > 0.6 else STONE[4])
		# carved bands and a channel down the face: somebody made these
		for fk: float in [0.28, 0.52]:
			var yy := roundf(by - 3 - ht * fk)
			var xx := bx + dx * lean * fk * 0.6
			var ww := w * (1 - fk * 0.7)
			_rect(c, xx - ww, yy, roundf(ww * 2), 1, STONE[1])
			_rect(c, xx - ww, yy - 1, roundf(ww), 1, STONE[5])
		_rect(c, bx + dx * 0.5, by - 3 - ht * 0.72, 1, roundf(ht * 0.4), STONE[1])
		# near the tip the stone darkens as if wet; a thin dark line in the channel runs down to the plinth
		if h > 0.3:
			_rect(c, tipx - 1, tipy + 1, 2, 3, Color(40 / 255.0, 16 / 255.0, 16 / 255.0, 0.55))
			_rect(c, bx + dx * 0.5, by - 3 - ht * 0.3, 1, roundf(ht * 0.3), Color(40 / 255.0, 14 / 255.0, 15 / 255.0, 0.5))
		if h > 0.5:
			_rect(c, bx - roundf(w), by - 5, 2, 2, MOSS)
