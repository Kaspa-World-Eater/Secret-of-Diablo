extends SceneTree
## Builds the game's sprite sheets and world art from free LPC packs.
##
##   LPC_SRC=/path/to/downloads godot --headless --path . --script res://tools/build_lpc.gd
##
## LPC_SRC must contain (see CREDITS.md for sources):
##   lpcgen/spritesheets/...           Universal LPC Spritesheet Character Generator
##   lpc-monsters/lpc-monsters/*.png   [LPC] Monsters
##   lpc_base_assets/LPC Base Assets/  LPC Base Assets
##   lpc-trees/lpc-trees/*.png         [LPC] Trees
##
## Output: assets/sprites/<key>.png + .json, assets/world/*.png + .json

const F := 64  # LPC frame size
const DIRS := ["up", "left", "down", "right"]
const FRAMES := {"walk": 9, "slash": 6, "thrust": 8, "spellcast": 7, "shoot": 13}

const PALE := [0.93, 0.9, 0.96, 0.65]
const ROBE := [0.24, 0.19, 0.3, 1.0]
const CAPE := [0.32, 0.18, 0.42, 1.0]
const DARK := [0.17, 0.15, 0.2, 1.0]

# Each layer: [path with {a} = animation name, tint [r,g,b,mix] or null]; drawn bottom to top.
const CHARACTERS := {
	"necromancer": {"attack": "slash", "cast": "spellcast", "layers": [
		["cape/tattered/bg/{a}.png", CAPE],
		["weapon/magic/simple/background/{a}/simple.png", null],
		["body/bodies/male/{a}.png", PALE],
		["legs/pants/male/{a}.png", DARK],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", ROBE],
		["cape/tattered/fg/{a}.png", CAPE],
		["head/heads/human/male_gaunt/{a}.png", PALE],
		["hair/long/adult/{a}.png", [1.0, 1.0, 1.0, 1.0]],
		["weapon/magic/simple/foreground/{a}/simple.png", null]]},
	"skeleton": {"attack": "thrust", "cast": "spellcast", "layers": [
		["weapon/polearm/spear/background/{a}/spear.png", null],
		["body/bodies/skeleton/{a}.png", null],
		["head/heads/skeleton/adult/{a}.png", null],
		["weapon/polearm/spear/foreground/{a}/spear.png", null]]},
	"skel_mage": {"attack": "spellcast", "cast": "spellcast", "layers": [
		["weapon/magic/simple/background/{a}/simple.png", null],
		["body/bodies/skeleton/{a}.png", null],
		["head/heads/skeleton/adult/{a}.png", null],
		["hat/cloth/hood/adult/{a}.png", CAPE],
		["weapon/magic/simple/foreground/{a}/simple.png", null]]},
	"merc": {"attack": "thrust", "cast": "spellcast", "layers": [
		["weapon/polearm/spear/background/{a}/spear.png", null],
		["body/bodies/male/{a}.png", null],
		["legs/armour/plate/male/{a}.png", null],
		["torso/armour/plate/male/{a}.png", [0.55, 0.65, 0.95, 0.55]],
		["head/heads/human/male/{a}.png", null],
		["hat/helmet/armet/adult/{a}.png", null],
		["weapon/polearm/spear/foreground/{a}/spear.png", null]]},
	"goblin": {"attack": "thrust", "cast": "spellcast", "layers": [
		["weapon/polearm/spear/background/{a}/spear.png", null],
		["body/bodies/male/{a}.png", [0.5, 0.8, 0.38, 0.85]],
		["legs/pants/male/{a}.png", [0.5, 0.33, 0.2, 1.0]],
		["head/heads/goblin/adult/{a}.png", null],
		["weapon/polearm/spear/foreground/{a}/spear.png", null]]},
	"goblin_archer": {"attack": "shoot", "cast": "spellcast", "layers": [
		["weapon/ranged/bow/normal/universal/background/{a}/normal.png", null],
		["body/bodies/male/{a}.png", [0.5, 0.8, 0.38, 0.85]],
		["legs/pants/male/{a}.png", [0.35, 0.42, 0.22, 1.0]],
		["head/heads/goblin/adult/{a}.png", null],
		["weapon/ranged/bow/normal/universal/foreground/{a}/normal.png", null]]},
	"ghoul": {"attack": "slash", "cast": "spellcast", "layers": [
		["body/bodies/zombie/{a}/zombie.png", null],
		["head/heads/zombie/adult/{a}.png", null]]},
}

