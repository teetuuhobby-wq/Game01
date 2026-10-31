extends RefCounted
## TALKING, as plain rules (no pictures): which line each resident says next.
## Each press of E gives the next line; after the last one the conversation ends
## (interact.gd closes it) and the next one starts from the top. Before Mira's errand is done
## some say their "before" lines first; once it's done, everyone starts again with
## their "after" lines (news travels), then the rest.

const Town := preload("res://town_data.gd")

var _said := {}       # cast id -> how many lines they've said
var _knew_done := {}  # cast id -> true once they've started on their "after" lines


## The lines a resident has right now. errand_on false: Mira's errand hasn't started
## yet (the morning round comes first), so nobody talks about the valve.
func lines_for(id: String, errand_done: bool, errand_on := true) -> Array:
	var c: Dictionary = Town.CAST[id]
	var out: Array = []
	if errand_done or errand_on:
		out.append_array(c.get("after" if errand_done else "before", []))
	out.append_array(c["lines"])
	return out


## The conversation is over (you said goodbye): next time they start from the top.
func restart(id: String) -> void:
	_said[id] = 0


## Which line (1..n) a resident said last, for showing "2/4".
func said_count(id: String, n: int) -> int:
	return posmod(_said.get(id, 1) - 1, n) + 1


## The next thing a resident says (and counts it).
func next_line(id: String, errand_done: bool, errand_on := true) -> String:
	if errand_done and not _knew_done.get(id, false):
		_knew_done[id] = true
		_said[id] = 0
	var lines := lines_for(id, errand_done, errand_on)
	var n: int = _said.get(id, 0)
	_said[id] = n + 1
	return lines[n % lines.size()]
