@tool
extends EditorPlugin
## Nothing to configure: the loaders are plain scripts (PFSpriteSet, PFFx, PFObjects). This plugin only makes
## them appear in the add-on list so a project knows it carries them.

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
