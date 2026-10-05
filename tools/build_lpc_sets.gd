extends SceneTree
## Builds Godmarrow-format sprite sets (art/sprites/<kind>.png + .json) from free LPC art, for the top-down
## Secret of Mana view. Also writes art/sprites/skins.json, mapping every monster kind, NPC and minion onto one of
## the LPC looks built here.
##
##   LPC_SRC=/path/to/packs godot --headless --path . --script res://tools/build_lpc_sets.gd
##
## LPC_SRC holds: lpcgen/spritesheets (Universal LPC Spritesheet Character Generator), lpc-monsters/lpc-monsters.
## Credits: CREDITS.md.

const F := 64          # LPC frame size
const K := 2           # export scale (nearest): an LPC figure stands ~1.5 yards at 64 px a yard
const ROW := {"up": 0, "left": 1, "down": 2, "right": 3}
const VIEWS := {"down": "down", "up": "up", "side": "right"}
const FRAMES := {"walk": 9, "slash": 6, "thrust": 8, "spellcast": 7, "shoot": 13, "hurt": 6}

const PALE := [0.93, 0.9, 0.96, 0.65]
const ROBE := [0.24, 0.19, 0.3, 1.0]
const CAPE := [0.3, 0.2, 0.36, 1.0]
const DARK := [0.17, 0.15, 0.2, 1.0]
const ASH := [0.5, 0.5, 0.52, 1.0]
const BROWN_SKIN := [0.42, 0.27, 0.18, 0.92]

const STAFF_BG := ["weapon/magic/simple/background/{a}/simple.png", null]
const STAFF_FG := ["weapon/magic/simple/foreground/{a}/simple.png", null]
const SPEAR_BG := ["weapon/polearm/spear/background/{a}/spear.png", null]
const SPEAR_FG := ["weapon/polearm/spear/foreground/{a}/spear.png", null]
const BOW_BG := ["weapon/ranged/bow/normal/universal/background/{a}/normal.png", null]
const BOW_FG := ["weapon/ranged/bow/normal/universal/foreground/{a}/normal.png", null]