# Single-sheet monsters: frame size, per-row frame ranges for walk / attack, optional tint.
const MONSTERS := {
	"hopper": {"file": "slime.png", "size": 64, "walk": [0, 4], "attack": [4, 6], "tint": [1.35, 1.12, 0.38, 0.92]},
	"shade": {"file": "ghost.png", "size": 64, "walk": [0, 3], "attack": [4, 6], "tint": [0.55, 0.4, 0.8, 0.85]},
	"shroom": {"file": "man_eater_flower.png", "size": 128, "walk": [0, 3], "attack": [3, 6], "scale": 0.5,
		"rows": {"up": 2, "left": 2, "down": 2, "right": 2}},
}

var src := ""


func _init() -> void:
	src = OS.get_environment("LPC_SRC")
	if src == "" or not DirAccess.dir_exists_absolute(src):
		push_error("Set LPC_SRC to the folder with the downloaded LPC packs")
		quit(1)
		return
	for key in CHARACTERS:
		_build_character(key, CHARACTERS[key])
	for key in MONSTERS:
		_build_monster(key, MONSTERS[key])
	_build_world()
	print("build_lpc: done")
	quit()


func _img(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _tint(img: Image, t) -> void:
	if t == null:
		return
	var tc := Color(t[0], t[1], t[2])
	var mix: float = t[3]
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			var l := 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
			var k: float = min(1.0, l * 1.45)
			var n := Color(tc.r * k, tc.g * k, tc.b * k, p.a)
			img.set_pixel(x, y, p.lerp(n, mix))


func _out(name: String) -> String:
	return ProjectSettings.globalize_path("res://assets/" + name)


func _save_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# ---------------------------------------------------------------- characters

func _build_character(key: String, recipe: Dictionary) -> void:
	var anims := {"walk": "walk", "attack": recipe["attack"], "cast": recipe["cast"]}
	var order := ["walk", "attack", "cast"]
	var cols := 13
	var sheet := Image.create(cols * F, order.size() * 4 * F, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var json_anims := {}
	for ai in order.size():
		var state: String = order[ai]
		var lpc_anim: String = anims[state]
		var n: int = FRAMES[lpc_anim]
		var comp := Image.create(n * F, 4 * F, false, Image.FORMAT_RGBA8)
		comp.fill(Color(0, 0, 0, 0))
		for layer in recipe["layers"]:
			var p: String = src + "/lpcgen/spritesheets/" + String(layer[0]).replace("{a}", lpc_anim)
			var img := _img(p)
			if img == null:
				continue
			_tint(img, layer[1])
			comp.blend_rect(img, Rect2i(0, 0, min(img.get_width(), n * F), min(img.get_height(), 4 * F)), Vector2i.ZERO)
		sheet.blit_rect(comp, Rect2i(0, 0, n * F, 4 * F), Vector2i(0, ai * 4 * F))
		for di in 4:
			var row := ai * 4 + di
			var dir: String = DIRS[di]
			if state == "walk":
				json_anims["idle_" + dir] = {"frames": [[0, row]], "fps": 1}
				var wf := []
				for i in range(1, n):
					wf.append([i, row])
				json_anims["walk_" + dir] = {"frames": wf, "fps": 12}
			else:
				var fr := []
				for i in n:
					fr.append([i, row])
				json_anims[state + "_" + dir] = {"frames": fr, "fps": n / 0.32, "loop": false}
				if state == "attack":
					json_anims["charge_" + dir] = {"frames": [[0, row]], "fps": 1}
	sheet.save_png(_out("sprites/%s.png" % key))
	_save_json(_out("sprites/%s.json" % key), {"sheet": key + ".png", "frame_size": [F, F], "offset": [0, -28],
		"scale": 1.0, "head_y": -54, "animations": json_anims})
	print("  character ", key)


# ---------------------------------------------------------------- monsters

func _build_monster(key: String, m: Dictionary) -> void:
	var img := _img(src + "/lpc-monsters/lpc-monsters/" + String(m["file"]))
	if img == null:
		push_warning("missing monster sheet " + str(m["file"]))
		return
	_tint(img, m.get("tint"))
	var s: int = m["size"]
	var anims := {}
	var rows: Dictionary = m.get("rows", {"up": 0, "left": 1, "down": 2, "right": 3})
	for dir in DIRS:
		var r: int = rows[dir]
		var w: Array = m["walk"]
		var a: Array = m["attack"]
		var wf := []
		for i in range(w[0], w[1]):
			wf.append([i, r])
		var af := []
		for i in range(a[0], a[1]):
			af.append([i, r])
		anims["idle_" + dir] = {"frames": [wf[0]], "fps": 1}
		anims["walk_" + dir] = {"frames": wf, "fps": 8}
		anims["attack_" + dir] = {"frames": af, "fps": af.size() / 0.32, "loop": false}
	img.save_png(_out("sprites/%s.png" % key))
	var sc: float = m.get("scale", 0.8)
	_save_json(_out("sprites/%s.json" % key), {"sheet": key + ".png", "frame_size": [s, s],
		"offset": [0, -s * 0.36], "scale": sc, "head_y": -s * 0.6 * sc, "animations": anims})
	print("  monster ", key)


# ---------------------------------------------------------------- world

func _build_world() -> void:
	DirAccess.make_dir_recursive_absolute(_out("world"))
	var tiles := src + "/lpc_base_assets/LPC Base Assets/tiles/"
	# terrain atlas: 96x192 autotile blocks side by side
	var blocks := ["grass.png", "grassalt.png", "dirt.png", "water.png"]
	var atlas := Image.create(96 * blocks.size() + 32, 192, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in blocks.size():
		var b := _img(tiles + blocks[i])
		atlas.blit_rect(b, Rect2i(0, 0, 96, 192), Vector2i(i * 96, 0))
	# bridge planks (a 32x32 cut from the bridge sheet) in the last column
	var br := _img(tiles + "bridges.png")
	if br:
		atlas.blit_rect(br, Rect2i(112, 140, 32, 32), Vector2i(96 * blocks.size(), 0))
	atlas.save_png(_out("world/terrain.png"))

	# trees: every separate tree on the sheet becomes a prop
	var trees := _img(src + "/lpc-trees/lpc-trees/trees-green.png")
	var props := []
	# islands on the sheet that are several objects stuck together
	var skip := [Vector2i(65, 0), Vector2i(256, 0), Vector2i(320, 0)]
	for r in _components(trees):
		if r.position in skip:
			continue
		if r.size.x >= 56 and r.size.x <= 150 and r.size.y >= 70 and r.size.y <= 170:
			props.append({"kind": "tree", "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
	trees.save_png(_out("world/trees.png"))
	var rocks := _img(tiles + "rock.png")
	rocks.save_png(_out("world/rocks.png"))
	props.append({"kind": "rock", "sheet": "rocks.png", "rect": [0, 0, 32, 32]})
	props.append({"kind": "rock", "sheet": "rocks.png", "rect": [32, 0, 32, 32]})
	_save_json(_out("world/props.json"), {"props": props})
	print("  world: terrain atlas, %d props" % props.size())


func _components(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes := []
	for y in h:
		for x in w:
			if seen[y * w + x] == 1 or img.get_pixel(x, y).a < 0.1:
				continue
			var r := Rect2i(x, y, 0, 0)
			var stack := [Vector2i(x, y)]
			seen[y * w + x] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				r = r.expand(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var i := q.y * w + q.x
					if seen[i] == 0 and img.get_pixel(q.x, q.y).a >= 0.1:
						seen[i] = 1
						stack.append(q)
			r.size += Vector2i(1, 1)
			boxes.append(r)
	return boxes
