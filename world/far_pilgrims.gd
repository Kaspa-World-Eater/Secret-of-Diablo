class_name FarPilgrims
extends Node
## Others on the road. Out in the open at dusk and by night, now and then a pilgrim of another order walks far off
## across the dark: a lantern moving, and a figure seen only in its own small pool of light. They are going somewhere
## of their own. They cannot be reached: come within a few steps and they are not there. (Dark Souls' phantoms;
## the Stranger would say the Hide remembers everyone who ever walked it.)
## Only outdoors, never in the camp, one at a time, every minute or so.

const ORDERS := ["monk", "hemomancer", "ossumancer", "miasmancer", "animancer"]
var main: Node
var zone: Zone
var hero: Hero
var cur: Dictionary = {}
var wait := 20.0

func _init(m: Node) -> void:
	main = m

func bind(z: Zone, h: Hero) -> void:
	_end()
	zone = z
	hero = h
	wait = randf_range(12.0, 30.0)

func _end() -> void:
	if not cur.is_empty():
		if is_instance_valid(cur["node"]):
			cur["node"].queue_free()
	cur = {}

func _process(dt: float) -> void:
	if zone == null or not is_instance_valid(zone) or hero == null or not is_instance_valid(hero):
		return
	var outdoor: bool = zone.d.get("outdoor", false)
	var town: bool = zone.id == "moor" or zone.d.get("town", false)
	var night := 1.0 - Game.day_k()
	if cur.is_empty():
		if not outdoor or town or night < 0.35 or hero.dead:
			return
		wait -= dt
		if wait <= 0.0:
			wait = randf_range(40.0, 90.0)
			_spawn()
		return
	_walk(dt)

func _spawn() -> void:
	# somewhere at the edge of seeing, on open ground, walking across your view rather than toward you
	for tries in 30:
		# a point in the upper or lower part of the frame, well away from you, walking across it
		var sx := randf_range(-760.0, 760.0)
		var sy := -randf_range(170.0, 330.0)
		var dd := Vector2(sx / 72.0, sy / 36.0)      # (x - y, x + y)
		var p := hero.tp + Vector2((dd.x + dd.y) * 0.5, (dd.y - dd.x) * 0.5)
		if p.distance_to(hero.tp) < 6.0 or p.x < 2 or p.y < 2 or p.x > zone.w - 2 or p.y > zone.h - 2 or zone.is_solid(p):
			continue
		var side := Vector2(1, -1).normalized() * (-1.0 if sx > 0.0 else 1.0)
		side = side.rotated(randf_range(-0.3, 0.3))
		var node := Node2D.new()
		var kind: String = ORDERS[randi() % ORDERS.size()]
		if kind == hero.cls:
			kind = ORDERS[(ORDERS.find(kind) + 1) % ORDERS.size()]
		var spr := AnimSprite.new(Data.sprite_set(kind))
		spr.play("walk")
		node.add_child(spr)
		var L := PointLight2D.new()     # the pool its lantern throws (the dark layer draws it)
		L.texture = Lights.radial(64)
		L.color = Color8(236, 178, 104)
		L.energy = 0.0
		L.set_meta("dark_r", 22.0)
		L.set_meta("dark_core", 0.22)
		L.set_meta("dark_w", 0.45)
		L.position = Vector2(14, -6)
		node.add_child(L)
		zone.sorted.add_child(node)
		cur = {"node": node, "spr": spr, "light": L, "p": p, "dir": side, "t": 0.0, "life": randf_range(24.0, 40.0), "out": -1.0, "face": 1}
		_place()
		return

func _place() -> void:
	var node: Node2D = cur["node"]
	node.position = Iso.to_screen(cur["p"])

func _walk(dt: float) -> void:
	var node = cur["node"]
	if not is_instance_valid(node):
		cur = {}
		return
	cur["t"] += dt
	var p: Vector2 = cur["p"]
	var dir: Vector2 = cur["dir"]
	# a slow walker's pace; round what stands in the way
	var nxt := p + dir * 1.25 * dt
	if zone.is_solid(nxt + dir * 0.4):
		var turned := false
		for k in [0.6, -0.6, 1.2, -1.2]:
			var d2 := dir.rotated(k)
			if not zone.is_solid(p + d2 * 0.6):
				cur["dir"] = d2
				turned = true
				break
		if not turned and cur["out"] < 0.0:
			cur["out"] = 0.0
	else:
		cur["p"] = nxt
	# a slight wander in the line
	cur["dir"] = (cur["dir"] as Vector2).rotated(sin(cur["t"] * 0.4) * 0.15 * dt).normalized()
	_place()
	var spr: AnimSprite = cur["spr"]
	var vf: Array = AnimSprite.hero_view(cur["dir"], cur["face"])
	if vf[0] != "":
		spr.view = vf[0]
	spr.face = vf[1]
	cur["face"] = vf[1]
	spr.step(dt)
	# they are not there when you come to them; and each walks only so far
	var dh: float = (cur["p"] as Vector2).distance_to(hero.tp)
	if cur["out"] < 0.0 and (dh < 4.5 or cur["t"] > cur["life"] or dh > 18.0):
		cur["out"] = 0.0
	var a := minf(1.0, cur["t"] / 3.0)
	if cur["out"] >= 0.0:
		cur["out"] += dt
		a *= maxf(0.0, 1.0 - cur["out"] / 2.0)
		if cur["out"] >= 2.0:
			_end()
			return
	# a phantom: a little pale, a little see-through
	node.modulate = Color(0.78, 0.8, 0.86, 0.8 * a)
	var L: PointLight2D = cur["light"]
	L.position = Vector2(14 * spr.face, -6)
	L.visible = a > 0.25
