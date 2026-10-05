extends Node
## The walker (ACT1_PLAN step 5): a scripted pilgrim that walks Act I zone by zone under the real game, and says what
## is stuck, unreachable or broken. Only with the user arg --walk (world/objects.gd starts it):
##   --walk                 every Act I zone in data/zones/index.json, in its order
##   --walk=moor,fen        only those zones
##   --walk_speed=N         game speed while walking (default 3)
##   --walk_t=S             the most game seconds spent on one goal (default 90)
##   --walk_shots=DIR       (needs a window) a screenshot with the collision overlay wherever a goal fails, and the
##                          route it was given drawn in blue: DIR/<zone>_<n>.png
## In each zone it walks to every exit, lantern-stone, waystone and chest, nearest first, fighting whatever comes
## within reach on the way. It takes no blows, and a creature too strong for its level (15 s of fighting) is cut
## through and named on the line, since the walk is about the map, not the balance. A goal it cannot
## path to is UNREACHABLE; one it stops closing on for 12 s is STUCK. Chests are opened (the loot path). Lines:
##   WALK <zone> <type> "<name>" ok|STUCK|UNREACHABLE|TIMEOUT <secs> [at hero (x,y) goal (x,y)]
##   WALKZONE <zone> goals N ok N bad N kills N secs S
##   WALKDONE zones N bad N   (then it quits)

const GOALS := ["portal", "lantern", "wp", "chest"]
var main: Node
var only: PackedStringArray = []
var speed := 3.0
var goal_t := 90.0
var kills := 0
var hurt := 0.0
var shots := ""
var shot_n := 0
var route := PackedVector2Array()
var trace := false

func _ready() -> void:
	name = "Walker"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--walk="):
			only = a.trim_prefix("--walk=").split(",", false)
		elif a.begins_with("--walk_speed="):
			speed = float(a.trim_prefix("--walk_speed="))
		elif a == "--walk_trace":
			trace = true
		elif a.begins_with("--walk_shots="):
			shots = a.trim_prefix("--walk_shots=")
		elif a.begins_with("--walk_t="):
			goal_t = float(a.trim_prefix("--walk_t="))
	Bus.monster_killed.connect(func(_m): kills += 1)
	_run()

func _process(_dt: float) -> void:
	_tend()   # every frame: the walker is not here to die
	if main.hud and main.hud.has_method("close_panels"):
		main.hud.close_panels()   # a fresh pilgrim opens the skill page; the walker has no hands for it

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _zones() -> Array:
	if not only.is_empty():
		return Array(only)
	var out := []
	var zs: Dictionary = Data.zone_index().get("zones", {})
	for zid in zs:
		if int(zs[zid].get("act", 0)) == 1:
			out.append(zid)
	return out

func _mgr() -> Node:
	return main.zone.get_node_or_null("WorldObjects") if main.zone else null

## keep the pilgrim standing: top its life up and count what it lost
func _tend() -> void:
	var h = main.hero
	if h == null or h.dead:
		return
	var mx: float = h.st.life_max()
	h.invuln = 0.5   # no blow lands on the walker; what the creatures do is still seen in their fights
	if h.st.hp < mx:
		hurt += mx - h.st.hp
		h.st.hp = mx

func _run() -> void:
	Engine.time_scale = speed
	await _wait(1.5)
	var zones := _zones()
	var bad_total := 0
	for i in zones.size():
		var zid: String = zones[i]
		if main.zone == null or main.zone.id != zid:
			await main.enter(zid, "")
			await _wait(1.5)
		bad_total += await _walk_zone(zid)
	print("WALKDONE zones ", zones.size(), " bad ", bad_total)
	Engine.time_scale = 1.0
	get_tree().quit()

func _walk_zone(zid: String) -> int:
	var t0 := Time.get_ticks_msec()
	kills = 0
	hurt = 0.0
	var m := _mgr()
	var goals := []
	if m:
		for e in m.things:
			if e["live"] and e["type"] in GOALS:
				goals.append(e)
	var ok := 0
	var bad := 0
	var at: Vector2 = main.hero.tp
	while not goals.is_empty():
		goals.sort_custom(func(a, b): return at.distance_to(a["tp"]) < at.distance_to(b["tp"]))
		var e: Dictionary = goals.pop_front()
		var r: String = await _reach(e)
		if r == "ok":
			ok += 1
		else:
			bad += 1
		if r == "LEFT":   # carried out of the zone: come back and walk on
			while main.travelling or main.hero == null:
				await _wait(0.2)
			await main.enter(zid, "")
			await _wait(1.5)
			goals = goals.filter(func(g): return is_instance_valid(_mgr()))
			if _mgr() == null:
				break
			var left := []
			for g in goals:
				for e2 in _mgr().things:
					if e2["live"] and e2["type"] == g["type"] and e2["tp"] == g["tp"]:
						left.append(e2)
			goals = left
		at = main.hero.tp
	print("WALKZONE ", zid, " goals ", ok + bad, " ok ", ok, " bad ", bad, " kills ", kills,
		" secs ", snappedf((Time.get_ticks_msec() - t0) / 1000.0 * speed, 0.1))
	return bad

