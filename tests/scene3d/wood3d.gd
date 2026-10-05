extends Node3D
## The 3D test scene (the user, 2026-09-30, after the D2R-3D video): a corner of the Hollow Wood at night, built in real 3D
## under the 2D game's camera. The painted ground, trees, stones and the Ossuarch stay exactly as painted (one texel per
## screen pixel), but the light is real: the lantern and a lantern-post are lights that fall off in stepped pixel bands,
## trunks, canopies, walls and the pilgrim cast real shadows, and the moon gives the dark its cold floor. Nothing is laid
## over the screen.
## Run: godot --path . res://tests/scene3d/wood3d.tscn   (-- --hero_still to hold him in place)
##
## The camera is Diablo II's: no perspective (orthographic), looking down 30 degrees, turned 45 so a tile (1 m) is the
## 2D game's 144 x 72 px diamond. 1 m = 101.82 screen px.

const PPM := 101.82
const PX := 1.0 / PPM                 # one screen px, in metres
const GROUND_SH := preload("res://tests/scene3d/lit_ground.gdshader")
const SPRITE_SH := preload("res://tests/scene3d/lit_sprite.gdshader")

var cam: Camera3D
var hero_card: MeshInstance3D
var hero_mat: ShaderMaterial
var hero_proxy: MeshInstance3D
var hero_pos := Vector3(3.0, 0, 3.4)
var lantern_node: Node3D
var lamp: OmniLight3D
var sheet: Texture2D
var frames := {}                     # anim -> [[x, y, w, h, dx, dy], ...]
var t := 0.0
var still := false
var path := [Vector3(3.0, 0, 3.4), Vector3(5.2, 0, 5.4), Vector3(6.4, 0, 4.6)]

func _ready() -> void:
	Assets.load_meta()
	still = OS.get_cmdline_user_args().has("--hero_still")
	_world()
	_camera()
	_ground()
	_props()
	_hero()
	_lantern()

# ------------------------------------------------------------------ light and air
func _world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.2, 0.34)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# the moon: faint, cold, from the upper left, with long soft shadows
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.22
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.85
	moon.rotation_degrees = Vector3(-38, -150, 0)
	add_child(moon)

func _camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1080.0 / PPM              # the vertical extent, so a metre is PPM px at 1080 lines
	cam.near = 0.1
	cam.far = 200.0
	add_child(cam)
	_aim(Vector3(5.2, 0, 5.2))

func _aim(target: Vector3) -> void:
	# from the +x +z side, looking back and 30 degrees down: +x runs right-down the screen, +z left-down, and the larger
	# x + z is nearer the eye, exactly as the 2D game sorts
	var f := Vector3(-cos(deg_to_rad(30.0)) * 0.70711, -sin(deg_to_rad(30.0)), -cos(deg_to_rad(30.0)) * 0.70711)
	cam.position = target - f * 40.0
	cam.look_at(target, Vector3.UP)

# ------------------------------------------------------------------ the ground
func _ground() -> void:
	var set := Assets.ground("wood")
	var m := ShaderMaterial.new()
	m.shader = GROUND_SH
	m.set_shader_parameter("ground_tex", Assets.tex(set["main"][0]))
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = m
	g.position = Vector3(5, 0, 5)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	# a strip of old road through it
	var rm := ShaderMaterial.new()
	rm.shader = GROUND_SH
	rm.set_shader_parameter("ground_tex", Assets.tex(set["road"][0]))
	var rp := PlaneMesh.new()
	rp.size = Vector2(2.2, 16)
	var r := MeshInstance3D.new()
	r.mesh = rp
	r.material_override = rm
	r.position = Vector3(5.2, 0.01, 5.2)
	r.rotation_degrees = Vector3(0, 45, 0)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(r)

