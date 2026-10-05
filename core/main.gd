extends Node2D
## Godmarrow (Godot): the game scene. Builds the zone from the export, the hero, the creatures, light and camera,
## moves between zones through their gates and caves, and handles death and the lantern's return.

var zone: Zone
var hero: Hero
var cam: Camera2D
var eye: CamDirector
var sky: Weather
var sound: Soundscape
var far: FarPilgrims
var ambient: CanvasModulate
var hud: Node
var dark: DarkLayer
var atmos: Atmos
var args := {}
var last_lantern := {}        # {zone, x, y}
var remnant := {}             # {zone, x, y, gold}
var travelling := false
var whisper_t := 60.0         # the world's whispers (zz_voice.js): every 60-120 s of quiet exploring
var voice := {}
var last_whisper := ""
var boss_awake: Node = null
var title_open := false      # ui/title.gd is up: the camera drifts, the HUD and the pilgrim wait
var title_t := 0.0
var reading_open := false    # ui/reading.gd is up: a new pilgrim is being read before the walk
var pending_load := {}        # a save waiting to be poured into the first hero (Continue)
const SaveIO := preload("res://core/save.gd")
const TestHooks := preload("res://core/test_hooks.gd")

func _ready() -> void:
	randomize()
	Assets.load_meta()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("seed"):   # tests: the same run every time (tools/smoke.sh)
		seed(int(args["seed"]))
	if args.has("trial"):   # tests: the Trial of Thirty slot (--trial --new makes a fresh one)
		Game.slot = "_trial"
		Game.trial_new = args.has("new")
	Game.new_run()
	if args.has("cls"):
		Game.cls = args["cls"]
	if args.has("hour"):
		Game.clock = float(args["hour"]) * Game.day_len
	if args.has("zseed"):   # tests: every zone at this exported seed (tools/zone_export/compare.mjs, side by side)
		for zid in Data.zone_index().get("zones", {}):
			if int(args["zseed"]) in Data.zone_seeds(zid):
				Game.zone_seeds[zid] = int(args["zseed"])
	if Game.force_new:
		args["new"] = "1"
		Game.force_new = false
	# the title: when the game is simply launched (no test arguments), or with --title
	var plain := args.is_empty() or (args.size() == 1 and args.has("hour"))
	title_open = (plain or args.has("title")) and not Game.skip_title
	Game.skip_title = false
	reading_open = Game.read_new or args.has("reading")
	Game.read_new = false
	# Continue: the saved pilgrim, in a freshly rolled world, at the camp (--new starts over)
	if not args.has("new") and not args.has("demo") and SaveIO.exists():
		# a named order (--cls) wakes that order's own pilgrim, not the latest one
		pending_load = SaveIO.read(Game.load_cls if Game.load_cls != "" else String(args.get("cls", "")))
		Game.load_cls = ""
		if not pending_load.is_empty():
			Game.cls = pending_load.get("cls", Game.cls)
	ambient = CanvasModulate.new()
	add_child(ambient)
	dark = DarkLayer.new()
	add_child(dark)
	atmos = Atmos.new()
	add_child(atmos)
	sky = Weather.new()
	add_child(sky)
	sound = Soundscape.new(self)
	add_child(sound)
	add_child(Sfx.new())
	far = FarPilgrims.new(self)
	add_child(far)
	Bus.monster_killed.connect(func(_m): Sfx.play("fall"))
	sky.snd = sound
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)
	eye = CamDirector.new(self, cam)
	Bus.monster_killed.connect(_on_kill)
	Bus.boss_woke.connect(func(m): boss_awake = m)
	Bus.boss_felled.connect(func(m): if m == boss_awake: boss_awake = null)
	var vj = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/voice.json"))
	if vj is Dictionary:
		voice = vj
	if ResourceLoader.exists("res://ui/hud.gd") and not OS.has_environment("GM_NOHUD"):
		hud = load("res://ui/hud.gd").new()
		add_child(hud)
	await enter(args.get("zone", "moor"), "")
	await TestHooks.run(self)   # test and capture hooks (core/test_hooks.gd); nothing without their args


