class_name Hero
extends Node2D
## The hero on the tile grid. Positions are in tiles (yards), as in the web build; the node sits at iso(tp).
## Diablo II control (checklist section 2): hold left to walk (repath every 0.18 s); click a creature to go to it and
## strike (the melee string, or the Bone Wand's bolt); shift+left strikes in place; hold the attack to charge a heavy
## blow; right click casts the right skill (hold repeats); Space rolls; 1-4 drink from the belt.

signal stats_changed
signal died

var zone: Zone
var tp := Vector2.ZERO
var cls := "animancer"
var spr: AnimSprite
var face := 1
var view := "down"
var path := PackedVector2Array()
var path_i := 0
var repath := 0.0
var goal := Vector2.ZERO
var walking := false
var lantern: LanternUnit = null    # the floating lantern (the Mystic, the Penitent)
var class_lamp: Node2D = null      # the lamp carried in hand (the Ossuarch, the Shrine Keeper, the Empty Hand)
var lamp: PointLight2D
var st: HeroStats
var skills: SkillBook
var target: Monster = null
var dead := false
var radius := 0.25

# actions
var act := ""              # "", swing, cast, roll, heavy, stun
var act_t := 0.0
var act_len := 0.0
var act_hit_at := 0.0
var act_done := false
var act_target: Monster
var act_mult := 1.0
var string_i := 0          # the melee string: cut, return cut, overhead
var string_idle := 0.0
var invuln := 0.0
var roll_dir := Vector2.ZERO
var charge := 0.0          # heavy wind-up held
var holding_attack := false
var hold_t := 0.0          # how long the attack button has been held (heavy wind-up after 0.18 s)
var heavy_pm := 0.0        # a released heavy: its poise-damage multiplier (x2 -> x3.5); 0 for other blows
var cast_hold := 0.0

# poise break (v60, v79)
var break_grace := 0.0
var shaken := false        # after a break: no rolling until poise is full
var poise_burst := 0.0

const STRING := [[1.0, 0.85, 0.12], [1.1, 0.95, 0.2], [1.6, 1.35, 0.42]]   # dmg x, time x, step yd (the overhead lunges 0.42 yd)

var last_blow := ""        # the last thing that hurt him, in plain words (Combat._blow_text), for the death screen

func setup(z: Zone, c: String, at: Vector2) -> void:
	zone = z
	cls = c
	tp = at
	var kind := c
	# the old painter variant "<kind>_unclipped" only when nothing newer stands in: no skins.json entry for the class
	# (Data.skin_for) and no PixelForge build of the class's own set (meta.source "pixelforge")
	if Data.skin_for(c) == c and not Data.is_pixelforge_set(c) and ResourceLoader.exists("res://art/sprites/%s_unclipped.json" % c):
		kind = c + "_unclipped"
	for a in OS.get_cmdline_user_args():   # --skin=ossuarch: a look test of another body on this order's moves
		if a.begins_with("--skin=") and FileAccess.file_exists("res://art/sprites/%s.json" % a.substr(7)):
			kind = a.substr(7)
	spr = AnimSprite.new(Data.sprite_set(kind))
	spr.view = "down"
	add_child(spr)
	add_child(load("res://entities/hero_rim.gd").new(self, spr))   # the edge the nearest flame lights (heroRim37)
	spr.play("idle")
	_shadow()
	lamp = PointLight2D.new()
	lamp.texture = Lights.pool(512)
	lamp.set_meta("dark_skip", true)   # the dark layer cuts the lantern's pool
	lamp.color = HeroStats.lamp_color(c)
	lamp.energy = 1.25
	lamp.texture_scale = light_radius() * Iso.HX * 2.0 / 512.0 * 1.25
	lamp.position = Vector2(28, -90)
	lamp.shadow_enabled = true
	lamp.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	lamp.shadow_color = Color(0, 0, 0, 0.8)
	add_child(lamp)
	if st == null:
		st = HeroStats.new()
		st.setup(c)
	if skills == null:
		skills = SkillBook.for_class(self, c)
	else:
		skills.hero = self
	z.hero_ref = self
	_sync()

