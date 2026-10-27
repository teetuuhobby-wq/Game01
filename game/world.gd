extends "res://world/walk_map.gd"
## THE WORLD: the desert, the walking city on its legs, and its people.
## Built from code at start-up. This file only puts it together (in this order) and
## moves it each frame; each part lives in its own file in world/, each one building
## on the one before (blocks -> sky_and_ground -> buildings -> city -> errand_sites ->
## market -> legs -> people -> walk_map -> here). See docs/ARCHITECTURE.md.


func _ready() -> void:
	rng.seed = SEED
	noise.seed = SEED
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	_init_palette()
	_make_materials()
	_make_world()
	_build_ground()
	_build_city()
	_seed("legs")
	_build_legs()
	_seed("people")
	_add_residents()
	_build_walk_map()


func _build_city() -> void:
	city = Node3D.new()
	add_child(city)
	grid.resize(NX * NY * NZ)
	_map_levels()
	_build_deck()
	_build_wall_ring()
	_build_terraces()
	_build_stairs()
	_reserve_streets()
	var top: int = LEVELS[LEVELS.size() - 1][1]
	origin = Vector3i(PLAZA_X, top, 0)
	_seed("plaza")
	_build_plaza()
	origin = Vector3i(0, top, 0)
	_seed("tower")
	_build_tower(-62, -13)
	origin = Vector3i.ZERO
	plaza_c = Vector3(PLAZA_X, top, 0) * VS
	_build_errand_sites()
	_seed("market")
	_build_market()
	_seed("houses")
	_place_houses()
	_seed("trees")
	_place_trees()
	_build_underside()
	for hip in _hip_positions():
		var hb := Vector3i(hip * RES)
		_sphere(hb.x, hb.y, hb.z, 11.0, P.HULL, P.BRASS)
	_build_struts()
	_emit_grid()


func _process(delta: float) -> void:
	if not paused:
		t += delta
		life_t += delta
		_update_walkers(delta)
		_update_promenaders(delta)
		_update_market(delta)
	var period := 2.0 * STEP_LENGTH / CITY_SPEED
	var body_x := CITY_SPEED * t
	if body_x > 230.0:
		# Loop back a whole number of strides. The desert repeats every LOOP metres,
		# so the jump can't be seen and the walk never ends.
		t -= LOOP / CITY_SPEED
		body_x = CITY_SPEED * t
	var bob := -0.6 * T.SWAY * absf(sin(TAU * t / period))
	city.position = Vector3(body_x, CITY_HEIGHT + bob, 0)
	city.rotation.x = 0.012 * T.SWAY * sin(TAU * t / period)
	_update_legs(period)
