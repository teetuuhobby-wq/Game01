extends RefCounted
## TOY B RULES: the turn-based fight, as plain rules with no pictures (turns.gd draws it).
## You and Bram share one hand of cards and some energy each turn. The beetle always
## shows what it will do next, at whom, and WHEN: at the end of your turn, or after
## you've played a certain number of cards (so the order you play them in matters).
## Every change is returned as a list of events, so the screen can show them one by one.

const T := preload("res://tuning.gd")

const YOU := 0
const BRAM := 1
const BEETLE := 2
const NAMES := ["You", "Bram", "the beetle"]

## aim: "enemy" (the beetle), "ally" (you pick You or Bram), "self" (the card's owner)
const CARDS := {
	"strike": {"name": "Strike", "who": YOU, "cost": 1, "aim": "enemy", "text": "Deal 6."},
	"twin": {"name": "Twin Cut", "who": YOU, "cost": 2, "aim": "enemy", "text": "Deal 5, twice."},
	"flash": {"name": "Lantern Flash", "who": YOU, "cost": 1, "aim": "enemy", "text": "Dazzle it: its next attack does half damage."},
	"sidestep": {"name": "Sidestep", "who": YOU, "cost": 1, "aim": "self", "text": "You gain 7 Block this turn."},
	"smash": {"name": "Wrench Smash", "who": BRAM, "cost": 2, "aim": "enemy", "text": "Crack 8 Shell, then deal 8."},
	"patch": {"name": "Patch Up", "who": BRAM, "cost": 1, "aim": "ally", "text": "Heal You or Bram by 7."},
	"cover": {"name": "Cover", "who": BRAM, "cost": 1, "aim": "self", "text": "Bram gains 6 Block. Attacks at You hit Bram instead, this turn."},
	"toss": {"name": "Spanner Toss", "who": BRAM, "cost": 0, "aim": "enemy", "text": "Deal 3."},
}
const DECK := ["strike", "strike", "strike", "twin", "flash", "sidestep", "sidestep",
		"smash", "smash", "patch", "cover", "toss"]

## after: 0 = at the end of your turn; N = right after your Nth card this turn.
const INTENTS := {
	"lunge": {"name": "Lunge", "dmg": 11, "hits": 1, "aim": "one", "after": 0},
	"snap": {"name": "Double Snap", "dmg": 6, "hits": 2, "aim": "one", "after": 2},
	"sweep": {"name": "Sand Sweep", "dmg": 6, "hits": 1, "aim": "all", "after": 0},
	"harden": {"name": "Harden Shell", "shell": 8, "aim": "self", "after": 1},
	"burrow": {"name": "Burrow", "aim": "one", "after": 0},
	"erupt": {"name": "Erupt", "dmg": 16, "hits": 1, "aim": "one", "after": 1},
}
const ENRAGED_BONUS := 3     # extra damage per hit once it's below half health

var hp := [T.B_YOU_HEALTH, T.B_BRAM_HEALTH, T.B_BEETLE_HEALTH]
var max_hp := [T.B_YOU_HEALTH, T.B_BRAM_HEALTH, T.B_BEETLE_HEALTH]
var block := [0, 0, 0]
var shell := T.B_BEETLE_SHELL
var dazzled := false
var covered := false       # Bram is covering You this turn
var energy := 0
var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var intent := {}           # {"id", "target" (0/1, or -1 for everyone / itself)}
var cards_played := 0      # this turn
var acted := false         # the beetle already acted this turn
var turn := 0
var enraged := false
var result := ""           # "", "win" or "lose"
var rng := RandomNumberGenerator.new()
var _last_intent := ""


func start(seed_value: int) -> Array:
	rng.seed = seed_value
	draw_pile = DECK.duplicate()
	_shuffle(draw_pile)
	var ev := []
	_pick_intent(ev)
	_start_turn(ev)
	return ev


func alive(i: int) -> bool:
	return hp[i] > 0


## Why a card can't be played right now ("" = it can).
func cant_play(index: int) -> String:
	if result != "":
		return "the fight is over"
	var c: Dictionary = CARDS[hand[index]]
	if not alive(c["who"]):
		return "%s is down" % NAMES[c["who"]]
	if c["cost"] > energy:
		return "not enough energy"
	return ""


## Plays the card at `index` in the hand. target: YOU or BRAM for "ally" cards.
func play(index: int, target := -1) -> Array:
	var ev := []
	if cant_play(index) != "":
		return ev
	var id: String = hand[index]
	var c: Dictionary = CARDS[id]
	hand.remove_at(index)
	discard.append(id)
	energy -= c["cost"]
	cards_played += 1
	var who: int = c["who"]
	ev.append({"t": "card", "id": id, "who": who, "target": target})
	match id:
		"strike":
			_hurt_beetle(ev, 6, 0, who)
		"twin":
			_hurt_beetle(ev, 5, 0, who)
			if result == "":
				_hurt_beetle(ev, 5, 0, who)
		"flash":
			dazzled = true
			ev.append({"t": "dazzle"})
		"sidestep":
			block[YOU] += 7
			ev.append({"t": "block", "who": YOU, "amount": 7})
		"smash":
			_hurt_beetle(ev, 8, 8, who)
		"patch":
			if target != YOU and target != BRAM:
				target = YOU if hp[YOU] * max_hp[BRAM] < hp[BRAM] * max_hp[YOU] else BRAM
			if alive(target):
				var heal := mini(7, max_hp[target] - hp[target])
				hp[target] += heal
				ev.append({"t": "heal", "who": target, "amount": heal})
		"cover":
			block[BRAM] += 6
			covered = true
			ev.append({"t": "block", "who": BRAM, "amount": 6})
			ev.append({"t": "cover"})
		"toss":
			_hurt_beetle(ev, 3, 0, who)
	var after: int = INTENTS[intent["id"]]["after"]
	if result == "" and not acted and after > 0 and cards_played >= after:
		_beetle_acts(ev)
	return ev


