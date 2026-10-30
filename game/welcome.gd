extends Node
## THE MORNING ROUND: a first walk round the town, before Mira's errand. Mira asks you
## to help Pip with his deliveries; you take them to the guild, the store, the tavern,
## the bathhouse and the lookout, trying one thing at each place, and the last stop
## (Bram's workshop) hands over to Mira's errand. When the rain-catcher works again,
## the clock jumps to evening: the bell, the lamps, the city stopping and kneeling.
## When Day 2 begins, the round is over.
## The stops and every line are data: ROUND in town_data.gd. The clock stands still at
## ROUND_HOUR (tuning.gd) until the evening, so everyone is at work (T waits too), and
## nobody talks about Mira's valve until Bram hands it over. Turn the round off
## with WELCOME_ROUND in tuning.gd.

signal step_changed(what: String)   ## each stop done, "errand", "evening", "over" (for the recorder and tests)

const Town := preload("res://town_data.gd")
const T := preload("res://tuning.gd")
const THANKS_SECONDS := 8.0   # after the valve goes on: time for Mira's thanks before the evening

enum Phase { ROUND, ERRAND, THANKS, EVENING, OVER }

var phase := Phase.ROUND
var stop := 0          # which stop of Town.ROUND you're on
var world: Node3D      # world.gd
var player: Node3D     # player.gd
var hud: Node          # quest_hud.gd
var errand: Node       # errand.gd
var day_view: Node     # day_view.gd

var _wait := 0.0
var _carried: Node3D   # what you carry from stop to stop (the tea), or null


func setup(w: Node3D, p: Node3D, h: Node, e: Node, d: Node) -> void:
	world = w
	player = p
	hud = h
	errand = e
	day_view = d
	errand.active = false   # Mira's errand waits until Bram's
	day_view.jump_to(T.ROUND_HOUR)
	day_view.day.frozen = true
	day_view.hold_t = true   # T would close the places and send everyone home mid-round
	errand.step_changed.connect(_on_errand)
	day_view.happened.connect(_on_day)
	var s: Dictionary = Town.ROUND_START
	errand.set_bubble(s["bubble"], 12.0)
	hud.speak(s["who"], s["text"], 12.0)


func _process(delta: float) -> void:
	match phase:
		Phase.ROUND:
			var s: Dictionary = Town.ROUND[stop]
			var at := target()
			hud.goal("%s  (%s)" % [s["goal"], hud.where(player.position, at)])
			hud.prompt("")
			hud.point_at(at)
		Phase.THANKS:
			_wait -= delta
			if _wait <= 0.0:
				_evening()
		Phase.EVENING:
			hud.goal(Town.ROUND_EVENING["goal"])
			hud.point_at(null)
		Phase.OVER:
			hud.goal(Town.ROUND_OVER)
			hud.point_at(null)


## Where the current stop is (the resident, wherever they are now, or the thing to use).
func target() -> Vector3:
	var s: Dictionary = Town.ROUND[stop]
	if s["do"] == "talk":
		return world.cast_nodes[s["id"]].position
	for spot in world.interact_spots:
		if _is_stop_spot(spot, s):
			return spot["pos"]
	return player.position


## What a resident says when you talk to them at their stop, or Mira's reminder while
## the round is on ("" = their usual lines). interact.gd asks before every talk.
func talk_line(id: String) -> String:
	if phase != Phase.ROUND:
		return ""
	var s: Dictionary = Town.ROUND[stop]
	if s["do"] == "talk" and s["id"] == id:
		return s["line"]
	return Town.ROUND_START["mira_line"] if id == "mira" else ""


## True until Bram's stop hands over to Mira's errand: nobody talks about the valve yet.
func before_errand() -> bool:
	return phase == Phase.ROUND


## Something was used with E (interact.gd tells us): if it's this stop, on to the next.
func used(t: Dictionary) -> void:
	if phase != Phase.ROUND:
		return
	var s: Dictionary = Town.ROUND[stop]
	var match_it: bool = (t["kind"] == "talk" and s["do"] == "talk" and t["id"] == s["id"]) or _is_stop_spot(t, s)
	if not match_it:
		return
	if s.has("carry"):
		_carry(s["carry"])
	if s.has("say"):
		hud.speak("You", s["say"], 8.0)
	step_changed.emit("stop_%d_%s" % [stop + 1, s.get("id", s.get("where", ""))])
	stop += 1
	if stop >= Town.ROUND.size():
		# Bram's: the valve is right there, so Mira's errand takes over the guide
		phase = Phase.ERRAND
		errand.begin()
		step_changed.emit("errand")


func _is_stop_spot(spot: Dictionary, s: Dictionary) -> bool:
	if spot.get("kind", "") != s["do"] or s["do"] == "talk":
		return false
	if s["do"] == "sit":
		return spot["where"] == s["where"] and spot.get("soak", false) == s.get("soak", false)
	return spot["id"] == s["id"]


func _on_errand(what: String) -> void:
	if what == "valve_fitted" and phase == Phase.ERRAND:
		errand.active = false   # the guide is the round's again
		phase = Phase.THANKS
		_wait = THANKS_SECONDS
		hud.goal("Done! The rain-catcher works again.")
		hud.prompt("")
		hud.point_at(null)


## The clock jumps to evening behind a fade, then runs: bell, lamps, the city kneels.
func _evening() -> void:
	phase = Phase.EVENING
	day_view.hold_t = false
	day_view.fade_to(float(Town.ROUND_EVENING["hour"]), true)
	hud.speak("You", Town.ROUND_EVENING["say"], 10.0)
	step_changed.emit("evening")


func _on_day(what: String) -> void:
	if what == "skip_held":
		hud.speak("You", Town.ROUND_START["hold_t"], 5.0)
	if what == "awake" and phase == Phase.EVENING:
		phase = Phase.OVER
		hud.goal(Town.ROUND_OVER)
		step_changed.emit("over")


## Something small in your hand (the tea for Wendel), or nothing ("").
func _carry(what: String) -> void:
	if _carried != null:
		_carried.queue_free()
		_carried = null
	if what == "tea":
		_carried = Node3D.new()
		var cup := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.09, 0.1, 0.09)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.82, 0.75)
		m.material = mat
		cup.mesh = m
		_carried.add_child(cup)
		var tea := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.07, 0.01, 0.07)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.45, 0.25, 0.1)
		tm.material = tmat
		tea.mesh = tm
		tea.position = Vector3(0, 0.05, 0)
		_carried.add_child(tea)
		player.hand.add_child(_carried)
