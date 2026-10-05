extends Node2D
## Rising text for damage numbers and notifications.

var text := ""
var color := Color.WHITE
var size := 13
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= 28.0 * delta
	if _t > 0.9:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var a = 1.0 - max(0.0, (_t - 0.5) / 0.4)
	draw_string_outline(f, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, a))
	draw_string(f, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))
