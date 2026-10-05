extends Node2D
## The Iron Golem standing in the zone: the sprite (iron_golem_<weapon>[_noshield]) and the ally interface monsters
## and their missiles use. Group "allies" (while it stands; a dormant golem is not a target): tp, radius, take_hit().

var g                        # the golem's logic (golem.gd)
var spr: AnimSprite
var kind := ""
var shadow: Polygon2D

var tp: Vector2:
	get:
		return g.tp if g else Vector2.ZERO
var radius: float:
	get:
		return g.r if g else 0.6

func setup(golem) -> void:
	g = golem
	g.node = self
	shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * 58.0, sin(a) * 22.0 + 6.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.32)
	add_child(shadow)
	_sprite()
	position = Iso.to_screen(g.tp)

func _sprite() -> void:
	var w: String = g.book.gweapon
	var k := "iron_golem_%s%s" % [w, "" if g.shield else "_noshield"]
	if k == kind:
		return
	kind = k
	var old_anim := "idle"
	if spr:
		old_anim = spr.anim
		spr.queue_free()
	spr = AnimSprite.new(Data.sprite_set(k))
	add_child(spr)
	spr.play(old_anim)

func take_hit(dmg: float, elem: String = "phys", from = null) -> void:
	if g:
		g.take_hit(dmg, elem, from)

func is_down() -> bool:
	return g == null or g.state == "dormant"

func _process(dt: float) -> void:
	if g == null or g.node != self:
		queue_free()
		return
	_sprite()
	position = Iso.to_screen(g.tp)
	if g.state == "dormant":
		if is_in_group("allies"):
			remove_from_group("allies")
	elif not is_in_group("allies"):
		add_to_group("allies")
	spr.face = g.face
	spr.view = g.view
	var a := "idle"
	if g.state == "dormant":
		a = "dormant"
		spr.view = "front"
	elif g.state == "chargeWind":
		a = "charge_wind"
	elif g.state == "charge":
		a = "charge"
	elif not g.atk.is_empty():
		var k: float = g.atk["t"] / maxf(0.01, g.atk["dur"])
		if k < 0.5:
			a = "wind"
		else:
			a = "atk"
	elif g.moved > 0.0005:
		a = "walk"
	spr.play(a)
	if a == "atk":
		var k2: float = g.atk["t"] / maxf(0.01, g.atk["dur"])
		spr.set_index(0 if k2 < 0.6 else (1 if k2 < 0.72 else 2))
	elif a == "walk":
		# 4.2 frames per yard walked
		spr.fps_override = 4.2 * g.moved / maxf(dt, 0.001)
		spr.step(dt)
		spr.fps_override = 0.0
	elif a == "idle":
		spr.fps_override = 2.0
		spr.step(dt)
		spr.fps_override = 0.0
	else:
		spr.set_index(0)
	var m := Color(1, 1, 1, 0.92 if g.state == "dormant" else 1.0)
	if g.ramp > 0.0:
		m = Color(1.12, 1.14, 1.1, 1.0)     # pale, not a glow
	spr.modulate = m
