extends RefCounted
## The body board, the Inverted Triune (checklist 10; zz_arcana_web.js, zz_arcana_zbody.js, k_arcana.js).
## Each order's plate is a graph (data/board.json, exported from the web build): the gate (root), Minor knots (pegs and
## great knots, "notables") laid along the body's roads, and cards: Minor cards, Major Arcana (upright or reversed),
## the hybrids at the feet, the Hollow steps and the Void at the seat. v103 added the rungs between a page's Majors and
## the Outer Circle joining the pages, so a held Major is a crossroads.
##   Minor points: one each level from 2, plus gifts (minor_bonus). Every knot laid costs one.
##   Major points ("Arcana"): HeroStats.arcana_points, from bosses, guardians, Heralds, hidden shrines, vows. Every card
##   taken costs one. The Void opens after ten Majors are held.
##   Roads start at the gate and at every card held. A knot is reachable next to a laid knot or a held card; clicking a
##   far knot lays the cheapest road to it. A card is taken next to a laid knot or a held card.
##   Lifting: a leaf knot (nothing laid or held depends on it) for 10 + 5 x level gold. The Hollow Token returns all.
##   Majors are set upright ("u") or reversed ("r"); turning one is free at a lantern.

const VOID_GATE := 10
static var _data := {}

var cls := ""
var N := {}                  # id -> node {kind, x, y, stat, fx, name, area, lore, card, links: Array}
var laid := {}               # knot id -> true
var cards := {}              # card id -> "u" | "r"
var minor_bonus := 0
var both := ""               # The Unmade upright: one Major counts upright and reversed at once
var silence_zone := ""       # The Last Silence: the place it was spent this walk
var st                       # HeroStats
var _sums := {}
var _dirty := true

static func board() -> Dictionary:
	if _data.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/board.json"))
		_data = j if j is Dictionary else {"classes": {}, "arcana": {}}
	return _data

static func card_def(id: String) -> Dictionary:
	return board().get("arcana", {}).get(id, {})

func setup(stats, c: String) -> void:
	st = stats
	cls = c
	var b: Dictionary = board().get("classes", {}).get(c, {})
	N = b.get("nodes", {})
	_dirty = true

func plate() -> Dictionary:
	return board().get("classes", {}).get(cls, {}).get("plate", {})

func root_id() -> String:
	for id in N:
		if N[id]["kind"] == "root":
			return id
	return ""

# ------------------------------------------------------------------ points
func minor_earned() -> int:
	return maxi(0, int(st.level) - 1) + minor_bonus

func minor_spent() -> int:
	return laid.size()

func minor_avail() -> int:
	return minor_earned() - minor_spent()

func major_avail() -> int:
	return int(st.arcana_points)

func majors_held() -> int:
	var n := 0
	for id in cards:
		if card_def(id).get("kind", "") in ["major", "hybrid"]:
			n += 1
	return n

# ------------------------------------------------------------------ what can be reached
func is_knot(id: String) -> bool:
	return N.has(id) and N[id]["kind"] in ["peg", "notable"]

func is_card(id: String) -> bool:
	return N.has(id) and N[id]["kind"] == "card"

func anchors() -> Dictionary:
	var a := {}
	var r := root_id()
	if r != "":
		a[r] = true
	for id in cards:
		if N.has(id):
			a[id] = true
	return a

func _held(id: String, A: Dictionary) -> bool:
	return laid.has(id) or A.has(id)

func reachable(id: String) -> bool:
	if not N.has(id) or laid.has(id) or cards.has(id):
		return false
	var A := anchors()
	if A.has(id):
		return false
	for l in N[id]["links"]:
		if _held(l, A):
			return true
	return false

## the cheapest road from what is held to a knot: the knots not yet laid on it, nearest first ([] if none)
func road_to(id: String) -> Array:
	if not is_knot(id) or laid.has(id):
		return []
	var A := anchors()
	var par := {}
	var q: Array = []
	for a in A:
		par[a] = ""
		q.append(a)
	for t in laid:
		if not par.has(t):
			par[t] = ""
			q.append(t)
	var i := 0
	var found := false
	while i < q.size() and not found:
		var cur: String = q[i]
		i += 1
		for l in N[cur]["links"]:
			if par.has(l) or not is_knot(l):
				continue   # an untaken card is a wall on a road; a held one is already an anchor
			par[l] = cur
			if l == id:
				found = true
				break
			q.append(l)
	if not found:
		return []
	var path: Array = []
	var c := id
	while c != "" and not laid.has(c) and not A.has(c):
		path.push_front(c)
		c = par.get(c, "")
	return path