# layered humanoids: attack = the LPC animation used for blows; layers bottom to top, tint [r,g,b,mix] or null
const HUMANOIDS := {
	"ossumancer": {"attack": "slash", "layers": [["cape/tattered/bg/{a}.png", CAPE], STAFF_BG,
		["body/bodies/male/{a}.png", PALE], ["legs/pants/male/{a}.png", DARK],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", ROBE], ["cape/tattered/fg/{a}.png", CAPE],
		["head/heads/human/male_gaunt/{a}.png", PALE], ["hair/long/adult/{a}.png", [0.95, 0.95, 0.97, 1.0]], STAFF_FG]},
	"animancer": {"attack": "spellcast", "layers": [STAFF_BG, ["body/bodies/male/{a}.png", null],
		["legs/pants/male/{a}.png", [0.25, 0.27, 0.33, 1.0]], ["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.45, 0.52, 0.62, 1.0]],
		["head/heads/human/male/{a}.png", null], ["hat/cloth/hood/adult/{a}.png", [0.55, 0.62, 0.72, 1.0]], STAFF_FG]},
	"hemomancer": {"attack": "slash", "layers": [["cape/tattered/bg/{a}.png", [0.3, 0.22, 0.2, 1.0]],
		["body/bodies/male/{a}.png", BROWN_SKIN], ["legs/pants/male/{a}.png", [0.22, 0.18, 0.16, 1.0]],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.36, 0.26, 0.22, 1.0]], ["cape/tattered/fg/{a}.png", [0.3, 0.22, 0.2, 1.0]],
		["head/heads/human/male/{a}.png", BROWN_SKIN]]},
	"miasmancer": {"attack": "spellcast", "layers": [["cape/tattered/bg/{a}.png", [0.28, 0.33, 0.26, 1.0]], STAFF_BG,
		["body/bodies/male/{a}.png", null], ["legs/pants/male/{a}.png", DARK],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.33, 0.38, 0.3, 1.0]], ["cape/tattered/fg/{a}.png", [0.28, 0.33, 0.26, 1.0]],
		["head/heads/human/male/{a}.png", null], ["hat/cloth/hood/adult/{a}.png", [0.3, 0.34, 0.28, 1.0]], STAFF_FG]},
	"monk": {"attack": "slash", "layers": [["body/bodies/male/{a}.png", null], ["legs/pants/male/{a}.png", [0.5, 0.42, 0.3, 1.0]],
		["head/heads/human/male/{a}.png", null]]},
	# NPCs
	"npc_vendor": {"attack": "slash", "layers": [["body/bodies/male/{a}.png", null], ["legs/pants/male/{a}.png", [0.35, 0.3, 0.25, 1.0]],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.55, 0.45, 0.3, 1.0]], ["head/heads/human/male/{a}.png", null],
		["hair/long/adult/{a}.png", [0.35, 0.28, 0.2, 1.0]]]},
	"npc_giver": {"attack": "slash", "layers": [["body/bodies/male/{a}.png", null], ["legs/pants/male/{a}.png", DARK],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.4, 0.4, 0.45, 1.0]], ["head/heads/human/male_gaunt/{a}.png", null],
		["hat/cloth/hood/adult/{a}.png", [0.4, 0.38, 0.35, 1.0]]]},
	"npc_smith": {"attack": "slash", "layers": [["body/bodies/male/{a}.png", null], ["legs/armour/plate/male/{a}.png", ASH],
		["torso/armour/plate/male/{a}.png", ASH], ["head/heads/human/male/{a}.png", null]]},
	"npc_healer": {"attack": "spellcast", "layers": [["body/bodies/male/{a}.png", null], ["legs/pants/male/{a}.png", [0.8, 0.78, 0.72, 1.0]],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.82, 0.8, 0.74, 1.0]], ["head/heads/human/male/{a}.png", null],
		["hat/cloth/hood/adult/{a}.png", [0.82, 0.8, 0.74, 1.0]]]},
	"npc_stranger": {"attack": "slash", "layers": [["cape/tattered/bg/{a}.png", DARK], ["body/bodies/male/{a}.png", PALE],
		["legs/pants/male/{a}.png", DARK], ["torso/clothes/longsleeve/longsleeve/male/{a}.png", DARK],
		["cape/tattered/fg/{a}.png", DARK], ["head/heads/human/male_gaunt/{a}.png", PALE], ["hat/cloth/hood/adult/{a}.png", DARK]]},
	# creatures
	"lpc_zombie": {"attack": "slash", "layers": [["body/bodies/zombie/{a}/zombie.png", null], ["head/heads/zombie/adult/{a}.png", null]]},
	"lpc_drowned": {"attack": "slash", "layers": [["body/bodies/zombie/{a}/zombie.png", [0.45, 0.6, 0.62, 0.7]],
		["head/heads/zombie/adult/{a}.png", [0.45, 0.6, 0.62, 0.7]]]},
	"lpc_ashen": {"attack": "slash", "layers": [["body/bodies/zombie/{a}/zombie.png", [0.55, 0.53, 0.5, 0.8]],
		["head/heads/zombie/adult/{a}.png", [0.55, 0.53, 0.5, 0.8]]]},
	"lpc_skeleton": {"attack": "thrust", "layers": [SPEAR_BG, ["body/bodies/skeleton/{a}.png", null],
		["head/heads/skeleton/adult/{a}.png", null], SPEAR_FG]},
	"lpc_skeleton_bow": {"attack": "shoot", "layers": [BOW_BG, ["body/bodies/skeleton/{a}.png", null],
		["head/heads/skeleton/adult/{a}.png", null], BOW_FG]},
	"lpc_skeleton_mage": {"attack": "spellcast", "layers": [STAFF_BG, ["body/bodies/skeleton/{a}.png", null],
		["head/heads/skeleton/adult/{a}.png", null], ["hat/cloth/hood/adult/{a}.png", CAPE], STAFF_FG]},
	"lpc_skeleton_brute": {"attack": "slash", "layers": [["body/bodies/skeleton/{a}.png", [0.85, 0.82, 0.74, 0.5]],
		["head/heads/skeleton/adult/{a}.png", [0.85, 0.82, 0.74, 0.5]]]},
	"lpc_cultist": {"attack": "spellcast", "layers": [STAFF_BG, ["body/bodies/male/{a}.png", ASH], ["legs/pants/male/{a}.png", DARK],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.28, 0.25, 0.22, 1.0]], ["head/heads/human/male_gaunt/{a}.png", ASH],
		["hat/cloth/hood/adult/{a}.png", [0.26, 0.23, 0.2, 1.0]], STAFF_FG]},
	"lpc_crone": {"attack": "spellcast", "layers": [["cape/tattered/bg/{a}.png", [0.25, 0.22, 0.28, 1.0]], ["body/bodies/male/{a}.png", [0.6, 0.62, 0.5, 0.8]],
		["torso/clothes/longsleeve/longsleeve/male/{a}.png", [0.25, 0.22, 0.28, 1.0]], ["cape/tattered/fg/{a}.png", [0.25, 0.22, 0.28, 1.0]],
		["head/heads/human/male_gaunt/{a}.png", [0.6, 0.62, 0.5, 0.8]], ["hair/long/adult/{a}.png", [0.6, 0.6, 0.62, 1.0]]]},
	"lpc_knight": {"attack": "thrust", "layers": [SPEAR_BG, ["body/bodies/male/{a}.png", null], ["legs/armour/plate/male/{a}.png", [0.35, 0.36, 0.4, 0.8]],
		["torso/armour/plate/male/{a}.png", [0.35, 0.36, 0.4, 0.8]], ["head/heads/human/male/{a}.png", null],
		["hat/helmet/armet/adult/{a}.png", [0.35, 0.36, 0.4, 0.8]], SPEAR_FG]},
	"lpc_ghoul_pale": {"attack": "slash", "layers": [["body/bodies/male/{a}.png", [0.75, 0.75, 0.7, 0.9]],
		["legs/pants/male/{a}.png", [0.3, 0.27, 0.25, 1.0]], ["head/heads/human/male_gaunt/{a}.png", [0.75, 0.75, 0.7, 0.9]]]},
}