# ------------------------------------------------------------------ trees, stones, a ruin, a lantern-post
func _props() -> void:
	var trees := [["sp_ashoak_mature0", -0.5, 6.0, 1.35], ["sp_ashoak_dying0", 8.8, 2.2, 1.0], ["sp_ashoak_dead0", 2.2, 3.9, 0.7],
		["sp_ashoak_mature0", 12.4, 6.2, 1.35], ["sp_ashoak_snag0", 6.8, 3.2, 0.0], ["sp_ashoak_young0", 1.0, 9.8, 0.8],
		["sp_ashoak_dead0", 10.5, 5.4, 0.7], ["sp_ashoak_stump0", 5.6, 7.9, 0.0], ["sp_ashoak_dying0", 0.8, 1.2, 1.0]]
	for tr in trees:
		_sprite("trees", tr[0], Vector3(tr[1], 0, tr[2]), false)
		var e := Assets.piece("trees", tr[0])
		var tex := Assets.tex(e["png"])
		var h: float = float(e.get("oy", tex.get_height())) * PX * 4.0 / float(e.get("hr", 4))
		_proxy_cylinder(Vector3(tr[1], 0, tr[2]), 0.18 if h > 1.2 else 0.3, minf(h * 0.8, 3.2))
		if tr[3] > 0.0:
			_proxy_sphere(Vector3(tr[1], h * 0.72, tr[2]), tr[3])
	for rk in [["rk0", 7.8, 7.0], ["rk2", 3.4, 6.2], ["rkf1", 8.2, 4.4], ["grave1", 4.0, 2.2], ["grave0", 4.8, 1.6]]:
		_sprite("trees", rk[0], Vector3(rk[1], 0, rk[2]), false)
		_proxy_cylinder(Vector3(rk[1], 0, rk[2]), 0.32, 0.5)
	# a broken wall of the ruin: real stone, lit and shadowing
	var wall_tex := Assets.tex("wtex/tx_ruin.png")
	for seg in [[Vector3(1.0, 0, 5.4), Vector3(0.4, 1.6, 2.6)], [Vector3(1.0, 0, 3.4), Vector3(0.4, 0.9, 1.0)], [Vector3(2.6, 0, 9.6), Vector3(2.4, 1.2, 0.4)]]:
		_wall(seg[0], seg[1], wall_tex)
	# a lantern-post by the road, its own warm light
	var post := _sprite("world", "lantern", Vector3(7.2, 0, 6.6), false)
	_proxy_cylinder(Vector3(7.2, 0, 6.6), 0.08, 1.6)
	var pl := OmniLight3D.new()
	pl.light_color = Color8(255, 170, 96)
	pl.light_energy = 1.4
	pl.omni_range = 5.0
	pl.omni_attenuation = 1.3
	pl.shadow_enabled = true
	pl.position = Vector3(7.2, 1.35, 6.6)
	add_child(pl)

func _sprite(cat: String, key: String, at: Vector3, flip: bool) -> MeshInstance3D:
	var e := Assets.piece(cat, key)
	if e.is_empty():
		push_warning("no piece " + key)
		return null
	var tex := Assets.tex(e["png"])
	var hr := float(e.get("hr", 2 if cat == "world" else 4))
	var k := 4.0 / hr                      # screen px per texel (the 2D game's Iso.WPX / hr)
	var ox := float(e.get("ox", tex.get_width() * 0.5))
	var oy := float(e.get("oy", tex.get_height()))
	return _card(tex, Rect2(0, 0, tex.get_width(), tex.get_height()), ox, oy, k, at, flip)

