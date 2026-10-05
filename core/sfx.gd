class_name Sfx
extends Node
## The body's sounds: feet on ash, stone, leaves and water; the swing, the blow landing, the heavy blow, a guard
## broken, a body falling, the roll, the draught, being struck. Made here from noise and a few tones, once, as short
## sounds with small random changes of pitch so no two steps are alike. Sfx.play("hit") from anywhere.
## (The web's sfx() beeps are placeholders; these are the Godot build's own.)
## Where a real recording serves better, it is used: footsteps, blows, cloth, glass, iron, coins, leather, books and a
## bell come from Kenney's CC0 "Impact Sounds" and "RPG Audio" (Godot Asset Library 1841 and 1840; audio/sfx/,
## LICENSE_kenney.txt). Everything plays through the "World" bus, whose reverb opens up under the ground.

const RATE := 22050
static var me: Sfx              # the one live kit (a Node, not a Resource; cleared on exit)
var pool: Array = []
var bank := {}                  # name -> Array[AudioStreamWAV] (a few takes each)
var last := {}                  # name -> time last played (so a storm of hits doesn't become a roar)

func _ready() -> void:
	me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus()
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "World"
		add_child(p)
		pool.append(p)

## the World bus: a reverb whose wet grows under the ground (set_room)
func _bus() -> void:
	if AudioServer.get_bus_index("World") >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "World")
	AudioServer.set_bus_send(i, "Master")
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.35
	rv.damping = 0.6
	rv.wet = 0.06
	rv.dry = 1.0
	rv.spread = 0.8
	rv.predelay_msec = 30.0
	AudioServer.add_bus_effect(i, rv)

## how the place answers: open ground barely echoes; stone halls and crypts ring
static func set_room(indoor: bool) -> void:
	var i := AudioServer.get_bus_index("World")
	if i < 0:
		return
	var rv := AudioServer.get_bus_effect(i, 0) as AudioEffectReverb
	if rv:
		rv.room_size = 0.72 if indoor else 0.3
		rv.wet = 0.24 if indoor else 0.05
		rv.damping = 0.45 if indoor else 0.7
		rv.predelay_msec = 45.0 if indoor else 20.0

func _exit_tree() -> void:
	if me == self:
		me = null

static func play(name: String, vol: float = 1.0, pitch: float = 1.0) -> void:
	if me != null and is_instance_valid(me):
		me._play(name, vol, pitch)

func _play(name: String, vol: float, pitch: float) -> void:
	if LAYERS.has(name):
		for l in LAYERS[name]:
			if float(l[1]) <= 0.0:
				_play(l[0], vol, pitch)
			else:
				var nm: String = l[0]
				get_tree().create_timer(float(l[1])).timeout.connect(func(): _play(nm, vol, pitch))
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -9.0)) < 0.035:
		return
	last[name] = now
	var takes: Array = _takes(name)
	if takes.is_empty():
		return
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		return
	p.stream = takes[randi() % takes.size()]
	p.volume_db = linear_to_db(maxf(0.0001, vol * float(Settings.sfx_vol))) + float(SGAIN.get(name, GAIN.get(name, 0.0)))
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()

