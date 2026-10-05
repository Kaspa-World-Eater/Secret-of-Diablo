extends Node
## ui/bronze.gd: words cast in metal, as the web's title casts them (zz_title54.js:44-122). The letters are set once in
## white in a small off-screen viewport, read back as a mask, and recast pixel by pixel:
## - "title": stepped bronze, six tones from 1a1008 to fae2aa in bands down the letter, a lit lip on edges facing up and
##   left, a dark lip facing down and right, a dark cut bed one step out and a shadow down and right (buildTitle);
## - "label" / "label_bright": old pitted bronze; tarnished letters hold verdigris in their pits, the chosen one is
##   rubbed bright (castLabel).
## S is the web's grid in screen px (4). get(key) returns the texture once it is cast (null until then).

const S := 4
var done := {}
var queue: Array = []
var busy := false

## ask for a casting; returns the texture when ready, else null (and casts it soon)
func cast(key: String, text: String, font: Font, size: int, spacing: int, kind: String, w: int, h: int, base: int) -> Texture2D:
	if done.has(key):
		return done[key]
	for q in queue:
		if q[0] == key:
			return null
	queue.append([key, text, font, size, spacing, kind, w, h, base])
	if not busy:
		_next()
	return null

func _next() -> void:
	if queue.is_empty():
		busy = false
		return
	busy = true
	var q: Array = queue.pop_front()
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(q[6], q[7])
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(q[6], q[7])
	c.draw.connect(_mask.bind(c, q))
	vp.add_child(c)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	done[q[0]] = ImageTexture.create_from_image(_recast(img, q[5], q[8], q[1]))
	_next()

## the letters in white, spaced as the web spaces them
func _mask(c: Control, q: Array) -> void:
	var f: Font = q[2]
	var sz: int = q[3]
	var sp: int = q[4]
	var tw := 0.0
	for ch in String(q[1]):
		tw += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + sp
	tw -= sp
	var x := (float(q[6]) - tw) / 2.0
	for ch in String(q[1]):
		c.draw_string(f, Vector2(x, q[8]), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color.WHITE)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + sp

static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967295.0

func _recast(m: Image, kind: String, base: int, text: String) -> Image:
	var w := m.get_width()
	var h := m.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var A := PackedByteArray()
	A.resize(w * h)
	for j in h:
		for i in w:
			A[j * w + i] = int(m.get_pixel(i, j).a * 255.0)
	var at := func(i: int, j: int) -> int:
		return 0 if i < 0 or j < 0 or i >= w or j >= h else A[j * w + i]
	var title := kind == "title"
	var bright := kind == "label_bright"
	var BZ: Array
	if title:
		BZ = [Color8(26, 16, 8), Color8(61, 37, 18), Color8(112, 70, 34), Color8(168, 116, 58), Color8(224, 180, 108), Color8(250, 226, 170)]
	elif bright:
		BZ = [Color8(27, 16, 8), Color8(61, 37, 18), Color8(112, 70, 34), Color8(168, 116, 58), Color8(214, 164, 96), Color8(240, 210, 150)]
	else:
		BZ = [Color8(40, 26, 14), Color8(96, 64, 34), Color8(146, 104, 58), Color8(182, 138, 82), Color8(208, 166, 104), Color8(226, 190, 130)]
	var VG := Color8(58, 92, 70)
	var top: float = base - (17 if title else 8) * S
	var bot: float = base + S
	var ring: Array = [[S, 0], [-S, 0], [0, S], [0, -S], [-S, -S], [-2 * S, -2 * S]] if title else [[S, 0], [-S, 0], [0, S], [0, -S], [-S, -S], [S, S], [2 * S, 2 * S], [0, 2 * S], [S, 2 * S]]
	var bed := Color(6 / 255.0, 4 / 255.0, 5 / 255.0, 235 / 255.0) if title else Color(5 / 255.0, 3 / 255.0, 3 / 255.0, 245 / 255.0)
	for j in h:
		for i in w:
			if A[j * w + i] > 110:
				var f := (j - top) / (bot - top)
				var k := 0
				if title:
					k = 4 if f < 0.18 else (3 if f < 0.45 else (2 if f < 0.75 else 1))
				else:
					k = 4 if f < 0.2 else (3 if f < 0.5 else (2 if f < 0.8 else 1))
				if at.call(i - S, j - S) < 110:
					k = mini(5, k + 1)
				if at.call(i + S, j + S) < 110:
					k = maxi(0, k - 1)
				var c: Color = BZ[k]
				if not title:
					# pits: the metal is eaten in small cells; tarnished letters hold verdigris in them
					var hs := _hash(int(i / S) * 7 + text.length() * 13, int(j / S) * 11 + 5)
					if hs < (0.05 if bright else 0.08):
						c = VG if not bright and hs < 0.03 else BZ[maxi(1, k - 1)]
				out.set_pixel(i, j, c)
			else:
				for d in ring:
					if at.call(i + d[0], j + d[1]) > 110:
						out.set_pixel(i, j, bed)
						break
	return out
