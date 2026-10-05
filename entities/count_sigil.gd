class_name CountSigil
extends Node2D
## The Ossuarch's count, hung over the head of whatever he has cursed (the user, 2026-09-30: "a white geometric symbol
## number thing, ghostly and ethereal above their head"). A ring of nine points, the curse's own figure inside it,
## and the count's numeral at its heart. Each notch lights a point and draws the next line of the figure; at nine the
## count closes: the sigil swells and thins away. White and pale, slow: it breathes and turns, it never flickers.
## Kinds: "open" (Open Count: the nine-pointed star, drawn stroke by stroke), "fewer" (The Fewer: one line standing
## alone), "weigh" (The Weighing: a beam and two pans), "stair" (The Ninth Stair: nine steps going down).
## Use: CountSigil.on(monster, kind) returns the sigil (one per monster); sigil.count = n; sigil.close().
## Test: --arena=5 --sigils.

const R := 22.0
var kind := "open"
var count := 0
var shown := 0.0          # the count as drawn, easing toward count
var t := 0.0
var closing := -1.0
var motes: Array = []
var font: Font

static func on(m: Node2D, k: String) -> CountSigil:
	var s: CountSigil = m.get_node_or_null("CountSigil")
	if s == null:
		s = CountSigil.new()
		s.name = "CountSigil"
		m.add_child(s)
	s.kind = k
	return s

func _ready() -> void:
	z_index = 60
	z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # the dark never hides it
	material = mat
	font = load("res://ui/uikit.gd").font("sc")
	var p = get_parent()
	var r: float = p.radius if "radius" in p else 0.3
	position = Vector2(0, -150.0 * clampf(r / 0.3, 0.8, 2.2) - 30.0)
	modulate.a = 0.0

func close() -> void:
	closing = 0.0

func _process(dt: float) -> void:
	t += dt
	if has_meta("demo"):   # --sigils: the count climbs on its own, to show every step
		count = mini(9, int(t / 0.7) + int(get_meta("demo")))
	shown = move_toward(shown, float(count), dt * 6.0)
	var p = get_parent()
	# hang just over its head, wherever the head is this frame
	if p and "spr" in p and p.spr is Sprite2D and p.spr.texture:
		var top: float = p.spr.position.y + p.spr.get_rect().position.y * absf(p.spr.scale.y)
		position.y = lerpf(position.y, top - R - 8.0, minf(1.0, dt * 8.0)) if t > 0.1 else top - R - 8.0
	if p == null or ("dead" in p and p.dead and closing < 0.0):
		closing = 0.0 if closing < 0.0 else closing
	if closing >= 0.0:
		closing += dt
		scale = Vector2.ONE * (1.0 + closing * 1.4)
		modulate.a = maxf(0.0, 1.0 - closing / 0.6)
		if closing > 0.6:
			queue_free()
	else:
		modulate.a = minf(1.0, modulate.a + dt * 2.0)
	# a few pale threads drift up off it
	if randf() < dt * 6.0:
		var a := randf() * TAU
		motes.append({"p": Vector2(cos(a), sin(a)) * R * randf_range(0.6, 1.1), "v": Vector2(randf_range(-4, 4), -12.0 - randf() * 10.0), "t": 0.0, "life": 1.2 + randf()})
	for m in motes:
		m["t"] += dt
		m["p"] += m["v"] * dt
	motes = motes.filter(func(m): return m["t"] < m["life"])
	queue_redraw()

func _pt(i: int, rot: float) -> Vector2:
	var a := -PI / 2.0 + i / 9.0 * TAU + rot
	return Vector2(cos(a), sin(a)) * R

## a strand of the figure: lit strands are the count, the rest wait as the faintest ghost of themselves
func _strand(a: Vector2, b: Vector2, i: int, lit_c: Color, ghost: Color) -> void:
	var f := clampf(shown - i, 0.0, 1.0)
	draw_line(a, b, ghost, 1.0)
	if f > 0.0:
		draw_line(a, a.lerp(b, f), lit_c, 2.0)

func _draw() -> void:
	var breath := 0.8 + 0.12 * sin(t * 1.6)
	var bob := Vector2(0, sin(t * 1.1) * 2.0)
	var W := Color(0.95, 0.97, 1.0, 0.95 * breath)
	var GHOST := Color(0.85, 0.88, 0.95, 0.16 * breath)
	var rot := t * 0.12
	draw_set_transform(bob, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, R + 3.0, 0.0, TAU, 40, Color(GHOST, 0.14 * breath), 1.0)
	match kind:
		"open":   # the nine-pointed star {9/4}: a strand per notch
			for i in 9:
				_strand(_pt(i * 4 % 9, rot), _pt((i + 1) * 4 % 9, rot), i, W, GHOST)
		"fewer":  # nine spokes going out from one point alone
			for i in 9:
				var a := -PI / 2.0 + i / 9.0 * TAU + rot
				_strand(Vector2(cos(a), sin(a)) * R * 0.18, Vector2(cos(a), sin(a)) * R, i, W, GHOST)
		"weigh":  # the beam tips as the strands of the pans fill
			var tilt := clampf(shown / 9.0, 0.0, 1.0) * 0.45
			_strand(Vector2(0, -R * 0.8), Vector2(0, R * 0.8), -1, W, GHOST)
			for i in 9:
				var side := -1.0 if i % 2 == 0 else 1.0
				var y := -R * 0.45 + (i / 2) * R * 0.22 + side * tilt * R * 0.5
				_strand(Vector2(side * R * 0.2, y), Vector2(side * R * 0.85, y + side * tilt * R * 0.35), i, W, GHOST)
		"stair":  # nine steps going down
			for i in 9:
				var x0 := -R * 0.8 + i * R * 0.18
				var y0 := -R * 0.7 + i * R * 0.16
				_strand(Vector2(x0, y0), Vector2(x0 + R * 0.18, y0 + R * 0.16), i, W, GHOST)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in motes:
		var al: float = clampf(1.0 - m["t"] / m["life"], 0.0, 1.0)
		draw_rect(Rect2(m["p"] * 0.6 + bob, Vector2(2, 2)), Color(0.9, 0.93, 1.0, 0.3 * al))
