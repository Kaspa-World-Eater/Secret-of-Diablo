extends "res://entities/ai/brain.gd"
## OSSUARY WARDENS (and the Trunk-Thing): a tower shield of fused skulls. What strikes it from the front arc
## (cos > 0.34 toward the blow's source) is 85% blocked, unless it is recovering from its own blow or reeling.
## The plain melee rhythm at 90% pace; the Trunk-Thing barely moves (0.35 yd/s) and lashes at 1.8 yd.
## Tell: the shield lowers (the wind pose). Counter: flank it, or break its poise. zc_combat22.js AI22.shield, monDmg22.

var fdir := Vector2(1, 0)

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	fdir = dir_to(m, h.tp)
	melee_k(m, h, dt, 0.9)

func damage_taken_mult(m: Monster, elem: String, from: Vector2, opts: Dictionary) -> float:
	if state == "recover" or m.reeling > 0.0 or from == Vector2.INF or state == "sleep":
		return 1.0
	var v := from - m.tp
	if v.length() < 0.001:
		return 1.0
	if v.normalized().dot(fdir) > 0.34:
		if world:
			world.grit_burst(m.tp + fdir * 0.4, Color(0.91, 0.886, 0.816), 2, 0.6, 60.0)
		return 0.15
	return 1.0

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
