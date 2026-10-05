class_name Iso
extends RefCounted
## The grid projection. Godmarrow drew an isometric diamond grid; this game is Secret of Mana's straight top-down view:
## a tile (a yard) is an S x S square and screen = tile * S. Every system places things through to_screen / to_tile,
## so this one file turns the whole game top-down. HX and HY (half-sizes the iso grid used for screen radii) are both S
## here, so pools and rings come out round.

const S := 64.0             # Godot units (screen px at zoom 1) per tile
const WPX := 4.0            # Godot units per web world px (heights and offsets carried over from the web build)
const HX := S
const HY := S

static func to_screen(t: Vector2) -> Vector2:
	return t * S

static func to_tile(s: Vector2) -> Vector2:
	return s / S

## depth for y-sorting: screen y
static func depth(t: Vector2) -> float:
	return t.y
