class_name Unit
extends Node2D
## Base for the player, monsters, minions and the mercenary.
## Handles health, damage types, poison, stun, knockback, movement and placeholder art.

signal died(unit)

const OUTLINE := Color(0.1, 0.07, 0.08)
const KNOCK_DECAY := 900.0

var team := 1
var display_name := "Unit"
var level := 1
var max_hp := 10.0
var hp := 10.0
var radius := 10.0
var move_speed := 100.0
var head_y := -36.0
var resist := {"physical": 0.0, "magic": 0.0, "fire": 0.0, "cold": 0.0, "lightning": 0.0, "poison": 0.0}
var dead := false

# visuals
var shape := "humanoid"
var weapon := ""
var color := Color.WHITE
var color2 := Color.WHITE
var color3 := Color.WHITE
var base_modulate := Color.WHITE
var facing := Vector2.DOWN
var anim_time := 0.0
var moving := false
var attack_anim := 0.0
var hurt_flash := 0.0
var sprite_key := ""
var sprite: AnimatedSprite2D = null

# status effects
var stun_time := 0.0
var knock := Vector2.ZERO  # knockback velocity, decays
var dmg_reduction := 0.0
var invisible := false  # untargetable (e.g. shades outside the light)
var poison_dps := 0.0
var poison_time := 0.0
var poison_source = null
var slow_time := 0.0
var slow_amount := 0.0
var bone_armor := 0.0
var bone_armor_max := 0.0
var thorns := 0.0

var path := PackedVector2Array()
var path_index := 0


func _ready() -> void:
	Game.register(self)
	var frames := SpriteLib.get_frames(sprite_key)
	if frames:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.offset = frames.get_meta("offset", Vector2.ZERO)
		var sc: float = frames.get_meta("scale", 1.0)
		sprite.scale = Vector2(sc, sc)
		add_child(sprite)


func _exit_tree() -> void:
	Game.unregister(self)


# ---------------------------------------------------------------- combat

func speed_mult() -> float:
	if slow_time > 0.0:
		return 1.0 - slow_amount
	return 1.0


func damage_taken_mult(_dtype: String) -> float:
	return 1.0


func take_damage(amount: float, dtype: String, source = null, melee := false, silent := false) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var a := amount
	var res: float = clamp(resist.get(dtype, 0.0), -100.0, 95.0)
	a *= 1.0 - res / 100.0
	a *= (1.0 - dmg_reduction) * damage_taken_mult(dtype)
	if dtype == "physical" and bone_armor > 0.0:
		var absorbed: float = min(bone_armor, a)
		bone_armor -= absorbed
		a -= absorbed
		if bone_armor <= 0.0:
			bone_armor_max = 0.0
	if a <= 0.0:
		return 0.0
	hp -= a
	if not silent:
		hurt_flash = 0.12
		if team != 0 and a >= 1.0:
			Game.float_text(global_position + Vector2(0, head_y + 20), str(int(a)), _dmg_color(dtype))
	if source != null and is_instance_valid(source) and not source.dead:
		if melee and thorns > 0.0:
			source.take_damage(amount * thorns, "physical", null)
	if hp <= 0.0:
		die(source)
	return a


func _dmg_color(dtype: String) -> Color:
	match dtype:
		"fire": return Color(1, 0.55, 0.2)
		"cold": return Color(0.5, 0.8, 1)
		"lightning": return Color(1, 1, 0.4)
		"poison": return Color(0.4, 1, 0.3)
		"magic": return Color(0.95, 0.85, 0.6)
	return Color(1, 1, 1)


func heal(amount: float) -> void:
	if not dead:
		hp = min(max_hp, hp + amount)


func apply_stun(duration: float) -> void:
	stun_time = max(stun_time, duration)


func apply_knockback(dir: Vector2, distance: float) -> void:
	## Pushes the unit roughly `distance` pixels (velocity decays at KNOCK_DECAY).
	if distance <= 0.0:
		return
	knock = dir.normalized() * sqrt(2.0 * KNOCK_DECAY * distance)


func apply_poison(total: float, duration: float, source) -> void:
	var dps := total / duration
	if dps >= poison_dps or poison_time <= 0.0:
		poison_dps = dps
		poison_time = duration
		poison_source = source


func apply_slow(amount: float, duration: float) -> void:
	if amount >= slow_amount or slow_time <= 0.0:
		slow_amount = amount
	slow_time = max(slow_time, duration)


