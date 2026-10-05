extends SceneTree
## Board test: builds the Mystic's body board on a fake level-20 pilgrim and prints roads, laying and cards.
##   godot --headless --path . -s tests/test_arcana.gd
class FakeInv:
	var gold := 1000
class FakeSt:
	var level := 20
	var arcana_points := 3
	var inv := FakeInv.new()
func _init() -> void:
	var A = load("res://core/arcana.gd").new()
	var st := FakeSt.new()
	A.setup(st, "animancer")
	print("nodes ", A.N.size(), " root ", A.root_id(), " minor ", A.minor_avail())
	var r = A.road_to("w_ani_rung0_0")
	print("road to rung0_0 len ", r.size())
	var rd = A.road_to("a_anvil")
	print("road to card (should be empty) ", rd.size())
	# walk to the right-hand page: find the knot next to i_quake
	var q = ""
	for l in A.N["i_quake"]["links"]:
		if A.is_knot(l): q = l
	var r2 = A.road_to(q)
	print("road to hand ", q, " len ", r2.size(), " lay ", A.lay(q), " minor left ", A.minor_avail())
	print("i_quake why ", A.card_why_not("i_quake"), " take ", A.take_card("i_quake"))
	for c in ["i_rust", "i_rally"]:
		print(c, " why ", A.card_why_not(c))
	print("sums ", A.sums())
	print("can lift hand ", A.can_lift(q))
	quit()
