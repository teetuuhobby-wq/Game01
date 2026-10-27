extends "res://panel_base.gd"
## THE SOUND BOARD (F4): every sound in the game, grouped. Press ▶ to hear one, pick
## which recording it uses (or "code" for the made-in-code version, or "off"), and set
## its volume and variety (how much each play differs). Walk around with it open to
## hear the market crowd change live. "Save" keeps your choices for next time
## (audio/sound_settings.json). New files dropped into audio/<sound>/ show up after
## "Look for new files".

var sfx: Node   # sfx.gd


func _init() -> void:
	title = "Sound board   (F4 to close)"
	toggle_action = "sound_board"


func _build() -> void:
	var group := ""
	for n in sfx.SOUNDS:
		var info: Array = sfx.SOUNDS[n]
		if info[0] != group:
			group = info[0]
			header(group)
		var top := row(info[1] + ("  (loop)" if info[2] == "loop" else ""))
		button(top, " ▶ ", _preview.bind(n))
		option(top, sfx.choices(n), str(sfx.settings[n]["choice"]), _choose.bind(n))
		slider("   volume", -40.0, 6.0, 0.5, sfx.settings[n]["db"], _set_volume.bind(n), "%+.1f dB")
		if info[2] == "one":
			slider("   variety", 0.0, 0.3, 0.01, sfx.settings[n]["variety"], _set_variety.bind(n), "%.2f")
	button(_footer, "Save", _save)
	button(_footer, "Look for new files", _rescan)
	button(_footer, "Close", set_open.bind(false))


func _preview(n: String) -> void:
	sfx.preview(n)


func _choose(c: String, n: String) -> void:
	sfx.settings[n]["choice"] = c
	sfx.refresh_loop(n)
	sfx.preview(n)


func _set_volume(v: float, n: String) -> void:
	sfx.settings[n]["db"] = v
	sfx.refresh_loop(n)


func _set_variety(v: float, n: String) -> void:
	sfx.settings[n]["variety"] = v


func _save() -> void:
	sfx.save_settings()
	note("Saved. The game starts with these sounds next time.")


func _rescan() -> void:
	sfx.rescan()
	sfx.reload_settings()
	clear_rows()
	_build.call_deferred()
	note("Looked in game/audio/ for new recordings.")