func enter(zid: String, from: String) -> void:
	travelling = true
	if from != "" and from != "__lantern":
		Sfx.play("passage")
	var old_stats: HeroStats = hero.st if hero else null
	var old_skills: SkillBook = hero.skills if hero else null
	if zone:
		zone.queue_free()
		zone = null
		hero = null
		await get_tree().process_frame
	zone = Zone.new()
	add_child(zone)
	move_child(zone, 0)
	zone.load_zone(zid, Game.seed_for(zid))
	var at: Vector2
	if from == "__lantern" and not last_lantern.is_empty():
		at = Vector2(last_lantern["x"], last_lantern["y"] + 1.2)
	elif from != "" and zone.arrive.has(from):
		at = Vector2(zone.arrive[from]["x"], zone.arrive[from]["y"])
	else:
		at = Vector2(zone.markers["start"]["x"], zone.markers["start"]["y"])
	hero = Hero.new()
	hero.st = old_stats
	hero.skills = old_skills
	zone.sorted.add_child(hero)
	hero.setup(zone, Game.cls, at)
	if Game.trial_new:
		# the Trial of Thirty (the web's test character): level 30, 120 skill points (S), 145 stat points (C)
		Game.trial_new = false
		hero.st.level = 30
		hero.st.skill_points = 120
		hero.st.attr_points = 145
		hero.st.arcana_points = 30
		hero.st.hp = hero.st.life_max()
		hero.st.res = hero.st.res_max()
		hero.st.poise = hero.st.poise_max()
		get_tree().create_timer(8.0).timeout.connect(func(): Bus.say.emit("The Trial of Thirty: level 30, 120 skill points (S), 145 stat points (C)", 5.0))
	var fresh_pilgrim := hero.st.level == 1 and hero.st.xp == 0 and pending_load.is_empty() and from == ""
	if not pending_load.is_empty():
		SaveIO.apply(self, pending_load)
		pending_load = {}
		if args.has("hour"):
			Game.clock = float(args["hour"]) * Game.day_len
	hero.died.connect(_on_hero_died)
	if title_open:
		_title_open()
	elif reading_open and fresh_pilgrim:
		_reading_open()
	for m in zone.d.get("monsters", []):
		# the safe circle of a town holds no creatures
		var sc = zone.markers.get("safeCircle")
		if sc is Dictionary and Vector2(m["x"], m["y"]).distance_to(Vector2(sc["x"], sc["y"])) < float(sc["r"]):
			continue
		var mon := Monster.new()
		zone.sorted.add_child(mon)
		mon.setup(zone, m)
	eye.arrive(zone, hero, from)
	cam.position = eye.update(0.016, hero, null, zone)
	cam.reset_smoothing()
	dark.bind(zone, hero)
	atmos.bind(zone, hero, dark)
	sky.bind(zone, hero, dark)
	far.bind(zone, hero)
	Sfx.set_room(not zone.d.get("outdoor", false))
	if OS.has_environment("GM_FARNOW"):
		far.wait = 0.5
	if hud and hud.has_method("bind"):
		hud.bind(hero, zone)
		# a new pilgrim opens on the skill page to spend the first point
		if fresh_pilgrim and hero.st.skill_points > 0 and not args.has("demo") and not args.has("panel") and not args.has("shot") and not args.has("arena") and not hud.is_open("skills"):
			hud.toggle_panel("skills")
	if ResourceLoader.exists("res://world/objects.gd") and not OS.has_environment("GM_NOOBJ"):   # (world objects): town, objects, waystones, vows
		load("res://world/objects.gd").attach(self, zone, hero)
	Bus.zone_entered.emit(zid)
	whisper_t = randf_range(40.0, 75.0)
	save_game()
	await get_tree().create_timer(0.5).timeout
	travelling = false

