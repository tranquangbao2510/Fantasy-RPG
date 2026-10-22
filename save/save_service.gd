extends Node
## SaveService (Autoload duy nhất được phép, TASK M1): lưu/đọc trạng thái người chơi ra JSON. Không biết chi tiết hệ thống nào:
## - Node trong group `saveable` cung cấp `get_save_id() -> String` (ID ổn định, không phải đường dẫn node),
##   `save_state() -> Dictionary`, `load_state(Dictionary)`. Tùy chọn `is_save_global() -> bool` (true = đi theo
##   người chơi qua mọi map, vd. Player; mặc định thuộc map hiện tại, vd. rương, vật phẩm trên đất).
## - Map lưu được: scene hiện tại có `map_id` khác rỗng và có trong MapCatalog.
##
## Ô save (TASK M6): 3 ô (SLOT_COUNT) cho người chơi; mỗi ô một thư mục `user://saves/slot_<n>/` gồm bản thủ công
## (`manual.json`, lưu từ menu tạm dừng) và bản tự lưu (`autosave.json`, ghi khi ngủ), mỗi bản có `.bak`; ảnh chụp nhỏ
## `<bản>.png`; metadata `meta.json` = {version, manual: {...}, autosave: {...}} (ngày / giờ game, playtime, thời điểm lưu,
## map) — danh sách ô đọc file này, không phải đọc cả save. Save đơn cũ (M1–M5: `slot_<n>.json`) tự chuyển thành bản thủ
## công của ô n (lần đầu dùng thư mục save — _ensure_layout), không mất dữ liệu.
## Ô đang chơi: `current_slot` (chơi mới / tải / lưu thủ công đặt lại); tự lưu khi ngủ ghi vào ô này.
##
## Cấu trúc file (schema_version 6):
##   { schema_version, saved_at ("YYYY-MM-DD HH:MM:SS", giờ máy), saved_unix, playtime (giây), map_id,
##     global: { save_id: state }, maps: { map_id: { save_id: state } } }
## Trạng thái của các map khác (đã ghé trong phiên) được giữ nguyên khi lưu ở map hiện tại.
##
## Ghi an toàn: ghi `.tmp` → đổi file cũ thành `.bak` → đổi `.tmp` thành file chính. Đọc: file chính hỏng/thiếu
## thì thử `.bak`; cả hai hỏng thì báo lỗi, không crash. Field thiếu/sai kiểu → giá trị mặc định (+ cảnh báo).
## Bản cũ hơn → chạy migration theo từng version (SaveMigrations: v1 → v2 ở TASK M2, ..., v5 → v6 ở TASK M6); bản mới
## hơn → từ chối.
## Tải: đổi scene qua AppOverlay (màn đen, chặn input, game dừng tới khi áp xong trạng thái).

signal saved(slot: int)
## Đã tải xong và áp trạng thái lên scene mới.
signal loaded(slot: int)
## Lưu/tải thất bại (thông báo cho người chơi).
signal failed(message: String)
## Danh sách ô save đổi (lưu / xóa).
signal slots_changed

const SCHEMA_VERSION: int = 6
const GROUP: StringName = &"saveable"
const DEFAULT_SLOT: int = 1
## Số ô save người chơi chọn được.
const SLOT_COUNT: int = 3
const MANUAL: StringName = &"manual"
const AUTO: StringName = &"autosave"
const KINDS: Array[StringName] = [MANUAL, AUTO]
const META_VERSION: int = 1
const THUMBNAIL_SIZE: Vector2i = Vector2i(192, 108)
## Map bắt đầu khi chơi mới.
const NEW_GAME_MAP: StringName = &"glade"
const MAP_CATALOG: MapCatalog = preload("res://world/maps/map_catalog.tres")

## Thư mục save (test đổi sang thư mục riêng).
var save_dir: String = "user://saves/":
	set(value):
		save_dir = value
		_layout_checked = false
