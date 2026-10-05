extends "res://entities/ai/brain.gd"
## TITHE-HANDS: they circle at 2.7 yd and dart in from behind: when one holds an attack turn, when you are busy with
## something else, when others press you, or on a whim. In the wind-up it lunges (x1.7). Back to a wall and they can
## only circle. The last one flees at half life. Tell: fingers tense. zc_combat22.js AI22.flank (v0.88).

var flee_t := 0.0
var fled := false
var orbit := 0.0
var oa := INF
var bk := 0.0

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if flee_t > 0.0:
		flee_t -= dt
		m.step_toward(m.tp - dir_to(m, h.tp) * 2.0, dt, m.move_speed() * 1.1)
		if flee_t <= 0.0:
			state = "chase"
		return
	if m.hp < m.hp_max * 0.5 and not fled and awake_packmates(m, 10.0) == 0:
		fled = true
		flee_t = 3.0
		state = "flee"
		_release_token(m)
		return
	if h.dead or d > 26.0 or state == "home":
		melee_rhythm(m, h, dt)
		return
	if state in ["wind", "strike", "recover", "gap"]:
		if state == "wind" and d > reach * 0.8 and not m.zone.is_solid(m.tp + dir_to(m, h.tp) * 0.3):
			m.step_toward(h.tp, dt, m.move_speed() * 1.7)   # v0.88: the lunge
		melee_rhythm(m, h, dt)
		if state == "chase":
			orbit = 1.1
		return
	state = "chase"
	orbit -= dt
	if oa == INF:
		oa = atan2(m.tp.y - h.tp.y, m.tp.x - h.tp.x)
	oa += dt * 1.1 * circle_dir()
	var f := hero_front(h)
	var busy := h.act != "" or (h.target != null and h.target != m)
	var others := false
	for o in m.get_tree().get_nodes_in_group("monsters"):
		if o != m and o.brain and o.brain.state != "sleep" and o.tp.distance_to(h.tp) < 1.4:
			others = true
			break
	var has_turn := token or (d < 5.0 and take_token(m))
	if orbit <= 0.0 and cd <= 0.0 and (has_turn or busy or others or randf() < dt * 0.25):
		# aim for the back: a point behind the hero, turned a little per hand
		var off := circle_dir() * 0.5
		var b := (-f).rotated(off)
		var p := h.tp + b * 0.9
		if not m.zone.is_solid(p):
			bk += dt
			if d > reach + 0.6 and bk > 1.2:
				_approach(m, h.tp, dt, 1.25)
				return
			if m.tp.distance_to(p) > 0.5 and d > reach + 0.6:
				_approach(m, p, dt, 1.25)
				return
			bk = 0.0
			state = "wind"
			st = wind
			aim = h.tp
			m.look(h.tp - m.tp)
			return
		# your back is to a wall: they can only wait and circle
	var o2 := h.tp + Vector2(cos(oa), sin(oa)) * 2.7
	if m.zone.is_solid(o2):
		odir = -circle_dir()
	_approach(m, o2, dt, 0.8)
	m.look(h.tp - m.tp)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
