extends Node2D
## The lantern bearer: a tiny, immortal, untargetable companion carrying your
## light. Press L (controller: Y) to plant the lantern at the cursor and again to
## recall it. A planted lantern burns 25% brighter but you leave its light.

var owner_p = null
var planted := false
var plant_pos := Vector2.ZERO
var light: PointLight2D
var facing := Vector2.DOWN
var _t := 0.0
var _moving := false


func _ready() -> void:
	light = Lighting.make_light(200.0, Color(1.0, 0.86, 0.6), 1.05)
	light.position = Vector2(0, -26)
	add_child(light)
	Game.light_sources.append(self)


func _exit_tree() -> void:
	Game.light_sources.erase(self)


func light_radius_px() -> float:
	if owner_p == null:
		return 0.0
	return owner_p.light_radius * (1.25 if planted else 1.0)


func light_pos() -> Vector2:
	return global_position + Vector2(0, -26)


func toggle_plant(at: Vector2) -> void:
	if planted:
		planted = false
		Game.message("Lantern recalled")
		return
	var w = Game.world
	if at.distance_to(owner_p.global_position) > 260.0 or not w.is_walkable_px(at):
		at = global_position
	planted = true
	plant_pos = at
	Game.message("Lantern planted")


func _physics_process(delta: float) -> void:
	if owner_p == null:
		return
	_t += delta
	var goal: Vector2
	if planted:
		goal = plant_pos
	else:
		var f: Vector2 = owner_p.facing
		goal = owner_p.global_position - f * 26.0 + f.orthogonal() * 16.0
	var d := goal - global_position
	_moving = d.length() > 4.0
	if d.length() > 500.0:
		global_position = goal
	elif _moving:
		var spd: float = owner_p.move_speed * 1.25 * (1.0 if d.length() > 30.0 else 0.6)
		global_position += d.normalized() * min(d.length(), spd * delta)
		facing = d.normalized()
	var r := light_radius_px()
	light.texture_scale = r * 2.0 / 256.0
	light.energy = (1.0 + 0.06 * sin(_t * 9.0) + 0.04 * sin(_t * 23.0)) * Game.light_visual()
	queue_redraw()


func _draw() -> void:
	var o := Color(0.1, 0.07, 0.08)
	var bone := Color(0.93, 0.9, 0.82)
	var hop = abs(sin(_t * 12.0)) * 2.5 if _moving else 0.0
	var side = 0.0 if abs(facing.x) < 0.5 else sign(facing.x)
	# shadow
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if planted:
		# lantern hung on a bone post, bearer sits beside it
		draw_line(Vector2(0, 0), Vector2(0, -24), o, 4.0)
		draw_line(Vector2(0, 0), Vector2(0, -24), bone, 2.0)
		_lantern(Vector2(0, -26))
		_imp(Vector2(10, 0), 0.0, 0.0, o, bone)
	else:
		_imp(Vector2(0, -hop), side, hop, o, bone)
		var hand := Vector2(5 + side * 2, -14 - hop)
		draw_line(hand, hand + Vector2(0, -8), o, 2.0)
		_lantern(hand + Vector2(0, -12 + sin(_t * 6.0)))


func _imp(p: Vector2, side: float, _hop: float, o: Color, bone: Color) -> void:
	# a tiny skeleton: legs, ribcage, big skull
	draw_line(p + Vector2(-2, 0), p + Vector2(-2, -5), bone, 1.5)
	draw_line(p + Vector2(2, 0), p + Vector2(2, -5), bone, 1.5)
	draw_rect(Rect2(p + Vector2(-3.5, -12), Vector2(7, 7)), o)
	draw_rect(Rect2(p + Vector2(-2.5, -11), Vector2(5, 5)), bone)
	draw_circle(p + Vector2(side, -17), 5.5, o)
	draw_circle(p + Vector2(side, -17), 4.5, bone)
	draw_circle(p + Vector2(side - 1.6, -17), 1.1, o)
	draw_circle(p + Vector2(side + 1.6, -17), 1.1, o)


func _lantern(c: Vector2) -> void:
	var o := Color(0.1, 0.07, 0.08)
	var flick := 1.0 + 0.15 * sin(_t * 17.0)
	draw_circle(c, 9.0 * flick, Color(1, 0.8, 0.4, 0.22))
	draw_rect(Rect2(c + Vector2(-4, -5), Vector2(8, 10)), o)
	draw_rect(Rect2(c + Vector2(-3, -4), Vector2(6, 8)), Color(1, 0.85, 0.45))
	draw_circle(c, 2.0 * flick, Color(1, 1, 0.85))
	draw_line(c + Vector2(-4, -6), c + Vector2(4, -6), Color(0.35, 0.3, 0.25), 2.0)
