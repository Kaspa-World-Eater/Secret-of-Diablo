extends RefCounted
## The world's objects, the town and the vows, wired into a zone (see world/objects/manager.gd).
## main.gd calls `load("res://world/objects.gd").attach(self, zone, hero)` at the end of every zone entry (after the
## hero and the creatures are placed). Calling it again for the same zone with a new hero only rebinds the hero.
## Persistent pieces live under main for the whole run: the world's voice on screen (GodmarrowWorldUI) and the
## waystone passage (WaystonePassage). The vows' state is the static store world/quests.gd.

const QUESTS := preload("res://world/quests.gd")

static func attach(main: Node, zone: Node, hero: Node) -> void:
	if main == null or zone == null:
		return
	Engine.set_meta("godmarrow_quests", QUESTS)   # keeps the static store alive for the run
	if main.get_node_or_null("GodmarrowWorldUI") == null:
		var ui := CanvasLayer.new()
		ui.set_script(load("res://world/objects/world_ui.gd"))
		main.add_child(ui)
		ui.name = "GodmarrowWorldUI"
	if main.get_node_or_null("WaystonePassage") == null:
		var p := Node.new()
		p.set_script(load("res://world/objects/passage.gd"))
		p.set("main", main)
		main.add_child(p)
		p.name = "WaystonePassage"
	# test scenarios: --objtest=<name> (world/objects/test_driver.gd)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--objtest=") and main.get_node_or_null("ObjTest") == null:
			var t := Node.new()
			t.set_script(load("res://world/objects/test_driver.gd"))
			t.set("main", main)
			t.set("which", a.trim_prefix("--objtest="))
			main.add_child(t)
		# the walker: a scripted pilgrim through Act I (world/objects/walker.gd)
		if (a == "--walk" or a.begins_with("--walk=")) and main.get_node_or_null("Walker") == null:
			var w := Node.new()
			w.set_script(load("res://world/objects/walker.gd"))
			w.set("main", main)
			main.add_child(w)
	var mgr := zone.get_node_or_null("WorldObjects")
	if mgr:
		mgr.rebind(hero)
		return
	mgr = Node2D.new()
	mgr.set_script(load("res://world/objects/manager.gd"))
	mgr.name = "WorldObjects"
	zone.add_child(mgr)
	mgr.setup(main, zone, hero)

## the vows' store (static): journal(act), waystones(act), act_name(n), max_act(), to_dict()/from_dict()
static func quests():
	return QUESTS
