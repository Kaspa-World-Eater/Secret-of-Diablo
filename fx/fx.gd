class_name Fx
extends RefCounted
## small effects: dark blood that falls and stays a while. No glow, nothing bright.

static func blood(parent: Node, pos: Vector2, dir: Vector2, n: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = n * 3
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = dir if dir.length() > 0.1 else Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	p.color = Color(0.22, 0.03, 0.03)
	p.position = pos
	p.z_index = 5
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	# a few drops stay on the ground
	for i in n:
		var s := Polygon2D.new()
		var r := randf_range(1.2, 3.2)
		var pts := PackedVector2Array()
		for k in 7:
			var a := k / 7.0 * TAU
			pts.append(Vector2(cos(a) * r * randf_range(0.7, 1.3), sin(a) * r * 0.5 * randf_range(0.7, 1.3)))
		s.polygon = pts
		s.color = Color(0.16, 0.02, 0.02, 0.85)
		s.position = pos + Vector2(randf_range(-14, 14) + dir.x * 12.0, 26 + randf_range(-5, 5))
		s.z_index = -50
		parent.add_child(s)
		var tw: Tween = s.create_tween()
		tw.tween_interval(randf_range(14, 22))
		tw.tween_property(s, "modulate:a", 0.0, 3.0)
		tw.tween_callback(s.queue_free)


## damage numbers (off by default): chunky digits that rise and fade
static func number(parent: Node, pos: Vector2, v: float) -> void:
	var l := Label.new()
	l.text = str(int(round(v)))
	l.add_theme_font_size_override("font_size", 22 if v < 50 else 34)
	l.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.position = pos + Vector2(randf_range(-14, 8), 0)
	l.z_index = 200
	l.z_as_relative = false
	parent.add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 50.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