func _card(tex: Texture2D, r: Rect2, ox: float, oy: float, k: float, at: Vector3, flip: bool) -> MeshInstance3D:
	var q := QuadMesh.new()
	var w := r.size.x * k * PX
	var h := r.size.y * k * PX
	q.size = Vector2(w, h)
	q.center_offset = Vector3((r.size.x * 0.5 - ox) * k * PX, (oy - r.size.y * 0.5) * k * PX, 0)
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SH
	m.set_shader_parameter("tex", tex)
	var ts := Vector2(tex.get_width(), tex.get_height())
	m.set_shader_parameter("region", Vector4(r.position.x / ts.x, r.position.y / ts.y, r.size.x / ts.x, r.size.y / ts.y))
	m.set_shader_parameter("flip", 1.0 if flip else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # shadows come from the proxies
	add_child(mi)
	return mi

## invisible shapes that only throw shadows: a painted card can't, so its body stands in for it
const BEHIND := Vector3(-0.7071, 0, -0.7071)   # away from the eye: a proxy stands just behind its card, so the card is
                                              # lit from the front and only shadowed by what is really between it and a lamp

func _proxy_cylinder(at: Vector3, r: float, h: float) -> MeshInstance3D:
	at += BEHIND * (r + 0.06)
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.15
	c.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.position = at + Vector3(0, h * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(mi)
	return mi

func _proxy_sphere(at: Vector3, r: float) -> void:
	at += BEHIND * (r * 0.6)
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.5
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(mi)

func _wall(at: Vector3, size: Vector3, tex: Texture2D) -> void:
	var b := BoxMesh.new()
	b.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.83      # 122 texels over 122 screen px
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = at + Vector3(0, size.y * 0.5, 0)
	add_child(mi)

# ------------------------------------------------------------------ the Ossuarch and his lantern
func _hero() -> void:
	var f := FileAccess.open("res://art/sprites/ossuarch.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	sheet = load("res://art/sprites/" + String(d["sheets"][0]))
	for key in d["idx"]:
		var parts: PackedStringArray = String(key).split("/")
		var v: Array = d["idx"][key]
		if not frames.has(parts[0]):
			frames[parts[0]] = []
		frames[parts[0]].append([v[1], v[2], v[3], v[4], -float(v[5]), -float(v[6])])
	var fr: Array = frames["idle"][0]
	hero_card = _card(sheet, Rect2(fr[0], fr[1], fr[2], fr[3]), fr[4], fr[5], 1.0, hero_pos, false)
	hero_mat = hero_card.material_override
	hero_proxy = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.9
	hero_proxy.mesh = cap
	hero_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(hero_proxy)

func _lantern() -> void:
	lantern_node = Node3D.new()
	add_child(lantern_node)
	var e := Assets.piece("lanterns", "iron")
	var tex := Assets.tex(e["png"])
	var card := _card(tex, Rect2(0, 0, tex.get_width(), tex.get_height()), tex.get_width() * 0.5, tex.get_height() * 0.6, 4.0 / float(e.get("k", 4)), Vector3.ZERO, false)
	remove_child(card)
	lantern_node.add_child(card)
	(card.material_override as ShaderMaterial).set_shader_parameter("emit", Vector3(0.5, 0.45, 0.35))
	# the light itself: a bone-pale candle behind glass; real falloff, real shadows
	# the glass's own glow: three dithered discs, drawn as light (added), never over the world's colours elsewhere
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.4, 0.4)
	halo.mesh = hq
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://tests/scene3d/halo.gdshader")
	hm.set_shader_parameter("col", Vector3(0.94, 0.87, 0.74))
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0, 0.02, 0)
	lantern_node.add_child(halo)
	lamp = OmniLight3D.new()
	lamp.light_color = Color8(240, 222, 190)
	lamp.light_energy = 2.2
	lamp.omni_range = 6.5
	lamp.omni_attenuation = 1.15
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.08
	lantern_node.add_child(lamp)

func _process(dt: float) -> void:
	t += dt
	# walk the path, then stand
	var anim := "idle"
	if not still:
		var total := 0.0
		for i in path.size() - 1:
			total += path[i].distance_to(path[i + 1])
		var dist := minf(t * 0.9, total)
		var acc := 0.0
		for i in path.size() - 1:
			var seg: float = path[i].distance_to(path[i + 1])
			if dist <= acc + seg:
				hero_pos = path[i].lerp(path[i + 1], (dist - acc) / seg)
				break
			acc += seg
		if dist < total:
			anim = "walk"
	var fl: Array = frames[anim]
	var fi := int(t * (8.0 if anim == "walk" else 5.0)) % fl.size()
	var fr: Array = fl[fi]
	var ts := Vector2(sheet.get_width(), sheet.get_height())
	hero_mat.set_shader_parameter("region", Vector4(fr[0] / ts.x, fr[1] / ts.y, fr[2] / ts.x, fr[3] / ts.y))
	hero_card.position = hero_pos
	hero_proxy.position = hero_pos + Vector3(0, 0.95, 0) + BEHIND * 0.38
	# the lantern floats at his shoulder, a little to the lamp side, and bobs on its own breath
	var bob := sin(t * 1.55) * 0.05 + sin(t * 0.6) * 0.03
	lantern_node.position = hero_pos + Vector3(-0.2, 1.45 + bob, 0.45)
	lamp.light_energy = 2.2 * (0.95 + 0.05 * sin(t * 1.7) + 0.03 * sin(t * 2.9))
	_aim(hero_pos.lerp(Vector3(5.2, 0, 5.2), 0.5))
	if OS.get_cmdline_user_args().has("--where") and int(t * 10) % 30 == 0:
		print("HERO ", cam.unproject_position(hero_pos), " t ", t)
		for c in get_children():
			if c is MeshInstance3D and c.mesh is QuadMesh:
				print("CARD ", c.position, " -> ", cam.unproject_position(c.position))
