extends RefCounted
## Item tooltips as [text, Color] lines for the UI helper to draw (the web's itemLines + zz_voice's lore line).
## Order: name (rarity colour), base name (rare, unique), damage or armour, required level (red if too high),
## order lock, affix lines (blue), one lore line (rare, unique), sell value (at a vendor).

const COL_TEXT := Color("#d6d2c8")
const COL_DIM := Color("#a39d8c")
const COL_FAINT := Color("#6f6a79")
const COL_BAD := Color("#c8553d")
const COL_AFFIX := Color("#8b95ff")
const COL_LORE := Color("#a3977f")
const COL_GOLD := Color("#d9a441")

## one line of lore per base; the named uniques have their own (zz_voice.js LORE / LORE_U; the talons' line no
## longer names a bird, by the rule on animal words)
const LORE := {
	"wand": ["Carved from a finger that once pointed at the god, and was right.", "Bone remembers being a hand. It still wants to point."],
	"dagger": ["A tithe-knife. The blade is thin from all the giving.", "The knife that cuts the cord cuts the vow, the midwives say."],
	"staff": ["A pilgrim's staff, black with grave-dirt at the heel.", "It has walked further down than you. It knows the way."],
	"claw": ["Lacquered claws, black as a shrine-bell's tongue."],
	"talons": ["Hooked bone on a leather cuff, for those who take their tithe by hand."],
	"relic": ["The skull is warm. It is listening to you choose.", "Pilgrims carried relics to be carried. It has not decided about you."],
	"hood": ["Mourning cloth dyed in ash. It is never quite dry.", "Worn low, as the Tithed wear it, so the god cannot see who weeps."],
	"mask": ["The face beneath it was forgotten. The mask was not.", "Cut from a Warden's brow. It still sees what he saw."],
	"robe": ["Ash-woven, warm as the Moor. It remembers the last procession."],
	"mail": ["Grave mail. Every ring was once a wedding band.", "It has been buried twice. It came up both times."],
	"gloves": ["Wrappings from a Husk's hands. They are still closing, slowly.", "Take them off at the lantern. They are shy of the light."],
	"boots": ["The soles are worn to the shape of the down-road.", "Every step in them finishes a step someone else began."],
	"belt": ["Knotted a hundred and eight times, one for each thing you owe."],
	"amulet": ["A prayer in a locket, no longer addressed to anyone.", "Bell-yolk brass, cracked. It hums near the dead."],
	"ring": ["A ring from a finger that is still looking for it.", "Cold on the hand, warm on the heart. At night, the other way."],
	"wraps": ["Bound in sutras by a monk who would not strike first."],
	"iwraps": ["Each line of the sutra is a breath not wasted."],
	"spade": ["It has dug nine hundred graves, and one way out."],
	"shakujo": ["The rings chime to warn small things from underfoot. Nothing here is small."],
}
const LORE_U := {
	"Lanternkeeper's Hood": "Worn by those who never let the Sighing Lantern go dark.",
	"The Hollow Choir": "Three small voices, never quite finishing the note.",
	"Warden's Ribcage": "It was a Warden's. It still salutes when you pass another.",
	"Whisperbone": "It speaks when you are quiet. Stay quiet.",
	"Grave-Walkers": "They know the way down, and take it faster than you'd like.",
	"Knot of Sorrows": "Every knot a grief. Untie none.",
	"Crown of the Forgotten Epoch": "Swallowed before the god was born, and never digested.",
}
## stat texts the export leaves out (the three elements' "magic" came from the old lightning key)
const EXTRA_TEXT := {
	"magic": "+# Magic Damage to weapon attacks",
	"gf": "+#% Gold Found",
	"ltng": "+# Magic Damage to weapon attacks",
}

static func lore_for(it: Item) -> String:
	if it == null or it.potion != "" or (it.q != "rare" and it.q != "unique"):
		return ""
	if it.q == "unique" and LORE_U.has(it.name):
		return LORE_U[it.name]
	var l: Array = LORE.get(it.base, [])
	if l.is_empty():
		return ""
	return l[absi(hash(str(it.uid) + ":" + it.name)) % l.size()]

static func _res_name(hero) -> String:
	if hero != null and hero.st != null:
		return hero.st.res_name()
	return "Essence"

static func _tabs(hero) -> Array:
	var c: String = hero.cls if hero != null else Game.cls
	return Data.table("classes").get("classes", {}).get(c, {}).get("tabs", ["First", "Second", "Third"])

## the text of one stat, signed, in the world's words
static func stat_line(k: String, v: float, hero) -> String:
	var n := str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
	if k.begins_with("skt"):
		var tabs := _tabs(hero)
		var i := int(k.substr(3))
		var tab: String = tabs[i] if i < tabs.size() else "Tree"
		return "%s%s to %s Skills" % ["+" if v >= 0 else "", n, tab]
	var t: String = Data.table("items").get("stat_text", {}).get(k, EXTRA_TEXT.get(k, k + " #"))
	if k == "mana":
		t = t.replace("Maximum Essence", "Maximum " + _res_name(hero))
	if v < 0.0 and t.begins_with("+#"):
		return t.replace("+#", n)
	return t.replace("#", n)

static func lines(it: Item, hero, at_vendor: bool = false) -> Array:
	var L := []
	if it == null:
		return L
	L.append([it.name, it.color()])
	if it.potion != "":
		if it.potion == "hp":
			L.append(["It mends the body slowly, as all mending here is slow.", COL_DIM])
		else:
			L.append(["It fills the %s again, a swallow at a time." % _res_name(hero), COL_DIM])
		L.append(["Kept on the belt, drunk from it.", COL_FAINT])
		if at_vendor:
			L.append(["Sell value: %d gold" % it.sell_value(), COL_GOLD])
		return L
	if it.q == "rare" or it.q == "unique":
		L.append([it.base_name(), it.color()])
	if it.dmg != Vector2.ZERO:
		L.append(["Damage: %d to %d" % [int(it.dmg.x), int(it.dmg.y)], COL_TEXT])
	if it.armor > 0.0:
		L.append(["Armor: %d" % int(it.armor), COL_TEXT])
	var lvl: int = hero.st.level if hero != null and hero.st != null else 99
	if it.req > 1:
		L.append(["Required Level: %d" % it.req, COL_TEXT if lvl >= it.req else COL_BAD])
	var lock := it.class_lock()
	if lock != "":
		var nm: String = Data.table("classes").get("classes", {}).get(lock, {}).get("display_name", lock)
		var mine: bool = hero == null or hero.cls == lock
		L.append(["Borne only by the %s" % nm if not nm.begins_with("The ") else "Borne only by %s" % nm, COL_TEXT if mine else COL_BAD])
	for k in it.stats:
		L.append([stat_line(k, float(it.stats[k]), hero), COL_AFFIX])
	var lo := lore_for(it)
	if lo != "":
		L.append([lo, COL_LORE])
	if at_vendor:
		L.append(["Sell value: %d gold" % it.sell_value(), COL_GOLD])
	return L
