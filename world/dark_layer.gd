class_name DarkLayer
extends CanvasLayer
## The dark over the world (shaders/dark.gdshader), fed each frame with the pools of light the web build cuts into it
## (zz_zx_dark64.js): the hero's lantern (the main light, with shadows from walls, trunks, stones and camp things), the
## world's flames (the nearest four also throw shadows), the pyres and ground fires, and every PointLight2D that other
## systems place (wisps, skills, objects), which is turned into a pool here and switched off so nothing is lit twice.

const ISO_R := 25.456          # one yard across the screen, in web world px (TW * 0.7071)
const RND := {2: 0.24, 3: 0.4, 9: 0.34}
const SQ := {5: true, 7: true, 10: true}
const DR := {"statue_saint": 0.32, "statue_angel": 0.34, "cage": 0.22, "cage2": 0.22, "tent": 0.75}
const MAXH := 48
const MAXL := 48               # lights in the light map
## the lands' grades (zz_grade55.js): sat, con, bri; hi/lo soft-light tints [rgb, a]; hz the day haze
const GR := {
	"moor": {"sat": 1.22, "con": 1.1, "bri": 1.08, "hi": [Color8(60, 86, 112), 0.18], "lo": [Color8(176, 112, 56), 0.14], "hz": [Color8(96, 112, 128), 0.05]},
	"wood": {"sat": 1.3, "con": 1.12, "bri": 1.04, "hi": [Color8(30, 96, 92), 0.2], "lo": [Color8(168, 118, 52), 0.14], "hz": [Color8(60, 110, 100), 0.06]},
	"fen": {"sat": 1.24, "con": 1.1, "bri": 1.03, "hi": [Color8(50, 100, 76), 0.18], "lo": [Color8(116, 74, 126), 0.14], "hz": [Color8(80, 118, 98), 0.07]},
	"under": {"sat": 1.1, "con": 1.12, "bri": 1.0, "hi": [Color8(40, 38, 78), 0.16], "lo": [Color8(156, 90, 42), 0.1]},
	"night": {"sat": 1.16, "con": 1.14, "hi": [Color8(26, 46, 100), 0.18], "lo": [Color8(130, 76, 42), 0.08]},
}

static func land_of(z: Zone) -> String:
	var t: String = str(z.d.get("theme", ""))
	if t == "moor":
		return "moor"
	if t == "fen" or t.contains("shog") or t.contains("bog") or t.contains("mire"):
		return "fen"
	if t.contains("wood") or t.contains("root") or t.contains("fern"):
		return "wood"
	return "moor" if z.d.get("outdoor", false) else "under"
const MAXO := 128

const FlameK = preload("res://fx/flame.gd")
var rect: ColorRect
var lm_vp: SubViewport
var lm_rect: ColorRect
var lm_mat: ShaderMaterial
var mat: ShaderMaterial
var zone: Zone
var hero: Hero
var statics: Array = []        # [{t (tile), r (world px), core, far, w, rgb, kind}]
var round_things: Array = []   # [[tile, radius yd]] camp things that throw shadows
var extra_lights: Array = []   # PointLight2D nodes found in the zone
var scan_t := 0.0
var flash_next := 0.0          # the far flash (zz_zz_cine76.js): rare, at night, on open ground, never in town
var flash_t0 := -9.0
var mood := 1.0               # the lantern's mood (zz_zz_cine76): shrinks and stutters when the wound is deep, gutters in a boss fight
var keep := 1.0               # the dim wick and what the lantern keeps (zz_zz_study82), applied after the 5.4 cap
var boss_m: Node = null
var t := 0.0
var enabled := true
var last_holes: Array = []     # this frame's pools (window px), for light_at()
var last_A := 0.8
var last_xf := Transform2D.IDENTITY

