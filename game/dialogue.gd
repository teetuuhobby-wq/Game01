extends RefCounted
## TALKING, as plain rules (no pictures): which line each resident says next.
## Each press of E gives the next line, round and round. Once Mira's errand is done,
## everyone starts again with their "after" line (news travels), then the rest.

const Town := preload("res://town_data.gd")

var _said := {}       # cast id -> how many lines they've said
var _knew_done := {}  # cast id -> true once they've started on their "after" lines


## The lines a resident has right now.
func lines_for(id: String, errand_done: bool) -> Array:
	var c: Dictionary = Town.CAST[id]
	var out: Array = []
	if errand_done:
		out.append_array(c.get("after", []))
	out.append_array(c["lines"])
	return out


## The next thing a resident says (and counts it).
func next_line(id: String, errand_done: bool) -> String:
	if errand_done and not _knew_done.get(id, false):
		_knew_done[id] = true
		_said[id] = 0
	var lines := lines_for(id, errand_done)
	var n: int = _said.get(id, 0)
	_said[id] = n + 1
	return lines[n % lines.size()]
