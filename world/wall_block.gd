class_name WallBlock
extends Node2D
## A cliff, dungeon wall or ruin cell: an iso block with two lit faces and a top, textured with the painted wtex
## textures at 3 texels per world px, mirrored-tiling, following the face slope (zz_walls63.js). Palisades are stakes.

var tile := Vector2i.ZERO
var kind := "cliff"
var height := 256.0
var face_tex: Texture2D
var top_tex: Texture2D
var show_left := true
var show_right := true
var along := Vector2i(1, 0)   # palisade: which way the fence runs (x, y; both at a corner)
var fade := 1.0
var _fade_to := 1.0

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_cut(on: bool) -> void:
	_fade_to = 0.28 if on else 1.0

func _process(dt: float) -> void:
	if absf(fade - _fade_to) > 0.01:
		fade = move_toward(fade, _fade_to, dt * 3.0)
		modulate.a = fade
		set_process(true)
	elif fade == _fade_to:
		set_process(false)

func _uv_face(p: Vector2, slope: float) -> Vector2:
	# world px of the global point, then 3 texels per world px over a 122 px texture
	var g := (global_position + p) / Iso.WPX
	return Vector2(g.x * 3.0 / 122.0, (g.y + slope * g.x * 0.5) * 3.0 / 122.0)

func _uv_top(p: Vector2) -> Vector2:
	var g := (global_position + p) / Iso.WPX
	return Vector2(g.x * 3.0 / 122.0, g.y * 3.0 / 122.0)

func _draw() -> void:
	var N := Vector2(0, -Iso.HY)
	var E := Vector2(Iso.HX, 0)
	var S := Vector2(0, Iso.HY)
	var W := Vector2(-Iso.HX, 0)
	var H := Vector2(0, -height)
	if kind == "palisade":
		_stakes()
		return
	var lc := Color(0.6, 0.58, 0.56)
	var rc := Color(0.8, 0.78, 0.75)
	if show_left:
		var pts := PackedVector2Array([W, S, S + H, W + H])
		if face_tex:
			draw_polygon(pts, PackedColorArray([lc, lc, lc, lc]), PackedVector2Array(Array(pts).map(func(p): return _uv_face(p, -1.0))), face_tex)
		else:
			draw_colored_polygon(pts, Color(0.16, 0.15, 0.14))
	if show_right:
		var pts2 := PackedVector2Array([S, E, E + H, S + H])
		if face_tex:
			draw_polygon(pts2, PackedColorArray([rc, rc, rc, rc]), PackedVector2Array(Array(pts2).map(func(p): return _uv_face(p, 1.0))), face_tex)
		else:
			draw_colored_polygon(pts2, Color(0.22, 0.2, 0.19))
	var top := PackedVector2Array([N + H, E + H, S + H, W + H])
	if top_tex:
		# the web lays the texture over the block's own dark colour (70% base, the texture only for grain): pale stone tops
		# must read as shadowed stone, not bright paving
		var tc := Color(0.46, 0.44, 0.45) if top_tex.resource_path.contains("top_stone") else Color(0.85, 0.85, 0.85)
		draw_polygon(top, PackedColorArray([tc, tc, tc, tc]), PackedVector2Array(Array(top).map(func(p): return _uv_top(p))), top_tex)
	elif face_tex:
		draw_polygon(top, PackedColorArray([Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.9)]), PackedVector2Array(Array(top).map(func(p): return _uv_top(p))), face_tex)
	# a dark line where the faces meet the ground and each other
	draw_line(W, S, Color(0, 0, 0, 0.5), 2.0)
	draw_line(S, E, Color(0, 0, 0, 0.5), 2.0)
	draw_line(S, S + H, Color(0, 0, 0, 0.25), 1.0)

## the browser's palisade (zt_env32.js ztPalisade): four posts along the fence's run (both runs at a corner), each a
## leaning sharpened log in pale or dark wood, two rope lashings across them, now and then a skull on a point or a cord
## hanging down. Every choice is the web's hash of the tile, so a fence looks the same each time it is built.
const WOOD := [Color("#2d1e12"), Color("#4d341f"), Color("#6e4c2e"), Color("#946c46")]
const WOODD := [Color("#22170e"), Color("#3a2818"), Color("#553a24"), Color("#6e4c2e")]
const SKULL := [".1331.", "134431", "300403", "334433", ".3033."]
const SKULLC := [Color("#1e1818"), Color("#4a3f36"), Color("#76674f"), Color("#a2916f"), Color("#c4b28c")]

