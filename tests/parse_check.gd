extends SceneTree
## Loads every script under res:// (tests excluded) and reports any that fail to parse.
##   godot --headless --path . -s tests/parse_check.gd [-- dir]
func _init() -> void:
	var bad := 0
	var dirs := ["res://"]
	while dirs:
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if not sub.begins_with(".") and sub != "legacy" and sub != "tools":
				dirs.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d.path_join(f))
				if s == null or not s.can_instantiate():
					bad += 1
					print("BAD ", d.path_join(f))
	print("parse check: %d bad" % bad)
	quit()
