extends SceneTree
## Nạp rồi lưu lại một scene như Editor (để Godot gán unique_id cho node thêm tay). Chạy ở chế độ editor:
##   Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --script res://tools/scene_resave/resave_scene.gd -- <res://scene.tscn>

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else ""
	var packed: PackedScene = load(path) as PackedScene
	var root_node: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var out: PackedScene = PackedScene.new()
	var err: Error = out.pack(root_node)
	if err == OK:
		err = ResourceSaver.save(out, path)
	print("resave %s: %s" % [path, error_string(err)])
	root_node.free()
	quit(0 if err == OK else 1)
