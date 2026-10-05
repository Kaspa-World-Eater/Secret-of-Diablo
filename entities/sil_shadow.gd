class_name SilShadow
extends Node2D
## A figure's shadow on the ground, as the web throws it; it lives on the zone's shadow layer (under all standing
## things, over the ground), dithered at the world's grain into two steps of the shadow colour (shaders/shadow37).
## - The hero (zz_zz_shadow70.js): their own silhouette, this frame, laid flat and stretched away from what lights them,
##   fading toward the tip: from the floating lantern (a long shadow off the far side), from the two strongest flames
##   in reach (stand between two and you have two, the nearer darker), and by day from the sun, turning and lengthening
##   with the hour.
## - Every creature (y_light21.js:270-308, zz_zz_cine76.js:62-69): a wedge thrown away from each flame within reach,
##   and from the hero's lantern, darkest at the feet, longer the farther from the flame.

const SH := preload("res://shaders/shadow37.gdshader")
const Flame = preload("res://fx/flame.gd")
const A := 18.0              # half a tile across, web px
const B := 9.0               # half a tile down
const PPW := 25.4558         # sqrt(2) x A
static var _src_zone: Object = null
static var _src: Array = []  # this frame's lights: {tp, R (tiles), a, kind}

var src: AnimSprite
var owner_node: Node2D
var is_hero := false
var casts: Array = []        # the hero's silhouettes (Sprite2D)
var wedge_mat: ShaderMaterial

func _init(s: AnimSprite, who: Node2D, hero_flag: bool) -> void:
	src = s
	owner_node = who
	is_hero = hero_flag
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_hero:
		for i in 4:
			var sp := Sprite2D.new()
			sp.centered = false
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var m := ShaderMaterial.new()
			m.shader = SH
			sp.material = m
			sp.visible = false
			add_child(sp)
			casts.append(sp)
	else:
		wedge_mat = ShaderMaterial.new()
		wedge_mat.shader = SH
		wedge_mat.set_shader_parameter("sil", false)
		wedge_mat.set_shader_parameter("levels", 2.4)
		wedge_mat.set_shader_parameter("steps", Vector2(120.0, 200.0) / 255.0)
		wedge_mat.set_shader_parameter("th_off", 0.3)
		wedge_mat.set_shader_parameter("th_mul", 2.5)
		material = wedge_mat

## the lights that throw shadows this frame (the world's flames, and the hero's lantern for creatures)
static func lights(zone, hero) -> Array:
	if zone == _src_zone:
		return _src
	_src_zone = zone
	_src = []
	for L in zone.d.get("lights", []):
		if L.get("type", "") != "fire":
			continue
		var a := float(L.get("a", 1.0))
		var k: String = L.get("kind", "fire")
		if k == "fire" and a < 0.5:
			continue
		var tp := Vector2(L["x"], L["y"])
		var rgb: PackedStringArray = String(L.get("rgb", "255,150,72")).split(",")
		_src.append({"tp": tp, "R": float(L.get("radius", 3.0)), "a": a, "kind": k, "rgb": Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])),
			"at": Iso.to_screen(tp) + Vector2(float(L.get("dxPx", 0)), -float(L.get("heightPx", 0))) * 4.0, "seed": tp.x * 3.1 + tp.y * 7.7})
	return _src

func _sky() -> Array:
	var zone = owner_node.get("zone")
	var out: bool = zone.d.get("outdoor", false)
	return [out, Game.day_k() if out else 0.0]

