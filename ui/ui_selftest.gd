extends Node
## ui/ui_selftest.gd (--uitest): drives the interface with synthetic input and prints PASS/FAIL lines. For headless checks.

var hud: Node

func _w(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * p

func _click(p: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	p = _w(p)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await get_tree().process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = button
		e.pressed = down
		e.shift_pressed = shift
		Input.parse_input_event(e)
		await get_tree().process_frame

func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame

func _ok(name: String, cond: bool) -> void:
	print(("UITEST PASS " if cond else "UITEST FAIL ") + name)

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var h: Hero = hud.hero
	var st := h.st
	var inv := st.inv
	# panels open with keys
	await _key(KEY_I)
	_ok("I opens the inventory", hud.p_inv.visible)
	await _key(KEY_C)
	_ok("C opens the character page", hud.p_char.visible)
	await _key(KEY_S)
	_ok("S opens the skill page and closes C", hud.p_skills.visible and not hud.p_char.visible)
	# the hero must not walk under a panel
	var m := InputEventMouseMotion.new()
	m.position = _w(Vector2(300, 300))
	Input.parse_input_event(m)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok("a panel stops the mouse (hovered control)", h.get_viewport().gui_get_hovered_control() != null)
	# learn a skill: the first row, first tree
	var sb := h.skills
	var sp0 := st.skill_points
	var first := ""
	for id in sb.data:
		var s: Dictionary = sb.data[id]
		if int(s.get("tab", 0)) == 0 and int(s.get("row", 0)) == 1 and s.get("prerequisites", []).is_empty():
			first = id
			break
	var c := Vector2(hud.p_skills.col_x(int(sb.data[first]["col"]) - 1), hud.p_skills.row_y(0)) * 4.0
	var h0: int = sb.hard.get(first, 0)
	await _click(hud.p_skills.global_position + c)
	_ok("click learns %s" % first, sb.hard.get(first, 0) == h0 + 1 and st.skill_points == sp0 - 1)
	# hover it and bind a key
	var mm := InputEventMouseMotion.new()
	mm.position = _w(hud.p_skills.global_position + c)
	Input.parse_input_event(mm)
	await get_tree().process_frame
	await get_tree().process_frame
	if sb.data[first].get("kind", "cast") != "passive":
		await _key(KEY_O)
		_ok("hover + O binds it", sb.keys.get("o", "") == first)
		print("  hovered: ", hud._hovered_skill(), " picker ", hud.picking)
	# the character page: spend a point
	await _key(KEY_C)
	st.attr_points = 2
	var v0 := st.vit
	await _click(hud.p_char.global_position + Vector2(204, 66) * 4.0)
	_ok("+ spends a point on Vitality", st.vit == v0 + 1 and st.attr_points == 1)
	# the inventory: pick up the first bag item and put it down elsewhere
	if inv.bag.size() > 0:
		var e: Dictionary = inv.bag[0]
		var it: Item = e["item"]
		var p: Vector2i = e["pos"]
		var gp: Vector2 = hud.p_inv.global_position + (Vector2(14, 120) + Vector2(p) * 12.0 + Vector2(6, 6)) * 4.0
		await _click(gp)
		_ok("click picks up %s" % it.name, hud.cursor_item == it)
		var dest: Vector2 = hud.p_inv.global_position + (Vector2(14, 120) + Vector2(8, 0) * 12.0 + Vector2(it.grid) * 6.0) * 4.0
		await _click(dest)
		_ok("click puts it down at 8,0", hud.cursor_item == null and inv.pos_of(it) == Vector2i(8, 0))
		# right-click equips it if it can be worn
		if it.slot != "" and inv.can_equip(it, st.level, st.cls):
			await _click(dest, MOUSE_BUTTON_RIGHT)
			_ok("right-click wears it", inv.equip.values().has(it))
	# belt: click drinks
	var n0: int = int(inv.belt[0]["n"]) if inv.belt[0] != null else 0
	await _click(hud.bar.global_position + Vector2(188 + 8, 250 + 8 - 216) * 4.0)
	var n1: int = int(inv.belt[0]["n"]) if inv.belt[0] != null else 0
	_ok("clicking the belt drinks", n0 == 0 or n1 == n0 - 1)
	# the skill picker
	await _click(hud.bar.global_position + Vector2(404 + 9, 249 + 9 - 216) * 4.0)
	_ok("the right skill button opens the picker", hud.picking == "R")
	await _key(KEY_ESCAPE)
	_ok("Esc closes it", hud.picking == "" and not hud.p_inv.visible)
	await _key(KEY_ESCAPE)
	_ok("Esc opens the pause menu", hud.pause.visible and get_tree().paused)
	await _key(KEY_ESCAPE)
	_ok("Esc resumes", not hud.pause.visible and not get_tree().paused)
	await _key(KEY_TAB)
	_ok("Tab shows the map", hud.automap.visible)
	print("UITEST DONE")
