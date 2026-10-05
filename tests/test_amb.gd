extends SceneTree
## writes the soundscape's noise loops to /tmp/gd/aud for listening
func _initialize() -> void:
	var s = load("res://world/soundscape.gd").new(null)
	for k in ["wind", "rain", "hum", "fire"]:
		var w: AudioStreamWAV = s._noise_loop(k)
		w.save_to_wav("/tmp/gd/aud/amb_" + k + ".wav")
		var mx := 0.0
		for i in range(0, w.data.size(), 2):
			mx = maxf(mx, absf(w.data.decode_s16(i)))
		print(k, " peak ", mx / 32767.0)
	s._bell().save_to_wav("/tmp/gd/aud/amb_bell.wav")
	s.free()
	quit()
