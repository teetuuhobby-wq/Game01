# WORLD FINGERPRINT: proves a code change left the built world exactly the same.
# Run it before and after a refactor and compare the FP lines (from the game/ folder):
#   <godot_console.exe> --headless --fixed-fps 30 --path . --script ../tools/world_fingerprint.gd
extends SceneTree
# It builds the world, lets it run 100 frames, then prints hashes of the blocks, walk map, shops and people.
var world: Node3D
var frames := 0

func _initialize() -> void:
	world = load("res://world.gd").new()
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 101:
		var people := ""
		for w in world.walkers + world.promenaders + world.market_people:
			people += str(w["node"].position.snapped(Vector3.ONE * 0.001))
		for l in world.legs:
			people += str(l["foot"].global_position.snapped(Vector3.ONE * 0.001))
		print("FP grid ", hash(world.grid), " filled ", world.filled.size())
		print("FP walk ", hash(world.walk_ok), " ", hash(world.walk_floor))
		print("FP market ", world.market_path.size(), " shops ", world.shopkeepers.size(), " shoppers ", world.shoppers.size())
		print("FP people ", world.walkers.size(), "/", world.promenaders.size(), "/", world.market_people.size(), "/", world.market_idlers.size(), " ", hash(people))
		print("FP spots ", world.you_spot, " ", world.workshop_use, " ", world.catcher_use)
		return true
	return false