func _reach(e: Dictionary) -> String:
	var h = main.hero
	var z = main.zone
	var zid: String = z.id
	var foe := ""
	var cut := 0
	var tp: Vector2 = e["tp"]
	var reach: float = maxf(1.6, float(e["reach"]) + 0.4)
	if e["type"] == "wp":
		reach = 2.2   # its panel opens within 1.1: stop short of it
	var t := 0.0
	var anchor: Vector2 = h.tp
	var since := 0.0
	var foe_t := 0.0
	var last_foe = null
	var fight := 0.0   # fighting on the way does not count against the walk
	var res := ""
	var p: PackedVector2Array = z.path(h.tp, tp)
	if p.is_empty() and not z.line_clear(h.tp, tp):
		res = "UNREACHABLE"
	if e["type"] == "chest":
		_mgr().pending = e
	h.walk_to(tp)
	while res == "":
		await _wait(0.2)
		t += 0.2
		if main.zone != z or main.hero == null:
			res = "LEFT"   # something carried the pilgrim out of the zone
			break
		_tend()
		h = main.hero
		var d: float = h.tp.distance_to(tp)
		if trace and int(t * 5) % 25 == 0:
			print("  T %.1f hero (%.1f,%.1f) d %.1f walking %s path %d/%d goal (%.1f,%.1f) act '%s' target %s" % [t, h.tp.x, h.tp.y, d, h.walking, h.path_i, h.path.size(), h.goal.x, h.goal.y, h.act, h.target.kind if h.target else "-"])
		if d <= reach:
			res = "ok"
			break
		# fight what comes close (or what it is already fighting); then walk on
		var mon = h.target if h.target != null and is_instance_valid(h.target) and not h.target.dead else null
		if mon == null:
			var near := Combat.nearest_monster(z, h.tp, 5.0)
			if near and not near.dead and z.line_clear(h.tp, near.tp):
				mon = near
		if mon:
			h.target = mon
			since = 0.0
			anchor = h.tp
			fight += 0.2
			foe_t = foe_t + 0.2 if mon == last_foe else 0.2
			last_foe = mon
			if foe_t > 15.0:
				# too strong for this pilgrim: note it and cut through, the walk is about the map
				foe += "%s%s hp %.0f/%.0f" % [", " if foe != "" else "", mon.kind, mon.hp, mon.hp_max]
				Combat.hit_monster(mon, 1e6, "phys", h.tp)
				foe_t = 0.0
			continue
		if not h.walking and h.act == "":
			if e["type"] == "chest" and _mgr().pending == null and not e["live"]:
				res = "ok"   # opened
				break
			h.walk_to(tp)
		# stuck: not moved half a yard in 12 s of walking (a route may lead away from the goal before it turns)
		if h.tp.distance_to(anchor) > 0.5:
			anchor = h.tp
			since = 0.0
		else:
			since += 0.2
		if since > 12.0:
			res = "STUCK"
		elif t - fight > goal_t:
			res = "TIMEOUT"
	var line := "WALK %s %s \"%s\" %s %.1f (fighting %.1f)" % [zid, e["type"], e["name"], res, t, fight]
	if res != "ok" and res != "LEFT" and is_instance_valid(h):
		line += " at hero (%.1f,%.1f) goal (%.1f,%.1f) path %d" % [h.tp.x, h.tp.y, tp.x, tp.y, p.size()]
	if foe != "":
		line += " | cut through (too strong): " + foe
	if shots != "" and res in ["STUCK", "TIMEOUT", "UNREACHABLE"] and is_instance_valid(h):
		line += " | shot " + await _shot(zid, h, tp)
	print(line)
	if res != "LEFT" and is_instance_valid(h):
		h.walking = false
		h.target = null
	return res


## the place a goal failed, for the eye: the collision overlay (TestHooks), the route in blue, the goal in white
func _shot(zid: String, h, goal: Vector2) -> String:
	Engine.time_scale = 1.0
	route = main.zone.path(h.tp, goal)
	var n := Node2D.new()
	n.z_index = 4001
	n.z_as_relative = false
	main.zone.add_child(n)
	n.draw.connect(func():
		for i in range(1, route.size()):
			n.draw_line(Iso.to_screen(route[i - 1]), Iso.to_screen(route[i]), Color(0.3, 0.6, 1.0, 0.9), 3.0)
		n.draw_circle(Iso.to_screen(goal), 8.0, Color(1, 1, 1, 0.9)))
	if main.zone.get_node_or_null("CollisionShow") == null:
		load("res://core/test_hooks.gd")._show_collision(main)
	main.cam.position = h.position
	main.cam.reset_smoothing()
	for i in 3:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(shots)
	shot_n += 1
	var path := "%s/%s_%d.png" % [shots, zid, shot_n]
	get_viewport().get_texture().get_image().save_png(path)
	n.queue_free()
	Engine.time_scale = speed
	return path