func tick_status(delta: float) -> void:
	anim_time += delta
	hurt_flash = max(0.0, hurt_flash - delta)
	attack_anim = max(0.0, attack_anim - delta)
	if stun_time > 0.0:
		stun_time -= delta
	if knock.length_squared() > 4.0:
		try_move(knock * delta)
		knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	else:
		knock = Vector2.ZERO
	if slow_time > 0.0:
		slow_time -= delta
	if poison_time > 0.0:
		poison_time -= delta
		var src = poison_source if is_instance_valid(poison_source) else null
		take_damage(poison_dps * delta, "poison", src, false, true)
		if poison_time <= 0.0:
			poison_dps = 0.0


func die(killer) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	died.emit(self)
	_on_death(killer)
	queue_free()


func _on_death(_killer) -> void:
	pass


# ---------------------------------------------------------------- movement

func try_move(v: Vector2) -> void:
	var w = Game.world
	var np := global_position + v
	if not w.is_walkable_px(global_position) or w.is_walkable_px(np):
		global_position = np
		return
	if v.x != 0.0 and w.is_walkable_px(global_position + Vector2(v.x, 0)):
		global_position += Vector2(v.x, 0)
	elif v.y != 0.0 and w.is_walkable_px(global_position + Vector2(0, v.y)):
		global_position += Vector2(0, v.y)


func move_towards(target_pos: Vector2, delta: float) -> bool:
	var d := target_pos - global_position
	var dist := d.length()
	if dist < 1.5:
		return true
	var step: float = min(dist, move_speed * speed_mult() * delta)
	facing = d / dist
	moving = true
	try_move(facing * step)
	return step >= dist


func set_path(p: PackedVector2Array) -> void:
	path = p
	path_index = 1 if p.size() > 1 else 0


func follow_path(delta: float) -> bool:
	if path_index >= path.size():
		path = PackedVector2Array()
		return true
	if move_towards(path[path_index], delta):
		path_index += 1
	return false


func dir_name() -> String:
	if abs(facing.x) > abs(facing.y):
		return "right" if facing.x > 0 else "left"
	return "down" if facing.y > 0 else "up"


# ---------------------------------------------------------------- visuals

func _process(_delta: float) -> void:
	var m := base_modulate
	if hurt_flash > 0.0:
		m = m * Color(1.8, 0.6, 0.6)
	elif poison_time > 0.0:
		m = m * Color(0.7, 1.2, 0.6)
	elif slow_time > 0.0:
		m = m * Color(0.7, 0.85, 1.3)
	if invisible:
		m.a = 0.12
	modulate = m
	if sprite:
		var state := "attack" if attack_anim > 0.0 else ("walk" if moving else "idle")
		var pick: Array = SpriteLib.pick(sprite.sprite_frames, state, dir_name())
		if sprite.animation != pick[0] or not sprite.is_playing():
			sprite.play(pick[0])
		sprite.flip_h = pick[1]
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.get_screen_center_position().distance_squared_to(global_position) < 900.0 * 900.0:
		queue_redraw()


func _draw() -> void:
	_ellipse(Vector2.ZERO, radius * 1.05, radius * 0.45, Color(0, 0, 0, 0.3))
	if sprite == null:
		draw_figure()
	_draw_overlays()


func draw_figure() -> void:
	match shape:
		"blob": _draw_blob()
		"mushroom": _draw_mushroom()
		"wisp": _draw_wisp()
		"shade": _draw_shade()
		"golem": _draw_golem()
		"skeleton": _draw_humanoid(color, color, Color(0, 0, 0, 0), weapon, false, 1.0, true)
		"goblin": _draw_humanoid(color, color2, Color(0, 0, 0, 0), weapon, false, 0.85)
		"ghoul": _draw_humanoid(color, color2, Color(0.25, 0.25, 0.28), "", false, 1.05)
		"necro": _draw_humanoid(color, color2, color3, "wand", true, 1.0)
		_: _draw_humanoid(color, color2, color3, weapon, false, 1.0)


func _draw_overlays() -> void:
	if stun_time > 0.0:
		for i in 3:
			var a := anim_time * 6.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * 9.0, head_y - 4 + sin(a) * 3.0), 2.2, Color(1, 0.95, 0.4))
	if bone_armor > 0.0:
		draw_arc(Vector2(0, -14), radius + 6.0, 0, TAU, 24, Color(0.95, 0.92, 0.8, 0.55), 2.0)
	if team == 0 and self != Game.player:
		var w := 22.0
		var y := head_y - 2
		draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2, y, w * clamp(hp / max_hp, 0.0, 1.0), 3), Color(0.3, 0.9, 0.3))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_ellipse(c, rx + 1.5, ry + 1.5, OUTLINE)
	_ellipse(c, rx, ry, col)
	_ellipse(c + Vector2(-rx * 0.3, -ry * 0.35), rx * 0.35, ry * 0.25, col.lightened(0.25))


