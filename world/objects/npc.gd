extends Node2D
## A townsfolk figure (Maren, Ysolde, Brannoc, Esk, the Stranger; Nell) from art/sprites/npc_<role>, never mirrored, a
## ground shadow 2 world px below the feet (the web's ztObjSprite townsfolk). No marker over the head. A hand-drawn set
## (8 views, many idle frames) faces the camera and plays its idle; an old one-frame set stands as it always did.

var role := ""
var spr: Sprite2D
var tp := Vector2.ZERO

func setup(r: String, at: Vector2, tex_kind: String = "") -> void:
	role = r
	tp = at
	position = Iso.to_screen(at)
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 11.0 + 8.0))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.38)
	add_child(sh)
	var kind := tex_kind if tex_kind != "" else "npc_" + r
	if ResourceLoader.exists("res://art/sprites/%s.json" % kind):
		var set: SpriteSet = Data.sprite_set(kind)
		var a := AnimSprite.new(set)
		a.view = "down" if set.has_view("down") else "front"
		a.face = 1
		a.play("idle")
		a.step(randf() * 3.0)       # each starts at its own point in the loop, so the camp does not breathe in step
		spr = a
	else:
		spr = Sprite2D.new()
		spr.centered = false
	add_child(spr)

func _process(dt: float) -> void:
	if spr is AnimSprite:
		(spr as AnimSprite).step(dt)

## the figure's rect in canvas coordinates (for clicks)
func click_rect() -> Rect2:
	if spr == null or spr.texture == null:
		return Rect2(global_position - Vector2(40, 180), Vector2(80, 190))
	var r := spr.get_rect()
	return Rect2(spr.global_position + r.position, r.size)
