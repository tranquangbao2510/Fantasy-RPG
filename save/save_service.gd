extends Node
## SaveService (Autoload duy nhất được phép, TASK M1): lưu/đọc trạng thái người chơi ra JSON
## `user://saves/slot_<n>.json`. Không biết chi tiết hệ thống nào:
## - Node trong group `saveable` cung cấp `get_save_id() -> String` (ID ổn định, không phải đường dẫn node),
##   `save_state() -> Dictionary`, `load_state(Dictionary)`. Tùy chọn `is_save_global() -> bool` (true = đi theo
##   người chơi qua mọi map, vd. Player; mặc định thuộc map hiện tại, vd. rương, vật phẩm trên đất).
## - Map lưu được: scene hiện tại có `map_id` khác rỗng và có trong MapCatalog.
##
## Cấu trúc file (schema_version 3):
##   { schema_version, saved_at ("YYYY-MM-DD HH:MM:SS", giờ máy), playtime (giây), map_id,
##     global: { save_id: state }, maps: { map_id: { save_id: state } } }
## Trạng thái của các map khác (đã ghé trong phiên) được giữ nguyên khi lưu ở map hiện tại.
##
## Ghi an toàn: ghi `.tmp` → đổi file cũ thành `.bak` → đổi `.tmp` thành file chính. Đọc: file chính hỏng/thiếu
## thì thử `.bak`; cả hai hỏng thì báo lỗi, không crash. Field thiếu/sai kiểu → giá trị mặc định (+ cảnh báo).
## Bản cũ hơn → chạy migration theo từng version (SaveMigrations: v1 → v2 ở TASK M2, v2 → v3 ở TASK M3); bản mới hơn → từ chối.

signal saved(slot: int)
## Đã tải xong và áp trạng thái lên scene mới.
signal loaded(slot: int)
## Lưu/tải thất bại (thông báo cho người chơi).
signal failed(message: String)

const SCHEMA_VERSION: int = 3
const GROUP: StringName = &"saveable"
const DEFAULT_SLOT: int = 1
const MAP_CATALOG: MapCatalog = preload("res://world/maps/map_catalog.tres")

## Thư mục save (test đổi sang thư mục riêng).
var save_dir: String = "user://saves/"
## Tổng thời gian chơi (giây) của phiên, chỉ tính khi đang ở map lưu được.
var playtime: float = 0.0
## Tự lưu slot mặc định khi đóng cửa sổ game (nếu đang ở map lưu được).
var autosave_on_quit: bool = true
## Lỗi gần nhất (rỗng nếu thành công).
var last_error: String = ""

## version → Callable(data: Dictionary) -> Dictionary: nâng dữ liệu từ version đó lên version + 1.
var _migrations: Dictionary[int, Callable] = {}
## Dữ liệu phiên: global + maps đã ghé (nền để ghi đè khi lưu).
var _session: Dictionary = {}
var _pending_load: Dictionary = {}
var _pending_slot: int = 0
var _timed_scene: Node
var _scene_counts_playtime: bool = false


func _ready() -> void:
	SaveMigrations.register_all(self)
	new_session()
	get_tree().scene_changed.connect(_on_scene_changed)


func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _timed_scene:
		_timed_scene = scene
		_scene_counts_playtime = not _map_id_of(scene).is_empty()
	if _scene_counts_playtime:
		playtime += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_on_quit and can_save():
		save_game(DEFAULT_SLOT)


# --- API -----------------------------------------------------------------------------------------

## Bắt đầu phiên mới (New game / vào map thử nghiệm từ menu): bỏ trạng thái phiên cũ, playtime về 0.
func new_session() -> void:
	_session = _default_data()
	playtime = 0.0
	_pending_load = {}


func get_slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func get_backup_path(slot: int) -> String:
	return get_slot_path(slot) + ".bak"


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(get_slot_path(slot)) or FileAccess.file_exists(get_backup_path(slot))


## map_id của scene hiện tại ("" nếu không phải map lưu được).
func get_current_map_id() -> String:
	return _map_id_of(get_tree().current_scene)


func can_save() -> bool:
	return not get_current_map_id().is_empty()


