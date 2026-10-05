extends RefCounted
## The vows, the waystones and the world's memory of what was done (zz_quests.js, zz_voice.js, zd_world22.js).
## A static store: everything lives in static vars on this script, so it outlives every zone. Load it by path
## (`load("res://world/quests.gd")`) and call the static functions; world/objects.gd keeps it referenced.
## Save with to_dict() / from_dict().
##
## For the journal (J) the UI calls: journal(act) -> [{id, name, target, kind, state, state_text, desc, where, reward,
## progress, fulfilled}], max_act(), act_name(n). For the waystone panel: waystones(act) -> [{id, name, town, here}].

const ROMAN := ["", "I", "II", "III", "IV", "V"]
const ACT_NAME := ["", "Act I · The Ashen Moor", "Act II · The Bleached Barrens", "Act III · The Fen of Shog-Mire", "Act IV · The Heights of An-Vhar", "Act V · The Descent"]
const ACT_MLVL := [[0, 0], [1, 17], [18, 24], [24, 30], [30, 34], [34, 40]]
## Act I waystones (every town has one; about every other zone)
const A1_WP := ["moor", "hollow_wood", "fen", "crypt", "barrow", "cata1", "cata2", "root_deep", "sighing_ridge", "pilgrim_road", "drowned_village", "sunken_bog", "burnt_heath"]
const ELEMS := ["magic", "miasma", "blood", "void", "radiance", "fire", "cold", "poison"]

## kinds: zoneboss (a zone's own boss), kill (a named one placed in a zone), relic (take it), shrine (kneel and hold
## through two waves), captive (the keepers within 12 yd must fall first), seal (three seals open a vault), actboss
const QUESTS := [
	{"id": "a1_warden", "act": 1, "kind": "zoneboss", "zones": ["crypt"], "name": "The Carrion Warden", "target": "The Carrion Warden",
		"desc": "Beneath the Moor the Hollow Crypt keeps a warden who forgot what he guards. He eats what the Tithed bury. Go down into {Z} and let him stop.",
		"done": "Esk: 'Then the Tithed can bury their mothers again. Take this. It was his, and he will not want it.'", "rew": {"gold": 200, "item": "magic"}},
	{"id": "a1_lantern", "act": 1, "kind": "shrine", "zones": ["sighing_ridge", "moor"], "name": "The Sighing Lantern", "target": "The Sighing Lantern",
		"desc": "The bronze lantern at the crossing has stopped singing. Something drinks the light before it reaches the road. Kneel at it in {Z} and hold it until the drinkers are gone.",
		"done": "Esk: 'It sings again. Badly. It always sang badly. Here, a small truth for your trouble.'", "rew": {"skill": 1}},
	{"id": "a1_daughter", "act": 1, "kind": "captive", "zones": ["drowned_village", "fen"], "name": "The Widow's Daughter", "target": "Nell, the foreman's daughter",
		"desc": "The caravan-foreman died holding both his daughters' hands. One of them let go. She lives, and the drowned keep her in {Z}. Free her.",
		"done": "Nell: 'I let go, and I lived. Tell no one, and I will teach you to stand as he stood.'", "rew": {"stat": 3}},
	{"id": "a1_ink", "act": 1, "kind": "relic", "zones": ["cata1"], "name": "The Reader's Ink", "target": "The Reader's Book",
		"desc": "In the Reader's Bay of {Z} a book lies open, and the page is always in your hand. Bring it up before it finishes writing you.",
		"done": "Esk: 'Do not read it. I did, once. Keep it closed and let it keep you.'", "rew": {"item": "rare", "arcana": 1}},
	{"id": "a1_hesk", "act": 1, "kind": "kill", "zones": ["bogwitch_shack", "sunken_bog", "root_deep", "fen"], "name": "The Tallow-Mother", "target": "Tallow-Mother Hesk",
		"desc": "A bog-witch renders the drowned into candles in {Z}, and the candles walk. Put out Hesk, the Tallow-Mother, and the wicks with her.",
		"done": "Esk: 'Her candles went out all at once; I felt it in my teeth. Wear this ash. It remembers her fire and refuses it.'", "rew": {"res": 5}},
	{"id": "a1_matron", "act": 1, "kind": "actboss", "zones": ["cata2"], "name": "The Ossuary Matron", "target": "The Ossuary Matron",
		"desc": "At the bottom of the ossuary, where the monks struck something warm, the Matron counts the dead she has stood up. Go down into {Z}. End the count. The way down opens behind her.",
		"done": "The Stranger: 'Down. Always down. The Barrens are waiting, and they are very dry.'", "rew": {"gold": 400, "item": "rare"}},
]

