extends Node2D
## Builds the sandbox: world, player, mercenary, monsters and HUD.

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

const TARGET_MONSTERS := 150

var world
var player
var _respawn_check := 10.0


func _ready() -> void:
	randomize()
	world = WorldScript.new()
	add_child(world)
	world.generate(randi())

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

	player = PlayerScript.new()
	player.position = world.center_of(world.spawn_cell)
	player.spawn_point = player.position
	Game.player = player
	units.add_child(player)

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

	Game.spawn_merc(player.position + Vector2(40, 24))
	for i in TARGET_MONSTERS / 4:
		_spawn_pack(600.0)

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
		if n < TARGET_MONSTERS:
			for i in 3:
				_spawn_pack(1000.0)


func _spawn_pack(min_dist_from_player: float) -> void:
	for attempt in 40:
		var c: Vector2i = world.reachable_cells.pick_random()
		var dc := Vector2(c - world.spawn_cell).length()
		if dc < 16.0:
			continue
		var wp: Vector2 = world.center_of(c)
		if wp.distance_to(player.global_position) < min_dist_from_player:
			continue
		var kinds := CreatureDB.pack_kinds(dc)
		var kind: String = kinds.pick_random()
		var lvl := 1 + int(dc / 7.0)
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
