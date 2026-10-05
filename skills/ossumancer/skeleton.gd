extends Node2D
## One of the Ossuarch's standing dead (f_bone.js newSkel / updateSkels / skelStrike / hurtSkel). It claws up out
## of the ground (0.45 s), keeps near him, goes for the nearest creature that is awake near him or that threatens
## him or his dead, winds up and strikes with its loadout (sword and shield: sturdy, and its blows draw the struck
## onto it; greatsword: a sweeping arc; halberd: long reach that shoves back). It mends near him (2% a second),
## and one left more than 18 yd behind comes back to his side. An ally (group "allies": tp, radius, take_hit,
## is_down) so creatures and their missiles can strike it. The painted sprites are the web build's skeleton_<load>.

var book
var tp := Vector2.ZERO
var radius := 0.27
var load_id := "shield"
var hp := 10.0
var max_hp := 10.0
var gone := false
var rise := 0.45
var cd := 0.4
var wind := -1.0             # >= 0 while winding up a blow
var tgt = null
var face := 1
var view := "front"
var hurt_t := 0.0
var swing_t := 0.0
var spr: AnimSprite
var temp := 0.0              # > 0: an Unearthed one, crumbling when it runs out; it holds no shards

func setup_numbers() -> void:
	max_hp = book.skel_hp() * float(book.LOADS[load_id]["hp"])
	hp = max_hp

func _ready() -> void:
	add_to_group("allies")
	spr = AnimSprite.new(Data.sprite_set("skeleton_" + load_id))
	spr.play("idle")
	add_child(spr)
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 14:
		var a := i / 14.0 * TAU
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 6.0 + 4.0))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.35)
	sh.z_index = -1
	add_child(sh)
	move_child(sh, 0)
	position = Iso.to_screen(tp)

func is_down() -> bool:
	return rise > 0.0

func take_hit(dmg: float, elem: String = "phys", _from: Vector2 = Vector2.INF) -> void:
	if gone:
		return
	if rise > 0.0:
		dmg *= 0.5
	dmg *= (100.0 / 120.0 if elem == "phys" else 0.9) * (1.0 - float(book.LOADS[load_id].get("dr", 0.0)))
	hp -= dmg
	hurt_t = 0.1
	if hp <= 0.0 and not gone:
		gone = true
		remove_from_group("allies")
		book.skel_fell(self)
		queue_free()

func _physics_process(dt: float) -> void:
	if book == null or book.hero == null or gone:
		return
	var hero = book.hero
	var L: Dictionary = book.LOADS[load_id]
	hurt_t = maxf(0.0, hurt_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	var haste: float = book.skel_haste()
	var spd: float = 3.2 * book.skel_speed()
	cd -= dt * haste
	if temp > 0.0:
		temp -= dt
		if temp <= 0.0:
			take_hit(1e9, "true")
			return
	if rise > 0.0:
		rise -= dt
		spr.position.y = 30.0 * maxf(0.0, rise) / 0.45   # comes up out of the ground
		_draw_sprite(dt, "idle")
		return
	spr.position.y = 0.0
	if tp.distance_to(hero.tp) < 3.0:
		hp = minf(max_hp, hp + max_hp * (0.06 if book.K("mknit") > 0 else 0.02) * dt)
	elif book.K("mknit") > 0:
		hp = minf(max_hp, hp + max_hp * 0.01 * dt)
	if tp.distance_to(hero.tp) > 18.0:
		tp = hero.tp + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		if book.zone.is_solid(tp):
			tp = hero.tp
	var anim := "idle"
	if wind >= 0.0:
		wind += dt
		anim = "wind"
		if wind > (0.3 + float(L["cd"]) * 0.15) / haste:
			wind = -1.0
			cd = float(L["cd"])
			if tgt != null and is_instance_valid(tgt) and not tgt.dead:
				_strike(tgt, L)
	else:
		tgt = _target()
		if tgt != null:
			var d: float = tp.distance_to(tgt.tp)
			var reach: float = float(L["reach"]) + tgt.radius
			_look(tgt.tp - tp)
			if d > reach:
				_move(tgt.tp, spd, dt)
				anim = "walk"
			elif cd <= 0.0:
				wind = 0.0
		else:
			# form up round him: shields in close, reach behind
			var i: int = book.skels.find(self)
			var n: int = maxi(1, book.skels.size())
			var ring: float = 1.7 if load_id == "halberd" else (1.1 if load_id == "shield" else 1.4)
			var ang := float(i) / n * TAU + 0.6
			var anchor: Vector2 = book.anchor()
			var goal: Vector2 = anchor + Vector2(cos(ang), sin(ang)) * ring
			if goal.distance_to(tp) > 0.5:
				_move(goal, spd * (1.3 if tp.distance_to(anchor) > 4.0 else 1.0), dt)
				_look(goal - tp)
				anim = "walk"
	if swing_t > 0.0:
		anim = "atk"
	_draw_sprite(dt, anim)

func _target():
	var hero = book.hero
	var prey = book.commanded_prey()
	if prey != null:
		return prey
	var best = null
	var bd := 1e9
	for m in book.mons():
		if not m.awake and m.tp.distance_to(hero.tp) > 6.0:
			continue
		var da: float = m.tp.distance_to(hero.tp)
		if da > 7.0:
			continue
		var d: float = m.tp.distance_to(tp) + da * 0.5
		if d < bd:
			bd = d
			best = m
	return best

func _strike(T, L: Dictionary) -> void:
	var dm: Vector2 = book.skel_dmg()
	var dmg: float = randf_range(dm.x, dm.y) * float(L["dmg"]) * book.march_dmg() * (0.8 if temp > 0.0 else 1.0)
	var hit := func(m):
		book.hurt(m, dmg, "raise", {"from": tp})
		if L.has("taunt") and m.rank != "boss":
			m.set_meta("mys_taunt_until", Time.get_ticks_msec() / 1000.0 + float(L["taunt"]))
			m.set_meta("mys_taunt_by", self)
		if L.has("knock") and m.rank != "boss":
			m.tp = book.zone.move(m.tp, (m.tp - tp).normalized() * float(L["knock"]), m.radius)
	if L.has("arc"):
		var fwd: Vector2 = (T.tp - tp).normalized()
		for m in book.mons():
			var dv: Vector2 = m.tp - tp
			if dv.length() > float(L["reach"]) + m.radius + 0.2:
				continue
			if dv.length() < 0.01 or dv.normalized().dot(fwd) > cos(float(L["arc"])):
				hit.call(m)
	elif tp.distance_to(T.tp) <= float(L["reach"]) + T.radius + 0.25:
		hit.call(T)
	swing_t = 0.2
	Sfx.play("swing", 0.35, 1.3)

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

func _draw_sprite(dt: float, anim: String) -> void:
	position = Iso.to_screen(tp)
	spr.view = view
	spr.face = face
	spr.play(anim)
	spr.step(dt)
	spr.modulate = Color(1.2, 1.15, 1.1) if hurt_t > 0.0 else Color.WHITE