const TOWN := {
	1: {"giver": "Warden-Crone Esk", "healer": "Sister Ysolde, Tallow-Nurse", "smith": "Brannoc of the Nail", "vendor": "Maren the Gravekeeper",
		"greet": "Esk: 'Another pilgrim. Good. The dead swore what they could not finish. Now you have. Your journal (J).'"},
}
const STRANGER_LINES := {
	1: ["The Stranger: 'You have found the Sighing Lantern? Good. Not all of them still sing.'",
		"The Stranger: 'Down. Always down. If a road here rises for long, it is lying to you.'",
		"The Stranger: 'Do not thank me. Thanks are a kind of debt, and the god counts debts.'"],
}
## town barks (zz_voice.js): act -> role -> lines. Act I: weary Tithed plain-speech; the Stranger in half-lines.
const BARKS := {
	1: {
		"vendor": ["Everything here was someone's. I only keep it until someone else needs it.",
			"Gold's no use to the dead. They sell cheap. I don't.",
			"Dig long enough on the Moor and you find a sword. Dig longer and you find its owner.",
			"I bury what I can't sell and sell what I can't bury. It evens out.",
			"Mind the ash on the goods. It isn't dust. It's the Moor.",
			"Past the white road is beyond the Pale. Their counting-men buy nothing and weigh everything.",
			"Ashwake keeps a wake every night. There is always someone owed one."],
		"healer": ["Hold still. The ash gets into wounds here, and it doesn't want to come out.",
			"I mended three pilgrims today. Two walked on. The third is you, again.",
			"Breathe out, slowly. The Breath is thin even here. Don't waste it on pain.",
			"I pray while I stitch. Not to the god. To the needle.",
			"There. You'll scar. Scars are how the body remembers it lived.",
			"Catch your breath. It's only lent, but the god isn't asking for it back tonight.",
			"Nothing here is done in cold blood. The ash sees to that."],
		"smith": ["Every nail on the Moor came from my forge or my father's. Most are in coffins.",
			"Iron's honest. It rusts where you can see it. Not like bone.",
			"Bring me what breaks. I'll tell you if it was ever worth mending.",
			"God-bone blunts a blade in a season. Mine hold a year. Best I've got.",
			"Hammer, fire, water. Same three prayers for forty years.",
			"The Ossa sent a skeleton crew for nails last spring. I mean that as plainly as it sounds.",
			"Strike while the iron's hot. Everything else on the Moor is warm already."],
		"stash": ["The lid is carved with a sleeping woman. She shifts a little as it opens.",
			"Cedar and tallow inside. Whatever you leave, it keeps.",
			"The chest is older than the camp. The camp was built around it.",
			"Scratched inside the lid: 'kept, and kept, and kept.'"],
		"giver": ["The dead leave vows the way the living leave debts. Someone pays them, in the end.",
			"I was a warden once. Now I send the young ones where I used to go.",
			"Come back with it done, or don't come back. Either way I'll light a candle.",
			"Hundred-Fingers blew his kangling at me once. I blew back. He hasn't tried since.",
			"The Moor is patient. I'm not. Go on.",
			"I've a bone to pick with the Pale Order. They keep counting mine.",
			"Bone-tired, they say. Here that's a trade, not a complaint."],
		"stranger": ["The ash is warm... you noticed. Good. Most never do.",
			"Keep the lantern on your left. The dead... prefer the right.",
			"You'll go down. Everyone who listens to me goes down.",
			"A pilgrim asked me the way once. I told her. I am... still sorry.",
			"Rest while the fire is yours. Fires change hands, here.",
			"Keep your chin up. The god's has been dripping eleven hundred years... and look, it holds.",
			"No sign of her. Neither hair nor... well. Hide. We stand on the hide."],
	},
}
## the greeting of the Hide: "godmarrow", said the way the old lands said good morrow. Heard as a blessing on the day
## and as the thing the god is still made of. Said once a day to a pilgrim, before whatever else is said.
const GREET := {
	"any": ["Godmarrow.", "Godmarrow to you.", "A godmarrow on you, pilgrim.", "Godmarrow. May it keep.",
		"Godmarrow. And a marrow worth the digging.", "Godmarrow. The bones are warm today."],
	"dusk": ["Godmarrow. Late for it, but it still counts.", "Godmarrow. What's left of it."],
	"night": ["Godmarrow. Or god-evening. The god won't mind which.", "Godmarrow, though it's dark. It's always marrow somewhere down."],
	"vendor": ["Godmarrow. Mind the ash on the goods.", "Godmarrow. Buying or burying?"],
	"healer": ["Godmarrow. Let's see how much of yours is left.", "Godmarrow. Sit. You're dripping on my floor."],
	"smith": ["Godmarrow. Iron's hot, and so's the god, somewhere under.", "Godmarrow. Bring it here and let me look."],
	"giver": ["Godmarrow. The dead have been asking after you.", "Godmarrow. A vow doesn't keep. The dead do."],
	"stranger": ["Godmarrow... an old word. Older than the ones who say it.", "Godmarrow. They used to mean the morning by it."],
}
## how the folk greet each order: plays on each order's own trade (blood, mirrors and thread, bone, breath and paper,
## the empty hand). Mixed into greet() by the hero's order.
const ORDER_GREET := {
	"hemomancer": ["Godmarrow, and good blood to you.", "Bleed easy, brother.",
		"No bad blood between us, I hope. You've enough of the other kind.", "In the pink, are we? You'd know better than me.",
		"Heart on your sleeve again. Put it back, there's a draught.", "First blood's free, they say. Not from your lot.",
		"Cut along now. Don't let me keep you."],
	"animancer": ["God-mirror to you. Forgive me, it's an old one.", "Hanging by a thread, pilgrim? Aren't we all.",
		"Mind your reflection. It minded you just now.", "You've a loose end. No, the other one.",
		"Seven winters' good fortune to you, glass-bearer.", "Keep your wits about you, and your dead about you too.",
		"Look sharp. Your mirrors do."],
	"ossumancer": ["Godmarrow. The marrow's the best of it, eh?", "Got a bone to pick? Pick one of ours, we've plenty.",
		"Chin up, spine straight. Though I see you've managed.", "Nothing to rattle you today, I hope.",
		"Bare bones of a welcome, but it's yours.", "You're a sight for sore sockets.", "Stand easy. Well. Stand, anyway."],
	"miasmancer": ["Bless you. Oh, you didn't sneeze. Bless you anyway.", "Don't hold your breath on my account.",
		"Godmarrow to you, and to all eight million.", "A breath of fresh air, you are. Near enough.",
		"Paper it over, that's what I always say.", "Take a breather. You've plenty of other folk's.",
		"Air your grievances elsewhere, Keeper. Kindly."],
	"monk": ["Godmarrow. Or god-nothing, as your lot has it.", "Nothing doing? Good. That's your trade, isn't it.",
		"Hands empty, bowl empty. Heart?", "Say nothing. I'll know what you mean.",
		"A fine day for it. Or night. You'd know which.", "Nothing ventured, nothing lost, eh, Hand?",
		"Out of the sun, Hand. You shade it just by standing there."],
}

