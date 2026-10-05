class_name Lights
extends RefCounted
## Soft light textures made once and shared.

static var _cache := {}

static func radial(size: int) -> Texture2D:
	if _cache.has(size):
		return _cache[size]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	g.add_point(0.7, Color(1, 1, 1, 0.12))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	_cache[size] = t
	return t

## The web's dark layer (zz_zx_dark64.js, zz_zz_cine76.js): a light is a pool on the ground, an iso ellipse twice as
## wide as it is tall; its light falls in stepped bands (a bright core, three rings, a faint ring) whose edges are
## dithered in 4-px cells, never smooth. One texture is baked and shared; texture_scale sets the radius.
const POOL_W := 1440
const POOL_H := 720
const BANDS := [[0.42, 1.0], [0.6, 0.8], [0.75, 0.6], [0.87, 0.4], [0.96, 0.2], [1.0, 0.0]]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static func pool(_size: int = 0) -> Texture2D:
	if _cache.has("pool"):
		return _cache["pool"]
	var data := PackedByteArray()
	data.resize(POOL_W * POOL_H * 2)
	var cx := POOL_W * 0.5
	var cy := POOL_H * 0.5
	var i := 0
	for y in POOL_H:
		var dy := (y + 0.5 - cy) / cy
		for x in POOL_W:
			var dx := (x + 0.5 - cx) / cx
			var r := sqrt(dx * dx + dy * dy)
			var v := 0.0
			var th := float(BAYER[((y >> 2) & 3) * 4 + ((x >> 2) & 3)]) / 16.0
			var prev := 1.0
			for bd in BANDS:
				var edge: float = bd[0]
				if r < edge:
					# dither the last 5% of each band toward the next one
					var w := 0.05
					var t2 := (r - (edge - w)) / w
					v = prev if (t2 <= 0.0 or t2 < th) else float(bd[1])
					break
				prev = float(bd[1])
			var b8 := int(clampf(v, 0.0, 1.0) * 255.0)
			data[i] = 255
			data[i + 1] = b8
			i += 2
	var img := Image.create_from_data(POOL_W, POOL_H, false, Image.FORMAT_LA8, data)
	var t := ImageTexture.create_from_image(img)
	_cache["pool"] = t
	return t

## a soft elliptical glow for small things (wisps, candles): smooth, no bands
static func soft(_size: int = 0) -> Texture2D:
	if _cache.has("soft"):
		return _cache["soft"]
	var w := 256
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_LA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			var v := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v * v))
	var t := ImageTexture.create_from_image(img)
	_cache["soft"] = t
	return t

## a lantern or fire light that breathes and flickers a little
static func flicker(parent: Node, pos: Vector2, col: Color, energy: float, scale: float, shadows: bool = false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = pool()
	l.color = col
	l.energy = energy
	l.texture_scale = scale
	l.position = pos
	l.shadow_enabled = shadows
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_color = Color(0, 0, 0, 0.75)
	l.set_script(load("res://fx/flicker.gd"))
	parent.add_child(l)
	return l