## the title (ui/title.gd): the world runs behind it; the pilgrim and the HUD wait
func _title_open() -> void:
	var T = load("res://ui/title.gd").new(self)
	add_child(T)
	if hud:
		hud.visible = false
		hud.set_process_input(false)
	hero.set_process_unhandled_input(false)
	hero.set_process_input(false)

## the Reading: the Stranger's fire over everything until the new pilgrim rises; what it gives is theirs for the walk
func _reading_open() -> void:
	var Rd = load("res://ui/reading.gd").new(self, hero.cls)
	Rd.on_done = _reading_done
	add_child(Rd)
	title_open = true      # (the world waits the same way it does for the title)
	if hud:
		hud.visible = false
		hud.set_process_input(false)
	hero.set_process_unhandled_input(false)
	hero.set_process_input(false)

func _reading_done(r: Dictionary) -> void:
	reading_open = false
	hero.st.fate = r.get("fx", {})
	hero.st.fate_picks = r.get("picks", [])
	hero.st.hp = hero.st.life_max()
	hero.st.res = hero.st.res_max()
	hero.st.poise = hero.st.poise_max()
	title_done()
	save_game()

func title_done() -> void:
	title_open = false
	if hud:
		hud.visible = true
		hud.set_process_input(true)
	hero.set_process_unhandled_input(true)
	hero.set_process_input(true)

## the lantern's panel: go to any lantern kindled on this walk
func travel_lantern(e: Dictionary) -> void:
	if travelling or hero == null:
		return
	last_lantern = e.duplicate()
	if e.get("zone", "") == zone.id:
		hero.tp = Vector2(e["x"], e["y"] + 1.2)
		hero.target = null
		hero.walking = false
		hero._sync()
		eye.cut(hero)
		cam.position = eye.update(0.016, hero, null, zone)
		cam.reset_smoothing()
	else:
		await enter(e["zone"], "__lantern")

## the save (core/save.gd): on entering a zone, touching a lantern, from the pause menu, and on quitting
func save_game() -> void:
	if hero != null and not hero.dead and not args.has("demo"):
		SaveIO.write(self)

