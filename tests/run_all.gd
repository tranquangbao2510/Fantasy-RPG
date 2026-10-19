extends SceneTree
## Chạy mọi test headless (tests/**/test_*.gd), mỗi test một tiến trình Godot riêng (scene/Autoload sạch).
## Một test FAIL khi: mã thoát ≠ 0 (ca sai, lỗi ngoài dự kiến, script không biên dịch được) hoặc không in dòng RESULT.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_all.gd
## Chỉ chạy một số test: biến môi trường TEST_ONLY=inventory,save (khớp một phần đường dẫn).
## Thoát mã 1 nếu có test FAIL.


func _init() -> void:
	quit(_run())


func _run() -> int:
	var tests: Array[String] = []
	_collect("res://tests", tests)
	tests.sort()
	var only: PackedStringArray = OS.get_environment("TEST_ONLY").split(",", false)
	var failures: Array[String] = []
	var ran: int = 0
	for path: String in tests:
		if not only.is_empty() and not Array(only).any(func(part: String) -> bool: return path.contains(part)):
			continue
		ran += 1
		var output: Array = []
		var started: int = Time.get_ticks_msec()
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", path], output, true)
		var text: String = _decode("".join(output))
		var result: String = ""
		for line: String in text.split("\n"):
			if line.begins_with("RESULT"):
				result = line.strip_edges()
		var ok: bool = code == 0 and not result.is_empty()
		print("%s %s — %s (%.1fs)" % ["PASS" if ok else "FAIL", path, result if not result.is_empty() else "không có dòng RESULT", (Time.get_ticks_msec() - started) / 1000.0])
		if not ok:
			failures.append(path)
			for line: String in text.split("\n"):
				if line.begins_with("FAIL") or line.contains("SCRIPT ERROR") or line.begins_with("ERROR"):
					print("    ", line.strip_edges())
	print("TESTS %d/%d passed" % [ran - failures.size(), ran])
	return 1 if not failures.is_empty() or ran == 0 else 0


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_base.gd":
			out.append(dir_path.path_join(file))


## Windows giải mã output tiến trình con theo CP1252 trong khi Godot in UTF-8 → đổi ngược lại để đọc được tiếng Việt.
## Không đổi được (đã là UTF-8 đúng / ký tự ngoài CP1252) thì giữ nguyên.
func _decode(text: String) -> String:
	const CP1252: Dictionary = {
		0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
		0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
		0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
		0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
	}
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		if code < 0x100:
			bytes.append(code)
		elif CP1252.has(code):
			bytes.append(CP1252[code])
		else:
			return text
	var decoded: String = bytes.get_string_from_utf8()
	return decoded if not decoded.is_empty() else text
