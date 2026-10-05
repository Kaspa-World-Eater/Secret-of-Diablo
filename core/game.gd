extends Node
## Autoload "Game": the run's state that outlives a zone (hero, time of day, which zones are generated).

var cls := "animancer"
var seed := 0
var day_len := 600.0
var clock := 0.12 * 600.0
var zone_seeds := {}       # zone id -> exported seed chosen for this run (maps are random per new game)
var visited := {}
var skip_title := false      # a new pilgrim chosen on the title reloads the scene straight into play
var force_new := false
var slot := ""                # "" the pilgrims; "_trial" the Trial of Thirty (the web's test character), kept apart
var trial_new := false         # a new Trial pilgrim: level 30 with every point to spend
var read_new := false         # a new pilgrim from an order's page: the Reading comes first
var load_cls := ""           # the order whose pilgrim to wake next (the title's order page); "" = the latest

func new_run() -> void:
	seed = randi()
	zone_seeds.clear()
	sky_force = ""
	clock = 0.12 * day_len

func seed_for(zid: String) -> int:
	if not zone_seeds.has(zid):
		var seeds: Array = Data.zone_seeds(zid)
		zone_seeds[zid] = int(seeds[(hash(str(seed) + zid) & 0x7fffffff) % seeds.size()])
	return zone_seeds[zid]

## the Empty Hand can turn the sky: a forced noon or night holds the hour (and so the light and the creatures)
var sky_force := ""
var sky_t := 0.0

func phase() -> float:
	if sky_force == "noon":
		return 0.3
	if sky_force == "night":
		return 0.78
	return fmod(clock / day_len, 1.0)

## the hour: day to 0.55, dusk to 0.66, night to 0.9, dawn to 1.0 (a 600 s day)
func hour_name() -> String:
	var p := phase()
	if p < 0.55:
		return "day"
	if p < 0.66:
		return "dusk"
	if p < 0.9:
		return "night"
	return "dawn"

func hour_speed() -> float:
	return {"dusk": 1.12, "night": 1.05, "dawn": 0.95}.get(hour_name(), 1.0)

func day_k() -> float:
	var p := phase()
	if p < 0.55:
		return 1.0
	if p < 0.66:
		return 1.0 - (p - 0.55) / 0.11
	if p < 0.9:
		return 0.0
	return (p - 0.9) / 0.1

## hit-stop: freeze the frame for a few hundredths of a second on heavy blows (checklist section 1)
var _stop := 0.0
## screen shake (checklist 1): heavy blows, finishers and slams; Settings.screen_shake turns it off. main.gd reads shake_amt.
var shake_amt := 0.0
var wind := 0.5              # the one shared gust (world/atmos.gd): mist, leaves, dust, grass and flames answer to it
func shake(px: float) -> void:
	if Settings.screen_shake:
		shake_amt = maxf(shake_amt, px)

func hitstop(secs: float) -> void:
	_stop = maxf(_stop, secs)
	Engine.time_scale = 0.05

func _process(dt: float) -> void:
	if _stop > 0.0:
		_stop -= dt / maxf(0.05, Engine.time_scale)
		if _stop <= 0.0:
			Engine.time_scale = 1.0
	clock += dt
	shake_amt = move_toward(shake_amt, 0.0, dt * 60.0)
