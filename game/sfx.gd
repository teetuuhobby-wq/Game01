extends Node
## SOUND: every sound in the toy is made here from code, so there are no sound files.
## Footsteps, the city's giant stomps, wind, and the errand's chime, clunk and bell.

const T := preload("res://tuning.gd")
const RATE := 22050

var _steps: Array[AudioStreamWAV] = []
var _stomp: AudioStreamWAV
var _chime: AudioStreamWAV
var _clunk: AudioStreamWAV
var _tick: AudioStreamWAV
var _bell: AudioStreamWAV
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	for i in 4:
		_steps.append(_wav(_footstep()))
	_stomp = _wav(_make_stomp())
	_chime = _wav(_make_chime())
	_clunk = _wav(_make_clunk())
	_tick = _wav(_make_tick())
	_bell = _wav(_make_bell())
	var wind := AudioStreamPlayer.new()
	wind.stream = _wav(_make_wind(), true)
	wind.volume_db = T.WIND_DB
	wind.autoplay = true
	add_child(wind)


func footstep() -> void:
	_play(_steps[_rng.randi() % _steps.size()], T.FOOTSTEP_DB, _rng.randf_range(0.9, 1.1))


func stomp() -> void:
	_play(_stomp, T.STOMP_DB, _rng.randf_range(0.92, 1.05))


func chime() -> void:
	_play(_chime, T.EFFECTS_DB)


func clunk() -> void:
	_play(_clunk, T.EFFECTS_DB)


func tick() -> void:
	_play(_tick, T.EFFECTS_DB - 4.0, _rng.randf_range(0.95, 1.05))


func bell() -> void:
	_play(_bell, T.EFFECTS_DB)


func _play(stream: AudioStream, db: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


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
