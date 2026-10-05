extends Node2D
## The Ossuary Colossus (f_bone.js fuseOne / updateColossus / colossusStrike / colLeap / hurtColossus): a hundred dead
## fused into one frame, seams and all. It grows with each skeleton fed into it (life, blows, size), keeps their
## shards of the Mantle, goes for his prey or the nearest threat near him, and leaps onto prey 2.6-7.5 yd off with a
## clear line, landing in a burst of bone that throws the small clear. With the Tower Shield (its weapon until army
## orders come) it bashes slow, takes far less, and its blows draw the struck onto it.
## An ally (group "allies": tp, radius, take_hit, is_down). The painted sprite is the web build's colossus_shield.
## No waits (the user's rule): it leaps whenever prey is at leaping range; Earthshaker makes the landing 30% harder.

const W := {"mult": 0.75, "dur": 1.0, "reach": 1.1, "dr": 0.3}   # the Tower Shield

var book
var tp := Vector2.ZERO
var n := 0
var hp := 100.0
var max_hp := 100.0
var radius := 0.45
var prey = null
var order := {}                # {tp, t}: march to a point
var atk := {}                  # {t, dur, T, hit}
var leap := {}                 # {from, to, t, dur}
var grow := 0.0
var hurt_t := 0.0
var taunt_t := 3.0
var face := 1
var view := "front"
var spr: AnimSprite

func _ready() -> void:
	add_to_group("allies")
	spr = AnimSprite.new(Data.sprite_set("colossus_shield"))
	spr.play("idle")
	add_child(spr)
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 12.0 + 6.0))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.4)
	add_child(sh)
	move_child(sh, 0)
	position = Iso.to_screen(tp)

func is_down() -> bool:
	return false

func take_hit(dmg: float, elem: String = "phys", _from: Vector2 = Vector2.INF) -> void:
	if hp <= 0.0:
		return
	dmg *= (100.0 / 140.0 if elem == "phys" else 0.85) * (1.0 - float(W["dr"])) * (0.75 if book.K("bulwarkC") > 0 else 1.0)
	hp -= dmg
	hurt_t = 0.1
	if book.K("cracked") > 0 and randf() < 0.12:
		book.motes.append({"tp": tp, "z": 8.0, "rise": 0.1, "out": 0.0, "v": Vector2.ZERO, "spd": 4.0, "t": 0.0, "dmg": 0.0, "hit": {}, "val": 1.0})
	if hp <= 0.0:
		remove_from_group("allies")
		book.colossus_fell(self)
		queue_free()

