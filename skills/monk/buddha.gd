extends Node2D
## The-Weeping-One-Who-Walks: the weeping stone guardian from the gate of the Peak, many-armed and taller than a house
## (zw_monk.js summonBuddha / updateBuddha / hurtBuddha). It lumbers after what is near the Empty Hand, smashes it
## flat and draws its anger (every 3 s it calls the creatures within 5 yd to itself). Cast again to send it to the
## cursor, or on it to send it back into the earth; it keeps its wounds and mends 1% a second when idle.
## An ally (group "allies": tp, radius, take_hit, is_down) so creatures and their missiles can strike it.
## Drawn here in stone until it has a painted sprite.

var book
var tp = Vector2.ZERO
var radius = 0.62
var hp = 100.0
var max_hp = 100.0
var face = 1
var cd = 1.0
var rise = 1.0
var taunt_t = 0.5
var atk = {}
var order = {}
var hurt_t = 0.0
var walk_d = 0.0

const STONE := Color8(150, 146, 136)
const STONE_D := Color8(84, 80, 74)
const STONE_L := Color8(196, 192, 180)
const TEAR := Color8(191, 232, 255)

func _ready() -> void:
	add_to_group("allies")
	position = Iso.to_screen(tp)

func is_down() -> bool:
	return rise > 0.0

func take_hit(dmg: float, _elem: String = "phys", _from: Vector2 = Vector2.INF) -> void:
	hp -= dmg * 0.8
	hurt_t = 0.12
	if hp <= 0.0 and book:
		book.buddha_fell()

func _physics_process(dt: float) -> void:
	if book == null or book.hero == null or book.zone == null:
		return
	var h = book.hero
	var z = book.zone
	var st: Dictionary = book.buddha_stats()
	max_hp = st["max"]
	cd -= dt
	hurt_t = maxf(0.0, hurt_t - dt)
	position = Iso.to_screen(tp)
	queue_redraw()
	if rise > 0.0:
		rise -= dt
		return
	taunt_t -= dt
	if taunt_t <= 0.0:
		taunt_t = 3.0
		var n = 0
		for m in book.foes(tp, 5.0):
			m.set_meta("mys_taunt_by", self)
			m.set_meta("mys_taunt_until", Time.get_ticks_msec() / 1000.0 + 3.0)
			book.wake(m)
			n += 1
		if n > 0:
			book.ring(tp, 5.0, 0.5, Color(0.69, 0.67, 0.63, 0.6))
	var o = tp
	if not atk.is_empty():
		atk["t"] += dt
		if atk["t"] >= 0.55 and not atk["done"]:
			atk["done"] = true
			var hx: Vector2 = tp + atk["d"] * 0.9
			for m in book.foes(hx, 1.5):
				book.hurt(m, st["dmg"], "kweep", {"heavy": true})
				book.stun(m, 1.0 if book.K("kweep2") > 0 else 0.35)
			book.slams.append({"tp": hx, "z": 0, "t": 0.5, "max": 0.5, "kind": "crater", "R": 1.4})
			Game.shake(4.0)
			Sfx.play("heavy", 0.9, 0.5)
		if atk["t"] > 1.0:
			atk = {}
			cd = 0.9
		return
	if not order.is_empty():
		order["t"] -= dt
		var d: float = tp.distance_to(order["tp"])
		if d < 0.4 or order["t"] <= 0.0:
			order = {}
		else:
			_step(order["tp"], 2.6 * dt)
	else:
		var tg = book.near(tp, 7.0, func(m): return m.tp.distance_to(h.tp) < 11.0)
		if tg != null:
			var d2: float = tg.tp.distance_to(tp)
			face = 1 if (tg.tp.x - tg.tp.y) > (tp.x - tp.y) else -1
			if d2 > 1.1 + tg.radius:
				_step(tg.tp, 2.4 * dt)
			elif cd <= 0.0:
				atk = {"t": 0.0, "d": (tg.tp - tp).normalized(), "done": false}
		elif tp.distance_to(h.tp) > 2.2:
			_step(h.tp, 2.8 * dt)
		elif hp < max_hp:
			hp = minf(max_hp, hp + max_hp * 0.01 * dt)
	walk_d += tp.distance_to(o)
	if tp.distance_to(h.tp) > 16.0:
		tp = h.tp + Vector2(1, 0)
		if z.is_solid(tp):
			tp = h.tp