func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/dark.gdshader")
	rect.material = mat
	add_child(rect)
	# the light map, one texel per art pixel (shaders/lightmap.gdshader)
	lm_vp = SubViewport.new()
	lm_vp.disable_3d = true
	lm_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	lm_vp.size = Vector2i(480, 270)
	lm_rect = ColorRect.new()
	lm_mat = ShaderMaterial.new()
	lm_mat.shader = load("res://shaders/lightmap.gdshader")
	lm_rect.material = lm_mat
	lm_rect.size = Vector2(480, 270)
	lm_vp.add_child(lm_rect)
	add_child(lm_vp)
	mat.set_shader_parameter("lmap", lm_vp.get_texture())
	Bus.boss_woke.connect(func(m): boss_m = m)
	Bus.boss_felled.connect(func(m): if m == boss_m: boss_m = null)

func bind(z: Zone, h: Hero) -> void:
	zone = z
	hero = h
	statics.clear()
	round_things.clear()
	extra_lights.clear()
	scan_t = 0.0
	for L in z.d.get("lights", []):
		var rgb := _rgb(L.get("rgb", "255,150,72"))
		match L.get("type", ""):
			"fire":
				var k: String = L.get("kind", "fire")
				var kk := 0.26 if k == "lantern" else (0.36 if k == "brazier" else 0.32)
				statics.append({"t": Vector2(L["x"], L["y"]), "r": maxf(14.0, float(L.get("radius", 3)) * ISO_R * kk), "core": 0.4, "far": 1.6, "w": 0.3, "rgb": rgb, "kind": k,
					"R": float(L.get("radius", 3)), "a": float(L.get("a", 1.0)), "fh": float(L.get("heightPx", 0)), "dx": float(L.get("dxPx", 0))})
			"raw":
				statics.append({"t": Vector2(L["x"], L["y"]), "r": maxf(10.0, float(L.get("radiusPx", 30))), "core": 0.35, "far": 1.5, "w": 0.3, "rgb": rgb, "kind": "raw"})
			"wallCandle":
				# the candle burns on the wall's face: its pool lies on the floor in front of it (the open side)
				var ct := Vector2(L["x"], L["y"])
				for dv in [Vector2(0.75, 0.0), Vector2(0.0, 0.75), Vector2(0.55, 0.55), Vector2(-0.75, 0.0), Vector2(0.0, -0.75)]:
					if not z.is_solid(ct + dv):
						ct += dv
						break
				statics.append({"t": ct, "r": maxf(14.0, float(L.get("radiusPx", 34)) * 1.15), "core": 0.4, "far": 1.7, "w": 0.3, "rgb": rgb, "kind": "wallc"})
	for dc in z.d.get("decor", []):
		var rr = DR.get(dc.get("key", ""))
		if rr != null:
			round_things.append([Vector2(dc["x"], dc["y"]), float(rr)])
	for o in z.objects:
		if o.get("type", "") in ["shrine", "altar"]:
			round_things.append([Vector2(o["x"], o["y"]), 0.4])

static func _rgb(s) -> Color:
	if s is Array:
		return Color8(int(s[0]), int(s[1]), int(s[2]))
	var p: PackedStringArray = String(s).split(",")
	return Color8(int(p[0]), int(p[1]), int(p[2]))