func light_radius() -> float:
	# heroLightR (zd_world22.js:421, zz_zw_lantern63.js:44): wider as the day goes; the dim wick and what the lantern
	# keeps are the lantern's mood, not its reach (zz_zz_study82.js:16-20, world/dark_layer.gd)
	var out: bool = zone != null and zone.d.get("outdoor", false)
	var r := 7.0 + 1.5 * (1.0 - Game.day_k()) if out else 7.5
	if skills:
		r = skills.light_mod(r)
	r *= 0.62 * (1.0 + (st.item("lrad") if st else 0.0) / 100.0)
	return r * Affixes.lantern_k(self)

## the dim wick and what the lantern keeps (zz_zz_study82.js: target, eased 0.08 a frame by the dark layer)
func lamp_keep() -> float:
	if st == null:
		return 1.0
	return (0.62 if st.dim_wick else 1.0) * (1.0 - 0.12 * clampf(st.kept, 0, 3))

func _shadow() -> void:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * 30.0, sin(a) * 12.0 + 6.0))
	s.polygon = pts
	s.color = Color(0, 0, 0, 0.25)   # the contact shadow under the feet
	add_child(s)
	move_child(s, 0)
	if zone and zone.shadow_layer:
		zone.shadow_layer.add_child(SilShadow.new(spr, self, true))
	# the Wickbound: the lantern floats beside him, its own small follower (entities/lantern_unit.gd)
	if LanternUnit.WHO.has(cls) and zone:
		lantern = LanternUnit.new()
		zone.sorted.add_child(lantern)
		lantern.setup(self)

func _sync() -> void:
	position = Iso.to_screen(tp)

func mouse_tile() -> Vector2:
	return Iso.to_tile(get_global_mouse_position())

func walk_to(t: Vector2) -> void:
	goal = t
	walking = true
	path = zone.path(tp, t)
	path_i = 0
	# the first cell is the one we stand in: skip it, and walk straight when the line is clear
	if path.size() > 1:
		path_i = 1
	if zone.line_clear(tp, t) and not zone.is_solid(t):
		path = PackedVector2Array([t])
		path_i = 0
	repath = 0.18

func monster_at_mouse() -> Monster:
	var mp := get_global_mouse_position()
	var best: Monster = null
	var bd := 60.0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.dead or m.buried:
			continue
		var c: Vector2 = m.position + Vector2(0, -60)
		var d := c.distance_to(mp)
		if d < bd:
			bd = d
			best = m
	return best

# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if dead:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := monster_at_mouse()
		if m and skills.left != "attack":
			skills.use(skills.left, m.tp, m)
		elif m:
			target = m
			walking = false
		elif Input.is_key_pressed(KEY_SHIFT):
			_start_attack(null, mouse_tile())
		else:
			target = null
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_cast_right()
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE:
				roll()
			KEY_1, KEY_2, KEY_3, KEY_4:
				drink(ev.keycode - KEY_1)
			KEY_L:
				st.dim_wick = not st.dim_wick
				lamp.texture_scale = light_radius() * Iso.HX * 2.0 / 512.0 * 1.25
				Bus.say.emit("You turn the wick down." if st.dim_wick else "You turn the wick up.", 1.5)
		var k: String = OS.get_keycode_string(ev.keycode).to_lower()
		if skills.keys.has(k):
			if Input.is_key_pressed(KEY_SHIFT):
				skills.left = skills.keys[k]
			else:
				skills.right = skills.keys[k]
			stats_changed.emit()

func _cast_right() -> void:
	if act != "" and act != "swing":
		return
	var m := monster_at_mouse()
	var at := m.tp if m else mouse_tile()
	if skills.right == "attack":
		_start_attack(m, at)
		return
	_face(at - tp)
	skills.cast_anim = "cast"
	skills.cast_len = -1.0
	if skills.use(skills.right, at, m):
		_start_act(skills.cast_anim, skills.cast_len if skills.cast_len > 0.0 else 0.55 / st.cast_speed())
		walking = false
		cast_hold = 0.0