func _box(r: Rect2, col: Color) -> void:
	draw_rect(r.grow(1.5), OUTLINE)
	draw_rect(r, col)


func _side() -> float:
	if abs(facing.x) > abs(facing.y) * 0.8:
		return sign(facing.x)
	return 0.0


func _swing_dir() -> Vector2:
	var d := facing if facing != Vector2.ZERO else Vector2.DOWN
	if attack_anim > 0.0:
		d = d.rotated(lerp(-1.3, 1.0, 1.0 - attack_anim / 0.3))
	return d


func _draw_humanoid(body: Color, skin: Color, hair: Color, weap: String, robe: bool, s: float, bones := false) -> void:
	var t := anim_time * 14.0
	var bob := sin(t) * 1.2 if moving else 0.0
	var step := sin(t) * 3.0 if moving else 0.0
	var side := _side()
	var back := facing.y < -0.5 and side == 0.0
	var top := -24.0 * s + bob
	var wdir := _swing_dir()
	var hand := Vector2((8.0 if side >= 0 else -8.0) * s, top + 10.0 * s)
	if back:
		_draw_weapon(weap, hand, wdir, s)
	# legs
	if not robe:
		var leg := body.darkened(0.35) if not bones else body
		_box(Rect2(-5 * s, -9 * s + step * 0.4, 4 * s, 9 * s - step * 0.4), leg)
		_box(Rect2(1 * s, -9 * s - step * 0.4, 4 * s, 9 * s + step * 0.4), leg)
	# torso
	var torso_h := (24.0 if robe else 15.0) * s
	_box(Rect2(-7 * s, top, 14 * s, torso_h - (bob if robe else 0.0)), body)
	if robe:
		draw_rect(Rect2(-7 * s, top + torso_h - 4 * s - bob, 14 * s, 3 * s), Color(0.5, 0.25, 0.6))
		draw_line(Vector2(0, top + 2), Vector2(0, top + torso_h - 4 - bob), body.lightened(0.15), 1.5)
	if bones:
		for i in 3:
			draw_line(Vector2(-5 * s, top + (4 + i * 3.5) * s), Vector2(5 * s, top + (4 + i * 3.5) * s), OUTLINE, 1.0)
	# arms
	_box(Rect2(-10 * s, top + 2 * s, 3 * s, 9 * s), body.darkened(0.15))
	_box(Rect2(7 * s, top + 2 * s, 3 * s, 9 * s), body.darkened(0.15))
	# head
	var hc := Vector2(side * 1.5 * s, top - 6.5 * s)
	_blob(hc, 6.5 * s, 6.5 * s, skin)
	if hair.a > 0.0:
		if back:
			_ellipse(hc, 6.6 * s, 6.6 * s, hair)
		else:
			_ellipse(hc + Vector2(0, -3 * s), 6.6 * s, 3.8 * s, hair)
	if not back:
		var eye_col := Color(0.05, 0.05, 0.05)
		if bones:
			eye_col = Color(0.0, 0.0, 0.0)
		var ex := side * 2.0 * s
		draw_circle(hc + Vector2(ex - 2.2 * s, 0.5 * s), (1.6 if bones else 1.0) * s, eye_col)
		draw_circle(hc + Vector2(ex + 2.2 * s, 0.5 * s), (1.6 if bones else 1.0) * s, eye_col)
	if not back:
		_draw_weapon(weap, hand, wdir, s)