## Tổng thời gian chơi (giây) của phiên, chỉ tính khi đang ở map lưu được (dừng khi game tạm dừng).
var playtime: float = 0.0
## Lỗi gần nhất (rỗng nếu thành công).
var last_error: String = ""
## Ô đang chơi (0 = chưa chọn, vd. mở thẳng map từ editor → dùng DEFAULT_SLOT).
var current_slot: int = 0
## Chụp ảnh nhỏ khi lưu (tắt khi không có màn hình — headless).
var capture_thumbnails: bool = true

## version → Callable(data: Dictionary) -> Dictionary: nâng dữ liệu từ version đó lên version + 1.
var _migrations: Dictionary[int, Callable] = {}
## Dữ liệu phiên: global + maps đã ghé (nền để ghi đè khi lưu).
var _session: Dictionary = {}
var _timed_scene: Node
var _scene_counts_playtime: bool = false
var _saved_playtime: float = 0.0
var _new_game: bool = false
var _layout_checked: bool = false


func _ready() -> void:
	SaveMigrations.register_all(self)
	new_session()


func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _timed_scene:
		_timed_scene = scene
		_scene_counts_playtime = not _map_id_of(scene).is_empty()
	if _scene_counts_playtime:
		playtime += delta


# --- Phiên ---------------------------------------------------------------------------------------

## Bắt đầu phiên mới (về màn hình tiêu đề / vào map thử nghiệm): bỏ trạng thái phiên cũ, playtime về 0.
func new_session() -> void:
	_session = _default_data()
	playtime = 0.0
	_saved_playtime = 0.0
	_new_game = false


## Chơi mới vào ô `slot`: xóa dữ liệu cũ của ô (UI đã xác nhận ghi đè), phiên mới, vào map đầu game.
func start_new_game(slot: int) -> bool:
	if not _valid_player_slot(slot):
		return _fail("Ô save không hợp lệ.")
	delete_slot(slot)
	new_session()
	current_slot = slot
	_new_game = true
	AppOverlay.ensure(get_tree()).change_scene(MAP_CATALOG.get_scene_path(NEW_GAME_MAP))
	return true


## true một lần sau start_new_game (World hiện bảng gợi ý phím lần đầu).
func consume_new_game() -> bool:
	var value: bool = _new_game
	_new_game = false
	return value


## Ô dùng khi không chỉ định (ô đang chơi, hoặc DEFAULT_SLOT).
func get_active_slot() -> int:
	return current_slot if current_slot > 0 else DEFAULT_SLOT


## Có tiến trình chưa lưu (đã chơi thêm > 1 s ở map lưu được kể từ lần lưu / tải gần nhất).
func has_unsaved_progress() -> bool:
	return can_save() and playtime - _saved_playtime > 1.0


# --- Đường dẫn -----------------------------------------------------------------------------------

func get_slot_dir(slot: int) -> String:
	return save_dir.path_join("slot_%d" % slot)


func get_slot_path(slot: int, kind: StringName = MANUAL) -> String:
	return get_slot_dir(slot).path_join("%s.json" % kind)


func get_backup_path(slot: int, kind: StringName = MANUAL) -> String:
	return get_slot_path(slot, kind) + ".bak"


func get_thumbnail_path(slot: int, kind: StringName = MANUAL) -> String:
	return get_slot_dir(slot).path_join("%s.png" % kind)


func get_meta_path(slot: int) -> String:
	return get_slot_dir(slot).path_join("meta.json")


## Ô có bản `kind` (rỗng = bản bất kỳ).
func has_save(slot: int = DEFAULT_SLOT, kind: StringName = &"") -> bool:
	_ensure_layout()
	for k: StringName in KINDS:
		if (kind == &"" or kind == k) and (FileAccess.file_exists(get_slot_path(slot, k)) or FileAccess.file_exists(get_backup_path(slot, k))):
			return true
	return false


func has_any_save() -> bool:
	return not latest_save().is_empty()


## map_id của scene hiện tại ("" nếu không phải map lưu được).
func get_current_map_id() -> String:
	return _map_id_of(get_tree().current_scene)