# ------------------------------------------------------------------ the frame
func _physics_process(dt: float) -> void:
	if dead or zone == null:
		if dead:
			spr.step(dt)
		return
	st.tick(dt)
	skills.tick(dt)
	invuln = maxf(0.0, invuln - dt)
	break_grace = maxf(0.0, break_grace - dt)
	if poise_burst > 0.0:
		var a := minf(poise_burst, st.poise_max() * 0.5 / 0.35 * dt)
		poise_burst -= a
		st.poise = minf(st.poise_max(), st.poise + a)
	if shaken and st.poise >= st.poise_max() - 0.5:
		shaken = false
	string_idle += dt
	if string_idle > 0.8:
		string_i = 0
	# hold right to repeat the skill
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and act == "" and skills.right != "attack":
		cast_hold += dt
		if cast_hold > 0.25:
			_cast_right()
	_heavy(dt)
	if act != "":
		_act(dt)
		_sync()
		return
	if holding_attack:
		# winding up: creep toward the target at 35% (in _walk), the blow drawn back
		if target and not target.dead and tp.distance_to(target.tp) - target.radius > _reach():
			repath -= dt
			if repath <= 0.0 or not walking:
				walk_to(target.tp)
			_walk(dt)
		_face((target.tp if target and not target.dead else mouse_tile()) - tp)
		spr.view = view
		spr.face = face
		spr.play("heavy" if spr.set.has("heavy") else "atk", false, false)
		spr.set_index(mini(1, spr.frame_count() - 1))
		_sync()
		return
	# auto-attack (an option; off by default on desktop): an idle pilgrim turns on what comes near
	if Settings.auto_attack and target == null and not walking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var near := Combat.nearest_monster(zone, tp, 5.0, true)
		if near and near.awake:
			target = near
	# walk or chase
	var moved := false
	if target and not target.dead and not target.buried:
		var reach := _reach()
		var d := tp.distance_to(target.tp) - target.radius
		if d <= reach:
			# a held button is deciding between a cut and a heavy: wait for it (Settings.hold_heavy)
			if not (Settings.hold_heavy and hold_t > 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and skills.left == "attack"):
				_start_attack(target, target.tp)
		else:
			repath -= dt
			if repath <= 0.0 or not walking:
				walk_to(target.tp)
			moved = _walk(dt)
	else:
		target = null
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _ui_captured() and not Input.is_key_pressed(KEY_SHIFT):
			repath -= dt
			if repath <= 0.0 or not walking:
				walk_to(mouse_tile())
		moved = _walk(dt)
	spr.view = view
	spr.face = face
	if moved:
		spr.play("walk")
		spr.step(dt, st.move_speed() / 3.11)
		if act == "":
			st.poise = maxf(0.0, st.poise - 1.6 * dt)   # walking drains 1.6/s (regeneration still runs)
	else:
		spr.play("idle")
		spr.step(dt)
	_sync()

var step_acc := 0.0
func _walk(dt: float) -> bool:
	if not walking or path_i >= path.size():
		walking = false
		return false
	var wp: Vector2 = path[path_i]
	var to := wp - tp
	var spd := st.move_speed()
	if zone.type_at(tp) == 12:
		spd *= 0.72
	elif zone.type_at(tp) == 13:
		spd *= 0.8
	if charge > 0.0:
		spd *= 0.35
	if skills.has_method("move_k"):
		spd *= skills.move_k()
	var step := spd * dt
	step_acc += minf(step, to.length())
	if step_acc > 0.62:
		step_acc = 0.0
		Sfx.play("step_" + zone.surface_at(tp))
	if to.length() <= step:
		tp = zone.move(tp, to, radius)
		path_i += 1
	else:
		tp = zone.move(tp, to.normalized() * step, radius)
	_face(to)
	if path_i >= path.size():
		walking = false
	return true

func _face(dir: Vector2) -> void:
	var r := AnimSprite.hero_view(dir, face, spr.set if spr else null)
	if r[0] != "":
		view = r[0]
		face = r[1]

