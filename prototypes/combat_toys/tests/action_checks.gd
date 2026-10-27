extends SceneTree
## ACTION TOY CHECKS: small set-up moments, stepped frame by frame, for things the bot can't show.
##   1. Each red warning mark is honest: standing just on the red gets you hit, just off it doesn't.
##      (The charge strip, the bite fan and the burst-up circle. The edges are read from the
##      shapes actually drawn on the sand, not from tuning.gd.)
##   2. A click or roll pressed during the hit-freeze or a stagger isn't lost.
##   3. Being knocked out by the burst-up doesn't show "STUCK!" on the end screen.
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys --script res://tests/action_checks.gd

const Probe := preload("res://tests/action_probe.gd")
const T := preload("res://tuning.gd")
const DT := 1.0 / 60.0

var _ok := true


func _initialize() -> void:
	_run.call_deferred()     # once the main loop is going, so the fights get their _ready()


func _run() -> void:
	_check_marks()
	_check_buffer()
	_check_ko_by_erupt()
	quit(0 if _ok else 1)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	_ok = _ok and ok


## A fresh fight: the beetle in the middle facing north (-z), you somewhere south of it.
func _probe() -> Node:
	var a = Probe.new()
	root.add_child(a)
	a.set_physics_process(false)    # we step it ourselves
	a.b_pos = Vector3.ZERO
	a.b_yaw = 0.0
	a.b_dir = Vector3.FORWARD
	return a


## The beetle's warning for `kind` ends this frame, then it attacks. You stand still at `p`.
## Returns [was p on the red when the warning ended, did it hit you, the fight,
## the red shape's triangles as they were drawn at that moment, the mark itself].
func _attack(kind: String, p: Vector3, hearts := 5) -> Array:
	var a = _probe()
	a.p_pos = p
	a.hearts = hearts
	var mark: MeshInstance3D
	match kind:
		"lunge":
			a.b_state = "lunge_windup"
			mark = a._strip
		"snap":
			a.b_state = "snap_windup"
			mark = a._cone
		"erupt":
			a.b_state = "erupt_warn"
			a.b_target = Vector3.ZERO
			a.beetle.visible = false
			mark = a._circle
	a.b_t = 0.0001
	a._physics_process(DT)     # the last frame of the warning: the mark is drawn, then it strikes
	var tris := _triangles(mark)
	var red := _on_mark(tris, a.p_pos)
	for i in 120:               # let a charge run all the way
		if a.b_state != "lunge" or a.over:
			break
		a._physics_process(DT)
	return [red, a.hits_taken > 0, a, tris, mark]


