extends SceneTree
## Saves a screenshot as a JPG for docs/screens/ (several times smaller than PNG).
## Usage (from the repo root):
##   <godot_console.exe> --headless --script tools/to_jpg.gd -- <in.png> <out.jpg>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: --script tools/to_jpg.gd -- <in.png> <out.jpg>")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	if img == null:
		quit(1)
		return
	var err := img.save_jpg(args[1], 0.9)
	if err == OK:
		print("saved ", args[1])
	else:
		printerr("could not save ", args[1])
	quit(err)
