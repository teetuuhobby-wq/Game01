extends Node
## SOUND: every sound in the game, by name. Each one can come from a recording
## (audio files in audio/<name>/, see audio/CREDITS.md) or be made here from code.
## The sound board (F4 in the game, sound_board.gd) lets you pick which, and set each
## sound's volume and variety; your choices are saved in audio/sound_settings.json.

const RATE := 22050
const SETTINGS := "res://audio/sound_settings.json"

## name: [group, what it is, "one" (plays when something happens) or "loop", volume (dB), variety]
## Variety = how much the pitch changes from one play to the next (0.1 = up to 10% either way).
const SOUNDS := {
	"footstep": ["You", "Your footsteps", "one", -10.0, 0.08],
	"stomp": ["City", "Giant footsteps", "one", -11.0, 0.06],
	"wind": ["City", "Desert wind", "loop", -20.0, 0.0],
	"crowd": ["Market", "Crowd chatter", "loop", -12.0, 0.0],
	"coins": ["Market", "Coins", "one", -18.0, 0.15],
	"crate": ["Market", "Crates set down", "one", -18.0, 0.15],
	"chime": ["Errand", "Picked something up", "one", -4.0, 0.0],
	"clunk": ["Errand", "Valve fitted", "one", -4.0, 0.0],
	"tick": ["Errand", "Valve turning", "one", -8.0, 0.05],
	"bell": ["Errand", "Town bell", "one", -4.0, 0.0],
}
## Sounds whose code-made version isn't good enough to play: they stay silent
## until a recording is chosen (the crowd murmur sounded like static).
const CODE_OFF := ["crowd"]

var world: Node3D    # set by main.gd, for how close you are to the market
var player: Node3D
var settings := {}   # name -> {"db": float, "variety": float, "choice": "code" | "off" | "all" | a file name}

var _code := {}      # name -> [AudioStream] made in code
var _files := {}     # name -> [file names] found in audio/<name>/
var _cache := {}     # file path -> AudioStream
var _loops := {}     # name -> AudioStreamPlayer for looping sounds
var _market_t := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	var steps := []
	for i in 4:
		steps.append(_wav(_footstep()))
	_code = {
		"footstep": steps, "stomp": [_wav(_make_stomp())], "wind": [_wav(_make_wind(), true)],
		"crowd": [_wav(_make_chatter(), true)], "coins": [_wav(_make_clink())], "crate": [_wav(_make_knock())],
		"chime": [_wav(_make_chime())], "clunk": [_wav(_make_clunk())], "tick": [_wav(_make_tick())],
		"bell": [_wav(_make_bell())],
	}
	rescan()
	_load_settings()
	for n in SOUNDS:
		if SOUNDS[n][2] == "loop":
			var p := AudioStreamPlayer.new()
			add_child(p)
			_loops[n] = p
			refresh_loop(n)


## Looks for recordings in audio/<name>/ (.ogg, .wav or .mp3).
func rescan() -> void:
	for n in SOUNDS:
		var found := []
		var dir := DirAccess.open("res://audio/" + n)
		if dir != null:
			for f in dir.get_files():
				if f.get_extension().to_lower() in ["ogg", "wav", "mp3"]:
					found.append(f)
		found.sort()
		_files[n] = found


## The choices for a sound, as shown on the sound board.
func choices(n: String) -> Array:
	var c := ["off", "code"]
	if _files[n].size() > 1:
		c.append("all")
	c.append_array(_files[n])
	return c


func _load_settings() -> void:
	var saved := {}
	if FileAccess.file_exists(SETTINGS):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if parsed is Dictionary:
			saved = parsed
	for n in SOUNDS:
		var def_choice := "code"
		if _files[n].size() > 1:
			def_choice = "all"
		elif _files[n].size() == 1:
			def_choice = _files[n][0]
		elif n in CODE_OFF:
			def_choice = "off"
		var st := {"db": float(SOUNDS[n][3]), "variety": float(SOUNDS[n][4]), "choice": def_choice}
		if saved.has(n) and saved[n] is Dictionary:
			for k in ["db", "variety", "choice"]:
				if saved[n].has(k):
					st[k] = saved[n][k]
		if not str(st["choice"]) in choices(n):
			st["choice"] = def_choice   # the chosen file was removed
		settings[n] = st


func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	f.store_string(JSON.stringify(settings, "\t", true))


## Back to the built-in volume and variety (keeps the chosen recording).
func reset(n: String) -> void:
	settings[n]["db"] = float(SOUNDS[n][3])
	settings[n]["variety"] = float(SOUNDS[n][4])
	refresh_loop(n)


