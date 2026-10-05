extends Node2D
## world/flames.gd: what every flame in a place does besides lighting the ground (y_light21.js, e_ui.js:224).
## - a halo at the flame's own height, a round glow stepped into four Bayer-dithered levels (pixel rings), breathing with
##   the flame (fx/flame.gd): lantern-stones r12 255,170,90 at .5, braziers and fires r16 255,130,60 at .5, sconces r10
##   at .38, candles r8 at .3, wall candles r4 255,190,110 at .14 (y_light21.js:100-107,137);
## - the lantern-post's glass: a soft glow r24 217,190,120 at .4 + .05 sin 5t (e_ui.js:224);
## - embers and smoke off every flame on screen (y_light21.js:336-345): embers climb, slow and cool from white-gold
##   through orange (the web's last two steps are red; by the user's rule they cool to ash instead), smoke rises in
##   dithered puffs that swell and thin, warmed where the flame still lights them.
## The halos live in the world under the dark (the dark opens round each flame); embers and smoke are drawn by
## world/atmos.gd over the dark, as the web draws them in drawAtmos.

const Flame = preload("res://fx/flame.gd")
const PX := 4.0
const EMB_COL := [Color("#fff0b8"), Color("#ffc860"), Color("#ff9038"), Color("#8a6a4a"), Color("#4a4038")]

var zone: Zone
var src: Array = []          # {tp, at (screen px of the flame), kind, seed, rgb}
var posts: Array = []        # lantern-post feet (screen px)
var refl: Node2D             # the lanterns lying in the water (on the floor layer)
var emb: Array = []
var smk: Array = []
var t := 0.0

func bind(z: Zone) -> void:
	zone = z
	z_index = 900
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	src.clear()
	posts.clear()
	if refl == null:
		refl = Node2D.new()
		refl.draw.connect(_draw_refl)
		z.floor_layer.add_child(refl)
	for L in z.d.get("lights", []):
		var tp := Vector2(L["x"], L["y"])
		var seed: float = tp.x * 3.1 + tp.y * 7.7
		match L.get("type", ""):
			"fire":
				var at := Iso.to_screen(tp) + Vector2(float(L.get("dxPx", 0)), -float(L.get("heightPx", 0))) * PX
				src.append({"tp": tp, "at": at, "kind": String(L.get("kind", "fire")), "seed": seed})
			"wallCandle":
				src.append({"tp": tp, "at": Iso.to_screen(tp) + Vector2(0, -float(L.get("heightPx", 20))) * PX, "kind": "wallc", "seed": seed})
	for o in z.objects:
		if o.get("type", "") == "lantern":
			posts.append(Iso.to_screen(Vector2(o["x"], o["y"])))

func _halo_of(kind: String) -> Array:
	# [r web px, colour, alpha]
	match kind:
		"lantern":
			return [12, Color8(255, 170, 90), 0.5]
		"candles":
			return [8, Color8(255, 130, 60), 0.3]
		"sconce":
			return [10, Color8(255, 130, 60), 0.38]
		"wallc":
			return [4, Color8(255, 190, 110), 0.14]
	return [16, Color8(255, 130, 60), 0.5]

var _view := Rect2()          # the screen, in world px, this frame
const WispView = preload("res://skills/animancer/wisp_view.gd")

func _on_screen(p: Vector2, m: float) -> bool:
	return _view.grow(m).has_point(p)


func _process(dt: float) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	t += dt
	var ixf := get_viewport().get_canvas_transform().affine_inverse()
	_view = Rect2(ixf * Vector2.ZERO, Vector2.ZERO).expand(ixf * get_viewport_rect().size)
	# embers and smoke from every flame on screen (none on a slower machine)
	var w2 := sin(t * 0.37) * 4.0 + 3.0
	for s in ([] if Settings.fewer_fx else src):
		var at: Vector2 = s["at"]
		if not _on_screen(at, 160.0):
			continue
		var k: String = s["kind"]
		var er: float = {"brazier": 7.0, "fire": 5.0, "pyre": 5.0, "sconce": 3.0, "lantern": 0.8}.get(k, 0.5)
		if randf() < er * dt and emb.size() < 160:
			emb.append({"p": at + Vector2((randf() - 0.5) * (8.0 if k == "brazier" else 3.0), -2.0) * PX, "vx": (randf() - 0.5) * 8.0, "vy": -(14.0 + randf() * 22.0),
				"t": 0.0, "life": 0.9 + randf() * (2.6 if k in ["brazier", "fire", "pyre"] else 1.2), "s": randf() * TAU})
		var sr: float = {"brazier": 7.0, "fire": 3.5, "pyre": 3.5, "sconce": 2.4, "candles": 0.8}.get(k, 0.0)
		if randf() < sr * dt and smk.size() < 110:
			smk.append({"p": at + Vector2((randf() - 0.5) * 3.0, -5.0) * PX, "vx": w2 * 0.5 + (randf() - 0.5) * 3.0, "vy": -(7.0 + randf() * 6.0), "t": 0.0,
				"life": (4.5 if k == "brazier" else 3.0) + randf() * 3.0, "r0": 1.5 if k == "candles" else (3.5 if k == "brazier" else 2.5), "s": randf() * TAU, "src": k})
	for e in emb:
		e["t"] += dt
		e["vy"] *= 1.0 - 0.35 * dt
		e["p"] += Vector2(e["vx"] + sin(t * 3.0 + e["s"]) * 10.0, e["vy"]) * PX * dt
	for s in smk:
		s["t"] += dt
		s["p"] += Vector2(s["vx"] + sin(t * 0.8 + s["s"]) * 3.0, s["vy"]) * PX * dt
		s["vx"] += w2 * 0.15 * dt
	for i in range(emb.size() - 1, -1, -1):
		if emb[i]["t"] >= emb[i]["life"]:
			emb.remove_at(i)
	for i in range(smk.size() - 1, -1, -1):
		if smk[i]["t"] >= smk[i]["life"]:
			smk.remove_at(i)
	queue_redraw()
	if refl:
		refl.queue_redraw()

