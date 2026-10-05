class_name AffixFx
extends Node2D
## What the deeds leave in the world (entities/affixes.gd): hot ash where one walked, the dust of one that slips
## through the earth, the ground giving up the Grave-Called, and a body that bursts. The user's rule: whatever can hurt
## must be plainly seen (no Diablo IV deaths to things you could not see), so the ash smoulders bright enough to read
## in the dark and only burns once it has settled. Drawn on the ground in the pixel grain;
## nothing glows.

const P := 4.0                 # the pixel grain
var kind := ""
var tp := Vector2.ZERO
var zone
var t := 0.0
var life := 1.0
var dmg := 0.0
var m                          # the creature, for slip and graves
var src_desc := ""             # who left it (the death screen)
var n := 0
var spots: Array = []          # ash: [Vector2 screen offset, ember?]
var hurt_t := 0.0

static func _make(z, k: String, at: Vector2, lf: float) -> AffixFx:
	var f := AffixFx.new()
	f.zone = z
	f.kind = k
	f.tp = at
	f.life = lf
	f.position = Iso.to_screen(at)
	f.z_index = -45
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # the dark never hides a tell (as the world's fires)
	f.material = mat
	z.sorted.add_child(f)
	return f

## a patch of hot ash where an Ash-Trailing creature walked; it hurts whoever stands in it
static func ash(z, at: Vector2, d: float, who: String = "") -> void:
	var f := _make(z, "ash", at, 4.5)
	f.src_desc = who
	f.dmg = d
	for i in 26:
		var a := randf() * TAU
		var r := sqrt(randf())
		f.spots.append([Vector2(floorf(cos(a) * r * 46.0 / P) * P, floorf(sin(a) * r * 22.0 / P) * P), randf() < 0.4])

## an Unquiet creature sinks, and comes up beside the hero
static func slip(mon, h) -> void:
	var f := _make(mon.zone, "slip", mon.tp, 0.5)
	f.m = mon
	mon.buried = true
	mon.stun = maxf(mon.stun, 0.5)
	_dust(mon.zone, mon.position, 10)
	Sfx.play("roll", 0.5, 0.7)

## the ground under a fallen Grave-Called gives up others
static func graves(mon, count: int) -> void:
	var f := _make(mon.zone, "graves", mon.tp, 1.0)
	f.m = mon
	f.n = count

## a Bursting body swells, then flies apart in bone
static func burst(mon) -> void:
	var f := _make(mon.zone, "burst", mon.tp, 1.0)
	f.dmg = (mon.dmg.x + mon.dmg.y) * 0.5 * 1.7
	f.src_desc = Combat.who(mon)
	f.z_index = -40