# single-sheet LPC monsters: file, cell size, walk/attack frame ranges per row, rows by direction, tint, scale
const SHEETS := {
	"lpc_slime": {"file": "slime.png", "size": 64, "walk": [0, 4], "attack": [4, 6], "tint": [0.6, 0.7, 0.45, 0.85]},
	"lpc_bloat": {"file": "slime.png", "size": 64, "walk": [0, 4], "attack": [4, 6], "tint": [0.7, 0.62, 0.55, 0.85], "k": 3},
	"lpc_ghost": {"file": "ghost.png", "size": 64, "walk": [0, 3], "attack": [4, 6], "tint": [0.7, 0.75, 0.82, 0.8]},
	"lpc_wisp": {"file": "ghost.png", "size": 64, "walk": [0, 3], "attack": [4, 6], "tint": [0.75, 0.88, 1.0, 0.85]},
	"lpc_worm": {"file": "big_worm.png", "size": 64, "walk": [0, 3], "attack": [3, 6], "tint": [0.6, 0.5, 0.48, 0.7]},
	"lpc_leech": {"file": "small_worm.png", "size": 64, "walk": [0, 4], "attack": [4, 8], "tint": [0.45, 0.32, 0.35, 0.7]},
	"lpc_bat": {"file": "bat.png", "size": 64, "walk": [0, 3], "attack": [3, 7], "tint": [0.6, 0.57, 0.52, 0.85]},
	"lpc_eye": {"file": "eyeball.png", "size": 64, "walk": [0, 3], "attack": [3, 7], "tint": null},
	"lpc_pyre": {"file": "pumpking.png", "size": 64, "walk": [0, 3], "attack": [3, 6], "tint": null},
	"lpc_trunk": {"file": "man_eater_flower.png", "size": 128, "walk": [0, 3], "attack": [3, 6], "tint": [0.45, 0.4, 0.32, 0.7], "k": 1,
		"rows": {"up": 2, "left": 2, "down": 2, "right": 2}},
}

