extends Node2D
## The Shrine Keeper's companions (group "allies": tp, radius, take_hit, is_down), both her own reflection:
##  - "decoy": what Blur leaves where she stood; creatures turn on it for a few seconds; it can be struck down.
##  - "sister": the Mirror-Sister (m_mias.js updateSister, zz_miasma_breath.js): Akane, a reversed reflection who walks
##    across from her and every few seconds uses one of her skills at a share of her strength (walking in for the
##    melee ones). She has her own life; struck down she disperses and re-forms after 6 s.
## Drawn with the Shrine Keeper's own sprite, pale and cold; the sister mirrored.

var book
var kind := "decoy"
var tp := Vector2.ZERO
var radius := 0.28
var hp := 50.0
var max_hp := 50.0
var life := 3.0
var face := 1
var cd := 1.5
var go := {}
var gone_t := 0.0            # the sister, dispersed: time until she re-forms
var hurt_t := 0.0
var spr: AnimSprite
var last := Vector2.INF

func _ready() -> void:
	add_to_group("allies")
	spr = AnimSprite.new(Data.sprite_set("miasmancer"))
	spr.play("idle")
	spr.view = "front"
	add_child(spr)
	position = Iso.to_screen(tp)

func is_down() -> bool:
	return gone_t > 0.0

func take_hit(dmg: float, _elem: String = "phys", _from: Vector2 = Vector2.INF) -> void:
	if gone_t > 0.0:
		return
	hp -= dmg
	hurt_t = 0.15
	if hp <= 0.0:
		if kind == "decoy":
			book.decoy_gone(self)
			queue_free()
		else:
			gone_t = 6.0
			book.puff(tp, book.WARP, 24, 2.4)
			book.say_at(tp, "the sister disperses", book.WARP)

func _physics_process(dt: float) -> void:
	if book == null or book.hero == null or book.zone == null:
		return
	var h = book.hero
	hurt_t = maxf(0.0, hurt_t - dt)
	if kind == "decoy":
		life -= dt
		if life <= 0.0:
			book.decoy_gone(self)
			queue_free()
			return
		spr.play("idle")
		spr.step(dt)
		modulate = Color(0.72, 0.68, 0.9, 0.55 + 0.1 * sin(Time.get_ticks_msec() / 90.0))
	else:
		_sister(h, dt)
	spr.face = face
	position = Iso.to_screen(tp)
	if hurt_t > 0.0:
		spr.self_modulate = Color(1.4, 1.4, 1.5)
	else:
		spr.self_modulate = Color.WHITE

func _sister(h, dt: float) -> void:
	if gone_t > 0.0:
		gone_t -= dt
		visible = false
		if gone_t <= 0.0:
			hp = max_hp * 0.6
			tp = h.tp + Vector2(-1.2, 0.4)
			visible = true
			book.puff(tp, book.WARP, 18, 2.0)
		return
	visible = true
	modulate = Color(0.66, 0.75, 0.9, 0.78)
	max_hp = h.st.life_max() * (0.35 + 0.02 * (book.K("sister") - 1))
	cd -= dt
	if go.is_empty() and hurt_t <= 0.0:
		hp = minf(max_hp, hp + max_hp * 0.02 * dt)
	if tp.distance_to(h.tp) > 14.0:
		tp = h.tp - Vector2(h.face, 0)
	var foe = book.near(tp, 9.0, func(m): return book.zone.sight_clear(tp, m.tp))
	var moved := false
	if not go.is_empty():
		var f = go["foe"]
		go["t"] -= dt
		if f == null or not is_instance_valid(f) or f.dead or go["t"] <= 0.0:
			go = {}
		elif f.tp.distance_to(tp) > f.radius + 0.9:
			moved = _step(f.tp, 6.0 * dt)
		else:
			var id: String = go["id"]
			go = {}
			book.sister_cast_now(id, f.tp, f)
			cd = book.sister_cd()
	elif foe == null:
		# she walks as your mirror: across from you
		var t := Time.get_ticks_msec() / 1000.0
		var goal: Vector2 = h.tp - Vector2(cos(t * 0.4), sin(t * 0.4)) * 1.4
		if goal.distance_to(tp) > 0.3:
			moved = _step(goal, 4.0 * dt)
		face = -h.face
	else:
		face = 1 if (foe.tp.x - foe.tp.y) > (tp.x - tp.y) else -1
		if cd <= 0.0:
			var list: Array = book.SISTER_SKILLS.filter(func(id): return book.K(id) > 0 and not (id in book.TRAPS and book.traps.size() >= book.trap_max()))
			if list.is_empty():
				cd = 1.0
			else:
				var id: String = list[randi() % list.size()]
				cd = book.sister_cd()
				if id in book.SISTER_MELEE and foe.tp.distance_to(tp) > foe.radius + 0.9:
					go = {"id": id, "foe": foe, "t": 3.0}
				else:
					book.sister_cast_now(id, foe.tp, foe)
					spr.play("cast", true, false)
	if moved:
		spr.play("walk")
	elif spr.anim == "walk" or spr.done:
		spr.play("idle")
	spr.step(dt)

func _step(to: Vector2, s: float) -> bool:
	var v := to - tp
	if v.length() < 0.02:
		return false
	tp = book.zone.move(tp, v.normalized() * minf(s, v.length()), 0.25)
	var vf: Array = AnimSprite.hero_view(v, face)
	if vf[0] != "":
		spr.view = vf[0]
	face = vf[1]
	return true
