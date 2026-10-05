class_name CamDirector
extends RefCounted
## The camera's eye (wiki 06 §3, "cinematography is key"). The camera stays on the pilgrim, but it is not a dead lock:
## - it leads a little into the way you walk, so you see what you are walking into, and settles back when you stop;
## - on arriving somewhere it opens on the place first (an establishing drift from deeper in the land back to you);
##   coming back from the lantern it sinks down onto you from above;
## - when a great one wakes it holds you both in the frame, leaning toward the threat;
## - when you fall it pushes in slowly on the body, and lets go when the lantern gives you back.
## The shake (Game.shake) rides on top of all of it.

var main: Node
var cam: Camera2D
var lead := Vector2.ZERO
var last_pos := Vector2.INF
var arr_from := Vector2.ZERO      # establishing offset, eased to zero
var arr_t := 9.0
var arr_len := 2.6
var boss_off := Vector2.ZERO
var fall := 0.0                   # 0..1, the push-in on a fallen pilgrim
var poi := Vector2.ZERO           # the eye drawn toward a near lantern (the brightest spot leads the eye)

func _init(m: Node, c: Camera2D) -> void:
	main = m
	cam = c

## a new zone: from a gate we open looking into the land; from the lantern (or the first waking) we sink down onto you
func arrive(zone, hero, from: String) -> void:
	lead = Vector2.ZERO
	last_pos = hero.position
	boss_off = Vector2.ZERO
	fall = 0.0
	cam.zoom = Vector2.ONE
	arr_t = 0.0
	if from == "" or from == "__lantern":
		arr_from = Vector2(0, -150)
		arr_len = 2.2
		return
	# deeper into the land: toward the zone's middle from where we stand
	var w := float(zone.w)
	var h := float(zone.h)
	var mid := Iso.to_screen(Vector2(w, h) * 0.5)
	var dv: Vector2 = mid - hero.position
	arr_from = dv.normalized() * minf(220.0, dv.length() * 0.5) if dv.length() > 1.0 else Vector2.ZERO
	arr_len = 2.8

## a jump within the same zone (a lantern, a passage): no drift, no lead
func cut(hero) -> void:
	lead = Vector2.ZERO
	last_pos = hero.position
	arr_t = 9.0

func update(dt: float, hero, boss, zone = null) -> Vector2:
	if dt <= 0.0:
		dt = 0.016
	# 1. the lead: the way you walk, softened a great deal so the frame glides and never jerks
	var vel := Vector2.ZERO
	if last_pos != Vector2.INF:
		vel = (hero.position - last_pos) / dt
		if vel.length() > 2000.0:   # a blink or a cut, not a walk
			vel = Vector2.ZERO
	last_pos = hero.position
	var want := Vector2.ZERO
	if not hero.dead and hero.walking:
		want = vel * 0.32
		if want.length() > 64.0:
			want = want.normalized() * 64.0
	lead += (want - lead) * minf(1.0, dt * (1.4 if want != Vector2.ZERO else 0.9))
	# 2. the establishing drift after arriving
	var arr := Vector2.ZERO
	if arr_t < arr_len:
		arr_t += dt
		var u := clampf(arr_t / arr_len, 0.0, 1.0)
		arr = arr_from * pow(1.0 - u, 3.0)
	# 3. a great one awake: hold you both, leaning toward it
	var bw := Vector2.ZERO
	if boss != null and is_instance_valid(boss) and not boss.dead and not hero.dead:
		var dv: Vector2 = boss.position - hero.position
		if dv.length() < 900.0:
			bw = dv * 0.3
			if bw.length() > 170.0:
				bw = bw.normalized() * 170.0
	boss_off += (bw - boss_off) * minf(1.0, dt * 1.2)
	# 4. a lantern near: the frame leans a little toward it, as the eye does
	var pw := Vector2.ZERO
	if zone != null and bw == Vector2.ZERO:
		for l in zone.lanterns:
			if not (l is Dictionary):
				continue
			var lv: Vector2 = Iso.to_screen(Vector2(float(l.get("x", 0)), float(l.get("y", 0)))) - hero.position
			var ld := lv.length()
			if ld < 380.0 and ld > 40.0:
				var k := 0.22 * sin(PI * ld / 380.0)
				if (lv * k).length() > pw.length():
					pw = lv * k
	poi += (pw - poi) * minf(1.0, dt * 0.8)
	# 5. the fall: a slow push in on the body; the frame drifts down to the ground where you lie
	fall = clampf(fall + (dt / 3.0 if hero.dead else -dt * 2.0), 0.0, 1.0)
	var fk := fall * fall * (3.0 - 2.0 * fall)
	cam.zoom = Vector2.ONE * (1.0 + 0.12 * fk)
	var fo := Vector2(0, 30.0 * fk)
	return hero.position + Vector2(0, -40) + lead * (1.0 - fk) + arr + (boss_off + poi) * (1.0 - fk) + fo