# which look stands in for each sprite kind the game asks for (anything not listed falls to the rules in _guess)
const SKINS := {
	"ossumancer": "ossumancer", "ossuarch_hd": "ossumancer", "animancer": "animancer", "mystic_hd": "animancer",
	"hemomancer": "hemomancer", "miasmancer": "miasmancer", "keeper_hd": "miasmancer", "monk": "monk",
	"npc_vendor": "npc_vendor", "npc_giver": "npc_giver", "npc_smith": "npc_smith", "npc_stash": "npc_vendor",
	"npc_healer": "npc_healer", "npc_stranger": "npc_stranger", "kneeler": "lpc_cultist",
	"hollow": "lpc_zombie", "hound": "lpc_ghoul_pale", "archer": "lpc_skeleton_bow", "caster": "lpc_cultist",
	"bloat": "lpc_bloat", "bloatling": "lpc_slime", "knight": "lpc_knight", "pyre": "lpc_pyre", "pyre@doused": "lpc_pyre",
	"bell": "lpc_ghost", "worm": "lpc_worm", "moth": "lpc_bat", "moth_saint": "lpc_bat", "boss": "lpc_knight",
	"drowned": "lpc_drowned", "leech": "lpc_leech", "bogwitch": "lpc_crone", "marrow": "lpc_skeleton_brute",
	"ossarcher": "lpc_skeleton_bow", "matron": "lpc_crone", "hbone": "lpc_skeleton", "hflesh": "lpc_zombie",
	"hbreath": "lpc_ghost", "hhollow": "lpc_zombie", "wraith": "lpc_ghost", "stalker_crone": "lpc_crone",
	"trunk_thing": "lpc_trunk", "chorister": "lpc_cultist", "veinworm_elder": "lpc_worm", "swarmling": "lpc_leech",
	"skeleton_bow": "lpc_skeleton_bow", "skeleton_mage": "lpc_skeleton_mage", "skeleton_shield": "lpc_skeleton",
	"skeleton_halberd": "lpc_skeleton", "skeleton_flail": "lpc_skeleton_brute", "skeleton_greatsword": "lpc_skeleton_brute",
	"colossus_shield": "lpc_skeleton_brute", "colossus_flail": "lpc_skeleton_brute", "colossus_scythe": "lpc_skeleton_brute",
	"colossus_swords": "lpc_skeleton_brute", "flesh_golem": "lpc_ashen", "flesh_golem_gorged": "lpc_ashen",
	"iron_golem_axe": "lpc_knight", "iron_golem_flail": "lpc_knight", "iron_golem_sword": "lpc_knight",
	"iron_golem_axe_noshield": "lpc_knight", "iron_golem_flail_noshield": "lpc_knight", "iron_golem_sword_noshield": "lpc_knight",
	"wisp_beam": "lpc_wisp", "wisp_prism": "lpc_wisp", "wisp_rev": "lpc_wisp", "stone_buddha": "lpc_cultist",
	"mirror_sister": "lpc_crone",
}

var src := ""


func _init() -> void:
	src = OS.get_environment("LPC_SRC")
	if src == "" or not DirAccess.dir_exists_absolute(src):
		push_error("Set LPC_SRC to the folder with the LPC packs")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs("res://art/sprites"))
	for kind in HUMANOIDS:
		_humanoid(kind, HUMANOIDS[kind])
	for kind in SHEETS:
		_sheet(kind, SHEETS[kind])
	_skins()
	print("build_lpc_sets: %d humanoids, %d creature sheets" % [HUMANOIDS.size(), SHEETS.size()])
	quit()


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)


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
			img.set_pixel(x, y, p.lerp(Color(tc.r * k, tc.g * k, tc.b * k, p.a), mix))


func _compose(recipe: Dictionary, lpc_anim: String) -> Image:
	var n: int = FRAMES[lpc_anim]
	var rows := 1 if lpc_anim == "hurt" else 4
	var comp := Image.create(n * F, rows * F, false, Image.FORMAT_RGBA8)
	comp.fill(Color(0, 0, 0, 0))
	for layer in recipe["layers"]:
		var img := _img(src + "/lpcgen/spritesheets/" + String(layer[0]).replace("{a}", lpc_anim))
		if img == null:
			continue
		_tint(img, layer[1])
		comp.blend_rect(img, Rect2i(0, 0, min(img.get_width(), n * F), min(img.get_height(), rows * F)), Vector2i.ZERO)
	return comp


