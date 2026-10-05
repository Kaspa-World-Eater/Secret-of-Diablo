extends "res://skills/ossumancer/fx.gd"
## Look test for the Bone Lance: all four tiers at a few angles, and a charging one growing, on the ground's dark.
## Writes /tmp/ossport/lance_preview.png. Run: godot --path . res://tests/lance_preview.tscn

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.1, 0.09, 0.08))
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/ossport/lance_preview.png")
	get_tree().quit()

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var dirs := [Vector2(1, 0), Vector2(1, -0.5).normalized(), Vector2(0.6, 0.8).normalized()]
	for tier in 4:
		for d in dirs.size():
			lance(Vector2(160 + d * 330, 120 + tier * 150), dirs[d], tier, 1.0)
	for g in 4:
		lance(Vector2(1180, 120 + g * 150), Vector2(1, -0.5).normalized(), g, 0.55)
