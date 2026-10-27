extends "res://action.gd"
## The action toy with no player at the keys: the checks in action_checks.gd set it up by hand,
## give it one press at a time and step it frame by frame.

var press := {}   # buttons pressed on the next frame only, e.g. {"attack": true}


func read_input() -> Dictionary:
	var out := {"move": Vector2.ZERO, "attack": press.get("attack", false), "dodge": press.get("dodge", false)}
	press = {}
	return out
