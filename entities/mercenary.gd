extends RefCounted
## (Secret of Diablo) The mercenary: a Pandoran Guard, a spearman who walks with the pilgrim of any order, Diablo II's
## hireling. He comes into each zone at the pilgrim's side, grows with the pilgrim's level, and when he falls he comes
## back 25 s later. Built on entities/ally_sod.gd. Attached by core/main.gd on every zone entry.

const Ally = preload("res://entities/ally_sod.gd")
const RETURN_S := 25.0

static var node = null
static var back_t := 0.0
static var _timer_owner = null


static func stats(lvl: int) -> Dictionary:
	return {"id": "merc", "name": "Pandoran Guard", "sprite": "lpc_knight", "hp": 70.0 + 18.0 * (lvl - 1),
		"dmg": Vector2(4.0 + 2.0 * lvl, 9.0 + 3.0 * lvl), "reach": 1.3, "cd": 1.0, "speed": 3.4, "dr": 0.15,
		"res": {"fire": 20.0, "cold": 20.0, "poison": 20.0, "magic": 20.0}, "tint": Color(0.75, 0.82, 1.0)}


static func attach(main, zone, hero) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	node = null
	if back_t <= 0.0:
		_spawn(zone, hero)
	if _timer_owner == null or not is_instance_valid(_timer_owner):
		var t := Timer.new()
		t.wait_time = 1.0
		t.autostart = true
		main.add_child(t)
		t.timeout.connect(func(): _tick(main))
		_timer_owner = t


static func _spawn(zone, hero) -> void:
	var a := Ally.new()
	a.setup(hero, stats(hero.st.level), hero.tp + Vector2(1.0, 0.6))
	if zone.is_solid(a.tp):
		a.tp = hero.tp
	a.slot = 1
	zone.sorted.add_child(a)
	a.fell.connect(func(_x):
		back_t = RETURN_S
		hero.skills.say("Your mercenary has fallen. He will return.", 1.6) if hero.skills.has_method("say") else null)
	node = a


static func _tick(main) -> void:
	var hero = main.hero
	if hero == null or not is_instance_valid(hero) or hero.zone == null:
		return
	if node != null and is_instance_valid(node) and not node.gone:
		# he grows with the pilgrim
		var s := stats(hero.st.level)
		if float(s["hp"]) > node.max_hp:
			var frac: float = node.hp / node.max_hp
			node.cfg["dmg"] = s["dmg"]
			node.max_hp = s["hp"]
			node.hp = node.max_hp * frac
		return
	if back_t > 0.0:
		back_t -= 1.0
		if back_t <= 0.0:
			_spawn(hero.zone, hero)