## what the folk of each land say (heard now and then in the quiet, like the land's own whispers)
const LAND_SAYINGS := {
	"moor": ["Ash to ash, and the rest to the Moor.", "Every cloud has a cinder lining.",
		"Where there's smoke, there's a god still burning.", "Don't weep over spilt ash. There's always more coming down.",
		"Many hands make light work. The Moor took the light."],
	"fen": ["Still waters run deep. The drowned run deeper.", "Keep your head above water, and your name below it.",
		"A reed that bends is a reed that breathes.", "Water under the bridge is still water. Count what's in it.",
		"Don't wade where the fen won't say its name."],
	"wood": ["Can't see the dead for the trees.", "Out of the wood isn't out of the woods.",
		"Knock on wood. If it knocks back, walk faster.", "The root of the matter is always further down.",
		"Every trunk is somebody's."],
	"heath": ["No smoke without a saint.", "Playing with fire? The Pyre-Saints never stopped.",
		"Out of the kiln, into the fire.", "Burn the candle at both ends and the heath will light the middle.",
		"Strike while the saint is hot."],
	"under": ["Dead men tell no tales. The dead down here never stop.", "Grave news travels slow, but it gets there.",
		"One foot in the grave is one foot in the door.", "Let the sleeping dead lie. They seldom do.",
		"What goes down must come up."],
}
const LAND_OF := {"moor": "moor", "pilgrim_road": "moor", "ash_shore": "moor", "sighing_ridge": "moor", "broken_bridge": "moor",
	"fen": "fen", "sunken_bog": "fen", "drowned_village": "fen", "bogwitch_shack": "fen",
	"hollow_wood": "wood", "fern_gully": "wood", "tree_hollow": "wood", "hunter_cache": "wood",
	"burnt_heath": "heath", "fallen_watchtower": "heath"}
