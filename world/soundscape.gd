class_name Soundscape
extends Node
## What the pilgrim hears (checklist 12, music; zz_zz_music96.js).
## - The score: the Forge's port of the web's live-synthesised score rendered to seamless loops (audio/music/*.ogg,
##   tools/make_music.py -> pixelforge music; one cue per act and place, five bosses, the title):
##   the camp's twelve-string, the wilds' long silences and drones, the deep's sub-drones and far bells, the boss's drums.
##   Places cross-fade slowly; a waking great one cuts in fast; when it falls the land's own cue comes back.
## - The land: wind that rises with the gust you see (Game.wind), rain in the fen that swells with the shower, a low hum
##   under the ground with drips from the roof (world/weather.gd calls drip()), and, on the moor, now and then a bell
##   very far off. The land's sounds are made here once, from noise, as small loops.

const RATE := 22050
var main: Node
var mus_a: AudioStreamPlayer
var mus_b: AudioStreamPlayer
var mus_key := ""
var fade := 1.0              # 0..1, how far the cross-fade from b (old) to a (new) has gone
var fade_len := 3.0
var wind_p: AudioStreamPlayer
var rain_p: AudioStreamPlayer
var hum_p: AudioStreamPlayer
var fire_p: AudioStreamPlayer
var rec := {}                # recorded beds (audio/amb/*.ogg, CC0 and CC-BY, see CREDITS.txt): wind, rain, deep, fire
var fires: Array = []        # [tile, strength] of flames in this place (braziers, fires, lantern-stones, candles)
var fires_zone := ""
var one_p: Array = []        # one-shots (drips, bells)
var bell_t := 60.0
var boss_gone_t := 0.0
var master := 1.0            # paused, the score falls silent (zz_zz_music96.js:452: want 0, eased at tau 0.5)
var streams := {}            # instance cache (static Resources crash Godot at exit)

func _init(m: Node) -> void:
	main = m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mus_a = _player()
	mus_b = _player()
	wind_p = _player()
	rain_p = _player()
	hum_p = _player()
	fire_p = _player()
	for i in 4:
		one_p.append(_player())
	wind_p.stream = _noise_loop("wind")
	rain_p.stream = _noise_loop("rain")
	hum_p.stream = _noise_loop("hum")
	fire_p.stream = _noise_loop("fire")
	for k in ["wind", "rain", "deep", "fire"]:
		var path := "res://audio/amb/%s.ogg" % k
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamOggVorbis:
				st.loop = true
			var rp := _player()
			rp.stream = st
			rp.volume_db = -80.0
			rp.play(randf() * maxf(0.0, st.get_length() - 0.5))   # never two beds in step
			rec[k] = rp
	for p in [wind_p, rain_p, hum_p, fire_p]:
		p.volume_db = -80.0
		p.play()
	bell_t = randf_range(40.0, 90.0)

func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p

# ------------------------------------------------------------------ the score

func _music(key: String) -> AudioStream:
	if streams.has(key):
		return streams[key]
	var path := "res://audio/music/%s.ogg" % key
	if not ResourceLoader.exists(path):
		path = "res://audio/music/%s.wav" % key
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 4   # 16-bit stereo
	streams[key] = s
	return s

func _pick() -> String:
	# the browser's pick (zz_zz_music96.js): each act has its own camp, wilds, depths and boss cue; the title has its own
	var z = main.zone
	if main.get("title_open") == true:
		return _have("title", "dirge")
	if z == null:
		return ""
	var act: int = load("res://world/quests.gd").act_of(z.id)
	var boss := "boss%d" % act
	var b = main.boss_awake
	if b != null and is_instance_valid(b) and not b.dead:
		boss_gone_t = 4.0
		return _have(boss, "boss1")
	if boss_gone_t > 0.0 and mus_key.begins_with("boss"):
		return mus_key      # the drums ring out a little after it falls
	if z.id == "moor" or z.d.get("town", false):
		return _have("a%d_town" % act, "a1_town")
	if not z.d.get("outdoor", false):
		return _have("a%d_deep" % act, "a1_deep")
	return _have("a%d_wild" % act, "a1_wild")

func _have(key: String, fallback: String) -> String:
	# a cue not rendered yet (tools/make_music.py) falls back to Act I's
	return key if ResourceLoader.exists("res://audio/music/%s.ogg" % key) or ResourceLoader.exists("res://audio/music/%s.wav" % key) else fallback