func lay(id: String) -> bool:
	var p := road_to(id)
	if p.is_empty() or p.size() > minor_avail():
		return false
	for k in p:
		laid[k] = true
	_changed()
	return true

func card_why_not(id: String) -> String:
	if not is_card(id):
		return "No card lies there."
	if cards.has(id):
		return ""
	var d := card_def(id)
	if d.get("kind", "") == "void" and majors_held() < VOID_GATE:
		return "The Void opens to one who holds ten Majors."
	if not reachable(id):
		return "No road reaches it yet."
	if major_avail() < 1:
		return "You have no Arcanum to lay."
	return ""

func take_card(id: String, orient: String = "u") -> bool:
	if card_why_not(id) != "":
		return false
	st.arcana_points -= 1
	cards[id] = orient if card_def(id).get("kind", "") in ["major", "hybrid", "void"] else "u"
	_changed()
	return true

## turn a held Major (free, at a lantern: the UI checks that)
func flip(id: String) -> bool:
	if not cards.has(id) or not card_def(id).has("rev"):
		return false
	cards[id] = "r" if cards[id] == "u" else "u"
	_changed()
	return true

# ------------------------------------------------------------------ lifting
func lift_cost() -> int:
	return 10 + 5 * int(st.level)

## a knot may be lifted only if everything else held still reaches the gate without it
func can_lift(id: String) -> bool:
	if not laid.has(id):
		return false
	var r := root_id()
	var seen := {r: true}
	var q: Array = [r]
	var i := 0
	while i < q.size():
		var cur: String = q[i]
		i += 1
		for l in N[cur]["links"]:
			if l == id or seen.has(l):
				continue
			if laid.has(l) or cards.has(l):
				seen[l] = true
				q.append(l)
	for k in laid:
		if k != id and not seen.has(k):
			return false
	for c in cards:
		if N.has(c) and not seen.has(c):
			return false
	return true

func lift(id: String) -> String:
	if not can_lift(id):
		return "Something you hold rests on it."
	if st.inv.gold < lift_cost():
		return "It costs %d gold to lift." % lift_cost()
	st.inv.gold -= lift_cost()
	laid.erase(id)
	_changed()
	return ""

func respec() -> void:
	st.arcana_points += cards.size()
	laid.clear()
	cards.clear()
	_changed()

# ------------------------------------------------------------------ the sums
func _changed() -> void:
	_dirty = true

func sum(k: String) -> float:
	if _dirty:
		_sums = sums()
		_dirty = false
	return float(_sums.get(k, 0.0))

func sums() -> Dictionary:
	var S := {}
	var ids: Array = laid.keys()
	var r := root_id()
	if r != "":
		ids.append(r)
	for id in ids:
		if not N.has(id):
			continue
		var fx = N[id].get("fx", {})
		if fx is Dictionary:
			for k in fx:
				S[k] = float(S.get(k, 0.0)) + float(fx[k])
	return S

## is a card held, and which way (for the skill books): aU upright, aR reversed, aM held at all
func aM(id: String) -> bool:
	return cards.has(id)

func aU(id: String) -> bool:
	return cards.get(id, "") == "u" or (both == id and cards.has(id) and cards.get("v_unmade", "") == "u")

func aR(id: String) -> bool:
	return cards.get(id, "") == "r" or (both == id and cards.has(id) and cards.get("v_unmade", "") == "u")

## The Unmade reversed: +1 to all skills for each Major held (up to +4)
func skill_bonus() -> int:
	return mini(4, majors_held()) if cards.get("v_unmade", "") == "r" else 0

## The Unmade, either way: a quarter of the life is gone
func life_k() -> float:
	return 0.75 if cards.has("v_unmade") else 1.0

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {"laid": laid.keys(), "cards": cards.duplicate(), "minor_bonus": minor_bonus, "both": both}

func from_dict(d: Dictionary) -> void:
	laid.clear()
	for k in d.get("laid", []):
		if N.has(k):
			laid[k] = true
	cards = {}
	var c: Dictionary = d.get("cards", {})
	for k in c:
		if N.has(k):
			cards[k] = c[k]
	minor_bonus = int(d.get("minor_bonus", 0))
	both = str(d.get("both", ""))
	_changed()
