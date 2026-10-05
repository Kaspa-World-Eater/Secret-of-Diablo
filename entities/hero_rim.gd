extends Sprite2D
## The hero rimmed by the nearest flame that reaches them (heroRim37, y_light21.js:240-268): their silhouette lit along
## the edge that faces it, in its colour, added. With no flame near, the cold of the sky (outdoors, not by day) or of
## the vault rims them faintly from the upper left.

var hero
var src: AnimSprite

func _init(h, s: AnimSprite) -> void:
	hero = h
	src = s
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rim37.gdshader")
	material = m

func _process(_dt: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.dead or src == null or not src.visible or hero.zone == null:
		visible = false
		return
	var zone = hero.zone
	var best = null
	var bd := 1e9
	for s in SilShadow.lights(zone, hero):
		var d: float = hero.tp.distance_to(s["tp"])
		if d < s["R"] * 1.05 and d / s["R"] < bd:
			bd = d / s["R"]
			best = s
	var dir := Vector2(-1, -0.8)
	var col := Color8(150, 170, 225)
	var a := 0.0
	if best != null:
		var at: Vector2 = best["at"] if best.has("at") else Iso.to_screen(best["tp"])
		dir = at - (hero.position + Vector2(0, -20 * 4))
		col = best["rgb"] if best.has("rgb") else Color8(255, 150, 72)
		a = minf(0.85, 0.95 * (1.0 - bd * 0.8) * load("res://fx/flame.gd").smooth(best["seed"]))
	else:
		var out: bool = zone.d.get("outdoor", false)
		var k := Game.day_k() if out else 0.0
		if k > 0.6:
			visible = false
			return
		col = Color8(150, 170, 225) if out else Color8(140, 150, 190)
		a = 0.32 * (1.0 - k)
	if a <= 0.01:
		visible = false
		return
	visible = true
	dir = dir.normalized()
	var o := Vector2(roundf(dir.x * 2.0), roundf(dir.y * 2.0))
	if o == Vector2.ZERO:
		visible = false
		return
	texture = src.texture
	offset = src.offset
	flip_h = src.flip_h
	position = src.position
	if flip_h:
		o.x = -o.x
	var m := material as ShaderMaterial
	m.set_shader_parameter("off", o)
	m.set_shader_parameter("rim", Color(col.r, col.g, col.b, a))