const LAND_NAME := {"moor": "a saying of the Moor", "fen": "a saying of the fen folk", "wood": "a saying of the woodfolk",
	"heath": "a saying of the heath", "under": "a saying of the diggers"}

## a folk saying for a place (indoors and underground: the diggers'), with who says it
static func land_saying(zid: String, outdoor: bool) -> Array:
	var land: String = LAND_OF.get(zid, "moor") if outdoor else "under"
	var pool: Array = LAND_SAYINGS[land]
	return [LAND_NAME[land], pool[randi() % pool.size()]]

const WAYSTONE := {1: ["Chalked Waystone", "Kindled by pilgrims. Touch it, and every lit waystone on the Hide knows your step."]}
## inscriptions for the lanterns the builders named well (Act I), and a pool for the rest, picked by name
const LAN_INSCR := {
	"Lantern Camp": "Maren's lantern. It was the first lit on the Moor after the fall, and never since put out.",
	"The Sighing Lantern": "It hums through its cracked bell when the Last Breath is up. Not all of them still sing.",
	"The Widow's Stumps": "Three warm stumps. A father's hands and two daughters' hands, never let go.",
	"The Broken Kneeler": "Halved by something falling, the night the god died. Nobody has moved the halves.",
	"Ashwake Milestone": "Chalked each year by Villa Llaga's penitents. This year's chalk is still fresh.",
	"Ashwake Waystone": "Four hundred paces from the last. Four hundred to the next. Down, always.",
	"The Empty Reliquary Milestone": "Sister Un's box rested here on its way below. No dust settles where it stood.",
	"The Counting Wall": "A hundred and eight to a group. Add one mark, if you like. Everyone does.",
	"The Reed That Points Home": "It turns to face the village you were born in. It is turning now.",
	"The Kneeling Arch": "It leans forty degrees and never falls further. The boatmen trust it with their sleep.",
	"The Buried Bell": "Under the turf, a bell. Under the bell, the tower that fell to keep it.",
	"Sunken Chapel": "The chapel went under with its lamps lit. This is the one that came back up.",
}
const LAN_POOL := {1: ["I burned for a mother who does not know I am still burning.", "Forty nights. Fourteen. Four. It is all the same to a wick.",
	"If you go into the dark, take some of me. If you do not come back, I burn alone.", "The ash remembers you. Do not ask what it remembers.",
	"Chalk on the post, renewed each year by hands from Villa Llaga."]}
