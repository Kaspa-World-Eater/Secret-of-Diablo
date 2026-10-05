extends PointLight2D
## flame light: a slow breath with small quick flickers (never strobing)
var base_e := 1.0
var base_s := 1.0
var t := 0.0
func _ready() -> void:
	base_e = energy
	base_s = texture_scale
	t = randf() * 10.0
func _process(dt: float) -> void:
	t += dt
	var f := sin(t * 1.3) * 0.06 + sin(t * 7.1) * 0.03 + sin(t * 12.7 + 1.0) * 0.02
	energy = base_e * (1.0 + f)
	texture_scale = base_s * (1.0 + f * 0.3)
