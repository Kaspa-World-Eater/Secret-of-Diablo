extends SceneTree
## Sound test: renders each synthesised sound to /tmp/gd/aud/*.wav and prints its length and peak.
##   godot --headless --path . -s tests/test_sfx.gd
func _initialize() -> void:
	var k = load("res://core/sfx.gd").new()
	for n in ["step_ash","step_stone","step_leaf","step_wet","swing","hit","heavy","break","hurt","fall","roll","drink","m_wind","cast_mirror","cast_soul","cast_thread","chest","kindle","shrine","passage","hinge","lid","coins","glass","bell_far","page_open","roll","hit","fall","break"]:
		var t: Array = k._takes(n)
		var mx := 0.0
		if t.is_empty():
			print(n, " none")
			continue
		if not (t[0] is AudioStreamWAV):
			print(n, " recorded takes ", t.size(), " ", t[0].get_length(), " s")
			continue
		var w: AudioStreamWAV = t[0]
		var d := w.data
		for i in range(0, d.size(), 2):
			mx = maxf(mx, absf(d.decode_s16(i)))
		w.save_to_wav("/tmp/gd/aud/" + n + ".wav")
		print(n, " takes ", t.size(), " len ", d.size() / 2, " peak ", mx / 32767.0)
	k.free()
	quit()