## the gods of the altars and their Heralds (zd_world22.js)
const GODS := {
	"bone": {"name": "Old Upright", "herald": "The Marrow Pontiff", "rgb": Color8(232, 226, 208), "mon": "hbone"},
	"flesh": {"name": "the Red Mother", "herald": "The Wet Nurse", "rgb": Color8(196, 150, 150), "mon": "hflesh"},
	"breath": {"name": "the Last Breath", "herald": "The Long Exhale", "rgb": Color8(180, 225, 255), "mon": "hbreath"},
	"hollow": {"name": "the Hush", "herald": "A Silent One", "rgb": Color8(150, 110, 200), "mon": "hhollow"},
}
const SHRINE_NAMES := {"echo": "Shrine of Echoes", "wisp": "Shrine of the Wisp", "stone": "Shrine of Stone", "refill": "Refilling Shrine", "arcana": "A Hidden Shrine"}

## the run's state
static var s := {}
static var _bark_i := {}

static func fresh() -> Dictionary:
	return {"act": 1, "q": {}, "wp": {}, "wpn": {}, "res": 0, "life": 0, "ended": false, "seen": {}, "done": {},
		"objs": {}, "felled": {}, "lanterns": {}, "majors": 0, "act_open": {1: true}, "marks": {}}

static func state() -> Dictionary:
	if s.is_empty():
		s = fresh()
	return s

static func reset() -> void:
	s = fresh()
	_bark_i.clear()

static func to_dict() -> Dictionary:
	return state().duplicate(true)

static func from_dict(d: Dictionary) -> void:
	s = fresh()
	for k in d:
		s[k] = d[k]

# ------------------------------------------------------------------ acts and zones
static func act_of(id: String) -> int:
	if id == "":
		return 1
	var re := RegEx.create_from_string("^a(\\d)_")
	var m := re.search(id)
	if m:
		return clampi(int(m.get_string(1)), 1, 5)
	var re2 := RegEx.create_from_string("^qvault_(\\d)")
	var m2 := re2.search(id)
	if m2:
		return int(m2.get_string(1))
	if id.contains("scar") or id.contains("nihl"):
		return 5
	return 1

static func lair_of(n: int) -> String:
	return "cata2" if n == 1 else "a%d_lair" % n

static func is_town(id: String) -> bool:
	return id == "moor" or (id.begins_with("a") and id.ends_with("_town"))

static func zone_exists(id: String) -> bool:
	return Data.zone_index().get("zones", {}).has(id)

static func zone_name(id: String) -> String:
	var z: Dictionary = Data.zone_index().get("zones", {}).get(id, {})
	if z.has("name"):
		return z["name"]
	if state()["wpn"].has(id):
		return s["wpn"][id]
	return id.capitalize()

static func act_name(n: int) -> String:
	return ACT_NAME[clampi(n, 0, 5)]

static func max_act() -> int:
	return maxi(1, int(state()["act"]))

# ------------------------------------------------------------------ vows
static func quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == id:
			return q
	return {}

static func st(id: String) -> Dictionary:
	return state()["q"].get(id, {})

static func resolve_zone(q: Dictionary) -> String:
	for z in q.get("zones", []):
		if zone_exists(z):
			return z
	var zs: Array = q.get("zones", [])
	return lair_of(int(q["act"])) if zs.is_empty() else zs[zs.size() - 1]

## write the act's vows into the journal (on reaching the act). Returns how many were new.
static func activate(n: int) -> int:
	var fresh_n := 0
	for q in QUESTS:
		if int(q["act"]) != n:
			continue
		if not state()["q"].has(q["id"]):
			s["q"][q["id"]] = {"s": 1, "n": 0, "z": resolve_zone(q)}
			fresh_n += 1
	return fresh_n

static func is_done(id: String) -> bool:
	return int(st(id).get("s", 0)) == 3

static func _with_the(n: String) -> String:
	if n.begins_with("The "):
		return "the " + n.substr(4)
	if n.begins_with("the ") or n.begins_with("a ") or n.begins_with("an "):
		return n
	return "the " + n

static func desc(q: Dictionary) -> String:
	var e := st(q["id"])
	var zn := _with_the(zone_name(e["z"])) if e.get("z", "") != "" else "the deep places"
	return String(q["desc"]).replace("{Z}", zn)