## recordings: a name's takes (files in audio/sfx/, without .ogg), and their own level
const SAMPLES := {
	"step_stone": ["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003", "footstep_concrete_004"],
	"step_ash": ["footstep_snow_000", "footstep_snow_001", "footstep_snow_002", "footstep_snow_003", "footstep_snow_004"],
	"step_leaf": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003", "footstep_grass_004"],
	"hit": ["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002", "impactPunch_medium_003", "impactPunch_medium_004"],
	"heavy": ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002", "impactPunch_heavy_003", "impactPunch_heavy_004"],
	"hurt": ["impactSoft_heavy_000", "impactSoft_heavy_001", "impactSoft_heavy_002", "impactSoft_heavy_003", "impactSoft_heavy_004"],
	"fall_body": ["impactSoft_medium_000", "impactSoft_medium_001", "impactSoft_medium_002", "impactSoft_medium_003", "impactSoft_medium_004"],
	"break_iron": ["impactMetal_heavy_000", "impactMetal_heavy_001", "impactMetal_heavy_002", "impactMetal_heavy_003", "impactMetal_heavy_004"],
	"glass": ["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002", "impactGlass_light_003", "impactGlass_light_004"],
	"bell_far": ["impactBell_heavy_000", "impactBell_heavy_001", "impactBell_heavy_002"],
	"lid": ["impactWood_medium_000", "impactWood_medium_001", "impactWood_medium_002", "impactWood_medium_003", "impactWood_medium_004"],
	"roll": ["cloth1", "cloth2", "cloth3", "cloth4"],
	"hinge": ["creak1", "creak2", "creak3"],
	"coins": ["handleCoins", "handleCoins2"],
	"leather": ["handleSmallLeather", "handleSmallLeather2", "dropLeather"],
	"page_open": ["bookOpen", "bookFlip1"],
	"page_close": ["bookClose", "bookFlip2", "bookFlip3"],
	"draw_blade": ["drawKnife1", "drawKnife2", "drawKnife3"],
	"latch": ["metalLatch"],
}
## sounds made of others, [name, delay s]
const LAYERS := {
	"chest": [["hinge", 0.0], ["lid", 0.34]],
	"break": [["break_iron", 0.0], ["break_ring", 0.0]],
	"fall": [["fall_body", 0.0], ["fall_knocks", 0.12]],
	"cast_mirror": [["glass", 0.0], ["cast_mirror_ring", 0.0]],
}
const SGAIN := {"step_stone": -22.0, "step_ash": -21.0, "step_leaf": -16.0, "hit": -11.0, "heavy": -8.0, "hurt": -10.0,
	"fall_body": -12.0, "break_iron": -12.0, "glass": -15.0, "bell_far": -20.0, "lid": -12.0, "roll": -12.0, "hinge": -8.0,
	"coins": -8.0, "leather": -14.0, "page_open": -4.0, "page_close": -6.0, "draw_blade": 8.0, "latch": -10.0}

const GAIN := {"break_ring": -15.0, "fall_knocks": -16.0, "cast_mirror_ring": -20.0, "step_ash": -17.0, "step_stone": -18.0, "step_leaf": -18.0, "step_wet": -14.0, "swing": -13.0, "hit": -7.0,
	"heavy": -5.0, "break": -9.0, "hurt": -8.0, "fall": -10.0, "roll": -12.0, "drink": -10.0, "m_wind": -12.0, "cast_mirror": -14.0, "cast_soul": -12.0, "cast_thread": -12.0, "chest": -9.0, "kindle": -9.0, "shrine": -10.0, "passage": -12.0}

func _takes(name: String) -> Array:
	if bank.has(name):
		return bank[name]
	var out: Array = []
	if SAMPLES.has(name):
		for f in SAMPLES[name]:
			var path := "res://audio/sfx/%s.ogg" % f
			if ResourceLoader.exists(path):
				out.append(load(path))
		if not out.is_empty():
			bank[name] = out
			return out
	for k in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name) + k * 977
		var s: PackedFloat32Array = _make(name, rng)
		if s.is_empty():
			break
		out.append(_wav(s))
	bank[name] = out
	return out

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var pk := 0.0
	for v in samples:
		pk = maxf(pk, absf(v))
	if pk > 0.9:
		for i in samples.size():
			samples[i] *= 0.9 / pk
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

## filtered noise with an envelope: lo/hi are one-pole coefficients (0..1, higher = brighter)
func _noise(rng: RandomNumberGenerator, dur: float, att: float, decay: float, lo: float, hi: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf() * 2.0 - 1.0
		a += (w - a) * hi
		b += (a - b) * lo
		var e := minf(1.0, t / maxf(0.0005, att)) * exp(-maxf(0.0, t - att) * decay)
		s[i] = (a - b) * e * amp
	return s

## a falling tone (a thud's body)
func _thud(dur: float, f0: float, f1: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t * 18.0)
		ph += f / RATE
		s[i] = sin(ph * TAU) * exp(-t * decay) * minf(1.0, t / 0.002) * amp
	return s

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, off: int = 0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size() + off)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in a.size():
		s[i] = a[i]
	for i in b.size():
		s[i + off] += b[i]
	return s