func end_turn() -> Array:
	var ev := []
	if result != "":
		return ev
	if not acted:
		_beetle_acts(ev)
	discard.append_array(hand)
	hand.clear()
	if result == "":
		_start_turn(ev)
	return ev


## How many cards until the beetle acts this turn (0 = at the end of the turn, -1 = it already did).
func cards_until_act() -> int:
	if acted:
		return -1
	var after: int = INTENTS[intent["id"]]["after"]
	if after == 0:
		return 0
	return maxi(after - cards_played, 0)


## Damage per hit the current intent will do (before Block), with anger and dazzle.
func intent_damage() -> int:
	var d: int = INTENTS[intent["id"]].get("dmg", 0)
	if d > 0 and enraged:
		d += ENRAGED_BONUS
	if dazzled:
		d /= 2
	return d


func _start_turn(ev: Array) -> void:
	turn += 1
	energy = T.B_ENERGY
	block[YOU] = 0
	block[BRAM] = 0
	covered = false
	cards_played = 0
	acted = false
	for i in T.B_HAND:
		if draw_pile.is_empty():
			draw_pile = discard.duplicate()
			discard.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	ev.append({"t": "turn", "turn": turn})


func _beetle_acts(ev: Array) -> void:
	acted = true
	var id: String = intent["id"]
	var info: Dictionary = INTENTS[id]
	ev.append({"t": "beetle", "id": id, "target": intent["target"]})
	match id:
		"harden":
			var add: int = info["shell"] + (2 if enraged else 0)
			shell += add
			ev.append({"t": "shell", "amount": add})
		"burrow":
			ev.append({"t": "burrow"})
		_:
			var d := intent_damage()
			var targets: Array = [YOU, BRAM] if info["aim"] == "all" else [intent["target"]]
			for h in info["hits"]:
				for tg in targets:
					_hurt_party(ev, tg, d)
					if result != "":
						return
			if dazzled:
				dazzled = false
				ev.append({"t": "dazzle_gone"})
	if result == "":
		_pick_intent(ev)


func _hurt_party(ev: Array, tg: int, d: int) -> void:
	if not alive(tg):
		tg = BRAM if tg == YOU else YOU
	if tg == YOU and covered and alive(BRAM):
		tg = BRAM
		ev.append({"t": "covered"})
	var soaked := mini(block[tg], d)
	block[tg] -= soaked
	hp[tg] = maxi(hp[tg] - (d - soaked), 0)
	ev.append({"t": "hit", "who": tg, "dmg": d - soaked, "blocked": soaked})
	if hp[tg] == 0:
		ev.append({"t": "down", "who": tg})
		if not alive(YOU) and not alive(BRAM):
			result = "lose"
			ev.append({"t": "lose"})


func _hurt_beetle(ev: Array, d: int, crack: int, by: int) -> void:
	var cracked := mini(shell, crack)
	shell -= cracked
	var soaked := mini(shell, d)
	shell -= soaked
	hp[BEETLE] = maxi(hp[BEETLE] - (d - soaked), 0)
	ev.append({"t": "hit", "who": BEETLE, "dmg": d - soaked, "blocked": soaked, "cracked": cracked, "by": by})
	if hp[BEETLE] == 0:
		result = "win"
		ev.append({"t": "win"})
	elif not enraged and hp[BEETLE] * 2 <= max_hp[BEETLE]:
		enraged = true
		ev.append({"t": "enrage"})


func _pick_intent(ev: Array) -> void:
	var id := ""
	var target := YOU if rng.randf() < 0.5 else BRAM
	if not alive(target):
		target = BRAM if target == YOU else YOU
	if _last_intent == "burrow":
		id = "erupt"
		target = intent["target"] if alive(intent["target"]) else target
	else:
		var weights := {"lunge": 3.0, "snap": 3.0, "sweep": 2.0, "harden": 3.0 if shell == 0 else 1.0}
		if enraged:
			weights["burrow"] = 2.5
		weights.erase(_last_intent)
		var total := 0.0
		for k in weights:
			total += weights[k]
		var r := rng.randf() * total
		for k in weights:
			r -= weights[k]
			if r <= 0.0:
				id = k
				break
		if id == "":
			id = weights.keys()[0]
	var aim: String = INTENTS[id]["aim"]
	intent = {"id": id, "target": target if aim == "one" else -1}
	_last_intent = id
	ev.append({"t": "intent", "id": id, "target": intent["target"]})


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Plain words for what the beetle will do, for the screen.
func intent_text() -> String:
	var id: String = intent["id"]
	var info: Dictionary = INTENTS[id]
	var who: String = NAMES[intent["target"]] if intent["target"] >= 0 else ""
	match id:
		"lunge", "erupt":
			return "%s at %s: %d" % [info["name"], who, intent_damage()]
		"snap":
			return "%s at %s: %d x2" % [info["name"], who, intent_damage()]
		"sweep":
			return "%s: %d to both of you" % [info["name"], intent_damage()]
		"harden":
			return "%s: +%d Shell" % [info["name"], info["shell"] + (2 if enraged else 0)]
		"burrow":
			return "Burrow: next turn it bursts up under %s" % who
	return info["name"]