## static caches that hold Resources (textures, fonts, sounds, scripts) must be emptied before the engine shuts down, or
## it crashes on exit freeing them after the servers are gone
func _exit_tree() -> void:
	# a script kept on the Engine's metadata is freed after the script language itself: that was the crash on exit
	if Engine.has_meta("godmarrow_quests"):
		Engine.remove_meta("godmarrow_quests")
	var U = load("res://ui/uikit.gd")
	U._fonts.clear()
	U._tex.clear()
	Lights._cache.clear()
	Assets._cache.clear()
	load("res://world/objects/world_ui.gd")._fonts.clear()
	load("res://world/objects/manager_build.gd")._tex_cache.clear()
	load("res://items/item_sfx.gd")._cache.clear()
	load("res://items/loot.gd")._icons.clear()
	load("res://entities/ai/brain.gd")._mys = null
	load("res://items/shop.gd")._wares.clear()
	load("res://items/shop.gd")._stash.clear()
	load("res://items/ground.gd")._kept.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func _process(_dt: float) -> void:
	if hero == null or zone == null or travelling:
		return
	cam.position = eye.update(_dt, hero, boss_awake, zone)
	if title_open:
		# the title's slow drift over the camp: wide, unhurried, never quite repeating
		title_t += _dt
		cam.position += Vector2(-240.0 + sin(title_t * 0.045) * 200.0 + sin(title_t * 0.11) * 40.0, -60.0 + cos(title_t * 0.037) * 70.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake_amt if Game.shake_amt > 0.05 else Vector2.ZERO
	ambient.color = Color.WHITE   # the dark layer does the night now (web model)
	# gates and caves: walk onto one to go through
	for c in zone.connections:
		var p := Vector2(c["x"], c["y"])
		if hero.tp.distance_to(p) < 0.8 and not hero.dead:
			enter(c["to"], zone.id)
			return
	# lantern-stones: kindled by passing and set as the return point by touch (world/objects/manager.gd)
	# the remnant: what the lantern kept waits where you fell
	if not remnant.is_empty() and remnant["zone"] == zone.id and not hero.dead:
		var rp := Vector2(remnant["x"], remnant["y"])
		if hero.tp.distance_to(rp) > 2.5:
			remnant["armed"] = true
		elif remnant.get("armed", false) and hero.tp.distance_to(rp) < 0.9:
			hero.st.inv.gold += int(remnant["gold"])
			hero.st.kept = 0
			hero.st.hp = minf(hero.st.life_max(), hero.st.hp + hero.st.life_max() * 0.25)
			remnant = {}
			Bus.say.emit("The lantern takes back what it kept.", 2.5)
			hero.stats_changed.emit()
	_cut_walls()
	_whisper(_dt)

func _whisper(dt: float) -> void:
	whisper_t -= dt
	if whisper_t > 0.0:
		return
	var quiet: bool = not hero.dead and (hud == null or not hud.any_panel()) and not (boss_awake != null and is_instance_valid(boss_awake) and not boss_awake.dead)
	if not quiet or voice.is_empty():
		whisper_t = 5.0
		return
	whisper_t = randf_range(60.0, 120.0)
	# now and then, instead of the land's own voice, a saying of the folk who live on it
	if randf() < 0.3:
		var ls: Array = load("res://world/quests.gd").land_saying(zone.id, zone.d.get("outdoor", false))
		var W0 := _world_ui()
		if W0:
			W0.whisper(ls[0], ls[1])
		return
	var zd: Dictionary = voice.get("zones", {}).get(zone.id, {})
	var pool: Array = zd.get("w", [])
	if pool.is_empty():
		pool = voice.get("act", {}).get(str(load("res://world/quests.gd").act_of(zone.id)), [])
	if pool.is_empty():
		return
	var line: String = pool[randi() % pool.size()]
	if line == last_whisper and pool.size() > 1:
		line = pool[(pool.find(line) + 1) % pool.size()]
	last_whisper = line
	var W := _world_ui()
	if W:
		W.whisper("", line)

## walls in front of the hero go thin so he is never lost behind them (the web cuts them to a stub)
func _cut_walls() -> void:
	for b: WallBlock in zone.wall_nodes:
		var t := Vector2(b.tile) + Vector2(0.5, 0.5)
		var dt := t - hero.tp
		if absf(dt.x) > 5.0 or absf(dt.y) > 5.0:
			if b._fade_to != 1.0:
				b.set_cut(false)
			continue
		b.set_cut((t.x + t.y) > (hero.tp.x + hero.tp.y) and dt.length() < 4.0)

# ------------------------------------------------------------------ kills, death, return
## XP pacing (zz_progression.js): by the creature's level and by the hero's, piecewise-linear
const XP_KNOTS := [[1, 0.72], [24, 0.74], [30, 0.78], [34, 0.6], [40, 0.72]]
const LVL_KNOTS := [[1, 1.0], [16, 1.0], [21, 0.92], [27, 0.9], [32, 0.6], [36, 0.58], [40, 0.53]]
static func _knot(k: Array, x: float) -> float:
	if x <= k[0][0]:
		return k[0][1]
	for i in range(1, k.size()):
		if x <= k[i][0]:
			var a: Array = k[i - 1]
			var b: Array = k[i]
			return lerpf(a[1], b[1], (x - a[0]) / float(b[0] - a[0]))
	return k[k.size() - 1][1]

func _on_kill(m: Monster) -> void:
	if hero == null:
		return
	var gain := _knot(LVL_KNOTS, hero.st.level)   # (the export's m.xp already carries the creature-level factor, XP_KNOTS)
	gain = gain * (1.0 + hero.st.item("xpK") / 100.0)
	if hero.st.level > m.level + 5:
		gain *= maxf(0.1, 1.0 - 0.15 * (hero.st.level - m.level - 5))
	if hero.st.add_xp(int(round(m.xp * gain))):
		Bus.level_up.emit(hero.st.level)
		Bus.say.emit("You feel the marrow settle. Level %d." % hero.st.level, 2.5)
	var lok := hero.st.item("lok")
	if lok > 0.0:
		hero.st.hp = minf(hero.st.life_max(), hero.st.hp + lok)
	var unwritten: bool = hero.st.arc != null and hero.st.arc.aU("v_unwritten") and not m.boss
	if unwritten:
		m.corpse_t = 0.0   # no corpse, nothing dropped
	elif ResourceLoader.exists("res://items/loot.gd"):
		load("res://items/loot.gd").on_kill(zone, m, hero)
	hero.stats_changed.emit()

const DEATH_LINES := [
	"The body keeps walking a moment longer, then remembers.",
	"Your breath goes out and joins the Last Breath. It does not come back alone.",
	"Somewhere a lantern leans toward the place you fell.",
	"The ground takes you in, gently, the way it took the god.",
	"You were a shape. Now you are a story the ash will tell badly.",
	"The mourners in the ash come to look. They have always come to look.",
	"Bone, flesh, breath: each lets go of you in turn.",
	"The dark is warm here. That is the worst of it.",
	"Your name goes on the long list. Not in ink. Not yet.",
	"Somewhere below, something hungry marks the place, and waits."]
const RETURN_LINES := [
	"The lantern gives you back. It keeps a little, as it always does.",
	"You wake to wick-light, the taste of ash, and your own name.",
	"The flame leans toward you. It remembered.",
	"Breath returns, borrowed. The Last Breath lends, and counts.",
	"Again. The wick says a little longer. The wick always says a little longer.",
	"You stand where you last knelt. The ground is still warm from you.",
	"The ash parts to let you rise. It has seen this before.",
	"Back, and lighter by something. You will not know what until you need it.",
	"The lantern burned for you while you were gone. It is tired.",
	"Up, pilgrim. The road is still down, and still yours."]
var _last_death := -1
var _last_ret := -1

func _world_ui() -> Node:
	return get_tree().root.find_child("GodmarrowWorldUI", true, false)

func _pick(arr: Array, last: int) -> int:
	var i := randi() % arr.size()
	return (i + 1) % arr.size() if i == last else i

func _on_hero_died() -> void:
	var gold := hero.st.inv.gold
	hero.st.inv.gold = 0
	hero.st.kept = mini(3, hero.st.kept + 1)
	remnant = {"zone": zone.id, "x": hero.tp.x, "y": hero.tp.y, "gold": gold}
	if hero.skills:
		hero.skills.on_death()   # wisps, the golem and every summoned thing are cleared
	# whatever was chasing loses the scent
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.brain and not m.boss and m.brain.state != "sleep":
			m.brain.set_state("sleep")
			m.awake = false
	_last_death = _pick(DEATH_LINES, _last_death)
	var W := _world_ui()
	if W:
		W.banner("ANIMA SEVERED", Color8(142, 38, 48), 3.2)
		# what did it: never an unknown killer (the user's rule: every danger is plainly seen)
		W.whisper(("Slain by " + hero.last_blow + ".") if hero.last_blow != "" else "", DEATH_LINES[_last_death], 4.0)
	else:
		Bus.say.emit(DEATH_LINES[_last_death], 3.0)
	await get_tree().create_timer(3.0).timeout
	var back_zone: String = last_lantern.get("zone", "moor")
	var at_self := back_zone == zone.id and not last_lantern.is_empty()
	if at_self:
		hero.revive(Vector2(last_lantern["x"], last_lantern["y"] + 1.2))
	else:
		await enter(back_zone, "__lantern" if not last_lantern.is_empty() else "")
		hero.revive(hero.tp)
	if hero.skills:
		hero.skills.on_lantern()
	_last_ret = _pick(RETURN_LINES, _last_ret)
	var W2 := _world_ui()
	if W2:
		W2.whisper("", RETURN_LINES[_last_ret], 5.0)
