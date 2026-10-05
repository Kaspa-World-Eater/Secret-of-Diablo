extends RefCounted
## fx/flame.gd: every flame's own life, as the web gives it. Load by path: load("res://fx/flame.gd").
## - flame55 (zz_grade55.js:88-106): drift, tremble, and now and then a gutter or a flare, each flame on its own schedule
##   (the timeline cut into 4.1 s windows; about half hold one event).
## - eased over about a fifth of a second (zz_zz_light79.js:11-20): the slow swells and gutters stay, the flutter goes.
## - dither_glow (y_light21.js:212-221): a round glow whose alpha is stepped into four levels and Bayer-dithered, so
##   flames glow in pixel rings. dither_puff (y_light21.js:400-409): a smoke puff in two dithered levels.
## Textures are one texel per web px; draw them 4x, nearest.

const BAY4 := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _glow := {}
static var _puff := {}
static var _sm := {}

## the web's hash (b_core.js:103), 0..1
static func hash2(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967295.0

static func _vn(t: float, s: int) -> float:
	var i := int(floor(t))
	var f := t - i
	var u := f * f * (3.0 - 2.0 * f)
	return hash2(i * 7 + 3, s) * (1.0 - u) + hash2(i * 7 + 10, s) * u

static func flame55(t: float, seed: float) -> float:
	var s := int(seed * 131.0) + 7
	var f := 1.0 + 0.016 * sin(t * 1.3 + seed * 1.7) + 0.012 * sin(t * 2.7 + seed * 0.61) + 0.05 * (_vn(t * 0.7, s + 11) - 0.5) \
		+ 0.05 * (_vn(t * 9.0, s) - 0.5) + 0.025 * (_vn(t * 23.0, s + 3) - 0.5)
	var T := t + seed * 3.1
	var W0 := 4.1
	var w := int(floor(T / W0))
	if hash2(w * 13 + 5, s) < 0.5:
		var at := hash2(w * 5 + 3, s + 17) * (W0 - 0.8)
		var u := T - w * W0 - at
		if u > 0.0 and u < 0.75:
			var gutter := hash2(w * 11 + 1, s + 5) < 0.78
			var depth := 0.16 + 0.16 * hash2(w, s + 9) if gutter else 0.09
			var env := u / 0.06 if u < 0.06 else pow(maxf(0.0, 1.0 - (u - 0.06) / 0.69), 1.6)
			var shake := 1.0 + 0.45 * sin(u * 55.0 + seed) * env
			f += (-1.0 if gutter else 1.0) * depth * env * shake
	return f

## the flame, eased (one state per seed)
static func smooth(seed: float) -> float:
	var fr := Engine.get_process_frames()
	var memo: Array = _sm.get(seed, [])
	if memo.size() > 2 and int(memo[2]) == fr:
		return memo[0]   # asked again this frame
	var t := Time.get_ticks_msec() / 1000.0   # one clock for every caller (the state is shared per flame)
	var raw := flame55(t, seed)
	var s: Array = _sm.get(seed, [])
	if s.is_empty():
		_sm[seed] = [raw, t, fr]
		return raw
	var dt := clampf(t - float(s[1]), 0.0, 0.2)
	s[1] = t
	s[0] = float(s[0]) + (raw - float(s[0])) * (1.0 - exp(-dt * 5.0))
	if s.size() > 2:
		s[2] = fr
	else:
		s.append(fr)
	return s[0]

static func dither_glow(r: int, col: Color) -> Texture2D:
	r = maxi(2, int(round(r / 2.0)) * 2)
	var key := "%d|%s" % [r, col.to_html(false)]
	if _glow.has(key):
		return _glow[key]
	var n := r * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var dd := Vector2(i - r, j - r).length() / r
			if dd >= 1.0:
				continue
			var v := (1.0 - dd) * (1.0 - dd) * 4.0
			var b := (float(BAY4[((j & 3) << 2) + (i & 3)]) + 0.5) / 16.0
			var lv := int(v) + (1 if (v - int(v) - 0.25) * 2.0 > b else 0)
			if lv <= 0:
				continue
			img.set_pixel(i, j, Color(col.r, col.g, col.b, minf(255.0, lv * 60.0) / 255.0))
	var tex := ImageTexture.create_from_image(img)
	_glow[key] = tex
	return tex

static func dither_puff(r: int, col: Color) -> Texture2D:
	r = clampi(r, 1, 14)
	var key := "%d|%s" % [r, col.to_html(false)]
	if _puff.has(key):
		return _puff[key]
	var n := r * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var dd := Vector2(i - r, (j - r) * 1.15).length() / (r + 0.5)
			if dd >= 1.0:
				continue
			var v := (1.0 - dd * dd) * 2.0 + (hash2(i * 3 + r, j * 5) - 0.5) * 0.5
			var b := (float(BAY4[((j & 3) << 2) + (i & 3)]) + 0.5) / 16.0
			var lv := clampi(int(v) + (1 if (v - int(v) - 0.3) * 2.5 > b else 0), 0, 2)
			if lv == 0:
				continue
			var sh := 1.08 if j < r else 0.92
			img.set_pixel(i, j, Color(minf(1.0, col.r * sh), minf(1.0, col.g * sh), minf(1.0, col.b * sh), 130.0 / 255.0 if lv == 1 else 1.0))
	var tex := ImageTexture.create_from_image(img)
	if _puff.size() > 300:
		_puff.clear()
	_puff[key] = tex
	return tex
