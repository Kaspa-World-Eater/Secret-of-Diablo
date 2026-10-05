extends Node
## (creature AI port) test bench, not part of the game: runs the game scene, then (user args after --)
##   --spawn=hollow*3,archer*2   kinds to set down 6-8 yd from the hero on open ground (awake unless --asleep)
##   --only                      clear the zone's own creatures first
##   --lvl=5                     their level     --god     the hero never dies     --at=x,y  put the hero there
## e.g. godot --path . res://tests/ai_test.tscn -- --zone=moor --demo --only --spawn=bell --god

var main: Node
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	main = load("res://scenes/game.tscn").instantiate()
	add_child(main)
	_run()

func _physics_process(_dt: float) -> void:
	if args.has("god") and main and main.hero and not main.hero.dead:
		main.hero.st.hp = main.hero.st.life_max()

func _open(z: Zone, c: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if z.is_solid(c + Vector2(dx, dy)):
				return false
	return true

func _run() -> void:
	while main.zone == null or main.hero == null or main.travelling:
		await get_tree().process_frame
	var z: Zone = main.zone
	var h: Hero = main.hero
	if args.has("only"):
		for m in get_tree().get_nodes_in_group("monsters"):
			m.remove_from_group("monsters")
			m.queue_free()
	if args.has("atboss"):
		var r = z.markers.get("bossRoom")
		if r is Dictionary:
			h.tp = Vector2(float(r["x"]) + 2.5, float(r["cy"]))
			if z.is_solid(h.tp):
				var c := z._nearest_open(Vector2i(int(h.tp.x), int(h.tp.y)))
				h.tp = Vector2(c.x + 0.5, c.y + 0.5)
		for m in get_tree().get_nodes_in_group("monsters"):
			if m.boss and args.has("bosshp"):
				m.hp = m.hp_max * float(args["bosshp"])
			if not m.boss and m.tp.distance_to(h.tp) < 30.0:
				m.remove_from_group("monsters")
				m.queue_free()
	elif args.has("altar"):
		for o in z.objects:
			if o.get("type") == "altar":
				h.tp = Vector2(o["x"] + 0.5, o["y"])
				print("TB altar of ", o.get("god"), " at ", h.tp)
				break
	elif args.has("at"):
		var p: PackedStringArray = args["at"].split(",")
		h.tp = Vector2(float(p[0]), float(p[1]))
	elif args.has("spawn"):
		# the nearest wide open ground to the start
		var best := h.tp
		for r in range(0, 90, 2):
			var found := false
			for i in 24:
				var a := i / 24.0 * TAU
				var c := h.tp + Vector2(cos(a), sin(a)) * r
				c = Vector2(floor(c.x) + 0.5, floor(c.y) + 0.5)
				var sc = z.markers.get("safeCircle")
				if sc is Dictionary and c.distance_to(Vector2(sc["x"], sc["y"])) < float(sc["r"]) + 12.0:
					continue
				if c.x > 12 and c.y > 12 and c.x < z.w - 12 and c.y < z.h - 12 and _open(z, c, 5) and (not args.has("soft") or z.type_at(c) not in [1, 14]):
					best = c
					found = true
					break
			if found:
				break
		h.tp = best
	h.position = Iso.to_screen(h.tp)
	if args.has("god"):
		h.st.extra["vit"] = 3000.0
		h.st.hp = h.st.life_max()
	var lvl := int(args.get("lvl", "3"))
	var n := 0
	if args.has("spawn"):
		for part in args["spawn"].split(","):
			var kp: PackedStringArray = part.split("*")
			var cnt := int(kp[1]) if kp.size() > 1 else 1
			for i in cnt:
				var a := (n * 2.39996) + 0.5
				n += 1
				var at := h.tp + Vector2(cos(a), sin(a)) * randf_range(5.0, 7.0)
				var rank := "normal"
				var kind := kp[0]
				if kind.contains("@"):
					rank = kind.split("@")[1]
					kind = kind.split("@")[0]
				var m: Monster = Brain.spawn(z, kind, at, lvl, rank, "test")
				if m and args.has("asleep"):
					m.brain.state = "sleep"
					m.awake = false
	var tick := 0
	while true:
		await get_tree().create_timer(0.5).timeout
		tick += 1
		if main.hero == null:
			continue
		h = main.hero
		if args.has("leave") and tick == int(args["leave"]):
			var r2 = main.zone.markers.get("bossRoom")
			h.tp = h.tp + Vector2(-40, 0) if r2 == null else Vector2(float(r2["cx"]), float(r2["cy"]))
			main.set("args", {})
			for i in 400:
				var c2 := Vector2(randf_range(5, main.zone.w - 5), randf_range(5, main.zone.h - 5))
				if not main.zone.is_solid(c2) and c2.distance_to(Vector2(float(r2["cx"]), float(r2["cy"]))) > 45.0:
					h.tp = c2
					break
			h.position = Iso.to_screen(h.tp)
			h.target = null
			print("TB hero leaves to ", h.tp)
		if args.has("god"):
			h.st.hp = h.st.life_max()
			if h.dead:
				h.revive(h.tp)
		if tick % 2 == 0:
			var s := "TB t=%d hero %s hp %d poise %d act %s view %s/%d |" % [tick / 2, h.tp.snapped(Vector2(0.1, 0.1)), h.st.hp, h.st.poise, h.act, h.view, h.face]
			for m in get_tree().get_nodes_in_group("monsters"):
				if m.tp.distance_to(h.tp) < 14.0 or m.boss:
					s += " %s:%s(%.1f,%d%s)" % [m.kind, m.brain.state, m.tp.distance_to(h.tp), m.hp, " B" if m.buried else ""]
			print(s)
