class_name ScatterLayer
extends Node2D
## Ground litter (leaves, twigs, stones, bone chips, black glass...): drawn flat, in one batch, at grain 2.
var items: Array = []
var texs := {}
var sway := {}               # sprite id -> [lean left, upright, lean right]: grass and reeds answer the wind
var t := 0.0
var redraw_t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(dt: float) -> void:
	if sway.is_empty():
		set_process(false)
		return
	t += dt
	redraw_t -= dt
	if redraw_t <= 0.0:
		redraw_t = 0.12
		queue_redraw()

func _draw() -> void:
	var w: float = Game.wind
	for it in items:
		var tex: Texture2D = texs.get(it[2])
		if not sway.is_empty() and sway.has(it[2]):
			# each blade leans on its own beat, harder in a gust; the web's three frames
			var s0 := sin(t * (1.3 + w) + float(it[0]) * 0.7 + float(it[1]) * 0.3) * (0.4 + w)
			var fi := 1 if absf(s0) < 0.45 else (2 if s0 > 0.0 else 0)
			tex = sway[it[2]][fi]
		if tex == null:
			continue
		var s := Iso.to_screen(Vector2(it[0], it[1]))
		var sz := Vector2(tex.get_width(), tex.get_height()) * (Iso.WPX / 2.0)
		var tl := s + Vector2(-sz.x * 0.5, -sz.y + Iso.WPX)
		var flip: bool = it.size() > 3 and bool(it[3])
		if flip:
			draw_set_transform(Vector2(tl.x + sz.x, tl.y), 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(tex, Rect2(tl, sz), false)
