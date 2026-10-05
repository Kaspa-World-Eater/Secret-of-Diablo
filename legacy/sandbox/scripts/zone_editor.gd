extends Node2D
## In-game collision painter for imported zones (F9 to toggle; saves on exit).
##
##   Left-drag ........ paint cells solid
##   Right-drag ....... paint cells walkable
##   Shift + click .... toggle "this tile is solid" everywhere it appears
##                      (one click marks every tree / wall / water tile of that kind)
##   P ................ set the player spawn point at the cursor
##   F9 ............... save and return to play

var active := false
var _paint := 0  # 1 solid, -1 open


func _ready() -> void:
	z_index = 50


func toggle() -> void:
	var w = Game.world
	if w.zone == "":
		Game.message("Collision painting is for imported zones (F10 to travel)")
		return
	active = not active
	Game.editing = active
	if active:
		Game.message("COLLISION PAINT: L-drag solid, R-drag walkable, Shift+click tile type, P spawn, F9 save")
	else:
		w.refresh_zone_collision()
		w.save_zone_collision()
		Game.message("Collision saved")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	var w = Game.world
	if event is InputEventMouseButton:
		var c: Vector2i = w.cell_of(get_global_mouse_position())
		if event.pressed and event.shift_pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_tile_type(c)
		elif event.pressed:
			_paint = 1 if event.button_index == MOUSE_BUTTON_LEFT else (-1 if event.button_index == MOUSE_BUTTON_RIGHT else 0)
			_apply(c)
		else:
			_paint = 0
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _paint != 0:
		_apply(w.cell_of(get_global_mouse_position()))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var c: Vector2i = w.cell_of(get_global_mouse_position())
		w.collision["spawn"] = [c.x, c.y]
		Game.message("Spawn set")
		queue_redraw()
		get_viewport().set_input_as_handled()


func _apply(c: Vector2i) -> void:
	var w = Game.world
	if _paint == 0 or not w.in_bounds(c):
		return
	var key := [c.x, c.y]
	var sc: Array = w.collision["solid_cells"]
	var oc: Array = w.collision["open_cells"]
	sc.erase(key)
	oc.erase(key)
	var want := _paint == 1
	w.set_cell_solid(c, false)  # evaluate tile rules without overrides
	if w.cell_solid_by_rules(c) != want:
		(sc if want else oc).append(key)
	w.set_cell_solid(c, want)
	queue_redraw()


func _toggle_tile_type(c: Vector2i) -> void:
	var w = Game.world
	if not w.in_bounds(c):
		return
	var t: int = w.top_tile(c)
	if t < 0:
		return
	var st: Array = w.collision["solid_tiles"]
	if st.has(t):
		st.erase(t)
		Game.message("Tile #%d is walkable" % t)
	else:
		st.append(t)
		Game.message("Tile #%d is solid everywhere" % t)
	w.refresh_zone_collision()
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var w = Game.world
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom / 2.0 + Vector2(64, 64)
	var a: Vector2i = w.cell_of(center - half)
	var b: Vector2i = w.cell_of(center + half)
	for y in range(max(0, a.y), min(w.H, b.y + 1)):
		for x in range(max(0, a.x), min(w.W, b.x + 1)):
			if w.solid[y * w.W + x] == 1:
				draw_rect(Rect2(Vector2(x, y) * w.TILE, Vector2(w.TILE, w.TILE)), Color(1, 0.1, 0.1, 0.35))
	var mc: Vector2i = w.cell_of(get_global_mouse_position())
	draw_rect(Rect2(Vector2(mc) * w.TILE, Vector2(w.TILE, w.TILE)), Color(1, 1, 0.3, 0.9), false, 2.0)
	var sp = w.collision.get("spawn")
	var sc: Vector2i = w.spawn_cell if sp == null else Vector2i(int(sp[0]), int(sp[1]))
	draw_circle(w.center_of(sc), 8.0, Color(0.3, 1, 0.3, 0.9))