func can_save() -> bool:
	return not get_current_map_id().is_empty()


# --- Lưu / tải -----------------------------------------------------------------------------------

## Lưu scene hiện tại vào bản `kind` của ô (0 = ô đang chơi). Luật gameplay (không lưu khi bị truy đuổi...) do World kiểm
## tra trước (World.get_save_block_reason). false (+ failed) nếu không ở map lưu được hoặc ghi lỗi.
func save_game(slot: int = 0, kind: StringName = MANUAL, thumbnail: Image = null) -> bool:
	if slot <= 0:
		slot = get_active_slot()
	var scene: Node = get_tree().current_scene
	if _map_id_of(scene).is_empty():
		return _fail("Không lưu được ở map này.")
	var data: Dictionary = capture(scene)
	if thumbnail == null:
		thumbnail = capture_thumbnail()
	if write_save(slot, data, kind, thumbnail) != OK:
		return _fail("Lưu thất bại: %s" % last_error)
	_session = data
	current_slot = slot
	_saved_playtime = playtime
	saved.emit(slot)
	return true


## Tự lưu (khi ngủ) vào ô đang chơi.
func autosave(thumbnail: Image = null) -> bool:
	return save_game(0, AUTO, thumbnail)


## Ảnh chụp nhỏ của khung hình hiện tại (null nếu không có màn hình / tắt chụp).
func capture_thumbnail() -> Image:
	if not capture_thumbnails or DisplayServer.get_name() == "headless":
		return null
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		return null
	image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image


## Đọc bản `kind` của ô (rỗng = bản mới nhất), mở scene của map trong save qua AppOverlay rồi áp trạng thái.
func load_game(slot: int = 0, kind: StringName = &"") -> bool:
	if slot <= 0:
		slot = get_active_slot()
	if kind == &"":
		kind = newest_kind(slot)
	var data: Dictionary = read_save(slot, kind)
	if data.is_empty():
		return _fail("Không tải được save: %s" % last_error)
	var map_id: StringName = StringName(data["map_id"])
	if not MAP_CATALOG.has_map(map_id):
		last_error = "map '%s' không có trong MapCatalog" % map_id
		return _fail("Không tải được save: %s" % last_error)
	var overlay: AppOverlay = AppOverlay.ensure(get_tree())
	if overlay.is_busy():
		last_error = "đang chuyển cảnh"
		return _fail("Không tải được save: %s" % last_error)
	_session = data
	playtime = data["playtime"]
	current_slot = slot
	_new_game = false
	overlay.change_scene(MAP_CATALOG.get_scene_path(map_id), _apply_loaded.bind(data, slot))
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
	data["saved_unix"] = Time.get_unix_time_from_system()
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


## Ghi an toàn (tmp → bak → chính) bản `kind` của ô + cập nhật metadata (+ ảnh nhỏ nếu có). Trả về mã lỗi; last_error mô tả lỗi.
func write_save(slot: int, data: Dictionary, kind: StringName = MANUAL, thumbnail: Image = null) -> Error:
	last_error = ""
	_ensure_layout()
	var err: Error = DirAccess.make_dir_recursive_absolute(get_slot_dir(slot))
	if err != OK:
		last_error = "không tạo được thư mục %s (%s)" % [get_slot_dir(slot), error_string(err)]
		return err
	err = _write_json_safely(get_slot_path(slot, kind), data)
	if err != OK:
		return err
	var thumb_path: String = get_thumbnail_path(slot, kind)
	var has_thumbnail: bool = false
	if thumbnail != null and not thumbnail.is_empty():
		has_thumbnail = thumbnail.save_png(thumb_path) == OK
	elif FileAccess.file_exists(thumb_path):
		DirAccess.remove_absolute(thumb_path)
	var meta: Dictionary = read_meta(slot)
	meta[String(kind)] = _meta_entry(data, has_thumbnail)
	_write_meta(slot, meta)
	slots_changed.emit()
	return OK