static func reward_text(r: Dictionary) -> String:
	var o: Array[String] = []
	if r.has("skill"):
		o.append("%d skill point%s" % [r["skill"], "s" if int(r["skill"]) > 1 else ""])
	if r.has("stat"):
		o.append("%d stat points" % r["stat"])
	if r.has("arcana"):
		o.append("%d Arcana" % r["arcana"])
	if r.has("res"):
		o.append("+%d%% to every resistance" % r["res"])
	if r.has("life"):
		o.append("+%d life" % r["life"])
	if r.has("item"):
		o.append("a %s relic" % r["item"])
	if r.has("gold"):
		o.append("%d gold" % r["gold"])
	return ", ".join(o)

## the journal's rows for one act
static func journal(act: int) -> Array:
	var out := []
	for q in QUESTS:
		if int(q["act"]) != act:
			continue
		var e := st(q["id"])
		var heard := not e.is_empty()
		var sv := int(e.get("s", 0))
		var row := {"id": q["id"], "kind": q["kind"], "name": q["name"] if heard else "? ? ?", "target": q["target"],
			"state": "unheard" if not heard else ("fulfilled" if sv == 3 else ("opened" if sv == 2 else "open")),
			"fulfilled": sv == 3, "desc": desc(q) if heard else "You have not yet sworn this vow.",
			"where": zone_name(e["z"]) if heard and e.get("z", "") != "" else "", "reward": "Reward: " + reward_text(q["rew"]), "progress": ""}
		row["state_text"] = row["state"]
		if q["kind"] == "seal" and sv < 3 and heard:
			var lit := 0
			for i in 3:
				if int(e.get("n", 0)) & (1 << i):
					lit += 1
			row["progress"] = "%d of 3 seals pressed" % lit
		out.append(row)
	return out

static func pending(act: int) -> int:
	var n := 0
	for q in QUESTS:
		if int(q["act"]) == act and not st(q["id"]).is_empty() and not is_done(q["id"]):
			n += 1
	return n

## fulfil an vow: rewards, the banner and the giver's line. `at` is where a relic reward drops.
static func complete(id: String, hero: Node, zone: Node, at: Vector2) -> bool:
	var q := quest(id)
	if q.is_empty():
		return false
	if not state()["q"].has(id):
		s["q"][id] = {"s": 1, "n": 0, "z": zone.id if zone else ""}
	var e: Dictionary = s["q"][id]
	if int(e["s"]) == 3:
		return false
	e["s"] = 3
	var r: Dictionary = q["rew"]
	var hst = hero.st if hero else null
	if hst:
		if r.has("gold"):
			hst.inv.gold += int(r["gold"])
			Bus.gold_changed.emit(hst.inv.gold)
		if r.has("skill"):
			hst.skill_points += int(r["skill"])
		if r.has("stat"):
			hst.attr_points += int(r["stat"])
		if r.has("arcana"):
			hst.arcana_points += int(r["arcana"])
		if r.has("res"):
			s["res"] = int(s["res"]) + int(r["res"])
			for el in ELEMS:
				hst.extra["res_" + el] = float(hst.extra.get("res_" + el, 0.0)) + float(r["res"])
		if r.has("life"):
			s["life"] = int(s["life"]) + int(r["life"])
			hst.extra["life"] = float(hst.extra.get("life", 0.0)) + float(r["life"])
			hst.hp = minf(hst.life_max(), hst.hp + float(r["life"]))
		if r.has("item"):
			var lvl := maxi(int(hst.level), int(ACT_MLVL[int(q["act"])][1])) + 2
			_reward_item(zone, at + Vector2(0, 0.6), lvl, String(r["item"]), hero)
		hero.stats_changed.emit()
	var W = _world()
	if W:
		if q["kind"] in ["zoneboss", "actboss"]:
			W.banner_later("THE VOW IS PAID", Color8(201, 164, 90), 3.2, 3.6, zone.id)   # after the FELLED banner
		else:
			W.banner("THE VOW IS PAID", Color8(201, 164, 90), 3.2)
		W.speak_line(String(q["done"]) + "   (" + reward_text(r) + ")", 7.0)
	if Bus.has_signal("quest_changed"):
		Bus.emit_signal("quest_changed", id)
	return true