func _process(dt: float) -> void:
	if zone == null or not is_instance_valid(zone) or hero == null or not is_instance_valid(hero):
		rect.visible = false
		return
	rect.visible = enabled
	t += dt
	var k := 1.0
	# the wound and the flame's own gutters: the lantern says how brightly it burns (entities/lantern_unit.gd glow)
	if hero.lantern and is_instance_valid(hero.lantern):
		k *= hero.lantern.glow
	if boss_m != null and is_instance_valid(boss_m) and not boss_m.dead and boss_m.zone == zone:
		k *= 0.92 + 0.04 * sin(t * 2.1) - (0.06 if sin(t * 0.83) > 0.9 else 0.0)
	mood += (k - mood) * minf(1.0, dt * 15.0)
	keep += (hero.lamp_keep() - keep) * minf(1.0, dt * 4.8)   # 0.08 a frame at 60 (zz_zz_study82.js:19)
	var outdoor: bool = zone.d.get("outdoor", false)
	var dk := Game.day_k() if outdoor else 0.0
	var A := (0.82 - 0.5 * dk * dk) if outdoor else 0.84
	# the far flash: two flickers, a quick one, a gap, a longer one fading; the land stands up out of the dark
	var nk := clampf((1.0 - dk - 0.4) / 0.6, 0.0, 1.0) if outdoor else 0.0
	var fv := 0.0
	if nk > 0.0 and not load("res://world/quests.gd").is_town(zone.id):
		if flash_next <= 0.0:
			flash_next = t + randf_range(30.0, 70.0)
		if t > flash_next and (boss_m == null or not is_instance_valid(boss_m)):
			flash_t0 = t
			flash_next = t + randf_range(55.0, 125.0)
		var fa := t - flash_t0
		if fa >= 0.0 and fa <= 0.9:
			var f1 := 0.7 if fa < 0.07 else 0.0
			var f2 := pow(1.0 - (fa - 0.16) / 0.74, 2.2) if fa > 0.16 else 0.0
			fv = maxf(f1, f2) * nk
	else:
		flash_next = maxf(flash_next, t + 20.0)
	A *= 1.0 - 0.6 * fv
	var dark_rgb := Color8(8, 13, 27) if outdoor else Color8(8, 9, 20)
	var vp := get_viewport()
	var xf := vp.get_screen_transform() * vp.get_canvas_transform()
	var sc := xf.get_scale().x
	var vis := Rect2(Vector2.ZERO, Vector2(vp.get_visible_rect().size) * vp.get_screen_transform().get_scale())
	var holes: Array = []
	var occs: Array = []
	var lights: Array = []    # the light map (y_light21.js L37): [pos, r (window px), A, rgb, mode, squash, hole whose edges stop it]
	var lnk := (1.0 - dk) if outdoor else 1.0   # how far into the night (the light map's nk)
	# ---- the hero's lantern
	var hp := hero.tp
	if not hero.dead:
		var lampk := 1.5 + hero.st.item("lrad") / 100.0 * 0.5
		var R := minf(hero.light_radius(), 5.4 * lampk / 1.5) * ISO_R * 0.4 * (1.0 + 0.5 * dk) * mood * keep
		var foot := hp + Vector2(0.25, -0.25) * float(hero.face)   # the web: P + face x (0.25, -0.25) (y_light21.js:112)
		if hero.lantern and is_instance_valid(hero.lantern):
			foot = hero.lantern.tp   # the pool lies under the lantern, wherever it floats
		# each order's own flame (zz_zw_lantern63 BASE_RGB): ghost-blue glass, the penitent's amber, bone-pale candle, paper
		# lantern, the black flame's cold light
		var rgb: Color = {"animancer": Color8(120, 178, 255), "hemomancer": Color8(255, 164, 84)}.get(hero.cls, Color8(255, 170, 96))
		# the flame breathes (zz_zw_lantern63: a slow swell, no flutter; a quick flutter strobed on phones)
		var br := 0.86 + 0.09 * sin(t * 1.7) + 0.05 * sin(t * 2.9 + sin(t * 0.7))
		R *= 0.96 + 0.05 * br
		var hi := holes.size()
		holes.append([xf * Iso.to_screen(foot) + Vector2(0, sc * 4.0), R * 4.0 * sc, 2.1, 0.22, 0.26, 1.0, rgb, 1.0, 0.0, 0.18, 0.0, 0.32 * mood, 1.0])
		_occluders(occs, foot, R * 2.1 / ISO_R, hi, xf)
		# the light map: the hero's pool cut by what the lantern can see (y_light21.js:110-116, zz_grade55.js:111-123), and the
		# lantern's own light from its glass down to the ground (zz_zw_lantern63.js:51-70)
		var fl: float = FlameK.smooth(3.3)
		var Ry := minf(hero.light_radius(), R / ISO_R * 1.35)
		var lp: Vector2 = xf * Iso.to_screen(foot)
		# the lantern's own colour (zz_zw_lantern63 BASE_RGB), or its wick's (__lampRGB): the wick tints the light (the pool keeps the order's tint, as the web's does)
		var lrgb: Color = {"animancer": Color8(150, 196, 255), "hemomancer": Color8(242, 214, 168), "ossumancer": Color8(240, 228, 204), "miasmancer": Color8(255, 210, 150)}.get(hero.cls, Color8(255, 214, 160))
		var wk: String = load("res://items/ground.gd").wick(hero)
		if wk != "":
			lrgb = load("res://items/ground.gd").WICK_RGB[wk]
		lights.append([lp, Ry * 0.85 * ISO_R * 4.0 * sc * fl, minf(1.0, (0.06 + 0.36 * lnk) * (1.0 if outdoor else 0.9) * lampk * 0.5), lrgb, 2, 0.5, hi])
		lights.append([lp, Ry * (0.84 + 0.04 * fl) * ISO_R * 4.0 * sc, minf(1.0, (0.34 + 0.86 * (1.0 - dk) if outdoor else 1.05) * 0.62 * fl * 0.5), lrgb, 2, 0.5, hi])
		if hero.lantern and is_instance_valid(hero.lantern) and hero.lantern.visible:
			var k2 := maxf(0.5, 1.0 + (fl - 1.0) * 0.8 - Game.wind * 0.06) * lampk * mood * keep
			var gl: Vector2 = xf * hero.lantern.glass_screen()
			var gq: Vector2 = lp + Vector2(0, 4.0 * sc)
			lights.append([gq, 64.0 * lampk / 1.5 * 4.0 * sc, minf(1.0, (0.17 + 0.15 * lnk) * k2 * 0.5), lrgb, 0, 1.0, -1])
			lights.append([gl, 22.0 * 4.0 * sc, minf(1.0, (0.2 + 0.12 * lnk) * k2 * 0.5), lrgb, 0, 1.0, -1])
			lights.append([(gq + gl) / 2.0, 26.0 * 4.0 * sc, minf(1.0, (0.1 + 0.08 * lnk) * k2 * 0.5), lrgb, 0, 1.0, -1])
			lights.append([gl, 16.0 * 4.0 * sc, minf(1.0, 0.5 * k2 * 0.5), lrgb, 0, 1.0, -1])
		# the glow in the lantern's own glass
		if hero.lantern and is_instance_valid(hero.lantern) and hero.lantern.visible:
			holes.append([xf * hero.lantern.glass_screen(), 15.0 * 4.0 * sc * mood, 1.5, 0.3, 0.0, 0.6, rgb, 0.0, 0.0, 0.1, 1.0, 0.25, br * mood])
		elif hero.class_lamp and is_instance_valid(hero.class_lamp) and hero.class_lamp.visible:
			# the lamp in hand: its light lives inside it (zz_tune_v59.js:83-94, a spot r50 on the lamp)
			holes.append([xf * hero.class_lamp.glass_screen(), 15.0 * 4.0 * sc * mood, 1.5, 0.3, 0.0, 0.6, rgb, 0.0, 0.0, 0.1, 1.0, 0.25, br * mood])
	# ---- the world's flames (the nearest four throw shadows)
	var near: Array = []
	for s in statics:
		near.append([s["t"].distance_to(hp), s])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var n_sh := 0
	for e in near:
		var s: Dictionary = e[1]
		var pos: Vector2 = xf * Iso.to_screen(s["t"])
		var st0: Vector2 = s["t"]
		var r: float = s["r"] * 4.0 * sc * FlameK.smooth(st0.x * 3.1 + st0.y * 7.7)   # each flame breathes (zz_zx_dark64.js:131, s.f)
		if not vis.grow(r * float(s["far"])).has_point(pos):
			continue
		if holes.size() >= MAXH:
			break
		var hi2 := holes.size()
		var shadowed := 0.0
		if n_sh < 4 and s["kind"] != "wallc":
			n_sh += 1
			shadowed = 1.0
			_occluders(occs, s["t"], s["r"] * 1.6 / ISO_R, hi2, xf)
		holes.append([pos, r, float(s["far"]), float(s["core"]), 0.0, float(s["w"]), s["rgb"], shadowed, 0.0, 0.0, 0.0, 0.0, 1.0])
		# the light map: a pool on the ground cut by what the flame can see, a round light at the flame's own height
		# (fireLight37, y_light21.js:100-107); a wall candle's glow (y_light21.js:131-136)
		var ff: float = FlameK.smooth(st0.x * 3.1 + st0.y * 7.7)
		if s["kind"] == "wallc":
			lights.append([pos + Vector2(0, -16.0 * sc), 36.0 * 4.0 * sc, minf(1.0, 0.85 * 0.5) * (1.0 if ff > 0.95 else 0.86), s["rgb"], 1, 1.0, -1])
		elif s.has("R"):
			var fa: float = s["a"]
			if s["kind"] == "lantern":
				fa = 2.3 - 0.9 * dk
			elif outdoor:
				fa *= 1.0 - 0.5 * dk
			lights.append([pos, s["R"] * (0.96 + 0.04 * ff) * ISO_R * 4.0 * sc, minf(1.0, fa * ff * 0.5), s["rgb"], 2, 0.5, hi2 if shadowed > 0.0 else -1])
			lights.append([pos + Vector2(s["dx"], -s["fh"]) * 4.0 * sc, s["R"] * ISO_R * 0.42 * 4.0 * sc, minf(1.0, fa * 0.7 * ff * 0.5), s["rgb"], 1, 1.0, -1])
	# ---- lights other systems placed (wisps, skills, objects, fires): made into pools
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.5
		extra_lights = zone.find_children("*", "PointLight2D", true, false)
	for l in extra_lights:
		if not is_instance_valid(l):
			continue
		var pl := l as PointLight2D
		if pl.has_meta("dark_skip"):
			pl.enabled = false
			continue
		if pl.visible and pl.is_visible_in_tree():
			pl.enabled = false
			if holes.size() >= MAXH:
				continue
			# the pool lies on the ground under the light (a light hung at a height sets meta dark_dy, its drop in px)
			var pos2: Vector2 = xf * (pl.global_position + Vector2(0, float(pl.get_meta("dark_dy", 0.0))))
			if pl.has_meta("dark_r"):   # a light that asks for an exact pool, in web world px (wisps: r 21, core .25, far 1.5)
				var rw: float = float(pl.get_meta("dark_r")) * 4.0 * sc
				if vis.grow(rw * 1.6).has_point(pos2):
					lights.append([xf * pl.global_position, rw * 1.4, minf(1.0, 0.42 * 1.25 * 0.5), pl.color, 0, 1.0, -1])   # a soft light where it hangs (y_light21.js:148)
					holes.append([pos2, rw, float(pl.get_meta("dark_far", 1.5)), float(pl.get_meta("dark_core", 0.25)), 0.0, float(pl.get_meta("dark_w", 0.5)), pl.color, 0.0, 0.0, 0.0])
				continue
			var tw := float(pl.texture.get_width()) if pl.texture else 256.0
			var r2 := tw * 0.5 * pl.texture_scale * 0.5 * sc * clampf(pl.energy, 0.4, 1.4)
			r2 = clampf(r2, 20.0 * sc, 600.0 * sc)
			if vis.grow(r2 * 1.8).has_point(pos2):
				var fl := clampf(1.0 - pl.energy * 0.9, 0.0, 0.7)   # faint lights never clear the dark
				holes.append([pos2, r2, 1.8, 0.12, 0.0, 0.45, pl.color, 0.0, fl])
	last_holes = holes
	last_A = A
	last_xf = vp.get_screen_transform()
	# ---- feed the shader
	var hA := PackedVector4Array()
	var hB := PackedVector4Array()
	var hC := PackedVector4Array()
	var hD := PackedVector4Array()
	for h in holes:
		var pos3: Vector2 = h[0]
		hA.append(Vector4(pos3.x, pos3.y, float(h[1]), float(h[2])))
		var sh := float(h[7]) if h.size() > 7 else 0.0
		hB.append(Vector4(float(h[3]), float(h[4]), float(h[5]), sh))
		var c: Color = h[6]
		hC.append(Vector4(c.r, c.g, c.b, float(h[8]) if h.size() > 8 else 0.0))
		hD.append(Vector4(float(h[9]) if h.size() > 9 else 0.0, float(h[10]) if h.size() > 10 else 0.0, float(h[11]) if h.size() > 11 else 0.0, float(h[12]) if h.size() > 12 else 1.0))
	while hA.size() < MAXH:
		hA.append(Vector4.ZERO)
		hB.append(Vector4.ZERO)
		hC.append(Vector4.ZERO)
		hD.append(Vector4.ZERO)
	var oA := PackedVector4Array()
	var oH := PackedFloat32Array()
	for o in occs:
		if oA.size() >= MAXO:
			break
		oA.append(o[0])
		oH.append(o[1])
	var n_occ := oA.size()
	while oA.size() < MAXO:
		oA.append(Vector4.ZERO)
		oH.append(-1.0)
	var lA := PackedVector4Array()
	var lB := PackedVector4Array()
	var lC := PackedVector4Array()
	for l in lights:
		if lA.size() >= MAXL:
			break
		var lc: Color = l[3]
		lA.append(Vector4(l[0].x, l[0].y, l[1], l[2]))
		lB.append(Vector4(lc.r, lc.g, lc.b, float(l[4])))
		lC.append(Vector4(l[5], float(l[6]), 0.0, 0.0))
	var n_l := lA.size()
	while lA.size() < MAXL:
		lA.append(Vector4.ZERO)
		lB.append(Vector4.ZERO)
		lC.append(Vector4.ZERO)
	var cellw := 4.0 * sc
	var vsz := Vector2i(int(ceil(vis.size.x / cellw)), int(ceil(vis.size.y / cellw)))
	if lm_vp.size != vsz:
		lm_vp.size = vsz
		lm_rect.size = Vector2(vsz)
	for i in n_l:
		lA[i] = Vector4(lA[i].x / cellw, lA[i].y / cellw, lA[i].z / cellw, lA[i].w)
	var oT := PackedVector4Array()
	for o in oA:
		oT.append(o / cellw)
	lm_mat.set_shader_parameter("n_lights", n_l)
	lm_mat.set_shader_parameter("lA", lA)
	lm_mat.set_shader_parameter("lB", lB)
	lm_mat.set_shader_parameter("lC", lC)
	lm_mat.set_shader_parameter("n_occ", n_occ)
	lm_mat.set_shader_parameter("occ", oT)
	lm_mat.set_shader_parameter("occ_h", oH)
	mat.set_shader_parameter("n_holes", holes.size())
	mat.set_shader_parameter("hA", hA)
	mat.set_shader_parameter("hB", hB)
	mat.set_shader_parameter("hC", hC)
	mat.set_shader_parameter("hD", hD)
	mat.set_shader_parameter("n_occ", n_occ)
	mat.set_shader_parameter("occ", oA)
	mat.set_shader_parameter("occ_h", oH)
	mat.set_shader_parameter("dark_a", A)
	mat.set_shader_parameter("dark_rgb", Vector3(dark_rgb.r, dark_rgb.g, dark_rgb.b))
	mat.set_shader_parameter("tint_a", 0.2 + 0.1 * (1.0 - dk))
	mat.set_shader_parameter("cell", 4.0 * sc)
	# the grade, eased toward the night's as the day goes
	var land := land_of(zone)
	var g: Dictionary = GR[land]
	var n := (1.0 - dk) if outdoor else 0.0
	var N: Dictionary = GR["night"]
	var hi: Color = (g["hi"][0] as Color).lerp(N["hi"][0], n)
	var lo: Color = (g["lo"][0] as Color).lerp(N["lo"][0], n)
	mat.set_shader_parameter("g_sat", lerpf(g["sat"], N["sat"], n))
	mat.set_shader_parameter("g_con", lerpf(g["con"], N["con"], n))
	mat.set_shader_parameter("g_bri", g.get("bri", 1.0))
	mat.set_shader_parameter("g_hi", Vector4(hi.r, hi.g, hi.b, lerpf(g["hi"][1], N["hi"][1], n)))
	mat.set_shader_parameter("g_lo", Vector4(lo.r, lo.g, lo.b, lerpf(g["lo"][1], N["lo"][1], n)))
	# no haze: the web's three dithered strips drifting over the screen (drawHaze37) read as fog popping up over the
	# view; the user hated them (2026-10-05). The shader's haze stays off.
	mat.set_shader_parameter("g_haze", Vector4.ZERO)
	var am := zone.ambient_at(Game.phase())
	mat.set_shader_parameter("amb", Vector3(am.r, am.g, am.b))
	lm_mat.set_shader_parameter("amb", Vector3(am.r, am.g, am.b))

