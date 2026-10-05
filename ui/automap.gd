extends Control
## ui/automap.gd: the automap (Tab), D2 style: the zone drawn small and isometric over the world, centred on the hero.
## Tiles within 11 yd of the hero are revealed every 0.25 s and stay revealed for the run (fog of war per zone id).
## Walls and edges are bone lines, open ground a faint wash; gates, lantern-stones and the hero are marked.
## It never takes the mouse: the hero keeps walking under it.

const U := preload("res://ui/uikit.gd")
const REVEAL := 11.0
const K := 12.0                      # screen px per tile along an iso axis

var hud: Node
var seen := {}                       # zone id -> PackedByteArray (w*h)
var img: Image
var tex: ImageTexture
var zid := ""
var tick := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(zone: Zone) -> void:
	zid = zone.id
	if not seen.has(zid) or (seen[zid] as PackedByteArray).size() != zone.w * zone.h:
		var b := PackedByteArray()
		b.resize(zone.w * zone.h)
		seen[zid] = b
	img = Image.create(zone.w, zone.h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var b: PackedByteArray = seen[zid]
	for j in zone.h:
		for i in zone.w:
			if b[j * zone.w + i]:
				img.set_pixel(i, j, _col(zone, i, j))
	tex = ImageTexture.create_from_image(img)

func _col(zone: Zone, i: int, j: int) -> Color:
	var t := zone.types[j * zone.w + i]
	var solid := t in Zone.SOLID_TYPES
	if not solid:
		if t == 12 or t == 4:
			return Color(0.36, 0.46, 0.52, 0.28)
		return Color(0.62, 0.58, 0.5, 0.2)
	# a solid tile touching open ground is an edge: a bone line
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = i + d.x
		var y: int = j + d.y
		if x >= 0 and y >= 0 and x < zone.w and y < zone.h and not (zone.types[y * zone.w + x] in Zone.SOLID_TYPES):
			return Color(0.86, 0.82, 0.7, 0.62)
	return Color(0, 0, 0, 0)

## reveal around the hero (called by the HUD every frame, map open or not)
func step(dt: float) -> void:
	var h: Hero = hud.hero
	var zone: Zone = hud.zone
	if h == null or zone == null or img == null or zone.id != zid:
		return
	tick -= dt
	if tick > 0.0:
		return
	tick = 0.25
	var b: PackedByteArray = seen[zid]
	var r := int(REVEAL)
	var cx := int(h.tp.x)
	var cy := int(h.tp.y)
	var changed := false
	for j in range(maxi(0, cy - r), mini(zone.h, cy + r + 1)):
		for i in range(maxi(0, cx - r), mini(zone.w, cx + r + 1)):
			var k := j * zone.w + i
			if b[k]:
				continue
			if Vector2(i + 0.5, j + 0.5).distance_to(h.tp) > REVEAL:
				continue
			b[k] = 1
			img.set_pixel(i, j, _col(zone, i, j))
			changed = true
	if changed:
		tex.update(img)
	if visible:
		queue_redraw()

func _draw() -> void:
	var h: Hero = hud.hero
	var zone: Zone = hud.zone
	if h == null or zone == null or tex == null:
		return
	var vs := get_viewport_rect().size
	var centre := vs / 2.0 - Vector2(0, 60)
	# iso: tile x runs down-right, tile y down-left (the world's own projection, scaled)
	var ax := Vector2(K, K * 0.5)
	var ay := Vector2(-K, K * 0.5)
	var origin := centre - (ax * h.tp.x + ay * h.tp.y)
	draw_set_transform_matrix(Transform2D(ax, ay, origin))
	draw_texture(tex, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var to := func(p: Vector2) -> Vector2: return origin + ax * p.x + ay * p.y
	var b: PackedByteArray = seen.get(zid, PackedByteArray())
	var known := func(p: Vector2) -> bool:
		var i := int(p.x)
		var j := int(p.y)
		return i >= 0 and j >= 0 and i < zone.w and j < zone.h and b.size() > j * zone.w + i and b[j * zone.w + i] == 1
	for c in zone.connections:
		var p := Vector2(c["x"], c["y"])
		if known.call(p):
			var q: Vector2 = to.call(p)
			draw_rect(Rect2(q - Vector2(7, 7), Vector2(14, 14)), Color("#6a8ab8"), false, 3.0)
			U.text(self, str(c.get("name", c.get("to", ""))), q.x / U.S, q.y / U.S - 3, Color("#a8c0e0"), 0, "book", 6, true)
	for L in zone.lanterns:
		var p := Vector2(L["x"], L["y"])
		if known.call(p):
			var q: Vector2 = to.call(p)
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -8), q + Vector2(6, 0), q + Vector2(0, 8), q + Vector2(-6, 0)]), Color("#e8d8a8"))
	var hq: Vector2 = to.call(h.tp)
	draw_rect(Rect2(hq - Vector2(5, 5), Vector2(10, 10)), Color("#050407"))
	draw_rect(Rect2(hq - Vector2(3, 3), Vector2(6, 6)), U.cls_col(h.st.cls))
	U.text(self, str(zone.d.get("name", zone.id)).to_upper(), (vs.x - 40) / U.S, 12, U.TEXT, 1, "pixel", 8, true)