func _swap(key: String) -> void:
	# the old cue moves to b and fades out; the new one comes in on a
	var tmp := mus_b
	mus_b = mus_a
	mus_a = tmp
	mus_key = key
	fade = 0.0
	fade_len = 0.8 if key == "boss1" else 3.5
	var s := _music(key)
	mus_a.stream = s
	mus_a.volume_db = -80.0
	if s:
		mus_a.play()

func _process(dt: float) -> void:
	if main == null:
		return
	boss_gone_t = maxf(0.0, boss_gone_t - dt)
	var key := _pick()
	if key != mus_key:
		_swap(key)
	fade = minf(1.0, fade + dt / fade_len)
	var mv := float(Settings.music_vol)
	var paused := main.get_tree().paused
	master += ((0.0 if paused else 1.0) - master) * (1.0 - exp(-dt / 0.5))
	var mk := mv * master
	mus_a.volume_db = linear_to_db(maxf(0.0001, mk * fade))
	mus_b.volume_db = linear_to_db(maxf(0.0001, mk * (1.0 - fade)))
	if fade >= 1.0 and mus_b.playing:
		mus_b.stop()
	_land(dt)

# ------------------------------------------------------------------ the land

func _land(dt: float) -> void:
	var z = main.zone
	var sv := float(Settings.sfx_vol)
	if z == null or main.hero == null:
		return
	var outdoor: bool = z.d.get("outdoor", false)
	var wind := Game.wind
	# wind: a floor of breath, rising with each gust (the pitch climbs a little with it)
	var wv := (0.1 + 0.55 * clampf(wind, 0.0, 1.2)) if outdoor else 0.03
	var has_w := rec.has("wind")
	wind_p.volume_db = lerpf(wind_p.volume_db, linear_to_db(maxf(0.0001, wv * sv * (0.22 if has_w else 0.5))), minf(1.0, dt * 2.0))
	wind_p.pitch_scale = 0.8 + 0.35 * clampf(wind, 0.0, 1.2)
	_bed("wind", wv * sv * 0.75, dt, 2.0, 0.93 + 0.12 * clampf(wind, 0.0, 1.2))
	# rain: with the shower
	var sky = main.get("sky")
	var rv := 0.0
	if sky != null and sky.kind == "rain":
		rv = 0.25 + 0.55 * float(sky.beat)
	rain_p.volume_db = lerpf(rain_p.volume_db, linear_to_db(maxf(0.0001, rv * sv * (0.06 if rec.has("rain") else 0.22))), minf(1.0, dt * 1.5))
	_bed("rain", rv * sv * 0.8, dt, 1.5)
	# the hum under the ground
	var hv := 0.0 if outdoor else 0.4
	hum_p.volume_db = lerpf(hum_p.volume_db, linear_to_db(maxf(0.0001, hv * sv * (0.2 if rec.has("deep") else 0.5))), minf(1.0, dt * 1.0))
	_bed("deep", hv * sv * 1.6, dt, 1.0)
	# fire: the nearest flames crackle, louder as you come to them
	if fires_zone != z.id:
		fires_zone = z.id
		fires.clear()
		for l in z.d.get("lights", []):
			if l is Dictionary and l.get("type", "") == "fire":
				var k: float = {"brazier": 1.0, "fire": 1.0, "bonfire": 1.2, "lantern": 0.45, "candles": 0.25, "torch": 0.6}.get(str(l.get("kind", "")), 0.5)
				fires.append([Vector2(float(l["x"]), float(l["y"])), k])
	var fv := 0.0
	var hp: Vector2 = main.hero.tp
	for f in fires:
		var dd: float = hp.distance_to(f[0])
		if dd < 7.0:
			fv = maxf(fv, float(f[1]) * pow(1.0 - dd / 7.0, 1.6))
	fire_p.volume_db = lerpf(fire_p.volume_db, linear_to_db(maxf(0.0001, fv * sv * (0.3 if rec.has("fire") else 0.55))), minf(1.0, dt * 3.0))
	_bed("fire", fv * sv * 0.75, dt, 3.0)
	# a bell very far off, on the open moor
	if outdoor and sky != null and sky.kind == "ash":
		bell_t -= dt
		if bell_t <= 0.0:
			bell_t = randf_range(70.0, 150.0)
			Sfx.play("bell_far", 0.8, randf_range(0.5, 0.58))   # a real bell, pitched down: very far and very large

## a recorded bed eased toward a loudness (and a pitch)
func _bed(k: String, v: float, dt: float, rate: float, pitch: float = 1.0) -> void:
	if not rec.has(k):
		return
	var p: AudioStreamPlayer = rec[k]
	p.volume_db = lerpf(p.volume_db, linear_to_db(maxf(0.0001, v)), minf(1.0, dt * rate))
	p.pitch_scale = lerpf(p.pitch_scale, pitch, minf(1.0, dt))