## the edges that stop a light at tile l within rw yards, as screen-space segments (the near side of each blocker:
## round bases for trunks, stones and pillars; the two corners that bound a wall tile's silhouette)
func _occluders(out: Array, l: Vector2, rw: float, hole_i: int, xf: Transform2D) -> void:
	var x0 := int(floor(l.x - rw))
	var x1 := int(floor(l.x + rw))
	var y0 := int(floor(l.y - rw))
	var y1 := int(floor(l.y + rw))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if out.size() >= MAXO:
				return
			var t := zone.type_at(Vector2(tx + 0.5, ty + 0.5))
			var rr = RND.get(t)
			var sq: bool = SQ.has(t)
			if rr == null and not sq:
				continue
			var c := Vector2(tx + 0.5, ty + 0.5)
			var dv := c - l
			var dd := dv.length()
			if dd < 0.45 or dd > rw + 1.0:
				continue
			var a: Vector2
			var b: Vector2
			if rr != null:
				if dd <= float(rr) + 0.05:
					continue
				var th := atan2(dv.y, dv.x)
				var al := asin(minf(0.99, float(rr) / dd))
				var tl := sqrt(dd * dd - float(rr) * float(rr))
				a = l + Vector2(cos(th - al), sin(th - al)) * tl
				b = l + Vector2(cos(th + al), sin(th + al)) * tl
			else:
				var th2 := atan2(dv.y, dv.x)
				var mn := 9.0
				var mx := -9.0
				for cc in [Vector2(tx, ty), Vector2(tx + 1, ty), Vector2(tx, ty + 1), Vector2(tx + 1, ty + 1)]:
					var da := atan2(cc.y - l.y, cc.x - l.x) - th2
					da = atan2(sin(da), cos(da))
					if da < mn:
						mn = da
						a = cc
					if da > mx:
						mx = da
						b = cc
			var A2: Vector2 = xf * Iso.to_screen(a)
			var B2: Vector2 = xf * Iso.to_screen(b)
			out.append([Vector4(A2.x, A2.y, B2.x, B2.y), float(hole_i)])
	for rt in round_things:
		var c2: Vector2 = rt[0]
		var rr2: float = rt[1]
		var dv2 := c2 - l
		var dd2 := dv2.length()
		if dd2 <= rr2 + 0.05 or dd2 > rw + 1.0:
			continue
		var th3 := atan2(dv2.y, dv2.x)
		var al2 := asin(minf(0.99, rr2 / dd2))
		var tl2 := sqrt(dd2 * dd2 - rr2 * rr2)
		var a3: Vector2 = xf * Iso.to_screen(l + Vector2(cos(th3 - al2), sin(th3 - al2)) * tl2)
		var b3: Vector2 = xf * Iso.to_screen(l + Vector2(cos(th3 + al2), sin(th3 + al2)) * tl2)
		out.append([Vector4(a3.x, a3.y, b3.x, b3.y), float(hole_i)])


## how lit a point of the viewport is (0 = the open dark, 1 = a pool's heart; by day the open dark is lighter), and the
## colour of the light there (for mist, dust, leaves: world/atmos.gd). Occluders are not tested (cheap).
func light_at(vp_pt: Vector2) -> Array:
	var p: Vector2 = last_xf * vp_pt
	var dark := 1.0
	var col := Color(0.62, 0.66, 0.78)
	for h in last_holes:
		var c: Vector2 = h[0]
		var r: float = h[1]
		var d := Vector2((p.x - c.x) / r, (p.y - c.y) / (r * 0.56)).length()
		var far: float = h[2]
		if d >= far:
			continue
		var v := 0.0 if d < float(h[3]) else (0.64 * clampf((d - float(h[3])) / (1.0 - float(h[3])), 0.0, 1.0) if d < 1.0 else 0.64 + 0.36 * pow((d - 1.0) / (far - 1.0), 0.6))
		if v < dark:
			dark = v
			col = (h[6] as Color)
	var lum := 1.0 - last_A * dark
	return [lum, col.lerp(Color(0.62, 0.66, 0.78), dark)]