func _draw_weapon(weap: String, hand: Vector2, wdir: Vector2, s: float) -> void:
	match weap:
		"wand":
			draw_line(hand, hand + wdir * 13 * s, OUTLINE, 3.5)
			draw_line(hand, hand + wdir * 13 * s, Color(0.93, 0.9, 0.8), 2.0)
			draw_circle(hand + wdir * 14 * s, 3.0 * s, Color(0.93, 0.9, 0.8))
			draw_circle(hand + wdir * 14 * s, 1.0 * s, OUTLINE)
		"spear":
			draw_line(hand - wdir * 6, hand + wdir * 24 * s, OUTLINE, 3.5)
			draw_line(hand - wdir * 6, hand + wdir * 24 * s, Color(0.55, 0.38, 0.2), 2.0)
			draw_colored_polygon(PackedVector2Array([hand + wdir * 30 * s, hand + wdir * 22 * s + wdir.orthogonal() * 3, hand + wdir * 22 * s - wdir.orthogonal() * 3]), Color(0.85, 0.85, 0.9))
		"sword":
			draw_line(hand, hand + wdir * 15 * s, OUTLINE, 3.5)
			draw_line(hand, hand + wdir * 15 * s, Color(0.7, 0.72, 0.75), 2.0)
			draw_line(hand + wdir.orthogonal() * 3, hand - wdir.orthogonal() * 3, Color(0.5, 0.4, 0.3), 2.0)
		"club":
			draw_line(hand, hand + wdir * 12 * s, OUTLINE, 5.0)
			draw_line(hand, hand + wdir * 12 * s, Color(0.5, 0.33, 0.18), 3.5)
		"staff":
			draw_line(hand - wdir * 4, hand + wdir * 16 * s, OUTLINE, 3.0)
			draw_line(hand - wdir * 4, hand + wdir * 16 * s, Color(0.45, 0.35, 0.25), 1.5)
			draw_circle(hand + wdir * 17 * s, 3.5, color2)
		"bone_sword":
			draw_line(hand, hand + wdir * 18 * s, OUTLINE, 5.0)
			draw_line(hand, hand + wdir * 18 * s, Color(0.95, 0.93, 0.85), 3.0)
			draw_circle(hand + wdir * 2, 3.0, Color(0.85, 0.82, 0.72))
		"maul":
			draw_line(hand, hand + wdir * 16 * s, OUTLINE, 4.0)
			draw_line(hand, hand + wdir * 16 * s, Color(0.9, 0.88, 0.8), 2.5)
			_blob(hand + wdir * 18 * s, 5.5 * s, 5.5 * s, Color(0.95, 0.93, 0.85))
			draw_circle(hand + wdir * 18 * s + Vector2(-1.5, 0), 1.2, OUTLINE)
			draw_circle(hand + wdir * 18 * s + Vector2(1.5, 0), 1.2, OUTLINE)
		"scythe":
			draw_line(hand - wdir * 6, hand + wdir * 20 * s, OUTLINE, 4.0)
			draw_line(hand - wdir * 6, hand + wdir * 20 * s, Color(0.9, 0.88, 0.8), 2.0)
			var o := wdir.orthogonal()
			var tip := hand + wdir * 20 * s
			draw_colored_polygon(PackedVector2Array([tip, tip + o * 14 + wdir * 3, tip + o * 10 - wdir * 2]), Color(0.95, 0.93, 0.85))
		"whip":
			var pts := PackedVector2Array()
			var o := wdir.orthogonal()
			var reach := 14.0 + attack_anim * 60.0
			for i in 8:
				var k := i / 7.0
				pts.append(hand + wdir * reach * k + o * sin(k * PI * 2.0 + anim_time * 10.0) * 3.0)
			draw_polyline(pts, OUTLINE, 3.5)
			draw_polyline(pts, Color(0.92, 0.9, 0.8), 2.0)
		"bone_spear":
			draw_line(hand - wdir * 8, hand + wdir * 26 * s, OUTLINE, 3.5)
			draw_line(hand - wdir * 8, hand + wdir * 26 * s, Color(0.92, 0.9, 0.8), 2.0)
			draw_colored_polygon(PackedVector2Array([hand + wdir * 33 * s, hand + wdir * 24 * s + wdir.orthogonal() * 4, hand + wdir * 24 * s - wdir.orthogonal() * 4]), Color(0.97, 0.95, 0.88))
		"shield":
			_blob(hand + wdir * 6, 6.0 * s, 8.0 * s, Color(0.9, 0.88, 0.8))
			for i in 3:
				draw_line(hand + wdir * 6 + Vector2(-4, -4 + i * 4), hand + wdir * 6 + Vector2(4, -4 + i * 4), OUTLINE, 1.0)
		"bow":
			var o := wdir.orthogonal()
			var pts := PackedVector2Array()
			for i in 9:
				var k := (i - 4) / 4.0
				pts.append(hand + wdir * (6 + 4 * (1 - k * k)) + o * k * 9)
			draw_polyline(pts, Color(0.45, 0.3, 0.15), 2.0)
			draw_line(pts[0], pts[8], Color(0.9, 0.9, 0.85), 1.0)