static func _reward_item(zone: Node, at: Vector2, ilvl: int, want: String, hero: Node) -> void:
	if not ResourceLoader.exists("res://items/loot.gd"):
		return
	var L = load("res://items/loot.gd")
	# zz_quests qRollItem: roll until it meets the rarity (400 tries), dropped at your feet
	if L and L.has_method("roll_min") and L.has_method("drop_item"):
		var cls: String = hero.cls if hero and "cls" in hero else ""
		var it = L.roll_min(ilvl, 300.0, want, cls, 400)
		if it:
			L.drop_item(zone, at, it)

## the persistent world UI (world/objects/world_ui.gd), if one is up
static func _world() -> Object:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null:
		return null
	var n := ml.root.find_child("GodmarrowWorldUI", true, false)
	return n

# ------------------------------------------------------------------ kills: vows, bosses, Heralds
static func on_kill(m: Node, zone: Node, hero: Node) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var zid: String = zone.id
	var n := act_of(zid)
	var pk: String = m.pack
	# a named vow-target (its pack is "q<vow id>")
	if pk.begins_with("q") and m.rank == "unique":
		var qid := pk.substr(1)
		var q := quest(qid)
		if not q.is_empty() and q["kind"] == "kill" and not is_done(qid) and not st(qid).is_empty():
			complete(qid, hero, zone, m.tp)
	if m.boss:
		var first: bool = not state()["felled"].has(zid)
		state()["felled"][zid] = true
		var W0 = _world()
		if W0:
			W0.banner(str(m.info.get("name", "")).to_upper() + " FELLED" if str(m.info.get("name", "")) != "" else "FELLED", Color8(201, 164, 90), 3.6)
		# the boss's own gifts, once per pilgrim (checklist 16): the Warden +1 skill point, the Matron +2; each +1 Hollow
		# Token and +2 Arcana
		if first and hero and hero.st:
			var act_boss: bool = zid == lair_of(n)
			hero.st.skill_points += 2 if act_boss else 1
			hero.st.hollow_tokens += 1
			hero.st.arcana_points += 2
			Bus.say.emit("Something of it stays with you: %s, a Hollow Token, two Arcana." % ("two lessons" if act_boss else "a lesson"), 4.0)
			hero.stats_changed.emit()
		for q in QUESTS:
			var e := st(q["id"])
			if q["kind"] == "zoneboss" and e.get("z", "") == zid and int(e.get("s", 0)) != 3:
				complete(q["id"], hero, zone, m.tp)
		if zid == lair_of(n):
			act_done(n, m, hero, zone)

## an act's final boss has fallen: the way to the next act opens (recorded; Act II is not built yet)
static func act_done(n: int, m: Node, hero: Node, zone: Node) -> void:
	state()["act"] = maxi(int(s["act"]), mini(5, n + 1))
	s["act_open"][n + 1] = true
	s["done"]["boss:" + zone.id] = true
	for q in QUESTS:
		if int(q["act"]) == n and q["kind"] == "actboss":
			if not s["q"].has(q["id"]):
				s["q"][q["id"]] = {"s": 1, "n": 0, "z": zone.id}
			complete(q["id"], hero, zone, m.tp)
	if n >= 5:
		s["ended"] = true
	var W = _world()
	if W and n < 5:
		W.banner_later("THE WAY DOWN OPENS", Color8(201, 164, 90), 4.0, 3.4, zone.id)

# ------------------------------------------------------------------ waystones
static func wants_wp(zid: String) -> bool:
	if zid.begins_with("qvault_"):
		return false
	if is_town(zid):
		return true
	var n := act_of(zid)
	if n == 1:
		return A1_WP.has(zid)
	return zid != lair_of(n)

static func known_wp(zid: String) -> bool:
	return state()["wp"].has(zid)

