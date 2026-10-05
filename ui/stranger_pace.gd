extends RefCounted
## ui/stranger_pace.gd: how the Stranger moves (zz_art_reading.js:36-79). He mostly sits still: a slow idle drifts back
## and forth through the rest pose (hand at the chin, hood and fire breathing a little), at 5-9 frames a second, now and
## then pausing; only at random does he lower the hand to the table or reach out across it. The gesture never runs on a
## fixed beat, so the animation does not read as a loop. step(dt) returns the frame (0..120) of his 121.

const N := 121
var rest: Array = []
var ri := 0
var dir := 1
var hold := 0.0
var nxt := 6.0
var acc := 0.0
var g := {}                  # the gesture under way: p, to, fps, dir, back, hold

func _init() -> void:
	for i in range(99, 121):
		rest.append(i)
	for i in 4:
		rest.append(i)
	nxt = 6.0 + randf() * 8.0

func _idle(dt: float) -> void:
	if hold > 0.0:
		hold -= dt
		return
	acc += dt * (5.0 + randf() * 4.0)
	while acc >= 1.0:
		acc -= 1.0
		ri += dir
		if ri <= 0 or ri >= rest.size() - 1:
			ri = clampi(ri, 0, rest.size() - 1)
			dir = -dir
		if randf() < 0.04:   # a pause, then drift back
			dir = -dir
			hold = 0.3 + randf() * 1.2
			break

func step(dt: float) -> int:
	dt = minf(dt, 0.1)
	if not g.is_empty():
		g["p"] += dt * g["fps"] * g["dir"]
		if g["dir"] > 0 and g["p"] >= g["to"]:
			if g["back"]:
				g["dir"] = -1
				g["p"] = g["to"]
				g["hold"] = 0.4 + randf() * 1.4
			else:
				g = {}
				ri = 0
				dir = 1
		if not g.is_empty() and g["hold"] > 0.0 and g["dir"] < 0:
			g["hold"] -= dt
			g["p"] = g["to"]
		if not g.is_empty() and g["dir"] < 0 and g["p"] <= 3.0:
			g = {}
			ri = rest.size() - 1
			dir = -1
		if not g.is_empty():
			return clampi(int(round(g["p"])), 0, N - 1)
	else:
		nxt -= dt
		if nxt <= 0.0 and rest[ri] == 3:   # only leave the rest pose from its edge, so nothing jumps
			if randf() < 0.45:
				g = {"p": 3.0, "to": 98.0, "fps": 18.0 + randf() * 6.0, "dir": 1, "back": false, "hold": 0.0}   # the full reach
			else:
				g = {"p": 3.0, "to": float(22 + randi() % 30), "fps": 12.0 + randf() * 6.0, "dir": 1, "back": true, "hold": 0.0}   # a hand lowered, raised again
			nxt = 9.0 + randf() * 16.0
		else:
			if nxt <= 0.0:   # due: drift toward the edge frame
				dir = 1
				hold = 0.0
			_idle(dt)
	return int(rest[ri]) % N
