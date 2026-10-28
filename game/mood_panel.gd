extends "res://panel_base.gd"
## THE MOOD PANEL (F5): the world's light and colour on sliders, with presets
## (golden hour, midday, soft morning, dusk, night). Everything changes live.
## "Save as default" makes the game start with this look (mood.json).
## The light normally follows the time of day. Touching a slider or a preset pins it
## (the clock stops changing it); "Follow the day" hands it back to the clock.

var mood: Node   # mood.gd
var _sliders := {}
var _follow_note: Label
var _syncing := false   # moving the sliders to match the light: that's not you touching them
var _since_sync := 0.0


func _init() -> void:
	title = "Mood and lighting   (F5 to close)"
	toggle_action = "mood"


func _build() -> void:
	header("Time of day")
	var h0 := HBoxContainer.new()
	_box.add_child(h0)
	button(h0, "Follow the day", _follow)
	_follow_note = Label.new()
	h0.add_child(_follow_note)
	header("Presets")
	var names: Array = mood.PRESETS.keys()
	var row: HBoxContainer
	for i in names.size():
		if i % 3 == 0:   # three to a row
			row = HBoxContainer.new()
			_box.add_child(row)
		button(row, names[i], _preset.bind(names[i]))
	header("Light")
	for k in mood.SLIDERS:
		var s: Array = mood.SLIDERS[k]
		_sliders[k] = slider(s[0], s[1], s[2], s[3], mood.values[k], _change.bind(k), s[4])
	button(_footer, "Save as default", _save)
	button(_footer, "Back to saved", _reload)
	button(_footer, "Close", set_open.bind(false))
	_show_follow()


func _on_open(on: bool) -> void:
	if on:
		_sync()   # the light may have moved on with the clock since the panel was last open


## While the light follows the day, the sliders follow it too (twice a second).
func _process(delta: float) -> void:
	if not is_open() or not mood.follow_day:
		return
	_since_sync += delta
	if _since_sync >= 0.5:
		_since_sync = 0.0
		_sync()


func _change(v: float, k: String) -> void:
	mood.values[k] = v
	if not _syncing:
		_pin()
	mood.apply()


## You changed the look: the clock stops changing it.
func _pin() -> void:
	if mood.follow_day:
		mood.follow_day = false
		_show_follow()


func _follow() -> void:
	mood.follow()
	_sync()
	_show_follow()
	note("The light follows the time of day again.")


func _show_follow() -> void:
	_follow_note.text = "  following the clock" if mood.follow_day else "  pinned: your own look"


## Moves the sliders (and the numbers beside them) to the current values.
func _sync() -> void:
	_syncing = true
	for k in _sliders:
		_sliders[k].set_value_no_signal(mood.values[k])
		_sliders[k].value_changed.emit(mood.values[k])
	_syncing = false


func _preset(name: String) -> void:
	mood.use_preset(name)
	_pin()
	_sync()
	note("%s. Follow the day gives the light back to the clock." % name)


func _save() -> void:
	mood.save()
	mood.saved = mood.values.duplicate()
	note("Saved. It's the day's golden hour from now on.")


func _reload() -> void:
	mood._ready()
	_pin()
	_sync()
	note("Back to the saved look.")