func _draw_blob() -> void:
	var hop = abs(sin(anim_time * 10.0)) * 6.0 if moving else abs(sin(anim_time * 3.0)) * 1.5
	var c := Vector2(0, -9 - hop)
	var side := _side()
	_blob(c + Vector2(-4 + side, -10), 2.5, 7, color)
	_blob(c + Vector2(4 + side, -10), 2.5, 7, color)
	draw_line(c + Vector2(-4 + side, -14), c + Vector2(-4 + side, -7), color2, 1.5)
	draw_line(c + Vector2(4 + side, -14), c + Vector2(4 + side, -7), color2, 1.5)
	_blob(c, 10, 8.5, color)
	if facing.y > -0.5:
		draw_circle(c + Vector2(side * 3 - 3, -1), 1.6, OUTLINE)
		draw_circle(c + Vector2(side * 3 + 3, -1), 1.6, OUTLINE)
		draw_rect(Rect2(c.x + side * 3 - 1.5, c.y + 3, 3, 2.5), Color(1, 1, 1))


func _draw_mushroom() -> void:
	var bob := sin(anim_time * 12.0) * 1.5 if moving else 0.0
	_blob(Vector2(0, -7), 6, 7, color2)
	if facing.y > -0.5:
		draw_circle(Vector2(-2.2 + _side() * 2, -7), 1.2, OUTLINE)
		draw_circle(Vector2(2.2 + _side() * 2, -7), 1.2, OUTLINE)
	_blob(Vector2(0, -17 + bob), 13, 8, color)
	draw_circle(Vector2(-6, -19 + bob), 2.2, Color(1, 1, 1))
	draw_circle(Vector2(4, -21 + bob), 2.6, Color(1, 1, 1))
	draw_circle(Vector2(7, -15 + bob), 1.6, Color(1, 1, 1))


func _draw_wisp() -> void:
	var fl := sin(anim_time * 4.0) * 3.0
	var c := Vector2(0, -20 + fl)
	var pulse := 1.0 + sin(anim_time * 17.0) * 0.12
	draw_circle(c, 13 * pulse, Color(color, 0.22))
	draw_circle(c, 8.5 * pulse, Color(color, 0.65))
	draw_circle(c, 4.5, color2)
	draw_circle(c + Vector2(-2, -1), 1.2, OUTLINE)
	draw_circle(c + Vector2(2, -1), 1.2, OUTLINE)


func _draw_shade() -> void:
	var fl := sin(anim_time * 3.0) * 2.0
	var c := Vector2(0, -16 + fl)
	var pts := PackedVector2Array()
	for i in 12:
		var a := PI + PI * i / 11.0
		pts.append(c + Vector2(cos(a) * 10.0, sin(a) * 14.0))
	for i in 5:
		var x := 10.0 - i * 5.0
		pts.append(c + Vector2(x, 12.0 + sin(anim_time * 8.0 + i) * 3.0 + (i % 2) * 4.0))
	draw_colored_polygon(pts, Color(color, 0.85))
	draw_polyline(pts, Color(color2, 0.5), 1.0)
	if facing.y > -0.5:
		draw_circle(c + Vector2(-3 + _side() * 2, -4), 1.8, color2)
		draw_circle(c + Vector2(3 + _side() * 2, -4), 1.8, color2)


func _draw_golem() -> void:
	var bob := sin(anim_time * 8.0) * 1.5 if moving else 0.0
	var swing := attack_anim * 18.0
	var c := Vector2(0, -18 + bob)
	_blob(c + Vector2(-6, 14), 5, 5, color.darkened(0.2))
	_blob(c + Vector2(6, 14), 5, 5, color.darkened(0.2))
	_blob(c, 13, 14, color)
	_blob(c + Vector2(-14, -2 + swing * 0.3), 5, 8, color.darkened(0.1))
	_blob(c + Vector2(14, -2 - swing * 0.3), 5, 8, color.darkened(0.1))
	_blob(c + Vector2(0, -17), 6.5, 5.5, color.lightened(0.05))
	if facing.y > -0.5:
		var eye := Color(1, 0.9, 0.3) if kind_is_fire() else Color(1, 0.3, 0.2)
		draw_circle(c + Vector2(-2.5, -17), 1.5, eye)
		draw_circle(c + Vector2(2.5, -17), 1.5, eye)
	if kind_is_fire():
		for i in 4:
			var a := anim_time * 3.0 + i * 1.6
			draw_circle(c + Vector2(cos(a) * 9, -8 + sin(a * 1.7) * 6), 3.0, Color(1, 0.8, 0.2, 0.7))


func kind_is_fire() -> bool:
	return false
