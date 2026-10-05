extends Node2D
## Missiles: teeth, bone spear, bone spirit, poison nova, arrows and bolts.
## Position is at ground level (matching unit feet); art is drawn raised.

const LIFT := Vector2(0, -14)

var vel := Vector2.ZERO
var speed := 300.0
var team := 0  # -1 hits everyone except the owner
var owner_unit = null
var only_target = null
var dmg_min := 0.0
var dmg_max := 0.0
var dtype := "magic"
var pierce := false
var max_dist := 500.0
var radius := 6.0
var color := Color.WHITE
var style := "bolt"
var poison_total := 0.0
var slow := 0.0
var homing := false
var target = null

var _traveled := 0.0
var _age := 0.0
var _hit := {}


func _physics_process(delta: float) -> void:
	_age += delta
	if homing:
		if target == null or not is_instance_valid(target) or target.dead:
			target = Game.nearest_hostile(global_position, team, 450.0)
		if target != null:
			var desired: Vector2 = (target.global_position - global_position).normalized() * speed
			vel = vel.lerp(desired, clamp(5.0 * delta, 0.0, 1.0)).normalized() * speed
	var step := vel * delta
	position += step
	_traveled += step.length()
	if _traveled > max_dist or Game.world.blocks_projectile_px(global_position):
		queue_free()
		return
	for u in Game.units:
		if u.dead or u == owner_unit:
			continue
		var id: int = u.get_instance_id()
		if _hit.has(id) or not _can_hit(u):
			continue
		var rr: float = u.radius + radius
		if global_position.distance_squared_to(u.global_position) <= rr * rr:
			_hit[id] = true
			_apply(u)
			if not pierce:
				queue_free()
				return
	queue_redraw()


func _can_hit(u) -> bool:
	if team == -1:
		return true
	if only_target != null and is_instance_valid(only_target) and u == only_target:
		return true
	return u.team != team


func _apply(u) -> void:
	var src = owner_unit if is_instance_valid(owner_unit) else null
	if dmg_max > 0.0:
		u.take_damage(randf_range(dmg_min, dmg_max), dtype, src)
	if is_instance_valid(u) and not u.dead:
		if poison_total > 0.0:
			u.apply_poison(poison_total, 2.0, src)
		if slow > 0.0:
			u.apply_slow(slow, 1.5)


func _draw() -> void:
	var d := vel.normalized()
	var o := d.orthogonal()
	var c := LIFT
	match style:
		"teeth":
			draw_colored_polygon(PackedVector2Array([c + d * 6, c + o * 2.5 - d * 3, c - o * 2.5 - d * 3]), color)
		"spear":
			draw_line(c - d * 16, c + d * 10, Color(0.2, 0.15, 0.1), 5.0)
			draw_line(c - d * 16, c + d * 10, color, 3.0)
			draw_colored_polygon(PackedVector2Array([c + d * 16, c + d * 8 + o * 4, c + d * 8 - o * 4]), color)
		"spirit":
			draw_circle(c, 9.0, Color(color, 0.25))
			draw_circle(c, 5.5, Color(color, 0.8))
			for i in 4:
				draw_circle(c - d * (6 + i * 5), 4.0 - i, Color(color, 0.4 - i * 0.08))
		"nova":
			draw_circle(c, 5.0, Color(color, 0.55))
			draw_circle(c, 2.5, color)
		"arrow":
			draw_line(c - d * 9, c + d * 5, Color(0.35, 0.25, 0.15), 2.0)
			draw_colored_polygon(PackedVector2Array([c + d * 8, c + d * 3 + o * 2.5, c + d * 3 - o * 2.5]), Color(0.75, 0.75, 0.8))
		"fire":
			draw_circle(c, 7.0, Color(1, 0.5, 0.1, 0.5))
			draw_circle(c, 4.0, Color(1, 0.9, 0.4))
		_:
			draw_circle(c, 6.0, Color(color, 0.4))
			draw_circle(c, 3.5, color)