func _physics_process(dt: float) -> void:
	if book == null or book.hero == null or hp <= 0.0:
		return
	var hero = book.hero
	hurt_t = maxf(0.0, hurt_t - dt)
	grow = maxf(0.0, grow - dt)
	max_hp = book.col_hp(n)
	hp = minf(hp, max_hp)
	radius = 0.42 + 0.035 * n
	var spd: float = 3.6 * (1.1 if book.K("colgiant") > 0 else 1.0) * book.skel_speed()
	if tp.distance_to(hero.tp) > 20.0:
		tp = hero.tp + Vector2(1, 0)
		if book.zone.is_solid(tp):
			tp = hero.tp
	# Unbroken Bulwark: every 6 s it bellows, and what is near comes to it
	if book.K("bulwarkC") > 0:
		taunt_t -= dt
		if taunt_t <= 0.0:
			taunt_t = 6.0
			for m in book.foes(tp, 4.5):
				if m.rank != "boss":
					m.set_meta("mys_taunt_until", Time.get_ticks_msec() / 1000.0 + 4.0)
					m.set_meta("mys_taunt_by", self)
	var anim := "idle"
	var lift := 0.0
	if not leap.is_empty():
		leap["t"] += dt
		var k: float = minf(1.0, leap["t"] / leap["dur"])
		tp = leap["from"].lerp(leap["to"], k)
		lift = sin(k * PI) * (22.0 + 6.0 * mini(8, n))
		anim = "walk"
		if k >= 1.0:
			leap = {}
			_land()
	elif not atk.is_empty():
		atk["t"] += dt
		anim = "atk" if atk["t"] > atk["dur"] * 0.45 else "wind"
		if not atk["hit"] and atk["t"] > atk["dur"] * 0.55:
			atk["hit"] = true
			if is_instance_valid(atk["T"]) and not atk["T"].dead:
				_strike(atk["T"])
		if atk["t"] >= atk["dur"]:
			atk = {}
	elif not order.is_empty():
		if tp.distance_to(order["tp"]) > 0.6:
			_move(order["tp"], spd * 1.2, dt)
			_look(order["tp"] - tp)
			anim = "walk"
		else:
			order["t"] -= dt
			if order["t"] <= 0.0:
				order = {}
	else:
		if prey != null and (not is_instance_valid(prey) or prey.dead):
			prey = null
		var T = prey if prey != null else _target()
		if T != null:
			var d: float = tp.distance_to(T.tp)
			var reach: float = float(W["reach"]) + T.radius + radius * 0.5
			_look(T.tp - tp)
			if d > 2.6 and d < 7.5 and not book.zone.blocks_sight(tp.lerp(T.tp, 0.5)):
				var to: Vector2 = tp + (T.tp - tp) * maxf(0.0, (d - T.radius - radius - 0.2) / d)
				leap = {"from": tp, "to": to if not book.zone.is_solid(to) else tp, "t": 0.0, "dur": 0.5 + 0.03 * d}
				Sfx.play("roll", 0.6, 0.5)
			elif d > reach:
				_move(T.tp, spd, dt)
				anim = "walk"
			else:
				var dur: float = float(W["dur"]) * 0.7 / book.skel_haste()
				atk = {"t": 0.0, "dur": dur, "T": T, "hit": false}
		elif tp.distance_to(book.anchor()) > 2.2:
			_move(book.anchor(), spd * (1.3 if tp.distance_to(book.anchor()) > 5.0 else 1.0), dt)
			_look(book.anchor() - tp)
			anim = "walk"
	# shove creatures out of its way
	for m in book.foes(tp, radius + 0.3):
		var dv: Vector2 = m.tp - tp
		if dv.length() > 0.001:
			m.tp = book.zone.move(m.tp, dv.normalized() * (radius + m.radius - dv.length()) * 0.6, m.radius)
	position = Iso.to_screen(tp)
	var sc := minf(1.25, 0.72 + 0.05 * n) * (1.0 + 0.12 * grow)
	spr.scale = Vector2(sc, sc)
	spr.position.y = -lift
	spr.view = view
	spr.face = face
	spr.play(anim)
	spr.step(dt)
	spr.modulate = Color(1.2, 1.15, 1.1) if hurt_t > 0.0 else Color.WHITE

func _target():
	var hero = book.hero
	var best = null
	var bd := 1e9
	for m in book.mons():
		var da: float = m.tp.distance_to(hero.tp)
		if da > 8.0 or (not m.awake and da > 6.0):
			continue
		var d: float = m.tp.distance_to(tp) + da * 0.5
		if d < bd:
			bd = d
			best = m
	return best

func _strike(T) -> void:
	var dmg: float = book.col_dmg(n) * float(W["mult"])
	book.hurt(T, dmg, "colossus", {"from": tp})
	if T.rank != "boss":
		T.tp = book.zone.move(T.tp, (T.tp - tp).normalized() * 0.4, T.radius)
		T.set_meta("mys_taunt_until", Time.get_ticks_msec() / 1000.0 + 3.0)
		T.set_meta("mys_taunt_by", self)
	book.dust(T.tp, 5)
	Sfx.play("hit", 0.7, 0.6)

func _land() -> void:
	var R := 1.6 + 0.08 * mini(10, n)
	var dmg: float = book.col_dmg(n) * 1.4 * (1.3 if book.K("colleap") > 0 else 1.0)
	for m in book.foes(tp, R):
		book.hurt(m, dmg, "colossus", {"from": tp})
		if m.rank != "boss":
			m.stun = maxf(m.stun, 0.8)
			m.tp = book.zone.move(m.tp, (m.tp - tp).normalized() * 0.6, m.radius)
	book.spikes_fx.append({"tp": tp, "a": 0.0, "len": R, "t": 0.4, "ring": true})
	book.dust(tp, 30)
	Game.shake(5.0)
	Sfx.play("break", 1.0, 0.4)

func _move(goal: Vector2, spd: float, dt: float) -> void:
	var dv := goal - tp
	if dv.length() < 0.01:
		return
	tp = book.zone.move(tp, dv.normalized() * minf(dv.length(), spd * dt), radius)

func _look(dir: Vector2) -> void:
	var r := AnimSprite.mon_view(dir, face)
	if r[0] != "":
		view = r[0]
		face = r[1]
