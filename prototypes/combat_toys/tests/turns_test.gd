extends "res://turns.gd"
## TURN-BASED TOY TEST: the smart bot plays the real screen (with all the animations)
## until the fight ends. Passes if the fight finishes with a win and nothing broke.
## Add --shots to save screenshots to shots/ (run with tools/godot_offscreen.ps1).
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys res://tests/turns_test.tscn -- --seed 1001

const Bots := preload("res://turns_bots.gd")

var shots := false
var _wait_t := 1.0
var _bot_rng := RandomNumberGenerator.new()
var _seen := {}
var _done := false
var _clock := 0.0
var style := "smart"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args.has("--shots")
	var bi := args.find("--bot")
	if bi >= 0 and bi + 1 < args.size():
		style = args[bi + 1]
	super()


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if shots:
		if _clock > 1.6 and not _seen.has("start"):
			_seen["start"] = true
			_save("start")
		if rules.turn == 2 and not busy and not _seen.has("turn2"):
			_seen["turn2"] = true
			_save("turn2")
		if rules.enraged and not busy and not _seen.has("enraged"):
			_seen["enraged"] = true
			_save("enraged")
	if rules.result != "":
		if not _done:
			_done = true
			if shots:
				get_tree().create_timer(2.2).timeout.connect(_save.bind("end"))
			get_tree().create_timer(3.0 if shots else 0.2).timeout.connect(_report)
		return
	if busy or _clock > 600.0:
		if _clock > 600.0 and not _done:
			_done = true
			_report()
		return
	_wait_t -= delta
	if _wait_t > 0.0:
		return
	_wait_t = 0.35
	var m: Dictionary = Bots.choose(rules, style, _bot_rng)
	if m.has("end"):
		_end_turn()
	elif R.CARDS[rules.hand[m["play"]]]["aim"] == "ally":
		_click_card(m["play"])
		if shots and not _seen.has("aiming"):
			_seen["aiming"] = true
			_save("aiming")
			_wait_t = 0.6
		_pick_target(m["target"] if m["target"] >= 0 else R.YOU)
	else:
		_click_card(m["play"])
		if shots and rules.cards_played == 1 and not _seen.has("card"):
			_seen["card"] = true
			get_tree().create_timer(0.3).timeout.connect(_save.bind("card"))


func _save(n: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/turns_%s.png" % n)


func _report() -> void:
	var ok := rules.result == "win" if style == "smart" else rules.result != ""
	print("%s  the %s bot finishes a fight on the real screen  (%s in %d turns, %.0f s)" % [
			"PASS" if ok else "FAIL", style, rules.result if rules.result != "" else "unfinished", rules.turn, _clock])
	get_tree().quit(0 if ok else 1)
