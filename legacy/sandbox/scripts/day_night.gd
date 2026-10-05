extends Node
## Day/night cycle. Drives the world's CanvasModulate (darkness) and exposes
## daylight 0..1 for gameplay (Game.daylight()).

const CYCLE_SECONDS := 1200.0  # one full day = 20 minutes
const DAY_COLOR := Color(1, 1, 1)
const NIGHT_COLOR := Color(0.11, 0.12, 0.24)
const DUSK_TINT := Color(1.0, 0.78, 0.6)

var time_of_day := 0.3  # 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
var day := 1
var daylight := 1.0
var modulate: CanvasModulate


func _ready() -> void:
	modulate = CanvasModulate.new()
	add_child(modulate)
	_update()


func _process(delta: float) -> void:
	time_of_day += delta / CYCLE_SECONDS
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	_update()


func advance(fraction: float) -> void:
	time_of_day = fposmod(time_of_day + fraction, 1.0)
	_update()


func sun() -> float:
	return sin((time_of_day - 0.25) * TAU)  # -1 midnight, 0 dawn/dusk, 1 noon


func _update() -> void:
	var s := sun()
	daylight = smoothstep(-0.22, 0.22, s)
	var c = NIGHT_COLOR.lerp(DAY_COLOR, daylight)
	var dusk: float = clamp(1.0 - abs(s) / 0.3, 0.0, 1.0)
	c = c.lerp(c * DUSK_TINT, dusk * 0.8)
	modulate.color = c


func is_night() -> bool:
	return daylight < 0.4


func clock_text() -> String:
	var hours := time_of_day * 24.0
	var h := int(hours)
	var m := int((hours - h) * 60.0)
	var phase := "Night"
	var s := sun()
	if abs(s) < 0.2:
		phase = "Dawn" if time_of_day < 0.5 else "Dusk"
	elif s > 0.0:
		phase = "Day"
	return "Day %d  %02d:%02d  %s" % [day, h, m, phase]
