extends "res://world/objects/manager_use.gd"
## The world's objects, part 3 of 3: the frame (proximity, the town's safe circle, pending walks), hover and clicks.
## The state and how everything is built are in manager_build.gd (its header says what this system is).

# ------------------------------------------------------------------ the frame
func _process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if waystone:
		waystone.tick(dt, Q.known_wp(zone.id))
	_tick_buffs(dt)
	_tick_altars()
	if main.travelling or (passage and passage.on):
		return
	_hover()
	if hero.dead:
		pending = null
		return
	# the town's safe circle: nothing may come in, nothing can hurt you there
	if safe_r > 0.0:
		if hero.tp.distance_to(safe_c) < safe_r:
			hero.invuln = maxf(hero.invuln, 0.15)
		sweep_t -= dt
		if sweep_t <= 0.0:
			sweep_t = 0.25
			_sweep()
	_proximity()
	_pending(dt)
	mark_cool -= dt
	mark_t -= dt
	if mark_t <= 0.0:
		mark_t = 0.4
		if mark_cool <= 0.0:
			_marks()
	if not wave.is_empty():
		wave["t"] = wave.get("t", 0.0) - dt
		if wave["t"] <= 0.0:
			wave["t"] = 0.25
			_wave_check()

func _sweep() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.zone != zone or m.dead:
			continue
		if m.tp.distance_to(safe_c) < safe_r + 1.0:
			if m.home.distance_to(safe_c) > safe_r + 2.0:
				m.tp = m.home
				if m.brain:
					m.brain.state = "sleep"
			else:
				m.remove_from_group("monsters")
				m.queue_free()

func _proximity() -> void:
	# waystones: stand in one and it learns you; at the centre the travel panel opens
	if waystone:
		var d := hero.tp.distance_to(waystone.tp)
		if d < 3.2 and Q.kindle_wp(zone.id):
			Sfx.play("shrine", 0.8, 0.8)
			Bus.say.emit("%s knows your step." % zone.d.get("name", "The waystone"), 2.5)
			if ui:
				ui.speak(String(waystone.o.get("name", "Waystone")), String(waystone.o.get("vInscr", "")), -1.0, true)
		if d < 1.1:
			if not wp_near:
				wp_near = true
				_open_waystones()
		elif d > 2.4:
			wp_near = false
			if ui and ui.panel_open():
				ui.close_panel()
	# lantern-stones: remember every one passed within 6 yd; touch one to be restored
	for e in things:
		if e["type"] != "lantern":
			continue
		var d: float = hero.tp.distance_to(e["tp"])
		var key := "%s:%d" % [zone.id, int(e["o"].get("idx", 0))]
		if d < 6.0 and not Q.state()["lanterns"].has(key):
			Q.state()["lanterns"][key] = {"zone": zone.id, "x": e["tp"].x, "y": e["tp"].y, "name": e["name"]}
		if d < 1.3 and not lantern_latch.get(key, false):
			lantern_latch[key] = true
			_touch_lantern(e)
		elif d > 3.0:
			lantern_latch[key] = false

func _hover() -> void:
	var h = _thing_at_mouse()
	if h != hovered:
		hovered = h
		if ui:
			ui.hover(h["name"] if h else "")

func _thing_at_mouse():
	var mp := get_global_mouse_position()
	var mt := Iso.to_tile(mp)
	var best = null
	var by := -1e9
	for e in things:
		if not e["live"] or e["name"] == "":
			continue
		var node: Node2D = e["node"]
		var hit := false
		if node and is_instance_valid(node) and e["type"] != "wp":
			var r := _rect_of(node)
			hit = r.has_point(mp)
		if not hit:
			hit = mt.distance_to(e["tp"]) < (1.4 if e["type"] == "wp" else 0.7)
		if hit and node and node.global_position.y > by:
			by = node.global_position.y
			best = e
	return best

static func _rect_of(node: Node2D) -> Rect2:
	if node.has_method("click_rect"):
		return node.click_rect()
	for c in node.get_children():
		if c is Sprite2D and c.texture:
			var r: Rect2 = c.get_rect()
			return Rect2(c.global_position + r.position * c.scale, r.size * c.scale)
	return Rect2(node.global_position - Vector2(40, 120), Vector2(80, 130))

func _unhandled_input(ev: InputEvent) -> void:
	if hero == null or hero.dead or main.travelling or (passage and passage.on):
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h = _thing_at_mouse()
		if h == null:
			pending = null
			return
		if hero.monster_at_mouse() != null and h["type"] != "npc" and h["type"] != "vendor":
			pending = null
			return
		pending = h
		hero.target = null
		hero.walk_to(_approach(h))
		get_viewport().set_input_as_handled()

func _approach(h: Dictionary) -> Vector2:
	var tp: Vector2 = h["tp"]
	if h["type"] == "wp":
		return tp
	var to := hero.tp - tp
	if to.length() < 0.01:
		return tp
	return tp + to.normalized() * minf(to.length(), float(h["reach"]) * 0.6)

func _pending(_dt: float) -> void:
	if pending == null:
		return
	if hero.target != null:
		pending = null
		return
	var d: float = hero.tp.distance_to(pending["tp"])
	if d <= float(pending["reach"]):
		var h = pending
		pending = null
		hero.walking = false
		_face(h["tp"])
		_interact(h)
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (not hero.walking or hero.goal.distance_to(pending["tp"]) > float(pending["reach"])):
		hero.walk_to(_approach(pending))

func _face(tp: Vector2) -> void:
	var r := AnimSprite.hero_view(tp - hero.tp, hero.face)
	if r[0] != "":
		hero.view = r[0]
		hero.face = r[1]
