extends "res://tests/test_base.gd"
## Smoke test (TASK M2): nạp và chạy vài chục frame mọi scene chính (Main, test_map, Combat Sandbox, Environment
## Prototype). Fail nếu có lỗi biên dịch / runtime / push_error trong lúc nạp và chạy (test_base.gd).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke/test_scenes_load.gd

const SCENES: Array[String] = [
	"res://app/main.tscn",
	"res://world/world.tscn",
	"res://world/sandbox/combat_sandbox.tscn",
	"res://world/environment_prototype/environment_prototype.tscn",
]


func _run_tests() -> void:
	for path: String in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		var scene: Node = packed.instantiate() if packed != null else null
		if scene == null:
			check("load_%s" % path.get_file(), false)
			continue
		root.add_child(scene)
		current_scene = scene
		await frames(30)
		check("run_%s" % path.get_file(), is_instance_valid(scene) and scene.is_inside_tree())
		scene.queue_free()
		await process_frame