## Collects frames as [anim, view, Image] and writes the atlas + json in the game's format.
class Builder:
	var frames: Array = []
	var cell := 0
	var foot := Vector2.ZERO

	func add(anim: String, view: String, img: Image) -> void:
		frames.append([anim, view, img])

	func save(kind: String, fps: Dictionary, extra_meta: Dictionary) -> void:
		var cols := 16
		var rows := int(ceil(frames.size() / float(cols)))
		var sheet := Image.create(cols * cell, max(1, rows) * cell, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0, 0))
		var idx := {}
		var counts := {}
		var anims := {}
		for i in frames.size():
			var f: Array = frames[i]
			var x := (i % cols) * cell
			var y := (i / cols) * cell
			sheet.blit_rect(f[2], Rect2i(0, 0, cell, cell), Vector2i(x, y))
			var key := "%s/%s" % [f[0], f[1]]
			var n: int = counts.get(key, 0)
			counts[key] = n + 1
			idx["%s/%d" % [key, n]] = [0, x, y, cell, cell, -foot.x, -foot.y]
			if not anims.has(f[0]):
				anims[f[0]] = {"frames": 0, "views": []}
			if not f[1] in anims[f[0]]["views"]:
				anims[f[0]]["views"].append(f[1])
			anims[f[0]]["frames"] = max(anims[f[0]]["frames"], n + 1)
		sheet.save_png(ProjectSettings.globalize_path("res://art/sprites/%s.png" % kind))
		var meta := {"kind": kind, "source": "lpc", "anims": anims, "fps": fps}
		meta.merge(extra_meta)
		var f := FileAccess.open(ProjectSettings.globalize_path("res://art/sprites/%s.json" % kind), FileAccess.WRITE)
		f.store_string(JSON.stringify({"sheets": ["%s.png" % kind], "idx": idx, "meta": meta}))
		f.close()


func _frame(src_img: Image, col: int, row: int, size: int, k: int) -> Image:
	var fr := src_img.get_region(Rect2i(col * size, row * size, size, size))
	fr.resize(size * k, size * k, Image.INTERPOLATE_NEAREST)
	return fr


func _humanoid(kind: String, r: Dictionary) -> void:
	var b := Builder.new()
	b.cell = F * K
	b.foot = Vector2(32, 61) * K
	var walk := _compose(r, "walk")
	var atk_name: String = r["attack"]
	var atk := _compose(r, atk_name)
	var cast := _compose(r, "spellcast")
	var thrust := _compose(r, "thrust") if atk_name != "thrust" else atk
	var hurt := _compose(r, "hurt")
	var na: int = FRAMES[atk_name]
	var half: int = max(1, na / 2)
	for view in VIEWS:
		var row: int = ROW[VIEWS[view]]
		b.add("idle", view, _frame(walk, 0, row, F, K))
		for i in range(1, 9):
			b.add("walk", view, _frame(walk, i, row, F, K))
		for i in range(1, 9, 2):
			b.add("dodge", view, _frame(walk, i, row, F, K))
			b.add("roll", view, _frame(walk, i, row, F, K))
		for i in half:
			b.add("wind", view, _frame(atk, i, row, F, K))
		for i in range(half, na):
			b.add("atk", view, _frame(atk, i, row, F, K))
		for i in na:
			b.add("heavy", view, _frame(atk, i, row, F, K))
		for i in FRAMES["thrust"]:
			b.add("atk2", view, _frame(thrust, i, row, F, K))
		for i in FRAMES["spellcast"]:
			b.add("cast", view, _frame(cast, i, row, F, K))
		b.add("parry", view, _frame(atk, 0, row, F, K))
	# LPC's hurt is one row: a fall. Hit = its first frames, death = the whole fall.
	for i in 2:
		b.add("hit", "down", _frame(hurt, i, 0, F, K))
	for i in 6:
		b.add("death", "down", _frame(hurt, i, 0, F, K))
		b.add("death_back", "down", _frame(hurt, i, 0, F, K))
	b.add("stun", "down", _frame(hurt, 1, 0, F, K))
	b.save(kind, {"idle": 2.0, "walk": 10.0, "dodge": 16.0, "roll": 16.0, "wind": 8.0, "atk": 14.0, "heavy": 14.0,
		"atk2": 18.0, "cast": 16.0, "parry": 1.0, "hit": 10.0, "death": 10.0, "death_back": 10.0, "stun": 1.0}, {"category": "lpc_humanoid"})
	print("  ", kind)


