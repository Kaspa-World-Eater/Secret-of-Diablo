extends "res://entities/ai/brain.gd"
## PYRE-SAINTS: burning martyrs. They walk straight at you leaving burning footprints (a fire every 0.45 s: 0.45 yd,
## 70% of their mean damage per second, 3.5 s), and at 1.35 yd they flare (0.9 s) and erupt: a 1.8 yd blast of x1.6
## magic and a ring of six fires, and die. Killed, they still erupt at 55%. Wading through shallows douses one for good
## (x0.7 speed, x0.45 damage, a plain melee walker). They burn in the dark (drawn unshaded). Tell: the flames roar
## white (the wind pose). zc_combat22.js AI22.pyre, pyreErupt, monDeath22.

var doused := false
var trail_t := 0.0
var last_fire := Vector2.INF

func init(m: Monster) -> void:
	super.init(m)
	fix_sprite(m)
	reach = 1.35
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	m.spr.material = mat

func tick(m: Monster, dt: float) -> void:
	kind_tick(m, dt)

func think(m: Monster, h: Hero, dt: float) -> void:
	var d := m.tp.distance_to(h.tp)
	if not doused and m.zone.type_at(m.tp) == 12:
		douse(m)
	if doused:
		melee_k(m, h, dt, 1.0)
		return
	if h.dead or d > 26.0 or state == "home":
		melee_rhythm(m, h, dt)
		return
	trail_t -= dt
	if trail_t <= 0.0 and m.tp != last_fire and world:
		trail_t = 0.45
		last_fire = m.tp
		world.fire(m.tp, 0.45, (m.dmg.x + m.dmg.y) * 0.5 * 0.7 * m.hour_mult(), 3.5, m)
	if state == "wind":
		m.look(h.tp - m.tp)
		if t > wind:
			erupt(m, h, 1.0)
			m.die(m.tp)
		return
	state = "chase"
	if d < 1.35:
		set_state("wind")
		return
	_approach(m, h.tp, dt)

func douse(m: Monster) -> void:
	doused = true
	m.speed *= 0.7
	m.dmg *= 0.45
	m.name_shown = "Doused " + m.name_shown.trim_prefix("Champion ")
	reach = 0.95
	m.spr.material = null
	if ResourceLoader.exists("res://art/sprites/pyre@doused.json"):
		m.spr.set = Data.sprite_set("pyre@doused")
		m.spr.play("idle", true)
	if world:
		world.grit_burst(m.tp, Color(0.78, 0.8, 0.84, 0.8), 18, 1.2, 50.0)
		world.grit_burst(m.tp, Color(0.56, 0.54, 0.49), 8, 0.8, 40.0)
	Bus.say.emit("The Pyre-Saint gutters out", 1.2)
	state = "chase"

func erupt(m: Monster, h: Hero, k: float) -> void:
	var R := 1.8 * k
	var dmg := m.roll_damage() * 1.6 * k
	if world:
		world.grit_burst(m.tp, Color(0.95, 0.62, 0.3), 30, 1.6, 50.0)
		world.grit_burst(m.tp, Color(0.25, 0.2, 0.18), 16, 1.2, 40.0)
	if h and hero_open(h) and m.tp.distance_to(h.tp) < R:
		Combat.hit_hero(h, dmg, "magic", m.tp, {"src": Combat.who(m) + "|its eruption"})
	hit_allies(m.get_tree(), m.tp, R, dmg, "magic", m.tp)
	if world:
		for i in 6:
			var a := i / 6.0 * TAU
			world.fire(m.tp + Vector2(cos(a), sin(a)) * R * 0.55, 0.5, dmg * 0.4, 4.0, m)

func on_death(m: Monster) -> void:
	super.on_death(m)
	if not doused and state != "wind":
		erupt(m, m.hero(), 0.55)

func _anim(m: Monster, dt: float) -> void:
	pose(m, dt)

func on_hit(m: Monster, d: float, from: Vector2, opts: Dictionary) -> void:
	super.on_hit(m, d, from, opts)
	hurt_t = 0.24
