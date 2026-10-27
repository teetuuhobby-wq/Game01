extends RefCounted
## BOTS that play the turn-based fight, for tests and screenshots (never for the player).
## "smart" reads the beetle's plan and defends first when a hit is coming; "random"
## plays any card it can. If smart wins much more often than random, choices matter.

const R := preload("res://turns_rules.gd")


## The next move: {"play": hand index, "target": who} or {"end": true}.
static func choose(rules, style: String, rng: RandomNumberGenerator) -> Dictionary:
	var playable := []
	for i in rules.hand.size():
		if rules.cant_play(i) == "":
			playable.append(i)
	if playable.is_empty():
		return {"end": true}
	if style == "random":
		if rng.randf() < 0.15:
			return {"end": true}
		var pick: int = playable[rng.randi() % playable.size()]
		return {"play": pick, "target": R.YOU if rng.randf() < 0.5 else R.BRAM}
	return _smart(rules, playable)


static func _find(rules, playable: Array, id: String) -> int:
	for i in playable:
		if rules.hand[i] == id:
			return i
	return -1


static func _smart(rules, playable: Array) -> Dictionary:
	var info: Dictionary = R.INTENTS[rules.intent["id"]]
	var incoming := {R.YOU: 0, R.BRAM: 0}
	if not rules.acted and info.has("dmg"):
		var total: int = rules.intent_damage() * info["hits"]
		if info["aim"] == "all":
			incoming[R.YOU] = total
			incoming[R.BRAM] = total
		else:
			var tg: int = rules.intent["target"]
			if tg == R.YOU and rules.covered:
				tg = R.BRAM
			incoming[tg] = total
	var you_need: int = incoming[R.YOU] - rules.block[R.YOU]
	var bram_need: int = incoming[R.BRAM] - rules.block[R.BRAM]
	# 1. A big hit is coming: blunt it first
	if not rules.dazzled and incoming[R.YOU] + incoming[R.BRAM] >= 12:
		var f := _find(rules, playable, "flash")
		if f >= 0:
			return {"play": f, "target": -1}
	if you_need >= 5 and rules.alive(R.YOU):
		var s := _find(rules, playable, "sidestep")
		if s >= 0:
			return {"play": s, "target": -1}
		var c := _find(rules, playable, "cover")
		if c >= 0 and rules.hp[R.BRAM] > rules.intent_damage() * 2 and not rules.covered:
			return {"play": c, "target": -1}
	if bram_need >= 5:
		var c := _find(rules, playable, "cover")
		if c >= 0 and not rules.covered:
			return {"play": c, "target": -1}
	# 2. Someone is badly hurt
	for who in [R.YOU, R.BRAM]:
		if rules.alive(who) and rules.hp[who] * 10 < rules.max_hp[who] * 5:
			var p := _find(rules, playable, "patch")
			if p >= 0:
				return {"play": p, "target": who}
	# 3. Hit it: crack the shell first, then the best damage for the energy left
	if rules.shell > 0:
		var sm := _find(rules, playable, "smash")
		if sm >= 0:
			return {"play": sm, "target": -1}
	for id in ["twin", "strike", "smash", "toss"]:
		var i := _find(rules, playable, id)
		if i >= 0:
			return {"play": i, "target": -1}
	# 4. Anything left that helps
	for id in ["sidestep", "cover", "flash", "patch"]:
		var i := _find(rules, playable, id)
		if i >= 0:
			var who: int = R.YOU if rules.hp[R.YOU] * rules.max_hp[R.BRAM] < rules.hp[R.BRAM] * rules.max_hp[R.YOU] else R.BRAM
			return {"play": i, "target": who}
	return {"end": true}


## Plays one whole fight; returns {"result", "turns"}.
static func play_out(seed_value: int, style: String) -> Dictionary:
	var rules := R.new()
	rules.start(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + 1
	var steps := 0
	while rules.result == "" and steps < 600:
		steps += 1
		var m := choose(rules, style, rng)
		if m.has("end"):
			rules.end_turn()
		else:
			rules.play(m["play"], m["target"])
	return {"result": rules.result, "turns": rules.turn}
