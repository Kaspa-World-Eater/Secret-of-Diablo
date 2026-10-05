class_name Lighting
extends RefCounted
## Helpers for 2D point lights. Darkness itself comes from the CanvasModulate
## in DayNight; every light source both brightens the screen and counts for
## gameplay through Game.light_at().

static var _tex: Texture2D = null


static func light_texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 256
		t.height = 256
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex = t
	return _tex


static func make_light(radius: float, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius * 2.0 / 256.0
	l.color = color
	l.energy = energy
	return l


static func falloff(dist: float, radius: float) -> float:
	## Gameplay brightness 0..1 of a light at `dist` from a source of `radius`.
	if radius <= 0.0 or dist >= radius:
		return 0.0
	return clamp((1.0 - dist / radius) * 1.8, 0.0, 1.0)
