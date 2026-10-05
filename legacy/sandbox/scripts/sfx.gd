extends Node
## Sound effects (Kenney CC0 packs). Sfx.play("hit", position) picks a random
## variation; positional sounds fade with distance from the camera.

const DIR := "res://assets/audio/sfx/"
const GROUPS := {
	"swing": ["knifeSlice", "knifeSlice2", "drawKnife1", "drawKnife2", "drawKnife3"],
	"cast": ["cloth1", "cloth2", "cloth3", "cloth4"],
	"hit": ["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002", "impactPunch_medium_003", "impactPunch_medium_004"],
	"hit_heavy": ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002", "impactPunch_heavy_003", "impactPunch_heavy_004"],
	"bone": ["impactWood_light_000", "impactWood_light_001", "impactWood_light_002", "impactWood_light_003", "impactWood_light_004"],
	"explode": ["impactMining_000", "impactMining_001", "impactMining_002", "impactMining_003", "impactMining_004"],
	"block": ["impactMetal_medium_000", "impactMetal_medium_001", "impactMetal_medium_002", "impactMetal_medium_003", "impactMetal_medium_004"],
	"soft": ["impactSoft_medium_000", "impactSoft_medium_001", "impactSoft_medium_002", "impactSoft_medium_003", "impactSoft_medium_004"],
	"step": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003", "footstep_grass_004"],
	"coins": ["handleCoins", "handleCoins2"],
	"potion": ["beltHandle1", "beltHandle2"],
	"chop": ["chop"],
	"levelup": ["impactBell_heavy_000"],
}
const POOL := 16

var _streams := {}
var _players: Array = []
var _next := 0
var enabled := true


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR + name + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	_streams[name] = s
	return s


func play(group: String, pos = null, volume_db := 0.0) -> void:
	if not enabled or not GROUPS.has(group):
		return
	var vol := volume_db
	if pos != null:
		var cam := get_viewport().get_camera_2d()
		if cam:
			var d: float = cam.get_screen_center_position().distance_to(pos)
			if d > 700.0:
				return
			vol -= d / 700.0 * 18.0
	var s := _stream(GROUPS[group].pick_random())
	if s == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