## a drop from the roof reaching the floor (world/weather.gd)
func drip() -> void:
	_one(_drip_s(), -22.0 + linear_to_db(maxf(0.0001, float(Settings.sfx_vol))), randf_range(0.8, 1.3))

func _one(s: AudioStream, db: float, pitch: float) -> void:
	for p in one_p:
		if not p.playing:
			if AudioServer.get_bus_index("World") >= 0:
				p.bus = "World"
			p.stream = s
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return

# ------------------------------------------------------------------ sounds made from noise

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	# no offset, and never clipped: each sound is levelled to the same peak, the players set the loudness
	var mean := 0.0
	for v in samples:
		mean += v
	mean /= maxf(1.0, float(samples.size()))
	var pk := 0.0
	for i in samples.size():
		samples[i] -= mean
		pk = maxf(pk, absf(samples[i]))
	if pk > 0.0001:
		for i in samples.size():
			samples[i] *= 0.8 / pk
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

## 6 s of filtered noise, its tail folded into its head so it loops without a seam
func _noise_loop(kind: String) -> AudioStreamWAV:
	var n := RATE * 6
	var xf := RATE / 2
	var raw := PackedFloat32Array()
	raw.resize(n + xf)
	var lp1 := 0.0
	var lp2 := 0.0
	var hp := 0.0
	var prev := 0.0
	var br := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for i in n + xf:
		var w := rng.randf() * 2.0 - 1.0
		var v := 0.0
		match kind:
			"wind":
				# a soft band of noise that breathes (two slow swells)
				lp1 += (w - lp1) * 0.06
				lp2 += (lp1 - lp2) * 0.06
				hp = lp2 - br
				br += (lp2 - br) * 0.004
				var t := float(i) / RATE
				v = hp * 5.0 * (0.7 + 0.3 * sin(t * TAU / 6.0) * sin(t * TAU / 3.0 + 1.0))
			"rain":
				# a hiss (high noise) and many small ticks of drops
				hp = w - prev
				prev = w
				lp1 += (hp - lp1) * 0.3
				lp2 += (lp1 - lp2) * 0.45
				v = lp2 * 0.4
				if rng.randf() < 0.0025:
					br = rng.randf_range(0.2, 0.6)
				v += br * (rng.randf() * 2.0 - 1.0)
				br *= 0.93
			"fire":
				# a low roar of burning air and the snap and tick of the wood
				lp1 += (w - lp1) * 0.03
				v = lp1 * 1.6
				if rng.randf() < 0.0012:
					br = rng.randf_range(0.3, 0.9)
				elif rng.randf() < 0.006:
					br = maxf(br, rng.randf_range(0.05, 0.2))
				hp = (w - prev) * br
				prev = w
				v += hp * 0.9
				br *= 0.9
			_:
				# the hum: brown noise far down, and a faint low tone under it
				br += (w * 0.02)
				br *= 0.998
				lp1 += (br - lp1) * 0.02
				v = lp1 * 2.2 + sin(float(i) / RATE * TAU * 41.0) * 0.03
		raw[i] = v
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in xf:
		var f := float(i) / float(xf)
		out[i] = raw[i] * f + raw[n + i] * (1.0 - f)
	return _wav(out, true)

func _drip_s() -> AudioStreamWAV:
	if streams.has("_drip"):
		return streams["_drip"]
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1500.0 * pow(0.55, t / 0.25) + 700.0
		s[i] = sin(TAU * f * t) * exp(-t * 26.0) * 0.5
	streams["_drip"] = _wav(s, false)
	return streams["_drip"]

## a bronze bell: inharmonic partials, a long fade, dulled by distance
func _bell() -> AudioStreamWAV:
	if streams.has("_bell"):
		return streams["_bell"]
	var n := RATE * 6
	var s := PackedFloat32Array()
	s.resize(n)
	var f0 := 146.8
	var parts := [[0.5, 0.5, 0.35], [1.0, 1.0, 0.5], [1.19, 0.6, 0.7], [1.5, 0.4, 0.9], [2.0, 0.3, 1.2], [2.74, 0.15, 1.6]]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in parts:
			v += sin(TAU * f0 * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
		var a := minf(1.0, t / 0.02)
		lp += (v * a - lp) * 0.25        # far off: the high edge is gone
		s[i] = lp * 0.3
	streams["_bell"] = _wav(s, false)
	return streams["_bell"]