func _stakes() -> void:
	var H2 := func(a: float, b: float) -> float: return Zone.hash2(int(a), int(b))
	var x := tile.x
	var y := tile.y
	var P := Iso.WPX
	var posts: Array = []
	var line := func(dx: float, dy: float):
		for k in 4:
			var t := (k + 0.5) / 4.0 - 0.5
			posts.append(Vector2(0.5 + dx * t, 0.5 + dy * t))
	if along.x != 0 or along.y == 0:
		line.call(1.0, 0.0)
	if along.y != 0:
		line.call(0.0, 1.0)
	posts.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	var tops: Array = []
	for k in posts.size():
		var w0: Vector2 = posts[k]
		# the post's foot, from the tile's centre (the web draws a fence 12 px a half-tile across, its posts kept inward)
		var base := Vector2((w0.x - w0.y) * 12.0, (w0.x + w0.y - 1.0) * 6.0) * P
		var hh: float = (30.0 + H2.call(x * 7 + k, y * 3 + k) * 10.0) * P
		var r: float = (2.2 + H2.call(k, x + y) * 0.6) * P
		var lean: float = (H2.call(x + k * 3, y) - 0.5) * 2.0 * P
		var pal: Array = WOODD if H2.call(k * 5, x * y + 1) < 0.35 else WOOD
		var top := base + Vector2(lean, -hh)
		# the log: a dark side, a lit side, a pale stripe where the light finds it
		draw_colored_polygon(PackedVector2Array([base + Vector2(-r, 0), base + Vector2(r, 0), top + Vector2(r * 0.95, 0), top + Vector2(-r * 0.95, 0)]), pal[1])
		draw_colored_polygon(PackedVector2Array([base + Vector2(-r, 0), base + Vector2(-r * 0.2, 0), top + Vector2(-r * 0.2, 0), top + Vector2(-r * 0.95, 0)]), pal[2])
		draw_line(base + Vector2(-r * 0.55, 0), top + Vector2(-r * 0.55, 0), pal[3], P * 0.5)
		draw_line(base + Vector2(r * 0.8, 0), top + Vector2(r * 0.8, 0), pal[0], P * 0.5)
		# the sharpened point
		var tip: float = (5.0 + H2.call(k, y) * 2.0) * P
		draw_colored_polygon(PackedVector2Array([top + Vector2(-r, P), top + Vector2(r, P), top + Vector2(0.3 * P, -tip)]), pal[1])
		draw_colored_polygon(PackedVector2Array([top + Vector2(-r, P), top + Vector2(-r * 0.1, P), top + Vector2(0.3 * P, -tip)]), pal[2])
		tops.append([top, base])
	# two lashings of rope across the posts
	for hy in [8.0, 22.0]:
		var pts := PackedVector2Array()
		for q in tops:
			var b2: Vector2 = q[1]
			pts.append(b2 + Vector2(0, -hy * P))
		if pts.size() > 1:
			draw_polyline(pts, Color("#5e4c32"), P * 0.8)
			draw_polyline(pts, Color("#3a2e1e"), P * 0.3)
	# the odd skull on a point, the odd cord hanging down
	for k in tops.size():
		var tp: Vector2 = tops[k][0]
		if H2.call(x * 3 + k, y * 11) < 0.12:
			for j in 5:
				for i in 6:
					var ch: String = SKULL[j][i]
					if ch != ".":
						draw_rect(Rect2(tp + Vector2(-3 + i, -9 + j) * P, Vector2(P, P)), SKULLC[int(ch)])
		elif H2.call(x + k * 7, y * 3) < 0.08:
			for j in 7:
				var off := 1 if j > 3 else 0
				draw_rect(Rect2(tp + Vector2(1 + off, 3 + j) * P, Vector2(P, P)), Color("#5a4a3a") if j % 3 else Color("#3a2e24"))