func _ui_captured() -> bool:
	var vp := get_viewport()
	return vp.gui_get_hovered_control() != null if vp else false

# ------------------------------------------------------------------ attacks
func _weapon() -> Item:
	return st.inv.weapon() if st.inv else null

func _reach() -> float:
	var w: Item = _weapon()
	if w and w.is_ranged():
		return 6.5
	return 1.5 + (0.35 if act_mult > 1.5 else 0.0)   # the overhead finisher reaches a little further

func _start_attack(m: Monster, at: Vector2) -> void:
	if act != "":
		return
	_face(at - tp)
	walking = false
	var w: Item = _weapon()
	if w and w.is_ranged():
		_start_act("atk", 0.55 / st.attack_speed())
		act_target = m
		act_hit_at = 0.45
		act_mult = 1.0
		return
	var s: Array = STRING[string_i]
	_start_act(["atk", "atk2", "atk3" if spr.set.has("light3") else "atk"][string_i], 0.55 * float(s[1]) / st.attack_speed())
	act_target = m
	act_hit_at = 0.5
	act_mult = float(s[0])
	if string_i == 2:
		spend_poise(4.0)
	Sfx.play("swing", 0.8 if string_i < 2 else 1.0, 1.0 if string_i < 2 else 0.82)
	tp = zone.move(tp, (at - tp).normalized() * float(s[2]), radius)
	string_i = (string_i + 1) % 3
	string_idle = 0.0

## poses a sprite set names otherwise (the Empty Hand's painted chain: three light blows, a dodge)
const ALIAS := {"atk": "light1", "atk2": "light2", "atk3": "light3"}

func _start_act(a: String, secs: float) -> void:
	act = a
	act_t = 0.0
	act_len = maxf(0.08, secs)
	act_done = false
	var anim := a
	if a == "swing":
		anim = "atk"
	if not spr.set.has(anim) and ALIAS.has(anim) and spr.set.has(ALIAS[anim]):
		anim = ALIAS[anim]
	if not spr.set.has(anim):
		anim = "atk" if spr.set.has("atk") else "idle"
	spr.play(anim, true, false)
	spr.fps_override = spr.frame_count() / act_len

func _act(dt: float) -> void:
	act_t += dt
	spr.view = view
	spr.face = face
	spr.step(dt)
	match act:
		"atk", "atk2", "atk3", "heavy", "swing":
			if not act_done and act_t >= act_len * act_hit_at:
				act_done = true
				_land_blow()
		"roll":
			tp = zone.move(tp, roll_dir * 8.5 * dt, radius)
		"stun":
			pass
	if act_t >= act_len:
		act = ""
		heavy_pm = 0.0
		spr.fps_override = 0.0
		if act_target and act_target.dead:
			target = null

