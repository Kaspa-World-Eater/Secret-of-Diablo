extends Node2D
## (Secret of Diablo) A companion that fights beside the pilgrim: the old Necromancer's golems, skeletal mages and
## revived creatures, and the mercenary. Built on the Ossuarch's standing dead (skills/ossumancer/skeleton.gd): it keeps
## near him, goes for the nearest creature that is awake near him, winds up and strikes. An ally (group "allies": tp,
## radius, take_hit, is_down) so creatures and their missiles can strike it.
##
## cfg keys: name, sprite, hp, dmg (Vector2), reach, cd, speed, elem, ranged (shot speed), radius, dr (share of a blow
## turned), life (seconds, 0 = stays), slow, leech, thorns, aura (dps), aura_r, poison (total over 2 s), scale, tint

signal fell(ally)

var hero
var book = null            # the Ossuarch's skill book, when the ally is his (its blows count in his numbers)
var cfg := {}
var tp := Vector2.ZERO
var radius := 0.3
var hp := 10.0
var max_hp := 10.0
var gone := false
var cd := 0.3
var wind := -1.0
var tgt = null
var face := 1
var view := "down"
var hurt_t := 0.0
var swing_t := 0.0
var life := 0.0
var aura_t := 0.0
var slot := 0              # its place in the ring it forms round him
var spr: AnimSprite


func setup(h, c: Dictionary, at: Vector2) -> void:
	hero = h
	cfg = c
	tp = at
	radius = float(c.get("radius", 0.3))
	max_hp = float(c.get("hp", 20.0))
	hp = max_hp
	life = float(c.get("life", 0.0))


func _ready() -> void:
	add_to_group("allies")
	spr = AnimSprite.new(Data.sprite_set(String(cfg.get("sprite", "lpc_skeleton"))))
	spr.play("idle")
	var sc: float = float(cfg.get("scale", 1.0))
	spr.scale = Vector2(sc, sc)
	add_child(spr)
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 14:
		var a := i / 14.0 * TAU
		pts.append(Vector2(cos(a) * 16.0 * sc, sin(a) * 6.0 * sc + 4.0))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.35)
	sh.z_index = -1
	add_child(sh)
	move_child(sh, 0)
	position = Iso.to_screen(tp)


func is_down() -> bool:
	return gone


func take_hit(dmg: float, elem: String = "phys", from: Vector2 = Vector2.INF) -> void:
	if gone:
		return
	dmg *= (100.0 / 120.0 if elem == "phys" else 0.9) * (1.0 - float(cfg.get("dr", 0.0)))
	var res: Dictionary = cfg.get("res", {})
	dmg *= 1.0 - clampf(float(res.get(elem, 0.0)), 0.0, 75.0) / 100.0
	hp -= dmg
	hurt_t = 0.1
	# thorns: a creature that strikes it in close takes part of the blow back
	if float(cfg.get("thorns", 0.0)) > 0.0 and from != Vector2.INF:
		var by = Combat.striker if Combat.striker_frame == Engine.get_physics_frames() else null
		if by != null and is_instance_valid(by) and not by.dead and by.tp.distance_to(tp) < 2.0:
			_hurt(by, dmg * float(cfg["thorns"]), "phys")
	if hp <= 0.0:
		_fall()


func _fall() -> void:
	if gone:
		return
	gone = true
	remove_from_group("allies")
	fell.emit(self)
	queue_free()