## Lưu scene hiện tại vào slot. false (+ failed) nếu không ở map lưu được hoặc ghi lỗi.
func save_game(slot: int = DEFAULT_SLOT) -> bool:
	var scene: Node = get_tree().current_scene
	if _map_id_of(scene).is_empty():
		return _fail("Không lưu được ở map này.")
	var data: Dictionary = capture(scene)
	if write_save(slot, data) != OK:
		return _fail("Lưu thất bại: %s" % last_error)
	_session = data
	saved.emit(slot)
	return true


## Đọc slot, nạp lại scene của map trong save rồi áp trạng thái (sau khi scene mới _ready xong).
func load_game(slot: int = DEFAULT_SLOT) -> bool:
	var data: Dictionary = read_save(slot)
	if data.is_empty():
		return _fail("Không tải được save: %s" % last_error)
	var map_id: StringName = StringName(data["map_id"])
	if not MAP_CATALOG.has_map(map_id):
		last_error = "map '%s' không có trong MapCatalog" % map_id
		return _fail("Không tải được save: %s" % last_error)
	_session = data
	playtime = data["playtime"]
	_pending_load = data
	_pending_slot = slot
	var err: Error = get_tree().change_scene_to_file(MAP_CATALOG.get_scene_path(map_id))
	if err != OK:
		_pending_load = {}
		last_error = error_string(err)
		return _fail("Không mở được map: %s" % last_error)
	return true


## Chụp trạng thái mọi saveable dưới `root` (scene map) thành dữ liệu save hoàn chỉnh.
func capture(root: Node) -> Dictionary:
	var map_id: String = _map_id_of(root)
	var data: Dictionary = _session.duplicate(true) if not _session.is_empty() else _default_data()
	# Giữ trạng thái global của phiên mà scene này không có (vd. đồng hồ khi lưu ở map không có GameClock).
	var global: Dictionary = (data.get("global", {}) as Dictionary).duplicate(true) if data.get("global") is Dictionary else {}
	var map_states: Dictionary = {}
	var captured: Dictionary = {}
	for node: Node in _saveables_under(root):
		var id: String = str(node.call(&"get_save_id"))
		var state: Variant = node.call(&"save_state")
		var is_global: bool = _is_global(node)
		var target: Dictionary = global if is_global else map_states
		var key: String = ("g:" if is_global else "m:") + id
		if captured.has(key):
			push_error("[SaveService] save_id trùng '%s' (%s) — bỏ qua bản sau." % [id, node.get_path()])
			continue
		captured[key] = true
		target[id] = state if state is Dictionary else {}
	data["schema_version"] = SCHEMA_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	data["playtime"] = snappedf(playtime, 0.01)
	data["map_id"] = map_id
	data["global"] = global
	(data["maps"] as Dictionary)[map_id] = map_states
	return data


## Áp dữ liệu save lên các saveable dưới `root`. Saveable không có trong save giữ trạng thái mặc định của scene.
func apply(root: Node, data: Dictionary) -> void:
	var global: Dictionary = data.get("global", {})
	var maps: Dictionary = data.get("maps", {})
	var map_states: Variant = maps.get(_map_id_of(root), {})
	for node: Node in _saveables_under(root):
		var id: String = str(node.call(&"get_save_id"))
		var source: Dictionary = global if _is_global(node) else (map_states if map_states is Dictionary else {})
		var state: Variant = source.get(id)
		if state is Dictionary:
			node.call(&"load_state", state)
		elif state != null:
			push_warning("[SaveService] State của '%s' không phải Dictionary — giữ mặc định." % id)


## Ghi an toàn (tmp → bak → chính). Trả về mã lỗi; last_error mô tả lỗi.
func write_save(slot: int, data: Dictionary) -> Error:
	last_error = ""
	var err: Error = DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		last_error = "không tạo được thư mục %s (%s)" % [save_dir, error_string(err)]
		return err
	var path: String = get_slot_path(slot)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "không ghi được %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())]
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		var backup: String = get_backup_path(slot)
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		err = DirAccess.rename_absolute(path, backup)
		if err != OK:
			last_error = "không tạo được bản .bak (%s)" % error_string(err)
			return err
	err = DirAccess.rename_absolute(temp_path, path)
	if err != OK:
		last_error = "không đổi tên file tạm (%s)" % error_string(err)
	return err


