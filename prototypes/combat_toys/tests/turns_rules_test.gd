extends SceneTree
## TURN-BASED RULES CHECKS: small set-up moments that a whole fight might not hit.
##   - Sand Sweep with Bram down hits You once, not twice.
##   - Double Snap's second bite doesn't jump to the other hero when the first one downs its target.
##   - Cards can't hit the beetle while it's underground (and can again once it bursts out).
##   - The smart bot never picks a hero who is down as the one to help.
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys --script res://tests/turns_rules_test.gd

const R := preload("res://turns_rules.gd")
const Bots := preload("res://turns_bots.gd")

var _ok := true


func _initialize() -> void:
	_sweep_with_bram_down()
	_snap_downs_its_target()
	_underground()
	_bot_helps_the_living()
	quit(0 if _ok else 1)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	_ok = _ok and ok


## A fight at the start of a turn, with the beetle about to do `id` (at `target`).
func _fight(id: String, target := -1) -> R:
	var r := R.new()
	r.start(1)
	r.intent = {"id": id, "target": target}
	r._last_intent = id
	return r


func _hits_on(ev: Array, who: int) -> int:
	var n := 0
	for e in ev:
		if e["t"] == "hit" and e["who"] == who:
			n += 1
	return n


func _sweep_with_bram_down() -> void:
	var r := _fight("sweep")
	r.hp[R.BRAM] = 0
	var before: int = r.hp[R.YOU]
	var d := r.intent_damage()
	var ev := r.end_turn()
	_check("Sand Sweep with Bram down hits You once  (%d hit(s), %d damage, sweep does %d)" % [_hits_on(ev, R.YOU), before - r.hp[R.YOU], d],
			_hits_on(ev, R.YOU) == 1 and before - r.hp[R.YOU] == d)


func _snap_downs_its_target() -> void:
	var r := _fight("snap", R.YOU)
	r.hp[R.YOU] = 3
	var bram: int = r.hp[R.BRAM]
	var ev := r.end_turn()
	_check("Double Snap at You: once You are down, the second bite doesn't hit Bram  (Bram %d -> %d)" % [bram, r.hp[R.BRAM]],
			not r.alive(R.YOU) and r.hp[R.BRAM] == bram and _hits_on(ev, R.BRAM) == 0)


func _underground() -> void:
	var r := _fight("burrow", R.YOU)
	r.end_turn()      # it digs in at the end of the turn; next turn it bursts up after 1 card
	r.hand = ["strike", "twin", "smash", "toss", "sidestep"]
	r.energy = 3
	var blocked := true
	for i in 4:
		blocked = blocked and r.cant_play(i) != ""
	var hp: int = r.hp[R.BEETLE]
	var shell: int = r.shell
	r.play(0)
	_check("while it's underground, attack cards can't be played  (reason: '%s')" % r.cant_play(0), blocked)
	_check("while it's underground, playing one anyway does nothing to it", r.hp[R.BEETLE] == hp and r.shell == shell)
	r.play(r.hand.find("sidestep"))     # the first card this turn, so it bursts up
	_check("once it bursts out, attack cards work again", r.intent["id"] != "erupt" and r.cant_play(0) == "")


func _bot_helps_the_living() -> void:
	var r := _fight("harden")
	r.hp[R.YOU] = 0
	r.hp[R.BRAM] = 25
	r.hand = ["patch"]
	r.energy = 3
	var m: Dictionary = Bots.choose(r, "smart", RandomNumberGenerator.new())
	_check("with You down, the smart bot patches Bram, not You  (picked %s)" % str(m), m.get("target", -1) == R.BRAM)
	var r2 := _fight("harden")
	r2.hp[R.YOU] = 0
	r2.hp[R.BRAM] = 25
	r2.hand = ["patch"]
	r2.energy = 3
	r2.play(0)      # no target given: the card picks
	_check("Patch Up with no target picked heals someone who is up  (Bram %d)" % r2.hp[R.BRAM], r2.hp[R.BRAM] > 25)
