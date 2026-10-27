extends SceneTree
## TURN-BASED BALANCE TEST: plays 300 fights with a smart bot and 300 with a random one.
## Pass bar: the smart bot usually wins (it's beatable), the random one usually doesn't
## (choices matter), and fights last a handful of turns.
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys --script res://tests/turns_balance.gd

const Bots := preload("res://turns_bots.gd")


func _init() -> void:
	var rates := {}
	var turns := {}
	for style in ["smart", "random"]:
		var wins := 0
		var total_turns := 0
		for s in 300:
			var r: Dictionary = Bots.play_out(1000 + s, style)
			if r["result"] == "win":
				wins += 1
			total_turns += r["turns"]
		rates[style] = wins / 300.0
		turns[style] = total_turns / 300.0
		print("%s bot: wins %d%%, %.1f turns on average" % [style, int(rates[style] * 100), turns[style]])
	var checks := [
		["the smart bot wins most fights (60-95%)", rates["smart"] >= 0.6 and rates["smart"] <= 0.95],
		["playing at random loses most fights (under 35%)", rates["random"] < 0.35],
		["a fight lasts 5 to 12 turns", turns["smart"] >= 5.0 and turns["smart"] <= 12.0],
	]
	var ok := true
	for c in checks:
		print("%s  %s" % ["PASS" if c[1] else "FAIL", c[0]])
		ok = ok and c[1]
	quit(0 if ok else 1)