func _sheet(kind: String, m: Dictionary) -> void:
	var img := _img(src + "/lpc-monsters/lpc-monsters/" + String(m["file"]))
	if img == null:
		push_warning("missing " + str(m["file"]))
		return
	_tint(img, m.get("tint"))
	var s: int = m["size"]
	var k: int = m.get("k", K)
	var b := Builder.new()
	b.cell = s * k
	b.foot = Vector2(s * 0.5, s * 0.86) * k
	var rows: Dictionary = m.get("rows", ROW)
	var w: Array = m["walk"]
	var a: Array = m["attack"]
	for view in VIEWS:
		var row: int = rows[VIEWS[view]]
		b.add("idle", view, _frame(img, w[0], row, s, k))
		for i in range(w[0], w[1]):
			b.add("walk", view, _frame(img, i, row, s, k))
			b.add("dodge", view, _frame(img, i, row, s, k))
		b.add("wind", view, _frame(img, a[0], row, s, k))
		for i in range(a[0], a[1]):
			b.add("atk", view, _frame(img, i, row, s, k))
			b.add("heavy", view, _frame(img, i, row, s, k))
			b.add("cast", view, _frame(img, i, row, s, k))
		b.add("hit", view, _frame(img, a[0], row, s, k))
		b.add("parry", view, _frame(img, a[0], row, s, k))
		b.add("death", view, _frame(img, a[1] - 1, row, s, k))
		b.add("stun", view, _frame(img, w[0], row, s, k))
	b.save(kind, {"idle": 2.0, "walk": 8.0, "dodge": 12.0, "wind": 6.0, "atk": 10.0, "heavy": 10.0, "cast": 10.0,
		"hit": 8.0, "parry": 1.0, "death": 6.0, "stun": 1.0}, {"category": "lpc_creature"})
	print("  ", kind)


func _guess(kind: String) -> String:
	var rules := [["worm", "lpc_worm"], ["leech", "lpc_leech"], ["larva", "lpc_leech"], ["parasite", "lpc_leech"],
		["wraith", "lpc_ghost"], ["shade", "lpc_ghost"], ["silence", "lpc_ghost"], ["thought", "lpc_eye"], ["synapse", "lpc_eye"],
		["golem", "lpc_knight"], ["sentinel", "lpc_knight"], ["ribward", "lpc_skeleton_brute"], ["knight", "lpc_knight"],
		["blade", "lpc_knight"], ["moth", "lpc_bat"], ["kite", "lpc_bat"], ["flag", "lpc_bat"], ["tumor", "lpc_bloat"],
		["sow", "lpc_bloat"], ["husk", "lpc_ashen"], ["bloat", "lpc_bloat"], ["witch", "lpc_crone"], ["crone", "lpc_crone"],
		["priest", "lpc_cultist"], ["monk", "lpc_cultist"], ["pilgrim", "lpc_cultist"], ["chorister", "lpc_cultist"],
		["osteo", "lpc_skeleton"], ["marrow", "lpc_skeleton_brute"], ["bone", "lpc_skeleton"], ["archer", "lpc_skeleton_bow"],
		["leaper", "lpc_ghoul_pale"], ["stalker", "lpc_ghoul_pale"], ["sapper", "lpc_ashen"], ["corroder", "lpc_slime"],
		["borer", "lpc_worm"], ["null", "lpc_ghost"], ["chalk", "lpc_ashen"], ["calc", "lpc_knight"]]
	for r in rules:
		if kind.contains(r[0]):
			return r[1]
	return "lpc_zombie"


func _skins() -> void:
	var out := {"_about": "which LPC look stands in for each sprite kind (tools/build_lpc_sets.gd)"}
	var f := FileAccess.open("res://data/monsters.json", FileAccess.READ)
	var mon: Dictionary = JSON.parse_string(f.get_as_text())
	for kind in mon.get("kinds", {}):
		out[kind] = SKINS.get(kind, _guess(kind))
	for kind in SKINS:
		out[kind] = SKINS[kind]
	for kind in HUMANOIDS:
		out[kind] = kind
	for kind in SHEETS:
		out[kind] = kind
	var w := FileAccess.open(_abs("res://art/sprites/skins.json"), FileAccess.WRITE)
	w.store_string(JSON.stringify(out, "\t"))
	w.close()
