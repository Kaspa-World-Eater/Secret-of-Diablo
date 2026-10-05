extends RefCounted
## Small synthesised sounds for items, made the way the web's sfx(freq, dur, type, vol, slide) makes them: one
## oscillator, an exponential slide toward freq + slide, an exponential fade. Rendered once into AudioStreamWAV.

const RATE := 22050
static var _cache := {}

static func tone(freq: float, dur: float, type: String = "square", vol: float = 0.04, slide: float = 0.0) -> AudioStreamWAV:
	var key := "%s|%s|%s|%s|%s" % [freq, dur, type, vol, slide]
	if _cache.has(key):
		return _cache[key]
	var n := int((dur + 0.02) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var f1 := maxf(30.0, freq + slide)
	var amp := clampf(vol * 6.0, 0.0, 0.9)     # the web's gains are for a quiet mix; lift them to Godot's full scale
	for i in n:
		var t := float(i) / RATE
		var k := minf(1.0, t / dur)
		var f := freq * pow(f1 / freq, k) if slide != 0.0 else freq
		ph = fmod(ph + f / RATE, 1.0)
		var s := 0.0
		match type:
			"sine":
				s = sin(ph * TAU)
			"triangle":
				s = 1.0 - 4.0 * absf(ph - 0.5)
			"sawtooth":
				s = 2.0 * ph - 1.0
			_:
				s = 1.0 if ph < 0.5 else -1.0
		var g := amp * pow(0.0001 / maxf(0.0001, amp), k) if t < dur else 0.0
		var v := int(clampf(s * g, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_cache[key] = w
	return w

## play a list of [delay_s, freq, dur, type, vol, slide] under a node
static func play(parent: Node, notes: Array) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var vol_k := 1.0
	if "sfx_vol" in Settings:
		vol_k = float(Settings.sfx_vol)
	if vol_k <= 0.0:
		return
	for n in notes:
		var p := AudioStreamPlayer.new()
		p.stream = tone(n[1], n[2], n[3], n[4], n[5] if n.size() > 5 else 0.0)
		p.volume_db = linear_to_db(vol_k)
		parent.add_child(p)
		p.finished.connect(p.queue_free)
		if float(n[0]) > 0.0:
			parent.get_tree().create_timer(float(n[0])).timeout.connect(func(): if is_instance_valid(p): p.play())
		else:
			p.play()

## the sound of a drop by its best rarity (zz_zz_study82): a dull fall, a glassy tick, two clear notes, a deep bell;
## gold falls silent
static func drop(parent: Node, best: int) -> void:
	if best >= 5:
		play(parent, [[0.0, 196, 1.4, "sine", 0.05, -4], [0.06, 392, 1.1, "sine", 0.03, -6], [0.16, 588, 0.9, "sine", 0.018]])
	elif best >= 3:
		play(parent, [[0.0, 880, 0.3, "sine", 0.035], [0.11, 1318, 0.45, "sine", 0.03]])
	elif best == 2:
		play(parent, [[0.0, 1560, 0.14, "triangle", 0.028, -220]])
	elif best == 1:
		play(parent, [[0.0, 170, 0.07, "square", 0.018, -50]])

static func pickup_item(parent: Node) -> void:
	if Sfx.me:
		Sfx.play("leather")
	else:
		play(parent, [[0.0, 700, 0.05, "square", 0.03]])

static func pickup_gold(parent: Node) -> void:
	if Sfx.me:
		Sfx.play("coins", 0.8)
	else:
		play(parent, [[0.0, 1200, 0.05, "square", 0.02]])

static func buy(parent: Node) -> void:
	if Sfx.me:
		Sfx.play("coins")
	else:
		play(parent, [[0.0, 1200, 0.06, "square", 0.02]])
