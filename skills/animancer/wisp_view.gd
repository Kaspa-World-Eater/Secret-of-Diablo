extends Node2D
## A wisp of the choir (or the great wisp, or a lantern's wisp) standing in the y-sorted layer, drawn live as the web
## draws it (zz_zx_dark64.js:158-206, v0.66-v0.80): a soft spot of pale light, a bright 2x2 heart in a small breathing
## halo, trailing a thin ghostly wake (the places it has been, fading, curling up and apart like breath in cold air) and
## shedding single motes of dust that twinkle, sink and fade. Everything is laid on the art grid (1 web px = 4 px here),
## added to what is under it. Each wisp opens two small pools in the dark (one on the ground, one round its own body) and
## casts no shadow.

const COL := {"rev": Color8(196, 226, 240), "beam": Color8(236, 222, 190), "prism": Color8(214, 204, 236)}
const PX := 4.0
static var _halo := {}           # radius (web px) -> the radial gradient as a texture, one texel per web px

var w                            # the wisp's state (animancer base.gd Wisp): tp, z, gone, scale, alpha, wt
var kind := "rev"
var col := COL["rev"]
var lamp: PointLight2D           # the pool on the ground under it
var body: PointLight2D           # the small pool round its own body, so the dark never swallows it
var t := 0.0
var wake: Array = []             # [tp, z, born, s]
var wake_last := -1.0
var dust: Array = []             # [tp, z, ox, born, life, s]
var dust_last := 0.0

func setup(wisp, k: String = "wisp_rev") -> void:
	w = wisp
	w.node = self
	kind = k.trim_prefix("wisp_")
	col = COL.get(kind, COL["rev"])
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamp = _pool(21.0, 0.25, 1.5, 0.5)
	body = _pool(12.0, 0.3, 1.4, 0.4)
	t = randf() * 8.0
	_place()

func _pool(r: float, core: float, far: float, wd: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Lights.radial(64)
	l.color = col
	l.energy = 0.45
	l.shadow_enabled = false
	l.set_meta("dark_r", r)
	l.set_meta("dark_core", core)
	l.set_meta("dark_far", far)
	l.set_meta("dark_w", wd)
	add_child(l)
	return l

static func halo(r: int) -> Texture2D:
	if _halo.has(r):
		return _halo[r]
	var n := r * 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length() / float(r)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(0.0, 1.0 - d)))
	var tex := ImageTexture.create_from_image(img)
	_halo[r] = tex
	return tex

func _ph() -> float:
	return float(w.wt) * 5.0

func _place() -> void:
	position = Iso.to_screen(w.tp)
	var ph := _ph()
	var bob := sin(t * 1.3 + ph) * 1.2
	# the ground pool breathes; the body pool sits at the wisp's height
	lamp.set_meta("dark_r", 21.0 * (0.85 + 0.15 * sin(t * 2.3 + ph)) * w.scale)
	lamp.position = Vector2(0, PX)
	body.set_meta("dark_r", 12.0 * w.scale)
	body.position = Vector2(0, -(w.z - bob) * PX)
	modulate.a = w.alpha

func _process(dt: float) -> void:
	if w == null or w.gone or w.node != self:
		queue_free()
		return
	t += dt
	# the wake: a point every 28 ms, kept 0.9 s
	if t - wake_last > 0.028:
		wake_last = t
		wake.append([w.tp, float(w.z), t, randf() * TAU])
	while wake.size() and t - float(wake[0][2]) > 0.9:
		wake.pop_front()
	# the dust: a mote every 0.09 s (seven in ten), at most 14, each 0.7-1.5 s
	var bob := sin(t * 1.3 + _ph()) * 1.2
	if t - dust_last > 0.09 and dust.size() < 14:
		dust_last = t
		if randf() < 0.7:
			dust.append([w.tp, float(w.z) + bob + (randf() - 0.5) * 3.0, (randf() - 0.5) * 5.0, t, 0.7 + randf() * 0.8, randf() * TAU])
	for i in range(dust.size() - 1, -1, -1):
		if t - float(dust[i][3]) >= float(dust[i][4]):
			dust.remove_at(i)
	_place()
	queue_redraw()

## a web-px point (relative to the wisp's foot, in web px) laid on the art grid, in this node's px
func _grid(wx: float, wy: float) -> Vector2:
	var g := global_position
	var p := Vector2(round((g.x + wx * PX) / PX) * PX, round((g.y + wy * PX) / PX) * PX)
	return p - g

func _cell(wx: float, wy: float, c: Color, a: float, cw := 1.0, ch := 1.0) -> void:
	var p := _grid(wx, wy)
	draw_rect(Rect2(p, Vector2(cw * PX, ch * PX)), Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))

func _glow(wx: float, wy: float, r: float, a: float) -> void:
	var ri := maxi(1, int(round(r)))
	var p := _grid(wx - ri, wy - ri)
	draw_texture_rect(halo(ri), Rect2(p, Vector2(ri * 2, ri * 2) * PX), false, Color(col.r, col.g, col.b, a))

func _draw() -> void:
	if w == null:
		return
	var ph := _ph()
	var bob := sin(t * 1.3 + ph) * 1.2
	var br := 0.72 + 0.28 * sin(t * 2.3 + ph) * sin(t * 5.1 + ph * 0.7)
	var me := Iso.to_screen(w.tp) / PX
	var sc: float = w.scale
	# the wake: older points rise and spread and fade
	for q in wake:
		var age := t - float(q[2])
		var k := 1.0 - age / 0.9
		if k <= 0.0:
			continue
		var pp: Vector2 = Iso.to_screen(q[0]) / PX - me
		var x := pp.x + sin(float(q[3]) + age * 4.0) * age * 3.0
		var y := pp.y - float(q[1]) + bob - age * 6.0
		_cell(x, y, col, 0.34 * k * k * br)
		if k > 0.6:
			_cell(x + 1.0, y, col, 0.12 * k * br)
	# the dust: single motes that twinkle and sink
	for m in dust:
		var a := t - float(m[3])
		var k := 1.0 - a / float(m[4])
		var pp: Vector2 = Iso.to_screen(m[0]) / PX - me
		var tw := 0.5 + 0.5 * sin(float(m[5]) * 3.0 + a * 14.0)
		_cell(pp.x + float(m[2]) + sin(float(m[5]) + a * 2.0) * 1.2, pp.y - float(m[1]) + a * 5.0, Color.WHITE if tw > 0.85 else col, 0.55 * k * tw)
	# the light itself: a wide soft halo, a slow breath, the heart
	var sy := -float(w.z) + bob
	var eb := 0.8 + 0.2 * sin(t * 1.1 + ph)
	_glow(1.0, sy + 1.0, 18.0 * sc, 0.12 * br * eb)
	_glow(1.0, sy + 1.0, 10.0 * sc, 0.3 * br)
	_glow(1.0, sy + 1.0, 5.0 * sc, 0.45 * br)
	var hc := Color(minf(1.0, col.r + 30.0 / 255.0), minf(1.0, col.g + 25.0 / 255.0), minf(1.0, col.b + 15.0 / 255.0))
	var hs := maxf(2.0, round(2.0 * sc))
	_cell(0.0, sy, hc, 0.95 * br, hs, hs)
	_cell(-1.0, sy, col, 0.35 * br, 1.0, hs)
	_cell(hs, sy, col, 0.35 * br, 1.0, hs)
	_cell(0.0, sy - 1.0, col, 0.35 * br, hs, 1.0)
	_cell(0.0, sy + hs, col, 0.35 * br, hs, 1.0)