func _step(to: Vector2, s: float) -> void:
	var v = to - tp
	if v.length() < 0.01:
		return
	face = 1 if (to.x - to.y) > (tp.x - tp.y) else -1
	tp = book.zone.move(tp, v.normalized() * minf(s, v.length()), 0.4)

func _draw() -> void:
	var up = 1.0 - clampf(rise, 0.0, 1.0)
	var sink = (1.0 - up) * 220.0
	var bob = sin(walk_d * 3.0) * 3.0
	var lean = 0.0
	if not atk.is_empty():
		lean = sin(clampf(atk["t"] / 0.55, 0.0, 1.0) * PI) * 26.0
	var fl = Color(1.3, 1.3, 1.3) if hurt_t > 0.0 else Color.WHITE
	# ground shadow
	draw_colored_polygon(_ell(Vector2.ZERO, 70, 22), Color(0, 0, 0, 0.35))
	var base = Vector2(0, sink - bob)
	# the plinth-legs and the robed body
	var body = PackedVector2Array([base + Vector2(-58, 0), base + Vector2(58, 0), base + Vector2(40 + lean * 0.3, -170), base + Vector2(-40 + lean * 0.3, -170)])
	draw_colored_polygon(body, STONE * fl)
	draw_line(base + Vector2(-58, 0), base + Vector2(-40 + lean * 0.3, -170), STONE_L, 3.0)
	for i in 4:
		var y = -30.0 - i * 34.0
		draw_line(base + Vector2(-50 + i * 4, y), base + Vector2(50 - i * 4, y), STONE_D, 2.0)
	# the many arms: three pairs, fanned
	for i in 3:
		for sd in [-1, 1]:
			var sh = base + Vector2(sd * (34 - i * 4) + lean * 0.4, -150 + i * 22)
			var a = (-0.9 + i * 0.5) * sd
			var hand = sh + Vector2(sd * cos(a) * 70.0, -sin(absf(a)) * 60.0 + i * 20.0)
			if i == 0 and not atk.is_empty():
				hand = sh + Vector2(sd * 30.0 + lean * face, -80.0 + lean * 3.0)
			draw_line(sh, hand, STONE_D * fl, 12.0)
			draw_line(sh, hand, STONE * fl, 8.0)
			draw_circle(hand, 9.0, STONE_L * fl)
	# the head: a heavy calm face, weeping
	var hc = base + Vector2(lean * 0.35, -196)
	draw_circle(hc, 28.0, STONE * fl)
	draw_circle(hc + Vector2(0, -26), 13.0, STONE_D * fl)
	draw_line(hc + Vector2(-13, -4), hc + Vector2(-5, -4), STONE_D, 3.0)
	draw_line(hc + Vector2(5, -4), hc + Vector2(13, -4), STONE_D, 3.0)
	var tk = fmod(walk_d * 0.6 + Time.get_ticks_msec() / 1000.0 * 0.4, 1.0)
	draw_rect(Rect2(hc + Vector2(-10, -1 + tk * 26.0), Vector2(2, 5)), TEAR)
	draw_rect(Rect2(hc + Vector2(8, -1 + fmod(tk + 0.5, 1.0) * 26.0), Vector2(2, 5)), TEAR)
	# its life, a thin bar while it is hurt
	if hp < max_hp:
		var w = 90.0
		draw_rect(Rect2(Vector2(-w / 2.0, -250 + sink), Vector2(w, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(Vector2(-w / 2.0, -250 + sink), Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 5)), STONE_L)

func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p = PackedVector2Array()
	for i in 24:
		var a = i / 24.0 * TAU
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p