## Đọc slot đã migrate + chuẩn hóa. File chính hỏng/thiếu → thử `.bak`. {} nếu cả hai hỏng (xem last_error).
func read_save(slot: int) -> Dictionary:
	last_error = ""
	var data: Dictionary = _read_file(get_slot_path(slot))
	if not data.is_empty():
		return data
	var main_error: String = last_error
	data = _read_file(get_backup_path(slot))
	if data.is_empty():
		last_error = "%s; bản .bak: %s" % [main_error, last_error]
		push_error("[SaveService] Không đọc được slot %d: %s" % [slot, last_error])
		return {}
	push_warning("[SaveService] Slot %d hỏng (%s) — đã dùng bản .bak." % [slot, main_error])
	return data


## Đăng ký migration từ `from_version` lên `from_version + 1`.
func register_migration(from_version: int, migration: Callable) -> void:
	_migrations[from_version] = migration


## Nâng dữ liệu lên SCHEMA_VERSION. {} nếu version mới hơn bản game hoặc thiếu bước migration.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", SCHEMA_VERSION))
	if version > SCHEMA_VERSION:
		last_error = "save từ phiên bản mới hơn (schema %d > %d)" % [version, SCHEMA_VERSION]
		return {}
	while version < SCHEMA_VERSION:
		if not _migrations.has(version):
			last_error = "thiếu migration từ schema %d" % version
			return {}
		data = _migrations[version].call(data)
		version += 1
		data["schema_version"] = version
	return data


# --- Nội bộ --------------------------------------------------------------------------------------

func _default_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "saved_at": "", "playtime": 0.0, "map_id": "", "global": {}, "maps": {}}


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		last_error = "không có file %s" % path.get_file()
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		last_error = "%s: JSON lỗi dòng %d (%s)" % [path.get_file(), json.get_error_line(), json.get_error_message()]
		return {}
	if not json.data is Dictionary:
		last_error = "%s: không phải object JSON" % path.get_file()
		return {}
	if not (json.data as Dictionary).has("schema_version"):
		push_warning("[SaveService] %s thiếu schema_version — coi như %d." % [path.get_file(), SCHEMA_VERSION])
	var data: Dictionary = migrate(json.data)
	return _normalize(data) if not data.is_empty() else {}


## Điền giá trị mặc định cho field thiếu / sai kiểu ở cấp gốc (field của từng hệ thống do hệ thống đó tự xử lý).
func _normalize(data: Dictionary) -> Dictionary:
	var defaults: Dictionary = _default_data()
	for key: String in defaults:
		var value: Variant = data.get(key)
		var expected: int = typeof(defaults[key])
		var ok: bool = typeof(value) == expected or (expected == TYPE_FLOAT and value is int) or (expected == TYPE_INT and value is float)
		if not ok:
			if data.has(key):
				push_warning("[SaveService] Field '%s' sai kiểu — dùng mặc định." % key)
			data[key] = defaults[key]
	data["schema_version"] = int(data["schema_version"])
	data["playtime"] = maxf(0.0, float(data["playtime"]))
	return data


func _saveables_under(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	for node: Node in root.get_tree().get_nodes_in_group(GROUP):
		if (node == root or root.is_ancestor_of(node)) and node.has_method(&"get_save_id") \
				and node.has_method(&"save_state") and node.has_method(&"load_state"):
			result.append(node)
	return result


func _is_global(node: Node) -> bool:
	return node.has_method(&"is_save_global") and bool(node.call(&"is_save_global"))


func _map_id_of(scene: Node) -> String:
	if scene == null or not &"map_id" in scene:
		return ""
	var map_id: String = str(scene.get(&"map_id"))
	return map_id if MAP_CATALOG.has_map(StringName(map_id)) else ""


func _fail(message: String) -> bool:
	push_warning("[SaveService] %s" % message)
	failed.emit(message)
	return false


func _on_scene_changed() -> void:
	if _pending_load.is_empty():
		return
	var data: Dictionary = _pending_load
	var slot: int = _pending_slot
	_pending_load = {}
	# Chờ một frame: các setup hoãn (call_deferred) trong _ready của map (vd. ElevationAgent) chạy xong trước.
	await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	apply(scene, data)
	loaded.emit(slot)