func _physics_process(dt: float) -> void:
	if gone or hero == null or not is_instance_valid(hero) or hero.zone == null:
		return
	var zone = hero.zone
	hurt_t = maxf(0.0, hurt_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	cd -= dt
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			_fall()
			return
	if tp.distance_to(hero.tp) < 3.0:
		hp = minf(max_hp, hp + max_hp * 0.02 * dt)
	if tp.distance_to(hero.tp) > 18.0:
		tp = hero.tp + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		if zone.is_solid(tp):
			tp = hero.tp
	# an aura of fire (the Fire Golem)
	var aura: float = float(cfg.get("aura", 0.0))
	if aura > 0.0:
		aura_t -= dt
		if aura_t <= 0.0:
			aura_t = 0.5
			for m in _mons():
				if m.tp.distance_to(tp) < float(cfg.get("aura_r", 2.0)):
					_hurt(m, aura * 0.5, "fire", {"dot": true})
	var anim := "idle"
	var spd: float = float(cfg.get("speed", 3.2))
	if wind >= 0.0:
		wind += dt
		anim = "wind"
		if wind > 0.35:
			wind = -1.0
			cd = float(cfg.get("cd", 1.0))
			if tgt != null and is_instance_valid(tgt) and not tgt.dead:
				_strike(tgt)
	else:
		tgt = _target()
		if tgt != null:
			var d: float = tp.distance_to(tgt.tp)
			var reach: float = float(cfg.get("reach", 0.9)) + tgt.radius
			_look(tgt.tp - tp)
			if d > reach or (cfg.has("ranged") and not zone.line_clear(tp, tgt.tp)):
				_move(tgt.tp, spd, dt)
				anim = "walk"
			elif cd <= 0.0:
				wind = 0.0
		else:
			var ang := float(slot) * 2.1 + 0.9
			var goal: Vector2 = hero.tp + Vector2(cos(ang), sin(ang)) * 1.6
			if goal.distance_to(tp) > 0.5:
				_move(goal, spd * (1.3 if tp.distance_to(hero.tp) > 4.0 else 1.0), dt)
				_look(goal - tp)
				anim = "walk"
	if swing_t > 0.0:
		anim = "atk"
	position = Iso.to_screen(tp)
	spr.view = view
	spr.face = face
	spr.play(anim)
	spr.step(dt)
	var tint: Color = cfg.get("tint", Color.WHITE)
	spr.modulate = Color(1.3, 1.2, 1.1) if hurt_t > 0.0 else tint


func _mons() -> Array:
	return hero.get_tree().get_nodes_in_group("monsters")


func _target():
	var best = null
	var bd := 1e9
	for m in _mons():
		if m.dead or (not m.awake and m.tp.distance_to(hero.tp) > 6.0):
			continue
		var da: float = m.tp.distance_to(hero.tp)
		if da > 8.0:
			continue
		var d: float = m.tp.distance_to(tp) + da * 0.5
		if d < bd:
			bd = d
			best = m
	return best


func _hurt(m, dmg: float, elem: String, o: Dictionary = {}) -> float:
	if m == null or not is_instance_valid(m) or m.dead:
		return 0.0
	if book != null:
		var opt := o.duplicate()
		opt["elem"] = elem
		opt["from"] = tp
		return book.hurt(m, dmg, String(cfg.get("id", "ally")), opt)
	return Combat.hit_monster(m, dmg, elem, tp, o)


func _strike(T) -> void:
	var dm: Vector2 = cfg.get("dmg", Vector2(2, 4))
	var dmg: float = randf_range(dm.x, dm.y)
	var elem: String = String(cfg.get("elem", "phys"))
	swing_t = 0.2
	if cfg.has("ranged"):
		var mi := Missile.fire(hero.zone, tp, T.tp, float(cfg["ranged"]), dmg, elem, "hero", "bolt")
		mi.col = cfg.get("bolt", Color(0.85, 0.8, 0.7))
		var me := self
		mi.on_hit = func(m, _mis):
			me._on_blow(m, dmg, elem)
		Sfx.play("swing", 0.3, 1.5)
		return
	if tp.distance_to(T.tp) <= float(cfg.get("reach", 0.9)) + T.radius + 0.25:
		_on_blow(T, dmg, elem)
	Sfx.play("swing", 0.35, 1.1)


func _on_blow(m, dmg: float, elem: String) -> void:
	if not is_instance_valid(m) or m.dead:
		return
	var dealt := _hurt(m, dmg, elem)
	if float(cfg.get("slow", 0.0)) > 0.0:
		m.slow = maxf(m.slow, float(cfg["slow"]))
	if float(cfg.get("poison", 0.0)) > 0.0:
		m.add_dot(float(cfg["poison"]) / 2.0, 2.0, "poison")
	if float(cfg.get("leech", 0.0)) > 0.0 and dealt > 0.0:
		hp = minf(max_hp, hp + dealt * float(cfg["leech"]))
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + dealt * float(cfg["leech"]) * 0.5)


func _move(goal: Vector2, spd: float, dt: float) -> void:
	var dv := goal - tp
	if dv.length() < 0.01:
		return
	tp = hero.zone.move(tp, dv.normalized() * minf(dv.length(), spd * dt), radius)


func _look(dir: Vector2) -> void:
	var r := AnimSprite.mon_view(dir, face)
	if r[0] != "":
		view = r[0]
		face = r[1]