## Is the point on the red shape as it's drawn right now? (Triangle by triangle, seen from above.)
func _on_mark(tris: Array, p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for tri in tris:
		# Inside (or exactly on an edge between two triangles): on the same side of all three edges
		var s1: float = (tri[1] - tri[0]).cross(q - tri[0])
		var s2: float = (tri[2] - tri[1]).cross(q - tri[1])
		var s3: float = (tri[0] - tri[2]).cross(q - tri[2])
		if (s1 >= -1e-5 and s2 >= -1e-5 and s3 >= -1e-5) or (s1 <= 1e-5 and s2 <= 1e-5 and s3 <= 1e-5):
			if absf((tri[1] - tri[0]).cross(tri[2] - tri[0])) > 1e-6:
				return true
	return false


func _triangles(mark: MeshInstance3D) -> Array:
	var f := mark.mesh.get_faces()
	var xf := mark.global_transform
	var out := []
	for i in range(0, f.size(), 3):
		var tri := []
		for k in 3:
			var g: Vector3 = xf * f[i + k]
			tri.append(Vector2(g.x, g.z))
		out.append(tri)
	return out


## Where the edges of a mark are, measured from what's drawn: [centre, forward, reach, half angle]
## for a fan, or [min corner, max corner] for the strip.
func _measure(kind: String) -> Array:
	var r: Array = _attack(kind, Vector3(0, 0, -17) if kind != "erupt" else Vector3(10, 0, 10))
	var a = r[2]
	var mark: MeshInstance3D = r[4]
	var pts := []
	for tri in r[3]:
		pts.append_array(tri)
	var out := []
	if kind == "lunge":
		var lo := Vector2(INF, INF)
		var hi := -lo
		for q in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		out = [lo, hi]
	else:
		var o := Vector2(mark.global_position.x, mark.global_position.z)
		var fw := Vector2(-mark.global_basis.z.x, -mark.global_basis.z.z).normalized()
		var reach := 0.0
		var half := 0.0
		for q in pts:
			var v: Vector2 = q - o
			if v.length() > 0.01:
				reach = maxf(reach, v.length())
				half = maxf(half, absf(fw.angle_to(v)))
		out = [o, fw, reach, half]
	a.free()
	return out


func _try(kind: String, name: String, p: Vector2, should_hit: bool) -> void:
	var r: Array = _attack(kind, Vector3(p.x, 0, p.y))
	r[2].free()
	_check("%s: %s  (on the red: %s, hit: %s)" % [kind, name, r[0], r[1]], r[0] == should_hit and r[1] == should_hit)


func _check_marks() -> void:
	# The charge: a strip along its line. Try just inside and outside its side edge and its far end.
	var s := _measure("lunge")
	var lo: Vector2 = s[0]
	var hi: Vector2 = s[1]
	print("charge strip drawn: %.2f m to each side, %.2f m ahead" % [hi.x, -lo.y])
	var mid := (lo.y + hi.y) * 0.5
	_try("lunge", "just inside the side edge gets hit", Vector2(hi.x - 0.05, mid), true)
	_try("lunge", "just outside the side edge is safe", Vector2(hi.x + 0.05, mid), false)
	_try("lunge", "just inside the far end gets hit", Vector2(0.0, lo.y + 0.1), true)
	_try("lunge", "just past the far end is safe", Vector2(0.0, lo.y - 0.1), false)
	# The bite: a fan in front of its head. Try its reach, and its side edge (a few degrees each way).
	var c := _measure("snap")
	print("bite fan drawn: reaches %.2f m, %.0f degrees to each side" % [c[2], rad_to_deg(c[3])])
	var o: Vector2 = c[0]
	var fw: Vector2 = c[1]
	_try("snap", "just inside its reach gets hit", o + fw * (c[2] - 0.05), true)
	_try("snap", "just past its reach is safe", o + fw * (c[2] + 0.05), false)
	_try("snap", "just inside its side edge gets hit", o + fw.rotated(c[3] - deg_to_rad(6)) * c[2] * 0.6, true)
	_try("snap", "just outside its side edge is safe", o + fw.rotated(c[3] + deg_to_rad(6)) * c[2] * 0.6, false)
	# The burst-up: a circle where it comes out.
	var e := _measure("erupt")
	print("burst-up circle drawn: %.2f m across the middle" % e[2])
	_try("erupt", "just inside the circle gets hit", Vector2(e[2] - 0.05, 0), true)
	_try("erupt", "just outside the circle is safe", Vector2(e[2] + 0.05, 0), false)


## You press `button` once, on the first frame, while `setup` is going on. Was it used afterwards?
func _pressed_during(setup: String, button: String) -> bool:
	var a = _probe()
	a.b_pos = Vector3(0, 0, -6)    # the beetle far off, walking over: nothing to dodge yet
	match setup:
		"freeze":
			a.freeze = 0.09
		"stagger":
			a.stagger_t = 0.3
		"roll":
			a.dodge_t = T.A_DODGE_TIME
			a.dodge_dir = Vector3.RIGHT
			a.dodge_cd = T.A_DODGE_TIME + T.A_DODGE_COOLDOWN
	a.press = {button: true}
	var used := false
	for i in 60:
		a._physics_process(DT)
		if i > 0 and ((button == "attack" and a.swing_t >= 0.0) or (button == "dodge" and a.dodge_t > 0.0 and setup != "roll")):
			used = true
	a.free()
	return used


func _check_buffer() -> void:
	_check("a click during the hit-freeze still swings when it ends", _pressed_during("freeze", "attack"))
	_check("a roll pressed during the hit-freeze still rolls when it ends", _pressed_during("freeze", "dodge"))
	_check("a click while staggered still swings when you recover", _pressed_during("stagger", "attack"))
	_check("a roll pressed while staggered still rolls when you recover", _pressed_during("stagger", "dodge"))
	_check("an old click (at the start of a roll) is forgotten, not fired late", not _pressed_during("roll", "attack"))


func _check_ko_by_erupt() -> void:
	var r: Array = _attack("erupt", Vector3(0.5, 0, 0), 1)
	var a = r[2]
	_check("knocked out by the burst-up: the fight ends and the beetle isn't 'stuck'  (state: %s)" % a.b_state,
			a.over and not a.won and a.b_state != "stuck")
	a.free()