## stand in a waystone and it learns you. Returns true the first time.
static func kindle_wp(zid: String) -> bool:
	if known_wp(zid):
		return false
	s["wp"][zid] = true
	s["wpn"][zid] = zone_name(zid)
	return true

## every kindled waystone of an act, towns first, then by name
static func waystones(act: int, here: String = "") -> Array:
	var ids := []
	for id in state()["wp"]:
		if act_of(id) == act and zone_exists(id):
			ids.append(id)
	ids.sort_custom(func(a, b):
		if is_town(a) != is_town(b):
			return is_town(a)
		return zone_name(a) < zone_name(b))
	return ids.map(func(id): return {"id": id, "name": zone_name(id), "town": is_town(id), "here": id == here})

static func kindle_all() -> void:
	for id in Data.zone_index().get("zones", {}):
		if wants_wp(id) and act_of(id) <= max_act():
			kindle_wp(id)

# ------------------------------------------------------------------ what the world remembers per zone
static func obj(zid: String, i: int) -> Dictionary:
	var o: Dictionary = state()["objs"]
	if not o.has(zid):
		o[zid] = {}
	if not o[zid].has(i):
		o[zid][i] = {}
	return o[zid][i]

static func felled(zid: String) -> bool:
	return state()["felled"].has(zid)

# ------------------------------------------------------------------ the voice
static func fnv(t: String) -> int:
	var h := 2166136261
	for i in t.length():
		h = h ^ t.unicode_at(i)
		h = (h * 16777619) & 0xffffffff
	return h

static func bark(n: int, role: String) -> String:
	var L: Array = BARKS.get(n, BARKS[1]).get(role, [])
	if L.is_empty():
		return ""
	var key := "%d:%s" % [n, role]
	var i: int
	if not _bark_i.has(key):
		i = randi() % L.size()
	else:
		i = (int(_bark_i[key]) + 1 + randi() % maxi(1, L.size() - 2)) % L.size()
	_bark_i[key] = i
	return L[i]

## a greeting, once a day per soul (the day's number from the clock); "" if already greeted today
static func greet(who: String, role: String) -> String:
	var day := int(Game.clock / maxf(1.0, Game.day_len))
	var key := "greet:" + who
	var st := state()
	if not st.has("seen"):
		st["seen"] = {}
	if int(st["seen"].get(key, -1)) == day:
		return ""
	st["seen"][key] = day
	var pool: Array = []
	pool.append_array(GREET["any"])
	pool.append_array(GREET.get(role, []))
	pool.append_array(GREET.get(role, []))      # their own words come oftener
	var og: Array = ORDER_GREET.get(Game.cls, [])
	pool.append_array(og)
	pool.append_array(og)                        # and they know an order when they see one
	var dk := Game.day_k()
	if dk < 0.2:
		pool.append_array(GREET["night"])
	elif dk < 0.8:
		pool.append_array(GREET["dusk"])
	return pool[randi() % pool.size()]

static func stranger_line(n: int) -> String:
	var L: Array = STRANGER_LINES.get(n, STRANGER_LINES[1])
	var key := "stranger%d" % n
	var i: int = (int(_bark_i.get(key, randi() % L.size())) + 1) % L.size()
	_bark_i[key] = i
	return L[i]

static func lantern_inscription(zid: String, o: Dictionary) -> String:
	if o.get("vInscr", "") != "":
		return o["vInscr"]
	var nm: String = o.get("name", "")
	if LAN_INSCR.has(nm):
		return LAN_INSCR[nm]
	var pool: Array = LAN_POOL.get(act_of(zid), LAN_POOL[1])
	return pool[fnv(zid + ":" + nm) % pool.size()]

## "Name: 'line'" -> [name, line]; anything else -> ["", text]
static func split_speech(t: String) -> Array:
	var re := RegEx.create_from_string("^([A-Z][^:'\"]{1,48}):\\s*['\"](.+?)['\"](\\s+\\(.*\\))?\\s*$")
	var m := re.search(t)
	if m:
		return [m.get_string(1), m.get_string(2) + (m.get_string(3) if m.get_string(3) != "" else "")]
	return ["", t]
