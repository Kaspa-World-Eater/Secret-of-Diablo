extends Control
## ui/sky_dial.gd: the clock (zz_polish.js:26-45): a small decorative dial in the top right, no words. The upper half is
## the sky by the hour, a horizon line, eight tick dots; the sun crosses through the day (0 to 0.55 of the cycle), the
## moon through the night. A gold rim at dawn. Outdoors only; hidden while a panel is open (zz_fix_ui53.js:27-33). Its
## tooltip names the hour and its line. Painted at the web's logical scale (1 px = 4 here), nearest.
## The web's dusk is red (sky #3a1a16, rim #b0402a); by the user's rule there is no red, so dusk is a bruised grey.

const PX := 4
const R := 10
const N := 2 * R + 3
var hud
var img: Image
var tex: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	img = Image.create(N, N, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(img)
	size = Vector2(N, N) * PX
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_dt: float) -> void:
	var z = hud.zone if hud else null
	var on: bool = z != null and is_instance_valid(z) and z.d.get("outdoor", false) and hud.hero != null \
		and not hud.any_panel() and not hud.pause.visible
	visible = on
	if not on:
		return
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - (22 + R + 1) * PX, (16 - R - 1) * PX)
	_paint()
	queue_redraw()

func _px(x: float, y: float, c: Color) -> void:
	var ix := int(round(x))
	var iy := int(round(y))
	if ix >= 0 and iy >= 0 and ix < N and iy < N:
		img.set_pixel(ix, iy, c)

func _disc(cx: float, cy: float, r: float, c: Color, half := 0) -> void:
	# half: 0 whole, -1 the upper half, 1 the lower half
	for y in N:
		for x in N:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r * r and (half == 0 or (half < 0 and dy <= 0.0) or (half > 0 and dy > 0.0)):
				img.set_pixel(x, y, c)

func _paint() -> void:
	img.fill(Color(0, 0, 0, 0))
	var c := N / 2.0
	var p := Game.phase()
	var h := Game.hour_name()
	_disc(c, c, R + 1, Color(10 / 255.0, 9 / 255.0, 13 / 255.0, 0.75))
	var sky: Color = {"night": Color("#141a2a"), "dusk": Color("#2a2230"), "dawn": Color("#3a2c18")}.get(h, Color("#2a3040"))
	_disc(c, c, R, sky, -1)
	_disc(c, c, R, Color("#17141c"), 1)
	# the rim
	var rim := Color("#c9a24a") if h == "dawn" else Color("#4a4458")
	for i in 96:
		var a := i / 96.0 * TAU
		_px(c - 0.5 + cos(a) * R, c - 0.5 + sin(a) * R, rim)
	# the horizon
	for x in range(int(c - R), int(c + R) + 1):
		_px(x, c - 0.5, Color("#3a3446"))
	for i in 8:
		var a := i / 8.0 * TAU
		_px(c - 0.5 + cos(a) * (R - 2), c - 0.5 + sin(a) * (R - 2), Color("#5a5468"))
	# the sun by day, the moon by night
	var day := p < 0.55
	var f := p / 0.55 if day else (p - 0.55) / 0.45
	var t := PI + PI * f
	var bx := c + cos(t) * (R - 3)
	var by := c + sin(t) * (R - 3)
	if day:
		_disc(bx, by, 2.2, Color("#f0a060") if h == "dusk" else Color("#f0d080"))
		_px(bx - 1.5, by - 1.5, Color("#fff2c0"))
	else:
		_disc(bx, by, 2.0, Color("#d8e0f0"))
		_disc(bx + 1.0, by - 0.7, 1.5, Color("#17141c"))
	tex.update(img)

func _draw() -> void:
	draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(N, N) * PX), false)

func tip() -> Array:
	var h := Game.hour_name()
	var ht: Dictionary = Data.table("world").get("hour_text", {})
	var line: String = ht[h][1] if ht.has(h) else ""
	return [[h.capitalize(), Color("#e8e2d0")], [line, Color("#a39d8c")]]