func _land_blow() -> void:
	var w: Item = _weapon()
	var fa: Vector2 = skills.fist_add()
	var lo: float = (w.dmg.x if w else 1.0) + fa.x
	var hi: float = (w.dmg.y if w else 3.0) + fa.y
	var d := randf_range(lo, hi)
	if w and w.is_ranged():
		var m := act_target
		if m == null or m.dead:
			m = Combat.nearest_monster(zone, mouse_tile(), 1.2)
		var to := m.tp if m else mouse_tile()
		# the wand's bolt is the weapon's own blow: physical, through armour, x1.15 on the skill multiplier (t_v17.js)
		var mi: Missile = Missile.fire(zone, tp + (to - tp).normalized() * 0.4, to, 11.0, d * st.skill_mult() * 1.15, "phys", "hero", "bolt")
		mi.height = 70.0
		return
	d *= st.melee_mult() * act_mult * (skills.melee_k() if skills.has_method("melee_k") else 1.0)
	var m2 := act_target
	if m2 and not m2.dead and tp.distance_to(m2.tp) <= _reach() + m2.radius + 0.4:
		var o_hit := {"melee": true, "heavy": act_mult > 1.5 or heavy_pm > 0.0}
		if heavy_pm > 0.0:
			o_hit["poise"] = d * heavy_pm
		var dealt: float = Combat.hit_monster(m2, d, "phys", tp, o_hit)
		Sfx.play("heavy" if (act_mult > 1.5 or heavy_pm > 0.0 or o_hit.get("finisher", false)) else "hit")
		skills.on_weapon_hit(m2, dealt)
		if o_hit.get("finisher", false):
			# the finishing blow: 15% of your resource and 20 poise come back, and the frame holds
			st.res = minf(st.res_max(), st.res + st.res_max() * 0.15)
			st.poise = minf(st.poise_max(), st.poise + 20.0)
			Game.hitstop(0.09)
			Game.shake(6.0)
		if act_mult > 1.5 and not m2.dead and not m2.boss:
			m2.stun = maxf(m2.stun, 0.35)   # the overhead staggers what it lands on (never a boss: zz_melee_chain.js:56)
		# a third splashes onto anything touching the target
		for o in Combat.monsters_in(zone, m2.tp, 0.7):
			if o != m2:
				Combat.hit_monster(o, d / 3.0, "phys", tp, {"melee": true})
		_weapon_elements(m2)
		if act_mult > 1.5:
			Game.hitstop(0.07)
			Game.shake(2.2)   # the browser's finisher shake (zz_melee_chain.js:55)
	else:
		# a swing at the air still cuts what stands in front
		var front := tp + Vector2(cos(0), sin(0)) * 0.0
		for o in Combat.monsters_in(zone, tp + (mouse_tile() - tp).normalized() * 1.0, 0.8):
			Combat.hit_monster(o, d, "phys", tp, {"melee": true})

func _weapon_elements(m: Monster) -> void:
	var f := st.item("fire")
	if f > 0.0:
		Combat.hit_monster(m, f * 0.5, "fire", tp, {"poise": 0.0})
		m.add_dot(f * 0.5, 3.0, "fire")
	var c := st.item("cold")
	if c > 0.0:
		Combat.hit_monster(m, c, "cold", tp, {"poise": 0.0})
		m.slow = maxf(m.slow, 0.35)
	var mg := st.item("magic") + st.item("ltng")
	if mg > 0.0:
		Combat.hit_monster(m, mg, "magic", tp, {"poise": 0.0})
		if randf() < 0.25:
			m.stun = maxf(m.stun, 0.15)
	var p := st.item("psn")
	if p > 0.0:
		m.add_dot(p / 2.0, 3.0, "poison")

# ------------------------------------------------------------------ roll, poise, damage
func roll() -> void:
	if act == "stun" or shaken:
		if shaken:
			Bus.say.emit("Too shaken to roll.", 1.0)
		return
	if st.poise < 16.0:
		return
	spend_poise(34.0)
	# Hollow Step: the roll leaves a silent afterimage; what is near it staggers
	if st.arc and st.arc.aM("h_step"):
		for m in Combat.monsters_in(zone, tp, 3.0):
			if not m.boss:
				m.stun = maxf(m.stun, 0.5)
	var to := mouse_tile() - tp
	roll_dir = to.normalized() if to.length() > 0.1 else Vector2(1, 1).normalized()
	_face(roll_dir)
	act = ""
	charge = 0.0
	holding_attack = false
	hold_t = 0.0
	string_i = 0
	_start_act("roll", 0.34)
	Sfx.play("roll")
	spr.play("dodge" if spr.set.has("dodge") else "walk", true, false)
	spr.fps_override = spr.frame_count() / 0.34
	invuln = 0.3
	walking = false

func spend_poise(n: float) -> void:
	st.poise = maxf(0.0, st.poise - n)
	st.poise_delay = 1.0