func _process(_dt: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or owner_node.is_queued_for_deletion():
		queue_free()
		return
	var zone = owner_node.get("zone")
	var gone: bool = zone == null or owner_node.get("dead") == true or owner_node.get("buried") == true or src == null or not is_instance_valid(src) or not src.visible
	if gone:
		visible = false
		return
	visible = true
	if is_hero:
		_hero(zone)
	else:
		# only creatures on screen throw a shadow anyone could see
		var xf := get_viewport().get_canvas_transform()
		var p: Vector2 = xf * owner_node.global_position
		var on := not Settings.fewer_fx and Rect2(Vector2(-300, -300), get_viewport_rect().size + Vector2(600, 600)).has_point(p)
		visible = on
		if on:
			queue_redraw()

# ------------------------------------------------------------------ the hero's silhouettes
## a world direction on screen (web px)
static func scr(d: Vector2) -> Vector2:
	return Vector2((d.x - d.y) * A, (d.x + d.y) * B)

## a screen vector in the world
static func wld(s: Vector2) -> Vector2:
	var u := s.x / A
	var v := s.y / B
	return Vector2((u + v) / 2.0, (v - u) / 2.0)

func _hero(zone) -> void:
	var h = owner_node
	var sky := _sky()
	var out: bool = sky[0]
	var dk: float = sky[1]
	var want: Array = []     # [world dir, length, strength]
	# 1. the floating lantern: a low light close by, a long shadow thrown off the far side
	var ln = h.get("lantern")
	if ln != null and is_instance_valid(ln):
		var d: Vector2 = h.tp - ln.tp
		if d.length() <= 0.08:
			var gl: Vector2 = ln.glass_screen() - h.position
			d = wld(Vector2(-gl.x / 4.0 * 1.6, 5.0 if ln.tp.x + ln.tp.y < h.tp.x + h.tp.y else -5.0))
		var lk: float = (1.5 + h.st.item("lrad") / 100.0 * 0.5) / 1.5
		want.append([d, 1.1 + 0.15 * (1.0 - dk), (0.04 + 0.4 * (1.0 - dk) if out else 0.45) * minf(1.2, lk)])
	# 2. the two strongest flames in reach
	var fl: Array = []
	for s in lights(zone, h):
		var d: float = h.tp.distance_to(s["tp"])
		if d < 0.4 or d > s["R"] * 0.95:
			continue
		fl.append([minf(1.0, 1.05 * pow(1.0 - d / (s["R"] * 0.95), 0.5) * minf(1.0, s["a"])), s, d])
	fl.sort_custom(func(a, b): return a[0] > b[0])
	for e in ([] if Settings.fewer_fx else fl.slice(0, 2)):
		want.append([h.tp - e[1]["tp"], minf(1.7, 0.55 + e[2] / e[1]["R"] * 1.3), e[0] * 0.8])
	# 3. the sun, outdoors by day: it turns with the hour and is long at either end of the day
	if out and dk > 0.05:
		var hh := clampf(Game.phase() / 0.55, 0.0, 1.0)
		var ang := -2.4 + hh * 2.2
		want.append([Vector2(cos(ang), sin(ang)), 0.85 + 0.9 * absf(hh - 0.5), 0.34 * dk])
	for i in casts.size():
		var sp: Sprite2D = casts[i]
		if i >= want.size():
			sp.visible = false
			continue
		_cast(sp, want[i][0], want[i][1], want[i][2])

## lay the frame flat from the feet along the world direction d, len times the figure's height, at strength al
func _cast(sp: Sprite2D, d: Vector2, len: float, al: float) -> void:
	if d.length() < 0.0001 or al <= 0.005:
		sp.visible = false
		return
	d = d.normalized()
	var av := scr(d) / PPW * len
	var bs := scr(Vector2(-d.y, d.x)) / PPW
	if bs.x < 0.0:
		bs = -bs
	sp.visible = true
	sp.texture = src.texture
	sp.offset = src.offset
	sp.flip_h = src.flip_h
	sp.transform = Transform2D(bs, -av, owner_node.global_position + Vector2(0, 8))
	var m := sp.material as ShaderMaterial
	m.set_shader_parameter("al", al)
	var at := src.texture as AtlasTexture
	if at and at.atlas:
		var H := float(at.atlas.get_height())
		var r := at.region
		var feet := r.position.y - src.offset.y   # the feet stand at the local origin
		m.set_shader_parameter("uv_feet", feet / H)
		m.set_shader_parameter("uv_head", r.position.y / H)

# ------------------------------------------------------------------ the creatures' wedges
func _draw() -> void:
	if is_hero:
		return
	var zone = owner_node.get("zone")
	if zone == null:
		return
	var hero = zone.hero_ref
	var tp: Vector2 = owner_node.get("tp")
	var srcs: Array = lights(zone, hero)
	var lamp_src = null
	# the hero's lantern throws their shadows too (zz_zz_cine76.js:62-69)
	if hero != null and is_instance_valid(hero) and not hero.dead and hero.lantern != null and is_instance_valid(hero.lantern):
		var sky := _sky()
		var dk: float = sky[1]
		var lampk: float = 1.5 + hero.st.item("lrad") / 100.0 * 0.5
		var pool := minf(hero.light_radius(), 5.4 * lampk / 1.5) * 0.4 * (1.0 + 0.5 * dk)
		lamp_src = {"tp": hero.lantern.tp, "R": pool * 2.4, "a": 0.2 + 0.65 * (1.0 - dk) if sky[0] else 0.8, "kind": "lamp"}
	# the figure's size: its frame against the web's 46 x 50
	var sc := 1.0
	var wk := 1.0
	var at := src.texture as AtlasTexture
	if at:
		sc = clampf(at.region.size.y / 4.0 / 46.0, 1.0, 3.6)
		wk = clampf(at.region.size.x / 4.0 / 50.0, 1.0, 3.0)
	var me := Iso.to_screen(tp)
	position = me
	for s in (srcs + [lamp_src] if lamp_src != null else srcs):
		var d: float = tp.distance_to(s["tp"])
		if d < 0.35 or d > s["R"] * 0.95:
			continue
		var fp := Vector2.ZERO
		var lp: Vector2 = (Iso.to_screen(s["tp"]) - me) / 4.0
		var v := fp - lp
		var vl := maxf(0.0001, v.length())
		v /= vl
		var ln := minf(150.0, minf(72.0, maxf(20.0, vl * (1.6 if s["kind"] in ["candles", "fire"] else 1.25))) * sc)
		var w0 := 7.0 * minf(wk, 2.4)
		var n := Vector2(-v.y, v.x)
		var al := minf(1.0, 1.1 * pow(1.0 - d / (s["R"] * 0.95), 0.5) * minf(1.0, s["a"]))
		var e := Vector2(v.x * ln, v.y * ln * 0.9)
		var b0 := n * Vector2(w0 * 0.8, w0 * 0.5) - v * 1.5
		var b1 := -n * Vector2(w0 * 0.8, w0 * 0.5) - v * 1.5
		var e0 := e + n * Vector2(w0 * 1.25, w0 * 0.8)
		var e1 := e - n * Vector2(w0 * 1.25, w0 * 0.8)
		var m0 := b0.lerp(e0, 0.7)
		var m1 := b1.lerp(e1, 0.7)
		var c0 := Color(0, 0, 0, al)
		var c7 := Color(0, 0, 0, al * 0.7)
		var c1 := Color(0, 0, 0, 0)
		draw_polygon(PackedVector2Array([b0 * 4.0, m0 * 4.0, m1 * 4.0, b1 * 4.0]), PackedColorArray([c0, c7, c7, c0]))
		draw_polygon(PackedVector2Array([m0 * 4.0, e0 * 4.0, e1 * 4.0, m1 * 4.0]), PackedColorArray([c7, c1, c1, c7]))
