extends Node
## The passage between waystones (zz_zz_maw95.js): walk to the centre; sink into the throat while it widens; the
## body comes apart in blood, bone and viscera; the stones close; black. At the destination the matter draws back
## together and you rise out of the pit, wet, and it closes behind you. Nothing glows.
## Lives under main for the whole run (the zone it starts in is freed on the way).

const SINK_MAX := 52.0     # world px the body sinks (x4 Godot px)

var main: Node
var on := false
var phase := ""
var t := 0.0
var dest := ""
var from := Vector2.ZERO
var ws: Node               # the waystone of the zone we are in
var sink := 0.0
var wet := false
var spilt := false
var _mat: ShaderMaterial

const CLIP := """
shader_type canvas_item;
uniform float cut_y = 1e9;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y; }
void fragment() { if (wy > cut_y) { discard; } }
"""

func _ready() -> void:
	name = "WaystonePassage"
	var sh := Shader.new()
	sh.code = CLIP
	_mat = ShaderMaterial.new()
	_mat.shader = sh

func _ui() -> Node:
	return main.get_node_or_null("GodmarrowWorldUI")

func _mgr() -> Node:
	return main.zone.get_node_or_null("WorldObjects") if main and main.zone else null

## start a passage to zone `id` from the waystone the hero stands at. False: not standing at one (plain travel).
func begin(id: String) -> bool:
	var m := _mgr()
	var h = main.hero
	if on or m == null or m.waystone == null or h == null or h.dead:
		return false
	ws = m.waystone
	if h.tp.distance_to(ws.tp) > 3.5:
		return false
	on = true
	phase = "walk"
	t = 0.0
	dest = id
	from = h.tp
	wet = false
	spilt = false
	ws.held = true
	_lock(h)
	return true

func _lock(h) -> void:
	h.act = "maw"
	h.act_t = 0.0
	h.act_len = 1e9
	h.walking = false
	h.target = null
	h.invuln = maxf(h.invuln, 0.5)
	h.set_process_unhandled_input(false)
	h.spr.material = _mat
	h.spr.play("idle")

func _release(h) -> void:
	if h == null or not is_instance_valid(h):
		return
	h.act = ""
	h.act_len = 0.0
	h.set_process_unhandled_input(true)
	h.spr.material = null
	h.spr.position = Vector2.ZERO
	if h.get_child_count() > 0 and h.get_child(0) is Polygon2D:
		h.get_child(0).visible = true

static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

func _apply_sink(h) -> void:
	if h == null or not is_instance_valid(h) or ws == null or not is_instance_valid(ws):
		return
	h.spr.position = Vector2(0, sink * Iso.WPX)
	var cut := Iso.to_screen(ws.tp).y + 2.0 * Iso.WPX
	_mat.set_shader_parameter("cut_y", cut if sink > 0.01 else 1e9)
	if h.get_child_count() > 0 and h.get_child(0) is Polygon2D:
		h.get_child(0).visible = sink < 4.0

func _gore() -> Node:
	var m := _mgr()
	return m.gore if m else null

func _process(dt: float) -> void:
	if not on:
		return
	var h = main.hero
	if phase == "wait":
		return
	if h == null or not is_instance_valid(h):
		return
	t += dt
	h.invuln = maxf(h.invuln, 0.3)
	h.walking = false
	h.target = null
	var ui := _ui()
	var g := _gore()
	match phase:
		"walk":
			var k := _ease(t / 0.45)
			h.tp = from.lerp(ws.tp + Vector2(0, 0.05), k)
			h._sync()
			ws.open += (1.0 - ws.open) * minf(1.0, dt * 6.0)
			if t >= 0.45:
				phase = "sink"
				t = 0.0
		"sink":
			var k := _ease(t / 0.95)
			sink = k * SINK_MAX
			ws.widen = k * 6.0
			if g and randf() < dt * 40.0:
				g.gore(h.tp + Vector2(randf() - 0.5, (randf() - 0.5) * 0.6) * 0.4, 4, true)
			if t >= 0.95:
				phase = "close"
				t = 0.0
				ws.open = 0.0
				if g:
					g.gore(ws.tp, 26, true)
					g.stain(ws.tp, 22, 9.0)
		"close":
			if ui:
				ui.set_fade(_ease(t / 0.45))
			if t >= 0.55:
				phase = "wait"
				t = 0.0
				if ui:
					ui.set_fade(1.0)
				ws.held = false
				_go()
				return
		"dark":
			if t >= 0.35:
				phase = "rise"
				t = 0.0
		"rise":
			if ui:
				ui.set_fade(1.0 - _ease(t / 0.5))
			ws.open += (1.0 - ws.open) * minf(1.0, dt * 7.0)
			if not spilt and t > 0.12:
				spilt = true
				if g:
					g.reform(h.tp, 70)
					g.gore(ws.tp, 24, true)
					g.stain(ws.tp, 26, 10.0)
			ws.widen = (1.0 - _ease(t / 1.1)) * 6.0
			sink = (1.0 - _ease((t - 0.15) / 1.0)) * SINK_MAX
			if g and randf() < dt * 14.0:
				g.gore(h.tp, 2, false)
			if t >= 1.2:
				sink = 0.0
				ws.widen = 0.0
				ws.held = false
				on = false
				if g:
					g.drips = 4.0
				_apply_sink(h)
				_release(h)
				return
	_apply_sink(h)

func _go() -> void:
	var h = main.hero
	if h:
		_release(h)
	await main.enter(dest, "")
	# attach() normally already placed us (arrive); make sure
	if phase == "wait":
		arrive(main.zone, main.hero)

## called when the destination zone is up (by objects.attach, or after enter returns)
func arrive(zone: Node, h) -> void:
	if phase != "wait" or zone == null or h == null:
		return
	var m := zone.get_node_or_null("WorldObjects")
	var w = m.waystone if m else null
	phase = "dark"
	t = 0.0
	if w == null:
		# no waystone here (should not happen): stand at the start, wet
		on = false
		var ui := _ui()
		if ui:
			ui.set_fade(0.0)
		return
	ws = w
	ws.held = true
	ws.open = 0.0
	h.tp = ws.tp + Vector2(0, 0.05)
	h._sync()
	_lock(h)
	sink = SINK_MAX
	_apply_sink(h)
	if main.cam:
		if main.eye:
			main.eye.cut(h)
		main.cam.position = h.position + Vector2(0, -40)
		main.cam.reset_smoothing()
	# the waystone learns you, even arriving
	var Q = load("res://world/quests.gd")
	Q.kindle_wp(zone.id)
	if m:
		m.wp_near = true

## travel without the passage (not standing at the waystone): arrive a step south of the destination's waystone
func plain(id: String) -> void:
	await main.enter(id, "")
	var mg = main.zone.get_node_or_null("WorldObjects") if main.zone else null
	if mg and mg.waystone and main.hero:
		main.hero.tp = mg.waystone.tp + Vector2(0, 1.3)
		main.hero._sync()
		mg.wp_near = true
		if main.cam:
			if main.eye:
				main.eye.cut(main.hero)
			main.cam.position = main.hero.position + Vector2(0, -40)
			main.cam.reset_smoothing()