## The stream to play for a sound right now (null = silent).
func _stream(n: String) -> AudioStream:
	var c: String = settings[n]["choice"]
	var loop: bool = SOUNDS[n][2] == "loop"
	if c == "off":
		return null
	if c == "code":
		return _code[n][_rng.randi() % _code[n].size()]
	var file := c
	if c == "all":
		file = _files[n][_rng.randi() % _files[n].size()]
	return _load_file("res://audio/%s/%s" % [n, file], loop)


## Loads a recording straight from its file (no import step needed).
func _load_file(path: String, loop: bool) -> AudioStream:
	var key := path + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	match path.get_extension().to_lower():
		"ogg":
			var o := AudioStreamOggVorbis.load_from_file(path)
			if o != null:
				o.loop = loop
			s = o
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(path)
			m.loop = loop
			s = m
		"wav":
			var w := AudioStreamWAV.load_from_file(path)
			if w != null and loop:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = int(w.get_length() * w.mix_rate)
			s = w
	if s == null:
		push_warning("sound: couldn't load " + path)
	_cache[key] = s
	return s


## Plays a one-off sound by name, with its volume and a little pitch variety.
func play(n: String, extra_db := 0.0) -> void:
	var stream := _stream(n)
	if stream == null:
		return
	var v: float = settings[n]["variety"]
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = float(settings[n]["db"]) + extra_db
	p.pitch_scale = 1.0 + _rng.randf_range(-v, v)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Restarts a looping sound with its current choice and volume.
func refresh_loop(n: String) -> void:
	if not _loops.has(n):
		return
	var p: AudioStreamPlayer = _loops[n]
	var stream := _stream(n)
	if p.stream != stream:
		p.stop()
		p.stream = stream
		if stream != null:
			p.play()
	if n == "wind":
		p.volume_db = settings[n]["db"]


## Plays a sound once on the sound board: a looping one for 4 seconds, at full volume.
func preview(n: String) -> void:
	if SOUNDS[n][2] == "one":
		play(n)
		return
	var stream := _stream(n)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = settings[n]["db"]
	add_child(p)
	p.play()
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


## After new files were found: keep the volumes, re-check the chosen recordings.
func reload_settings() -> void:
	var keep := settings.duplicate(true)
	_load_settings()
	for n in keep:
		settings[n]["db"] = keep[n]["db"]
		settings[n]["variety"] = keep[n]["variety"]
		if str(keep[n]["choice"]) in choices(n):
			settings[n]["choice"] = keep[n]["choice"]
		refresh_loop(n)


func footstep() -> void:
	play("footstep")


func stomp() -> void:
	play("stomp")


func chime() -> void:
	play("chime")


func clunk() -> void:
	play("clunk")


func tick() -> void:
	play("tick")


func bell() -> void:
	play("bell")


## How loud the market is where you stand: 1 in the street, fading over about 25 m.
func market_level() -> float:
	if world == null or player == null or not world.has_method("market_distance"):
		return 0.0
	var d: float = world.market_distance(player.position)
	return clampf(1.0 - (d - 3.0) / 25.0, 0.0, 1.0)


## The crowd follows you, and now and then a coin drops or a crate is set down.
func _process(delta: float) -> void:
	var k := market_level()
	var crowd: AudioStreamPlayer = _loops["crowd"]
	crowd.volume_db = float(settings["crowd"]["db"]) + linear_to_db(maxf(k * k, 0.0001))
	if k > 0.6:
		_market_t -= delta
		if _market_t <= 0.0:
			_market_t = _rng.randf_range(1.0, 4.0)
			play("coins" if _rng.randf() < 0.6 else "crate", _rng.randf_range(-4.0, 2.0))


## Turns samples (-1..1) into a 16-bit sound.
func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w


func _samples(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(seconds * RATE))
	return s


## A soft step on stone: a short, muffled burst of noise.
func _footstep() -> PackedFloat32Array:
	var s := _samples(0.12)
	var lp := 0.0
	for i in s.size():
		var tt := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		s[i] = lp * exp(-tt * 45.0) * 1.6
	return s


## A giant foot landing: a deep falling boom, a rumble, and a metal clank from the leg.
func _make_stomp() -> PackedFloat32Array:
	var s := _samples(1.6)
	var phase := 0.0
	var rumble := 0.0
	for i in s.size():
		var tt := float(i) / RATE
		phase += TAU * lerpf(58.0, 30.0, minf(1.0, tt / 0.8)) / RATE
		rumble += (_rng.randf_range(-1.0, 1.0) - rumble) * 0.02
		var boom := sin(phase) * exp(-tt * 3.0) * minf(1.0, tt * 200.0)
		var clank := (sin(TAU * 310.0 * tt) + 0.6 * sin(TAU * 467.0 * tt)) * exp(-tt * 14.0) * 0.12
		s[i] = boom * 0.85 + rumble * 4.0 * exp(-tt * 2.0) + clank
	return s