## Đọc bản `kind` của ô đã migrate + chuẩn hóa. File chính hỏng/thiếu → thử `.bak`. {} nếu cả hai hỏng (xem last_error).
func read_save(slot: int, kind: StringName = MANUAL) -> Dictionary:
	last_error = ""
	_ensure_layout()
	var data: Dictionary = _read_file(get_slot_path(slot, kind))
	if not data.is_empty():
		return data
	var main_error: String = last_error
	data = _read_file(get_backup_path(slot, kind))
	if data.is_empty():
		last_error = "%s; bản .bak: %s" % [main_error, last_error]
		push_error("[SaveService] Không đọc được ô %d (%s): %s" % [slot, kind, last_error])
		return {}
	push_warning("[SaveService] Ô %d (%s) hỏng (%s) — đã dùng bản .bak." % [slot, kind, main_error])
	return data


# --- Danh sách ô / metadata ----------------------------------------------------------------------

## Metadata của ô: {version, manual: {...}, autosave: {...}} (bản chưa có → không có khóa). Thiếu / hỏng file meta mà ô
## có save (vd. save chuyển từ bản cũ) → dựng lại từ save và ghi lại.
func read_meta(slot: int) -> Dictionary:
	_ensure_layout()
	var path: String = get_meta_path(slot)
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return _drop_missing_meta(slot, parsed)
		push_warning("[SaveService] meta.json của ô %d hỏng — dựng lại." % slot)
	return _rebuild_meta(slot)


## Danh sách ô người chơi: [{slot, manual: meta | {}, autosave: meta | {}}].
func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in range(1, SLOT_COUNT + 1):
		var meta: Dictionary = read_meta(slot)
		result.append({"slot": slot, "manual": meta.get(String(MANUAL), {}), "autosave": meta.get(String(AUTO), {})})
	return result


## Bản mới nhất trong ô (MANUAL nếu không có gì).
func newest_kind(slot: int) -> StringName:
	var meta: Dictionary = read_meta(slot)
	var best: StringName = MANUAL
	var best_time: float = -1.0
	for kind: StringName in KINDS:
		var entry: Variant = meta.get(String(kind))
		if entry is Dictionary and float((entry as Dictionary).get("saved_unix", 0.0)) > best_time:
			best_time = float((entry as Dictionary).get("saved_unix", 0.0))
			best = kind
	return best


## Bản save mới nhất trong mọi ô người chơi: {slot, kind} hoặc {} nếu chưa có save nào ("Tiếp tục").
func latest_save() -> Dictionary:
	var best: Dictionary = {}
	var best_time: float = -1.0
	for slot: int in range(1, SLOT_COUNT + 1):
		var meta: Dictionary = read_meta(slot)
		for kind: StringName in KINDS:
			var entry: Variant = meta.get(String(kind))
			if entry is Dictionary and float((entry as Dictionary).get("saved_unix", 0.0)) > best_time:
				best_time = float((entry as Dictionary).get("saved_unix", 0.0))
				best = {"slot": slot, "kind": kind}
	return best


## Ảnh nhỏ của bản `kind` (null nếu không có).
func load_thumbnail(slot: int, kind: StringName) -> Texture2D:
	var path: String = get_thumbnail_path(slot, kind)
	if not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


## Xóa mọi bản của ô (thủ công, tự lưu, .bak, ảnh, metadata).
func delete_slot(slot: int) -> void:
	_ensure_layout()
	var dir_path: String = get_slot_dir(slot)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(dir_path)
	if current_slot == slot:
		_saved_playtime = -INF
	slots_changed.emit()


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

func _apply_loaded(scene: Node, data: Dictionary, slot: int) -> void:
	apply(scene, data)
	_saved_playtime = playtime
	loaded.emit(slot)


func _default_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "saved_at": "", "saved_unix": 0.0, "playtime": 0.0, "map_id": "",
		"global": {}, "maps": {}}


func _valid_player_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


func _write_json_safely(path: String, data: Variant) -> Error:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "không ghi được %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())]
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err: Error = OK
	if FileAccess.file_exists(path):
		var backup: String = path + ".bak"
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