## the halos, in the world
func _draw() -> void:
	for s in src:
		var at: Vector2 = s["at"]
		if not _on_screen(at, 80.0):
			continue
		var f: float = Flame.smooth(s["seed"])
		var h := _halo_of(s["kind"])
		var g := Flame.dither_glow(h[0], h[1])
		var sz := g.get_size() * PX
		var p := ((at - sz / 2.0) / PX).round() * PX
		draw_texture_rect(g, Rect2(p, sz), false, Color(1, 1, 1, minf(1.0, h[2] * f)))
	for ps in posts:
		var c: Vector2 = ps + Vector2(15, -61) * PX
		if not _on_screen(c, 120.0):
			continue
		var tex := WispView.halo(24)
		draw_texture_rect(tex, Rect2(((c / PX).round() - Vector2(24, 24)) * PX, Vector2(48, 48) * PX), false, Color(217 / 255.0, 190 / 255.0, 120 / 255.0, 0.4 + 0.05 * sin(t * 5.0)))

## embers and smoke, over the dark (called by world/atmos.gd with its canvas and the world-to-screen transform)
func draw_air(cv: CanvasItem, xf: Transform2D, light: Callable) -> void:
	for s in smk:
		var k: float = s["t"] / s["life"]
		var r := float(s["r0"]) + k * (13.0 if s["src"] == "brazier" else 9.0)
		var a: float = (0.2 if s["src"] == "candles" else (0.5 if s["src"] == "brazier" else 0.36)) * minf(1.0, s["t"] / 0.7) * (1.0 - k * k)
		var q: Vector2 = xf * s["p"]
		if not s.has("col") or t - float(s.get("lt", -9.0)) > 0.2:   # the light round it, read now and then
			s["lt"] = t
			var L: Array = light.call(q)
			var lc: Color = L[1] if L.size() > 1 else Color(0.62, 0.66, 0.78)
			var lv: float = float(L[0])
			s["col"] = Color(minf(1.0, (96.0 * minf(1.05, lc.r * lv * 1.6) + 22.0) / 255.0), minf(1.0, (90.0 * minf(1.0, lc.g * lv * 1.6) + 20.0) / 255.0), minf(1.0, (92.0 * minf(1.0, lc.b * lv * 1.6) + 24.0) / 255.0))
		var col: Color = s["col"]
		var g := Flame.dither_puff(int(round(r)), Color(0.9, 0.9, 0.9))   # grey, shaded top and bottom; tinted as drawn
		var sz := g.get_size() * PX
		cv.draw_texture_rect(g, Rect2(((q - sz / 2.0) / PX).round() * PX, sz), false, Color(minf(1.0, col.r / 0.9), minf(1.0, col.g / 0.9), minf(1.0, col.b / 0.9), a))
	for e in emb:
		var k: float = e["t"] / e["life"]
		var ci := mini(4, int(k * 5.0))
		if sin(t * 23.0 + e["s"] * 9.0) <= -0.6:
			continue   # the blink
		var q: Vector2 = (xf * e["p"] / PX).floor() * PX
		cv.draw_rect(Rect2(q, Vector2(PX, PX)), EMB_COL[ci])
		if ci < 2:
			var c2: Color = EMB_COL[ci]
			c2.a = 0.5
			cv.draw_rect(Rect2(q + Vector2(0, PX), Vector2(PX, PX)), c2)

## the lanterns lie in the water (z_props21.js:243-253): a broken column of warm light below each one, shivering with
## the ripples, on water and shallows only
func _draw_refl() -> void:
	var i := 0
	for ps in posts:
		i += 1
		if not _on_screen(ps, 400.0):
			continue
		var lsx := roundf(ps.x / PX)
		var lsy := roundf(ps.y / PX) - 30.0
		for d in range(24, 89):
			var yy := lsy + d
			var px := lsx + roundf(sin(t * 2.2 + yy * 0.5) * 1.4)
			var ty := zone.type_at(Iso.to_tile(Vector2(px, yy) * PX))
			if ty != 4 and ty != 12:
				continue
			var n := Flame.hash2(int(yy), int(floor(t * 3.0)) + i * 7)
			if n < 0.45 + (d - 24) / 130.0:
				continue
			var c := Color("#d8a848") if d < 44 and n > 0.9 else (Color("#8a6a30") if d < 60 else Color("#4e4022"))
			refl.draw_rect(Rect2(Vector2(px, yy) * PX, Vector2(PX, PX)), c)