func poise_hit(pd: float, from: Vector2, heavy: bool) -> void:
	if break_grace > 0.0:
		return
	st.poise -= pd
	st.poise_delay = 1.0
	if heavy and from != Vector2.INF:
		tp = zone.move(tp, (tp - from).normalized() * 0.2, radius)
	if st.poise <= 0.0:
		st.poise = 0.0
		act = ""
		_start_act("stun", 0.75 * Combat.STAGGER)
		spr.play("hit" if spr.set.has("hit") else "idle", true, false)
		poise_burst = st.poise_max() * 0.5
		break_grace = 0.9 + 1.6
		shaken = true
		walking = false
		Sfx.play("break", 1.0, 0.8)

func absorb(d: float, elem: String) -> float:
	return skills.absorb(d, elem)

func drink(i: int) -> void:
	var k: String = st.inv.drink(i)
	if k != "":
		Sfx.play("drink")
	if k == "hp":
		if st.arc and st.arc.aR("v_crown"):
			Bus.say.emit("The draught does nothing. The choir mends you now.", 1.6)
		else:
			st.heal_pool += st.life_max() * 0.4 * (1.0 + float(st.fate.get("potion", 0.0)) / 100.0)
	elif k == "mp":
		st.restore_pool += st.res_max() * 0.5 * (1.0 + float(st.fate.get("potion", 0.0)) / 100.0)
	stats_changed.emit()

func die() -> void:
	if dead:
		return
	dead = true
	act = ""
	spr.play("death", true, false)
	spr.fps_override = 0.0
	died.emit()
	Bus.hero_died.emit()

func revive(at: Vector2) -> void:
	dead = false
	tp = at
	st.hp = st.life_max()
	st.res = st.res_max()
	st.poise = st.poise_max()
	act = ""
	target = null
	walking = false
	spr.play("idle", true)
	lamp.texture_scale = light_radius() * Iso.HX * 2.0 / 512.0 * 1.25
	_sync()
	stats_changed.emit()


# ------------------------------------------------------------------ the heavy attack (checklist 2, zz_mech_heavy.js)
## hold the attack past 0.18 s to wind up (full at 0.75 s); release lunges up to 0.9 yd and strikes x1.25 -> x2.0
## damage and x2 -> x3.5 poise damage for 12 -> 24 poise. Under 10% poise the wind-up is 1.35x and the recovery 1.3x
## slower (never locked out). A roll cancels it. Option: Settings.hold_heavy.
func _heavy(dt: float) -> void:
	var w: Item = _weapon()
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _ui_captured()
	var aimed := (target != null and not target.dead) or Input.is_key_pressed(KEY_SHIFT)
	var slow := 1.35 if st.poise < st.poise_max() * 0.1 else 1.0
	if not Settings.hold_heavy or (w and w.is_ranged()) or skills.left != "attack" or act == "stun" or act == "roll":
		hold_t = 0.0
		if holding_attack:
			holding_attack = false
			charge = 0.0
		return
	if lmb and aimed:
		hold_t += dt
		if hold_t > 0.18 * slow and (act == "" or holding_attack):
			if not holding_attack:
				holding_attack = true
				string_i = 0
			charge = clampf((hold_t - 0.18 * slow) / (0.57 * slow), 0.0, 1.0)
	elif holding_attack and not lmb:
		_release_heavy(slow)
	else:
		hold_t = 0.0

func _release_heavy(slow: float) -> void:
	var k := charge
	holding_attack = false
	hold_t = 0.0
	charge = 0.0
	var at: Vector2 = target.tp if target and not target.dead else mouse_tile()
	var to := at - tp
	var lunge := minf(0.9, maxf(0.0, to.length() - (target.radius if target else 0.0) - 0.9))
	if to.length() > 0.01:
		tp = zone.move(tp, to.normalized() * lunge, radius)
	_face(to)
	spend_poise(lerpf(12.0, 24.0, k))
	_start_act("heavy" if spr.set.has("heavy") else "atk", 0.55 * lerpf(1.1, 1.5, k) * (1.3 if slow > 1.0 else 1.0) / st.attack_speed())
	act_target = target if target and not target.dead else null
	act_hit_at = 0.35
	act_mult = lerpf(1.25, 2.0, k)
	heavy_pm = lerpf(2.0, 3.5, k)
	string_i = 0
	string_idle = 0.0