static func _dust(z, at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(0.3, 0.28, 0.26, 0.8)
	p.position = at + Vector2(0, -6)
	p.z_index = 5
	z.sorted.add_child(p)
	p.finished.connect(p.queue_free)

func _physics_process(dt: float) -> void:
	t += dt
	var h = zone.hero_ref if zone else null
	match kind:
		"ash":
			hurt_t -= dt
			if h and not h.dead and hurt_t <= 0.0 and t > 0.5 and t < life and h.tp.distance_to(tp) < 0.6:   # burns once settled
				hurt_t = 0.5
				var now := Time.get_ticks_msec()
				if now > int(h.get_meta("ground_hurt", 0)):   # ash and fire underfoot burn as one (the clarity rule)
					h.set_meta("ground_hurt", now + 480)
					Combat.hit_hero(h, dmg, "fire", tp, {"poise": 0.0, "src": (src_desc + "|its ash") if src_desc != "" else "hot ash on the ground"})
		"slip":
			if t >= life and m and is_instance_valid(m) and not m.dead:
				var to: Vector2 = m.tp
				if h:
					for k in 8:
						var a := randf() * TAU
						var q: Vector2 = h.tp + Vector2(cos(a), sin(a)) * 1.9
						if not zone.is_solid(q):
							to = q
							break
				m.tp = to
				m.buried = false
				m.stun = maxf(m.stun, 0.35)
				m.position = Iso.to_screen(to)
				_dust(zone, m.position, 12)
				Sfx.play("roll", 0.6, 0.6)
				m = null
		"graves":
			if t >= life and m != null:
				var kd_kind: String = m.kind if (m.kind in Monster.RAISED and m.radius <= 0.4) else "hollow"
				for i in n:
					var a := randf() * TAU
					var at: Vector2 = tp + Vector2(cos(a), sin(a)) * 0.9
					var g = Brain.spawn(zone, kd_kind, at, maxi(1, m.level - 1), "minion", str(m.pack))
					if g:
						g.name_shown = "Grave-Called " + String(g.name_shown)
						_dust(zone, g.position, 10)
				Sfx.play("break", 0.6, 0.55)
				m = null
		"burst":
			if t >= life and dmg > 0.0:
				var d := dmg
				dmg = 0.0
				var p := CPUParticles2D.new()
				p.one_shot = true
				p.emitting = true
				p.amount = 30
				p.lifetime = 0.6
				p.explosiveness = 1.0
				p.spread = 180.0
				p.initial_velocity_min = 160.0
				p.initial_velocity_max = 320.0
				p.gravity = Vector2(0, 300)
				p.scale_amount_min = 2.0
				p.scale_amount_max = 4.0
				p.color = Color(0.78, 0.74, 0.64)
				p.position = position + Vector2(0, -30)
				p.z_index = 6
				zone.sorted.add_child(p)
				p.finished.connect(p.queue_free)
				Sfx.play("break", 1.0, 0.8)
				if h and not h.dead and h.tp.distance_to(tp) < 2.4:
					Combat.hit_hero(h, d, "phys", tp, {"heavy": true, "src": (src_desc + "|its body bursting") if src_desc != "" else "a body bursting"})
	if t >= life + (0.6 if kind == "ash" else 0.3):
		queue_free()
	queue_redraw()

func _draw() -> void:
	match kind:
		"ash":
			var a := clampf(1.0 - (t - life) / 0.6, 0.0, 1.0) * clampf(t * 5.0, 0.0, 1.0)
			for s in spots:
				var o: Vector2 = s[0]
				if s[1]:
					var e := 0.5 + 0.5 * sin(t * 7.0 + o.x)
					draw_rect(Rect2(o, Vector2(P, P)), Color(0.78 + 0.14 * e, 0.42 + 0.1 * e, 0.16, 0.9 * a * clampf(1.2 - t / life, 0.0, 1.0)))
				else:
					draw_rect(Rect2(o, Vector2(P, P)), Color(0.2, 0.18, 0.17, 0.8 * a))
		"graves":
			# the ground cracks open where they will come up
			var k := clampf(t / life, 0.0, 1.0)
			for i in 10:
				var ang := i / 10.0 * TAU
				var r := 30.0 * k
				draw_rect(Rect2(Vector2(floorf(cos(ang) * r / P) * P, floorf(sin(ang) * r * 0.5 / P) * P), Vector2(P, P)), Color(0.08, 0.07, 0.07, 0.9))
		"burst":
			if dmg <= 0.0:
				return
			# the reach of the burst, marked in the dust, and the tightening ring that tells when
			var R := 2.4
			var k := clampf(t / life, 0.0, 1.0)
			for i in 40:
				var ang := i / 40.0 * TAU
				var q := Iso.to_screen(Vector2(cos(ang), sin(ang)) * R)
				draw_rect(Rect2(Vector2(floorf(q.x / P) * P, floorf(q.y / P) * P), Vector2(P, P)), Color(0.62, 0.58, 0.5, 0.55))
				var q2 := Iso.to_screen(Vector2(cos(ang), sin(ang)) * R * (1.0 - k) + Vector2.ZERO)
				if i % 2 == 0:
					draw_rect(Rect2(Vector2(floorf(q2.x / P) * P, floorf(q2.y / P) * P), Vector2(P, P)), Color(0.55, 0.5, 0.44, 0.45))
