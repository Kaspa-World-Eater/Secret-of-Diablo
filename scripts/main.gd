extends Node2D
## Builds the sandbox: world, player, mercenary, monsters and HUD.

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const DayNightScript := preload("res://scripts/day_night.gd")
const LanternScript := preload("res://scripts/lantern.gd")
const CampfireScript := preload("res://scripts/campfire.gd")
const ZoneEditorScript := preload("res://scripts/zone_editor.gd")

var target_monsters := 150
var editor

var world
var player
var _respawn_check := 10.0
var _night_check := 5.0
const MAX_SHADES := 24


func _ready() -> void:
	randomize()
	world = WorldScript.new()
	add_child(world)
	if Game.current_zone == "" or not world.load_zone(Game.current_zone):
		Game.current_zone = ""
		world.generate(randi())
	else:
		target_monsters = clampi(world.reachable_cells.size() / 220, 6, 150)
	var dn = DayNightScript.new()
	add_child(dn)
	Game.day_night = dn

	var ground := Node2D.new()
	add_child(ground)
	add_child(world.bone_layer)
	var units := Node2D.new()
	units.y_sort_enabled = true
	add_child(units)
	var proj := Node2D.new()
	add_child(proj)
	var fx := Node2D.new()
	add_child(fx)

	Game.world = world
	Game.ground_layer = ground
	Game.units_layer = units
	Game.proj_layer = proj
	Game.fx_layer = fx

	if world.zone == "":
		var fire = CampfireScript.new()
		fire.position = world.center_of(world.spawn_cell) + Vector2(0, -40)
		units.add_child(fire)

	player = PlayerScript.new()
	player.position = world.center_of(world.spawn_cell)
	player.spawn_point = player.position
	Game.player = player
	units.add_child(player)
	if not Game.saved_player.is_empty():
		player.from_dict(Game.saved_player)

	var cam := Camera2D.new()
	cam.zoom = Vector2(1.6, 1.6)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = world.W * world.TILE
	cam.limit_bottom = world.H * world.TILE
	player.add_child(cam)
	cam.make_current()

	var lantern = LanternScript.new()
	lantern.owner_p = player
	lantern.position = player.position + Vector2(-20, 10)
	player.lantern = lantern
	units.add_child(lantern)

	Game.spawn_merc(player.position + Vector2(40, 24))
	for i in target_monsters / 4:
		_spawn_pack(600.0 if world.zone == "" else 250.0)

	editor = ZoneEditorScript.new()
	add_child(editor)

	var hud = HudScript.new()
	add_child(hud)
	Game.hud = hud


func _process(delta: float) -> void:
	_respawn_check -= delta
	if _respawn_check <= 0.0:
		_respawn_check = 8.0
		var n := 0
		for u in Game.units:
			if u.team == 1:
				n += 1
		if n < target_monsters:
			for i in 3:
				_spawn_pack(1000.0)
	_night_check -= delta
	if _night_check <= 0.0:
		_night_check = 12.0
		if Game.is_night():
			var shades := 0
			for u in Game.units:
				if u.get("nocturnal"):
					shades += 1
			if shades < MAX_SHADES:
				_spawn_shades()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		var zones: Array = [""] + WorldScript.list_zones()
		if zones.size() == 1:
			Game.message("No imported zones yet - see assets/rip/README.md")
			return
		var i := zones.find(Game.current_zone)
		Game.travel(zones[(i + 1) % zones.size()])
		get_viewport().set_input_as_handled()


func _spawn_shades() -> void:
	## Shades rise out of the dark somewhere near (but not on top of) the player.
	for attempt in 30:
		var p: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(450.0, 850.0)
		if not world.is_walkable_px(p) or Game.light_at(p) > 0.3:
			continue
		var lvl: int = world.zone_level + 1 + int(world.dist_tiles_from_spawn(p) / 7.0)
		for i in randi_range(2, 4):
			var sp := p + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			if world.is_walkable_px(sp):
				Game.spawn_creature(CreatureDB.monster_stats("shade", lvl, false), 1, sp, null)
		return


func _spawn_pack(min_dist_from_player: float) -> void:
	for attempt in 40:
		var c: Vector2i = world.reachable_cells.pick_random()
		var dc := Vector2(c - world.spawn_cell).length()
		if dc < (16.0 if world.zone == "" else 8.0):
			continue
		var wp: Vector2 = world.center_of(c)
		if wp.distance_to(player.global_position) < min_dist_from_player:
			continue
		var kinds := CreatureDB.pack_kinds(dc)
		var kind: String = kinds.pick_random()
		var lvl: int = world.zone_level + int(dc / 7.0)
		var champion := randf() < 0.08
		var n := randi_range(2, 4) if champion else randi_range(3, 6)
		if kind == "hopper":
			n += 2
		for i in n:
			var sp := wp + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			if not world.is_walkable_px(sp):
				sp = wp
			var k: String = kind if randf() < 0.75 else kinds.pick_random()
			Game.spawn_creature(CreatureDB.monster_stats(k, lvl, champion), 1, sp, null)
		return