func _make(name: String, rng: RandomNumberGenerator) -> PackedFloat32Array:
	match name:
		"step_ash":    # a soft crunch in ash and dry earth
			return _mix(_noise(rng, 0.09, 0.004, 45.0, 0.25, 0.55, 1.2), _noise(rng, 0.05, 0.002, 70.0, 0.6, 0.9, 0.4), int(RATE * 0.02))
		"step_stone":  # a hard heel on flags: a click and a short knock
			return _mix(_noise(rng, 0.05, 0.001, 90.0, 0.5, 0.95, 0.9), _thud(0.07, 260.0, 140.0, 60.0, 0.35))
		"step_leaf":   # leaves and grass underfoot: a rustle
			return _noise(rng, 0.14, 0.02, 28.0, 0.5, 0.95, 0.9)
		"step_wet":    # a splash: a wash of noise and a small bubble
			var sp := _noise(rng, 0.2, 0.01, 18.0, 0.12, 0.5, 1.1)
			var bub := _thud(0.08, 700.0 + rng.randf() * 200.0, 380.0, 40.0, 0.25)
			return _mix(sp, bub, int(RATE * 0.03))
		"swing":       # air parted: a band of noise that rises and falls
			var n := int(0.24 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var a := 0.0
			var b := 0.0
			for i in n:
				var t := float(i) / RATE
				var cut := 0.08 + 0.35 * sin(PI * t / 0.24)
				var w := rng.randf() * 2.0 - 1.0
				a += (w - a) * cut
				b += (a - b) * 0.06
				s[i] = (a - b) * pow(sin(PI * t / 0.24), 2.0) * 1.1
			return s
		"hit":         # a blow landing in a body: a thud and a snap
			return _mix(_thud(0.16, 150.0, 60.0, 22.0, 0.9), _noise(rng, 0.05, 0.001, 80.0, 0.3, 0.8, 0.9))
		"heavy":       # the overhead, the charged blow: deeper, longer, with a crunch
			var body := _thud(0.32, 110.0, 42.0, 11.0, 1.0)
			var cr := _noise(rng, 0.12, 0.002, 30.0, 0.2, 0.6, 1.1)
			return _mix(body, cr, int(RATE * 0.005))
		"break_ring", "break":       # a guard broken: an iron clang, short
			var n := int(0.5 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var f0 := 330.0 + rng.randf() * 60.0
			for i in n:
				var t := float(i) / RATE
				var v := 0.0
				for r in [1.0, 2.41, 3.77, 5.2]:
					v += sin(TAU * f0 * r * t) / (r * 1.3)
				s[i] = v * exp(-t * 9.0) * 0.35
			return _mix(s, _noise(rng, 0.04, 0.001, 90.0, 0.5, 0.95, 0.5))
		"hurt":        # the pilgrim struck: a dull blow through cloth
			return _mix(_thud(0.2, 120.0, 55.0, 18.0, 0.9), _noise(rng, 0.09, 0.003, 40.0, 0.15, 0.45, 0.8))
		"fall_knocks": # the small knocks of a body settling
			var s := PackedFloat32Array()
			for k in 3:
				s = _mix(s, _thud(0.06, 300.0 + rng.randf() * 300.0, 180.0, 60.0, 0.18), int(RATE * (0.02 + 0.07 * k + rng.randf() * 0.04)))
			return s
		"fall":        # a body going down: a heavy thud, then a few small knocks settling
			var s := _thud(0.35, 90.0, 38.0, 10.0, 0.9)
			for k in 3:
				s = _mix(s, _thud(0.06, 300.0 + rng.randf() * 300.0, 180.0, 60.0, 0.18), int(RATE * (0.14 + 0.07 * k + rng.randf() * 0.04)))
			return s
		"roll":        # cloth and ground: a longer rustle that swells
			return _noise(rng, 0.34, 0.12, 9.0, 0.3, 0.7, 0.9)
		"m_wind":      # a creature drawing back: a low scrape and creak rising
			var n := int(0.4 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var a := 0.0
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				var w := rng.randf() * 2.0 - 1.0
				a += (w - a) * 0.05
				ph += (60.0 + 50.0 * t / 0.4) / RATE
				var saw := fmod(ph, 1.0) * 2.0 - 1.0
				var e := minf(1.0, t / 0.12) * (1.0 - t / 0.4)
				s[i] = (a * 2.2 + saw * 0.12 * (0.5 + 0.5 * sin(t * 90.0))) * e
			return s
		"cast_mirror_ring", "cast_mirror": # glass: a bright, uneven ring and a tick like a crack
			var n := int(0.7 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var f0 := 900.0 + rng.randf() * 180.0
			for i in n:
				var t := float(i) / RATE
				var v := 0.0
				for r in [1.0, 1.51, 2.37, 3.11]:
					v += sin(TAU * f0 * r * t) / (r * r)
				s[i] = v * exp(-t * 7.0) * 0.28
			return _mix(s, _noise(rng, 0.03, 0.001, 120.0, 0.7, 0.98, 0.5))
		"cast_soul":   # a breath let out: air, and a low hum under it
			var s := _noise(rng, 0.45, 0.12, 7.0, 0.08, 0.3, 1.0)
			return _mix(s, _thud(0.45, 140.0, 110.0, 6.0, 0.18))
		"cast_thread": # a taut thread plucked: a bright pluck bending down
			var n := int(0.4 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var per := int(RATE / (300.0 + rng.randf() * 80.0))
			var buf := PackedFloat32Array()
			buf.resize(per)
			for i in per:
				buf[i] = rng.randf() * 2.0 - 1.0
			for i in n:
				var j := i % per
				var nx := (j + 1) % per
				var v := buf[j]
				buf[j] = (buf[j] + buf[nx]) * 0.497
				s[i] = v * 0.4 * minf(1.0, float(i) / 40.0)
			return s
		"chest":       # an old lid: a creak of hinges, then the lid falls back on wood
			var n := int(0.45 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				if t < 0.3:
					ph += (180.0 + 260.0 * t / 0.3 + sin(t * 60.0) * 30.0) / RATE
					var pulse := 1.0 if fmod(ph, 1.0) < 0.12 else 0.0   # the rasp of a dry hinge
					s[i] = pulse * 0.3 * sin(PI * t / 0.3)
			return _mix(_mix(s, _noise(rng, 0.3, 0.05, 6.0, 0.2, 0.6, 0.15)), _thud(0.18, 140.0, 70.0, 22.0, 0.8), int(RATE * 0.3))
		"kindle":      # a lantern given its soul: a soft breath of flame catching, and a low bell under it
			var fl := _noise(rng, 0.8, 0.15, 4.0, 0.06, 0.25, 1.0)
			var n := int(1.6 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				s[i] = (sin(TAU * 196.0 * t) + 0.5 * sin(TAU * 293.7 * t) + 0.25 * sin(TAU * 392.0 * t * 1.003)) * exp(-t * 2.2) * minf(1.0, t / 0.05) * 0.22
			return _mix(fl, s, int(RATE * 0.08))
		"shrine":      # a waystone or shrine answering: a low stone hum with a pale ring over it
			var n := int(1.4 * RATE)
			var s := PackedFloat32Array()
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				var e := minf(1.0, t / 0.25) * exp(-maxf(0.0, t - 0.25) * 2.6)
				s[i] = (sin(TAU * 98.0 * t) * 0.5 + sin(TAU * 147.0 * t) * 0.3 + sin(TAU * 587.0 * t) * 0.12 * exp(-t * 3.0)) * e * 0.5
			return s
		"passage":     # going through: stone grinding, a step into another air
			var gr := _noise(rng, 0.7, 0.2, 3.5, 0.05, 0.18, 1.3)
			return _mix(gr, _thud(0.3, 70.0, 45.0, 8.0, 0.35), int(RATE * 0.05))
		"drink":       # the draught: two swallows
			var g1 := _thud(0.09, 180.0, 260.0, 30.0, 0.5)
			return _mix(g1, _thud(0.09, 170.0, 250.0, 30.0, 0.45), int(RATE * 0.16))
	return PackedFloat32Array()