## Mục metadata của một bản save (đọc từ dữ liệu save, không đọc scene).
func _meta_entry(data: Dictionary, has_thumbnail: bool) -> Dictionary:
	var clock: Variant = (data.get("global", {}) as Dictionary).get("clock") if data.get("global") is Dictionary else null
	var day: int = 1
	var minute: float = 360.0
	if clock is Dictionary:
		day = int((clock as Dictionary).get("day", 1))
		minute = float((clock as Dictionary).get("minute", 360.0))
	var map_id: String = str(data.get("map_id", ""))
	var saved_unix: float = float(data.get("saved_unix", 0.0))
	return {"saved_at": str(data.get("saved_at", "")), "saved_unix": saved_unix, "playtime": float(data.get("playtime", 0.0)),
		"map_id": map_id, "map_name": MAP_CATALOG.get_display_name(StringName(map_id)), "day": day, "minute": minute,
		"schema_version": int(data.get("schema_version", SCHEMA_VERSION)), "thumbnail": has_thumbnail}


func _write_meta(slot: int, meta: Dictionary) -> void:
	meta["version"] = META_VERSION
	if _write_json_safely(get_meta_path(slot), meta) != OK:
		push_warning("[SaveService] Không ghi được meta.json của ô %d: %s" % [slot, last_error])
	var backup: String = get_meta_path(slot) + ".bak"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)


## Bỏ mục metadata của bản không còn file (vd. bị xóa tay).
func _drop_missing_meta(slot: int, meta: Dictionary) -> Dictionary:
	for kind: StringName in KINDS:
		if meta.has(String(kind)) and not has_save(slot, kind):
			meta.erase(String(kind))
	return meta


## Dựng metadata từ các bản save hiện có của ô (đọc cả save — chỉ khi thiếu / hỏng meta.json).
func _rebuild_meta(slot: int) -> Dictionary:
	var meta: Dictionary = {}
	for kind: StringName in KINDS:
		if not has_save(slot, kind):
			continue
		var error_before: String = last_error
		var data: Dictionary = _read_file(get_slot_path(slot, kind))
		if data.is_empty():
			data = _read_file(get_backup_path(slot, kind))
		last_error = error_before
		if data.is_empty():
			continue
		if float(data.get("saved_unix", 0.0)) <= 0.0:
			data["saved_unix"] = float(FileAccess.get_modified_time(get_slot_path(slot, kind)))
		meta[String(kind)] = _meta_entry(data, FileAccess.file_exists(get_thumbnail_path(slot, kind)))
	if not meta.is_empty():
		_write_meta(slot, meta)
	return meta


## Chuyển save đơn cũ (`slot_<n>.json` + `.bak`, M1–M5) thành bản thủ công của ô n. Một lần mỗi thư mục save.
func _ensure_layout() -> void:
	if _layout_checked:
		return
	_layout_checked = true
	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null:
		return
	var regex: RegEx = RegEx.create_from_string("^slot_(\\d+)\\.json$")
	for file: String in dir.get_files():
		var found: RegExMatch = regex.search(file)
		if found == null:
			continue
		var slot: int = found.get_string(1).to_int()
		if FileAccess.file_exists(get_slot_path(slot, MANUAL)):
			push_warning("[SaveService] Ô %d đã có bản thủ công — giữ nguyên save cũ %s." % [slot, file])
			continue
		DirAccess.make_dir_recursive_absolute(get_slot_dir(slot))
		var legacy: String = save_dir.path_join(file)
		if DirAccess.rename_absolute(legacy, get_slot_path(slot, MANUAL)) != OK:
			push_warning("[SaveService] Không chuyển được save cũ %s." % file)
			continue
		if FileAccess.file_exists(legacy + ".bak"):
			DirAccess.rename_absolute(legacy + ".bak", get_backup_path(slot, MANUAL))
		_rebuild_meta(slot)
		print("[SaveService] Đã chuyển save cũ %s thành ô %d (bản thủ công)." % [file, slot])


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