## Desert wind: slowly swelling, muffled noise that loops seamlessly.
func _make_wind() -> PackedFloat32Array:
	var n := _samples(6.0)
	var lp := 0.0
	for i in n.size():
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.03
		n[i] = lp
	var s := _samples(6.0)
	var size := s.size()
	for i in size:
		# Two copies half a loop apart, faded so the seam can't be heard
		var w := pow(sin(PI * i / size), 2.0)
		var j := (i + size / 2) % size
		var swell := 0.6 + 0.4 * sin(TAU * i / size * 2.0)
		s[i] = (n[i] * w + n[j] * (1.0 - w)) * swell * 3.0
	return s


## Two bright notes: you picked something up.
func _make_chime() -> PackedFloat32Array:
	var s := _samples(0.7)
	for i in s.size():
		var tt := float(i) / RATE
		var a := sin(TAU * 880.0 * tt) * exp(-tt * 9.0)
		var b := 0.0
		if tt > 0.12:
			b = sin(TAU * 1320.0 * (tt - 0.12)) * exp(-(tt - 0.12) * 7.0)
		s[i] = (a + b) * 0.35
	return s


## A solid metal clunk: the valve goes in.
func _make_clunk() -> PackedFloat32Array:
	var s := _samples(0.35)
	for i in s.size():
		var tt := float(i) / RATE
		s[i] = sin(TAU * 140.0 * tt) * exp(-tt * 22.0) * 0.8 + _rng.randf_range(-1.0, 1.0) * exp(-tt * 60.0) * 0.4
	return s


## A small ratchet click while you turn the valve.
func _make_tick() -> PackedFloat32Array:
	var s := _samples(0.05)
	for i in s.size():
		var tt := float(i) / RATE
		s[i] = (sin(TAU * 1900.0 * tt) * 0.5 + _rng.randf_range(-1.0, 1.0) * 0.5) * exp(-tt * 120.0)
	return s


## The town bell: a few out-of-tune partials ringing down, like real bronze.
func _make_bell() -> PackedFloat32Array:
	var s := _samples(4.0)
	var parts := [[0.5, 1.0, 0.6], [1.0, 0.8, 1.0], [1.19, 0.5, 1.3], [1.56, 0.4, 1.8], [2.0, 0.3, 2.2], [2.51, 0.2, 3.0]]
	for i in s.size():
		var tt := float(i) / RATE
		var v := 0.0
		for p in parts:
			v += sin(TAU * 392.0 * p[0] * tt) * p[1] * exp(-tt * p[2])
		s[i] = v * 0.25 * minf(1.0, tt * 400.0)
	return s


## A crowd murmur: several voices, each a buzzing tone shaped into vowel-ish
## sounds, in short syllables with pauses, mixed so they blur into chatter.
func _make_chatter() -> PackedFloat32Array:
	var n := _samples(3.0)
	var size := n.size()
	for v in 7:
		var f0 := _rng.randf_range(95.0, 230.0)
		var phase := 0.0
		var low := 0.0
		var band := 0.0
		var syl := 0.0
		var amp := 0.0
		var target := 0.0
		var f := 0.2
		for i in size:
			syl -= 1.0 / RATE
			if syl <= 0.0:
				syl = _rng.randf_range(0.08, 0.22)
				target = 0.0 if _rng.randf() < 0.25 else _rng.randf_range(0.4, 1.0)
				f = 2.0 * sin(PI * [380.0, 520.0, 700.0, 900.0, 1200.0][_rng.randi() % 5] / RATE)
				f0 = clampf(f0 * _rng.randf_range(0.94, 1.06), 85.0, 260.0)
			amp += (target - amp) * 0.0025
			phase = fmod(phase + f0 / RATE, 1.0)
			var high := (phase * 2.0 - 1.0) - low - 0.35 * band
			band += f * high
			low += f * band
			n[i] += band * amp * 0.12
	var s := _samples(3.0)
	for i in size:
		# Two copies half a loop apart, faded so the seam can't be heard
		var w := pow(sin(PI * i / size), 2.0)
		s[i] = n[i] * w + n[(i + size / 2) % size] * (1.0 - w)
	return s


## A coin dropped on a counter: two bright metal notes.
func _make_clink() -> PackedFloat32Array:
	var s := _samples(0.25)
	for i in s.size():
		var tt := float(i) / RATE
		s[i] = (sin(TAU * 2350.0 * tt) * 0.6 + sin(TAU * 3480.0 * tt) * 0.4) * exp(-tt * 28.0) * 0.5
	return s


## A crate set down on stone: a short, dull wooden thud.
func _make_knock() -> PackedFloat32Array:
	var s := _samples(0.18)
	var lp := 0.0
	for i in s.size():
		var tt := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.3
		s[i] = (sin(TAU * 170.0 * tt) * 0.7 + lp * 0.6) * exp(-tt * 35.0) * 0.8
	return s
