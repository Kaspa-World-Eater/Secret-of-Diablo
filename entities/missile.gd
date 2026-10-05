class_name Missile
extends Node2D
## A thing that flies across the tile grid: arrows, bolts, orbs. Stops at walls (tall tiles), hits the first body.
## owner_side: "hero" hits monsters, "monster" hits the hero and allies. Drawn plainly: no glow, no trail.

var zone: Zone
var tp := Vector2.ZERO
var vel := Vector2.ZERO        # yards per second
var life := 2.0
var dmg := 1.0
var elem := "phys"
var side := "monster"
var radius := 0.25
var height := 60.0             # screen px above the ground
var look := "arrow"            # arrow | bolt | orb | needle
var col := Color(0.85, 0.82, 0.74)
var on_hit: Callable
var pierce := 0
var hit_list: Array = []
var opts := {}
## The Bell-Warden reversed (skills/animancer.gd): creatures within r of tp can't shoot while it holds
static var hush := {}

var by_desc := ""        # who loosed it, for the death screen (Combat.who)
const NAMES := {"needle": "its needle", "orb": "its orb", "arrow": "its arrow", "bolt": "its bolt"}

static func fire(z: Zone, from: Vector2, to: Vector2, speed: float, damage: float, e: String, who: String, kind: String = "arrow") -> Missile:
	var m := Missile.new()
	m.zone = z
	m.tp = from
	m.vel = (to - from).normalized() * speed
	m.dmg = damage
	m.elem = e
	m.side = who
	m.look = kind
	if who == "monster" and Combat.striker != null and is_instance_valid(Combat.striker) and Combat.striker_frame == Engine.get_physics_frames():
		m.by_desc = Combat.who(Combat.striker)   # the damage was rolled this frame by the one loosing it
	m.add_to_group("missiles")
	m.life = 12.0 / maxf(1.0, speed) + 0.6
	if who == "monster" and not hush.is_empty() and Time.get_ticks_msec() / 1000.0 < float(hush["until"]) and from.distance_to(hush["tp"]) < float(hush["r"]):
		m.dmg = 0.0
		m.life = 0.0   # the shot dies in the hand
	z.sorted.add_child(m)
	m.position = Iso.to_screen(m.tp)
	return m

func _physics_process(dt: float) -> void:
	life -= dt
	var n := 3
	for i in n:
		tp += vel * dt / n
		if zone.blocks_sight(tp) and zone.type_at(tp) != 4:
			queue_free()
			return
		if _collide():
			return
	position = Iso.to_screen(tp)
	queue_redraw()
	if life <= 0.0:
		queue_free()

func _collide() -> bool:
	if side == "hero":
		for m in get_tree().get_nodes_in_group("monsters"):
			if m.dead or m.buried or m in hit_list:
				continue
			if m.tp.distance_to(tp) < radius + m.radius:
				hit_list.append(m)
				if on_hit.is_valid():
					on_hit.call(m, self)
				else:
					Combat.hit_monster(m, dmg, elem, tp - vel.normalized(), opts)
				if pierce <= 0:
					queue_free()
					return true
				pierce -= 1
	else:
		var h: Hero = zone.hero_ref
		if h and not h.dead and h.tp.distance_to(tp) < radius + h.radius + 0.25 and h.skills and h.skills.catch_missile(self):
			queue_free()
			return true
		if h and not h.dead and h.tp.distance_to(tp) < radius + h.radius:
			Combat.hit_hero(h, dmg, elem, tp - vel.normalized(), {"src": (by_desc + "|" + NAMES.get(look, "its shot")) if by_desc != "" else ""})
			queue_free()
			return true
		for a in get_tree().get_nodes_in_group("allies"):
			if a.tp.distance_to(tp) < radius + a.radius and a.has_method("take_hit"):
				a.take_hit(dmg, elem, tp)
				queue_free()
				return true
	return false

func _draw() -> void:
	var dir := (Iso.to_screen(tp + vel.normalized()) - Iso.to_screen(tp)).normalized()
	var o := Vector2(0, -height)
	match look:
		"arrow", "needle":
			draw_line(o - dir * 26.0, o + dir * 10.0, col, 3.0)
			draw_line(o + dir * 10.0, o + dir * 4.0 + dir.orthogonal() * 4.0, col, 2.0)
		"bolt":
			draw_line(o - dir * 18.0, o + dir * 8.0, Color(0.82, 0.8, 0.72), 4.0)
		"orb":
			draw_circle(o, 9.0, Color(col.r, col.g, col.b, 0.85))
			draw_circle(o, 5.0, col.lightened(0.2))
